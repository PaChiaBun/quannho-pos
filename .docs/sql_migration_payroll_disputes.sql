-- Migration: Bảng khiếu nại phiếu lương
-- Chạy trên Supabase SQL Editor

CREATE TABLE IF NOT EXISTS payroll_disputes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    UUID NOT NULL,
  record_id   UUID NOT NULL REFERENCES payroll_records(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL,
  staff_name  TEXT NOT NULL,
  field       TEXT DEFAULT 'other',  -- 'total_hours' | 'overtime' | 'deduction' | 'other'
  message     TEXT NOT NULL,
  status      TEXT DEFAULT 'open',   -- open | resolved | dismissed
  reply       TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

GRANT SELECT, INSERT, UPDATE ON payroll_disputes TO anon, authenticated;
