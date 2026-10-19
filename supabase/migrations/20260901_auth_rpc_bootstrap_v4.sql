-- Auth RPC Bootstrap V4 — compatibility-safe production migration.
-- Creates the fail-closed RPC contracts needed by login and the POS JWT
-- gateway, but deliberately preserves legacy table grants/RLS during the
-- Windows rollout. Full table hardening is a separate post-rollout gate.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Production baseline 2026-08-26 does not yet have this column, while the
-- quick-PIN RPCs below require it. Keep the upgrade idempotent for databases
-- where an earlier auth rollout already added the column.
ALTER TABLE public.user_accounts
  ADD COLUMN IF NOT EXISTS quick_pin text;

-- The production staff baseline also predates per-user module overrides.
-- Admin RPCs and the current Flutter permission service both read/write this
-- field, so create it before compiling those routines.
ALTER TABLE public.staff_members
  ADD COLUMN IF NOT EXISTS modules jsonb NOT NULL DEFAULT '[]'::jsonb;

DO $$
DECLARE
  v_missing text;
BEGIN
  SELECT string_agg(required_name, ', ')
  INTO v_missing
  FROM (VALUES
    ('public.user_accounts.id'),
    ('public.user_accounts.phone'),
    ('public.user_accounts.display_name'),
    ('public.user_accounts.password_hash'),
    ('public.store_members.user_id'),
    ('public.store_members.store_id'),
    ('public.store_members.role'),
    ('public.staff_members.id'),
    ('public.staff_members.store_id'),
    ('public.staff_members.role'),
    ('public.stores.id'),
    ('public.stores.owner_user_id')
  ) AS required(required_name)
  WHERE NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = split_part(required_name, '.', 1)
      AND c.table_name = split_part(required_name, '.', 2)
      AND c.column_name = split_part(required_name, '.', 3)
  );

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'AUTH_PREFLIGHT_FAILED: missing columns: %', v_missing;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.pos_auth_attempts_v4 (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  phone_hash bytea NOT NULL,
  attempt_type text NOT NULL CHECK (attempt_type IN ('login', 'register', 'quick_pin')),
  is_success boolean NOT NULL DEFAULT false,
  attempted_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pos_auth_attempts_v4_window
  ON public.pos_auth_attempts_v4(phone_hash, attempt_type, attempted_at DESC);

ALTER TABLE public.pos_auth_attempts_v4 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_auth_attempts_v4 FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.pos_auth_attempts_v4 FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.onboarding_jti_consumptions_v4 (
  jti_hash text PRIMARY KEY CHECK (jti_hash ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.onboarding_jti_consumptions_v4 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_jti_consumptions_v4 FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.onboarding_jti_consumptions_v4
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.consume_onboarding_exchange_v4(
  p_jti_hash text,
  p_expires_at_epoch bigint,
  p_user_id uuid,
  p_store_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_rows integer;
  v_expires_at timestamptz := to_timestamp(p_expires_at_epoch);
  v_role text;
BEGIN
  IF p_jti_hash !~ '^[0-9a-f]{64}$'
     OR v_expires_at <= now()
     OR v_expires_at > now() + interval '10 minutes 30 seconds' THEN
    RETURN jsonb_build_object('consumed', false, 'error_code', 'INVALID_REPLAY_KEY');
  END IF;

  SELECT CASE WHEN is_owner THEN 'owner' ELSE role END
  INTO v_role
  FROM public.store_members
  WHERE user_id = p_user_id AND store_id = p_store_id;

  IF v_role IS NULL AND EXISTS (
    SELECT 1 FROM public.stores
    WHERE id = p_store_id AND owner_user_id = p_user_id
  ) THEN
    v_role := 'owner';
  END IF;

  IF v_role IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'STORE_MEMBERSHIP_FORBIDDEN'
    );
  END IF;

  DELETE FROM public.onboarding_jti_consumptions_v4
  WHERE expires_at <= now();

  INSERT INTO public.onboarding_jti_consumptions_v4(jti_hash, expires_at)
  VALUES (p_jti_hash, v_expires_at)
  ON CONFLICT (jti_hash) DO NOTHING;
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows <> 1 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'TOKEN_REPLAY_REJECTED'
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'role', v_role);
END;
$$;

CREATE OR REPLACE FUNCTION public.normalize_phone_digits_v4(p_phone text)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = public, extensions, pg_temp
AS $$
  SELECT CASE
    WHEN length(regexp_replace(p_phone, '\D', '', 'g')) >= 9
      THEN '+84' || right(regexp_replace(p_phone, '\D', '', 'g'), 9)
    ELSE regexp_replace(p_phone, '\D', '', 'g')
  END
$$;

CREATE OR REPLACE FUNCTION public.verify_password_hash_v4(
  p_phone text,
  p_password text,
  p_stored_hash text
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
STRICT
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_digits text := regexp_replace(p_phone, '\D', '', 'g');
  v_last9 text;
  v_variant text;
  v_legacy_hash text;
BEGIN
  IF p_password = '' OR p_stored_hash = '' THEN
    RETURN false;
  END IF;

  IF p_stored_hash LIKE '$2a$%'
     OR p_stored_hash LIKE '$2b$%'
     OR p_stored_hash LIKE '$2y$%' THEN
    RETURN crypt(p_password, p_stored_hash) = p_stored_hash;
  END IF;

  v_last9 := right(v_digits, 9);
  FOREACH v_variant IN ARRAY ARRAY[
    p_phone,
    '0' || v_last9,
    '+84' || v_last9,
    '84' || v_last9
  ]
  LOOP
    v_legacy_hash := encode(
      digest(convert_to(v_variant || ':' || p_password || ':qn_pos_2024_salt', 'utf8'), 'sha256'),
      'hex'
    );
    IF lower(v_legacy_hash) = lower(p_stored_hash) THEN
      RETURN true;
    END IF;
  END LOOP;
  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.has_active_store_access_v4(p_store_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL
     AND (
       EXISTS (
         SELECT 1
         FROM public.store_members sm
         WHERE sm.user_id = auth.uid() AND sm.store_id = p_store_id
       )
       OR EXISTS (
         SELECT 1
         FROM public.stores s
         WHERE s.id = p_store_id AND s.owner_user_id = auth.uid()
       )
     )
$$;

CREATE OR REPLACE FUNCTION public.verify_user_login_v4(
  p_phone text,
  p_password text,
  p_store_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_phone text := public.normalize_phone_digits_v4(COALESCE(p_phone, ''));
  v_phone_hash bytea;
  v_user record;
  v_valid boolean := false;
  v_failures integer;
  v_stores jsonb := '[]'::jsonb;
  v_selected_role text;
BEGIN
  IF v_phone = '' OR COALESCE(p_password, '') = '' THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 400,
      'error_code', 'MISSING_PARAMETERS',
      'message', 'Số điện thoại và mật khẩu là bắt buộc'
    );
  END IF;

  v_phone_hash := digest(convert_to(v_phone, 'utf8'), 'sha256');
  PERFORM pg_advisory_xact_lock(hashtextextended(encode(v_phone_hash, 'hex'), 0));

  DELETE FROM public.pos_auth_attempts_v4
  WHERE attempted_at < now() - interval '24 hours';

  SELECT count(*) INTO v_failures
  FROM public.pos_auth_attempts_v4
  WHERE phone_hash = v_phone_hash
    AND attempt_type = 'login'
    AND is_success = false
    AND attempted_at >= now() - interval '5 minutes';

  IF v_failures >= 5 THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 429,
      'error_code', 'RATE_LIMIT_EXCEEDED',
      'message', 'Quá nhiều lần thử thất bại. Vui lòng thử lại sau 5 phút.'
    );
  END IF;

  SELECT ua.id, ua.phone, ua.display_name, ua.password_hash
  INTO v_user
  FROM public.user_accounts ua
  WHERE public.normalize_phone_digits_v4(ua.phone) = v_phone
  ORDER BY ua.id
  LIMIT 1
  FOR UPDATE;

  IF v_user.id IS NOT NULL THEN
    v_valid := public.verify_password_hash_v4(
      v_user.phone,
      p_password,
      v_user.password_hash
    );
  END IF;

  IF NOT v_valid THEN
    INSERT INTO public.pos_auth_attempts_v4(phone_hash, attempt_type, is_success)
    VALUES (v_phone_hash, 'login', false);
    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'INVALID_CREDENTIALS',
      'message', 'Số điện thoại hoặc mật khẩu không chính xác'
    );
  END IF;

  IF v_user.password_hash NOT LIKE '$2a$%'
     AND v_user.password_hash NOT LIKE '$2b$%'
     AND v_user.password_hash NOT LIKE '$2y$%' THEN
    UPDATE public.user_accounts
    SET password_hash = crypt(p_password, gen_salt('bf', 12))
    WHERE id = v_user.id;
  END IF;

  DELETE FROM public.pos_auth_attempts_v4
  WHERE phone_hash = v_phone_hash AND attempt_type = 'login';

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'store_id', s.id,
    'store_name', s.name,
    'store_code', s.store_code,
    'role', sm.role,
    'is_owner', COALESCE(sm.is_owner, false)
  ) ORDER BY s.name), '[]'::jsonb)
  INTO v_stores
  FROM public.store_members sm
  JOIN public.stores s ON s.id = sm.store_id
  WHERE sm.user_id = v_user.id;

  IF p_store_id IS NOT NULL THEN
    SELECT sm.role INTO v_selected_role
    FROM public.store_members sm
    WHERE sm.user_id = v_user.id AND sm.store_id = p_store_id;

    IF v_selected_role IS NULL AND EXISTS (
      SELECT 1 FROM public.stores s
      WHERE s.id = p_store_id AND s.owner_user_id = v_user.id
    ) THEN
      v_selected_role := 'owner';
    END IF;

    IF v_selected_role IS NULL THEN
      RETURN jsonb_build_object(
        'success', false, 'status', 403,
        'error_code', 'STORE_MEMBERSHIP_FORBIDDEN',
        'message', 'Tài khoản không thuộc cửa hàng này'
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true, 'status', 200,
    'user_id', v_user.id,
    'phone', v_phone,
    'display_name', COALESCE(v_user.display_name, 'Người dùng'),
    'stores', v_stores,
    'selected_role', v_selected_role
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.register_user_account_v4(
  p_phone text,
  p_password text,
  p_display_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_phone text := public.normalize_phone_digits_v4(COALESCE(p_phone, ''));
  v_phone_hash bytea;
  v_user_id uuid := gen_random_uuid();
BEGIN
  IF v_phone = '' OR length(COALESCE(p_password, '')) < 8
     OR trim(COALESCE(p_display_name, '')) = '' THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 400,
      'error_code', 'INVALID_INPUT',
      'message', 'Thông tin đăng ký không hợp lệ'
    );
  END IF;

  v_phone_hash := digest(convert_to(v_phone, 'utf8'), 'sha256');
  PERFORM pg_advisory_xact_lock(hashtextextended(encode(v_phone_hash, 'hex'), 0));

  IF EXISTS (
    SELECT 1 FROM public.user_accounts ua
    WHERE public.normalize_phone_digits_v4(ua.phone) = v_phone
  ) THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 409,
      'error_code', 'PHONE_ALREADY_EXISTS',
      'message', 'Số điện thoại này đã được đăng ký. Vui lòng đăng nhập.'
    );
  END IF;

  INSERT INTO public.user_accounts(id, phone, display_name, password_hash)
  VALUES (
    v_user_id,
    v_phone,
    trim(p_display_name),
    crypt(p_password, gen_salt('bf', 12))
  );

  RETURN jsonb_build_object(
    'success', true, 'status', 200,
    'user_id', v_user_id,
    'phone', v_phone,
    'display_name', trim(p_display_name)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.change_user_password_v4(
  p_old_password text,
  p_new_password text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_user record;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực phiên đăng nhập'
    );
  END IF;
  IF length(COALESCE(p_new_password, '')) < 8 THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 400,
      'error_code', 'INVALID_PASSWORD_LENGTH',
      'message', 'Mật khẩu mới phải từ 8 ký tự trở lên'
    );
  END IF;

  SELECT ua.id, ua.phone, ua.password_hash
  INTO v_user
  FROM public.user_accounts ua
  WHERE ua.id = auth.uid()
  FOR UPDATE;

  IF v_user.id IS NULL OR NOT public.verify_password_hash_v4(
    v_user.phone, p_old_password, v_user.password_hash
  ) THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'INVALID_OLD_PASSWORD',
      'message', 'Mật khẩu hiện tại không chính xác'
    );
  END IF;

  UPDATE public.user_accounts
  SET password_hash = crypt(p_new_password, gen_salt('bf', 12))
  WHERE id = v_user.id;

  RETURN jsonb_build_object(
    'success', true, 'status', 200, 'message', 'Đổi mật khẩu thành công'
  );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- AUTHENTICATED SERVER-SIDE RPCS REPLACING DIRECT CLIENT MUTATIONS
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Set / Update 6-digit Quick PIN for authenticated user
CREATE OR REPLACE FUNCTION public.set_user_quick_pin_v4(p_pin text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực phiên đăng nhập'
    );
  END IF;

  IF p_pin IS NULL OR p_pin !~ '^\d{6}$' THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 400,
      'error_code', 'INVALID_PIN_FORMAT', 'message', 'Mã PIN phải gồm đúng 6 chữ số'
    );
  END IF;

  UPDATE public.user_accounts
  SET quick_pin = crypt(p_pin, gen_salt('bf', 12))
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'success', true, 'status', 200,
    'message', 'Cập nhật mã PIN duyệt nhanh thành công'
  );
