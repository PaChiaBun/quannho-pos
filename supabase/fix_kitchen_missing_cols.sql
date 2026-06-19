-- =====================================================================
-- FIX: kitchen_tickets thiếu started_at, done_at
--      kitchen_ticket_items thiếu cột 'done' và 'product_id'
-- Ngày: 2026-05-03
-- Chạy trong Supabase SQL Editor → Run
-- =====================================================================

-- ── 1. kitchen_tickets: thêm started_at, done_at ─────────────────────
ALTER TABLE kitchen_tickets
  ADD COLUMN IF NOT EXISTS started_at timestamptz,
  ADD COLUMN IF NOT EXISTS done_at    timestamptz;

-- ── 2. kitchen_ticket_items: thêm 'done' và 'product_id' ─────────────
--    Code insert: 'done': false và 'product_id': ...
ALTER TABLE kitchen_ticket_items
  ADD COLUMN IF NOT EXISTS done        boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS product_id  uuid;

-- ── 3. GRANT lại quyền ───────────────────────────────────────────────
GRANT ALL ON kitchen_tickets      TO anon, authenticated;
GRANT ALL ON kitchen_ticket_items TO anon, authenticated;

-- ── 4. Kiểm tra kết quả ──────────────────────────────────────────────
SELECT table_name, column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name IN ('kitchen_tickets', 'kitchen_ticket_items')
  AND column_name IN ('started_at', 'done_at', 'done', 'product_id')
ORDER BY table_name, column_name;
