-- ============================================================================
-- HOÀN TÁC 20261107_admin_nhip_app_v1.sql. MẤT dữ liệu nhịp app và nguồn khách đã ghi (chỉ là số thống kê).
-- Trả trang /admin cũ TRƯỚC. App đã cài gọi hàm không còn thì lỗi bị bỏ qua im lặng, không ảnh hưởng bán hàng.
-- ============================================================================
BEGIN;
DROP FUNCTION IF EXISTS public.admin_app_health_v1(boolean);
DROP FUNCTION IF EXISTS public.store_signup_source_set_v1(uuid, text);
DROP FUNCTION IF EXISTS public.app_heartbeat_v1(uuid, text, text, text, int);
ALTER TABLE public.stores DROP COLUMN IF EXISTS signup_source;
DROP TABLE IF EXISTS public.app_device_days;
COMMIT;
NOTIFY pgrst, 'reload schema';
