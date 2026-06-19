-- Sprint 2: Photo Proof + Shift Handover
-- Chạy trong Supabase SQL Editor

-- 1. Photo proof columns
ALTER TABLE ops_task_templates
ADD COLUMN IF NOT EXISTS requires_photo BOOLEAN DEFAULT false;

ALTER TABLE ops_daily_logs
ADD COLUMN IF NOT EXISTS proof_photo_url TEXT;

-- 2. Shift Handover table
CREATE TABLE IF NOT EXISTS ops_shift_handovers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id UUID NOT NULL,
  from_shift_id UUID REFERENCES store_shift_configs(id),
  to_shift_id UUID REFERENCES store_shift_configs(id),
  handover_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_by UUID NOT NULL,
  created_by_name TEXT NOT NULL DEFAULT '',
  issues TEXT,
  notes TEXT,
  pending_tasks TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Storage bucket for proof photos (run separately if needed)
-- INSERT INTO storage.buckets (id, name, public) VALUES ('ops-photos', 'ops-photos', true)
-- ON CONFLICT (id) DO NOTHING;
