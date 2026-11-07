-- Hoàn tác CHUỖI CỬA HÀNG báo cáo v1.1: trả get_chain_report_v1 về định nghĩa gốc (không có gross_revenue, void_*, first_order_at, wallet_revenue).
-- Giữ nguyên chữ ký/quyền; client mới tự bỏ qua trường vắng (coi là "không rõ").
BEGIN;
SET LOCAL search_path = public, pg_catalog, pg_temp;
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


DROP INDEX IF EXISTS public.idx_void_audit_store_created;
COMMIT;
NOTIFY pgrst, 'reload schema';
