-- ============================================================================
-- CHUỖI CỬA HÀNG — BÁO CÁO v1.1: thêm trường để nhận xét chính xác (18/10/2026).
-- Hoàn tác: 20261018_chuoi_bao_cao_them_truong_v1_ROLLBACK.sql  |  Test: supabase/tests/chuoi_bao_cao_truong_moi_test.sql
--
-- Thêm vào MỖI cửa hàng (và tổng) của get_chain_report_v1 — chỉ THÊM khóa JSON, không đổi chữ ký/quyền:
--   gross_revenue   doanh thu TRƯỚC giảm giá = SUM(total_amount) + SUM(discount). Dựa trên dữ liệu thật:
--                   orders.total_amount = subtotal − discount (kiểm 1.167/1.167 đơn có giảm giá). Không dùng
--                   cột subtotal vì có thể rỗng ở đơn cũ; không dùng discount_amount vì luôn rỗng.
--   void_count      số lần hủy món/hủy bàn trong kỳ (void_audit_logs, theo created_at)
--   void_amount     tổng giá trị hủy trong kỳ (cancel_table có thể = 0)
--   first_order_at  thời điểm đơn hoàn tất đầu tiên của quán (phân biệt "quán mới" với "quán sụt giảm")
--   wallet_revenue  doanh thu thanh toán bằng ví (trước đây không thuộc nhóm tiền mặt/chuyển khoản/thẻ nên
--                   tổng 3 nhóm có thể nhỏ hơn doanh thu)
-- Bất biến giữ nguyên: chỉ chủ chuỗi, chỉ cửa hàng người gọi còn là chủ, chỉ số tổng hợp theo cửa hàng,
-- KHÔNG có dữ liệu theo từng nhân viên (void theo người yêu cầu/duyệt KHÔNG được đưa ra).
-- Áp dụng: CHƯA áp production. Chạy thử trên bản sao trước.
-- ============================================================================
BEGIN;
SET LOCAL search_path = public, pg_catalog, pg_temp;

DO $$
BEGIN
  IF to_regprocedure('public.get_chain_report_v1(uuid,timestamptz,timestamptz,text)') IS NULL
     OR to_regclass('public.void_audit_logs') IS NULL THEN
    RAISE EXCEPTION 'CHUOI v1.1 PREFLIGHT: thiếu get_chain_report_v1 (cần 20261017) hoặc void_audit_logs';
  END IF;
END $$;

-- Báo cáo đọc void theo (cửa hàng, thời gian): chưa có chỉ mục nào ngoài khóa chính
CREATE INDEX IF NOT EXISTS idx_void_audit_store_created ON public.void_audit_logs (store_id, created_at);

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
           COALESCE(SUM(COALESCE(o.total_amount, o.total, 0) + COALESCE(o.discount, 0)), 0) AS gross_revenue,
           COALESCE(SUM(CASE WHEN lower(btrim(COALESCE(o.payment_method, 'cash'))) = 'cash'
                             THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END), 0) AS cash,
           COALESCE(SUM(CASE WHEN lower(btrim(COALESCE(o.payment_method, 'cash'))) NOT IN ('cash', 'card', 'wallet')
                             THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END), 0) AS transfer,
           COALESCE(SUM(CASE WHEN lower(btrim(COALESCE(o.payment_method, 'cash'))) = 'card'
                             THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END), 0) AS card,
           COALESCE(SUM(CASE WHEN lower(btrim(COALESCE(o.payment_method, 'cash'))) = 'wallet'
                             THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END), 0) AS wallet,
           COALESCE(SUM(COALESCE(o.discount, 0)), 0) AS discount
      FROM public.orders o
     WHERE o.store_id = ANY (v_ids) AND o.status = 'completed'
       AND o.created_at >= p_from AND o.created_at < p_to
     GROUP BY o.store_id
  ), vd AS (
    SELECT v.store_id, COUNT(*)::bigint AS void_count, COALESCE(SUM(v.amount), 0) AS void_amount
      FROM public.void_audit_logs v
     WHERE v.store_id = ANY (v_ids) AND v.created_at >= p_from AND v.created_at < p_to
     GROUP BY v.store_id
  )
  SELECT
    COALESCE(jsonb_agg(jsonb_build_object(
      'store_id', s.id, 'name', s.name, 'store_code', s.store_code,
      'orders', COALESCE(a.orders, 0), 'revenue', COALESCE(a.revenue, 0),
      'gross_revenue', COALESCE(a.gross_revenue, 0),
      'avg_order_value', CASE WHEN COALESCE(a.orders, 0) > 0 THEN ROUND(a.revenue / a.orders, 2) ELSE 0 END,
      'cash_revenue', COALESCE(a.cash, 0), 'transfer_revenue', COALESCE(a.transfer, 0),
      'card_revenue', COALESCE(a.card, 0), 'wallet_revenue', COALESCE(a.wallet, 0),
      'discount', COALESCE(a.discount, 0),
      'void_count', COALESCE(vd.void_count, 0), 'void_amount', COALESCE(vd.void_amount, 0),
      'first_order_at', (SELECT MIN(f.created_at) FROM public.orders f WHERE f.store_id = s.id AND f.status = 'completed')
    ) ORDER BY COALESCE(a.revenue, 0) DESC, s.name), '[]'::jsonb),
    jsonb_build_object(
      'orders', COALESCE(SUM(a.orders), 0), 'revenue', COALESCE(SUM(a.revenue), 0),
      'gross_revenue', COALESCE(SUM(a.gross_revenue), 0),
      'avg_order_value', CASE WHEN COALESCE(SUM(a.orders), 0) > 0 THEN ROUND(SUM(a.revenue) / SUM(a.orders), 2) ELSE 0 END,
      'cash_revenue', COALESCE(SUM(a.cash), 0), 'transfer_revenue', COALESCE(SUM(a.transfer), 0),
      'card_revenue', COALESCE(SUM(a.card), 0), 'wallet_revenue', COALESCE(SUM(a.wallet), 0),
      'discount', COALESCE(SUM(a.discount), 0),
      'void_count', COALESCE(SUM(vd.void_count), 0), 'void_amount', COALESCE(SUM(vd.void_amount), 0),
      'store_count', COUNT(*))
    INTO v_stores, v_tot
    FROM public.stores s
    LEFT JOIN agg a ON a.store_id = s.id
    LEFT JOIN vd ON vd.store_id = s.id
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

-- Quyền giữ nguyên như v1 (CREATE OR REPLACE không đổi ACL), kiểm lại để chắc chắn
DO $$
BEGIN
  IF has_function_privilege('anon', 'public.get_chain_report_v1(uuid,timestamptz,timestamptz,text)', 'execute')
     OR NOT has_function_privilege('authenticated', 'public.get_chain_report_v1(uuid,timestamptz,timestamptz,text)', 'execute') THEN
    RAISE EXCEPTION 'CHUOI v1.1: quyền thực thi không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
