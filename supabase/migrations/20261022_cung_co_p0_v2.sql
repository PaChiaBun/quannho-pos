-- ============================================================================
-- CỦNG CỐ P0 v2 (22/10/2026) — sửa các lỗ do đợt QC độc lập tìm ra sau khi áp P0-1…P0-5
--   1. ban_sessions: app (anon/authenticated) xoá được phiên đã thanh toán/đã huỷ → mất luôn
--      payment_settlements, ban_session_orders… (xoá dây chuyền chạy quyền chủ bảng nên các
--      trigger chặn không bắt được). App không có chỗ nào xoá phiên bàn → chặn hẳn.
--   2. payroll_actor_v1: Quản lý/Chủ quán đã bị vô hiệu (store_members không còn hoạt động)
--      vẫn trả lương được → chỉ tính quyền khi còn hoạt động (qr_is_active_member_v4).
--      Nhân viên tự xác nhận đã nhận lương không đổi (so theo user_id của phiếu).
--   3. finance_record_deletions: app chạy vai anon nên không đọc được vết xoá → cho anon đọc
--      đúng quán mình (RLS theo current_store_id()).
--   4. app_log_is_protected_tag: thêm nhóm 'kho', 'settings', 'inventory' (thay đổi tồn kho,
--      cài đặt) vào nhật ký nghiệp vụ không xoá được.
-- GHI NHẬN, KHÔNG SỬA Ở ĐÂY: danh tính người gọi lấy từ header x-user-id (app không đăng nhập
--   Supabase) → người biết API có thể giả danh; mọi chốt "chỉ Chủ quán/Quản lý" chỉ chặn được
--   app bình thường. Cần dự án riêng: đăng nhập thật (JWT) cho từng nhân viên.
-- Rollback: 20261022_cung_co_p0_v2_ROLLBACK.sql
-- ============================================================================

DO $pf$
BEGIN
  IF to_regprocedure('public.payroll_actor_v1(uuid)') IS NULL
     OR to_regprocedure('public.app_log_is_protected_tag(text)') IS NULL
     OR to_regclass('public.finance_record_deletions') IS NULL
     OR to_regprocedure('public.qr_is_active_member_v4(uuid,uuid)') IS NULL THEN
    RAISE EXCEPTION 'PREFLIGHT: cần áp trước khoa_duyet_tra_luong_v1, khoa_xoa_nhat_ky_v1, xoa_thu_chi_an_toan_v1';
  END IF;
  RAISE NOTICE 'PREFLIGHT cung_co_p0_v2: OK';
END
$pf$;

-- 1. Chặn app xoá phiên bàn ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_ban_session_delete_v2()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog, pg_temp
AS $fn$
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'BAN_SESSION_DELETE_BLOCKED: Không xoá phiên bàn từ app — huỷ bàn thay vì xoá'
    USING ERRCODE = '42501';
END
$fn$;

DROP TRIGGER IF EXISTS guard_ban_session_delete_v2 ON public.ban_sessions;
CREATE TRIGGER guard_ban_session_delete_v2
  BEFORE DELETE ON public.ban_sessions
  FOR EACH ROW EXECUTE FUNCTION public.guard_ban_session_delete_v2();

-- 2. Quyền lương chỉ tính khi còn hoạt động ----------------------------------------------
CREATE OR REPLACE FUNCTION public.payroll_actor_v1(p_store_id uuid,
  OUT uid uuid, OUT is_owner boolean, OUT is_manager boolean)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE v_m record;
BEGIN
  is_owner := false; is_manager := false;
  BEGIN
    SELECT * INTO v_m FROM public.verify_staff_qr_membership_v4(p_store_id, false, false);
  EXCEPTION WHEN OTHERS THEN
    RETURN;
  END;
  uid := v_m.member_user_id;
  -- Chủ quán/Quản lý đã bị vô hiệu thì không còn quyền duyệt/trả (uid vẫn giữ để tự xác nhận lương).
  IF uid IS NULL OR NOT public.qr_is_active_member_v4(p_store_id, uid) THEN
    RETURN;
  END IF;
  is_owner := COALESCE(v_m.is_owner_member, false) OR lower(COALESCE(v_m.member_role, '')) = 'owner';
  is_manager := is_owner OR lower(COALESCE(v_m.member_role, '')) IN ('manager', 'admin');
END
$fn$;
REVOKE ALL ON FUNCTION public.payroll_actor_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.payroll_actor_v1(uuid) TO anon, authenticated, service_role;

-- 3. App (vai anon) đọc được vết xoá thu chi của quán mình -------------------------------
GRANT SELECT ON public.finance_record_deletions TO anon;
DROP POLICY IF EXISTS finance_record_deletions_read ON public.finance_record_deletions;
CREATE POLICY finance_record_deletions_read ON public.finance_record_deletions
  FOR SELECT TO anon, authenticated
  USING (store_id = (SELECT public.current_store_id()));

-- 4. Thêm nhóm nhật ký nghiệp vụ được bảo vệ ---------------------------------------------
CREATE OR REPLACE FUNCTION public.app_log_is_protected_tag(p_tag text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_catalog, pg_temp
AS $fn$
  SELECT lower(COALESCE(p_tag, '')) IN ('action','checkout','order','auth','ban_items','finance','payroll','staff','staff_shift_audit','payroll_staff_confirm','kho','settings','inventory');
$fn$;

DO $chk$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'guard_ban_session_delete_v2')
     OR NOT public.app_log_is_protected_tag('KHO') THEN
    RAISE EXCEPTION 'POSTCHECK cung_co_p0_v2: thiếu trigger / tag';
  END IF;
  RAISE NOTICE 'POSTCHECK cung_co_p0_v2: OK';
END
$chk$;
