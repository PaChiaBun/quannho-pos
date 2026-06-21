-- =====================================================================
-- MIGRATION: Ca Cố Định + Module Tính Lương
-- Chạy trên Supabase SQL Editor — 1 lần duy nhất
-- =====================================================================

-- ─── PHASE A: CA CỐ ĐỊNH ─────────────────────────────────────────────

-- Template ca làm việc (Ca sáng / chiều / tối)
CREATE TABLE IF NOT EXISTS shift_templates (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id            UUID NOT NULL,
  name                TEXT NOT NULL,              -- "Ca sáng", "Ca chiều", "Ca tối"
  start_time          TIME NOT NULL,              -- '06:00:00'
  end_time            TIME NOT NULL,              -- '14:00:00'
  color               TEXT DEFAULT '#1C2151',
  late_grace_minutes  INT  DEFAULT 15,            -- cho phép trễ tối đa X phút (0 = không grace)
  is_active           BOOLEAN DEFAULT TRUE,
  sort_order          INT DEFAULT 0,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Phân công ca (NV nào làm ca nào ngày nào)
CREATE TABLE IF NOT EXISTS shift_assignments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id        UUID NOT NULL,
  user_id         UUID NOT NULL,
  template_id     UUID NOT NULL REFERENCES shift_templates(id) ON DELETE CASCADE,
  assigned_date   DATE NOT NULL,
  note            TEXT,
  created_by      UUID,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(store_id, user_id, assigned_date)
);

-- Thêm cột vào staff_shifts để tracking muộn
ALTER TABLE staff_shifts
  ADD COLUMN IF NOT EXISTS assignment_id  UUID,
  ADD COLUMN IF NOT EXISTS is_late        BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS late_minutes   INT     DEFAULT 0,
  ADD COLUMN IF NOT EXISTS photo_url_out  TEXT,
  ADD COLUMN IF NOT EXISTS latitude_out   NUMERIC,
  ADD COLUMN IF NOT EXISTS longitude_out  NUMERIC,
  ADD COLUMN IF NOT EXISTS address_out    TEXT,
  ADD COLUMN IF NOT EXISTS drive_file_id_out TEXT;

-- ─── PHASE B: TÍNH LƯƠNG ─────────────────────────────────────────────

