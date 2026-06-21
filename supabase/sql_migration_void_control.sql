-- SQL Migration: Void Control & Auditing
-- Chạy script này trên Supabase SQL Editor để cấu hình database

-- 1. Thêm cột quick_pin (lưu hash PIN 4 số) vào bảng user_accounts nếu chưa tồn tại
ALTER TABLE user_accounts 
  ADD COLUMN IF NOT EXISTS quick_pin TEXT;

-- 2. Tạo bảng void_audit_logs để lưu lịch sử kiểm toán hủy duyệt
CREATE TABLE IF NOT EXISTS void_audit_logs (
  id                    UUID PRIMARY KEY,
  store_id              UUID NOT NULL REFERENCES stores(id),
  void_type             TEXT NOT NULL,          -- 'cancel_table' | 'void_item' | 'cancel_order'
  reference_id          UUID NOT NULL,          -- session_id hoặc order_id
  label                 TEXT NOT NULL,          -- Tên bàn (vd: "Bàn 5") hoặc mã đơn (vd: "QN-20260529-001")
  requested_by_user_id  UUID NOT NULL REFERENCES user_accounts(id), -- Nhân viên yêu cầu hủy
  requested_by_name     TEXT NOT NULL,
  approved_by_user_id   UUID NOT NULL REFERENCES user_accounts(id), -- Quản lý/Chủ quán duyệt
  approved_by_name      TEXT NOT NULL,
  reason                TEXT NOT NULL,          -- Lý do hủy
  amount                NUMERIC NOT NULL,       -- Số tiền thất thoát nháp
  details_json          JSONB,                  -- Chi tiết danh sách món bị hủy
  created_at            TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Tắt RLS để đồng bộ với môi trường phát triển (RLS sẽ được bật sau khi Production)
ALTER TABLE void_audit_logs DISABLE ROW LEVEL SECURITY;

-- 4. Grant quyền đầy đủ cho vai trò anon và authenticated
GRANT SELECT, INSERT, UPDATE, DELETE ON void_audit_logs TO anon, authenticated;

-- 5. Bật Realtime cho bảng void_audit_logs để đồng bộ tức thời
ALTER PUBLICATION supabase_realtime ADD TABLE void_audit_logs;

-- 6. Reload schema cache cho PostgREST nhận diện thay đổi
NOTIFY pgrst, 'reload schema';
