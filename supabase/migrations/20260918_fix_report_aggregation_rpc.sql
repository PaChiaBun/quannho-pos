-- =============================================================================
-- Migration: 20260918_fix_report_aggregation_rpc.sql
-- Mục tiêu: Khắc phục triệt để lỗi hụt số liệu doanh thu tháng (>1000 đơn bị ngắt)
--           và lỗi báo cáo sản phẩm tuần/tháng bị sai lệch hoặc treo loading do
--           giới hạn 1000 dòng của PostgREST và bão hòa socket pool N+1 queries.
-- Quy chuẩn: Multi-tenant store_id, status = 'completed', fail-safe RPCs.
-- =============================================================================

-- Tối ưu hoá index phục vụ truy vấn tổng hợp báo cáo quy mô lớn (>10,000 đơn/tháng)
CREATE INDEX IF NOT EXISTS idx_orders_report_agg
  ON public.orders(store_id, status, created_at);

CREATE INDEX IF NOT EXISTS idx_order_items_order_store
  ON public.order_items(order_id, store_id);

CREATE INDEX IF NOT EXISTS idx_order_items_product_lookup
  ON public.order_items(product_id);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id_text
  ON public.order_items((order_id::text));

CREATE INDEX IF NOT EXISTS idx_order_items_product_id_text
  ON public.order_items((product_id::text));

CREATE INDEX IF NOT EXISTS idx_products_id_text
  ON public.products((id::text));

