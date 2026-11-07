-- ============================================================================
-- CHUỖI CỬA HÀNG v1 (17/10/2026) — nền tảng chuỗi + báo cáo tổng hợp cho Chủ quán.
-- Hoàn tác: 20261017_chuoi_cua_hang_v1_ROLLBACK.sql   |   Test: supabase/tests/chuoi_cua_hang_v1_test.sql
--
-- Phạm vi (giai đoạn 1 + 2):
--   GĐ1  Thực thể chuỗi do CHỦ QUÁN tạo; thêm/gỡ từng cửa hàng chủ động; audit; khóa tenant.
--   GĐ2  RPC báo cáo tổng hợp theo chuỗi: số liệu từng cửa hàng + tổng + doanh thu theo ngày.
-- KHÔNG làm ở bản này: chung Ví/điểm loyalty, chung khách, chung menu/kho/nhân viên.
--   Dữ liệu vận hành vẫn tách theo store_id; chuỗi chỉ là "lớp đọc tổng hợp" cho chủ.
--
-- Bất biến bảo mật:
--   * Không bỏ filter store_id ở bất kỳ bảng vận hành nào; báo cáo chuỗi chỉ ĐỌC orders theo danh sách store
--     mà người gọi VẪN LÀ CHỦ (qn_is_store_owner) tại thời điểm gọi.
--   * Chỉ Chủ quán (is_owner / role owner / stores.owner_user_id) tạo chuỗi và thêm cửa hàng. Quản lý KHÔNG được.
--   * Một cửa hàng chỉ thuộc tối đa 1 chuỗi đang hoạt động (unique index một phần).
--   * Ghi chỉ qua RPC SECURITY DEFINER (có audit cùng giao dịch); authenticated chỉ ĐỌC chuỗi của mình.
--   * Báo cáo chuỗi chỉ trả số tổng hợp theo cửa hàng; KHÔNG có KPI/danh sách cá nhân nhân viên xuyên chuỗi.
-- Áp dụng: CHƯA áp production. Chạy thử trên bản sao (db-fix/chuoi_stage_dryrun.sh) trước.
-- ============================================================================
BEGIN;
SET LOCAL search_path = public, pg_catalog, pg_temp;

-- 0) Preflight: phụ thuộc phải có sẵn
DO $$
BEGIN
  IF to_regclass('public.stores') IS NULL OR to_regclass('public.store_members') IS NULL
     OR to_regclass('public.user_accounts') IS NULL OR to_regclass('public.orders') IS NULL THEN
    RAISE EXCEPTION 'CHUOI v1 PREFLIGHT: thiếu bảng stores/store_members/user_accounts/orders';
  END IF;
  IF to_regprocedure('public.qn_caller_id()') IS NULL THEN
    RAISE EXCEPTION 'CHUOI v1 PREFLIGHT: thiếu hàm qn_caller_id() (cần migration fix04 trước)';
  END IF;
END $$;

-- 1) Bảng
CREATE TABLE IF NOT EXISTS public.store_chains (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 80),
  owner_user_id uuid NOT NULL REFERENCES public.user_accounts(id),
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_store_chains_owner ON public.store_chains(owner_user_id);

CREATE TABLE IF NOT EXISTS public.store_chain_stores (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id   uuid NOT NULL REFERENCES public.store_chains(id) ON DELETE CASCADE,
  store_id   uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  joined_at  timestamptz NOT NULL DEFAULT now(),
  left_at    timestamptz,
  added_by   uuid,
  removed_by uuid,
  CHECK (left_at IS NULL OR left_at >= joined_at)
);
-- Một cửa hàng chỉ ở 1 chuỗi đang hoạt động; lịch sử (left_at != null) được giữ
CREATE UNIQUE INDEX IF NOT EXISTS uq_store_chain_stores_active_store
  ON public.store_chain_stores(store_id) WHERE left_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_store_chain_stores_chain_active
  ON public.store_chain_stores(chain_id) WHERE left_at IS NULL;

