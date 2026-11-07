-- Boom chặng 1.2 (03/11/2026, .docs/thiet-ke-boom-may-chu-lay-so.md): tổng hợp số bán hàng của MỘT kỳ ngay trong Postgres
-- để hàm boom-chat (chế độ 'ask') đọc bằng vé của người hỏi — thay việc app tải từng đơn + toàn bộ order_items (tới 100k dòng).
-- Cùng cách tính với app (boom_read_only_data_service.dart: getRevenueSummary + getProductPerformance):
--   đơn status = 'completed', created_at trong [p_from, p_to); tiền đơn = total_amount, không có thì total;
--   giờ / thứ / khung giờ theo giờ Việt Nam; món: quantity ?? qty, tiền = subtotal ?? số lượng × unit_price,
--   giá vốn theo dòng đơn (cost_price > 0). Lọc món đang bán / nguyên liệu / topping và dựng nhóm làm ở hàm (ban_hang.ts).
-- SECURITY INVOKER: chạy bằng quyền người gọi → RLS của orders / order_items vẫn áp (khác quán không đọc được).
-- Chỉ mục dùng: idx_orders_report_agg (store_id, status, created_at), idx_order_items_order (order_id).
-- Hoàn tác: 20261103_boom_sales_raw_v1_ROLLBACK.sql

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

REVOKE ALL ON FUNCTION public.boom_sales_raw_v1(uuid, timestamptz, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.boom_sales_raw_v1(uuid, timestamptz, timestamptz) TO authenticated;
NOTIFY pgrst, 'reload schema';
