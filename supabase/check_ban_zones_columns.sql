-- 1. Bật Realtime cho ban_zones và ban_dining_tables
ALTER PUBLICATION supabase_realtime ADD TABLE ban_zones;
ALTER PUBLICATION supabase_realtime ADD TABLE ban_dining_tables;

-- 2. Kiểm tra data thực tế (không filter store_id)
SELECT id, store_id, name, color FROM ban_zones LIMIT 10;

-- 3. Xác nhận realtime đã bật
SELECT tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('ban_zones','ban_dining_tables','ban_sessions','ban_session_items')
ORDER BY tablename;
