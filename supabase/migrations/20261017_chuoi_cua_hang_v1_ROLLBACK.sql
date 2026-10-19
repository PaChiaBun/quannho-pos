-- Hoàn tác CHUỖI CỬA HÀNG v1. Chỉ xóa đối tượng do 20261017_chuoi_cua_hang_v1.sql tạo; không đụng dữ liệu vận hành.
-- Cảnh báo: xóa luôn lịch sử chuỗi + audit chuỗi. Sao lưu trước nếu đã dùng thật.
BEGIN;
DROP FUNCTION IF EXISTS public.get_chain_report_v1(uuid, timestamptz, timestamptz, text);
DROP FUNCTION IF EXISTS public.list_my_chains_v1();
DROP FUNCTION IF EXISTS public.remove_store_from_chain_v1(uuid, uuid);
DROP FUNCTION IF EXISTS public.add_store_to_chain_v1(uuid, uuid);
DROP FUNCTION IF EXISTS public.create_store_chain_v1(text);
DROP FUNCTION IF EXISTS public.qn_is_store_owner(uuid);
DROP TABLE IF EXISTS public.store_chain_audit_logs;
DROP TABLE IF EXISTS public.store_chain_stores;
DROP TABLE IF EXISTS public.store_chains;
COMMIT;
NOTIFY pgrst, 'reload schema';
