-- ═══════════════════════════════════════════════════════════════════════════
-- Thêm bảng Auth vào Supabase
-- Chạy trong SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Tài khoản người dùng
CREATE TABLE IF NOT EXISTS user_accounts (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  phone         text UNIQUE NOT NULL,       -- Số điện thoại (ID đăng nhập)
  password_hash text NOT NULL,              -- SHA-256(phone:password:qn_salt)
  display_name  text NOT NULL DEFAULT '',   -- Tên hiển thị
  created_at    timestamptz DEFAULT now()
);

-- 2. Thành viên quán (map user ↔ store với role)
CREATE TABLE IF NOT EXISTS store_members (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES user_accounts(id) ON DELETE CASCADE,
  store_id   uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  role       text NOT NULL DEFAULT 'cashier',  -- owner/manager/cashier/waiter/kitchen/stock
  is_owner   boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, store_id)
);

-- 3. Thêm owner_user_id vào stores
ALTER TABLE stores ADD COLUMN IF NOT EXISTS owner_user_id uuid REFERENCES user_accounts(id);

-- 4. Indexes
CREATE INDEX IF NOT EXISTS idx_user_phone    ON user_accounts(phone);
CREATE INDEX IF NOT EXISTS idx_members_user  ON store_members(user_id);
CREATE INDEX IF NOT EXISTS idx_members_store ON store_members(store_id);

-- 5. Grant cho anon role
GRANT SELECT, INSERT, UPDATE, DELETE ON user_accounts TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON store_members TO anon, authenticated;

-- 6. Disable RLS cho 2 bảng auth (bảo mật qua password hash)
ALTER TABLE user_accounts DISABLE ROW LEVEL SECURITY;
ALTER TABLE store_members DISABLE ROW LEVEL SECURITY;
ALTER TABLE stores        DISABLE ROW LEVEL SECURITY;
ALTER TABLE devices       DISABLE ROW LEVEL SECURITY;
