-- E-INVOICE FOUNDATION v1 (16/10/2026) — công tắc hóa đơn điện tử theo quán + bảng lưu hóa đơn + báo cáo.
-- Phạm vi: chỉ NỀN TẢNG. Chưa có worker phát hành meInvoice, chưa đụng settlement v5, chưa có thuế suất theo món.
--   Tắt/bật KHÔNG ảnh hưởng việc ghi bill/doanh thu: mọi bill vẫn ghi đầy đủ ở orders/payment_settlements/finance_records.
-- Bảo mật: ghi chỉ qua RPC SECURITY DEFINER (chủ quán) hoặc service_role (worker sau này). authenticated chỉ ĐỌC theo quán.
-- Áp dụng: CHƯA áp lên production. Cần Chủ quán duyệt, chạy thử trên bản sao trước.
-- Hoàn tác: 20261016_einvoice_foundation_v1_ROLLBACK.sql
BEGIN;
SET LOCAL search_path = public, pg_catalog, pg_temp;

-- 1) Cấu hình công tắc theo quán (mặc định TẮT)
CREATE TABLE IF NOT EXISTS public.einvoice_store_config (
  store_id   uuid PRIMARY KEY REFERENCES public.stores(id) ON DELETE CASCADE,
  enabled    boolean NOT NULL DEFAULT false,
  updated_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 2) Nhật ký thay đổi công tắc
CREATE TABLE IF NOT EXISTS public.einvoice_audit_logs (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  actor_user_id uuid,
  action        text NOT NULL,
  old_value     jsonb,
  new_value     jsonb,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_einvoice_audit_store_created
  ON public.einvoice_audit_logs(store_id, created_at DESC);

-- 3) Hóa đơn điện tử theo bill (worker meInvoice sẽ ghi bằng service_role)
CREATE TABLE IF NOT EXISTS public.einvoice_documents (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id                uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  source_type             text NOT NULL CHECK (source_type IN ('settlement', 'order')),
  source_id               uuid NOT NULL,
  provider                text NOT NULL DEFAULT 'misa_meinvoice',
  ref_id                  text NOT NULL,                      -- khóa chống trùng gửi nhà cung cấp (RefID)
  status                  text NOT NULL DEFAULT 'queued'
                          CHECK (status IN ('queued', 'issued', 'pending_code', 'rejected', 'failed', 'cancelled')),
  total_amount            numeric NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  invoice_date            timestamptz NOT NULL DEFAULT now(),
  inv_template_no         text,
  inv_series              text,
  inv_no                  text,
  tax_authority_code      text,                                -- mã cơ quan thuế cấp (hóa đơn máy tính tiền)
  provider_transaction_id text,
  error_code              text,
  error_message           text,
  attempts                integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  issued_at               timestamptz,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_einvoice_documents_ref UNIQUE (store_id, provider, ref_id)
);
CREATE INDEX IF NOT EXISTS idx_einvoice_documents_store_date
  ON public.einvoice_documents(store_id, invoice_date DESC);
CREATE INDEX IF NOT EXISTS idx_einvoice_documents_store_status
  ON public.einvoice_documents(store_id, status);
CREATE INDEX IF NOT EXISTS idx_einvoice_documents_source
  ON public.einvoice_documents(store_id, source_type, source_id);

-- 4) RLS: chỉ đọc theo quán; không có policy ghi cho authenticated
ALTER TABLE public.einvoice_store_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.einvoice_audit_logs   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.einvoice_documents    ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS einvoice_store_config_isolation ON public.einvoice_store_config;
CREATE POLICY einvoice_store_config_isolation ON public.einvoice_store_config
  FOR SELECT TO authenticated USING (store_id = public.current_store_id());

DROP POLICY IF EXISTS einvoice_audit_logs_isolation ON public.einvoice_audit_logs;
CREATE POLICY einvoice_audit_logs_isolation ON public.einvoice_audit_logs
  FOR SELECT TO authenticated USING (store_id = public.current_store_id());

DROP POLICY IF EXISTS einvoice_documents_isolation ON public.einvoice_documents;
CREATE POLICY einvoice_documents_isolation ON public.einvoice_documents
  FOR SELECT TO authenticated USING (store_id = public.current_store_id());

REVOKE ALL ON TABLE public.einvoice_store_config, public.einvoice_audit_logs, public.einvoice_documents
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.einvoice_store_config, public.einvoice_audit_logs, public.einvoice_documents
  TO authenticated;
