-- ============================================================================
-- HOÀN TÁC 20261101_tong_quan_nang_cap.sql — gỡ hàm chỉ đọc admin_overview_extra_v1 (trang /admin cũ không dùng hàm này;
-- trang mới sẽ báo "không tải được" ở các khối mới, các khối cũ vẫn chạy).
-- ============================================================================
BEGIN;
DROP FUNCTION IF EXISTS public.admin_overview_extra_v1(boolean);
COMMIT;
NOTIFY pgrst, 'reload schema';
