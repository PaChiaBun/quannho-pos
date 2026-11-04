-- ============================================================================
-- /admin THEO DÕI TĂNG TRƯỞNG — ĐỢT 1 (kế hoạch ke-hoach-admin-tang-truong-dot1.md, Chủ Quán duyệt 05/11)
-- Hai hàm mới, CHỈ ĐỌC, chỉ vé quản trị (qn_admin). Không đổi bảng, không đổi hàm cũ, không ghi dữ liệu:
--   • admin_growth_v1(p_include_test)  — tiền công ty, lứa quán, dùng thật, số khách (chủ quán)
--   • admin_store_list_v2(...)         — như v1, thêm sắp xếp trên TOÀN BỘ danh sách, số quán của chủ, lọc theo chủ
-- admin_store_list_v1 giữ nguyên để trang cũ chạy được khi hoàn tác. Hoàn tác: …_ROLLBACK.sql
-- ============================================================================
BEGIN;

DO $$
BEGIN
  IF to_regprocedure('public.qn_admin_caller()') IS NULL OR to_regprocedure('public.qn_vn_day(timestamptz)') IS NULL
     OR to_regclass('public.admin_store_actions') IS NULL OR to_regclass('public.billing_orders') IS NULL
     OR to_regclass('public.admin_test_stores') IS NULL THEN
    RAISE EXCEPTION 'Cần áp trang quản trị đợt 1 và thu phí đợt A trước';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_growth_v1(p_include_test boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  -- Ngưỡng "dùng thật" (Chủ Quán duyệt 05/11, mặc định kế hoạch). Trang đọc từ khối thresholds, không chép số.
  c_real_7d constant int := 20;
  c_real_30d constant int := 20;
  v_this_month date := date_trunc('month', now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
  v_first_month date := v_this_month - interval '11 months';
  r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  WITH base AS (
    SELECT st.* FROM public.stores st
     WHERE p_include_test OR NOT EXISTS (SELECT 1 FROM public.admin_test_stores t WHERE t.store_id = st.id)
  ), act AS (  -- nhật ký thao tác của các quán đang tính
    SELECT c.* FROM public.admin_store_actions c JOIN base b ON b.id = c.store_id
  ), paid AS (  -- khoản có tiền thật; amount 0 / NULL là tặng
    SELECT * FROM act WHERE action IN ('payment', 'set_plan') AND amount_vnd > 0
  ), first_paid AS (
    SELECT store_id, min(created_at) AS at FROM paid GROUP BY 1
  ), last_free AS (  -- về free rồi được tặng lại thì các khoản trước đó không còn tác dụng
    SELECT store_id, max(created_at) AS at FROM act WHERE action = 'set_plan' AND after->>'plan' = 'free' GROUP BY 1
  ), cur AS (  -- ĐƠN THU PHÍ gần nhất của từng quán. Khoản ghi tay (phụ thu, gia hạn tay) không thay thế đơn.
    SELECT DISTINCT ON (p.store_id) p.*
      FROM paid p LEFT JOIN last_free lf ON lf.store_id = p.store_id
     WHERE p.action = 'payment' AND p.created_at > COALESCE(lf.at, '-infinity'::timestamptz)
     ORDER BY p.store_id, p.created_at DESC, p.id DESC
  ), manual AS (  -- quán có tiền ghi tay qua "Đổi gói": form không có số tháng nên KHÔNG đoán, không vào MRR
    SELECT DISTINCT p.store_id
      FROM paid p LEFT JOIN last_free lf ON lf.store_id = p.store_id
     WHERE p.action = 'set_plan' AND p.created_at > COALESCE(lf.at, '-infinity'::timestamptz)
  ), pro AS (  -- Pro còn hạn, không khoá
    SELECT b.id, b.plan_ends_at, cur.amount_vnd,
           (cur.after->>'plan_ends_at')::timestamptz AS paid_until,  -- hết phần đã trả; tặng thêm sau đó không kéo dài phần này
           od.months
      FROM base b
      LEFT JOIN cur ON cur.store_id = b.id
      -- qn_billing_apply_order ghi đơn và nhật ký trong cùng giao dịch nên paid_at = created_at (cùng now()).
      LEFT JOIN LATERAL (
        SELECT bo.months FROM public.billing_orders bo
         WHERE bo.store_id = cur.store_id AND bo.status = 'paid'
           AND bo.paid_at = cur.created_at AND bo.paid_amount_vnd = cur.amount_vnd
         ORDER BY bo.months DESC LIMIT 1) od ON true
     WHERE b.plan = 'pro' AND b.status <> 'locked' AND (b.plan_ends_at IS NULL OR b.plan_ends_at > now())
  ), paying AS (
    SELECT id, round(amount_vnd::numeric / months) AS mrr
      FROM pro WHERE plan_ends_at IS NOT NULL AND months IS NOT NULL AND paid_until > now()
  ), owner_of AS (  -- một quán một chủ: ghi trên quán, thiếu thì thành viên đánh dấu chủ sớm nhất (như admin_overview_extra_v1)
    SELECT COALESCE(b.owner_user_id, (SELECT m.user_id FROM public.store_members m
                                       WHERE m.store_id = b.id AND m.is_owner ORDER BY m.created_at LIMIT 1)) AS owner_id
      FROM base b
  ), owners AS (
    SELECT owner_id, count(*) AS n FROM owner_of WHERE owner_id IS NOT NULL GROUP BY 1
  ), coh AS (  -- quán trong 12 tháng, số đơn theo tuổi quán
    SELECT date_trunc('month', b.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS month,
           b.created_at <= now() - interval '7 days' AS mature_7,
           b.created_at <= now() - interval '30 days' AS mature_30,
           b.created_at <= now() - interval '60 days' AS mature_60,
           EXISTS (SELECT 1 FROM public.products p WHERE p.store_id = b.id AND p.product_type = 'finished'
                    AND NOT COALESCE(p.is_deleted, false) AND COALESCE(p.is_active, true)
                    AND NOT COALESCE(p.is_raw_material, false)) AS has_menu,
           o.n7, o.n30, o.n60
      FROM base b
      CROSS JOIN LATERAL (
        SELECT count(*) FILTER (WHERE od.created_at < b.created_at + interval '7 days') AS n7,
               count(*) FILTER (WHERE od.created_at < b.created_at + interval '30 days') AS n30,
               count(*) FILTER (WHERE od.created_at >= b.created_at + interval '30 days') AS n60
          FROM public.orders od
         WHERE od.store_id = b.id AND od.status = 'completed' AND od.created_at >= b.created_at
           AND od.created_at < b.created_at + interval '60 days') o
     WHERE b.created_at >= (v_first_month::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh')
  )
  SELECT jsonb_build_object('ok', true,
    'thresholds', jsonb_build_object('real_use_7d', c_real_7d, 'real_use_30d', c_real_30d),
    'money', jsonb_build_object(
      -- Pro không thời hạn có tiền cũng không chia được theo tháng → đếm riêng, không vào MRR
      'mrr_vnd', COALESCE((SELECT sum(mrr) FROM paying), 0),
      'paying_stores', (SELECT count(*) FROM paying),
      'manual_paid_stores', (SELECT count(*) FROM pro WHERE plan_ends_at IS NOT NULL AND id NOT IN (SELECT id FROM paying)
                                AND id IN (SELECT store_id FROM manual)),
      'comp_stores', (SELECT count(*) FROM pro WHERE plan_ends_at IS NOT NULL AND id NOT IN (SELECT id FROM paying)
                         AND id NOT IN (SELECT store_id FROM manual)),
      'lifetime_stores', (SELECT count(*) FROM pro WHERE plan_ends_at IS NULL),
      'cash_30d_vnd', COALESCE((SELECT sum(amount_vnd) FROM act WHERE created_at > now() - interval '30 days'), 0),
      'first_paid_30d', (SELECT count(*) FROM first_paid WHERE at > now() - interval '30 days'),
      'renewed_30d', (SELECT count(DISTINCT p.store_id) FROM paid p JOIN first_paid f ON f.store_id = p.store_id
                       WHERE p.created_at > now() - interval '30 days' AND p.created_at > f.at
                         -- ghi thêm tiền mà không kéo dài hạn thì không phải trả tiếp
                         AND (p.action = 'payment' OR p.before->>'plan' IS DISTINCT FROM 'pro' OR p.before->>'plan_ends_at' IS NULL
                              OR (p.after->>'plan_ends_at')::timestamptz > (p.before->>'plan_ends_at')::timestamptz)),
      -- quán TỪNG TRẢ TIỀN đã hết hạn; quán được tặng hết hạn không phải mất khách trả phí
      'pro_lapsed', (SELECT count(*) FROM base b JOIN first_paid f ON f.store_id = b.id
                      WHERE b.plan = 'pro' AND b.status <> 'locked' AND b.plan_ends_at <= now()),
      'trial_ending_30d', (SELECT count(*) FROM base WHERE plan <> 'pro' AND status <> 'locked'
                            AND trial_ends_at > now() AND trial_ends_at <= now() + interval '30 days'),
      'self_extend_30d', (SELECT count(*) FROM act WHERE action = 'self_extend' AND created_at > now() - interval '30 days')),
    'usage', jsonb_build_object(
      'real_use_7d', (SELECT count(*) FROM (SELECT od.store_id FROM public.orders od JOIN base b ON b.id = od.store_id
                                             WHERE od.status = 'completed' AND od.created_at > now() - interval '7 days'
                                             GROUP BY 1 HAVING count(*) >= c_real_7d) x),
      'customers', (SELECT count(*) FROM owners),
      'multi_store_customers', (SELECT count(*) FROM owners WHERE n > 1)),
    -- Mỗi bước chỉ tính trên quán đã đủ tuổi của bước đó; chưa quán nào đủ tuổi thì NULL ("chưa đủ ngày"), không phải 0
    'cohorts', (SELECT jsonb_agg(jsonb_build_object(
        'month', m.month,
        'created', COALESCE(x.created, 0),
        'has_menu', COALESCE(x.has_menu, 0),
        'mature_7d', COALESCE(x.m7, 0),
        'first_order_7d', CASE WHEN COALESCE(x.m7, 0) > 0 THEN x.first7 END,
        'mature_30d', COALESCE(x.m30, 0),
        'real_use_30d', CASE WHEN COALESCE(x.m30, 0) > 0 THEN x.real30 END,
        'mature_60d', COALESCE(x.m60, 0),
        'retained_60d', CASE WHEN COALESCE(x.m60, 0) > 0 THEN x.ret60 END) ORDER BY m.month)
      FROM (SELECT g::date AS month FROM generate_series(v_first_month::timestamp, v_this_month::timestamp, interval '1 month') g) m
      LEFT JOIN (
        SELECT month, count(*) AS created, count(*) FILTER (WHERE has_menu) AS has_menu,
               count(*) FILTER (WHERE mature_7) AS m7, count(*) FILTER (WHERE mature_7 AND n7 > 0) AS first7,
               count(*) FILTER (WHERE mature_30) AS m30, count(*) FILTER (WHERE mature_30 AND n30 >= c_real_30d) AS real30,
               count(*) FILTER (WHERE mature_60) AS m60, count(*) FILTER (WHERE mature_60 AND n60 > 0) AS ret60
          FROM coh GROUP BY 1) x ON x.month = m.month)
  ) INTO r;
  RETURN r;
END
$fn$;

CREATE OR REPLACE FUNCTION public.admin_store_list_v2(
  p_filter text DEFAULT 'all', p_search text DEFAULT NULL, p_include_test boolean DEFAULT false,
  p_limit int DEFAULT 50, p_offset int DEFAULT 0,
  p_sort text DEFAULT 'default', p_dir text DEFAULT 'desc', p_owner uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_lim int := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
  v_off bigint := GREATEST(COALESCE(p_offset, 0), 0);
  v_q text := NULLIF(btrim(COALESCE(p_search, '')), '');
  v_sort text := COALESCE(p_sort, 'default');
  v_sign int;
  r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF COALESCE(p_filter, 'all') NOT IN ('all', 'active', 'sleeping', 'never', 'new7', 'test') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_FILTER');
  END IF;
  IF v_sort NOT IN ('default', 'orders_7d', 'orders_30d', 'last_order_at', 'created_at', 'menu_items', 'name')
     OR COALESCE(p_dir, 'desc') NOT IN ('asc', 'desc') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_SORT');
  END IF;
  v_sign := CASE WHEN p_dir = 'asc' THEN 1 ELSE -1 END;
  WITH own AS (  -- một quán một chủ, tính trước khi lọc để số quán của chủ không đổi theo ô tìm kiếm
    SELECT st.id,
           COALESCE(st.owner_user_id, (SELECT m.user_id FROM public.store_members m
                                        WHERE m.store_id = st.id AND m.is_owner ORDER BY m.created_at LIMIT 1)) AS owner_id,
           EXISTS (SELECT 1 FROM public.admin_test_stores t WHERE t.store_id = st.id) AS is_test
      FROM public.stores st
  ), rows AS (
    SELECT st.id, st.name, st.store_code, st.plan, st.status, st.trial_ends_at, st.plan_ends_at, st.last_active_at, st.created_at,
           ow.owner_id AS owner_user_id, ow.is_test,
           (SELECT display_name FROM public.user_accounts u WHERE u.id = ow.owner_id) AS owner_name,
           (SELECT count(*) FROM own o2 WHERE o2.owner_id = ow.owner_id AND (p_include_test OR NOT o2.is_test)) AS owner_store_count,
           (SELECT count(*) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed'
               AND o.created_at > now() - interval '7 days') AS orders_7d,
           (SELECT count(*) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed'
               AND o.created_at > now() - interval '30 days') AS orders_30d,
           (SELECT max(o.created_at) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed') AS last_order_at,
           (SELECT count(DISTINCT l.device_id) FROM public.app_logs l WHERE l.store_id = st.id
               AND l.created_at > now() - interval '30 days' AND l.device_id IS NOT NULL AND l.device_id <> 'Unknown') AS devices,
           (SELECT max(l.created_at) FROM public.app_logs l WHERE l.store_id = st.id
               AND l.created_at > now() - interval '30 days') AS device_last_seen,
           (SELECT count(DISTINCT x.u) FROM (
               SELECT m.user_id AS u FROM public.store_members m WHERE m.store_id = st.id AND m.is_owner
               UNION SELECT st.owner_user_id WHERE st.owner_user_id IS NOT NULL) x) AS staff_owner,
           (SELECT count(*) FROM public.store_members m WHERE m.store_id = st.id AND NOT COALESCE(m.is_owner, false)
               AND m.user_id IS DISTINCT FROM st.owner_user_id
               AND lower(COALESCE(m.role, '')) IN ('manager', 'quản lý', 'quan ly')) AS staff_manager,
           (SELECT count(*) FROM public.store_members m WHERE m.store_id = st.id AND NOT COALESCE(m.is_owner, false)
               AND m.user_id IS DISTINCT FROM st.owner_user_id
               AND lower(COALESCE(m.role, '')) NOT IN ('manager', 'quản lý', 'quan ly', 'owner', 'unassigned')) AS staff_other,
           (SELECT count(*) FROM public.products p WHERE p.store_id = st.id AND p.product_type = 'finished'
               AND NOT COALESCE(p.is_deleted, false) AND COALESCE(p.is_active, true)
               AND NOT COALESCE(p.is_raw_material, false)) AS menu_items
      FROM public.stores st JOIN own ow ON ow.id = st.id
     WHERE (p_owner IS NULL OR ow.owner_id = p_owner)
  ), f AS (
    SELECT * FROM rows
     WHERE (v_q IS NULL OR name ILIKE '%' || v_q || '%' OR store_code ILIKE '%' || v_q || '%' OR owner_name ILIKE '%' || v_q || '%')
       AND CASE COALESCE(p_filter, 'all')
             WHEN 'test' THEN is_test
             ELSE (p_include_test OR NOT is_test) AND CASE COALESCE(p_filter, 'all')
               WHEN 'active' THEN orders_7d > 0
               WHEN 'sleeping' THEN last_order_at IS NOT NULL AND orders_30d = 0
               WHEN 'never' THEN last_order_at IS NULL
               WHEN 'new7' THEN created_at > now() - interval '7 days'
               ELSE true END
           END
  ), page AS (
    SELECT f.*, row_number() OVER (ORDER BY
             -- quán chưa có đơn nào luôn xếp sau khi sắp theo "đơn gần nhất"
             v_sign * CASE v_sort WHEN 'orders_7d' THEN orders_7d
                                  WHEN 'orders_30d' THEN orders_30d
                                  WHEN 'menu_items' THEN menu_items
                                  WHEN 'last_order_at' THEN extract(epoch FROM last_order_at)
                                  WHEN 'created_at' THEN extract(epoch FROM created_at) END ASC NULLS LAST,
             CASE WHEN v_sort = 'name' AND v_sign = 1 THEN lower(name) END ASC,
             CASE WHEN v_sort = 'name' AND v_sign = -1 THEN lower(name) END DESC,
             orders_7d DESC, created_at DESC, id  -- mã quán chốt thứ tự để phân trang không trùng / sót
           ) AS rn
      FROM f
  )
  SELECT jsonb_build_object('ok', true, 'total', (SELECT count(*) FROM f),
    'rows', COALESCE((SELECT jsonb_agg(to_jsonb(x) - 'rn' ORDER BY x.rn)
                        FROM (SELECT * FROM page WHERE rn > v_off AND rn <= v_off + v_lim) x), '[]'::jsonb))
    INTO r;
  RETURN r;
END
$fn$;

REVOKE ALL ON FUNCTION public.admin_growth_v1(boolean) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.admin_store_list_v2(text, text, boolean, int, int, text, text, uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_growth_v1(boolean) TO qn_admin;
GRANT EXECUTE ON FUNCTION public.admin_store_list_v2(text, text, boolean, int, int, text, text, uuid) TO qn_admin;

DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY['public.admin_growth_v1(boolean)', 'public.admin_store_list_v2(text,text,boolean,int,int,text,text,uuid)'] LOOP
    IF has_function_privilege('anon', f, 'execute') OR has_function_privilege('authenticated', f, 'execute')
       OR NOT has_function_privilege('qn_admin', f, 'execute') THEN
      RAISE EXCEPTION 'ADMIN TANG TRUONG: quyền % không đúng thiết kế', f;
    END IF;
  END LOOP;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
