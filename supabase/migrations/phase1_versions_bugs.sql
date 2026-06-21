-- ─────────────────────────────────────────────────────────────────────────────
-- Quán Nhỏ POS — Phase 1: App Versions & Bug Reports tables
-- Chạy trong Supabase SQL Editor
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Bảng APP_VERSIONS — Quản lý phiên bản ứng dụng
CREATE TABLE IF NOT EXISTS app_versions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'macos', 'windows')),
  version_name TEXT NOT NULL,          -- '1.1.0'
  build_number INTEGER NOT NULL,       -- 2
  download_url TEXT,                   -- Link tải APK/DMG/EXE
  changelog TEXT,                      -- 'Sửa lỗi in bill...'
  is_force_update BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index cho query nhanh: lấy version mới nhất theo platform
CREATE INDEX IF NOT EXISTS idx_app_versions_platform_build
  ON app_versions (platform, build_number DESC);

-- RLS: Cho phép app đọc (anon), chỉ service_role mới ghi
ALTER TABLE app_versions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read versions" ON app_versions
  FOR SELECT USING (true);

-- Insert bản đầu tiên cho Android (version hiện tại)
INSERT INTO app_versions (platform, version_name, build_number, changelog)
VALUES ('android', '1.0.0', 1, 'Phiên bản đầu tiên 🚀');

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Bảng BUG_REPORTS — Báo lỗi từ người dùng
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bug_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id TEXT,                        -- ID người dùng (phone hoặc userId)
  store_id TEXT,                       -- Store đang dùng
  description TEXT NOT NULL,           -- Mô tả lỗi
  screenshot_url TEXT,                 -- URL ảnh chụp lỗi (Supabase Storage)
  device_info JSONB DEFAULT '{}',      -- {"model":"Sunmi P2 SE","os":"Android 11","app_version":"1.1.0"}
  screen_name TEXT,                    -- Màn hình đang mở khi báo lỗi
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'wontfix')),
  admin_note TEXT,                     -- Ghi chú từ admin
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

-- Index cho admin xem bug reports
CREATE INDEX IF NOT EXISTS idx_bug_reports_status ON bug_reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bug_reports_store ON bug_reports (store_id, created_at DESC);

-- RLS: App có thể insert, admin đọc/sửa
ALTER TABLE bug_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can insert bug reports" ON bug_reports
  FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can read bug reports" ON bug_reports
  FOR SELECT USING (true);
CREATE POLICY "Anyone can update bug reports" ON bug_reports
  FOR UPDATE USING (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Storage bucket cho screenshots
-- ─────────────────────────────────────────────────────────────────────────────
-- Chạy lệnh này trong Supabase Dashboard → Storage → Create bucket:
-- Tên: bug-screenshots
-- Public: YES
-- File size limit: 5MB
-- Allowed MIME types: image/jpeg, image/png, image/webp
