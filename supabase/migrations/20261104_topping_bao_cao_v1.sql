-- =============================================================================
-- Báo cáo đếm topping chọn kèm món (Chủ Quán 04/11/2026: "trân châu báo cáo sai số dù bán nhiều hơn").
--
-- Topping chọn ở "Tùy chọn" (Quản lý Bàn, đơn QR) không thành dòng đơn riêng mà nằm trong
-- order_items.modifiers_json của dòng món chính; các hàm số liệu chỉ cộng dòng đơn → topping bán kèm
-- món không được đếm (chỉ trân châu bán lẻ ở quầy mới có), tiền topping lại cộng vào món chính
-- (Trà đào TB 35.833 đ/phần thay vì 35.000 đ). Sửa 3 hàm:
--   • get_top_products_for_range_v1 (Báo cáo › Sản phẩm, Trang chủ)
--   • get_sold_categories_for_range_v1 (bộ lọc danh mục — thêm danh mục của topping)
--   • boom_sales_raw_v1 (số bán hàng cho Boom)
-- Mỗi topping thành một dòng riêng: món bàn ghi {"type":"topping","id","qty"} với qty = tổng cả dòng;
-- đơn QR (qr_price_items_v4 dựng lại, KHÔNG có "type") ghi {"id","price","quantity"} = mỗi phần × số món
-- (cùng cách trừ kho của 20261103_topping_ban_tru_kho_v1); tuỳ chọn hương vị (dòng product_modifiers, không
-- có "type" lẫn "quantity") không phải topping;
-- tiền = "price" × số phần, trừ khỏi tiền món chính → tổng doanh thu không đổi. Đơn cũ vẫn lưu topping
-- nên số các kỳ trước cũng đúng lại. modifiers_json là text: chỉ đọc dòng có khoá "id" và JSON hợp lệ
-- (pg_input_is_valid), số không hợp lệ coi như thiếu — dữ liệu hỏng không làm báo cáo lỗi.
--
-- PREFLIGHT: thân hàm đang chạy phải đúng bản đã biết (md5 prosrc: fix05a / 20261103) hoặc đã là bản này
-- (dấu "topping_bao_cao_v1") — khác thì dừng, không ghi đè bản lạ. Quyền GRANT giữ nguyên (CREATE OR REPLACE).
-- Hoàn tác: 20261104_topping_bao_cao_v1_ROLLBACK.sql. Test: supabase/tests/topping_bao_cao_v1_test.sql
-- =============================================================================

DO $pf$
DECLARE
  r record;
  v_src text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.get_top_products_for_range_v1(uuid, timestamptz, timestamptz, text, integer)', 'c5f7fa3175f028838dad8e4b6f8359c5'),
    ('public.get_sold_categories_for_range_v1(uuid, timestamptz, timestamptz)', '0ee785b70fc4ebe00fa7e0c3f91ce3f9'),
    ('public.boom_sales_raw_v1(uuid, timestamptz, timestamptz)', '55fd365b5a6470395c4e0d526dee3c6d')
  ) AS v(fn, md5_cu)
  LOOP
    SELECT prosrc INTO v_src FROM pg_proc WHERE oid = to_regprocedure(r.fn);
    IF v_src IS NULL THEN
      RAISE EXCEPTION 'TOPPING_BAO_CAO PREFLIGHT_FAIL: thiếu hàm %', r.fn;
    END IF;
    IF md5(v_src) <> r.md5_cu AND position('topping_bao_cao_v1' IN v_src) = 0 THEN
      RAISE EXCEPTION 'TOPPING_BAO_CAO PREFLIGHT_FAIL: % khác bản đã biết (md5 %) — so lại trước khi áp', r.fn, md5(v_src);
    END IF;
  END LOOP;
