-- Migration 03: Internal Security Helpers, Auth & Management RPCs
-- File: supabase/migrations/20260814091500_qr_v3_03_permission_and_management_rpcs.sql

-- Preflight
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'hash_pos_credential_v3') THEN
    RAISE EXCEPTION 'MIGRATION_03_PREFLIGHT_FAIL: Function hash_pos_credential_v3 already exists';
  END IF;
END $$;

-- 1. Helper: hash_pos_credential_v3 (SQL IMMUTABLE STRICT)
CREATE OR REPLACE FUNCTION public.hash_pos_credential_v3(
  p_phone      text,
  p_credential text
) RETURNS text
LANGUAGE sql
IMMUTABLE STRICT
SET search_path = public, pg_temp
AS $$
  SELECT encode(
    digest(convert_to(p_phone || ':' || p_credential || ':qn_pos_2024_salt', 'UTF8'), 'sha256'),
    'hex'
  );
$$;
ALTER FUNCTION public.hash_pos_credential_v3(text, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.hash_pos_credential_v3(text, text) FROM PUBLIC, anon, authenticated;

-- 2. Helper: verify_pos_token_internal (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.verify_pos_token_internal(
  p_raw_token text
) RETURNS TABLE (
  session_id      uuid,
  store_id        uuid,
  device_id       uuid,
  staff_id        uuid,
  user_account_id uuid,
  principal_type  text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_hash bytea;
  v_rec  RECORD;
  v_dev_exists boolean;
  v_staff_active boolean;
  v_user_member boolean;
BEGIN
  IF p_raw_token IS NULL OR p_raw_token !~ '^[0-9a-f]{64}$' THEN
    RETURN;
  END IF;

  v_hash := digest(convert_to(p_raw_token, 'UTF8'), 'sha256');

  SELECT s.id, s.store_id, s.device_id, s.staff_id, s.user_account_id, s.expires_at, s.revoked_at, s.last_seen_at
  INTO v_rec
  FROM public.pos_device_sessions s
  WHERE s.token_hash = v_hash;

  IF v_rec.id IS NULL OR v_rec.revoked_at IS NOT NULL OR v_rec.expires_at <= now() THEN
    RETURN;
  END IF;

  -- Verify device still exists and belongs to same store
  SELECT EXISTS (
    SELECT 1 FROM public.devices WHERE id = v_rec.device_id AND store_id = v_rec.store_id
  ) INTO v_dev_exists;

  IF v_dev_exists IS NOT TRUE THEN
    RETURN;
  END IF;

  -- Verify principal is active / member
  IF v_rec.staff_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.staff_members WHERE id = v_rec.staff_id AND store_id = v_rec.store_id AND is_active = true
    ) INTO v_staff_active;

    IF v_staff_active IS NOT TRUE THEN
      RETURN;
    END IF;
  ELSIF v_rec.user_account_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.store_members WHERE user_id = v_rec.user_account_id AND store_id = v_rec.store_id
    ) INTO v_user_member;

    IF v_user_member IS NOT TRUE THEN
      RETURN;
    END IF;
  ELSE
    RETURN;
  END IF;

  -- Update last_seen_at with throttling (only if older than 1 minute)
  IF v_rec.last_seen_at < (now() - INTERVAL '1 minute') THEN
    UPDATE public.pos_device_sessions SET last_seen_at = now() WHERE id = v_rec.id;
  END IF;

  session_id := v_rec.id;
  store_id := v_rec.store_id;
  device_id := v_rec.device_id;
  staff_id := v_rec.staff_id;
  user_account_id := v_rec.user_account_id;
  principal_type := CASE WHEN v_rec.staff_id IS NOT NULL THEN 'staff' ELSE 'user_account' END;

  RETURN NEXT;
END;
$$;
ALTER FUNCTION public.verify_pos_token_internal(text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.verify_pos_token_internal(text) FROM PUBLIC, anon, authenticated;

-- 3. Helper: check_pos_staff_action_permission (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.check_pos_staff_action_permission(
  p_store_id        uuid,
  p_staff_id        uuid,
  p_user_account_id uuid,
  p_action_key      text
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role           text;
  v_is_owner       boolean := false;
  v_setting_val    text;
  v_perms_json     jsonb;
  v_canon_role     text;
BEGIN
  IF p_store_id IS NULL THEN
    RETURN false;
  END IF;

  -- Allowlist strict check for exact 8 QR action keys
  IF p_action_key NOT IN (
    'qr_order.view_pending', 'qr_order.claim', 'qr_order.reject', 'qr_order.confirm',
    'qr_order.send_kitchen', 'qr_order.manage_channels', 'qr_order.print_qr', 'qr_order.manage_settings'
  ) THEN
    RETURN false;
  END IF;

  -- Validate exactly one principal
  IF (p_staff_id IS NOT NULL AND p_user_account_id IS NOT NULL) OR (p_staff_id IS NULL AND p_user_account_id IS NULL) THEN
    RETURN false;
  END IF;

  -- Verify staff membership
  IF p_staff_id IS NOT NULL THEN
    SELECT role INTO v_role
    FROM public.staff_members
    WHERE id = p_staff_id AND store_id = p_store_id AND is_active = true;

    IF v_role IS NULL THEN
      RETURN false;
    END IF;
  ELSE
    SELECT role, is_owner INTO v_role, v_is_owner
    FROM public.store_members
    WHERE user_id = p_user_account_id AND store_id = p_store_id;

    IF v_role IS NULL THEN
      RETURN false;
    END IF;

    IF v_is_owner IS TRUE THEN
      RETURN true;
    END IF;
  END IF;

  -- Manager / Owner full access override
  IF LOWER(v_role) IN ('owner', 'manager', 'quản lý') THEN
    RETURN true;
  END IF;

  -- Read action_perms_{role} from app_settings
  SELECT value INTO v_setting_val
  FROM public.app_settings
  WHERE store_id = p_store_id AND key = 'action_perms_' || v_role;

  IF v_setting_val IS NULL THEN
    -- Try canonical role key fallback
    v_canon_role := CASE LOWER(v_role)
      WHEN 'thu ngân' THEN 'cashier'
      WHEN 'phục vụ' THEN 'waiter'
      WHEN 'bếp' THEN 'kitchen'
      WHEN 'quản lý' THEN 'manager'
      ELSE LOWER(v_role)
    END;

    SELECT value INTO v_setting_val
    FROM public.app_settings
    WHERE store_id = p_store_id AND key = 'action_perms_' || v_canon_role;
  END IF;

  IF v_setting_val IS NOT NULL THEN
    BEGIN
      v_perms_json := v_setting_val::jsonb;
      IF jsonb_typeof(v_perms_json) = 'array' THEN
        RETURN v_perms_json @> to_jsonb(p_action_key);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RETURN false;
    END;
  END IF;

  -- Non-manager roles fail-closed if setting missing
  RETURN false;
END;
$$;
ALTER FUNCTION public.check_pos_staff_action_permission(uuid, uuid, uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.check_pos_staff_action_permission(uuid, uuid, uuid, text) FROM PUBLIC, anon, authenticated;

-- 4. bootstrap_first_pos_device_v3 (Explicit Non-NULL Checks on Both Sides)
CREATE OR REPLACE FUNCTION public.bootstrap_first_pos_device_v3(
  p_store_code  text,
  p_credential  text,
  p_device_name text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_norm_code       text;
  v_store_id        uuid;
  v_ip              text;
  v_identifier_hash bytea;
  v_last_success_at timestamptz;
  v_failed_count    integer;
  v_rem_sec         integer;
  v_owner_rec       RECORD;
  v_matched_count   integer := 0;
  v_matched_user_id uuid := NULL;
  v_provided_hash   text;
  v_device_id       uuid;
  v_token_raw       text;
  v_token_hash      bytea;
  v_session_id      uuid;
  v_expires_at      timestamptz;
BEGIN
  -- Section 1: Non-NULL & Non-Empty Input Credential Gate
  IF p_credential IS NULL OR TRIM(p_credential) = '' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_CREDENTIALS', 'message', 'Mật khẩu xác thực không được để rỗng');
  END IF;

  IF p_store_code IS NULL OR TRIM(p_store_code) = '' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_STORE', 'message', 'Mã cửa hàng không hợp lệ');
  END IF;

  v_norm_code := UPPER(TRIM(p_store_code));
  SELECT id INTO v_store_id FROM public.stores WHERE store_code = v_norm_code;
  IF v_store_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_STORE', 'message', 'Cửa hàng không tồn tại');
  END IF;

  -- Lock store before checking bootstrap state
  PERFORM pg_advisory_xact_lock(hashtext(v_store_id::text || '_bootstrap'));

  IF EXISTS (SELECT 1 FROM public.pos_store_bootstrap_state WHERE store_id = v_store_id) THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'ALREADY_BOOTSTRAPPED', 'message', 'Cửa hàng đã được khởi tạo thiết bị đầu tiên');
  END IF;

  -- Rate limit check by store + IP
  v_identifier_hash := digest(convert_to(v_store_id::text || ':bootstrap', 'UTF8'), 'sha256');
  v_ip := TRIM(SPLIT_PART(COALESCE(current_setting('request.headers', true)::json ->> 'x-forwarded-for', '0.0.0.0'), ',', 1));

  -- Section 2: Single lookup for last_success_at
  SELECT MAX(created_at) INTO v_last_success_at
  FROM public.pos_auth_attempts
  WHERE store_id = v_store_id AND attempt_type = 'bootstrap' AND identifier_hash = v_identifier_hash AND ip_address = v_ip AND is_success = true;

  v_last_success_at := COALESCE(v_last_success_at, '1970-01-01'::timestamptz);

  SELECT COUNT(*) INTO v_failed_count
  FROM public.pos_auth_attempts
  WHERE store_id = v_store_id
    AND attempt_type = 'bootstrap'
    AND identifier_hash = v_identifier_hash
    AND ip_address = v_ip
    AND is_success = false
    AND created_at > (now() - INTERVAL '15 minutes')
    AND created_at > v_last_success_at;

  IF v_failed_count >= 5 THEN
    SELECT GREATEST(0, EXTRACT(EPOCH FROM (MIN(created_at) + INTERVAL '15 minutes' - now())))::integer INTO v_rem_sec
    FROM public.pos_auth_attempts
    WHERE store_id = v_store_id
      AND attempt_type = 'bootstrap'
      AND identifier_hash = v_identifier_hash
      AND ip_address = v_ip
      AND is_success = false
      AND created_at > (now() - INTERVAL '15 minutes')
      AND created_at > v_last_success_at;

    RETURN jsonb_build_object('success', false, 'data', jsonb_build_object('lockout_remaining_seconds', v_rem_sec), 'error_code', 'RATE_LIMITED', 'message', 'Khởi tạo thất bại quá nhiều lần. Vui lòng thử lại sau');
  END IF;

  -- Section 1: Explicit Non-NULL checks on phone & password_hash before comparison
  FOR v_owner_rec IN
    SELECT sm.user_id, u.phone, u.password_hash
    FROM public.store_members sm
    JOIN public.user_accounts u ON u.id = sm.user_id
    WHERE sm.store_id = v_store_id AND sm.is_owner = true
  LOOP
    IF v_owner_rec.phone IS NOT NULL AND TRIM(v_owner_rec.phone) <> '' AND
       v_owner_rec.password_hash IS NOT NULL AND TRIM(v_owner_rec.password_hash) <> '' THEN

      v_provided_hash := public.hash_pos_credential_v3(v_owner_rec.phone, p_credential);
      IF v_provided_hash IS NOT NULL AND TRIM(v_provided_hash) <> '' AND
         v_provided_hash IS NOT DISTINCT FROM v_owner_rec.password_hash THEN
        v_matched_count := v_matched_count + 1;
        v_matched_user_id := v_owner_rec.user_id;
      END IF;
    END IF;
  END LOOP;

  IF v_matched_count <> 1 OR v_matched_user_id IS NULL THEN
    INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, 'bootstrap', v_identifier_hash, false, v_ip);
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_CREDENTIALS', 'message', 'Mật khẩu chủ cửa hàng không đúng');
  END IF;

  -- Success auth log
  INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, 'bootstrap', v_identifier_hash, true, v_ip);

  -- Create device using exact production columns
  INSERT INTO public.devices(store_id, device_name, device_role, last_seen)
  VALUES (v_store_id, COALESCE(TRIM(p_device_name), 'Thiết bị POS chính'), 'manager', now())
  RETURNING id INTO v_device_id;

  INSERT INTO public.pos_store_bootstrap_state(store_id, bootstrapped_by, initial_device_id)
  VALUES (v_store_id, v_matched_user_id, v_device_id);

  -- Issue session
  v_token_raw := encode(gen_random_bytes(32), 'hex');
  v_token_hash := digest(convert_to(v_token_raw, 'UTF8'), 'sha256');
  v_expires_at := now() + INTERVAL '30 days';

  INSERT INTO public.pos_device_sessions(token_hash, device_id, store_id, user_account_id, expires_at)
  VALUES (v_token_hash, v_device_id, v_store_id, v_matched_user_id, v_expires_at)
  RETURNING id INTO v_session_id;

  INSERT INTO public.qr_audit_logs(store_id, actor_type, actor_user_account_id, action, payload)
  VALUES (v_store_id, 'staff', v_matched_user_id, 'bootstrap_device', jsonb_build_object('device_id', v_device_id));

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'session_token', v_token_raw,
      'expires_at', v_expires_at,
      'device_id', v_device_id
    ),
    'error_code', NULL,
    'message', NULL
  );
END;
$$;
ALTER FUNCTION public.bootstrap_first_pos_device_v3(text, text, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.bootstrap_first_pos_device_v3(text, text, text) FROM PUBLIC, anon, authenticated;

-- 5. issue_pos_device_session_v3 (Explicit Non-NULL Checks on Both Sides)
CREATE OR REPLACE FUNCTION public.issue_pos_device_session_v3(
  p_store_code   text,
  p_auth_mode    text,
  p_principal_id uuid,
  p_credential   text,
  p_device_id    uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_norm_code       text;
  v_store_id        uuid;
  v_dev_rec         RECORD;
  v_staff_rec       RECORD;
  v_user_rec        RECORD;
  v_ip              text;
  v_identifier_hash bytea;
  v_last_success_at timestamptz;
  v_failed_count    integer;
  v_rem_sec         integer;
  v_provided_hash   text;
  v_staff_id        uuid := NULL;
  v_user_account_id uuid := NULL;
  v_token_raw       text;
  v_token_hash      bytea;
  v_session_id      uuid;
  v_expires_at      timestamptz;
BEGIN
  -- Section 1: Non-NULL & Non-Empty Input Credential Gate
  IF p_credential IS NULL OR TRIM(p_credential) = '' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_CREDENTIALS', 'message', 'Mật khẩu/PIN xác thực không được để rỗng');
  END IF;

  IF p_auth_mode NOT IN ('staff_pin', 'manager_quick_pin', 'owner_password') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_AUTH_MODE', 'message', 'Chế độ xác thực không hỗ trợ');
  END IF;

  IF p_principal_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PRINCIPAL', 'message', 'Vui lòng cung cấp ID đối tượng xác thực');
  END IF;

  IF p_store_code IS NULL OR TRIM(p_store_code) = '' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_STORE', 'message', 'Mã cửa hàng không hợp lệ');
  END IF;

  v_norm_code := UPPER(TRIM(p_store_code));
  SELECT id INTO v_store_id FROM public.stores WHERE store_code = v_norm_code;
  IF v_store_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_STORE', 'message', 'Cửa hàng không tồn tại');
  END IF;

  -- Verify device exists and belongs to same store
  SELECT id, store_id INTO v_dev_rec FROM public.devices WHERE id = p_device_id AND store_id = v_store_id;
  IF v_dev_rec.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_DEVICE', 'message', 'Thiết bị không thuộc cửa hàng hiện tại');
  END IF;

  -- Rate limit check
  v_identifier_hash := digest(convert_to(p_principal_id::text, 'UTF8'), 'sha256');
  v_ip := TRIM(SPLIT_PART(COALESCE(current_setting('request.headers', true)::json ->> 'x-forwarded-for', '0.0.0.0'), ',', 1));

  PERFORM pg_advisory_xact_lock(hashtext(v_store_id::text || '_' || p_auth_mode || '_' || v_identifier_hash::text));

  -- Section 2: Single lookup for last_success_at
  SELECT MAX(created_at) INTO v_last_success_at
  FROM public.pos_auth_attempts
  WHERE store_id = v_store_id AND attempt_type = p_auth_mode AND identifier_hash = v_identifier_hash AND ip_address = v_ip AND is_success = true;

  v_last_success_at := COALESCE(v_last_success_at, '1970-01-01'::timestamptz);

  SELECT COUNT(*) INTO v_failed_count
  FROM public.pos_auth_attempts
  WHERE store_id = v_store_id
    AND attempt_type = p_auth_mode
    AND identifier_hash = v_identifier_hash
    AND ip_address = v_ip
    AND is_success = false
    AND created_at > (now() - INTERVAL '15 minutes')
    AND created_at > v_last_success_at;

  IF v_failed_count >= 5 THEN
    SELECT GREATEST(0, EXTRACT(EPOCH FROM (MIN(created_at) + INTERVAL '15 minutes' - now())))::integer INTO v_rem_sec
    FROM public.pos_auth_attempts
    WHERE store_id = v_store_id
      AND attempt_type = p_auth_mode
      AND identifier_hash = v_identifier_hash
      AND ip_address = v_ip
      AND is_success = false
      AND created_at > (now() - INTERVAL '15 minutes')
      AND created_at > v_last_success_at;

    RETURN jsonb_build_object('success', false, 'data', jsonb_build_object('lockout_remaining_seconds', v_rem_sec), 'error_code', 'RATE_LIMITED', 'message', 'Xác thực thất bại quá nhiều lần. Vui lòng thử lại sau');
  END IF;

  -- Section 1: Auth mode check with strict NULL/empty checks on stored credentials before comparison
  IF p_auth_mode = 'staff_pin' THEN
    SELECT id, pin_hash, is_active INTO v_staff_rec
    FROM public.staff_members
    WHERE id = p_principal_id AND store_id = v_store_id;

    IF v_staff_rec.id IS NULL THEN
      INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, p_auth_mode, v_identifier_hash, false, v_ip);
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PRINCIPAL', 'message', 'Nhân viên không tồn tại trong cửa hàng');
    END IF;
    IF v_staff_rec.is_active IS NOT TRUE THEN
      INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, p_auth_mode, v_identifier_hash, false, v_ip);
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PRINCIPAL_INACTIVE', 'message', 'Tài khoản nhân viên đã bị khóa');
    END IF;

    IF v_staff_rec.pin_hash IS NULL OR TRIM(v_staff_rec.pin_hash) = '' THEN
      INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, p_auth_mode, v_identifier_hash, false, v_ip);
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_CREDENTIALS', 'message', 'Tài khoản nhân viên chưa khởi tạo mã PIN');
    END IF;

    v_provided_hash := encode(digest(convert_to(p_credential, 'UTF8'), 'sha256'), 'hex');
    IF v_provided_hash IS NULL OR TRIM(v_provided_hash) = '' OR v_provided_hash IS DISTINCT FROM v_staff_rec.pin_hash THEN
      INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, p_auth_mode, v_identifier_hash, false, v_ip);
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_CREDENTIALS', 'message', 'Mã PIN nhân viên không đúng');
    END IF;

    v_staff_id := v_staff_rec.id;

  ELSIF p_auth_mode IN ('manager_quick_pin', 'owner_password') THEN
    SELECT u.id, u.phone, u.quick_pin, u.password_hash, sm.is_owner, sm.role
    INTO v_user_rec
    FROM public.user_accounts u
    JOIN public.store_members sm ON sm.user_id = u.id
    WHERE u.id = p_principal_id AND sm.store_id = v_store_id;

    IF v_user_rec.id IS NULL THEN
      INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, p_auth_mode, v_identifier_hash, false, v_ip);
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PRINCIPAL', 'message', 'Tài khoản người dùng không thuộc cửa hàng');
    END IF;

    IF v_user_rec.phone IS NULL OR TRIM(v_user_rec.phone) = '' THEN
      INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, p_auth_mode, v_identifier_hash, false, v_ip);
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_CREDENTIALS', 'message', 'Tài khoản chưa đăng ký số điện thoại hợp lệ');
    END IF;

    IF p_auth_mode = 'manager_quick_pin' THEN
      IF v_user_rec.is_owner IS NOT TRUE AND LOWER(v_user_rec.role) NOT IN ('owner', 'manager', 'quản lý') THEN
        INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, p_auth_mode, v_identifier_hash, false, v_ip);
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PRINCIPAL', 'message', 'Tài khoản không có quyền Quản Lý');
      END IF;

      IF v_user_rec.quick_pin IS NULL OR TRIM(v_user_rec.quick_pin) = '' THEN
        INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, p_auth_mode, v_identifier_hash, false, v_ip);
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_CREDENTIALS', 'message', 'Tài khoản chưa khởi tạo Quick PIN');
      END IF;

      v_provided_hash := public.hash_pos_credential_v3(v_user_rec.phone, p_credential);
      IF v_provided_hash IS NULL OR TRIM(v_provided_hash) = '' OR v_provided_hash IS DISTINCT FROM v_user_rec.quick_pin THEN
        INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, p_auth_mode, v_identifier_hash, false, v_ip);
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_CREDENTIALS', 'message', 'Mã Quick PIN không đúng');
      END IF;

    ELSE -- owner_password
      IF v_user_rec.is_owner IS NOT TRUE THEN
        INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, p_auth_mode, v_identifier_hash, false, v_ip);
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PRINCIPAL', 'message', 'Tài khoản không có quyền Chủ Cửa Hàng');
      END IF;

      IF v_user_rec.password_hash IS NULL OR TRIM(v_user_rec.password_hash) = '' THEN
        INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, p_auth_mode, v_identifier_hash, false, v_ip);
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_CREDENTIALS', 'message', 'Tài khoản chưa khởi tạo mật khẩu');
      END IF;

      v_provided_hash := public.hash_pos_credential_v3(v_user_rec.phone, p_credential);
      IF v_provided_hash IS NULL OR TRIM(v_provided_hash) = '' OR v_provided_hash IS DISTINCT FROM v_user_rec.password_hash THEN
        INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, p_auth_mode, v_identifier_hash, false, v_ip);
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_CREDENTIALS', 'message', 'Mật khẩu tài khoản không đúng');
      END IF;
    END IF;

    v_user_account_id := v_user_rec.id;
  END IF;

  -- Success auth log
  INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, p_auth_mode, v_identifier_hash, true, v_ip);

  -- Revoke existing active session for device
  UPDATE public.pos_device_sessions SET revoked_at = now() WHERE store_id = v_store_id AND device_id = p_device_id AND revoked_at IS NULL;

  -- Issue session
  v_token_raw := encode(gen_random_bytes(32), 'hex');
  v_token_hash := digest(convert_to(v_token_raw, 'UTF8'), 'sha256');
  v_expires_at := now() + INTERVAL '30 days';

  INSERT INTO public.pos_device_sessions(token_hash, device_id, store_id, staff_id, user_account_id, expires_at)
  VALUES (v_token_hash, p_device_id, v_store_id, v_staff_id, v_user_account_id, v_expires_at)
  RETURNING id INTO v_session_id;

  INSERT INTO public.qr_audit_logs(store_id, actor_type, actor_staff_id, actor_user_account_id, action, payload)
  VALUES (v_store_id, 'staff', v_staff_id, v_user_account_id, 'issue_session', jsonb_build_object('device_id', p_device_id, 'auth_mode', p_auth_mode));

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'session_token', v_token_raw,
      'expires_at', v_expires_at,
      'principal_type', CASE WHEN v_staff_id IS NOT NULL THEN 'staff' ELSE 'user_account' END,
      'staff_id', v_staff_id,
      'user_account_id', v_user_account_id
    ),
    'error_code', NULL,
    'message', NULL
  );