END;
$$;

-- 2. Check if current authenticated user has configured Quick PIN (0 data leak)
CREATE OR REPLACE FUNCTION public.has_user_quick_pin_v4()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_has_pin boolean := false;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực phiên đăng nhập'
    );
  END IF;

  SELECT (quick_pin IS NOT NULL AND length(quick_pin) > 0)
  INTO v_has_pin
  FROM public.user_accounts
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'success', true, 'status', 200,
    'has_quick_pin', COALESCE(v_has_pin, false)
  );
END;
$$;

-- 3. Verify Manager / Owner Quick PIN for a specific store (Rate limited & Secure)
CREATE OR REPLACE FUNCTION public.verify_manager_quick_pin_v4(
  p_store_id uuid,
  p_pin text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_hash bytea;
  v_failures integer;
  v_manager record;
  v_matched boolean := false;
  v_manager_id uuid;
  v_manager_name text;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực phiên đăng nhập'
    );
  END IF;

  IF p_pin IS NULL OR p_pin !~ '^\d{6}$' THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 400,
      'error_code', 'INVALID_PIN_FORMAT', 'message', 'Mã PIN phải gồm đúng 6 chữ số'
    );
  END IF;

  IF NOT public.has_active_store_access_v4(p_store_id) THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 403,
      'error_code', 'STORE_MEMBERSHIP_FORBIDDEN', 'message', 'Tài khoản không thuộc cửa hàng này'
    );
  END IF;

  v_caller_hash := digest(convert_to(v_caller_id::text || ':' || p_store_id::text, 'utf8'), 'sha256');
  PERFORM pg_advisory_xact_lock(
    hashtextextended(encode(v_caller_hash, 'hex'), 0)
  );

  SELECT count(*) INTO v_failures
  FROM public.pos_auth_attempts_v4
  WHERE phone_hash = v_caller_hash
    AND attempt_type = 'quick_pin'
    AND is_success = false
    AND attempted_at >= now() - interval '5 minutes';

  IF v_failures >= 5 THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 429,
      'error_code', 'RATE_LIMIT_EXCEEDED',
      'message', 'Quá nhiều lần nhập sai mã PIN. Vui lòng thử lại sau 5 phút.'
    );
  END IF;

  FOR v_manager IN
    SELECT ua.id, ua.phone, ua.display_name, ua.quick_pin
    FROM public.user_accounts ua
    JOIN public.store_members sm ON sm.user_id = ua.id
    WHERE sm.store_id = p_store_id
      AND (sm.role IN ('owner', 'manager') OR sm.is_owner = true)
    UNION
    SELECT ua.id, ua.phone, ua.display_name, ua.quick_pin
    FROM public.user_accounts ua
    JOIN public.stores s ON s.owner_user_id = ua.id
    WHERE s.id = p_store_id
  LOOP
    IF v_manager.quick_pin IS NOT NULL AND v_manager.quick_pin <> '' THEN
      IF v_manager.quick_pin LIKE '$2a$%' OR v_manager.quick_pin LIKE '$2b$%' OR v_manager.quick_pin LIKE '$2y$%' THEN
        IF crypt(p_pin, v_manager.quick_pin) = v_manager.quick_pin THEN
          v_matched := true;
          v_manager_id := v_manager.id;
          v_manager_name := v_manager.display_name;
          EXIT;
        END IF;
      ELSE
        IF public.verify_password_hash_v4(v_manager.phone, p_pin, v_manager.quick_pin) THEN
          v_matched := true;
          v_manager_id := v_manager.id;
          v_manager_name := v_manager.display_name;
          UPDATE public.user_accounts
          SET quick_pin = crypt(p_pin, gen_salt('bf', 12))
          WHERE id = v_manager.id;
          EXIT;
        END IF;
      END IF;
    END IF;
  END LOOP;

  IF v_matched THEN
    DELETE FROM public.pos_auth_attempts_v4
    WHERE phone_hash = v_caller_hash AND attempt_type = 'quick_pin';

    RETURN jsonb_build_object(
      'success', true, 'status', 200,
      'manager_id', v_manager_id,
      'manager_name', COALESCE(v_manager_name, 'Quản lý')
    );
  ELSE
    INSERT INTO public.pos_auth_attempts_v4(phone_hash, attempt_type, is_success)
    VALUES (v_caller_hash, 'quick_pin', false);

    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'INVALID_PIN',
      'message', 'Mã PIN quản lý không chính xác'
    );
  END IF;