-- Kỳ lương
CREATE TABLE IF NOT EXISTS payroll_periods (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id        UUID NOT NULL,
  name            TEXT NOT NULL,              -- "Tháng 5/2026"
  period_type     TEXT DEFAULT 'monthly',     -- monthly | biweekly | weekly | custom
  from_date       DATE NOT NULL,
  to_date         DATE NOT NULL,
  status          TEXT DEFAULT 'draft',       -- draft | pending_review | approved | paid
  total_amount    NUMERIC DEFAULT 0,
  approval_config JSONB DEFAULT '{"steps":["owner"]}',
  current_step    TEXT,
  note            TEXT,
  created_by      UUID,
  locked_at       TIMESTAMPTZ,
  paid_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Bảng lương từng NV trong kỳ
CREATE TABLE IF NOT EXISTS payroll_records (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id          UUID NOT NULL,
  period_id         UUID NOT NULL REFERENCES payroll_periods(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL,
  staff_name        TEXT NOT NULL,
  role              TEXT,
  salary_mode       TEXT NOT NULL DEFAULT 'M1', -- M1 | M2 | M3 | M4
  base_salary       NUMERIC DEFAULT 0,
  hourly_rate       NUMERIC DEFAULT 0,
  total_hours       NUMERIC DEFAULT 0,
  overtime_hours    NUMERIC DEFAULT 0,
  regular_pay       NUMERIC DEFAULT 0,
  overtime_pay      NUMERIC DEFAULT 0,
  bonus_revenue     NUMERIC DEFAULT 0,
  bonus_manual      NUMERIC DEFAULT 0,
  deduction_late    NUMERIC DEFAULT 0,
  deduction_absent  NUMERIC DEFAULT 0,
  deduction_manual  NUMERIC DEFAULT 0,
  allowance_total   NUMERIC DEFAULT 0,
  gross_pay         NUMERIC DEFAULT 0,
  net_pay           NUMERIC DEFAULT 0,
  absent_days       INT DEFAULT 0,
  late_count        INT DEFAULT 0,
  payment_status    TEXT DEFAULT 'pending',    -- pending | paid | hold
  payment_method    TEXT,                      -- cash | transfer | momo
  paid_at           TIMESTAMPTZ,
  note              TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- Chi tiết từng khoản trong bảng lương
CREATE TABLE IF NOT EXISTS payroll_items (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    UUID NOT NULL,
  record_id   UUID NOT NULL REFERENCES payroll_records(id) ON DELETE CASCADE,
  item_type   TEXT NOT NULL,    -- bonus | deduction | allowance | overtime
  label       TEXT NOT NULL,
  amount      NUMERIC NOT NULL,
  is_auto     BOOLEAN DEFAULT FALSE,
  note        TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Quy tắc lương cấu hình
CREATE TABLE IF NOT EXISTS payroll_rules (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id              UUID NOT NULL,
  rule_type             TEXT NOT NULL,   -- bonus_revenue | allowance | deduction_late | overtime_config
  name                  TEXT NOT NULL,
  calc_type             TEXT DEFAULT 'fixed', -- fixed | percent_revenue | per_hour | per_day
  amount                NUMERIC DEFAULT 0,
  threshold             NUMERIC,              -- ngưỡng doanh thu (bonus_revenue)
  percent               NUMERIC,             -- % doanh thu chia thưởng
  apply_to              TEXT DEFAULT 'all',  -- all | role:<name> | user:<id>
  ot_rate_normal        NUMERIC DEFAULT 1.5,
  ot_rate_weekend       NUMERIC DEFAULT 2.0,
  ot_rate_holiday       NUMERIC DEFAULT 3.0,
  ot_threshold_hours    NUMERIC DEFAULT 8.0,
  is_active             BOOLEAN DEFAULT TRUE,
  created_at            TIMESTAMPTZ DEFAULT NOW()
);

-- ─── GRANTS ──────────────────────────────────────────────────────────

GRANT SELECT, INSERT, UPDATE, DELETE ON shift_templates   TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON shift_assignments  TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON payroll_periods   TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON payroll_records   TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON payroll_items     TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON payroll_rules     TO anon, authenticated;

-- ─── PHASE C: CẤU HÌNH LƯƠNG NHÂN VIÊN ──────────────────────────────

-- Lưu cấu hình lương của từng NV (chế độ, mức, khấu trừ)
CREATE TABLE IF NOT EXISTS staff_salary_configs (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id            UUID NOT NULL,
  user_id             UUID NOT NULL,
  staff_name          TEXT NOT NULL,
  role                TEXT DEFAULT '',
  salary_mode         TEXT DEFAULT 'M1', -- M1 | M2 | M3 | M4
  base_salary         NUMERIC DEFAULT 0,
  hourly_rate         NUMERIC DEFAULT 25000,
  daily_rate          NUMERIC DEFAULT 0,
  expected_days       INT DEFAULT 26,
  deduction_per_late  NUMERIC DEFAULT 50000,
  ot_threshold_hours  NUMERIC DEFAULT 8.0,
  ot_multiplier       NUMERIC DEFAULT 1.5,  -- Hệ số OT: 1.5 thường, 2.0 cuối tuần, 3.0 ngày lễ
  updated_at          TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(store_id, user_id)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON staff_salary_configs TO anon, authenticated;

-- ─── REALTIME (optional — nếu cần sync realtime) ─────────────────────
-- ALTER PUBLICATION supabase_realtime ADD TABLE payroll_periods;
-- ALTER PUBLICATION supabase_realtime ADD TABLE payroll_records;

-- ─── SEED DỮ LIỆU MẪU: 3 ca mặc định ────────────────────────────────
-- (Chạy riêng sau khi đã có store_id thực, hoặc để app tự seed khi tạo quán)
-- INSERT INTO shift_templates (store_id, name, start_time, end_time, color, sort_order)
-- VALUES
--   ('<your-store-id>', 'Ca sáng',  '06:00', '14:00', '#F59E0B', 1),
--   ('<your-store-id>', 'Ca chiều', '14:00', '22:00', '#3B82F6', 2),
--   ('<your-store-id>', 'Ca tối',   '17:00', '23:00', '#8B5CF6', 3);

-- ─── VERIFY ──────────────────────────────────────────────────────────
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'shift_templates','shift_assignments',
    'payroll_periods','payroll_records','payroll_items','payroll_rules'
  )
ORDER BY table_name;