END;
$$;
ALTER FUNCTION public.issue_pos_device_session_v3(text, text, uuid, text, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.issue_pos_device_session_v3(text, text, uuid, text, uuid) FROM PUBLIC, anon, authenticated;

-- 6. generate_pos_pairing_code_v3 (Collision Retry Guard Across ALL Rows)
CREATE OR REPLACE FUNCTION public.generate_pos_pairing_code_v3(
  p_raw_token   text,
  p_device_role text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess        RECORD;
  v_bytes       bytea;
  v_code_raw    text;
  v_code_hash   bytea;
  v_expires_at  timestamptz;
  v_retry       integer := 0;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.manage_settings') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền tạo mã ghép nối');
  END IF;

  IF COALESCE(p_device_role, 'staff') NOT IN ('staff', 'kds', 'cashier', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_DEVICE_ROLE', 'message', 'Vai trò thiết bị không hợp lệ');
  END IF;

  -- Generate 6-digit numeric string with collision check across ALL store_pairing_codes rows
  LOOP
    v_bytes := gen_random_bytes(3);
    v_code_raw := LPAD(((get_byte(v_bytes, 0) * 65536 + get_byte(v_bytes, 1) * 256 + get_byte(v_bytes, 2)) % 900000 + 100000)::text, 6, '0');
    v_code_hash := digest(convert_to(v_code_raw, 'UTF8'), 'sha256');

    v_expires_at := now() + INTERVAL '5 minutes';

    BEGIN
      INSERT INTO public.store_pairing_codes(store_id, pairing_code_hash, device_role, created_by_user, created_by_staff, expires_at)
      VALUES (v_sess.store_id, v_code_hash, COALESCE(p_device_role, 'staff'), v_sess.user_account_id, v_sess.staff_id, v_expires_at);

      EXIT; -- Success insert
    EXCEPTION WHEN unique_violation THEN
      v_retry := v_retry + 1;
      IF v_retry >= 5 THEN
        RAISE EXCEPTION 'MIGRATION_03_ERROR: Pairing code generation hit max retries';
      END IF;
    END;
  END LOOP;

  INSERT INTO public.qr_audit_logs(store_id, actor_type, actor_staff_id, actor_user_account_id, action, payload)
  VALUES (v_sess.store_id, 'staff', v_sess.staff_id, v_sess.user_account_id, 'generate_pairing_code', jsonb_build_object('device_role', p_device_role));

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'pairing_code', v_code_raw,
      'expires_at', v_expires_at
    ),
    'error_code', NULL,
    'message', NULL
  );
