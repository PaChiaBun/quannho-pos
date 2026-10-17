-- FIX 07 (07/10/2026) — Chủ quán không thấy tên/SĐT nhân viên mới trong module Nhân viên
-- Nguyên nhân: sau FIX 04, policy ua_select_v5 dùng qn_shares_store_with() chỉ xét bảng store_members.
--   Chủ quán KAY (stores.owner_user_id) không có dòng trong store_members → không đọc được user_accounts của nhân viên.
--   Đồng thời RPC get_store_staff_directory_v4 (migration 06/10) chưa từng được áp lên DB thật.
-- Sửa: (1) qn_shares_store_with tính cả chủ quán (stores.owner_user_id) ở cả hai phía;
--      (2) cài RPC get_store_staff_directory_v4 (SECURITY DEFINER, tự bù staff_members còn thiếu).
-- Rollback: 20261007_fix07_ROLLBACK.sql

CREATE OR REPLACE FUNCTION public.qn_shares_store_with(p_user uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT public.qn_caller_id() IS NOT NULL AND (
    p_user = public.qn_caller_id()
    OR EXISTS (
      WITH mine AS (
        SELECT store_id FROM public.store_members WHERE user_id = public.qn_caller_id()
        UNION SELECT id FROM public.stores WHERE owner_user_id = public.qn_caller_id()
      ), theirs AS (
        SELECT store_id FROM public.store_members WHERE user_id = p_user
        UNION SELECT id FROM public.stores WHERE owner_user_id = p_user
      )
      SELECT 1 FROM mine JOIN theirs USING (store_id)
    )
  );
$$;

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
  ON CONFLICT (id) DO UPDATE
    SET store_id = EXCLUDED.store_id,
        name = CASE
                 WHEN public.staff_members.name IN ('', 'Nhân viên', 'Nhân viên mới') AND EXCLUDED.name IS NOT NULL AND EXCLUDED.name <> ''
                 THEN EXCLUDED.name
                 ELSE public.staff_members.name
               END,
        phone = COALESCE(NULLIF(EXCLUDED.phone, ''), public.staff_members.phone),
        is_active = true,
        updated_at = extract(epoch from now()) * 1000;

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
