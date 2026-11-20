-- HOÀN TÁC 20261108_admin_viec_cham_soc_v1.sql: gỡ hàm chỉ đọc. Trả trang /admin cũ trước. Không có dữ liệu phải khôi phục.
BEGIN;
DROP FUNCTION IF EXISTS public.admin_care_v1(boolean);
COMMIT;
NOTIFY pgrst, 'reload schema';