END;
$$;
ALTER FUNCTION public.generate_pos_pairing_code_v3(text, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.generate_pos_pairing_code_v3(text, text) FROM PUBLIC, anon, authenticated;

-- 7. pair_pos_device_v3 (Advisory Lock & Single Success Window Calculation)
CREATE OR REPLACE FUNCTION public.pair_pos_device_v3(
  p_store_code   text,
  p_pairing_code text,
  p_device_name  text,
  p_device_role  text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_norm_code       text;
  v_store_id        uuid;
  v_ip              text;
  v_identifier_hash bytea;
  v_last_success_at timestamptz;
  v_failed_count    integer;
  v_rem_sec         integer;
  v_code_hash       bytea;
  v_pair_rec        RECORD;
  v_device_id       uuid;
BEGIN
  IF p_pairing_code IS NULL OR TRIM(p_pairing_code) = '' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PAIRING_CODE', 'message', 'Mã ghép nối không được để rỗng');
  END IF;

  IF p_store_code IS NULL OR TRIM(p_store_code) = '' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_STORE', 'message', 'Mã cửa hàng không hợp lệ');
  END IF;

  v_norm_code := UPPER(TRIM(p_store_code));
  SELECT id INTO v_store_id FROM public.stores WHERE store_code = v_norm_code;
  IF v_store_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_STORE', 'message', 'Cửa hàng không tồn tại');
  END IF;

  -- Rate limit by store + IP
  v_identifier_hash := digest(convert_to(v_store_id::text || ':pairing_code', 'UTF8'), 'sha256');
  v_ip := TRIM(SPLIT_PART(COALESCE(current_setting('request.headers', true)::json ->> 'x-forwarded-for', '0.0.0.0'), ',', 1));

  PERFORM pg_advisory_xact_lock(hashtext(v_store_id::text || '_pairing_code_' || v_ip));

  -- Section 2: Single lookup for last_success_at
  SELECT MAX(created_at) INTO v_last_success_at
  FROM public.pos_auth_attempts
  WHERE store_id = v_store_id AND attempt_type = 'pairing_code' AND identifier_hash = v_identifier_hash AND ip_address = v_ip AND is_success = true;

  v_last_success_at := COALESCE(v_last_success_at, '1970-01-01'::timestamptz);

  SELECT COUNT(*) INTO v_failed_count
  FROM public.pos_auth_attempts
  WHERE store_id = v_store_id
    AND attempt_type = 'pairing_code'
    AND identifier_hash = v_identifier_hash
    AND ip_address = v_ip
    AND is_success = false
    AND created_at > (now() - INTERVAL '15 minutes')
    AND created_at > v_last_success_at;

  IF v_failed_count >= 5 THEN
    SELECT GREATEST(0, EXTRACT(EPOCH FROM (MIN(created_at) + INTERVAL '15 minutes' - now())))::integer INTO v_rem_sec
    FROM public.pos_auth_attempts
    WHERE store_id = v_store_id
      AND attempt_type = 'pairing_code'
      AND identifier_hash = v_identifier_hash
      AND ip_address = v_ip
      AND is_success = false
      AND created_at > (now() - INTERVAL '15 minutes')
      AND created_at > v_last_success_at;

    RETURN jsonb_build_object('success', false, 'data', jsonb_build_object('lockout_remaining_seconds', v_rem_sec), 'error_code', 'RATE_LIMITED', 'message', 'Ghép nối thất bại quá nhiều lần. Vui lòng thử lại sau');
  END IF;

  v_code_hash := digest(convert_to(p_pairing_code, 'UTF8'), 'sha256');

  -- Lock pairing code row FOR UPDATE
  SELECT * INTO v_pair_rec
  FROM public.store_pairing_codes
  WHERE store_id = v_store_id AND pairing_code_hash = v_code_hash
  FOR UPDATE;

  IF v_pair_rec.id IS NULL OR v_pair_rec.used_at IS NOT NULL THEN
    INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, 'pairing_code', v_identifier_hash, false, v_ip);
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PAIRING_CODE', 'message', 'Mã ghép nối không hợp lệ hoặc đã sử dụng');
  END IF;

  IF v_pair_rec.expires_at <= now() THEN
    INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, 'pairing_code', v_identifier_hash, false, v_ip);
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PAIRING_CODE_EXPIRED', 'message', 'Mã ghép nối đã hết hạn');
  END IF;

  -- Validate client requested device_role matches stored pairing role
  IF p_device_role IS NOT NULL AND p_device_role <> v_pair_rec.device_role THEN
    INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, 'pairing_code', v_identifier_hash, false, v_ip);
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'ROLE_MISMATCH', 'message', 'Vai trò thiết bị yêu cầu không khớp với mã ghép nối');
  END IF;

  -- Consume pairing code atomically
  UPDATE public.store_pairing_codes
  SET used_at = now()
  WHERE id = v_pair_rec.id AND used_at IS NULL AND expires_at > now();

  IF NOT FOUND THEN
    INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, 'pairing_code', v_identifier_hash, false, v_ip);
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PAIRING_CODE', 'message', 'Mã ghép nối đã bị sử dụng bởi thiết bị khác');
  END IF;

  -- Success auth log
  INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address) VALUES (v_store_id, 'pairing_code', v_identifier_hash, true, v_ip);

  -- Create device using exact production columns
  INSERT INTO public.devices(store_id, device_name, device_role, last_seen)
  VALUES (v_store_id, COALESCE(TRIM(p_device_name), 'Thiết bị POS'), v_pair_rec.device_role, now())
  RETURNING id INTO v_device_id;

  INSERT INTO public.qr_audit_logs(store_id, actor_type, actor_staff_id, actor_user_account_id, action, payload)
  VALUES (v_store_id, 'staff', v_pair_rec.created_by_staff, v_pair_rec.created_by_user, 'pair_device', jsonb_build_object('device_id', v_device_id, 'device_role', v_pair_rec.device_role));

  -- Returns paired device_id & role ONLY
  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'device_id', v_device_id,
      'device_role', v_pair_rec.device_role
    ),
    'error_code', NULL,
    'message', NULL
  );
