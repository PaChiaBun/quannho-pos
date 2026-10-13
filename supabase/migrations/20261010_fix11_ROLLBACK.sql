-- Rollback FIX 11: bỏ hàm hoàn thành lệnh sản xuất (app tự quay về cách cũ, chỉ trừ nguyên liệu).
-- Bút toán stock_movements 'production' / 'production_output' đã ghi KHÔNG bị xóa.
DROP FUNCTION IF EXISTS public.complete_production_order_v1(uuid);
NOTIFY pgrst, 'reload schema';
