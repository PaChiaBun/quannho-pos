-- Hoàn tác E-INVOICE FOUNDATION v1. Cảnh báo: xóa toàn bộ dữ liệu hóa đơn và nhật ký công tắc đã lưu.
-- Hóa đơn đã phát hành lên nhà cung cấp/cơ quan thuế vẫn tồn tại bên đó; hãy sao lưu bảng trước khi chạy.
BEGIN;
DROP FUNCTION IF EXISTS public.einvoice_report_v1(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.set_einvoice_enabled_v1(boolean);
DROP TABLE IF EXISTS public.einvoice_documents;
DROP TABLE IF EXISTS public.einvoice_audit_logs;
DROP TABLE IF EXISTS public.einvoice_store_config;
COMMIT;
NOTIFY pgrst, 'reload schema';
