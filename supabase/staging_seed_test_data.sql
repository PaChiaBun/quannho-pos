-- ═══════════════════════════════════════════════════════════════════════════
-- QUÁN NHỎ POS & KAY RESTAURANT — STAGING SEED TEST DATA SCRIPT (VERIFIED SCHEMA)
-- File: supabase/staging_seed_test_data.sql
-- Note: Re-runnable / Idempotent script for STAGING/TEST ENVIRONMENT ONLY.
--       Matches exact schema types (ban_zones, ban_dining_tables, stores.store_code).
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_store_id uuid := '00000000-0000-0000-0000-000000000099'::uuid;
  v_store_code text := 'KAY-STAGING-TEST';
  v_zone1_id text := 'zone_stg_001';
  v_zone2_id text := 'zone_stg_002';
  v_table1_id text := 'tbl_stg_001';
  v_table2_id text := 'tbl_stg_002';
  
  v_p1_id uuid := '00000000-0000-0000-0003-000000000001'::uuid;
  v_p2_id uuid := '00000000-0000-0000-0003-000000000002'::uuid;
  v_p3_id uuid := '00000000-0000-0000-0003-000000000003'::uuid;
  v_p4_out_id uuid := '00000000-0000-0000-0003-000000000004'::uuid;
  
  v_top1_id uuid := '00000000-0000-0000-0004-000000000001'::uuid;
  v_top2_out_id uuid := '00000000-0000-0000-0004-000000000002'::uuid;
  v_now_ms bigint := (EXTRACT(EPOCH FROM now()) * 1000)::bigint;
BEGIN
  -- 1. Create Staging Test Store with required store_code
  INSERT INTO stores (id, store_code, name, slug, status)
  VALUES (v_store_id, v_store_code, 'KAY STAGING TEST', 'kay-staging-test', 'active')
  ON CONFLICT (id) DO UPDATE SET store_code = v_store_code, name = 'KAY STAGING TEST', slug = 'kay-staging-test';

  -- 2. Create Dining Zones (ban_zones table)
  INSERT INTO ban_zones (id, store_id, name, color, icon_code, sort_order, is_active, canvas_x, canvas_y, canvas_width, canvas_height, created_at)
  VALUES 
    (v_zone1_id, v_store_id, 'Khu Tầng 1 (Staging)', '#1C2151', 59672, 1, true, 40, 40, 220, 160, v_now_ms),
    (v_zone2_id, v_store_id, 'Khu Tầng 2 (Staging)', '#1C2151', 59672, 2, true, 40, 40, 220, 160, v_now_ms)
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

  -- 3. Create Dining Tables (ban_dining_tables table)
  INSERT INTO ban_dining_tables (id, store_id, zone_id, name, capacity, pos_x, pos_y, shape, table_width, table_height, sort_order, is_active, created_at)
  VALUES 
    (v_table1_id, v_store_id, v_zone1_id, 'Bàn T1-01 Staging', 4, 100, 100, 'rect', 90, 65, 1, true, v_now_ms),
    (v_table2_id, v_store_id, v_zone2_id, 'Bàn T2-01 Staging', 6, 100, 100, 'rect', 90, 65, 1, true, v_now_ms)
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, capacity = EXCLUDED.capacity;

  -- 4. Create QR Channels (1 Table, 1 Counter)
  INSERT INTO qr_channels (id, store_id, type, table_id, channel_code, name, is_active)
  VALUES 
    ('00000000-0000-0000-0005-000000000001'::uuid, v_store_id, 'table', v_table1_id, 'STAGING_TABLE_001', 'Bàn T1-01 Staging', true),
    ('00000000-0000-0000-0005-000000000002'::uuid, v_store_id, 'counter', NULL, 'STAGING_COUNTER_001', 'Quầy Thu Ngân Staging', true)
  ON CONFLICT (id) DO UPDATE SET channel_code = EXCLUDED.channel_code, name = EXCLUDED.name;

  -- 5. Create Test Products (3 Available, 1 Out of Stock)
  INSERT INTO products (id, store_id, name, category, sell_price, unit, description, is_available, is_active, is_deleted, is_topping, public_sort_order)
  VALUES
    (v_p1_id, v_store_id, 'Mì Cay Kim Chi Xúc Xích Test', 'Mỳ Kay Kim Chi', 39000, 'Tô', 'Mì cay kim chi xúc xích Đức (Môi trường Staging Test)', true, true, false, false, 1),
    (v_p2_id, v_store_id, 'Mì Cay Kim Chi Bò Mỹ Test', 'Mỳ Kay Kim Chi', 59000, 'Tô', 'Mì cay kim chi bò Mỹ cuộn (Môi trường Staging Test)', true, true, false, false, 2),
    (v_p3_id, v_store_id, 'Trà Sữa KAY Truyền Thống Test', 'Trà Sữa', 24000, 'Ly', 'Trà sữa truyền thống trân châu (Môi trường Staging Test)', true, true, false, false, 3),
    (v_p4_out_id, v_store_id, 'Mì Cay Kim Chi Bào Ngư Test (HẾT HÀNG)', 'Mỳ Kay Kim Chi', 89000, 'Tô', 'Mì cay bào ngư thượng hạng - Đã đánh dấu HẾT HÀNG', false, true, false, false, 4)
  ON CONFLICT (id) DO UPDATE SET sell_price = EXCLUDED.sell_price, is_available = EXCLUDED.is_available;

  -- 6. Create Test Toppings (1 Available, 1 Out of Stock)
  INSERT INTO products (id, store_id, name, category, sell_price, unit, is_available, is_active, is_deleted, is_topping)
  VALUES
    (v_top1_id, v_store_id, 'Cá Viên Thêm Test', 'Topping', 15000, 'Phần', true, true, false, true),
    (v_top2_out_id, v_store_id, 'Bạch Tuộc Thêm Test (HẾT HÀNG)', 'Topping', 25000, 'Phần', false, true, false, true)
  ON CONFLICT (id) DO UPDATE SET sell_price = EXCLUDED.sell_price, is_available = EXCLUDED.is_available;

  -- 7. Link Toppings to Products
  INSERT INTO product_topping_links (product_id, topping_id)
  VALUES
    (v_p1_id, v_top1_id),
    (v_p1_id, v_top2_out_id),
    (v_p2_id, v_top1_id),
    (v_p2_id, v_top2_out_id)
  ON CONFLICT DO NOTHING;

  RAISE NOTICE 'Staging Test Data Seeded Successfully for Store KAY STAGING TEST (%)', v_store_id;
END $$;