END;
$$;
ALTER FUNCTION public.pair_pos_device_v3(text, text, text, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.pair_pos_device_v3(text, text, text, text) FROM PUBLIC, anon, authenticated;

-- 8. revoke_pos_device_session_v3 (Self Revoke)
CREATE OR REPLACE FUNCTION public.revoke_pos_device_session_v3(
  p_raw_token text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess RECORD;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  UPDATE public.pos_device_sessions SET revoked_at = now() WHERE id = v_sess.session_id;

  INSERT INTO public.qr_audit_logs(store_id, actor_type, actor_staff_id, actor_user_account_id, action, payload)
  VALUES (v_sess.store_id, 'staff', v_sess.staff_id, v_sess.user_account_id, 'self_revoke_session', jsonb_build_object('session_id', v_sess.session_id));

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('revoked', true), 'error_code', NULL, 'message', NULL);
END;
$$;
ALTER FUNCTION public.revoke_pos_device_session_v3(text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.revoke_pos_device_session_v3(text) FROM PUBLIC, anon, authenticated;

-- 9. admin_revoke_device_session_v3 (Admin Revoke)
CREATE OR REPLACE FUNCTION public.admin_revoke_device_session_v3(
  p_raw_token         text,
  p_target_session_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess       RECORD;
  v_target_sid uuid;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.manage_settings') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền quản lý thiết bị');
  END IF;

  SELECT store_id INTO v_target_sid FROM public.pos_device_sessions WHERE id = p_target_session_id;
  IF v_target_sid IS NULL OR v_target_sid <> v_sess.store_id THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'CROSS_STORE_DENIED', 'message', 'Không thể thu hồi phiên thiết bị thuộc cửa hàng khác');
  END IF;

  UPDATE public.pos_device_sessions SET revoked_at = now() WHERE id = p_target_session_id;

  INSERT INTO public.qr_audit_logs(store_id, actor_type, actor_staff_id, actor_user_account_id, action, payload)
  VALUES (v_sess.store_id, 'staff', v_sess.staff_id, v_sess.user_account_id, 'admin_revoke_session', jsonb_build_object('target_session_id', p_target_session_id));

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('revoked', true, 'target_session_id', p_target_session_id), 'error_code', NULL, 'message', NULL);
END;
$$;
ALTER FUNCTION public.admin_revoke_device_session_v3(text, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.admin_revoke_device_session_v3(text, uuid) FROM PUBLIC, anon, authenticated;

-- 10. list_pos_device_sessions_v3
CREATE OR REPLACE FUNCTION public.list_pos_device_sessions_v3(
  p_raw_token text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess RECORD;
  v_list jsonb;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.manage_settings') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền xem danh sách thiết bị');
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'session_id', s.id,
    'device_id', s.device_id,
    'device_name', COALESCE(d.device_name, 'Thiết bị POS'),
    'principal_type', CASE WHEN s.staff_id IS NOT NULL THEN 'staff' ELSE 'user_account' END,
    'staff_id', s.staff_id,
    'user_account_id', s.user_account_id,
    'expires_at', s.expires_at,
    'revoked_at', s.revoked_at,
    'last_seen_at', s.last_seen_at
  )) INTO v_list
  FROM public.pos_device_sessions s
  LEFT JOIN public.devices d ON d.id = s.device_id
  WHERE s.store_id = v_sess.store_id;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('sessions', COALESCE(v_list, '[]'::jsonb)), 'error_code', NULL, 'message', NULL);
