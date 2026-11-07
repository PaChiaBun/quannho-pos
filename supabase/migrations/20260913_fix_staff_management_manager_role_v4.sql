-- =============================================================================
-- Migration: 20260913_fix_staff_management_manager_role_v4.sql
-- Description: Chuẩn hóa vai trò nhân sự 2 lớp và thiết lập rào chắn tôn ti
--              trật tự (Role Hierarchy Guardrails) ở Database:
--              1. Tạo hàm public.normalize_role_code_v4(text) -> text
--              2. Chạy chuẩn hóa dữ liệu cũ trong store_members và staff_members
--              3. Cập nhật admin_create_staff_member_v4
--              4. Cập nhật admin_update_staff_role_v4
--              5. Cập nhật admin_set_staff_status_v4
--              6. Cập nhật admin_revoke_staff_membership_v4
--              7. Cập nhật join_store_by_code_v4 để luôn ghi nhận mã chuẩn
-- =============================================================================

-- 1. Helper function chuẩn hóa vai trò (hỗ trợ cả tiếng Việt có dấu, không dấu và tiếng Anh)
CREATE OR REPLACE FUNCTION public.normalize_role_code_v4(p_role text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_clean text := lower(trim(COALESCE(p_role, '')));
BEGIN
  IF v_clean IN ('owner', 'chu quan', 'chủ quán', 'chủ') THEN
    RETURN 'owner';
  ELSIF v_clean IN ('manager', 'quan ly', 'quản lý') THEN
    RETURN 'manager';
  ELSIF v_clean IN ('cashier', 'thu ngan', 'thu ngân') THEN
    RETURN 'cashier';
  ELSIF v_clean IN ('waiter', 'phuc vu', 'phục vụ') THEN
    RETURN 'waiter';
  ELSIF v_clean IN ('kitchen', 'chef', 'bep', 'bếp', 'đầu bếp', 'dau bep') THEN
    RETURN 'kitchen';
  ELSIF v_clean IN ('stock', 'kho') THEN
    RETURN 'stock';
  ELSE
    RETURN v_clean;
  END IF;
END;
$$;

-- 2. Chuẩn hóa dữ liệu cũ trong store_members và staff_members
UPDATE public.store_members
SET role = public.normalize_role_code_v4(role)
WHERE role IS NOT NULL;

UPDATE public.staff_members
SET role = public.normalize_role_code_v4(role)
WHERE role IS NOT NULL;

-- 3. Cập nhật admin_create_staff_member_v4
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
    RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'INVALID_ROLE', 'message', 'Vai trò nhân viên không hợp lệ');
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

-- 4. Cập nhật admin_update_staff_role_v4
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
    RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'INVALID_ROLE', 'message', 'Vai trò không hợp lệ');
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

-- 5. Cập nhật admin_set_staff_status_v4
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

  SELECT public.normalize_role_code_v4(CASE WHEN is_owner THEN 'owner' ELSE role END)
  INTO v_caller_role
  FROM public.store_members
  WHERE user_id = v_caller_id AND store_id = p_store_id;
  IF v_caller_role IS NULL THEN
    SELECT 'owner' INTO v_caller_role FROM public.stores WHERE id = p_store_id AND owner_user_id = v_caller_id;
  END IF;

  IF v_caller_role NOT IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Không có quyền');
  END IF;

  SELECT public.normalize_role_code_v4(CASE WHEN is_owner THEN 'owner' ELSE role END)
  INTO v_target_role
  FROM public.store_members
  WHERE user_id = p_staff_id AND store_id = p_store_id;

  IF v_target_role IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 404, 'error_code', 'STAFF_NOT_FOUND', 'message', 'Không tìm thấy nhân viên trong quán');
  END IF;

  -- Quản lý không được khóa Chủ quán hoặc Quản lý khác
  IF v_caller_role = 'manager' AND v_target_role IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Quản lý không được khóa Chủ quán hoặc Quản lý khác');
  END IF;

  -- Không cho phép khóa Chủ quán cuối cùng
  IF p_is_active = false AND v_target_role = 'owner' THEN
    SELECT count(*) INTO v_owner_count
    FROM public.store_members
    WHERE store_id = p_store_id AND (is_owner = true OR public.normalize_role_code_v4(role) = 'owner');
    IF v_owner_count <= 1 THEN
      RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'CANNOT_LOCK_LAST_OWNER', 'message', 'Không thể khóa Chủ quán cuối cùng của cơ sở');
    END IF;
  END IF;

  UPDATE public.staff_members
  SET is_active = p_is_active, updated_at = extract(epoch from now()) * 1000
  WHERE id = p_staff_id AND store_id = p_store_id;

  RETURN jsonb_build_object('success', true, 'status', 200, 'is_active', p_is_active);
