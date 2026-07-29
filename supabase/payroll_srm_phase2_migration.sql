-- ─────────────────────────────────────────────────────────────────────────────
-- Quán Nhỏ POS — Phase 2: Payroll SRM (Staff Relationship Management)
-- Module: Lương (Độc lập, tính năng nâng cao tùy chọn)
-- Migration: Forward-only, additive, rerunnable
-- ─────────────────────────────────────────────────────────────────────────────

-- ============================================================================
-- 1. TABLES
-- ============================================================================

-- 1.1 Bảng Cấu hình (Settings)
CREATE TABLE IF NOT EXISTS public.payroll_srm_settings (
    store_id UUID PRIMARY KEY REFERENCES public.stores(id) ON DELETE CASCADE,
    enable_tam BOOLEAN NOT NULL DEFAULT false,
    enable_tue BOOLEAN NOT NULL DEFAULT false,
    point_rules JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(point_rules) = 'object'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 1.2 Bảng Đề xuất (Proposals)
CREATE TABLE IF NOT EXISTS public.payroll_srm_proposals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    target_user_id UUID NOT NULL REFERENCES public.user_accounts(id),
    proposed_by_user_id UUID NOT NULL REFERENCES public.user_accounts(id),
    reviewer_user_id UUID REFERENCES public.user_accounts(id),
    dimension TEXT NOT NULL CHECK (dimension IN ('tam', 'tue')),
    proposal_type TEXT NOT NULL CHECK (proposal_type IN ('recognition', 'initiative', 'coaching')),
    title TEXT NOT NULL CHECK (btrim(title) <> ''),
    description TEXT,
    evidence JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(evidence) = 'object'),
    proposed_points INTEGER NOT NULL CHECK (proposed_points >= 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    review_notes TEXT,
    reviewed_at TIMESTAMPTZ,
    idempotency_key TEXT NOT NULL CHECK (btrim(idempotency_key) <> ''),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_srm_proposals_store_idemp UNIQUE (store_id, idempotency_key),
    CONSTRAINT uq_srm_proposals_id_store UNIQUE (id, store_id),
    CONSTRAINT chk_srm_proposals_reviewer CHECK (
        (status IN ('approved', 'rejected') AND reviewer_user_id IS NOT NULL AND reviewed_at IS NOT NULL) OR
        (status IN ('pending', 'cancelled') AND reviewer_user_id IS NULL AND reviewed_at IS NULL)
    ),
    CONSTRAINT chk_srm_proposals_no_self_approve CHECK (
        reviewer_user_id IS NULL OR reviewer_user_id <> proposed_by_user_id
    )
);

-- 1.3 Bảng Sự kiện Điểm (Point Events - Append Only)
CREATE TABLE IF NOT EXISTS public.payroll_srm_point_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    proposal_id UUID NOT NULL UNIQUE REFERENCES public.payroll_srm_proposals(id),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    target_user_id UUID NOT NULL REFERENCES public.user_accounts(id),
    dimension TEXT NOT NULL CHECK (dimension IN ('tam', 'tue')),
    points INTEGER NOT NULL CHECK (points > 0),
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by_user_id UUID NOT NULL REFERENCES public.user_accounts(id),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_srm_point_events_proposal_store FOREIGN KEY (proposal_id, store_id)
        REFERENCES public.payroll_srm_proposals (id, store_id)
);

-- 1.4 Bảng Lịch sử Audit (Audit Events - Append Only)
CREATE TABLE IF NOT EXISTS public.payroll_srm_audit_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    actor_user_id UUID REFERENCES public.user_accounts(id),
    entity_type TEXT NOT NULL CHECK (btrim(entity_type) <> ''),
    entity_id UUID NOT NULL,
    action TEXT NOT NULL CHECK (btrim(action) <> ''),
    before_data JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(before_data) = 'object'),
    after_data JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(after_data) = 'object'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================================
-- 2. INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_srm_settings_store ON public.payroll_srm_settings(store_id);

CREATE INDEX IF NOT EXISTS idx_srm_proposals_store_target ON public.payroll_srm_proposals(store_id, target_user_id);
CREATE INDEX IF NOT EXISTS idx_srm_proposals_status ON public.payroll_srm_proposals(store_id, status);

CREATE INDEX IF NOT EXISTS idx_srm_point_events_store_target ON public.payroll_srm_point_events(store_id, target_user_id);
CREATE INDEX IF NOT EXISTS idx_srm_point_events_proposal ON public.payroll_srm_point_events(proposal_id);

CREATE INDEX IF NOT EXISTS idx_srm_audit_events_store_entity ON public.payroll_srm_audit_events(store_id, entity_type, entity_id);


-- ============================================================================
-- 3. UPDATED_AT TRIGGER (Idempotent, Safe search_path)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.payroll_srm_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = current_timestamp;
    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_payroll_srm_settings_updated_at'
        AND tgrelid = 'public.payroll_srm_settings'::regclass
    ) THEN
        CREATE TRIGGER trg_payroll_srm_settings_updated_at
        BEFORE UPDATE ON public.payroll_srm_settings
        FOR EACH ROW EXECUTE FUNCTION public.payroll_srm_set_updated_at();
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'trg_payroll_srm_proposals_updated_at'
        AND tgrelid = 'public.payroll_srm_proposals'::regclass
    ) THEN
        CREATE TRIGGER trg_payroll_srm_proposals_updated_at
        BEFORE UPDATE ON public.payroll_srm_proposals
        FOR EACH ROW EXECUTE FUNCTION public.payroll_srm_set_updated_at();
    END IF;