END
$pf$;

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

  -- topping_bao_cao_v1: topping trong modifiers_json của dòng món thành dòng riêng, tiền trừ khỏi món chính
  RETURN QUERY
  WITH it AS (
    SELECT oi.id AS line_id,
           oi.product_id::text AS pid,
           NULLIF(TRIM(oi.product_name), '') AS name1,
           NULLIF(TRIM(oi.name), '') AS name2,
           COALESCE(oi.quantity, oi.qty, 1)::numeric AS q,
           COALESCE(oi.subtotal, COALESCE(oi.quantity, oi.qty, 1) * COALESCE(oi.unit_price, 0))::numeric AS rev,
           CASE WHEN oi.modifiers_json LIKE '%"id"%' THEN
             CASE WHEN pg_input_is_valid(oi.modifiers_json, 'jsonb') THEN
               CASE WHEN jsonb_typeof(oi.modifiers_json::jsonb) = 'array' THEN oi.modifiers_json::jsonb END
             END
           END AS mods
    FROM public.orders o
    JOIN public.order_items oi ON oi.order_id::text = o.id::text
    WHERE o.store_id = p_store_id
      AND o.status = 'completed'
      AND (p_from IS NULL OR o.created_at >= p_from)
      AND (p_to IS NULL OR o.created_at < p_to)
  ),
  tp AS (
    SELECT it.line_id,
           TRIM(m->>'id') AS pid,
           NULLIF(TRIM(m->>'name'), '') AS name1,
           x.tq AS q,
           x.tq * x.price AS rev
    FROM it
    CROSS JOIN LATERAL jsonb_array_elements(it.mods) AS m
    CROSS JOIN LATERAL (
      SELECT COALESCE(
               CASE WHEN pg_input_is_valid(m->>'qty', 'numeric') THEN (m->>'qty')::numeric END,
               COALESCE(CASE WHEN pg_input_is_valid(m->>'quantity', 'numeric') THEN (m->>'quantity')::numeric END, 1) * it.q
             ) AS tq,
             COALESCE(CASE WHEN pg_input_is_valid(m->>'price', 'numeric') THEN (m->>'price')::numeric END, 0) AS price
    ) AS x
    WHERE it.q > 0
      AND jsonb_typeof(m) = 'object' AND (m->>'type' = 'topping' OR m ? 'quantity')
      AND NULLIF(TRIM(m->>'id'), '') IS NOT NULL
  ),
  tpl AS (
    SELECT tp.line_id, sum(tp.rev) AS rev FROM tp GROUP BY tp.line_id
  ),
  lines AS (
    SELECT it.pid, it.name1, it.name2, it.q, it.rev - COALESCE(tpl.rev, 0) AS rev
    FROM it
    LEFT JOIN tpl ON tpl.line_id = it.line_id
    WHERE it.pid IS NOT NULL AND TRIM(it.pid) <> ''
    UNION ALL
    SELECT tp.pid, tp.name1, NULL, tp.q, tp.rev FROM tp
  )
  SELECT
    l.pid AS product_id,
    COALESCE(MAX(NULLIF(TRIM(p.name), '')), MAX(l.name1), MAX(l.name2), 'Chưa đặt tên') AS product_name,
    COALESCE(SUM(l.q), 0)::numeric AS total_qty,
    COALESCE(SUM(l.rev), 0)::numeric AS total_revenue
  FROM lines l
  LEFT JOIN public.products p ON p.id::text = l.pid AND (p.store_id = p_store_id OR p.store_id IS NULL)
  WHERE (p_category IS NULL OR TRIM(p_category) = '' OR TRIM(p.category) = TRIM(p_category))
  GROUP BY l.pid
  ORDER BY total_revenue DESC, total_qty DESC, product_name ASC
  LIMIT COALESCE(p_limit, 20);
