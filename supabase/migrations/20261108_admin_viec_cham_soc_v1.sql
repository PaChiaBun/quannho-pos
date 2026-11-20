-- ============================================================================
-- /admin: QUÁN CẦN GỌI SỚM. Một hàm CHỈ ĐỌC, chỉ vé quản trị; không đổi bảng, không đổi hàm cũ.
--   admin_care_v1(p_include_test):
--   • concentration — quán lớn nhất và 3 quán lớn nhất chiếm bao nhiêu % doanh số 30 ngày
--   • declining     — đơn 7 ngày giảm từ một nửa trở lên so với 7 ngày trước, kỳ trước từ 20 đơn;
--                     quán về 0 đơn đã nằm ở "Quán đang bỏ dùng" nên không lặp lại ở đây
--   • new_idle      — quán tạo trong 14 ngày, chưa có đơn hoàn thành nào, không khoá
-- Hoàn tác: …_ROLLBACK.sql
-- ============================================================================
BEGIN;

DO $$
BEGIN
  IF to_regprocedure('public.qn_admin_caller()') IS NULL OR to_regclass('public.admin_test_stores') IS NULL THEN
    RAISE EXCEPTION 'Cần áp trang quản trị trước';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.admin_care_v1(p_include_test boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  c_min_prev constant int := 20;  -- kỳ trước dưới mức này thì dao động ngẫu nhiên, gọi vô ích
  r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  WITH base AS (
    SELECT st.* FROM public.stores st
     WHERE p_include_test OR NOT EXISTS (SELECT 1 FROM public.admin_test_stores t WHERE t.store_id = st.id)
  ), per AS (
    SELECT o.store_id,
           count(*) FILTER (WHERE o.created_at > now() - interval '7 days') AS o7,
           count(*) FILTER (WHERE o.created_at <= now() - interval '7 days' AND o.created_at > now() - interval '14 days') AS prev7,
           COALESCE(sum(COALESCE(o.total_amount, o.total, 0)) FILTER (WHERE o.created_at > now() - interval '30 days'), 0) AS r30,
           max(o.created_at) AS last_order
      FROM public.orders o JOIN base b ON b.id = o.store_id
     WHERE o.status = 'completed' AND o.created_at > now() - interval '30 days'
     GROUP BY o.store_id
  ), ranked AS (
    SELECT r30, row_number() OVER (ORDER BY r30 DESC) AS rn FROM per WHERE r30 > 0
  ), owner_of AS (  -- chủ: ghi trên quán, thiếu thì thành viên đánh dấu chủ sớm nhất (như admin_overview_extra_v1)
    SELECT b.id AS store_id, u.display_name AS owner_name, u.phone AS owner_phone
      FROM base b
      LEFT JOIN public.user_accounts u ON u.id = COALESCE(b.owner_user_id, (
        SELECT m.user_id FROM public.store_members m WHERE m.store_id = b.id AND m.is_owner ORDER BY m.created_at LIMIT 1))
  ), down AS (
    SELECT b.id, b.name, b.store_code AS code, ow.owner_name, ow.owner_phone, p.o7 AS orders_7d, p.prev7 AS orders_prev7,
           round(100.0 * (p.prev7 - p.o7) / p.prev7) AS drop_pct, p.last_order AS last_order_at, b.status = 'locked' AS locked
      FROM per p JOIN base b ON b.id = p.store_id JOIN owner_of ow ON ow.store_id = b.id
     WHERE p.prev7 >= c_min_prev AND p.o7 > 0 AND p.o7 * 2 <= p.prev7
  ), idle AS (
    SELECT b.id, b.name, b.store_code AS code, ow.owner_name, ow.owner_phone, b.created_at,
           EXISTS (SELECT 1 FROM public.products pr WHERE pr.store_id = b.id AND pr.product_type = 'finished'
                    AND NOT COALESCE(pr.is_deleted, false) AND COALESCE(pr.is_active, true)
                    AND NOT COALESCE(pr.is_raw_material, false)) AS has_menu
      FROM base b JOIN owner_of ow ON ow.store_id = b.id
     WHERE b.created_at > now() - interval '14 days' AND b.status IS DISTINCT FROM 'locked'
       AND NOT EXISTS (SELECT 1 FROM public.orders o WHERE o.store_id = b.id AND o.status = 'completed')
  )
  SELECT jsonb_build_object('ok', true,
    'concentration', jsonb_build_object(
      'stores', (SELECT count(*) FROM ranked),
      'top1_pct', (SELECT round(100 * max(r30) / NULLIF(sum(r30), 0)) FROM ranked),
      'top3_pct', (SELECT round(100 * sum(r30) FILTER (WHERE rn <= 3) / NULLIF(sum(r30), 0)) FROM ranked)),
    'declining', jsonb_build_object('total', (SELECT count(*) FROM down),
      'rows', COALESCE((SELECT jsonb_agg(t ORDER BY t.orders_prev7 - t.orders_7d DESC, t.id) FROM (
          SELECT * FROM down ORDER BY orders_prev7 - orders_7d DESC, id LIMIT 20) t), '[]'::jsonb)),
    'new_idle', jsonb_build_object('total', (SELECT count(*) FROM idle),
      'rows', COALESCE((SELECT jsonb_agg(t ORDER BY t.created_at, t.id) FROM (
          SELECT * FROM idle ORDER BY created_at, id LIMIT 30) t), '[]'::jsonb))
  ) INTO r;
  RETURN r;
END
$fn$;

REVOKE ALL ON FUNCTION public.admin_care_v1(boolean) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_care_v1(boolean) TO qn_admin;

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.admin_care_v1(boolean)', 'execute')
     OR has_function_privilege('authenticated', 'public.admin_care_v1(boolean)', 'execute')
     OR NOT has_function_privilege('qn_admin', 'public.admin_care_v1(boolean)', 'execute') THEN
    RAISE EXCEPTION 'QUAN CAN GOI: quyền không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
