-- ═══════════════════════════════════════════════════════════════════════════
-- THÊM CỘT CHẤM CÔNG VÀO staff_shifts
-- Chạy trong Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE staff_shifts
  ADD COLUMN IF NOT EXISTS photo_url  TEXT,
  ADD COLUMN IF NOT EXISTS latitude   DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS address    TEXT,
  ADD COLUMN IF NOT EXISTS drive_file_id TEXT;

-- Bật Realtime cho staff_shifts
ALTER PUBLICATION supabase_realtime ADD TABLE staff_shifts;

-- Kiểm tra
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'staff_shifts'
ORDER BY ordinal_position;
