-- ============================================================================
-- NÂNG CẤP TỔNG QUAN /admin (Chủ Quán 26/10: "doanh số toàn hệ thống, quán đang bỏ dùng, việc cần làm hôm nay,
-- biểu đồ dễ đọc hơn, gợi ý đánh dấu quán thử")
-- Một hàm mới, CHỈ ĐỌC: admin_overview_extra_v1(p_include_test) — không đổi hàm / bảng cũ.
--   • sales        — đơn + doanh thu (đơn hoàn thành) 7 / 30 ngày, kỳ trước để so, theo ngày 30 ngày, 5 quán bán nhiều nhất
--   • dropping     — quán có bán trong 30 ngày nhưng 0 đơn trong 7 ngày (đang bỏ dùng) + SĐT chủ để gọi
--   • todo         — việc hôm nay: sắp hết thử / hết thử / Pro sắp hết / Pro hết hạn, ghi chú cần gọi, hỗ trợ mới, đơn thu phí chờ
--   • test_suggest — quán CHƯA đánh dấu thử có tên chứa test/demo/thử, hoặc tên vô nghĩa mà chưa bán đơn nào
--                    (chỉ gợi ý — đánh dấu vẫn qua admin_set_test_store_v1, Chủ Quán bấm từng lần)
-- Chỉ vé quản trị (qn_admin). Hoàn tác: …_ROLLBACK.sql
-- ============================================================================
BEGIN;

DO $$
BEGIN
  IF to_regprocedure('public.qn_admin_caller()') IS NULL OR to_regprocedure('public.qn_store_plan_notice(text,text,timestamptz,timestamptz)') IS NULL
     OR to_regclass('public.billing_orders') IS NULL OR to_regclass('public.bug_reports') IS NULL THEN
    RAISE EXCEPTION 'Cần áp đợt 1 trang quản trị, thu phí đợt A, hỗ trợ H1H2 trước';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_overview_extra_v1(p_include_test boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_today date := public.qn_vn_day(now());
  r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  WITH s AS (
    SELECT st.*, EXISTS (SELECT 1 FROM public.admin_test_stores t WHERE t.store_id = st.id) AS is_test
      FROM public.stores st
  ), base AS (
    SELECT * FROM s WHERE p_include_test OR NOT s.is_test
  ), o AS (  -- đơn hoàn thành 60 ngày của các quán đang tính
    SELECT od.store_id, od.created_at, COALESCE(od.total_amount, od.total, 0) AS amt
      FROM public.orders od
     WHERE od.status = 'completed' AND od.created_at > now() - interval '60 days'
       AND od.store_id IN (SELECT id FROM base)
  ), per AS (
    SELECT store_id,
           count(*) FILTER (WHERE created_at > now() - interval '7 days') AS o7,
           count(*) FILTER (WHERE created_at > now() - interval '30 days') AS o30,
           COALESCE(sum(amt) FILTER (WHERE created_at > now() - interval '30 days'), 0) AS r30,
           max(created_at) AS last_order
      FROM o GROUP BY store_id
  )
  SELECT jsonb_build_object('ok', true,
    'sales', jsonb_build_object(
      'orders_7d', (SELECT count(*) FROM o WHERE created_at > now() - interval '7 days'),
      'revenue_7d', (SELECT COALESCE(sum(amt), 0) FROM o WHERE created_at > now() - interval '7 days'),
      'orders_prev7', (SELECT count(*) FROM o WHERE created_at <= now() - interval '7 days' AND created_at > now() - interval '14 days'),
      'revenue_prev7', (SELECT COALESCE(sum(amt), 0) FROM o WHERE created_at <= now() - interval '7 days' AND created_at > now() - interval '14 days'),
      'orders_30d', (SELECT count(*) FROM o WHERE created_at > now() - interval '30 days'),
      'revenue_30d', (SELECT COALESCE(sum(amt), 0) FROM o WHERE created_at > now() - interval '30 days'),
      'orders_prev30', (SELECT count(*) FROM o WHERE created_at <= now() - interval '30 days'),
      'revenue_prev30', (SELECT COALESCE(sum(amt), 0) FROM o WHERE created_at <= now() - interval '30 days'),
      'stores_selling_7d', (SELECT count(*) FROM per WHERE o7 > 0),
      'by_day', (SELECT COALESCE(jsonb_agg(jsonb_build_object('day', g::date, 'n', COALESCE(dd.n, 0), 'revenue', COALESCE(dd.rv, 0))
                                           ORDER BY g), '[]'::jsonb)
            FROM generate_series(v_today - 29, v_today, interval '1 day') g
            LEFT JOIN (SELECT public.qn_vn_day(created_at) AS d, count(*) AS n, sum(amt) AS rv  -- gom 1 lần quét
                         FROM o WHERE created_at > now() - interval '31 days' GROUP BY 1) dd ON dd.d = g::date),
      'top', (SELECT COALESCE(jsonb_agg(t ORDER BY t.revenue DESC, t.orders DESC), '[]'::jsonb) FROM (
          SELECT b.id, b.name, b.store_code AS code, p.o30 AS orders, p.r30 AS revenue, p.o7 AS orders_7d
            FROM per p JOIN base b ON b.id = p.store_id
           WHERE p.o30 > 0 ORDER BY p.r30 DESC, p.o30 DESC LIMIT 5) t)),
    'dropping', jsonb_build_object(
      'total', (SELECT count(*) FROM per WHERE o30 > 0 AND o7 = 0),
      'rows', (SELECT COALESCE(jsonb_agg(t ORDER BY t.revenue_30d DESC, t.orders_30d DESC), '[]'::jsonb) FROM (
          SELECT b.id, b.name, b.store_code AS code, ua.display_name AS owner_name, ua.phone AS owner_phone,
                 p.last_order AS last_order_at, p.o30 AS orders_30d, p.r30 AS revenue_30d, b.status = 'locked' AS locked
            FROM per p JOIN base b ON b.id = p.store_id
            -- chủ: ghi trên quán, thiếu thì thành viên đánh dấu chủ sớm nhất (như admin_plan_list_v1)
            LEFT JOIN LATERAL (SELECT u.display_name, u.phone FROM public.user_accounts u
                                WHERE u.id = COALESCE(b.owner_user_id, (SELECT m.user_id FROM public.store_members m
                                                                         WHERE m.store_id = b.id AND m.is_owner
                                                                         ORDER BY m.created_at LIMIT 1))) ua ON true
           WHERE p.o30 > 0 AND p.o7 = 0
           ORDER BY p.r30 DESC, p.o30 DESC LIMIT 50) t)),
    'todo', (SELECT jsonb_build_object(
      'trial_ending', count(*) FILTER (WHERE nt = 'trial_ending'),
      'trial_expired', count(*) FILTER (WHERE nt = 'trial_expired'),
      'pro_ending', count(*) FILTER (WHERE nt = 'pro_ending'),
      'pro_expired', count(*) FILTER (WHERE nt = 'pro_expired'),
      'follow_ups_due', (SELECT count(DISTINCT n.store_id) FROM public.admin_store_notes n JOIN base b ON b.id = n.store_id
                          WHERE n.done_at IS NULL AND n.follow_up_on <= v_today),
      'support_open', (SELECT count(*) FROM public.bug_reports WHERE status = 'open'),
      'support_in_progress', (SELECT count(*) FROM public.bug_reports WHERE status = 'in_progress'),
      'billing_pending', (SELECT count(*) FROM public.billing_orders bo JOIN base b ON b.id = bo.store_id
                           WHERE bo.status = 'pending' AND bo.expires_at > now()))
      FROM (SELECT public.qn_store_plan_notice(plan, status, trial_ends_at, plan_ends_at) AS nt FROM base) x),
    'test_suggest', (SELECT COALESCE(jsonb_agg(t ORDER BY t.reason DESC, t.created_at), '[]'::jsonb) FROM (  -- name_test (tin cậy hơn) trước
        SELECT q.id, q.name, q.store_code AS code, q.created_at, q.reason,
               (SELECT count(*) FROM public.orders od WHERE od.store_id = q.id AND od.status = 'completed') AS orders_total
          FROM (SELECT x.*,
                       CASE WHEN x.name ~* '(test|demo|thử|thu nghiem)' THEN 'name_test'
                            WHEN NOT EXISTS (SELECT 1 FROM public.orders od WHERE od.store_id = x.id AND od.status = 'completed')
                             AND (char_length(btrim(x.name)) <= 2 OR x.name !~ '[[:alpha:]]'
                                  OR (SELECT count(DISTINCT c) FROM regexp_split_to_table(lower(regexp_replace(x.name, '[^[:alpha:]]', '', 'g')), '') c) <= 2)
                            THEN 'name_junk' END AS reason
                  FROM s x WHERE NOT x.is_test) q
         WHERE q.reason IS NOT NULL
         ORDER BY q.reason DESC, q.created_at LIMIT 100) t)
  ) INTO r;
  RETURN r;
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_overview_extra_v1(boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_overview_extra_v1(boolean) TO qn_admin;

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.admin_overview_extra_v1(boolean)', 'execute')
     OR has_function_privilege('authenticated', 'public.admin_overview_extra_v1(boolean)', 'execute')
     OR NOT has_function_privilege('qn_admin', 'public.admin_overview_extra_v1(boolean)', 'execute') THEN
    RAISE EXCEPTION 'TONG QUAN NANG CAP: quyền không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
