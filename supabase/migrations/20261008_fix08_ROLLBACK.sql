CREATE OR REPLACE FUNCTION public.join_store_by_code_v4(p_store_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
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
      'role', public.normalize_role_code_v4(v_existing.role),
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
      v_assigned_role := public.normalize_role_code_v4(v_staff.role);
    ELSE
      v_assigned_role := 'waiter';
    END IF;
  END IF;

  INSERT INTO public.store_members(user_id, store_id, role, is_owner, created_at)
  VALUES (v_user_id, v_store.id, v_assigned_role, (v_assigned_role = 'owner'), now())
  ON CONFLICT (user_id, store_id) DO UPDATE
    SET role = excluded.role,
        is_owner = (excluded.role = 'owner');

  RETURN jsonb_build_object(
    'success', true, 'status', 200,
    'store_id', v_store.id,
    'store_code', v_store.store_code,
    'store_name', v_store.name,
    'role', v_assigned_role,
    'is_owner', (v_assigned_role = 'owner')
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.join_store_by_code_v4(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_store_by_code_v4(text) TO anon, authenticated, service_role;
-- get_store_staff_directory_v4: giữ bản FIX 07 (20261007_fix07_...sql) nếu cần quay lại
