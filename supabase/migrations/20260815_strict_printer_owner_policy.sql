-- ─────────────────────────────────────────────────────────────────────────────
-- SQL Migration: Strict Owner-Only Printer Settings Security
-- Cập nhật RLS Policy cho bảng app_settings để bảo vệ khóa qn_printer_profile_v2
-- và qn_print_server_owner_v1 chỉ cho phép vai trò 'owner' (Chủ quán) ghi đè.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Hàm helper kiểm tra người dùng hiện tại có phải Chủ quán (is_owner / role = owner)
CREATE OR REPLACE FUNCTION public.is_current_user_store_owner(_store_id uuid)
RETURNS boolean AS $$
DECLARE
  _user_id uuid;
  _is_owner boolean := false;
BEGIN
  _user_id := auth.uid();
  IF _user_id IS NULL THEN
    RETURN false;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.store_members
    WHERE store_id = _store_id
      AND user_id = _user_id
      AND (is_owner = true OR role = 'owner')
  ) INTO _is_owner;

  RETURN _is_owner;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Đảm bảo RLS enabled cho app_settings
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- 3. Policy đọc (SELECT): Tất cả các thành viên trong quán đều đọc được để máy in hoạt động
DROP POLICY IF EXISTS "app_settings_select_policy" ON public.app_settings;
CREATE POLICY "app_settings_select_policy" ON public.app_settings
  FOR SELECT
  USING (store_id::text = public.current_store_id()::text OR public.current_store_id() IS NULL);

-- 4. Policy ghi (INSERT/UPDATE/DELETE):
-- Chỉ cho phép cập nhật các khóa máy in (qn_printer_profile_v2, qn_print_server_owner_v1) nếu người dùng là Owner
DROP POLICY IF EXISTS "app_settings_printer_owner_write_policy" ON public.app_settings;
CREATE POLICY "app_settings_printer_owner_write_policy" ON public.app_settings
  FOR ALL
  USING (
    store_id::text = public.current_store_id()::text
    AND (
      key NOT IN ('qn_printer_profile_v2', 'qn_print_server_owner_v1')
      OR public.is_current_user_store_owner(store_id)
    )
  )
  WITH CHECK (
    store_id::text = public.current_store_id()::text
    AND (
      key NOT IN ('qn_printer_profile_v2', 'qn_print_server_owner_v1')
      OR public.is_current_user_store_owner(store_id)
    )
  );