GRANT ALL ON TABLE public.einvoice_store_config, public.einvoice_audit_logs, public.einvoice_documents
  TO service_role;

-- 5) RPC bật/tắt công tắc: chỉ Chủ quán, ghi audit cùng giao dịch
CREATE OR REPLACE FUNCTION public.set_einvoice_enabled_v1(p_enabled boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_store    uuid := public.current_store_id();
  v_user     uuid := public.qn_caller_id();
  v_is_owner boolean := false;
  v_old      boolean;
BEGIN
  IF p_enabled IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_PARAM');
  END IF;
  IF v_store IS NULL OR v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHENTICATED');
  END IF;

  SELECT COALESCE(m.is_owner, false) OR m.role = 'owner'
    INTO v_is_owner
    FROM public.store_members m
   WHERE m.store_id = v_store AND m.user_id = v_user
   LIMIT 1;
  IF NOT COALESCE(v_is_owner, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'OWNER_ONLY');
  END IF;

  -- Khóa theo quán để hai lần đổi đồng thời không ghi audit chéo nhau
  PERFORM pg_advisory_xact_lock(hashtextextended('einvoice_cfg:' || v_store::text, 0));

  SELECT c.enabled INTO v_old FROM public.einvoice_store_config c WHERE c.store_id = v_store;

  INSERT INTO public.einvoice_store_config AS c (store_id, enabled, updated_by, updated_at)
  VALUES (v_store, p_enabled, v_user, now())
  ON CONFLICT (store_id) DO UPDATE
    SET enabled = EXCLUDED.enabled, updated_by = EXCLUDED.updated_by, updated_at = EXCLUDED.updated_at;

  IF v_old IS DISTINCT FROM p_enabled THEN
    INSERT INTO public.einvoice_audit_logs (store_id, actor_user_id, action, old_value, new_value)
    VALUES (v_store, v_user, 'set_enabled',
            jsonb_build_object('enabled', COALESCE(v_old, false)),
            jsonb_build_object('enabled', p_enabled));
  END IF;

  RETURN jsonb_build_object('success', true, 'enabled', p_enabled, 'changed', v_old IS DISTINCT FROM p_enabled);
END
$fn$;
REVOKE ALL ON FUNCTION public.set_einvoice_enabled_v1(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_einvoice_enabled_v1(boolean) TO authenticated, service_role;

-- 6) RPC báo cáo: tổng hợp theo trạng thái trong khoảng [p_from, p_to). SECURITY INVOKER nên RLS theo quán vẫn áp dụng.
CREATE OR REPLACE FUNCTION public.einvoice_report_v1(p_from timestamptz, p_to timestamptz)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = public, pg_catalog, pg_temp
AS $fn$
  WITH d AS (
    SELECT status, total_amount
      FROM public.einvoice_documents
     WHERE store_id = public.current_store_id()
       AND invoice_date >= p_from AND invoice_date < p_to
  )
  SELECT jsonb_build_object(
    'enabled', COALESCE((SELECT enabled FROM public.einvoice_store_config
                          WHERE store_id = public.current_store_id()), false),
    'issued_amount',    COALESCE(SUM(total_amount) FILTER (WHERE status = 'issued'), 0),
    'issued_count',     COUNT(*) FILTER (WHERE status = 'issued'),
    'pending_amount',   COALESCE(SUM(total_amount) FILTER (WHERE status IN ('queued', 'pending_code')), 0),
    'pending_count',    COUNT(*) FILTER (WHERE status IN ('queued', 'pending_code')),
    'problem_amount',   COALESCE(SUM(total_amount) FILTER (WHERE status IN ('rejected', 'failed')), 0),
    'problem_count',    COUNT(*) FILTER (WHERE status IN ('rejected', 'failed')),
    'cancelled_amount', COALESCE(SUM(total_amount) FILTER (WHERE status = 'cancelled'), 0),
    'cancelled_count',  COUNT(*) FILTER (WHERE status = 'cancelled')
  )
  FROM d;
$fn$;
REVOKE ALL ON FUNCTION public.einvoice_report_v1(timestamptz, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.einvoice_report_v1(timestamptz, timestamptz) TO authenticated, service_role;

-- 7) Kiểm tra sau áp
DO $$
BEGIN
  IF has_table_privilege('anon', 'public.einvoice_documents', 'select')
     OR has_table_privilege('authenticated', 'public.einvoice_documents', 'insert')
     OR has_table_privilege('authenticated', 'public.einvoice_store_config', 'update') THEN
    RAISE EXCEPTION 'E-INVOICE v1: quyền bảng không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
