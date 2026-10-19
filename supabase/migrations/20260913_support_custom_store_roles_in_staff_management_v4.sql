-- =============================================================================
-- Migration: 20260913_support_custom_store_roles_in_staff_management_v4.sql
-- Description: Cho phép gán các vai trò tùy chỉnh (custom store_roles như Barista,
--              Kế toán, Pha chế...) trong các RPC quản lý nhân sự:
--              1. Cập nhật admin_create_staff_member_v4
--              2. Cập nhật admin_update_staff_role_v4
-- =============================================================================

-- 1. Cập nhật admin_create_staff_member_v4
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
  v_norm_role text;
  v_custom_role text;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 401, 'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực');
  END IF;

  SELECT public.normalize_role_code_v4(CASE WHEN is_owner THEN 'owner' ELSE role END)
  INTO v_caller_role
  FROM public.store_members
  WHERE user_id = v_caller_id AND store_id = p_store_id;
  IF v_caller_role IS NULL THEN
    SELECT 'owner' INTO v_caller_role FROM public.stores WHERE id = p_store_id AND owner_user_id = v_caller_id;
  END IF;

  IF v_caller_role NOT IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Chỉ chủ quán hoặc quản lý mới có quyền thêm nhân viên');
  END IF;

  v_norm_role := public.normalize_role_code_v4(p_role);
  IF v_norm_role NOT IN ('waiter', 'cashier', 'kitchen', 'stock', 'manager') THEN
    SELECT name INTO v_custom_role
    FROM public.store_roles
    WHERE store_id = p_store_id
      AND (name = p_role OR lower(trim(name)) = lower(trim(p_role)))
    LIMIT 1;

    IF v_custom_role IS NOT NULL THEN
      v_norm_role := v_custom_role;
    ELSE
      RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'INVALID_ROLE', 'message', 'Vai trò nhân viên không hợp lệ');
    END IF;
  END IF;

  IF v_caller_role = 'manager' AND v_norm_role IN ('owner', 'manager') THEN
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
  VALUES (v_user_id, p_store_id, trim(p_name), v_norm_phone, v_norm_role, '[]'::jsonb, true, extract(epoch from now()) * 1000)
  ON CONFLICT (id) DO UPDATE
    SET name = excluded.name,
        role = excluded.role,
        is_active = true,
        updated_at = excluded.updated_at
    WHERE public.staff_members.store_id = p_store_id;

  -- Upsert store_members
  INSERT INTO public.store_members(user_id, store_id, role, is_owner, created_at)
  VALUES (v_user_id, p_store_id, v_norm_role, false, now())
  ON CONFLICT (user_id, store_id) DO UPDATE
    SET role = excluded.role,
        is_owner = false;

  RETURN jsonb_build_object(
    'success', true, 'status', 200,
    'staff_id', v_user_id,
    'name', trim(p_name),
    'role', v_norm_role,
    'store_id', p_store_id
  );
END;
$$;

-- 2. Cập nhật admin_update_staff_role_v4
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
  v_norm_new_role text;
  v_custom_role text;
  v_owner_count integer;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 401, 'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực');
  END IF;

  -- Không thể tự đổi vai trò của chính mình
  IF v_caller_id = p_staff_id THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Không thể tự thay đổi vai trò của chính mình');
  END IF;

  SELECT public.normalize_role_code_v4(CASE WHEN is_owner THEN 'owner' ELSE role END)
  INTO v_caller_role
  FROM public.store_members
  WHERE user_id = v_caller_id AND store_id = p_store_id;
  IF v_caller_role IS NULL THEN
    SELECT 'owner' INTO v_caller_role FROM public.stores WHERE id = p_store_id AND owner_user_id = v_caller_id;
  END IF;

  IF v_caller_role NOT IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Không có quyền cập nhật nhân viên');
  END IF;

  v_norm_new_role := public.normalize_role_code_v4(p_new_role);
  IF v_norm_new_role NOT IN ('waiter', 'cashier', 'kitchen', 'stock', 'manager', 'owner') THEN
    SELECT name INTO v_custom_role
    FROM public.store_roles
    WHERE store_id = p_store_id
      AND (name = p_new_role OR lower(trim(name)) = lower(trim(p_new_role)))
    LIMIT 1;

    IF v_custom_role IS NOT NULL THEN
      v_norm_new_role := v_custom_role;
    ELSE
      RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'INVALID_ROLE', 'message', 'Vai trò không hợp lệ');
    END IF;
  END IF;

  -- Quản lý không được nâng quyền ai thành Quản lý hoặc Chủ quán
  IF v_caller_role = 'manager' AND v_norm_new_role IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Quản lý không được nâng quyền người khác thành Quản lý hoặc Chủ quán');
  END IF;

  -- Kiểm tra vai trò của tài khoản mục tiêu
  SELECT public.normalize_role_code_v4(CASE WHEN is_owner THEN 'owner' ELSE role END)
  INTO v_target_role
  FROM public.store_members
  WHERE user_id = p_staff_id AND store_id = p_store_id;

  IF v_target_role IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 404, 'error_code', 'STAFF_NOT_FOUND', 'message', 'Không tìm thấy nhân viên trong quán');
  END IF;

  -- Quản lý không được sửa Chủ quán hoặc Quản lý khác
  IF v_caller_role = 'manager' AND v_target_role IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Quản lý không được sửa Chủ quán hoặc Quản lý khác');
  END IF;

  -- Không cho phép hạ quyền Chủ quán cuối cùng
  IF v_target_role = 'owner' AND v_norm_new_role <> 'owner' THEN
    SELECT count(*) INTO v_owner_count
    FROM public.store_members
    WHERE store_id = p_store_id AND (is_owner = true OR public.normalize_role_code_v4(role) = 'owner');
    IF v_owner_count <= 1 THEN
      RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'CANNOT_DEMOTE_LAST_OWNER', 'message', 'Không thể hạ quyền Chủ quán cuối cùng của cơ sở');
    END IF;
  END IF;

  UPDATE public.staff_members
  SET role = v_norm_new_role, updated_at = extract(epoch from now()) * 1000
  WHERE id = p_staff_id AND store_id = p_store_id;

  UPDATE public.store_members
  SET role = v_norm_new_role, is_owner = (v_norm_new_role = 'owner')
  WHERE user_id = p_staff_id AND store_id = p_store_id;

  RETURN jsonb_build_object('success', true, 'status', 200, 'role', v_norm_new_role);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_create_staff_member_v4(uuid, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_create_staff_member_v4(uuid, text, text, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_update_staff_role_v4(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_staff_role_v4(uuid, uuid, text) TO authenticated, service_role;
