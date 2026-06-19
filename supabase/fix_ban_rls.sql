-- ======================================================================
-- TẠO ĐẦY ĐỦ CÁC BẢNG MODULE BÀN + FIX PERMISSIONS
-- Chạy 1 lần trong Supabase SQL Editor
-- ======================================================================

-- ── TẦNG 5: QUẢN LÝ BÀN ─────────────────────────────────────────────

-- Khu vực (Trong nhà, Ngoài trời, Tầng 2...)
CREATE TABLE IF NOT EXISTS ban_zones (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    uuid REFERENCES stores(id) ON DELETE CASCADE,
  name        text NOT NULL,
  color_value bigint DEFAULT 4279174481,  -- 0xFF1C2151
  icon_code   int DEFAULT 58136,           -- Icons.table_restaurant codePoint
  sort_order  int DEFAULT 0,
  is_active   boolean DEFAULT true,
  created_at  timestamptz DEFAULT now()
);

-- Bàn ăn
CREATE TABLE IF NOT EXISTS ban_dining_tables (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    uuid REFERENCES stores(id) ON DELETE CASCADE,
  zone_id     uuid REFERENCES ban_zones(id) ON DELETE CASCADE,
  label       text NOT NULL,
  seats       int DEFAULT 4,
  pos_x       numeric DEFAULT 0,
  pos_y       numeric DEFAULT 0,
  sort_order  int DEFAULT 0,
  is_active   boolean DEFAULT true,
  created_at  timestamptz DEFAULT now()
);

-- Phiên bàn (từ lúc khách ngồi → tính tiền xong)
CREATE TABLE IF NOT EXISTS ban_sessions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     uuid REFERENCES stores(id) ON DELETE CASCADE,
  table_id     uuid REFERENCES ban_dining_tables(id),
  status       text DEFAULT 'open',
  guest_count  int DEFAULT 1,
  total_amount numeric DEFAULT 0,
  staff_id     uuid,
  pos_order_id uuid,
  note         text,
  opened_at    timestamptz DEFAULT now(),
  closed_at    timestamptz
);

-- Món trong phiên bàn
CREATE TABLE IF NOT EXISTS ban_session_items (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id       uuid REFERENCES stores(id) ON DELETE CASCADE,
  session_id     uuid REFERENCES ban_sessions(id) ON DELETE CASCADE,
  product_id     uuid,
  product_name   text NOT NULL,
  unit_price     numeric NOT NULL,
  quantity       numeric DEFAULT 1,
  subtotal       numeric NOT NULL,
  note           text,
  added_by       text,
  kitchen_status text DEFAULT 'chua_gui',
  added_at       timestamptz DEFAULT now()
);

-- ── Thêm cột còn thiếu nếu bảng đã tồn tại ──────────────────────────
ALTER TABLE ban_zones         ADD COLUMN IF NOT EXISTS store_id    uuid REFERENCES stores(id) ON DELETE CASCADE;
ALTER TABLE ban_zones         ADD COLUMN IF NOT EXISTS color_value bigint DEFAULT 4279174481;
ALTER TABLE ban_zones         ADD COLUMN IF NOT EXISTS icon_code   int DEFAULT 58136;
ALTER TABLE ban_dining_tables ADD COLUMN IF NOT EXISTS store_id    uuid REFERENCES stores(id) ON DELETE CASCADE;
ALTER TABLE ban_dining_tables ADD COLUMN IF NOT EXISTS label       text;
ALTER TABLE ban_dining_tables ADD COLUMN IF NOT EXISTS seats       int DEFAULT 4;
ALTER TABLE ban_sessions      ADD COLUMN IF NOT EXISTS total_amount numeric DEFAULT 0;
ALTER TABLE ban_sessions      ADD COLUMN IF NOT EXISTS guest_count  int DEFAULT 1;

-- ── RLS: TẮT để anon key hoạt động tự do ────────────────────────────
ALTER TABLE ban_zones         DISABLE ROW LEVEL SECURITY;
ALTER TABLE ban_dining_tables DISABLE ROW LEVEL SECURITY;
ALTER TABLE ban_sessions      DISABLE ROW LEVEL SECURITY;
ALTER TABLE ban_session_items DISABLE ROW LEVEL SECURITY;

-- ── GRANT đầy đủ quyền ──────────────────────────────────────────────
GRANT ALL ON ban_zones         TO anon, authenticated;
GRANT ALL ON ban_dining_tables TO anon, authenticated;
GRANT ALL ON ban_sessions      TO anon, authenticated;
GRANT ALL ON ban_session_items TO anon, authenticated;

-- ── Bật Realtime ─────────────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE ban_session_items;

-- ── Kiểm tra kết quả ─────────────────────────────────────────────────
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('ban_zones','ban_dining_tables','ban_sessions','ban_session_items')
ORDER BY table_name;
