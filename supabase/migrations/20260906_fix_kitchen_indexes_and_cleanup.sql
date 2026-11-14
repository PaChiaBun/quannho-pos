-- =============================================================================
-- Migration: 20260906_fix_kitchen_indexes_and_cleanup.sql
-- Mục tiêu: 
-- 1. Bổ sung index cho kitchen_ticket_items và kitchen_tickets để tối ưu hóa triệt để
--    các truy vấn polling/lookup vé bếp, loại bỏ hoàn toàn Seq Scan 10.400+ dòng.
-- 2. Dọn dẹp các ticket rỗng 0 món phát sinh do timeout.
-- =============================================================================

-- 1. Index cho kitchen_ticket_items
CREATE INDEX IF NOT EXISTS idx_kitchen_ticket_items_ticket_id 
  ON public.kitchen_ticket_items USING btree (ticket_id);

CREATE INDEX IF NOT EXISTS idx_kitchen_ticket_items_store_id 
  ON public.kitchen_ticket_items USING btree (store_id);

CREATE INDEX IF NOT EXISTS idx_kitchen_ticket_items_session_item_id 
  ON public.kitchen_ticket_items USING btree (session_item_id);

-- 2. Index cho kitchen_tickets
CREATE INDEX IF NOT EXISTS idx_kitchen_tickets_store_sent_at 
  ON public.kitchen_tickets USING btree (store_id, status, sent_at DESC);

CREATE INDEX IF NOT EXISTS idx_kitchen_tickets_session_id 
  ON public.kitchen_tickets USING btree (session_id);

-- 3. Dọn dẹp các vé bếp rỗng 0 món hôm nay (2026-09-06)
DELETE FROM public.kitchen_tickets kt
WHERE kt.created_at >= '2026-09-06 00:00:00+00'
  AND NOT EXISTS (
    SELECT 1 FROM public.kitchen_ticket_items kti 
    WHERE kti.ticket_id = kt.id
  );

-- 4. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
