-- FIX 05b (07/10/2026) — Gỡ policy "ai cũng được" trên bàn / bếp / đơn.
-- Các bảng này đã có policy cô lập theo quán (current_store_id()); policy `true` đang vô hiệu hóa nó.
-- SAU KHI ÁP: client không có JWT hợp lệ (bản app cũ chỉ gửi header x-store-id) sẽ KHÔNG đọc/ghi được các bảng này.
-- Chỉ áp khi mọi máy đã dùng bản có POS JWT. Rollback: 20261007_fix05b_ROLLBACK.sql
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='ban_sessions' AND policyname='ban_sessions_isolation')
  OR NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='kitchen_tickets' AND policyname='kitchen_tickets_isolation')
  OR NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='kitchen_ticket_items' AND policyname='kitchen_ticket_items_isolation')
  OR NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='orders' AND policyname='orders_isolation')
  OR NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='order_items' AND policyname='order_items_isolation') THEN
    RAISE EXCEPTION 'Thiếu policy cô lập theo quán — không gỡ policy cũ';
  END IF;
END $$;
DROP POLICY IF EXISTS ban_all ON public.ban_sessions;
DROP POLICY IF EXISTS kitchen_all ON public.kitchen_tickets;
DROP POLICY IF EXISTS kitchen_items_all ON public.kitchen_ticket_items;
DROP POLICY IF EXISTS orders_all ON public.orders;
DROP POLICY IF EXISTS order_items_all ON public.order_items;
