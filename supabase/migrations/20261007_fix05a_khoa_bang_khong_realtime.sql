-- ═════════════════════════════════════════════════════════════════════════════
-- FIX 05a (07/10/2026) — Khoá các bảng KHÔNG dùng realtime + RPC báo cáo + chống spam
-- Bảng có realtime (bàn, bếp, đơn, menu…) để FIX 05b, sau khi app dùng JWT.
-- Rollback: 20261007_fix05a_ROLLBACK.sql
-- ═════════════════════════════════════════════════════════════════════════════

-- 1. Bỏ policy "ai cũng được" trên bảng đã có policy cô lập theo quán
DROP POLICY IF EXISTS settings_all ON public.app_settings;
DROP POLICY IF EXISTS finance_records_select_all ON public.finance_records;
DROP POLICY IF EXISTS staff_shifts_select_all ON public.staff_shifts;
DROP POLICY IF EXISTS production_logs_all ON public.production_logs;
DROP POLICY IF EXISTS production_orders_all ON public.production_orders;
DROP POLICY IF EXISTS recipes_all ON public.recipes;
DROP POLICY IF EXISTS devices_all_fixed ON public.devices;

-- 2. Thay policy "ai cũng được" bằng cô lập theo quán
DO $$ DECLARE r record; BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('coupons','coupons_all'), ('void_audit_logs','void_audit_logs_all'),
    ('payment_settlements','payment_settlements_all'), ('ban_session_orders','ban_session_orders_all'),
    ('ban_session_order_items','ban_session_order_items_all'), ('qr_audit_logs','qr_audit_logs_all'),
    ('qr_coupon_redemptions','qr_coupon_redemptions_all'),
    ('payroll_periods','Allow all for payroll_periods'), ('payroll_records','Allow all for payroll_records'),
    ('daily_order_counters',NULL), ('pos_coupon_redemptions',NULL), ('pos_idempotency_operations',NULL),
    ('store_shift_configs',NULL)) AS v(t, oldp)
  LOOP
    IF r.oldp IS NOT NULL THEN EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.oldp, r.t); END IF;
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.t || '_isolation_v5', r.t);
    EXECUTE format('CREATE POLICY %I ON public.%I TO anon, authenticated USING (store_id = (SELECT public.current_store_id())) WITH CHECK (store_id = (SELECT public.current_store_id()))', r.t || '_isolation_v5', r.t);
  END LOOP;
END $$;

-- 3. app_logs: ai cũng GHI được log (để không mất log trước đăng nhập), chỉ thành viên quán mới ĐỌC/sửa/xoá
DROP POLICY IF EXISTS app_logs_all ON public.app_logs;
DROP POLICY IF EXISTS app_logs_insert_v5 ON public.app_logs;
DROP POLICY IF EXISTS app_logs_isolation_v5 ON public.app_logs;
CREATE POLICY app_logs_insert_v5 ON public.app_logs FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY app_logs_isolation_v5 ON public.app_logs TO anon, authenticated USING (store_id = (SELECT public.current_store_id()));

-- 4. Bảng con không có store_id: cô lập qua bảng cha
DROP POLICY IF EXISTS recipe_ingredients_all ON public.recipe_ingredients;
DROP POLICY IF EXISTS recipe_ingredients_read_all ON public.recipe_ingredients;
DROP POLICY IF EXISTS recipe_ingredients_isolation_v5 ON public.recipe_ingredients;
CREATE POLICY recipe_ingredients_isolation_v5 ON public.recipe_ingredients TO anon, authenticated
  USING (EXISTS (SELECT 1 FROM public.recipes r WHERE r.id = recipe_ingredients.recipe_id AND r.store_id = (SELECT public.current_store_id())))
  WITH CHECK (EXISTS (SELECT 1 FROM public.recipes r WHERE r.id = recipe_ingredients.recipe_id AND r.store_id = (SELECT public.current_store_id())));

DROP POLICY IF EXISTS purchase_items_read_all ON public.purchase_items;
DROP POLICY IF EXISTS purchase_items_isolation_v5 ON public.purchase_items;
CREATE POLICY purchase_items_isolation_v5 ON public.purchase_items TO anon, authenticated
  USING (EXISTS (SELECT 1 FROM public.purchase_orders po WHERE po.id = coalesce(purchase_items.po_id, purchase_items.purchase_id) AND po.store_id = (SELECT public.current_store_id())))
  WITH CHECK (EXISTS (SELECT 1 FROM public.purchase_orders po WHERE po.id = coalesce(purchase_items.po_id, purchase_items.purchase_id) AND po.store_id = (SELECT public.current_store_id())));

