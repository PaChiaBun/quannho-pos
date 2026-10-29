-- Chỉ mục cho các truy vấn POS gọi liên tục (28/10/2026, Bò Đen lag khi mở bàn / thu chi).
-- Trước: ban_session_items lọc theo session_id phải quét cả bảng (30k dòng, 1,3 triệu lần gọi);
-- finance_records lọc store_id + recorded_at cũng quét cả bảng; product_modifiers giờ tải theo quán.
-- CONCURRENTLY: không khoá ghi khi quán đang bán. KHÔNG bọc trong transaction — chạy từng lệnh.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ban_session_items_session_id
  ON public.ban_session_items (session_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_finance_records_store_recorded_at
  ON public.finance_records (store_id, recorded_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_product_modifiers_store_id
  ON public.product_modifiers (store_id);

-- ROLLBACK:
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_ban_session_items_session_id;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_finance_records_store_recorded_at;
-- DROP INDEX CONCURRENTLY IF EXISTS public.idx_product_modifiers_store_id;
