-- ============================================================================
-- HOÀN TÁC 20261029_ho_tro_chu_quan_h1h2.sql
--   • Gỡ các hàm quản trị + trigger. GIỮ dữ liệu: bảng bug_reports (phản hồi khách đã gửi) và support_actions (nhật ký).
--     Muốn bỏ hẳn: DROP TABLE public.bug_reports, public.support_actions;
--   • Thu quyền THÊM vào bug_reports (app gửi phản hồi sẽ lại lỗi như trước khi áp).
--   • Mật khẩu tạm đã cấp KHÔNG trả lại (người dùng đã / sẽ đổi mật khẩu).
--   • Áp LẠI migration sau khi hoàn tác: migration chặn khi bug_reports đã có → phải đổi tên / xoá bảng cũ trước
--     (vd ALTER TABLE public.bug_reports RENAME TO bug_reports_cu;) rồi áp, chép dữ liệu cũ sang nếu cần.
-- ============================================================================
BEGIN;
REVOKE INSERT ON public.bug_reports FROM authenticated;
DROP POLICY IF EXISTS bug_reports_insert_v1 ON public.bug_reports;
DROP TRIGGER IF EXISTS qn_bug_reports_before_insert ON public.bug_reports;
DROP FUNCTION IF EXISTS public.qn_bug_reports_before_insert();
DROP FUNCTION IF EXISTS public.admin_support_list_v1(text, text, int, int);
DROP FUNCTION IF EXISTS public.admin_support_update_v1(uuid, text, text);
DROP FUNCTION IF EXISTS public.admin_account_search_v1(text);
DROP FUNCTION IF EXISTS public.admin_account_detail_v1(uuid);
DROP FUNCTION IF EXISTS public.admin_account_reset_password_v1(uuid, text, jsonb, uuid);
DROP FUNCTION IF EXISTS public.admin_account_clear_pin_v1(uuid, text);
DROP FUNCTION IF EXISTS public.qn_admin_account_json(uuid);
COMMIT;
NOTIFY pgrst, 'reload schema';
