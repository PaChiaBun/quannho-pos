-- =============================================================================
-- Migration: 20261001_create_store_shift_configs.sql
-- Mô tả: Khắc phục lỗi thiếu bảng ca làm việc public.store_shift_configs (PGRST205)
--       và bổ sung cột khóa ngoại shift_config_id vào bảng public.store_members.
-- Quy chuẩn: qn.md mục 2.43 (Lego Modules SSOT) & ORIGINAL_REQUEST.md (R3).
-- =============================================================================

-- 1. Tạo bảng store_shift_configs
CREATE TABLE IF NOT EXISTS public.store_shift_configs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  start_hour    INTEGER NOT NULL DEFAULT 6,
  start_minute  INTEGER NOT NULL DEFAULT 0,
  end_hour      INTEGER NOT NULL DEFAULT 14,
  end_minute    INTEGER NOT NULL DEFAULT 0,
  color         TEXT NOT NULL DEFAULT '#0EA5E9',
  sort_order    INTEGER NOT NULL DEFAULT 0,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Chỉ mục tối ưu truy vấn nạp ca theo quán
CREATE INDEX IF NOT EXISTS idx_store_shift_configs_store_id
  ON public.store_shift_configs(store_id, is_active);

-- 3. Tắt RLS và cấp toàn quyền (Đồng bộ với add_auth_tables.sql & add_staff_tables.sql)
ALTER TABLE public.store_shift_configs DISABLE ROW LEVEL SECURITY;

GRANT ALL ON TABLE public.store_shift_configs TO anon, authenticated, service_role;

-- 4. Bổ sung cột khóa ngoại shift_config_id vào bảng store_members
ALTER TABLE public.store_members
  ADD COLUMN IF NOT EXISTS shift_config_id UUID REFERENCES public.store_shift_configs(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_store_members_shift_config_id
  ON public.store_members(shift_config_id);

-- 5. Bổ sung liên kết phòng vệ cho bảng ops_task_templates (nếu có sử dụng shift_config_id)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'ops_task_templates'
  ) THEN
    ALTER TABLE public.ops_task_templates
      ADD COLUMN IF NOT EXISTS shift_config_id UUID REFERENCES public.store_shift_configs(id) ON DELETE SET NULL;
    CREATE INDEX IF NOT EXISTS idx_ops_task_templates_shift_config
      ON public.ops_task_templates(shift_config_id);
  END IF;
END $$;
