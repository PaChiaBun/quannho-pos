-- =====================================================================
-- KAY OPS MIGRATION — Nhật Ký Vận Hành
-- Chạy 1 lần trên Supabase SQL Editor
-- =====================================================================

-- 1. Bảng mẫu công việc
CREATE TABLE IF NOT EXISTS public.ops_task_templates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id        UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  store_role_id   UUID REFERENCES public.store_roles(id) ON DELETE SET NULL, -- null = tất cả roles
  title           TEXT NOT NULL,           -- "Vệ sinh Toilet lần 1"
  description     TEXT,                   -- Mô tả chi tiết, hướng dẫn thực hiện
  target_time     TEXT,                   -- "09:00" | "13:00" | "Cuối ca" | null
  sort_order      INTEGER NOT NULL DEFAULT 0,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ops_templates_store
  ON public.ops_task_templates(store_id, is_active);
CREATE INDEX IF NOT EXISTS idx_ops_templates_role
  ON public.ops_task_templates(store_role_id);

-- 2. Bảng nhật ký thực thi — log riêng cho từng nhân viên
CREATE TABLE IF NOT EXISTS public.ops_daily_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id        UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  template_id     UUID NOT NULL REFERENCES public.ops_task_templates(id) ON DELETE CASCADE,
  log_date        DATE NOT NULL DEFAULT CURRENT_DATE,   -- nhóm theo ngày
  staff_id        UUID,                                 -- store_members.id (snapshot)
  staff_name      TEXT,                                 -- SNAPSHOT tên lúc tick
  status          TEXT NOT NULL DEFAULT 'pending',      -- pending | completed | missed
  completed_at    TIMESTAMPTZ,
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Mỗi nhân viên chỉ có 1 log/template/ngày
CREATE UNIQUE INDEX IF NOT EXISTS idx_ops_logs_unique
  ON public.ops_daily_logs(template_id, log_date, staff_id);

CREATE INDEX IF NOT EXISTS idx_ops_logs_store_date
  ON public.ops_daily_logs(store_id, log_date, status);
CREATE INDEX IF NOT EXISTS idx_ops_logs_staff
  ON public.ops_daily_logs(staff_id, log_date);

-- 3. GRANT (đồng bộ với toàn dự án)
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.ops_task_templates TO anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.ops_daily_logs TO anon, authenticated;

-- 4. Xác nhận
SELECT table_name, COUNT(*) AS columns
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('ops_task_templates', 'ops_daily_logs')
GROUP BY table_name ORDER BY table_name;

-- =====================================================================
-- 5. ROW LEVEL SECURITY (RLS)
-- Manager / Owner → full access
-- Nhân viên        → chỉ đọc template, chỉ ghi/đọc log của chính mình
-- =====================================================================

ALTER TABLE public.ops_task_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ops_daily_logs     ENABLE ROW LEVEL SECURITY;

-- Helper: kiểm tra role trong store
CREATE OR REPLACE FUNCTION public.ops_is_manager(p_store_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.store_members
    WHERE user_id  = auth.uid()
      AND store_id = p_store_id
      AND role     IN ('owner', 'manager')
  );
$$;

-- Helper: lấy store_member.id của user hiện tại trong store
CREATE OR REPLACE FUNCTION public.ops_my_member_id(p_store_id UUID)
RETURNS UUID LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT id FROM public.store_members
  WHERE user_id  = auth.uid()
    AND store_id = p_store_id
  LIMIT 1;
$$;

-- ── ops_task_templates ──────────────────────────────────────────────

-- Đọc: tất cả thành viên store đều đọc được template (để hiển thị nhiệm vụ)
CREATE POLICY "tmpl_select_all_members"
  ON public.ops_task_templates FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.store_members sm
      WHERE sm.user_id  = auth.uid()
        AND sm.store_id = ops_task_templates.store_id
    )
  );

-- Ghi (INSERT/UPDATE/DELETE): chỉ manager & owner
CREATE POLICY "tmpl_write_manager_only"
  ON public.ops_task_templates FOR ALL
  USING  (public.ops_is_manager(store_id))
  WITH CHECK (public.ops_is_manager(store_id));

-- ── ops_daily_logs ──────────────────────────────────────────────────

-- Manager/Owner đọc toàn bộ log của store
CREATE POLICY "log_select_manager"
  ON public.ops_daily_logs FOR SELECT
  USING (public.ops_is_manager(store_id));

-- Nhân viên chỉ đọc log của chính mình
CREATE POLICY "log_select_own"
  ON public.ops_daily_logs FOR SELECT
  USING (staff_id = public.ops_my_member_id(store_id));

-- Nhân viên INSERT log của chính mình
CREATE POLICY "log_insert_own"
  ON public.ops_daily_logs FOR INSERT
  WITH CHECK (staff_id = public.ops_my_member_id(store_id));

-- Nhân viên UPDATE log của chính mình
CREATE POLICY "log_update_own"
  ON public.ops_daily_logs FOR UPDATE
  USING (staff_id = public.ops_my_member_id(store_id));

-- Manager/Owner UPDATE/DELETE bất kỳ log trong store
CREATE POLICY "log_write_manager"
  ON public.ops_daily_logs FOR ALL
  USING  (public.ops_is_manager(store_id))
  WITH CHECK (public.ops_is_manager(store_id));