END;
$$;
ALTER FUNCTION public.list_pos_device_sessions_v3(text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.list_pos_device_sessions_v3(text) FROM PUBLIC, anon, authenticated;

-- 11. list_qr_channels_v3
CREATE OR REPLACE FUNCTION public.list_qr_channels_v3(
  p_raw_token text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess RECORD;
  v_list jsonb;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.manage_channels') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền xem danh sách QR channel');
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'channel_id', c.id,
    'type', c.type,
    'channel_code', c.channel_code,
    'name', c.name,
    'table_id', c.table_id,
    'is_active', c.is_active,
    'created_at', c.created_at
  )) INTO v_list
  FROM public.qr_channels c
  WHERE c.store_id = v_sess.store_id;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('channels', COALESCE(v_list, '[]'::jsonb)), 'error_code', NULL, 'message', NULL);
END;
$$;
ALTER FUNCTION public.list_qr_channels_v3(text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.list_qr_channels_v3(text) FROM PUBLIC, anon, authenticated;

-- 12. upsert_qr_channel_v3
CREATE OR REPLACE FUNCTION public.upsert_qr_channel_v3(
  p_raw_token text,
  p_type      text,
  p_table_id  text,
  p_name      text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess      RECORD;
  v_tbl_rec   RECORD;
  v_chan_rec  RECORD;
  v_code      text;
  v_chan_id   uuid;
  v_name      text;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.manage_channels') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền quản lý kênh QR');
  END IF;

  IF p_type NOT IN ('table', 'counter') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_CHANNEL_TYPE', 'message', 'Loại kênh QR không hợp lệ');
  END IF;

  IF p_type = 'counter' AND p_table_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'COUNTER_TABLE_MUST_BE_NULL', 'message', 'Kênh quầy thu ngân không được gán table_id');
  END IF;

  IF p_type = 'table' THEN
    IF p_table_id IS NULL OR TRIM(p_table_id) = '' THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'TABLE_ID_REQUIRED', 'message', 'Kênh bàn ăn phải chọn bàn hợp lệ');
    END IF;

    SELECT id, name INTO v_tbl_rec FROM public.ban_dining_tables WHERE id = p_table_id AND store_id = v_sess.store_id;
    IF v_tbl_rec.id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'TABLE_NOT_FOUND', 'message', 'Bàn ăn không tồn tại hoặc thuộc cửa hàng khác');
    END IF;
  END IF;

  v_name := TRIM(COALESCE(p_name, CASE WHEN p_type = 'table' THEN v_tbl_rec.name ELSE 'Quầy Thu Ngân' END));
  IF length(v_name) NOT BETWEEN 1 AND 100 THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_NAME', 'message', 'Tên kênh QR phải từ 1 đến 100 ký tự');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(v_sess.store_id::text || '_upsert_channel_' || COALESCE(p_table_id, 'counter')));

  -- Return existing active channel if available
  IF p_type = 'table' THEN
    SELECT * INTO v_chan_rec FROM public.qr_channels WHERE store_id = v_sess.store_id AND table_id = p_table_id AND type = 'table' AND is_active = true LIMIT 1;
  ELSE
    SELECT * INTO v_chan_rec FROM public.qr_channels WHERE store_id = v_sess.store_id AND type = 'counter' AND is_active = true LIMIT 1;
  END IF;

  IF v_chan_rec.id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('channel_id', v_chan_rec.id, 'channel_code', v_chan_rec.channel_code, 'type', v_chan_rec.type, 'name', v_chan_rec.name), 'error_code', NULL, 'message', NULL);
  END IF;

  -- Insert new channel
  v_code := (CASE WHEN p_type = 'table' THEN 'tbl_' ELSE 'ctr_' END) || encode(gen_random_bytes(16), 'hex');

  INSERT INTO public.qr_channels(store_id, type, table_id, channel_code, name, is_active)
  VALUES (v_sess.store_id, p_type, CASE WHEN p_type = 'table' THEN p_table_id ELSE NULL END, v_code, v_name, true)
  RETURNING id INTO v_chan_id;

  INSERT INTO public.qr_audit_logs(store_id, actor_type, actor_staff_id, actor_user_account_id, action, payload)
  VALUES (v_sess.store_id, 'staff', v_sess.staff_id, v_sess.user_account_id, 'create_channel', jsonb_build_object('channel_id', v_chan_id, 'type', p_type));

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('channel_id', v_chan_id, 'channel_code', v_code, 'type', p_type, 'name', v_name), 'error_code', NULL, 'message', NULL);
END;
$$;
ALTER FUNCTION public.upsert_qr_channel_v3(text, text, text, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.upsert_qr_channel_v3(text, text, text, text) FROM PUBLIC, anon, authenticated;

-- 13. rotate_qr_channel_v3
CREATE OR REPLACE FUNCTION public.rotate_qr_channel_v3(
  p_raw_token  text,
  p_channel_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess      RECORD;
  v_old_rec   RECORD;
  v_new_code  text;
  v_new_id    uuid;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.manage_channels') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền xoay mã QR');
  END IF;

  SELECT * INTO v_old_rec FROM public.qr_channels WHERE id = p_channel_id AND store_id = v_sess.store_id FOR UPDATE;
  IF v_old_rec.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'CHANNEL_NOT_FOUND', 'message', 'Kênh QR không tồn tại');
  END IF;

  -- Deactivate old channel
  UPDATE public.qr_channels SET is_active = false WHERE id = v_old_rec.id;

  -- Create new channel code
  v_new_code := (CASE WHEN v_old_rec.type = 'table' THEN 'tbl_' ELSE 'ctr_' END) || encode(gen_random_bytes(16), 'hex');

  INSERT INTO public.qr_channels(store_id, type, table_id, channel_code, name, is_active)
  VALUES (v_sess.store_id, v_old_rec.type, v_old_rec.table_id, v_new_code, v_old_rec.name, true)
  RETURNING id INTO v_new_id;

  INSERT INTO public.qr_audit_logs(store_id, actor_type, actor_staff_id, actor_user_account_id, action, payload)
  VALUES (v_sess.store_id, 'staff', v_sess.staff_id, v_sess.user_account_id, 'rotate_channel', jsonb_build_object('old_channel_id', v_old_rec.id, 'new_channel_id', v_new_id));

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('new_channel_id', v_new_id, 'new_channel_code', v_new_code, 'old_channel_id', v_old_rec.id), 'error_code', NULL, 'message', NULL);
END;
$$;
ALTER FUNCTION public.rotate_qr_channel_v3(text, uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rotate_qr_channel_v3(text, uuid) FROM PUBLIC, anon, authenticated;

-- 14. set_qr_channel_active_v3
CREATE OR REPLACE FUNCTION public.set_qr_channel_active_v3(
  p_raw_token  text,
  p_channel_id uuid,
  p_is_active  boolean
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess RECORD;
  v_rec  RECORD;
  v_active_exists boolean;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.manage_channels') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền thay đổi trạng thái kênh QR');
  END IF;

  SELECT * INTO v_rec FROM public.qr_channels WHERE id = p_channel_id AND store_id = v_sess.store_id FOR UPDATE;
  IF v_rec.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'CHANNEL_NOT_FOUND', 'message', 'Kênh QR không tồn tại');
  END IF;

  IF p_is_active IS TRUE AND v_rec.is_active IS NOT TRUE THEN
    -- Check if another active channel exists for table/counter
    IF v_rec.type = 'table' THEN
      SELECT EXISTS (
        SELECT 1 FROM public.qr_channels WHERE store_id = v_sess.store_id AND table_id = v_rec.table_id AND type = 'table' AND is_active = true AND id <> v_rec.id
      ) INTO v_active_exists;
    ELSE
      SELECT EXISTS (
        SELECT 1 FROM public.qr_channels WHERE store_id = v_sess.store_id AND type = 'counter' AND is_active = true AND id <> v_rec.id
      ) INTO v_active_exists;
    END IF;

    IF v_active_exists THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'CHANNEL_ACTIVE_CONFLICT', 'message', 'Đã có kênh QR khác đang hoạt động cho bàn/quầy này');
    END IF;
  END IF;

  UPDATE public.qr_channels SET is_active = p_is_active WHERE id = p_channel_id;

  INSERT INTO public.qr_audit_logs(store_id, actor_type, actor_staff_id, actor_user_account_id, action, payload)
  VALUES (v_sess.store_id, p_channel_id, 'staff', v_sess.staff_id, v_sess.user_account_id, CASE WHEN p_is_active THEN 'activate_channel' ELSE 'disable_channel' END, jsonb_build_object('channel_id', p_channel_id, 'is_active', p_is_active));

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('channel_id', p_channel_id, 'is_active', p_is_active), 'error_code', NULL, 'message', NULL);
END;
$$;
ALTER FUNCTION public.set_qr_channel_active_v3(text, uuid, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.set_qr_channel_active_v3(text, uuid, boolean) FROM PUBLIC, anon, authenticated;

-- 15. get_qr_settings_v3 (Section 4 Fail-Closed Verification)
CREATE OR REPLACE FUNCTION public.get_qr_settings_v3(
  p_raw_token text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess RECORD;
  v_val  text;
  v_json jsonb;
  v_key  text;
  v_domain text;
  v_canon_json jsonb;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.manage_settings') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền xem cài đặt QR');
  END IF;

  SELECT value INTO v_val FROM public.app_settings WHERE store_id = v_sess.store_id AND key = 'qr_order_settings';

  IF v_val IS NOT NULL THEN
    BEGIN
      v_json := v_val::jsonb;

      IF jsonb_typeof(v_json) <> 'object' THEN
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Dữ liệu cài đặt QR bị lỗi định dạng không phải đối tượng JSON');
      END IF;

      -- Validate unknown keys or wrong types in stored row
      FOR v_key IN SELECT jsonb_object_keys(v_json) LOOP
        IF v_key NOT IN ('is_table_enabled', 'is_counter_enabled', 'auto_claim', 'sound_enabled', 'public_domain') THEN
          RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Dữ liệu cài đặt lưu trữ chứa thuộc tính không hợp lệ: ' || v_key);
        END IF;
      END LOOP;

      IF (v_json ? 'is_table_enabled' AND jsonb_typeof(v_json -> 'is_table_enabled') <> 'boolean') OR
         (v_json ? 'is_counter_enabled' AND jsonb_typeof(v_json -> 'is_counter_enabled') <> 'boolean') OR
         (v_json ? 'auto_claim' AND jsonb_typeof(v_json -> 'auto_claim') <> 'boolean') OR
         (v_json ? 'sound_enabled' AND jsonb_typeof(v_json -> 'sound_enabled') <> 'boolean') OR
         (v_json ? 'public_domain' AND jsonb_typeof(v_json -> 'public_domain') <> 'string') THEN
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Dữ liệu cài đặt lưu trữ có kiểu dữ liệu thuộc tính không hợp lệ');
      END IF;

      v_domain := TRIM(COALESCE(v_json ->> 'public_domain', ''));
      IF length(v_domain) > 255 OR (v_domain <> '' AND v_domain !~ '^https://[a-zA-Z0-9.-]+(:[0-9]+)?$') THEN
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Dữ liệu tên miền lưu trữ không hợp lệ');
      END IF;

      -- Merge partial JSON with exact 5 canonical defaults
      v_canon_json := jsonb_build_object(
        'is_table_enabled', COALESCE((v_json ->> 'is_table_enabled')::boolean, false),
        'is_counter_enabled', COALESCE((v_json ->> 'is_counter_enabled')::boolean, false),
        'auto_claim', COALESCE((v_json ->> 'auto_claim')::boolean, false),
        'sound_enabled', COALESCE((v_json ->> 'sound_enabled')::boolean, true),
        'public_domain', v_domain
      );

    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Dữ liệu cài đặt QR bị lỗi định dạng');
    END;
  ELSE
    v_canon_json := jsonb_build_object(
      'is_table_enabled', false,
      'is_counter_enabled', false,
      'auto_claim', false,
      'sound_enabled', true,
      'public_domain', ''
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('settings', v_canon_json), 'error_code', NULL, 'message', NULL);
END;
$$;
ALTER FUNCTION public.get_qr_settings_v3(text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_qr_settings_v3(text) FROM PUBLIC, anon, authenticated;

-- 16. save_qr_settings_v3
CREATE OR REPLACE FUNCTION public.save_qr_settings_v3(
  p_raw_token text,
  p_settings  jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess        RECORD;
  v_domain      text;
  v_key         text;
  v_canon_json  jsonb;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.manage_settings') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền thay đổi cài đặt QR');
  END IF;

  IF p_settings IS NULL OR jsonb_typeof(p_settings) <> 'object' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Định dạng cài đặt không hợp lệ');
  END IF;

  -- Validate unknown keys
  FOR v_key IN SELECT jsonb_object_keys(p_settings) LOOP
    IF v_key NOT IN ('is_table_enabled', 'is_counter_enabled', 'auto_claim', 'sound_enabled', 'public_domain') THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Cài đặt chứa thuộc tính không hợp lệ: ' || v_key);
    END IF;
  END LOOP;

  -- Validate boolean types if present
  IF (p_settings ? 'is_table_enabled' AND jsonb_typeof(p_settings -> 'is_table_enabled') <> 'boolean') OR
     (p_settings ? 'is_counter_enabled' AND jsonb_typeof(p_settings -> 'is_counter_enabled') <> 'boolean') OR
     (p_settings ? 'auto_claim' AND jsonb_typeof(p_settings -> 'auto_claim') <> 'boolean') OR
     (p_settings ? 'sound_enabled' AND jsonb_typeof(p_settings -> 'sound_enabled') <> 'boolean') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Các tùy chọn bật/tắt phải có kiểu boolean');
  END IF;

  -- Validate public_domain
  v_domain := '';
  IF p_settings ? 'public_domain' THEN
    IF jsonb_typeof(p_settings -> 'public_domain') <> 'string' THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Tên miền public_domain phải là chuỗi ký tự');
    END IF;

    v_domain := TRIM(COALESCE(p_settings ->> 'public_domain', ''));
    IF length(v_domain) > 255 THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Độ dài tên miền không được vượt quá 255 ký tự');
    END IF;
    IF v_domain <> '' AND v_domain !~ '^https://[a-zA-Z0-9.-]+(:[0-9]+)?$' THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Tên miền phải là HTTPS origin hợp lệ (ví dụ: https://quannho.lpm.vn)');
    END IF;
  END IF;

  -- Construct canonical complete JSON object merging missing keys with defaults
  v_canon_json := jsonb_build_object(
    'is_table_enabled', COALESCE((p_settings ->> 'is_table_enabled')::boolean, false),
    'is_counter_enabled', COALESCE((p_settings ->> 'is_counter_enabled')::boolean, false),
    'auto_claim', COALESCE((p_settings ->> 'auto_claim')::boolean, false),
    'sound_enabled', COALESCE((p_settings ->> 'sound_enabled')::boolean, true),
    'public_domain', v_domain
  );

  INSERT INTO public.app_settings(store_id, key, value)
  VALUES (v_sess.store_id, 'qr_order_settings', v_canon_json::text)
  ON CONFLICT (store_id, key) DO UPDATE SET value = EXCLUDED.value;

  INSERT INTO public.qr_audit_logs(store_id, actor_type, actor_staff_id, actor_user_account_id, action, payload)
  VALUES (v_sess.store_id, 'staff', v_sess.staff_id, v_sess.user_account_id, 'save_settings', jsonb_build_object('settings', v_canon_json));

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('settings', v_canon_json), 'error_code', NULL, 'message', NULL);
END;
$$;
ALTER FUNCTION public.save_qr_settings_v3(text, jsonb) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.save_qr_settings_v3(text, jsonb) FROM PUBLIC, anon, authenticated;

-- 17. cleanup_pos_auth_attempts_v3 (Service Role Maintenance)
CREATE OR REPLACE FUNCTION public.cleanup_pos_auth_attempts_v3()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_cnt integer;
BEGIN
  DELETE FROM public.pos_auth_attempts WHERE created_at < (now() - INTERVAL '24 hours');
  GET DIAGNOSTICS v_cnt = ROW_COUNT;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('deleted_count', v_cnt), 'error_code', NULL, 'message', NULL);
END;
$$;
ALTER FUNCTION public.cleanup_pos_auth_attempts_v3() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.cleanup_pos_auth_attempts_v3() FROM PUBLIC, anon, authenticated;

-- Postflight Integrity Check
DO $$
DECLARE
  v_func text;
BEGIN
  FOR v_func IN VALUES
    ('hash_pos_credential_v3'), ('verify_pos_token_internal'), ('check_pos_staff_action_permission'),
    ('bootstrap_first_pos_device_v3'), ('issue_pos_device_session_v3'), ('generate_pos_pairing_code_v3'),
    ('pair_pos_device_v3'), ('revoke_pos_device_session_v3'), ('admin_revoke_device_session_v3'),
    ('list_pos_device_sessions_v3'), ('list_qr_channels_v3'), ('upsert_qr_channel_v3'),
    ('rotate_qr_channel_v3'), ('set_qr_channel_active_v3'), ('get_qr_settings_v3'),
    ('save_qr_settings_v3'), ('cleanup_pos_auth_attempts_v3')
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = v_func) THEN
      RAISE EXCEPTION 'MIGRATION_03_POSTFLIGHT_FAIL: Function public.% missing', v_func;
    END IF;
  END LOOP;
END $$;
