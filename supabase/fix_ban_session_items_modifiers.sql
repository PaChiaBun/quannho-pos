-- =====================================================================
-- FIX: Thêm cột modifiers_json vào ban_session_items
-- Ngày: 2026-05-03
-- Lý do: Code insert modifiers_json nhưng cột chưa tồn tại trên DB
--         → PostgrestException PGRST204: Could not find column
-- Hướng dẫn: Chạy trong Supabase SQL Editor → Run
-- =====================================================================

-- Thêm cột vào ban_session_items (IF NOT EXISTS để idempotent)
ALTER TABLE ban_session_items
  ADD COLUMN IF NOT EXISTS modifiers_json text DEFAULT '[]';

-- Xác nhận
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'ban_session_items'
  AND column_name = 'modifiers_json';