END;
$$;

-- 4. Create Store with Owner Membership Atomically
CREATE OR REPLACE FUNCTION public.create_store_with_owner_v4(
  p_store_name text,
  p_store_code text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_store_id uuid := gen_random_uuid();
  v_code text;
  v_exists boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực phiên đăng nhập'
    );
  END IF;

  IF trim(COALESCE(p_store_name, '')) = '' THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 400,
      'error_code', 'INVALID_STORE_NAME', 'message', 'Vui lòng nhập tên quán'
    );
  END IF;

  IF p_store_code IS NOT NULL AND trim(p_store_code) <> '' THEN
    v_code := upper(trim(p_store_code));
  ELSE
    LOOP
      v_code := 'QN-' || upper(substring(encode(gen_random_bytes(3), 'hex') from 1 for 4));
      SELECT EXISTS(SELECT 1 FROM public.stores WHERE store_code = v_code) INTO v_exists;
      EXIT WHEN NOT v_exists;
    END LOOP;
  END IF;

  INSERT INTO public.stores(id, name, store_code, owner_user_id, status, created_at)
  VALUES (v_store_id, trim(p_store_name), v_code, v_user_id, 'trial', now());

  INSERT INTO public.store_members(user_id, store_id, role, is_owner, created_at)
  VALUES (v_user_id, v_store_id, 'owner', true, now())
  ON CONFLICT (user_id, store_id) DO UPDATE SET role = 'owner', is_owner = true;

  RETURN jsonb_build_object(
    'success', true, 'status', 200,
    'store_id', v_store_id,
    'store_code', v_code,
    'store_name', trim(p_store_name),
    'role', 'owner',
    'is_owner', true
  );
