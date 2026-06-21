-- =====================================================================
-- Loyalty Stamp Card Migration
-- Thêm stamp_count vào customers và loyalty_redeem_rate vào app_settings
-- =====================================================================

-- 1. Thêm cột stamp_count vào customers (safe — IF NOT EXISTS)
ALTER TABLE customers
  ADD COLUMN IF NOT EXISTS stamp_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stamp_total integer NOT NULL DEFAULT 0;
-- stamp_count: số tem hiện tại trong vòng này (reset về 0 sau khi đủ)
-- stamp_total: tổng tem đã tích lũy toàn thời gian (không reset, dùng cho stats)

-- 2. Thêm cài đặt tỷ lệ đổi điểm (redemption rate)
-- loyalty_redeem_rate: 1 điểm = X VNĐ giảm giá (mặc định 1000đ/điểm)
-- Ví dụ: khách có 50 điểm × 1000đ = giảm 50,000đ
INSERT INTO app_settings (id, store_id, key, value, created_at)
SELECT
  gen_random_uuid(),
  store_id,
  'loyalty_redeem_rate',
  '1000',
  now()
FROM (SELECT DISTINCT store_id FROM app_settings WHERE key = 'loyalty_rate') t
ON CONFLICT (store_id, key) DO NOTHING;

-- 3. Thêm stamp_threshold (số tem cần để nhận thưởng, mặc định 10)
INSERT INTO app_settings (id, store_id, key, value, created_at)
SELECT
  gen_random_uuid(),
  store_id,
  'stamp_threshold',
  '10',
  now()
FROM (SELECT DISTINCT store_id FROM app_settings WHERE key = 'loyalty_rate') t
ON CONFLICT (store_id, key) DO NOTHING;

-- 4. Xác nhận
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'customers'
  AND column_name IN ('stamp_count', 'stamp_total');
