-- ═══════════════════════════════════════════════════════════════════════════
-- QUÁN NHỎ POS — Add Index for App Logs Table
-- Copy paste câu lệnh này vào Supabase SQL Editor và chạy (Run)
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Thêm Index tối ưu cho việc truy vấn log theo cửa hàng và thời gian (giảm thiểu 100% lỗi Timeout PGRST 57014)
CREATE INDEX IF NOT EXISTS idx_app_logs_store_created_at 
ON app_logs(store_id, created_at DESC);

-- 2. Thêm Index phụ trợ nếu lọc theo level hoặc tag của log
CREATE INDEX IF NOT EXISTS idx_app_logs_filters 
ON app_logs(store_id, level, tag, created_at DESC);