END;
$$;

-- 6. Cập nhật admin_revoke_staff_membership_v4
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

  SELECT public.normalize_role_code_v4(CASE WHEN is_owner THEN 'owner' ELSE role END)
  INTO v_caller_role
  FROM public.store_members
  WHERE user_id = v_caller_id AND store_id = p_store_id;
  IF v_caller_role IS NULL THEN
    SELECT 'owner' INTO v_caller_role FROM public.stores WHERE id = p_store_id AND owner_user_id = v_caller_id;
  END IF;

  IF v_caller_role NOT IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Không có quyền');
  END IF;

  SELECT public.normalize_role_code_v4(CASE WHEN is_owner THEN 'owner' ELSE role END)
  INTO v_target_role
  FROM public.store_members
  WHERE user_id = p_staff_id AND store_id = p_store_id;

  IF v_target_role IS NULL THEN
    RETURN jsonb_build_object('success', true, 'status', 200, 'message', 'Nhân viên đã được thu hồi trước đó');
  END IF;

  -- Quản lý không được xóa Chủ quán hoặc Quản lý khác
  IF v_caller_role = 'manager' AND v_target_role IN ('owner', 'manager') THEN
    RETURN jsonb_build_object('success', false, 'status', 403, 'error_code', 'FORBIDDEN', 'message', 'Quản lý không được xóa Chủ quán hoặc Quản lý khác');
  END IF;

  -- Không thể xóa Chủ quán cuối cùng
  IF v_target_role = 'owner' THEN
    SELECT count(*) INTO v_owner_count
    FROM public.store_members
    WHERE store_id = p_store_id AND (is_owner = true OR public.normalize_role_code_v4(role) = 'owner');
    IF v_owner_count <= 1 THEN
      RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'CANNOT_REMOVE_LAST_OWNER', 'message', 'Không thể xóa Chủ quán cuối cùng của cơ sở');
    END IF;
  END IF;

  DELETE FROM public.store_members WHERE user_id = p_staff_id AND store_id = p_store_id;
  UPDATE public.staff_members SET is_active = false, updated_at = extract(epoch from now()) * 1000 WHERE id = p_staff_id AND store_id = p_store_id;

  RETURN jsonb_build_object('success', true, 'status', 200, 'message', 'Thu hồi quyền nhân viên thành công');
END;
$$;

-- 7. Cập nhật join_store_by_code_v4 để chuẩn hóa vai trò được gán
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
$$;

-- 8. Phân quyền thực thi (Grants)
REVOKE ALL ON FUNCTION public.normalize_role_code_v4(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.normalize_role_code_v4(text) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_create_staff_member_v4(uuid, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_create_staff_member_v4(uuid, text, text, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_update_staff_role_v4(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_staff_role_v4(uuid, uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_set_staff_status_v4(uuid, uuid, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_staff_status_v4(uuid, uuid, boolean) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.admin_revoke_staff_membership_v4(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_revoke_staff_membership_v4(uuid, uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.join_store_by_code_v4(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_store_by_code_v4(text) TO authenticated, service_role;
