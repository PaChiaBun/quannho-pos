-- ============================================================================
-- HOÀN TÁC 20261105_admin_tang_truong_v1.sql — gỡ 2 hàm chỉ đọc. Không có dữ liệu nào phải khôi phục.
-- Trả trang /admin cũ TRƯỚC (trang cũ dùng admin_store_list_v1, vẫn còn nguyên).
-- ============================================================================
BEGIN;
DROP FUNCTION IF EXISTS public.admin_growth_v1(boolean);
DROP FUNCTION IF EXISTS public.admin_store_list_v2(text, text, boolean, int, int, text, text, uuid);
COMMIT;
NOTIFY pgrst, 'reload schema';