END;
$$;

-- 5. Join Store by Code with Server-Determined Role
CREATE OR REPLACE FUNCTION public.join_store_by_code_v4(p_store_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_code text := upper(trim(COALESCE(p_store_code, '')));
  v_store record;
  v_existing record;
  v_assigned_role text := 'waiter';
  v_caller_phone text;
  v_staff record;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực phiên đăng nhập'
    );
  END IF;

  IF v_code = '' THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 400,
      'error_code', 'MISSING_STORE_CODE', 'message', 'Vui lòng nhập mã quán'
    );
  END IF;

  SELECT id, name, store_code, status, owner_user_id
  INTO v_store
  FROM public.stores
  WHERE store_code = v_code;

  IF v_store.id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 404,
      'error_code', 'STORE_NOT_FOUND', 'message', 'Mã quán không tồn tại'
    );
  END IF;

  IF v_store.status IN ('suspended', 'deleted') THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 403,
      'error_code', 'STORE_INACTIVE', 'message', 'Quán này đã bị khóa hoặc ngừng hoạt động'
    );
  END IF;

  SELECT role, is_owner
  INTO v_existing
  FROM public.store_members
  WHERE user_id = v_user_id AND store_id = v_store.id;

  IF v_existing.role IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true, 'status', 200,
      'store_id', v_store.id,
      'store_code', v_store.store_code,
      'store_name', v_store.name,
      'role', v_existing.role,
      'is_owner', COALESCE(v_existing.is_owner, false)
    );
  END IF;

  IF v_store.owner_user_id = v_user_id THEN
    v_assigned_role := 'owner';
  ELSE
    SELECT phone INTO v_caller_phone FROM public.user_accounts WHERE id = v_user_id;

    SELECT role INTO v_staff
    FROM public.staff_members
    WHERE store_id = v_store.id
      AND (id = v_user_id OR (v_caller_phone IS NOT NULL AND phone = v_caller_phone))
    LIMIT 1;

    IF v_staff.role IS NOT NULL AND v_staff.role <> '' THEN
      v_assigned_role := v_staff.role;
    ELSE
      v_assigned_role := 'waiter';
    END IF;
  END IF;

  INSERT INTO public.store_members(user_id, store_id, role, is_owner, created_at)
  VALUES (v_user_id, v_store.id, v_assigned_role, (v_assigned_role = 'owner'), now())
  ON CONFLICT (user_id, store_id) DO NOTHING;

  RETURN jsonb_build_object(
    'success', true, 'status', 200,
    'store_id', v_store.id,
    'store_code', v_store.store_code,
    'store_name', v_store.name,
    'role', v_assigned_role,
    'is_owner', (v_assigned_role = 'owner')
  );
END;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- 6. SERVER-AUTHORIZED DEVICE PAIRING (PHẦN B)
-- ═════════════════════════════════════════════════════════════════════════════
-- LEGACY POS INFRASTRUCTURE EXPLORATION ONLY — EXCLUDE FROM QR ORDER V4.
-- The accepted QR flow authenticates employees by account + store code and
-- treats device_id only as audit/idempotency metadata. Remove this entire
-- section from any QR V4 migration candidate after the real catalog is known.

