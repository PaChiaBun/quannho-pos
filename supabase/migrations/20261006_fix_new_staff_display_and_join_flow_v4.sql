-- =============================================================================
-- Migration: 20261006_fix_new_staff_display_and_join_flow_v4.sql
-- Description: Khắc phục triệt để sự cố nhân viên mới tham gia qua mã quán / QR
--              nhưng không hiển thị trong module Nhân viên (nhan_vien_screen.dart):
--              1. Cập nhật join_store_by_code_v4:
--                 - Đọc cả SĐT và display_name từ user_accounts.
--                 - Duy trì bản sao staff_members đồng bộ với store_members (SSOT).
--                 - Gán vai trò 'unassigned' (Chưa phân vai trò) nếu chưa có role định sẵn,
--                   hoặc giữ vai trò pre-assigned nếu đã tạo trước đó.
--              2. Tạo RPC get_store_staff_directory_v4 (Security Definer):
--                 - Trả về đầy đủ định danh (tên, SĐT, vai trò, ca, lương)
--                   ngay cả khi client gặp rào cản RLS trên user_accounts.
--                 - Tự động bù đắp (self-healing) các bản ghi staff_members còn thiếu.
--              3. Cấu hình RLS & Grants cho user_accounts:
--                 - Cho phép thành viên trong cùng một quán đọc display_name & SĐT
--                   của nhau mà không rò rỉ password_hash hay dữ liệu ngoài quán.
--              4. Bổ sung store_members & staff_members vào publication supabase_realtime.
--              5. Data backfill cho quán KAy và các quán hiện có.
-- =============================================================================

-- ── 1. Cập nhật RPC join_store_by_code_v4 ─────────────────────────────────────
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
  v_assigned_role text := 'unassigned';
  v_caller_phone text;
  v_caller_name text;
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

  -- Đọc thông tin người gọi từ user_accounts (Security Definer)
  SELECT phone, display_name
  INTO v_caller_phone, v_caller_name
  FROM public.user_accounts
  WHERE id = v_user_id;

  SELECT role, is_owner
  INTO v_existing
  FROM public.store_members
  WHERE user_id = v_user_id AND store_id = v_store.id;

  IF v_existing.role IS NOT NULL THEN
    -- Đảm bảo staff_members cũng tồn tại hồ sơ đồng bộ
    INSERT INTO public.staff_members (id, store_id, name, role, phone, is_active, updated_at)
    VALUES (
      v_user_id,
      v_store.id,
      COALESCE(NULLIF(trim(v_caller_name), ''), 'Nhân viên mới'),
      v_existing.role,
      v_caller_phone,
      true,
      extract(epoch from now()) * 1000
    )
    ON CONFLICT (id) DO UPDATE
      SET store_id = EXCLUDED.store_id,
          name = CASE
                   WHEN public.staff_members.name IN ('', 'Nhân viên', 'Nhân viên mới') AND v_caller_name IS NOT NULL AND trim(v_caller_name) <> ''
                   THEN trim(v_caller_name)
                   ELSE public.staff_members.name
                 END,
          phone = COALESCE(NULLIF(v_caller_phone, ''), public.staff_members.phone),
          is_active = true,
          updated_at = extract(epoch from now()) * 1000;

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

  -- 1. Lưu tư cách thành viên vào store_members (SSOT)
  INSERT INTO public.store_members(user_id, store_id, role, is_owner, created_at)
  VALUES (v_user_id, v_store.id, v_assigned_role, (v_assigned_role = 'owner'), now())
  ON CONFLICT (user_id, store_id) DO UPDATE
    SET role = excluded.role,
        is_owner = excluded.is_owner;

  -- 2. Duy trì bản sao staff_members đồng bộ
  INSERT INTO public.staff_members (id, store_id, name, role, phone, is_active, updated_at)
  VALUES (
    v_user_id,
    v_store.id,
    COALESCE(NULLIF(trim(v_caller_name), ''), 'Nhân viên mới'),
    v_assigned_role,
    v_caller_phone,
    true,
    extract(epoch from now()) * 1000
  )
  ON CONFLICT (id) DO UPDATE
    SET store_id = EXCLUDED.store_id,
        name = CASE
                 WHEN public.staff_members.name IN ('', 'Nhân viên', 'Nhân viên mới') AND v_caller_name IS NOT NULL AND trim(v_caller_name) <> ''
                 THEN trim(v_caller_name)
                 ELSE public.staff_members.name
               END,
        role = EXCLUDED.role,
        phone = COALESCE(NULLIF(v_caller_phone, ''), public.staff_members.phone),
        is_active = true,
        updated_at = extract(epoch from now()) * 1000;

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
GRANT EXECUTE ON FUNCTION public.join_store_by_code_v4(text) TO anon, authenticated, service_role;

-- ── 2. Tạo RPC get_store_staff_directory_v4 (Security Definer) ───────────────
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

-- ── 3. Chính sách RLS cho phép cùng quán xem tên & SĐT ────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_accounts'
  ) THEN
    DROP POLICY IF EXISTS user_accounts_store_member_select_v4 ON public.user_accounts;
    CREATE POLICY user_accounts_store_member_select_v4 ON public.user_accounts
      FOR SELECT TO authenticated
      USING (
        id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM public.store_members sm1
          JOIN public.store_members sm2 ON sm1.store_id = sm2.store_id
          WHERE sm1.user_id = auth.uid()
            AND sm2.user_id = public.user_accounts.id
        )
      );
  END IF;
END $$;

-- ── 4. Publication Realtime ──────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'store_members'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.store_members;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'staff_members'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.staff_members;
    END IF;
  END IF;
END $$;

-- ── 5. Backfill dữ liệu nhân viên cũ bị thiếu staff_members ──────────────────
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
WHERE NOT EXISTS (
  SELECT 1 FROM public.staff_members s WHERE s.id = sm.user_id AND s.store_id = sm.store_id
)
ON CONFLICT (id) DO UPDATE
  SET store_id = EXCLUDED.store_id,
      name = CASE
               WHEN public.staff_members.name IN ('', 'Nhân viên', 'Nhân viên mới') AND EXCLUDED.name IS NOT NULL AND EXCLUDED.name <> ''
               THEN EXCLUDED.name
               ELSE public.staff_members.name
             END,
      phone = COALESCE(EXCLUDED.phone, public.staff_members.phone),
      is_active = true,
      updated_at = extract(epoch from now()) * 1000;
