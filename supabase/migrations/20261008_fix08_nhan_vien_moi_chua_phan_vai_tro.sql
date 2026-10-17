-- FIX 08 (08/10/2026) — Nhân viên mới vào quán mặc định "Chưa phân vai trò" + chặn hàm bù hồ sơ kéo nhân viên sang quán khác
-- 1) join_store_by_code_v4: vai trò mặc định khi nhập mã quán = 'unassigned' (thay vì 'waiter'); chủ quán vẫn là 'owner';
--    nhân viên đã được chủ quán tạo sẵn hồ sơ (staff_members) vẫn nhận đúng vai trò đã gán.
-- 2) get_store_staff_directory_v4: bù hồ sơ staff_members bằng ON CONFLICT DO NOTHING (staff_members.id là khóa chính duy nhất,
--    trước đây DO UPDATE SET store_id có thể chuyển hồ sơ của người thuộc 2 quán sang quán đang xem).
-- Rollback: 20261008_fix08_ROLLBACK.sql

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
  v_assigned_role text := 'unassigned';
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
      v_assigned_role := 'unassigned';
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

CREATE OR REPLACE FUNCTION public.get_store_staff_directory_v4(p_store_id uuid)
RETURNS TABLE (
  user_id uuid,
  store_member_id uuid,
  role text,
  is_owner boolean,
  name text,
  phone text,
  hourly_rate numeric,
  shift_config_id uuid,
  is_clocked_in boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
#variable_conflict use_column
DECLARE
  v_caller_id uuid := auth.uid();
  v_has_access boolean := false;
BEGIN
  IF v_caller_id IS NULL THEN
    BEGIN
      v_caller_id := (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_caller_id := NULL;
    END;
  END IF;

  -- Kiểm tra quyền truy cập vào quán p_store_id
  IF v_caller_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.store_members WHERE user_id = v_caller_id AND store_id = p_store_id
      UNION
      SELECT 1 FROM public.stores WHERE id = p_store_id AND owner_user_id = v_caller_id
    ) INTO v_has_access;
  ELSIF (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role') = 'service_role'
        OR current_user = 'service_role' THEN
    v_has_access := true;
  END IF;

  IF NOT v_has_access THEN
    RETURN;
  END IF;

  -- Tự động bù đắp staff_members nếu thiếu
  INSERT INTO public.staff_members (id, store_id, name, role, phone, is_active, updated_at)
  SELECT
    sm.user_id,
    sm.store_id,
    COALESCE(NULLIF(trim(ua.display_name), ''), 'Nhân viên'),
    sm.role,
    ua.phone,
    true,
    extract(epoch from now()) * 1000
  FROM public.store_members sm
  LEFT JOIN public.user_accounts ua ON ua.id = sm.user_id
  WHERE sm.store_id = p_store_id
    AND NOT EXISTS (
      SELECT 1 FROM public.staff_members s WHERE s.id = sm.user_id AND s.store_id = p_store_id
    )
  ON CONFLICT (id) DO NOTHING; -- không kéo hồ sơ của người thuộc quán khác sang quán này

  RETURN QUERY
  SELECT
    sm.user_id,
    sm.id AS store_member_id,
    sm.role,
    COALESCE(sm.is_owner, false) AS is_owner,
    CASE
      WHEN smf.name IS NOT NULL AND trim(smf.name) NOT IN ('', 'Nhân viên', 'Nhân viên mới') THEN trim(smf.name)
      WHEN ua.display_name IS NOT NULL AND trim(ua.display_name) NOT IN ('', 'Nhân viên', 'Nhân viên mới') THEN trim(ua.display_name)
      WHEN smf.name IS NOT NULL AND trim(smf.name) <> '' THEN trim(smf.name)
      WHEN ua.display_name IS NOT NULL AND trim(ua.display_name) <> '' THEN trim(ua.display_name)
      ELSE 'Nhân viên'
    END AS name,
    COALESCE(NULLIF(trim(smf.phone), ''), NULLIF(trim(ua.phone), ''), '') AS phone,
    COALESCE(smf.hourly_rate, 0) AS hourly_rate,
    sm.shift_config_id,
    EXISTS (
      SELECT 1 FROM public.staff_shifts ss
      WHERE ss.user_id = sm.user_id AND ss.store_id = p_store_id AND ss.clock_out IS NULL
    ) AS is_clocked_in
  FROM public.store_members sm
  LEFT JOIN public.user_accounts ua ON ua.id = sm.user_id
  LEFT JOIN public.staff_members smf ON (smf.id = sm.user_id AND smf.store_id = p_store_id)
  WHERE sm.store_id = p_store_id
  ORDER BY
    CASE WHEN sm.role IN ('unassigned', 'none') OR sm.role LIKE '%chưa%' THEN 0 ELSE 1 END,
    name ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_store_staff_directory_v4(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_store_staff_directory_v4(uuid) TO authenticated, service_role;