/*
 * Intentionally excluded from this migration. Production already owns legacy
 * store_pairing_codes/pos_device_sessions tables with an incompatible V3
 * contract. Reusing those names would either fail the migration or corrupt the
 * active device-session subsystem. QR/Auth V4 does not consume these RPCs.

CREATE TABLE IF NOT EXISTS public.store_pairing_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  code_hash text NOT NULL,
  assigned_role text NOT NULL CHECK (assigned_role IN ('waiter', 'cashier', 'kitchen', 'stock', 'manager')),
  device_name text,
  created_by uuid NOT NULL REFERENCES public.user_accounts(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  is_claimed boolean NOT NULL DEFAULT false,
  claimed_at timestamptz,
  claimed_by_device text,
  is_revoked boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_store_pairing_codes_lookup
  ON public.store_pairing_codes(store_id, is_claimed, is_revoked, expires_at);

ALTER TABLE public.store_pairing_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_pairing_codes FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.store_pairing_codes FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.pos_device_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  device_identifier text NOT NULL,
  device_name text NOT NULL,
  assigned_role text NOT NULL CHECK (assigned_role IN ('waiter', 'cashier', 'kitchen', 'stock', 'manager')),
  paired_via_code_id uuid REFERENCES public.store_pairing_codes(id),
  paired_by uuid NOT NULL REFERENCES public.user_accounts(id),
  paired_at timestamptz NOT NULL DEFAULT now(),
  last_active_at timestamptz NOT NULL DEFAULT now(),
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE(store_id, device_identifier)
);

CREATE INDEX IF NOT EXISTS idx_pos_device_sessions_store
  ON public.pos_device_sessions(store_id, is_active);

ALTER TABLE public.pos_device_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_device_sessions FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.pos_device_sessions FROM PUBLIC, anon, authenticated;

-- 6.1 Create Device Pairing Code
CREATE OR REPLACE FUNCTION public.create_device_pairing_code_v4(
  p_store_id uuid,
  p_role text,
  p_device_name text DEFAULT 'Thiết bị mới',
  p_ttl_seconds integer DEFAULT 900
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_raw_code text;
  v_code_hash text;
  v_pairing_id uuid := gen_random_uuid();
  v_expires_at timestamptz;
  v_ttl integer := COALESCE(p_ttl_seconds, 900);
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 401, 'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực');
  END IF;

  SELECT role INTO v_caller_role FROM public.store_members WHERE user_id = v_caller_id AND store_id = p_store_id;
  IF v_caller_role IS NULL THEN
    SELECT 'owner' INTO v_caller_role FROM public.stores WHERE id = p_store_id AND owner_user_id = v_caller_id;
  END IF;

  IF v_caller_role NOT IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Chỉ chủ quán hoặc quản lý mới được tạo mã kết nối thiết bị');
  END IF;

  IF p_role NOT IN ('waiter', 'cashier', 'kitchen', 'stock', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'INVALID_ROLE', 'message', 'Vai trò thiết bị không hợp lệ');
  END IF;

  IF v_caller_role = 'manager' AND p_role = 'manager' THEN
    -- Manager cannot create another manager device pairing
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Quản lý không thể cấp quyền Quản lý cho thiết bị khác');
  END IF;

  IF v_ttl < 60 OR v_ttl > 3600 THEN
    v_ttl := 900;
  END IF;

  v_expires_at := now() + (v_ttl || ' seconds')::interval;
  v_raw_code := 'PAIR-' || upper(substring(encode(gen_random_bytes(4), 'hex') from 1 for 6));
  v_code_hash := crypt(v_raw_code, gen_salt('bf', 10));

  INSERT INTO public.store_pairing_codes(id, store_id, code_hash, assigned_role, device_name, created_by, created_at, expires_at)
  VALUES (v_pairing_id, p_store_id, v_code_hash, p_role, COALESCE(p_device_name, 'Thiết bị mới'), v_caller_id, now(), v_expires_at);

  RETURN jsonb_build_object(
    'success', true, 'status', 200,
    'pairing_id', v_pairing_id,
    'pairing_code', v_raw_code,
    'assigned_role', p_role,
    'expires_at', v_expires_at
  );
END;
$$;

-- 6.2 Claim Device Pairing Code
CREATE OR REPLACE FUNCTION public.claim_device_pairing_code_v4(
  p_pairing_code text,
  p_device_identifier text,
  p_device_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_clean_code text := upper(trim(COALESCE(p_pairing_code, '')));
  v_clean_device text := trim(COALESCE(p_device_identifier, ''));
  v_rec record;
  v_session_id uuid := gen_random_uuid();
BEGIN
  IF v_clean_code = '' OR v_clean_device = '' THEN
    RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'MISSING_PARAMETERS', 'message', 'Mã kết nối và định danh thiết bị là bắt buộc');
  END IF;

  SELECT * INTO v_rec
  FROM public.store_pairing_codes
  WHERE is_claimed = false
    AND is_revoked = false
    AND expires_at > now()
    AND crypt(v_clean_code, code_hash) = code_hash
  FOR UPDATE LIMIT 1;

  IF v_rec.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 401, 'error_code', 'INVALID_OR_EXPIRED_CODE', 'message', 'Mã kết nối không hợp lệ, đã hết hạn hoặc đã được sử dụng');
  END IF;

  UPDATE public.store_pairing_codes
  SET is_claimed = true,
      claimed_at = now(),
      claimed_by_device = v_clean_device
  WHERE id = v_rec.id;

  INSERT INTO public.pos_device_sessions(id, store_id, device_identifier, device_name, assigned_role, paired_via_code_id, paired_by, paired_at, last_active_at, is_active)
  VALUES (v_session_id, v_rec.store_id, v_clean_device, COALESCE(p_device_name, v_rec.device_name, 'Thiết bị POS'), v_rec.assigned_role, v_rec.id, v_rec.created_by, now(), now(), true)
  ON CONFLICT (store_id, device_identifier) DO UPDATE
    SET device_name = COALESCE(p_device_name, excluded.device_name),
        assigned_role = excluded.assigned_role,
        paired_via_code_id = excluded.paired_via_code_id,
        paired_by = excluded.paired_by,
        paired_at = now(),
        last_active_at = now(),
        is_active = true;

  RETURN jsonb_build_object(
    'success', true, 'status', 200,
    'store_id', v_rec.store_id,
    'role', v_rec.assigned_role,
    'device_name', COALESCE(p_device_name, v_rec.device_name),
    'device_identifier', v_clean_device
  );
END;
$$;

-- 6.3 Revoke Device Pairing Code
CREATE OR REPLACE FUNCTION public.revoke_device_pairing_code_v4(p_pairing_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_store_id uuid;
  v_caller_role text;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 401, 'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực');
  END IF;

  SELECT store_id INTO v_store_id FROM public.store_pairing_codes WHERE id = p_pairing_id;
  IF v_store_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 404, 'error_code', 'NOT_FOUND', 'message', 'Không tìm thấy mã kết nối');
  END IF;

  SELECT role INTO v_caller_role FROM public.store_members WHERE user_id = v_caller_id AND store_id = v_store_id;
  IF v_caller_role NOT IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Không có quyền');
  END IF;

  UPDATE public.store_pairing_codes SET is_revoked = true WHERE id = p_pairing_id;
  RETURN jsonb_build_object('success', true, 'status', 200, 'message', 'Thu hồi mã kết nối thành công');
END;
$$;

-- 6.4 List Active Device Sessions
CREATE OR REPLACE FUNCTION public.list_active_device_sessions_v4(p_store_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_sessions jsonb;
BEGIN
  IF NOT public.has_active_store_access_v4(p_store_id) THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Không có quyền truy cập cửa hàng');
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', id,
    'device_identifier', device_identifier,
    'device_name', device_name,
    'assigned_role', assigned_role,
    'paired_at', paired_at,
    'last_active_at', last_active_at,
    'is_active', is_active
  ))
  INTO v_sessions
  FROM public.pos_device_sessions
  WHERE store_id = p_store_id;

  RETURN jsonb_build_object('success', true, 'status', 200, 'sessions', COALESCE(v_sessions, '[]'::jsonb));
END;
$$;

-- 6.5 Revoke Device Session
CREATE OR REPLACE FUNCTION public.revoke_device_session_v4(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_store_id uuid;
  v_caller_role text;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 401, 'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực');
  END IF;

  SELECT store_id INTO v_store_id FROM public.pos_device_sessions WHERE id = p_session_id;
  IF v_store_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 404, 'error_code', 'NOT_FOUND', 'message', 'Không tìm thấy thiết bị');
  END IF;

  SELECT role INTO v_caller_role FROM public.store_members WHERE user_id = v_caller_id AND store_id = v_store_id;
  IF v_caller_role NOT IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Không có quyền');
  END IF;

  UPDATE public.pos_device_sessions SET is_active = false WHERE id = p_session_id;
  RETURN jsonb_build_object('success', true, 'status', 200, 'message', 'Ngắt kết nối thiết bị thành công');
END;
$$;

*/

