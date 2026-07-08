-- ═══════════════════════════════════════════════════════════════════════
-- CHẠY LỆNH NÀY TRONG SUPABASE SQL EDITOR ĐỂ BẬT REALTIME CHO APP_SETTINGS
-- ═══════════════════════════════════════════════════════════════════════

-- Bật Realtime cho bảng app_settings để đồng bộ hóa cấu hình máy in tức thời
ALTER PUBLICATION supabase_realtime ADD TABLE app_settings;
