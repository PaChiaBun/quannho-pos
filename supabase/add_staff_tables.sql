-- ═══════════════════════════════════════════════════════════════════════════
-- STAFF TABLES — Chạy trong Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Hồ sơ nhân viên (thông tin HR)
CREATE TABLE IF NOT EXISTS staff_profiles (
  user_id     uuid NOT NULL,
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  hourly_rate numeric(10,2) DEFAULT 0,
  base_salary numeric(12,0) DEFAULT 0,
  job_desc    text DEFAULT '',
  start_date  date DEFAULT CURRENT_DATE,
  created_at  timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, store_id)
);

-- 2. Chấm công (manual + fingerprint API)
CREATE TABLE IF NOT EXISTS staff_shifts (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid NOT NULL,
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  clock_in    timestamptz NOT NULL DEFAULT now(),
  clock_out   timestamptz,
  source      text DEFAULT 'manual',  -- 'manual' / 'fingerprint_api'
  device_ref  text,                   -- mã máy chấm công
  note        text,
  created_at  timestamptz DEFAULT now()
);

-- 3. Lịch sử thay đổi quyền (audit)
CREATE TABLE IF NOT EXISTS staff_perm_logs (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  target_user uuid,
  by_user     uuid,
  action      text,   -- 'add_staff' / 'remove_staff' / 'role_change' / 'perm_change'
  detail      text,   -- JSON: {old, new, module, ...}
  created_at  timestamptz DEFAULT now()
);

-- 4. Indexes
CREATE INDEX IF NOT EXISTS idx_shifts_user  ON staff_shifts(user_id, store_id);
CREATE INDEX IF NOT EXISTS idx_shifts_store ON staff_shifts(store_id, clock_in);
CREATE INDEX IF NOT EXISTS idx_perm_store   ON staff_perm_logs(store_id);

-- 5. Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_profiles  TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_shifts     TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE         ON staff_perm_logs  TO anon, authenticated;

-- 6. Disable RLS (dev mode)
ALTER TABLE staff_profiles  DISABLE ROW LEVEL SECURITY;
ALTER TABLE staff_shifts     DISABLE ROW LEVEL SECURITY;
ALTER TABLE staff_perm_logs  DISABLE ROW LEVEL SECURITY;