CREATE TABLE IF NOT EXISTS public.store_chain_audit_logs (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id      uuid,
  store_id      uuid,
  actor_user_id uuid,
  action        text NOT NULL,
  detail        jsonb,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_store_chain_audit_chain_created
  ON public.store_chain_audit_logs(chain_id, created_at DESC);

-- 2) Hàm hỗ trợ: người gọi có phải CHỦ của cửa hàng (không tính Quản lý)
CREATE OR REPLACE FUNCTION public.qn_is_store_owner(p_store uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT p_store IS NOT NULL AND public.qn_caller_id() IS NOT NULL AND (
    EXISTS (SELECT 1 FROM public.store_members m
             WHERE m.store_id = p_store AND m.user_id = public.qn_caller_id()
               AND (COALESCE(m.is_owner, false) OR lower(m.role) = 'owner'))
    OR EXISTS (SELECT 1 FROM public.stores s
                WHERE s.id = p_store AND s.owner_user_id = public.qn_caller_id()));
$$;
REVOKE ALL ON FUNCTION public.qn_is_store_owner(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.qn_is_store_owner(uuid) TO authenticated, service_role;

-- 3) RLS: authenticated chỉ ĐỌC chuỗi do mình sở hữu; ghi qua RPC
ALTER TABLE public.store_chains          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_chain_stores    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_chain_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS store_chains_owner_select ON public.store_chains;
CREATE POLICY store_chains_owner_select ON public.store_chains
  FOR SELECT TO authenticated USING (owner_user_id = public.qn_caller_id());

DROP POLICY IF EXISTS store_chain_stores_owner_select ON public.store_chain_stores;
CREATE POLICY store_chain_stores_owner_select ON public.store_chain_stores
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.store_chains c
             WHERE c.id = chain_id AND c.owner_user_id = public.qn_caller_id()));

DROP POLICY IF EXISTS store_chain_audit_owner_select ON public.store_chain_audit_logs;
CREATE POLICY store_chain_audit_owner_select ON public.store_chain_audit_logs
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.store_chains c
             WHERE c.id = chain_id AND c.owner_user_id = public.qn_caller_id()));

REVOKE ALL ON TABLE public.store_chains, public.store_chain_stores, public.store_chain_audit_logs
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.store_chains, public.store_chain_stores, public.store_chain_audit_logs
  TO authenticated;
GRANT ALL ON TABLE public.store_chains, public.store_chain_stores, public.store_chain_audit_logs
  TO service_role;

-- 4) RPC: tạo chuỗi
CREATE OR REPLACE FUNCTION public.create_store_chain_v1(p_name text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_user uuid := public.qn_caller_id();
  v_name text := btrim(COALESCE(p_name, ''));
  v_id   uuid;
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'UNAUTHENTICATED'); END IF;
  IF char_length(v_name) < 1 OR char_length(v_name) > 80 THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_NAME');
  END IF;
  -- Phải là chủ của ít nhất một cửa hàng
  IF NOT EXISTS (
    SELECT 1 FROM public.store_members m
     WHERE m.user_id = v_user AND (COALESCE(m.is_owner, false) OR lower(m.role) = 'owner')
    UNION ALL
    SELECT 1 FROM public.stores s WHERE s.owner_user_id = v_user
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'OWNER_ONLY');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('chain_create:' || v_user::text, 0));
  IF (SELECT count(*) FROM public.store_chains WHERE owner_user_id = v_user) >= 20 THEN
    RETURN jsonb_build_object('success', false, 'error', 'TOO_MANY_CHAINS');
  END IF;
  IF EXISTS (SELECT 1 FROM public.store_chains WHERE owner_user_id = v_user AND lower(name) = lower(v_name)) THEN
    RETURN jsonb_build_object('success', false, 'error', 'DUPLICATE_NAME');
  END IF;

  INSERT INTO public.store_chains (name, owner_user_id) VALUES (v_name, v_user) RETURNING id INTO v_id;
  INSERT INTO public.store_chain_audit_logs (chain_id, actor_user_id, action, detail)
  VALUES (v_id, v_user, 'create_chain', jsonb_build_object('name', v_name));
  RETURN jsonb_build_object('success', true, 'chain_id', v_id);