-- ═════════════════════════════════════════════════════════════════════════════
-- 7. SERVER-SIDE STAFF MEMBERSHIP ADMINISTRATION (PHẦN C)
-- ═════════════════════════════════════════════════════════════════════════════

-- 7.1 Create Staff Member
CREATE OR REPLACE FUNCTION public.admin_create_staff_member_v4(
  p_store_id uuid,
  p_name text,
  p_phone text,
  p_role text,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_norm_phone text;
  v_user_id uuid;
  v_existing_staff uuid;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 401, 'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực');
  END IF;

  SELECT CASE WHEN is_owner THEN 'owner' ELSE role END
  INTO v_caller_role
  FROM public.store_members
  WHERE user_id = v_caller_id AND store_id = p_store_id;
  IF v_caller_role IS NULL THEN
    SELECT 'owner' INTO v_caller_role FROM public.stores WHERE id = p_store_id AND owner_user_id = v_caller_id;
  END IF;

  IF v_caller_role NOT IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Chỉ chủ quán hoặc quản lý mới có quyền thêm nhân viên');
  END IF;

  IF p_role NOT IN ('waiter', 'cashier', 'kitchen', 'stock', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'INVALID_ROLE', 'message', 'Vai trò nhân viên không hợp lệ');
  END IF;

  IF v_caller_role = 'manager' AND p_role IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Quản lý không có quyền tạo thêm Quản lý hoặc Chủ quán');
  END IF;

  v_norm_phone := public.normalize_phone_digits_v4(p_phone);
  IF length(v_norm_phone) < 8 THEN
    RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'INVALID_PHONE', 'message', 'Số điện thoại không hợp lệ');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(p_store_id::text || ':staff:' || v_norm_phone));

  SELECT id INTO v_user_id FROM public.user_accounts WHERE phone = v_norm_phone;
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 409,
      'error_code', 'ACCOUNT_NOT_REGISTERED',
      'message', 'Nhân viên phải đăng ký tài khoản trước khi được thêm vào quán'
    );
  END IF;

  SELECT store_id INTO v_existing_staff
  FROM public.staff_members
  WHERE id = v_user_id;
  IF v_existing_staff IS NOT NULL AND v_existing_staff <> p_store_id THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 409,
      'error_code', 'STAFF_SCHEMA_MULTI_STORE_BLOCKED',
      'message', 'Schema staff_members hiện tại chưa được chứng minh hỗ trợ một tài khoản ở nhiều quán'
    );
  END IF;

  -- Upsert staff_members
  INSERT INTO public.staff_members(id, store_id, name, phone, role, modules, is_active, updated_at)
  VALUES (v_user_id, p_store_id, trim(p_name), v_norm_phone, p_role, '[]'::jsonb, true, extract(epoch from now()) * 1000)
  ON CONFLICT (id) DO UPDATE
    SET name = excluded.name,
        role = excluded.role,
        is_active = true,
        updated_at = excluded.updated_at
    WHERE public.staff_members.store_id = p_store_id;

  -- Upsert store_members
  INSERT INTO public.store_members(user_id, store_id, role, is_owner, created_at)
  VALUES (v_user_id, p_store_id, p_role, false, now())
  ON CONFLICT (user_id, store_id) DO UPDATE
    SET role = excluded.role,
        is_owner = false;

  RETURN jsonb_build_object(
    'success', true, 'status', 200,
    'staff_id', v_user_id,
    'name', trim(p_name),
    'role', p_role,
    'store_id', p_store_id
  );