END $$;


-- ============================================================================
-- 4. ROW LEVEL SECURITY (RLS) & POLICIES
-- ============================================================================

ALTER TABLE public.payroll_srm_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_srm_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_srm_point_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_srm_audit_events ENABLE ROW LEVEL SECURITY;

-- Lưu ý Trust Boundary: P2 RLS chỉ cách ly store theo x-store-id, quyền actions + người duyệt thật + chuyển status + tạo ledger nguyên tử sẽ do RPC/repository P3 phụ trách. Client không được coi policy store-only là quyền duyệt.

-- 4.1 Settings
DO $$ BEGIN
    CREATE POLICY "srm_settings_isolation_select" ON public.payroll_srm_settings FOR SELECT USING (store_id = public.current_store_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "srm_settings_isolation_insert" ON public.payroll_srm_settings FOR INSERT WITH CHECK (store_id = public.current_store_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "srm_settings_isolation_update" ON public.payroll_srm_settings FOR UPDATE USING (store_id = public.current_store_id()) WITH CHECK (store_id = public.current_store_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 4.2 Proposals
DO $$ BEGIN
    CREATE POLICY "srm_proposals_isolation_select" ON public.payroll_srm_proposals FOR SELECT USING (store_id = public.current_store_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "srm_proposals_isolation_insert" ON public.payroll_srm_proposals FOR INSERT WITH CHECK (store_id = public.current_store_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "srm_proposals_isolation_update" ON public.payroll_srm_proposals FOR UPDATE USING (store_id = public.current_store_id()) WITH CHECK (store_id = public.current_store_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 4.3 Point Events (Append Only)
DO $$ BEGIN
    CREATE POLICY "srm_point_events_isolation_select" ON public.payroll_srm_point_events FOR SELECT USING (store_id = public.current_store_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    -- Policy đảm bảo cross-store an toàn và thông tin đồng nhất với proposal đã duyệt.
    CREATE POLICY "srm_point_events_isolation_insert" ON public.payroll_srm_point_events FOR INSERT WITH CHECK (
        store_id = public.current_store_id() AND
        EXISTS (
            SELECT 1 FROM public.payroll_srm_proposals p
            WHERE p.id = public.payroll_srm_point_events.proposal_id
              AND p.store_id = public.payroll_srm_point_events.store_id
              AND p.status = 'approved'
              AND p.target_user_id = public.payroll_srm_point_events.target_user_id
              AND p.dimension = public.payroll_srm_point_events.dimension
              AND p.proposed_points = public.payroll_srm_point_events.points
        )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 4.4 Audit Events (Append Only)
DO $$ BEGIN
    CREATE POLICY "srm_audit_events_isolation_select" ON public.payroll_srm_audit_events FOR SELECT USING (store_id = public.current_store_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "srm_audit_events_isolation_insert" ON public.payroll_srm_audit_events FOR INSERT WITH CHECK (store_id = public.current_store_id());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ============================================================================
-- 5. GRANTS
-- ============================================================================

-- Đảm bảo không còn quyền dư thừa trước khi gán
REVOKE DELETE ON public.payroll_srm_settings FROM anon, authenticated;
REVOKE DELETE ON public.payroll_srm_proposals FROM anon, authenticated;
REVOKE UPDATE, DELETE ON public.payroll_srm_point_events FROM anon, authenticated;
REVOKE UPDATE, DELETE ON public.payroll_srm_audit_events FROM anon, authenticated;

-- Settings & Proposals: SELECT, INSERT, UPDATE.
GRANT SELECT, INSERT, UPDATE ON public.payroll_srm_settings TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.payroll_srm_proposals TO anon, authenticated;

-- Point & Audit events: Append-only
GRANT SELECT, INSERT ON public.payroll_srm_point_events TO anon, authenticated;
GRANT SELECT, INSERT ON public.payroll_srm_audit_events TO anon, authenticated;


-- ============================================================================
-- 6. PREFLIGHT / VERIFY
-- ============================================================================

-- Kiểm tra RLS cho các bảng P2
SELECT c.relname, c.relrowsecurity
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname LIKE 'payroll_srm_%';

-- Lấy danh sách cột
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name LIKE 'payroll_srm_%'
ORDER BY table_name, ordinal_position;

-- Lấy thông tin indexes
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename LIKE 'payroll_srm_%';

-- Lấy thông tin policies
SELECT tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename LIKE 'payroll_srm_%';

-- Lấy thông tin grants cho anon và authenticated
SELECT grantee, privilege_type, table_name
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name LIKE 'payroll_srm_%'
  AND grantee IN ('anon', 'authenticated');

-- Cảnh báo về bảng payroll_records
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'payroll_records';

-- ─────────────────────────────────────────────────────────────────────────────
-- Chú ý (Chỉ chạy thủ công): Lệnh sau kiểm tra duplicated records trong DB.
-- Vì Postgres báo lỗi lúc parse nếu table không tồn tại, nên truy vấn này
-- được comment lại. Phải đảm bảo `payroll_records` tồn tại trước khi chạy.
--
-- SELECT period_id, user_id, COUNT(*) AS duplicate_count
-- FROM public.payroll_records
-- GROUP BY period_id, user_id
-- HAVING COUNT(*) > 1;
-- ─────────────────────────────────────────────────────────────────────────────