END
$fn$;

-- 5) RPC: thêm cửa hàng vào chuỗi (chủ chuỗi + chủ cửa hàng)
CREATE OR REPLACE FUNCTION public.add_store_to_chain_v1(p_chain uuid, p_store uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_user uuid := public.qn_caller_id();
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'UNAUTHENTICATED'); END IF;
  IF p_chain IS NULL OR p_store IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'INVALID_PARAM'); END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('chain_store:' || p_store::text, 0));

  IF NOT EXISTS (SELECT 1 FROM public.store_chains WHERE id = p_chain AND owner_user_id = v_user) THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHAIN_NOT_FOUND');
  END IF;
  IF NOT public.qn_is_store_owner(p_store) THEN
    RETURN jsonb_build_object('success', false, 'error', 'STORE_OWNER_ONLY');
  END IF;
  IF EXISTS (SELECT 1 FROM public.store_chain_stores WHERE store_id = p_store AND left_at IS NULL) THEN
    RETURN jsonb_build_object('success', false, 'error', 'STORE_ALREADY_IN_CHAIN');
  END IF;
  IF (SELECT count(*) FROM public.store_chain_stores WHERE chain_id = p_chain AND left_at IS NULL) >= 50 THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHAIN_FULL');
  END IF;

  INSERT INTO public.store_chain_stores (chain_id, store_id, added_by) VALUES (p_chain, p_store, v_user);
  INSERT INTO public.store_chain_audit_logs (chain_id, store_id, actor_user_id, action)
  VALUES (p_chain, p_store, v_user, 'add_store');
  RETURN jsonb_build_object('success', true);
END
$fn$;

-- 6) RPC: gỡ cửa hàng khỏi chuỗi (giữ lịch sử)
CREATE OR REPLACE FUNCTION public.remove_store_from_chain_v1(p_chain uuid, p_store uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_user uuid := public.qn_caller_id();
  v_n    integer;
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'UNAUTHENTICATED'); END IF;
  IF p_chain IS NULL OR p_store IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'INVALID_PARAM'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.store_chains WHERE id = p_chain AND owner_user_id = v_user) THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHAIN_NOT_FOUND');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('chain_store:' || p_store::text, 0));
  UPDATE public.store_chain_stores
     SET left_at = now(), removed_by = v_user
   WHERE chain_id = p_chain AND store_id = p_store AND left_at IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n = 0 THEN RETURN jsonb_build_object('success', false, 'error', 'STORE_NOT_IN_CHAIN'); END IF;

  INSERT INTO public.store_chain_audit_logs (chain_id, store_id, actor_user_id, action)
  VALUES (p_chain, p_store, v_user, 'remove_store');
  RETURN jsonb_build_object('success', true);
END
$fn$;

-- 7) RPC: danh sách chuỗi của tôi + cửa hàng tôi sở hữu (để màn hình chọn)
CREATE OR REPLACE FUNCTION public.list_my_chains_v1()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_user uuid := public.qn_caller_id();
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'UNAUTHENTICATED'); END IF;
  RETURN jsonb_build_object(
    'success', true,
    'chains', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', c.id, 'name', c.name, 'created_at', c.created_at,
        'stores', COALESCE((
          SELECT jsonb_agg(jsonb_build_object('store_id', s.id, 'name', s.name, 'store_code', s.store_code,
                                              'joined_at', cs.joined_at) ORDER BY cs.joined_at)
            FROM public.store_chain_stores cs JOIN public.stores s ON s.id = cs.store_id
           WHERE cs.chain_id = c.id AND cs.left_at IS NULL), '[]'::jsonb)
      ) ORDER BY c.created_at)
      FROM public.store_chains c WHERE c.owner_user_id = v_user), '[]'::jsonb),
    'owned_stores', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'store_id', s.id, 'name', s.name, 'store_code', s.store_code,
        'chain_id', (SELECT cs.chain_id FROM public.store_chain_stores cs
                      WHERE cs.store_id = s.id AND cs.left_at IS NULL)) ORDER BY s.name)
      FROM public.stores s WHERE public.qn_is_store_owner(s.id)), '[]'::jsonb)
  );