END;
$$;

-- 7.2 Update Staff Role
CREATE OR REPLACE FUNCTION public.admin_update_staff_role_v4(
  p_store_id uuid,
  p_staff_id uuid,
  p_new_role text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_target_role text;
  v_owner_count integer;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 401, 'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực');
  END IF;

  -- Cannot change own role
  IF v_caller_id = p_staff_id THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Không thể tự thay đổi vai trò của chính mình');
  END IF;

  SELECT CASE WHEN is_owner THEN 'owner' ELSE role END
  INTO v_caller_role
  FROM public.store_members
  WHERE user_id = v_caller_id AND store_id = p_store_id;
  IF v_caller_role IS NULL THEN
    SELECT 'owner' INTO v_caller_role FROM public.stores WHERE id = p_store_id AND owner_user_id = v_caller_id;
  END IF;

  IF v_caller_role NOT IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Không có quyền cập nhật nhân viên');
  END IF;

  IF p_new_role NOT IN ('waiter', 'cashier', 'kitchen', 'stock', 'manager', 'owner') THEN
    RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'INVALID_ROLE', 'message', 'Vai trò không hợp lệ');
  END IF;

  IF v_caller_role = 'manager' AND p_new_role IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Quản lý không được nâng quyền người khác thành Quản lý hoặc Chủ quán');
  END IF;

  -- Check if demoting last owner
  SELECT role INTO v_target_role FROM public.store_members WHERE user_id = p_staff_id AND store_id = p_store_id;
  IF v_target_role IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 404, 'error_code', 'STAFF_NOT_FOUND', 'message', 'Không tìm thấy nhân viên trong quán');
  END IF;
  IF v_caller_role = 'manager' AND v_target_role IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Quản lý không được sửa Chủ quán hoặc Quản lý khác');
  END IF;
  IF v_target_role = 'owner' AND p_new_role <> 'owner' THEN
    SELECT count(*) INTO v_owner_count FROM public.store_members WHERE store_id = p_store_id AND role = 'owner';
    IF v_owner_count <= 1 THEN
      RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'CANNOT_DEMOTE_LAST_OWNER', 'message', 'Không thể hạ quyền Chủ quán cuối cùng của cơ sở');
    END IF;
  END IF;

  UPDATE public.staff_members
  SET role = p_new_role, updated_at = extract(epoch from now()) * 1000
  WHERE id = p_staff_id AND store_id = p_store_id;

  UPDATE public.store_members
  SET role = p_new_role, is_owner = (p_new_role = 'owner')
  WHERE user_id = p_staff_id AND store_id = p_store_id;

  RETURN jsonb_build_object('success', true, 'status', 200, 'role', p_new_role);
END;
$$;

-- 7.3 Set Staff Status (Lock / Unlock)
CREATE OR REPLACE FUNCTION public.admin_set_staff_status_v4(
  p_store_id uuid,
  p_staff_id uuid,
  p_is_active boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_target_role text;
  v_owner_count integer;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 401, 'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực');
  END IF;

  IF v_caller_id = p_staff_id AND p_is_active = false THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Không thể tự khóa tài khoản của chính mình');
  END IF;

  SELECT CASE WHEN is_owner THEN 'owner' ELSE role END
  INTO v_caller_role
  FROM public.store_members
  WHERE user_id = v_caller_id AND store_id = p_store_id;
  IF v_caller_role NOT IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Không có quyền');
  END IF;

  IF p_is_active = false THEN
    SELECT role INTO v_target_role FROM public.store_members WHERE user_id = p_staff_id AND store_id = p_store_id;
    IF v_target_role IS NULL THEN
      RETURN jsonb_build_object('success', false, 'status', 404, 'error_code', 'STAFF_NOT_FOUND', 'message', 'Không tìm thấy nhân viên trong quán');
    END IF;
    IF v_caller_role = 'manager' AND v_target_role IN ('owner', 'manager') THEN
      RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Quản lý không được khóa Chủ quán hoặc Quản lý khác');
    END IF;
    IF v_target_role = 'owner' THEN
      SELECT count(*) INTO v_owner_count FROM public.store_members WHERE store_id = p_store_id AND role = 'owner';
      IF v_owner_count <= 1 THEN
        RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'CANNOT_LOCK_LAST_OWNER', 'message', 'Không thể khóa Chủ quán cuối cùng của cơ sở');
      END IF;
    END IF;
  END IF;

  UPDATE public.staff_members
  SET is_active = p_is_active, updated_at = extract(epoch from now()) * 1000
  WHERE id = p_staff_id AND store_id = p_store_id;

  RETURN jsonb_build_object('success', true, 'status', 200, 'is_active', p_is_active);
END;
$$;

