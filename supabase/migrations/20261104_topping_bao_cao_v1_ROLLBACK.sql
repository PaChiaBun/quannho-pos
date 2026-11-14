-- Hoàn tác 20261104_topping_bao_cao_v1.sql: trả 3 hàm về nguyên văn bản cũ — topping chọn kèm món lại không
-- được đếm riêng, tiền topping lại cộng vào món chính. Chép nguyên văn từ 20261007_fix05a_khoa_bang_khong_realtime.sql
-- (dòng 289–360) và 20261103_boom_sales_raw_v1.sql. Quyền GRANT giữ nguyên (CREATE OR REPLACE).

CREATE OR REPLACE FUNCTION public.get_sold_categories_for_range_v1(p_store_id uuid, p_from timestamp with time zone, p_to timestamp with time zone)
 RETURNS TABLE(category text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- FIX05: chỉ thành viên của quán (hoặc service_role/kết nối nội bộ) mới xem được báo cáo
  IF NOT (public.qn_is_member(p_store_id)
          OR coalesce(NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role', '') = 'service_role'
          OR NULLIF(current_setting('request.jwt.claims', true), '') IS NULL) THEN
    RAISE EXCEPTION 'Không có quyền xem báo cáo của quán này' USING ERRCODE = '42501';
  END IF;
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
$function$
;

CREATE OR REPLACE FUNCTION public.get_top_products_for_range_v1(p_store_id uuid, p_from timestamp with time zone, p_to timestamp with time zone, p_category text DEFAULT NULL::text, p_limit integer DEFAULT 20)
 RETURNS TABLE(product_id text, product_name text, total_qty numeric, total_revenue numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- FIX05: chỉ thành viên của quán (hoặc service_role/kết nối nội bộ) mới xem được báo cáo
  IF NOT (public.qn_is_member(p_store_id)
          OR coalesce(NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role', '') = 'service_role'
          OR NULLIF(current_setting('request.jwt.claims', true), '') IS NULL) THEN
    RAISE EXCEPTION 'Không có quyền xem báo cáo của quán này' USING ERRCODE = '42501';
  END IF;
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
$function$
;

CREATE OR REPLACE FUNCTION public.boom_sales_raw_v1(p_store uuid, p_from timestamptz, p_to timestamptz)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  WITH o AS (
    SELECT id, COALESCE(total_amount, total, 0)::numeric AS amt,
           (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh') AS t
    FROM orders
    WHERE store_id = p_store AND status = 'completed' AND created_at >= p_from AND created_at < p_to
  ),
  i AS (
    SELECT oi.product_id AS pid,
           CASE WHEN extract(hour FROM o.t) >= 5 AND extract(hour FROM o.t) < 11 THEN 0
                WHEN extract(hour FROM o.t) >= 11 AND extract(hour FROM o.t) < 14 THEN 1
                WHEN extract(hour FROM o.t) >= 14 AND extract(hour FROM o.t) < 17 THEN 2
                ELSE 3 END AS band,
           COALESCE(oi.quantity, oi.qty, 0)::numeric AS q,
           COALESCE(oi.subtotal, COALESCE(oi.quantity, oi.qty, 0) * COALESCE(oi.unit_price, 0))::numeric AS rev,
           COALESCE(oi.cost_price, 0)::numeric AS c
    FROM order_items oi JOIN o ON o.id = oi.order_id
    WHERE oi.product_id IS NOT NULL
  ),
  p AS (
    SELECT pid, sum(q) AS q, sum(rev) AS rev,
           sum(CASE WHEN c > 0 THEN c * q ELSE 0 END) AS cost,
           sum(CASE WHEN c > 0 THEN q ELSE 0 END) AS cost_q
    FROM i GROUP BY pid
  ),
  b AS (SELECT band, pid, sum(q) AS q FROM i GROUP BY band, pid)
  SELECT jsonb_build_object(
    'revenue', COALESCE((SELECT sum(amt) FROM o), 0),
    'orders', (SELECT count(*) FROM o),
    'by_hour', (SELECT jsonb_agg(COALESCE(x.v, 0) ORDER BY g) FROM generate_series(0, 23) g
                LEFT JOIN (SELECT extract(hour FROM t)::int AS k, sum(amt) AS v FROM o GROUP BY 1) x ON x.k = g),
    'by_weekday', (SELECT jsonb_agg(COALESCE(x.v, 0) ORDER BY g) FROM generate_series(0, 6) g
                   LEFT JOIN (SELECT extract(isodow FROM t)::int - 1 AS k, sum(amt) AS v FROM o GROUP BY 1) x ON x.k = g),
    'items', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', pid, 'qty', q, 'revenue', rev, 'cost', cost, 'cost_qty', cost_q)) FROM p), '[]'::jsonb),
    'bands', (SELECT jsonb_agg(COALESCE((SELECT jsonb_agg(jsonb_build_object('id', pid, 'qty', q)) FROM b WHERE b.band = g), '[]'::jsonb) ORDER BY g)
              FROM generate_series(0, 3) g)
  );
$$;

NOTIFY pgrst, 'reload schema';
