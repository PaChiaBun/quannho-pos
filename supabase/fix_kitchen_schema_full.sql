-- =====================================================================
-- FIX: Căn chỉnh schema kitchen_tickets & kitchen_ticket_items
--      với code Flutter đang dùng
-- Ngày: 2026-05-03
-- Chạy trong Supabase SQL Editor → Run
-- =====================================================================

-- ── 1. kitchen_tickets — thêm các cột code đang insert ───────────────
ALTER TABLE kitchen_tickets
  ADD COLUMN IF NOT EXISTS session_id   uuid REFERENCES ban_sessions(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS table_label  text DEFAULT '',
  ADD COLUMN IF NOT EXISTS zone_label   text DEFAULT '',
  ADD COLUMN IF NOT EXISTS round        int  DEFAULT 1,
  ADD COLUMN IF NOT EXISTS sent_at      timestamptz DEFAULT now();

-- Đổi default status từ 'pending' → 'cho' (code dùng 'cho')
-- Không cần ALTER DEFAULT, code đã truyền tường minh rồi

-- ── 2. kitchen_ticket_items — thêm các cột code đang insert ──────────
ALTER TABLE kitchen_ticket_items
  ADD COLUMN IF NOT EXISTS session_item_id  uuid REFERENCES ban_session_items(id),
  ADD COLUMN IF NOT EXISTS product_name     text,   -- code dùng product_name (schema cũ có 'name')
  ADD COLUMN IF NOT EXISTS modifiers_json   text DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS free_note        text,   -- ghi chú từ nhân viên
  ADD COLUMN IF NOT EXISTS started_at       timestamptz,
  ADD COLUMN IF NOT EXISTS done_at          timestamptz;

-- ── 3. GRANT lại quyền (an toàn) ────────────────────────────────────
GRANT ALL ON kitchen_tickets      TO anon, authenticated;
GRANT ALL ON kitchen_ticket_items TO anon, authenticated;

-- ── 4. Kiểm tra kết quả ──────────────────────────────────────────────
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('kitchen_tickets', 'kitchen_ticket_items')
  AND column_name IN (
    'session_id', 'table_label', 'zone_label', 'round', 'sent_at',
    'session_item_id', 'product_name', 'modifiers_json', 'free_note'
  )
ORDER BY table_name, column_name;