END
$fn$;

-- 8) GĐ2 — Báo cáo tổng hợp chuỗi: số theo từng cửa hàng + tổng + doanh thu theo ngày.
--    Số liệu khớp get_report_stats_for_range_v1 / get_daily_revenue_for_range_v1 (orders.status='completed').
--    Chỉ gồm cửa hàng đang trong chuỗi VÀ người gọi vẫn là chủ; cửa hàng còn lại liệt kê ở excluded_stores.
CREATE OR REPLACE FUNCTION public.get_chain_report_v1(
  p_chain uuid, p_from timestamptz, p_to timestamptz, p_tz text DEFAULT 'Asia/Ho_Chi_Minh')
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_user uuid := public.qn_caller_id();
  v_tz   text := COALESCE(NULLIF(btrim(p_tz), ''), 'Asia/Ho_Chi_Minh');
  v_chain_name text;
  v_ids  uuid[];
  v_excl jsonb;
  v_stores jsonb;
  v_daily  jsonb;
  v_tot    jsonb;
BEGIN
  IF v_user IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'UNAUTHENTICATED'); END IF;
  IF p_chain IS NULL OR p_from IS NULL OR p_to IS NULL OR p_to <= p_from OR p_to - p_from > interval '367 days' THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_RANGE');
  END IF;
  BEGIN PERFORM now() AT TIME ZONE v_tz; EXCEPTION WHEN OTHERS THEN v_tz := 'Asia/Ho_Chi_Minh'; END;

  SELECT c.name INTO v_chain_name FROM public.store_chains c WHERE c.id = p_chain AND c.owner_user_id = v_user;
  IF v_chain_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'CHAIN_NOT_FOUND'); END IF;

  SELECT COALESCE(array_agg(cs.store_id), '{}') INTO v_ids
    FROM public.store_chain_stores cs
   WHERE cs.chain_id = p_chain AND cs.left_at IS NULL AND public.qn_is_store_owner(cs.store_id);

  SELECT COALESCE(jsonb_agg(jsonb_build_object('store_id', s.id, 'name', s.name, 'reason', 'NOT_OWNER_ANYMORE')), '[]'::jsonb)
    INTO v_excl
    FROM public.store_chain_stores cs JOIN public.stores s ON s.id = cs.store_id
   WHERE cs.chain_id = p_chain AND cs.left_at IS NULL AND NOT (cs.store_id = ANY (v_ids));

  WITH agg AS (
    SELECT o.store_id,
           COUNT(*)::bigint AS orders,
           COALESCE(SUM(COALESCE(o.total_amount, o.total, 0)), 0) AS revenue,
           COALESCE(SUM(CASE WHEN lower(btrim(COALESCE(o.payment_method, 'cash'))) = 'cash'
                             THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END), 0) AS cash,
           COALESCE(SUM(CASE WHEN lower(btrim(COALESCE(o.payment_method, 'cash'))) NOT IN ('cash', 'card', 'wallet')
                             THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END), 0) AS transfer,
           COALESCE(SUM(CASE WHEN lower(btrim(COALESCE(o.payment_method, 'cash'))) = 'card'
                             THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END), 0) AS card,
           COALESCE(SUM(COALESCE(o.discount, 0)), 0) AS discount
      FROM public.orders o
     WHERE o.store_id = ANY (v_ids) AND o.status = 'completed'
       AND o.created_at >= p_from AND o.created_at < p_to
     GROUP BY o.store_id
  )
  SELECT
    COALESCE(jsonb_agg(jsonb_build_object(
      'store_id', s.id, 'name', s.name, 'store_code', s.store_code,
      'orders', COALESCE(a.orders, 0), 'revenue', COALESCE(a.revenue, 0),
      'avg_order_value', CASE WHEN COALESCE(a.orders, 0) > 0 THEN ROUND(a.revenue / a.orders, 2) ELSE 0 END,
      'cash_revenue', COALESCE(a.cash, 0), 'transfer_revenue', COALESCE(a.transfer, 0),
      'card_revenue', COALESCE(a.card, 0), 'discount', COALESCE(a.discount, 0)
    ) ORDER BY COALESCE(a.revenue, 0) DESC, s.name), '[]'::jsonb),
    jsonb_build_object(
      'orders', COALESCE(SUM(a.orders), 0), 'revenue', COALESCE(SUM(a.revenue), 0),
      'avg_order_value', CASE WHEN COALESCE(SUM(a.orders), 0) > 0 THEN ROUND(SUM(a.revenue) / SUM(a.orders), 2) ELSE 0 END,
      'cash_revenue', COALESCE(SUM(a.cash), 0), 'transfer_revenue', COALESCE(SUM(a.transfer), 0),
      'card_revenue', COALESCE(SUM(a.card), 0), 'discount', COALESCE(SUM(a.discount), 0),
      'store_count', COUNT(*))
    INTO v_stores, v_tot
    FROM public.stores s LEFT JOIN agg a ON a.store_id = s.id
   WHERE s.id = ANY (v_ids);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'date', d.day, 'store_id', d.store_id, 'orders', d.orders, 'revenue', d.revenue)
         ORDER BY d.day, d.store_id), '[]'::jsonb)
    INTO v_daily
    FROM (
      SELECT to_char(o.created_at AT TIME ZONE v_tz, 'YYYY-MM-DD') AS day, o.store_id,
             COUNT(*)::bigint AS orders,
             COALESCE(SUM(COALESCE(o.total_amount, o.total, 0)), 0) AS revenue
        FROM public.orders o
       WHERE o.store_id = ANY (v_ids) AND o.status = 'completed'
         AND o.created_at >= p_from AND o.created_at < p_to
       GROUP BY 1, 2) d;

  RETURN jsonb_build_object('success', true,
    'chain', jsonb_build_object('id', p_chain, 'name', v_chain_name),
    'from', p_from, 'to', p_to, 'tz', v_tz,
    'stores', v_stores, 'totals', v_tot, 'daily', v_daily, 'excluded_stores', v_excl);
END
$fn$;

-- 9) Quyền thực thi: chỉ người đăng nhập (JWT) — anon bị chặn
REVOKE ALL ON FUNCTION public.create_store_chain_v1(text),
                       public.add_store_to_chain_v1(uuid, uuid),
                       public.remove_store_from_chain_v1(uuid, uuid),
                       public.list_my_chains_v1(),
                       public.get_chain_report_v1(uuid, timestamptz, timestamptz, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_store_chain_v1(text),
                          public.add_store_to_chain_v1(uuid, uuid),
                          public.remove_store_from_chain_v1(uuid, uuid),
                          public.list_my_chains_v1(),
                          public.get_chain_report_v1(uuid, timestamptz, timestamptz, text)
  TO authenticated, service_role;

-- 10) Kiểm tra sau áp
DO $$
BEGIN
  IF has_table_privilege('anon', 'public.store_chains', 'select')
     OR has_table_privilege('authenticated', 'public.store_chains', 'insert')
     OR has_table_privilege('authenticated', 'public.store_chain_stores', 'update')
     OR has_function_privilege('anon', 'public.get_chain_report_v1(uuid,timestamptz,timestamptz,text)', 'execute') THEN
    RAISE EXCEPTION 'CHUOI v1: quyền không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
