DROP FUNCTION IF EXISTS public.confirm_stock_count_v1(uuid);
DROP FUNCTION IF EXISTS public.record_stock_waste_v1(uuid, numeric, text, text);
-- Giữ lại bảng stock_counts / stock_count_items để không mất lịch sử kiểm kê; xóa tay nếu thật sự cần:
-- DROP TABLE IF EXISTS public.stock_count_items; DROP TABLE IF EXISTS public.stock_counts;
