-- Fix permission denied cho anon role
-- Chạy toàn bộ trong Supabase SQL Editor

-- 1. Grant quyền trên schema
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- 2. Grant quyền từng bảng cho anon
GRANT SELECT, INSERT, UPDATE, DELETE ON stores              TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON devices             TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON products            TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_members       TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON orders              TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON order_items         TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ban_sessions        TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON kitchen_tickets     TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON kitchen_ticket_items TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON app_settings        TO anon, authenticated;

-- 3. Đảm bảo RLS policy đúng cho stores
DROP POLICY IF EXISTS "stores_read"   ON stores;
DROP POLICY IF EXISTS "stores_insert" ON stores;
DROP POLICY IF EXISTS "stores_update" ON stores;

CREATE POLICY "stores_all" ON stores
  FOR ALL TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- 4. Tương tự cho devices
DROP POLICY IF EXISTS "devices_all" ON devices;
CREATE POLICY "devices_all_fixed" ON devices
  FOR ALL TO anon, authenticated
  USING (true)
  WITH CHECK (true);