DROP POLICY IF EXISTS session_item_modifiers_read_all ON public.session_item_modifiers;
DROP POLICY IF EXISTS session_item_modifiers_isolation_v5 ON public.session_item_modifiers;
CREATE POLICY session_item_modifiers_isolation_v5 ON public.session_item_modifiers TO anon, authenticated
  USING (EXISTS (SELECT 1 FROM public.ban_session_items i WHERE i.id = session_item_modifiers.session_item_id AND i.store_id = (SELECT public.current_store_id())))
  WITH CHECK (EXISTS (SELECT 1 FROM public.ban_session_items i WHERE i.id = session_item_modifiers.session_item_id AND i.store_id = (SELECT public.current_store_id())));

-- 5. Chống spam tạo tài khoản / quán (thực tế ~5 đăng ký/ngày; đợt spam: >2.000/giờ)
CREATE OR REPLACE FUNCTION public.qn_rate_limit_signup()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE n int;
BEGIN
  IF TG_TABLE_NAME = 'user_accounts' THEN
    SELECT count(*) INTO n FROM public.user_accounts WHERE created_at > now() - interval '10 minutes';
    IF n >= 20 THEN RAISE EXCEPTION 'Hệ thống đang nhận quá nhiều đăng ký, vui lòng thử lại sau ít phút' USING ERRCODE = 'P0429'; END IF;
  ELSIF TG_TABLE_NAME = 'stores' THEN
    SELECT count(*) INTO n FROM public.stores WHERE created_at > now() - interval '10 minutes';
    IF n >= 15 THEN RAISE EXCEPTION 'Hệ thống đang nhận quá nhiều yêu cầu tạo quán, vui lòng thử lại sau ít phút' USING ERRCODE = 'P0429'; END IF;
    IF NEW.owner_user_id IS NOT NULL THEN
      SELECT count(*) INTO n FROM public.stores WHERE owner_user_id = NEW.owner_user_id AND created_at > now() - interval '1 day';
      IF n >= 5 THEN RAISE EXCEPTION 'Mỗi tài khoản chỉ tạo tối đa 5 quán mỗi ngày' USING ERRCODE = 'P0429'; END IF;
    END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS qn_rate_limit_signup_trg ON public.user_accounts;
CREATE TRIGGER qn_rate_limit_signup_trg BEFORE INSERT ON public.user_accounts FOR EACH ROW EXECUTE FUNCTION public.qn_rate_limit_signup();
DROP TRIGGER IF EXISTS qn_rate_limit_signup_trg ON public.stores;
CREATE TRIGGER qn_rate_limit_signup_trg BEFORE INSERT ON public.stores FOR EACH ROW EXECUTE FUNCTION public.qn_rate_limit_signup();

-- 6. RPC báo cáo doanh thu: chỉ thành viên quán
CREATE OR REPLACE FUNCTION public.get_daily_revenue_for_range_v1(p_store_id uuid, p_from timestamp with time zone, p_to timestamp with time zone, p_tz text DEFAULT 'Asia/Ho_Chi_Minh'::text)
 RETURNS TABLE(report_date text, total_orders bigint, total_revenue numeric, cash_revenue numeric, transfer_revenue numeric, total_discount numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_tz text := COALESCE(NULLIF(TRIM(p_tz), ''), 'Asia/Ho_Chi_Minh');
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
$function$
;

CREATE OR REPLACE FUNCTION public.get_report_stats_for_range_v1(p_store_id uuid, p_from timestamp with time zone, p_to timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  -- FIX05: chỉ thành viên của quán (hoặc service_role/kết nối nội bộ) mới xem được báo cáo
  IF NOT (public.qn_is_member(p_store_id)
          OR coalesce(NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role', '') = 'service_role'
          OR NULLIF(current_setting('request.jwt.claims', true), '') IS NULL) THEN
    RAISE EXCEPTION 'Không có quyền xem báo cáo của quán này' USING ERRCODE = '42501';
  END IF;
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
NOTIFY pgrst, 'reload schema';