-- 7.4 Revoke Staff Membership
CREATE OR REPLACE FUNCTION public.admin_revoke_staff_membership_v4(
  p_store_id uuid,
  p_staff_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_target_role text;
  v_owner_count integer;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 401, 'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực');
  END IF;

  IF v_caller_id = p_staff_id THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Không thể tự xóa quyền của chính mình');
  END IF;

  SELECT CASE WHEN is_owner THEN 'owner' ELSE role END
  INTO v_caller_role
  FROM public.store_members
  WHERE user_id = v_caller_id AND store_id = p_store_id;
  IF v_caller_role NOT IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Không có quyền');
  END IF;

  SELECT role INTO v_target_role FROM public.store_members WHERE user_id = p_staff_id AND store_id = p_store_id;
  IF v_target_role IS NULL THEN
    RETURN jsonb_build_object('success', true, 'status', 200, 'message', 'Nhân viên đã được thu hồi trước đó');
  END IF;
  IF v_caller_role = 'manager' AND v_target_role IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Quản lý không được xóa Chủ quán hoặc Quản lý khác');
  END IF;
  IF v_target_role = 'owner' THEN
    SELECT count(*) INTO v_owner_count FROM public.store_members WHERE store_id = p_store_id AND role = 'owner';
    IF v_owner_count <= 1 THEN
      RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'CANNOT_REMOVE_LAST_OWNER', 'message', 'Không thể xóa Chủ quán cuối cùng của cơ sở');
    END IF;
  END IF;

  DELETE FROM public.store_members WHERE user_id = p_staff_id AND store_id = p_store_id;
  UPDATE public.staff_members SET is_active = false WHERE id = p_staff_id AND store_id = p_store_id;

  RETURN jsonb_build_object('success', true, 'status', 200, 'message', 'Thu hồi quyền nhân viên thành công');
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- RLS POLICIES & GRANTS
-- ─────────────────────────────────────────────────────────────────────────────
/* Deferred until every active client is built with POS_JWT_AUTH_URL and the
   gateway health/login smoke tests pass. Applying this block earlier would
   lock currently deployed anonymous clients out of all store data. */
/*
DO $$
DECLARE
  v_policy record;
BEGIN
  FOR v_policy IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('user_accounts', 'store_members', 'staff_members')
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON %I.%I',
      v_policy.policyname, v_policy.schemaname, v_policy.tablename
    );
  END LOOP;
END $$;

ALTER TABLE public.user_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_accounts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.store_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_members FORCE ROW LEVEL SECURITY;
ALTER TABLE public.staff_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_members FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.user_accounts FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.store_members FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.staff_members FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  v_columns text;
BEGIN
  SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position)
  INTO v_columns
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'user_accounts'
    AND column_name NOT IN ('password_hash', 'quick_pin');
  EXECUTE 'GRANT SELECT (' || v_columns || ') ON public.user_accounts TO authenticated';

  SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position)
  INTO v_columns
  FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'staff_members'
    AND column_name NOT IN ('pin_hash');
  EXECUTE 'GRANT SELECT (' || v_columns || ') ON public.staff_members TO authenticated';
END $$;

GRANT SELECT ON public.store_members TO authenticated;
GRANT UPDATE (display_name) ON public.user_accounts TO authenticated;

CREATE POLICY user_accounts_self_select_v4 ON public.user_accounts
  FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY user_accounts_self_update_v4 ON public.user_accounts
  FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());
CREATE POLICY store_members_store_select_v4 ON public.store_members
  FOR SELECT TO authenticated USING (public.has_active_store_access_v4(store_id));
CREATE POLICY staff_members_store_select_v4 ON public.staff_members
  FOR SELECT TO authenticated USING (public.has_active_store_access_v4(store_id));

*/

REVOKE ALL ON FUNCTION public.normalize_phone_digits_v4(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.verify_password_hash_v4(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_onboarding_exchange_v4(text, bigint, uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_active_store_access_v4(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.verify_user_login_v4(text, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.register_user_account_v4(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.change_user_password_v4(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_user_quick_pin_v4(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.has_user_quick_pin_v4() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.verify_manager_quick_pin_v4(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_store_with_owner_v4(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.join_store_by_code_v4(text) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.admin_create_staff_member_v4(uuid, text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_staff_role_v4(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_staff_status_v4(uuid, uuid, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_revoke_staff_membership_v4(uuid, uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.verify_user_login_v4(text, text, uuid)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.consume_onboarding_exchange_v4(text, bigint, uuid, uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.register_user_account_v4(text, text, text)
  TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.change_user_password_v4(text, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_user_quick_pin_v4(text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_user_quick_pin_v4()
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_manager_quick_pin_v4(uuid, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_store_with_owner_v4(text, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_store_by_code_v4(text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_active_store_access_v4(uuid)
  TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.admin_create_staff_member_v4(uuid, text, text, text, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_staff_role_v4(uuid, uuid, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_staff_status_v4(uuid, uuid, boolean)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_revoke_staff_membership_v4(uuid, uuid)
  TO authenticated, service_role;

/* Full-hardening postflight; deferred with the table RLS/grant block above.
DO $$
BEGIN
  IF has_column_privilege('anon', 'public.user_accounts', 'password_hash', 'SELECT')
     OR has_column_privilege('authenticated', 'public.user_accounts', 'password_hash', 'SELECT') THEN
    RAISE EXCEPTION 'AUTH_POSTFLIGHT_FAILED: password_hash remains readable';
  END IF;
  IF has_column_privilege('anon', 'public.user_accounts', 'quick_pin', 'SELECT')
     OR has_column_privilege('authenticated', 'public.user_accounts', 'quick_pin', 'SELECT') THEN
    RAISE EXCEPTION 'AUTH_POSTFLIGHT_FAILED: quick_pin remains readable';
  END IF;
  IF has_table_privilege('anon', 'public.store_members', 'INSERT')
     OR has_table_privilege('anon', 'public.store_members', 'UPDATE')
     OR has_table_privilege('anon', 'public.store_members', 'DELETE') THEN
    RAISE EXCEPTION 'AUTH_POSTFLIGHT_FAILED: anon can still mutate memberships';
  END IF;
END $$;
*/

COMMIT;