-- =============================================================================
-- =============================================================================
-- 1. get_daily_revenue_for_range_v1: Tổng hợp doanh thu từng ngày nghiệp vụ
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_daily_revenue_for_range_v1(
  p_store_id uuid,
  p_from timestamptz,
  p_to timestamptz,
  p_tz text DEFAULT 'Asia/Ho_Chi_Minh'
)
RETURNS TABLE (
  report_date text,
  total_orders bigint,
  total_revenue numeric,
  cash_revenue numeric,
  transfer_revenue numeric,
  total_discount numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tz text := COALESCE(NULLIF(TRIM(p_tz), ''), 'Asia/Ho_Chi_Minh');
BEGIN
  IF p_store_id IS NULL THEN
    RETURN;
  END IF;

  -- Safe timezone validation: fallback to Asia/Ho_Chi_Minh if invalid
  BEGIN
    PERFORM now() AT TIME ZONE v_tz;
  EXCEPTION WHEN OTHERS THEN
    v_tz := 'Asia/Ho_Chi_Minh';
  END;

  RETURN QUERY
  SELECT
    to_char((o.created_at AT TIME ZONE v_tz), 'YYYY-MM-DD') AS report_date,
    COUNT(*)::bigint AS total_orders,
    COALESCE(SUM(COALESCE(o.total_amount, o.total, 0)), 0)::numeric AS total_revenue,
    COALESCE(SUM(CASE WHEN LOWER(TRIM(COALESCE(o.payment_method, 'cash'))) = 'cash' THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END), 0)::numeric AS cash_revenue,
    COALESCE(SUM(CASE WHEN LOWER(TRIM(COALESCE(o.payment_method, 'cash'))) NOT IN ('cash', 'wallet') THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END), 0)::numeric AS transfer_revenue,
    COALESCE(SUM(COALESCE(o.discount, 0)), 0)::numeric AS total_discount
  FROM public.orders o
  WHERE o.store_id = p_store_id
    AND o.status = 'completed'
    AND (p_from IS NULL OR o.created_at >= p_from)
    AND (p_to IS NULL OR o.created_at < p_to)
  GROUP BY to_char((o.created_at AT TIME ZONE v_tz), 'YYYY-MM-DD')
  ORDER BY report_date ASC;
END;
$$;

-- =============================================================================
-- 2. get_report_stats_for_range_v1: Tổng hợp chỉ số kỳ báo cáo & phương thức TT
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_report_stats_for_range_v1(
  p_store_id uuid,
  p_from timestamptz,
  p_to timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_orders bigint := 0;
  v_total_revenue numeric := 0;
  v_avg_order_value numeric := 0;
  v_total_customers bigint := 0;
  v_cash_revenue numeric := 0;
  v_transfer_revenue numeric := 0;
  v_card_revenue numeric := 0;
  v_cashier_revenue jsonb := '{}'::jsonb;
  v_cashier_details jsonb := '{}'::jsonb;
  v_waiter_orders jsonb := '{}'::jsonb;
BEGIN
  IF p_store_id IS NULL THEN
    RETURN jsonb_build_object(
      'total_orders', 0,
      'total_revenue', 0,
      'avg_order_value', 0,
      'total_customers', 0,
      'cash_revenue', 0,
      'transfer_revenue', 0,
      'card_revenue', 0,
      'payment_breakdown', jsonb_build_object(
        'cash', 0,
        'transfer', 0,
        'card', 0
      ),
      'cashier_revenue', '{}'::jsonb,
      'cashier_details', '{}'::jsonb,
      'waiter_orders', '{}'::jsonb
    );
  END IF;

  -- 1. Tổng hợp chỉ số cốt lõi trực tiếp từ bảng orders (không bị limit 1000 dòng)
  SELECT
    COUNT(*)::bigint,
    COALESCE(SUM(COALESCE(o.total_amount, o.total, 0)), 0)::numeric,
    COUNT(DISTINCT o.customer_id::text) FILTER (WHERE o.customer_id IS NOT NULL AND TRIM(o.customer_id::text) <> '')::bigint,
    COALESCE(SUM(CASE WHEN LOWER(TRIM(COALESCE(o.payment_method, 'cash'))) = 'cash' THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END), 0)::numeric,
    COALESCE(SUM(CASE WHEN LOWER(TRIM(COALESCE(o.payment_method, 'cash'))) NOT IN ('cash', 'card', 'wallet') THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END), 0)::numeric,
    COALESCE(SUM(CASE WHEN LOWER(TRIM(COALESCE(o.payment_method, 'cash'))) = 'card' THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END), 0)::numeric
  INTO
    v_total_orders,
    v_total_revenue,
    v_total_customers,
    v_cash_revenue,
    v_transfer_revenue,
    v_card_revenue
  FROM public.orders o
  WHERE o.store_id = p_store_id
    AND o.status = 'completed'
    AND (p_from IS NULL OR o.created_at >= p_from)
    AND (p_to IS NULL OR o.created_at < p_to);

  IF v_total_orders > 0 THEN
    v_avg_order_value := ROUND(v_total_revenue / v_total_orders, 2);
  ELSE
    v_avg_order_value := 0;
  END IF;

  -- 2. Doanh thu theo thu ngân (cashier_revenue)
  SELECT COALESCE(jsonb_object_agg(sub.cashier_name, sub.total_amount), '{}'::jsonb)
  INTO v_cashier_revenue
  FROM (
    SELECT
      COALESCE(NULLIF(TRIM(sm.name), ''), 'Không rõ thu ngân') AS cashier_name,
      SUM(COALESCE(o.total_amount, o.total, 0)) AS total_amount
    FROM public.orders o
    LEFT JOIN public.staff_members sm ON sm.id::text = o.staff_id::text AND (sm.store_id = p_store_id OR sm.store_id IS NULL)
    WHERE o.store_id = p_store_id
      AND o.status = 'completed'
      AND (p_from IS NULL OR o.created_at >= p_from)
      AND (p_to IS NULL OR o.created_at < p_to)
    GROUP BY COALESCE(NULLIF(TRIM(sm.name), ''), 'Không rõ thu ngân')
  ) sub
  WHERE sub.cashier_name IS NOT NULL;

  -- 3. Chi tiết phương thức thanh toán theo thu ngân (cashier_details)
  SELECT COALESCE(
    jsonb_object_agg(
      sub_detail.cashier_name,
      jsonb_build_object(
        'cash', sub_detail.cash_amt,
        'transfer', sub_detail.transfer_amt,
        'card', sub_detail.card_amt,
        'total', sub_detail.total_amt
      )
    ),
    '{}'::jsonb
  )
  INTO v_cashier_details
  FROM (
    SELECT
      COALESCE(NULLIF(TRIM(sm.name), ''), 'Không rõ thu ngân') AS cashier_name,
      SUM(CASE WHEN LOWER(TRIM(COALESCE(o.payment_method, 'cash'))) = 'cash' THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END) AS cash_amt,
      SUM(CASE WHEN LOWER(TRIM(COALESCE(o.payment_method, 'cash'))) NOT IN ('cash', 'card', 'wallet') THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END) AS transfer_amt,
      SUM(CASE WHEN LOWER(TRIM(COALESCE(o.payment_method, 'cash'))) = 'card' THEN COALESCE(o.total_amount, o.total, 0) ELSE 0 END) AS card_amt,
      SUM(COALESCE(o.total_amount, o.total, 0)) AS total_amt
    FROM public.orders o
    LEFT JOIN public.staff_members sm ON sm.id::text = o.staff_id::text AND (sm.store_id = p_store_id OR sm.store_id IS NULL)
    WHERE o.store_id = p_store_id
      AND o.status = 'completed'
      AND (p_from IS NULL OR o.created_at >= p_from)
      AND (p_to IS NULL OR o.created_at < p_to)
    GROUP BY COALESCE(NULLIF(TRIM(sm.name), ''), 'Không rõ thu ngân')
  ) sub_detail
  WHERE sub_detail.cashier_name IS NOT NULL;

  -- 4. Số đơn theo nhân viên phục vụ (waiter_orders)
  SELECT COALESCE(jsonb_object_agg(sub_waiter.waiter_name, sub_waiter.order_cnt), '{}'::jsonb)
  INTO v_waiter_orders
  FROM (
    SELECT
      COALESCE(NULLIF(TRIM(sm.name), ''), 'Không rõ phục vụ') AS waiter_name,
      COUNT(*)::int AS order_cnt
    FROM public.orders o
    LEFT JOIN public.staff_members sm ON sm.id::text = o.waiter_id::text AND (sm.store_id = p_store_id OR sm.store_id IS NULL)
    WHERE o.store_id = p_store_id
      AND o.status = 'completed'
      AND (p_from IS NULL OR o.created_at >= p_from)
      AND (p_to IS NULL OR o.created_at < p_to)
      AND o.waiter_id IS NOT NULL
      AND TRIM(o.waiter_id::text) <> ''
    GROUP BY COALESCE(NULLIF(TRIM(sm.name), ''), 'Không rõ phục vụ')
  ) sub_waiter
  WHERE sub_waiter.waiter_name IS NOT NULL;

  RETURN jsonb_build_object(
    'total_orders', v_total_orders,
    'total_revenue', v_total_revenue,
    'avg_order_value', v_avg_order_value,
    'total_customers', v_total_customers,
    'cash_revenue', v_cash_revenue,
    'transfer_revenue', v_transfer_revenue,
    'card_revenue', v_card_revenue,
    'payment_breakdown', jsonb_build_object(
      'cash', v_cash_revenue,
      'transfer', v_transfer_revenue,
      'card', v_card_revenue
    ),
    'cashier_revenue', v_cashier_revenue,
    'cashier_details', v_cashier_details,
    'waiter_orders', v_waiter_orders
  );
END;
$$;

-- =============================================================================
-- 3. get_top_products_for_range_v1: Top món bán chạy (JOIN trực tiếp trên DB)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_top_products_for_range_v1(
  p_store_id uuid,
  p_from timestamptz,
  p_to timestamptz,
  p_category text DEFAULT NULL,
  p_limit int DEFAULT 20
)
RETURNS TABLE (
  product_id text,
  product_name text,
  total_qty numeric,
  total_revenue numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_store_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    oi.product_id::text AS product_id,
    COALESCE(MAX(NULLIF(TRIM(p.name), '')), MAX(NULLIF(TRIM(oi.product_name), '')), MAX(NULLIF(TRIM(oi.name), '')), 'Chưa đặt tên') AS product_name,
    COALESCE(SUM(COALESCE(oi.quantity, oi.qty, 1)), 0)::numeric AS total_qty,
    COALESCE(SUM(COALESCE(oi.subtotal, COALESCE(oi.quantity, oi.qty, 1) * COALESCE(oi.unit_price, 0))), 0)::numeric AS total_revenue
  FROM public.orders o
  JOIN public.order_items oi ON oi.order_id::text = o.id::text
  LEFT JOIN public.products p ON p.id::text = oi.product_id::text AND (p.store_id = p_store_id OR p.store_id IS NULL)
  WHERE o.store_id = p_store_id
    AND o.status = 'completed'
    AND (p_from IS NULL OR o.created_at >= p_from)
    AND (p_to IS NULL OR o.created_at < p_to)
    AND oi.product_id IS NOT NULL
    AND TRIM(oi.product_id::text) <> ''
    AND (p_category IS NULL OR TRIM(p_category) = '' OR TRIM(p.category) = TRIM(p_category))
  GROUP BY oi.product_id::text
  ORDER BY total_revenue DESC, total_qty DESC, product_name ASC
  LIMIT COALESCE(p_limit, 20);
END;
$$;

-- =============================================================================
-- 4. get_sold_categories_for_range_v1: Danh mục thực tế có món bán ra
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_sold_categories_for_range_v1(
  p_store_id uuid,
  p_from timestamptz,
  p_to timestamptz
)
RETURNS TABLE (
  category text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_store_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT DISTINCT TRIM(p.category) AS category
  FROM public.orders o
  JOIN public.order_items oi ON oi.order_id::text = o.id::text
  JOIN public.products p ON p.id::text = oi.product_id::text AND (p.store_id = p_store_id OR p.store_id IS NULL)
  WHERE o.store_id = p_store_id
    AND o.status = 'completed'
    AND (p_from IS NULL OR o.created_at >= p_from)
    AND (p_to IS NULL OR o.created_at < p_to)
    AND p.category IS NOT NULL
    AND TRIM(p.category) <> ''
  ORDER BY category ASC;
END;
$$;

-- =============================================================================
-- Phân quyền bảo mật EXECUTE cho anon, authenticated, service_role
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.get_daily_revenue_for_range_v1(uuid, timestamptz, timestamptz, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_report_stats_for_range_v1(uuid, timestamptz, timestamptz) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_top_products_for_range_v1(uuid, timestamptz, timestamptz, text, int) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_sold_categories_for_range_v1(uuid, timestamptz, timestamptz) TO anon, authenticated, service_role;
