-- ============================================================================
-- KHOÁ XOÁ / SỬA NHẬT KÝ KIỂM TOÁN (22/10/2026) — P0-2 trong .docs/Huong_dan/viec-can-sua.md
-- Lỗi cũ: nút "Xóa sạch" (log_viewer_screen.dart) xoá TOÀN BỘ app_logs của quán, gồm log
--   nghiệp vụ/kiểm toán (in lại bill, duyệt PIN quản lý, huỷ bàn, nạp ví…). Quản lý làm được →
--   xoá dấu vết. anon/authenticated còn có quyền UPDATE → sửa được nội dung log.
-- Sửa: trigger guard_app_logs_v1 (BEFORE UPDATE OR DELETE), chỉ áp vai trò client:
--   * UPDATE: luôn chặn (log là bất biến).
--   * DELETE: chặn dòng có tag nghiệp vụ (app_log_is_protected_tag); log kỹ thuật vẫn xoá được.
--   Vai trò quản trị / hàm lịch xoá log (SECURITY DEFINER) không bị chặn.
-- App cũ bấm "Xóa sạch": lô 500 dòng có lẫn log nghiệp vụ → lỗi "Xóa nhật ký thất bại", không
--   xoá gì trong lô đó (an toàn). App mới chỉ xoá log kỹ thuật.
-- Rollback: 20261022_khoa_xoa_nhat_ky_v1_ROLLBACK.sql
-- ============================================================================

CREATE OR REPLACE FUNCTION public.app_log_is_protected_tag(p_tag text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $fn$
  SELECT lower(COALESCE(p_tag, '')) IN (
    'action', 'checkout', 'order', 'auth', 'ban_items',
    'finance', 'payroll', 'staff', 'staff_shift_audit', 'payroll_staff_confirm'
  );
$fn$;
GRANT EXECUTE ON FUNCTION public.app_log_is_protected_tag(text) TO anon, authenticated, service_role;

-- Không SECURITY DEFINER: cần current_user là vai trò thật của người gọi.
CREATE OR REPLACE FUNCTION public.guard_app_logs_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'APP_LOG_IMMUTABLE: Không được sửa nhật ký.' USING ERRCODE = '42501';
  END IF;
  IF public.app_log_is_protected_tag(OLD.tag) THEN
    RAISE EXCEPTION 'APP_LOG_PROTECTED: Không được xoá nhật ký nghiệp vụ (%).', OLD.tag USING ERRCODE = '42501';
  END IF;
  RETURN OLD;
END
$fn$;

DROP TRIGGER IF EXISTS guard_app_logs_v1 ON public.app_logs;
CREATE TRIGGER guard_app_logs_v1
  BEFORE UPDATE OR DELETE ON public.app_logs
  FOR EACH ROW EXECUTE FUNCTION public.guard_app_logs_v1();

DO $chk$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'guard_app_logs_v1'
                 AND tgrelid = 'public.app_logs'::regclass AND NOT tgisinternal) THEN
    RAISE EXCEPTION 'POSTCHECK: thiếu trigger guard_app_logs_v1';
  END IF;
  RAISE NOTICE 'POSTCHECK khoa_xoa_nhat_ky_v1: OK';
END
$chk$;