END;
$function$
;

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

  -- topping_bao_cao_v1: thêm danh mục của topping chọn kèm món (nằm trong modifiers_json)
  RETURN QUERY
  WITH it AS (
    SELECT oi.product_id::text AS pid,
           CASE WHEN oi.modifiers_json LIKE '%"id"%' THEN
             CASE WHEN pg_input_is_valid(oi.modifiers_json, 'jsonb') THEN
               CASE WHEN jsonb_typeof(oi.modifiers_json::jsonb) = 'array' THEN oi.modifiers_json::jsonb END
             END
           END AS mods
    FROM public.orders o
    JOIN public.order_items oi ON oi.order_id::text = o.id::text
    WHERE o.store_id = p_store_id
      AND o.status = 'completed'
      AND (p_from IS NULL OR o.created_at >= p_from)
      AND (p_to IS NULL OR o.created_at < p_to)
  ),
  ids AS (
    SELECT it.pid FROM it WHERE it.pid IS NOT NULL
    UNION
    SELECT TRIM(m->>'id')
    FROM it CROSS JOIN LATERAL jsonb_array_elements(it.mods) AS m
    WHERE jsonb_typeof(m) = 'object' AND (m->>'type' = 'topping' OR m ? 'quantity') AND NULLIF(TRIM(m->>'id'), '') IS NOT NULL
  )
  SELECT DISTINCT TRIM(p.category) AS category
  FROM ids
  JOIN public.products p ON p.id::text = ids.pid AND (p.store_id = p_store_id OR p.store_id IS NULL)
  WHERE p.category IS NOT NULL
    AND TRIM(p.category) <> ''
  ORDER BY category ASC;
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
  -- topping_bao_cao_v1: topping trong modifiers_json của dòng món thành món riêng (giá vốn 0), tiền trừ khỏi món chính
  WITH o AS (
    SELECT id, COALESCE(total_amount, total, 0)::numeric AS amt,
           (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh') AS t
    FROM orders
    WHERE store_id = p_store AND status = 'completed' AND created_at >= p_from AND created_at < p_to
  ),
  i0 AS (
    SELECT oi.id AS lid,
           oi.product_id::text AS pid,
           CASE WHEN extract(hour FROM o.t) >= 5 AND extract(hour FROM o.t) < 11 THEN 0
                WHEN extract(hour FROM o.t) >= 11 AND extract(hour FROM o.t) < 14 THEN 1
                WHEN extract(hour FROM o.t) >= 14 AND extract(hour FROM o.t) < 17 THEN 2
                ELSE 3 END AS band,
           COALESCE(oi.quantity, oi.qty, 0)::numeric AS q,
           COALESCE(oi.subtotal, COALESCE(oi.quantity, oi.qty, 0) * COALESCE(oi.unit_price, 0))::numeric AS rev,
           COALESCE(oi.cost_price, 0)::numeric AS c,
           CASE WHEN oi.modifiers_json LIKE '%"id"%' THEN
             CASE WHEN pg_input_is_valid(oi.modifiers_json, 'jsonb') THEN
               CASE WHEN jsonb_typeof(oi.modifiers_json::jsonb) = 'array' THEN oi.modifiers_json::jsonb END
             END
           END AS mods
    FROM order_items oi JOIN o ON o.id = oi.order_id
  ),
  tp AS (
    SELECT i0.lid, TRIM(m->>'id') AS pid, i0.band, x.tq AS q, x.tq * x.price AS rev
    FROM i0
    CROSS JOIN LATERAL jsonb_array_elements(i0.mods) AS m
    CROSS JOIN LATERAL (
      SELECT COALESCE(
               CASE WHEN pg_input_is_valid(m->>'qty', 'numeric') THEN (m->>'qty')::numeric END,
               COALESCE(CASE WHEN pg_input_is_valid(m->>'quantity', 'numeric') THEN (m->>'quantity')::numeric END, 1) * i0.q
             ) AS tq,
             COALESCE(CASE WHEN pg_input_is_valid(m->>'price', 'numeric') THEN (m->>'price')::numeric END, 0) AS price
    ) AS x
    WHERE i0.q > 0 AND jsonb_typeof(m) = 'object' AND (m->>'type' = 'topping' OR m ? 'quantity') AND NULLIF(TRIM(m->>'id'), '') IS NOT NULL
  ),
  tpl AS (SELECT lid, sum(rev) AS rev FROM tp GROUP BY lid),
  i AS (
    SELECT i0.pid, i0.band, i0.q, i0.rev - COALESCE(tpl.rev, 0) AS rev, i0.c
    FROM i0 LEFT JOIN tpl ON tpl.lid = i0.lid
    WHERE i0.pid IS NOT NULL
    UNION ALL
    SELECT tp.pid, tp.band, tp.q, tp.rev, 0::numeric FROM tp
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
