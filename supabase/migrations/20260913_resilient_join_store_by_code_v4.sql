-- =============================================================================
-- Migration: 20260913_resilient_join_store_by_code_v4.sql
-- Description: Cải tiến join_store_by_code_v4 với cơ chế trích xuất user_id đa tầng:
--              1. auth.uid()
--              2. Fallback đọc request.jwt.claims ->> 'sub'
-- Giữ nguyên 100% logic phân quyền, vai trò nhân viên và bảo mật store_id.
-- =============================================================================

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
  -- Multi-tier user ID extraction fallback
  IF v_user_id IS NULL THEN
    BEGIN
      v_user_id := (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_user_id := NULL;
    END;
  END IF;

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

REVOKE ALL ON FUNCTION public.join_store_by_code_v4(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_store_by_code_v4(text) TO anon, authenticated;

-- =============================================================================
-- Function: create_store_with_owner_v4 (Resilient Onboarding Claims Fallback)
-- =============================================================================
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
  -- Multi-tier user ID extraction fallback
  IF v_user_id IS NULL THEN
    BEGIN
      v_user_id := (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_user_id := NULL;
    END;
  END IF;

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
    SELECT EXISTS(SELECT 1 FROM public.stores WHERE store_code = v_code) INTO v_exists;
    IF v_exists THEN
      RETURN jsonb_build_object(
        'success', false, 'status', 409,
        'error_code', 'STORE_CODE_EXISTS', 'message', 'Mã quán đã tồn tại'
      );
    END IF;
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

REVOKE ALL ON FUNCTION public.create_store_with_owner_v4(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_store_with_owner_v4(text, text) TO anon, authenticated;
