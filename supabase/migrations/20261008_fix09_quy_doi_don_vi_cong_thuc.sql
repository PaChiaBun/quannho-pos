-- FIX 09 (08/10/2026) — Trừ kho theo công thức phải quy đổi đơn vị (g→kg, ml→hộp/lít, g→gói...)
-- Nguyên nhân: complete_pos_sale_v1 và settle_ban_session_v5 trên DB thật trừ thẳng số lượng công thức (vd 15 g)
--   vào đơn vị kho (vd 15 gói) vì migration 20261001_fix_recipe_unit_conversion... chưa từng được áp.
-- Gồm: (A) hàm quy đổi + 2 RPC bán hàng có quy đổi (nội dung lấy từ migration 01/10, đã đối chiếu: chỉ khác phần quy đổi so với bản đang chạy)
--      (B) reconcile_recipe_usage_units_v2(dry_run): bù lại các lần trừ sai trước đây, APPEND-ONLY (reason='reconciliation'), idempotent.
-- Rollback: 20261008_fix09_ROLLBACK.sql (trả 2 RPC về bản trước; bút toán bù không xóa)
SET search_path = public, extensions, pg_catalog, pg_temp;

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS conversion_rate numeric DEFAULT 0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS conversion_unit text DEFAULT '';

-- ── 2. HÀM QUY ĐỔI ĐƠN VỊ ĐỊNH LƯỢNG NGUYÊN LIỆU F&B CHUẨN ──────────────────
CREATE OR REPLACE FUNCTION public.convert_recipe_ingredient_qty_v1(
  p_qty numeric,
  p_recipe_unit text,
  p_product_unit text,
  p_conversion_rate numeric DEFAULT 0,
  p_conversion_unit text DEFAULT ''
)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_r text := lower(trim(COALESCE(p_recipe_unit, '')));
  v_p text := lower(trim(COALESCE(p_product_unit, '')));
  v_c text := lower(trim(COALESCE(p_conversion_unit, '')));
  v_rate numeric := COALESCE(p_conversion_rate, 0);
  v_qty numeric := COALESCE(p_qty, 0);
  v_r_is_base boolean;
  v_r_is_large boolean;
  v_p_is_base boolean;
  v_p_is_large boolean;
  v_c_is_base boolean;
  v_c_is_large boolean;
BEGIN
  -- Phòng vệ số lượng 0 hoặc null
  IF v_qty = 0 THEN
    RETURN 0;
  END IF;

  -- Chuẩn hóa tên đơn vị & từ đồng nghĩa (synonyms / aliases)
  -- Khối lượng cơ sở (gram)
  IF v_r IN ('g', 'gr', 'gram', 'gam', 'grm') THEN v_r := 'g'; END IF;
  IF v_p IN ('g', 'gr', 'gram', 'gam', 'grm') THEN v_p := 'g'; END IF;
  IF v_c IN ('g', 'gr', 'gram', 'gam', 'grm') THEN v_c := 'g'; END IF;

  -- Khối lượng lớn (kilogram)
  IF v_r IN ('kg', 'ký', 'ky', 'kí', 'ki', 'kilogram', 'kilo') THEN v_r := 'kg'; END IF;
  IF v_p IN ('kg', 'ký', 'ky', 'kí', 'ki', 'kilogram', 'kilo') THEN v_p := 'kg'; END IF;
  IF v_c IN ('kg', 'ký', 'ky', 'kí', 'ki', 'kilogram', 'kilo') THEN v_c := 'kg'; END IF;

  -- Thể tích cơ sở (milliliter)
  IF v_r IN ('ml', 'mililit', 'mililít', 'mili lit', 'mili lít', 'milliliter', 'cc') THEN v_r := 'ml'; END IF;
  IF v_p IN ('ml', 'mililit', 'mililít', 'mili lit', 'mili lít', 'milliliter', 'cc') THEN v_p := 'ml'; END IF;
  IF v_c IN ('ml', 'mililit', 'mililít', 'mili lit', 'mili lít', 'milliliter', 'cc') THEN v_c := 'ml'; END IF;

  -- Thể tích lớn (liter)
  IF v_r IN ('l', 'lit', 'lít', 'liter', 'litre') THEN v_r := 'lít'; END IF;
  IF v_p IN ('l', 'lit', 'lít', 'liter', 'litre') THEN v_p := 'lít'; END IF;
  IF v_c IN ('l', 'lit', 'lít', 'liter', 'litre') THEN v_c := 'lít'; END IF;

  -- 1. Cùng đơn vị: Giữ nguyên số lượng
  IF v_r = v_p AND v_r <> '' THEN
    RETURN v_qty;
  END IF;

  -- Đánh dấu phân loại thang đo đơn vị
  v_r_is_base := v_r IN ('g', 'ml');
  v_r_is_large := v_r IN ('kg', 'lít');
  v_p_is_base := v_p IN ('g', 'ml');
  v_p_is_large := v_p IN ('kg', 'lít');
  v_c_is_base := v_c IN ('g', 'ml');
  v_c_is_large := v_c IN ('kg', 'lít');

  -- 2. Quy đổi theo quy cách đóng gói (VD: 1 lon = 385 ml, 1 hộp = 1000 ml, 1 gói = 500 g)
  IF v_rate > 0 AND v_c <> '' THEN
    -- Nếu đơn vị công thức khớp đơn vị sản phẩm (VD công thức chỉ định 1 lon)
    IF v_r = v_p THEN
      RETURN v_qty;
    END IF;

    -- Nếu đơn vị công thức khớp đơn vị quy cách hoặc cùng thang cơ sở (g/ml tương đương tỷ trọng 1.0)
    IF (v_r = v_c) OR (v_r_is_base AND v_c_is_base) THEN
      RETURN v_qty / v_rate;
    END IF;

    -- Đơn vị công thức là đơn vị lớn (lít/kg) còn quy cách tính bằng đơn vị nhỏ (ml/g)
    -- VD: công thức dùng 0.385 lít, quy cách 1 lon = 385 ml -> (0.385 * 1000) / 385 = 1 lon
    IF v_r_is_large AND v_c_is_base THEN
      RETURN (v_qty * 1000.0) / v_rate;
    END IF;

    -- Đơn vị công thức là đơn vị nhỏ (ml/g) còn quy cách tính bằng đơn vị lớn (lít/kg)
    IF v_r_is_base AND v_c_is_large THEN
      RETURN (v_qty / 1000.0) / v_rate;
    END IF;
  END IF;

  -- 3. Quy đổi hệ mét F&B tiêu chuẩn (Small <-> Large, tỷ trọng chất lỏng F&B xấp xỉ 1.0)
  -- Nhỏ sang lớn (gram/ml sang kg/lít): chia 1000.0
  -- VD: 20 ml -> 0.020 kg, 13 g -> 0.013 kg, 15 g -> 0.015 lít
  IF v_r_is_base AND v_p_is_large THEN
    RETURN v_qty / 1000.0;
  END IF;

  -- Lớn sang nhỏ (kg/lít sang gram/ml): nhân 1000.0
  IF v_r_is_large AND v_p_is_base THEN
    RETURN v_qty * 1000.0;
  END IF;

  -- Cùng cấp độ đơn vị chéo (g <-> ml hoặc kg <-> lít): tỷ trọng 1.0
  IF (v_r_is_base AND v_p_is_base) OR (v_r_is_large AND v_p_is_large) THEN
    RETURN v_qty;
  END IF;

  -- 4. Fallback: Đơn vị không tương thích hoặc rời rạc (cái, gói, phần...) trả về số lượng thô
  RETURN v_qty;
END;
$$;

-- Alias hàm tiện ích
CREATE OR REPLACE FUNCTION public.convert_fnb_unit(
  p_recipe_qty numeric,
  p_recipe_unit text,
  p_product_unit text,
  p_conversion_rate numeric DEFAULT 0,
  p_conversion_unit text DEFAULT ''
)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT public.convert_recipe_ingredient_qty_v1(p_recipe_qty, p_recipe_unit, p_product_unit, p_conversion_rate, p_conversion_unit);
$$;

REVOKE ALL ON FUNCTION public.convert_recipe_ingredient_qty_v1(numeric, text, text, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.convert_recipe_ingredient_qty_v1(numeric, text, text, numeric, text) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.convert_fnb_unit(numeric, text, text, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.convert_fnb_unit(numeric, text, text, numeric, text) TO anon, authenticated, service_role;


-- ── 3. CẬP NHẬT FUNCTION: complete_pos_sale_v1 ────────────────────────────────
CREATE OR REPLACE FUNCTION public.complete_pos_sale_v1(
  p_store_id uuid,
  p_idempotency_key text,
  p_lines jsonb,
  p_payment_method text DEFAULT 'cash',
  p_customer_id uuid DEFAULT NULL,
  p_discount numeric DEFAULT 0,
  p_loyalty_pts_used numeric DEFAULT 0,
  p_note text DEFAULT NULL,
  p_coupon_code text DEFAULT NULL,
  p_source_type text DEFAULT 'pos',
  p_source_id text DEFAULT NULL,
  p_expected_total numeric DEFAULT NULL,
  p_kitchen_session_ids uuid[] DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $$
DECLARE
  v_staff record;
  v_existing_op record;
  v_pos_op_id uuid;
  v_cart_fingerprint text;
  v_order_id uuid;
  v_order_number text;
  v_line jsonb;
  v_subtotal numeric := 0;
  v_authoritative_discount numeric := 0;
  v_points_discount numeric := 0;
  v_coupon_discount numeric := 0;
  v_total_amount numeric := 0;
  v_pts_earned numeric := 0;
  v_fund_type text;
  v_loyalty_rate_str text;
  v_loyalty_rate numeric := 10000;
  v_redeem_rate_str text;
  v_redeem_rate numeric := 1000;
  v_prod record;
  v_order_item_id uuid;
  v_qty numeric;
  v_unit_price numeric;
  v_line_subtotal numeric;
  v_customer record;
  v_coupon_id uuid;
  v_coupon_active boolean;
  v_coupon_start timestamptz;
  v_coupon_end timestamptz;
  v_coupon_type text;
  v_coupon_val numeric;
  v_coupon_min_order numeric;
  v_coupon_max_disc numeric;
  v_clean_source_type text;
  v_has_recipe boolean;
  v_rec_ing record;
  v_actual_ing_qty numeric;
  v_wallet_real_used numeric := 0;
  v_wallet_bonus_used numeric := 0;
  v_wallet_real numeric := 0;
  v_wallet_bonus numeric := 0;
  v_wallet_cap numeric;
  v_manual_discount numeric := 0;
  v_staff_actions jsonb;
  v_session_id uuid;
  v_pos_session record;
BEGIN
  -- 1. Xác thực quyền pos.checkout (Fail-Closed)
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);

  -- 2. Validate payload cơ bản
  IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Idempotency key là bắt buộc');
  END IF;

  IF p_lines IS NULL OR jsonb_typeof(p_lines) <> 'array' OR jsonb_array_length(p_lines) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'EMPTY_CART', 'message', 'Giỏ hàng trống hoặc định dạng không hợp lệ');
  END IF;

  p_payment_method := lower(trim(COALESCE(p_payment_method, 'cash')));
  IF p_payment_method NOT IN ('cash', 'transfer', 'card', 'bank', 'wallet') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYMENT_METHOD', 'message', 'Phương thức thanh toán không hợp lệ');
  END IF;

  -- Whitelist source_type
  v_clean_source_type := CASE
    WHEN lower(trim(COALESCE(p_source_type, 'pos'))) IN ('pos', 'takeaway', 'delivery')
    THEN lower(trim(COALESCE(p_source_type, 'pos')))
    ELSE 'pos'
  END;

  -- 3. Advisory lock trên idempotency key
  PERFORM pg_advisory_xact_lock(hashtext(p_store_id::text), hashtext('pos_sale:' || p_idempotency_key));

  -- 4. Băm cart fingerprint
  v_cart_fingerprint := encode(digest(
    p_store_id::text || ':' ||
    p_lines::text || ':' ||
    p_payment_method || ':' ||
    COALESCE(p_customer_id::text, '') || ':' ||
    round(COALESCE(p_discount, 0), 0)::text || ':' ||
    round(COALESCE(p_loyalty_pts_used, 0), 0)::text || ':' ||
    COALESCE(trim_scale(p_expected_total)::text, '') || ':' ||
    COALESCE(p_kitchen_session_ids::text, '{}') || ':' ||
    COALESCE(p_source_type, 'pos') || ':' || COALESCE(p_source_id, '') || ':' ||
    lower(trim(COALESCE(p_coupon_code, ''))),
    'sha256'
  ), 'hex');

  -- 5. Idempotency Check qua bảng pos_idempotency_operations
  SELECT * INTO v_existing_op
  FROM public.pos_idempotency_operations
  WHERE store_id = p_store_id AND idempotency_key = p_idempotency_key
  LIMIT 1;

  IF v_existing_op.id IS NOT NULL THEN
    IF v_existing_op.cart_fingerprint = v_cart_fingerprint THEN
      RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
          'order_id', v_existing_op.order_id,
          'order_number', v_existing_op.order_number,
          'total_amount', v_existing_op.total_amount,
          'payment_method', v_existing_op.payment_method,
          'wallet_real_used', v_existing_op.wallet_real_used,
          'wallet_bonus_used', v_existing_op.wallet_bonus_used,
          'subtotal', (SELECT subtotal FROM public.orders WHERE id = v_existing_op.order_id AND store_id = p_store_id),
          'discount', (SELECT discount FROM public.orders WHERE id = v_existing_op.order_id AND store_id = p_store_id),
          'is_replay', true
        )
      );
    ELSE
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'IDEMPOTENCY_CONFLICT',
        'message', 'Idempotency key đã được sử dụng với giỏ hàng hoặc giá trị khác'
      );
    END IF;
  END IF;

  -- Lock kitchen batches in a deterministic order, shared with table checkout.
  FOR v_session_id IN SELECT DISTINCT unnest(COALESCE(p_kitchen_session_ids, '{}')) ORDER BY 1 LOOP
    SELECT * INTO v_pos_session FROM public.ban_sessions
    WHERE id = v_session_id AND store_id = p_store_id FOR UPDATE;
    IF NOT FOUND OR v_pos_session.status <> 'open' THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'SESSION_NOT_OPEN', 'message', 'Phiên bếp đã đóng hoặc đã thanh toán. Hãy đối soát trước khi tiếp tục.');
    END IF;
    PERFORM 1 FROM public.ban_session_items WHERE session_id = v_session_id AND store_id = p_store_id FOR UPDATE;
    IF EXISTS (SELECT 1 FROM public.ban_session_orders WHERE session_id = v_session_id)
       OR EXISTS (SELECT 1 FROM public.ban_session_items WHERE session_id = v_session_id AND COALESCE(kitchen_status, '') = 'huy') THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'SESSION_CART_CHANGED', 'message', 'Phiên bếp đã thay đổi. Cần đối soát giỏ hàng với phiên bàn.');
    END IF;
  END LOOP;
  IF EXISTS (
    SELECT 1 FROM (
      SELECT product_id, sum(quantity) qty FROM public.ban_session_items
      WHERE store_id = p_store_id AND session_id = ANY(COALESCE(p_kitchen_session_ids, '{}'))
      GROUP BY product_id
    ) sent LEFT JOIN (
      SELECT (x->>'product_id')::uuid product_id, sum((x->>'quantity')::numeric) qty
      FROM jsonb_array_elements(p_lines) x GROUP BY 1
    ) cart USING (product_id) WHERE cart.qty IS NULL OR cart.qty < sent.qty
  ) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'SESSION_CART_CHANGED', 'message', 'Giỏ hàng thiếu món đã gửi bếp; chưa thu tiền.');
  END IF;

  -- Lock prices until commit so quote and inserted items cannot diverge.
  PERFORM 1 FROM public.products WHERE store_id = p_store_id
    AND id IN (SELECT (x->>'product_id')::uuid FROM jsonb_array_elements(p_lines) x)
    ORDER BY id FOR UPDATE;

  -- 6. Tính Subtotal Authoritative & Validate Items
  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines)
  LOOP
    v_qty := (v_line->>'quantity')::numeric;
    IF v_qty IS NULL OR v_qty <= 0 OR v_qty > 1000 THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_QUANTITY', 'message', 'Số lượng món không hợp lệ (phải > 0 và <= 1000)');
    END IF;

    SELECT * INTO v_prod FROM public.products WHERE id = (v_line->>'product_id')::uuid AND store_id = p_store_id AND is_deleted = false;
    IF v_prod IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'PRODUCT_NOT_FOUND', 'message', 'Sản phẩm không tồn tại hoặc đã bị xóa');
    END IF;

    v_unit_price := COALESCE(v_prod.sell_price, 0);
    IF v_line ? 'expected_unit_price' AND (v_line->>'expected_unit_price')::numeric IS DISTINCT FROM v_unit_price THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'FINANCIAL_QUOTE_CHANGED', 'message', 'Giá món đã đổi. Cập nhật giỏ hàng trước khi thanh toán.');
    END IF;
    v_subtotal := v_subtotal + (v_qty * v_unit_price);
  END LOOP;

  -- 7. Validate Customer & Points
  IF p_customer_id IS NOT NULL THEN
    SELECT * INTO v_customer FROM public.customers
    WHERE id = p_customer_id AND store_id = p_store_id AND is_deleted = false
    FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'CUSTOMER_NOT_FOUND', 'message', 'Khách hàng không tồn tại trong quán');
    END IF;
  END IF;
  IF p_payment_method = 'wallet' THEN
    IF p_customer_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'CUSTOMER_REQUIRED', 'message', 'Vui lòng chọn khách hàng để thanh toán ví');
    END IF;
    IF COALESCE(p_loyalty_pts_used, 0) <> 0 THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_POINTS', 'message', 'Không kết hợp đổi điểm với thanh toán ví');
    END IF;
    IF to_regclass('public.balance_transactions') IS NULL
       OR NOT (to_jsonb(v_customer) ?& ARRAY['real_balance', 'bonus_balance', 'bonus_cap_pct', 'bonus_expires_at']) THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'WALLET_SCHEMA_UNAVAILABLE', 'message', 'Cấu trúc ví chưa sẵn sàng');
    END IF;
  END IF;
  IF p_loyalty_pts_used IS NOT NULL AND p_loyalty_pts_used < 0 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_POINTS', 'message', 'Số điểm sử dụng không thể là số âm');
  END IF;

  IF p_loyalty_pts_used IS NOT NULL AND p_loyalty_pts_used > 0 THEN
    IF p_customer_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'CUSTOMER_REQUIRED', 'message', 'Vui lòng chọn khách hàng để sử dụng điểm');
    END IF;

    SELECT * INTO v_customer FROM public.customers WHERE id = p_customer_id AND store_id = p_store_id AND is_deleted = false FOR UPDATE;
    IF v_customer IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'CUSTOMER_NOT_FOUND', 'message', 'Khách hàng không tồn tại');
    END IF;

    IF p_loyalty_pts_used > COALESCE(v_customer.loyalty_pts, 0) THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INSUFFICIENT_POINTS', 'message', 'Điểm yêu cầu vượt quá số dư của khách');
    END IF;

    SELECT value INTO v_redeem_rate_str FROM public.app_settings WHERE store_id = p_store_id AND key = 'loyalty_redeem_rate' LIMIT 1;
    v_redeem_rate := COALESCE(v_redeem_rate_str::numeric, 1000);
    IF v_redeem_rate <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_POINTS', 'message', 'Tỷ lệ đổi điểm không hợp lệ');
    END IF;
    v_points_discount := p_loyalty_pts_used * v_redeem_rate;
  END IF;

  -- 8. Validate Coupon nếu có (Fail-Closed)
  IF p_coupon_code IS NOT NULL AND trim(p_coupon_code) <> '' THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'coupons') THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'COUPON_SCHEMA_UNAVAILABLE', 'message', 'Hệ thống voucher chưa sẵn sàng');
    END IF;

    EXECUTE '
      SELECT id, is_active, start_date, end_date, discount_type, value, min_order_amount, max_discount_amount
      FROM public.coupons
      WHERE store_id = $1 AND upper(trim(code)) = upper(trim($2))
      LIMIT 1
    ' INTO v_coupon_id, v_coupon_active, v_coupon_start, v_coupon_end, v_coupon_type, v_coupon_val, v_coupon_min_order, v_coupon_max_disc
    USING p_store_id, p_coupon_code;

    IF v_coupon_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'COUPON_NOT_FOUND', 'message', 'Mã giảm giá không tồn tại');
    END IF;

    IF v_coupon_active IS NOT TRUE THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'COUPON_DISABLED', 'message', 'Mã giảm giá hiện đang bị vô hiệu hóa');
    END IF;

    IF v_coupon_start IS NOT NULL AND now() < v_coupon_start THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'COUPON_NOT_STARTED', 'message', 'Mã giảm giá chưa đến thời gian áp dụng');
    END IF;

    IF v_coupon_end IS NOT NULL AND now() > v_coupon_end THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'COUPON_EXPIRED', 'message', 'Mã giảm giá đã hết hạn sử dụng');
    END IF;

    IF v_coupon_min_order IS NOT NULL AND v_subtotal < v_coupon_min_order THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'COUPON_MIN_ORDER_NOT_MET', 'message', 'Đơn hàng chưa đạt giá trị tối thiểu để áp dụng voucher');
    END IF;

    IF v_coupon_type = 'percent' THEN
      v_coupon_discount := (v_subtotal * COALESCE(v_coupon_val, 0)) / 100.0;
      IF v_coupon_max_disc IS NOT NULL AND v_coupon_max_disc > 0 THEN
        v_coupon_discount := LEAST(v_coupon_discount, v_coupon_max_disc);
      END IF;
    ELSIF v_coupon_type = 'fixed' THEN
      v_coupon_discount := LEAST(v_subtotal, COALESCE(v_coupon_val, 0));
    ELSE
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_COUPON_TYPE', 'message', 'Loại giảm giá không được hỗ trợ');
    END IF;
  END IF;

  IF COALESCE(trim(p_coupon_code), '') = '' AND COALESCE(p_discount, 0) > 0 THEN
    SELECT to_jsonb(sm)->'actions' INTO v_staff_actions FROM public.staff_members sm
    WHERE sm.id = v_staff.store_member_id AND sm.store_id = p_store_id AND sm.is_active;
    IF v_staff_actions IS NULL THEN
      SELECT value::jsonb INTO v_staff_actions FROM public.app_settings
      WHERE store_id = p_store_id AND key = 'action_perms_' || v_staff.member_role LIMIT 1;
    END IF;
    IF NOT v_staff.is_owner_member AND NOT COALESCE(v_staff_actions ? 'pos.apply_discount', false) THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'DISCOUNT_PERMISSION_DENIED', 'message', 'Không có quyền giảm giá thủ công');
    END IF;
    IF p_discount > v_subtotal THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'FINANCIAL_QUOTE_CHANGED', 'message', 'Giảm giá vượt giá trị đơn hàng');
    END IF;
    v_manual_discount := p_discount;
  END IF;
  v_authoritative_discount := LEAST(v_subtotal, v_coupon_discount + v_manual_discount + v_points_discount);
  v_total_amount := GREATEST(0, v_subtotal - v_authoritative_discount);

  -- 9. Đối Chiếu Expected Quote Từ Client
  IF (p_discount IS NOT NULL AND p_discount <> v_coupon_discount + v_manual_discount)
     OR (p_expected_total IS NOT NULL AND p_expected_total <> v_total_amount) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'FINANCIAL_QUOTE_CHANGED',
      'message', 'Số tiền chiết khấu đã thay đổi. Vui lòng xác nhận lại đơn hàng.',
      'data', jsonb_build_object(
        'authoritative_subtotal', v_subtotal,
        'authoritative_discount', v_authoritative_discount,
        'authoritative_total', v_total_amount
      )
    );
  END IF;

  -- 10. Tính điểm loyalty tích lũy
  IF p_payment_method = 'wallet' THEN
    v_wallet_real := GREATEST(0, COALESCE((to_jsonb(v_customer)->>'real_balance')::numeric, 0));
    v_wallet_bonus := GREATEST(0, COALESCE((to_jsonb(v_customer)->>'bonus_balance')::numeric, 0));
    v_wallet_cap := COALESCE((to_jsonb(v_customer)->>'bonus_cap_pct')::numeric, 15);
    IF v_wallet_cap < 0 OR v_wallet_cap > 100 THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_WALLET_CONFIG', 'message', 'Giới hạn bonus ví không hợp lệ');
    END IF;
    IF (to_jsonb(v_customer)->>'bonus_expires_at')::timestamptz IS NULL
       OR (to_jsonb(v_customer)->>'bonus_expires_at')::timestamptz > now() THEN
      v_wallet_bonus_used := LEAST(v_wallet_bonus, FLOOR(v_total_amount * v_wallet_cap / 100));
    END IF;
    v_wallet_real_used := v_total_amount - v_wallet_bonus_used;
    IF v_wallet_real_used > v_wallet_real THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INSUFFICIENT_WALLET', 'message', 'Số dư ví không đủ; chưa ghi nhận thanh toán');
    END IF;
  END IF;
  SELECT value INTO v_loyalty_rate_str FROM public.app_settings WHERE store_id = p_store_id AND key = 'loyalty_rate' LIMIT 1;
  v_loyalty_rate := COALESCE(v_loyalty_rate_str::numeric, 10000);
  IF v_loyalty_rate <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_LOYALTY_CONFIG', 'message', 'Tỷ lệ tích điểm không hợp lệ');
  END IF;
  IF p_customer_id IS NOT NULL THEN
    v_pts_earned := FLOOR(v_total_amount / v_loyalty_rate);
  END IF;

  -- 11. Sinh số order nguyên tử
  v_order_id := gen_random_uuid();
  v_pos_op_id := gen_random_uuid();
  v_order_number := public.generate_daily_order_number_v1(p_store_id, 'QN');
  v_fund_type := CASE WHEN p_payment_method = 'wallet' THEN 'wallet'
    WHEN p_payment_method IN ('transfer', 'card', 'bank') THEN 'bank' ELSE 'cash' END;

  -- 12. Ghi Order & POS Idempotency Operation
  INSERT INTO public.staff_members (id, store_id, name, role, phone, is_active, updated_at)
  SELECT v_staff.store_member_id, p_store_id, COALESCE(u.display_name, 'Nhân viên'),
    v_staff.member_role, u.phone, true, extract(epoch from now()) * 1000
  FROM public.user_accounts u WHERE u.id = v_staff.member_user_id
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.orders (
    id, store_id, order_number, subtotal, discount, tax, total, total_amount,
    payment_method, status, source_type, source_id, staff_id, customer_id,
    loyalty_pts_earned, loyalty_pts_used, receipt_printed, created_at,
    note
  ) VALUES (
    v_order_id, p_store_id, v_order_number, v_subtotal, v_authoritative_discount, 0, v_total_amount, v_total_amount,
    p_payment_method, 'completed', v_clean_source_type, p_source_id, v_staff.store_member_id, p_customer_id,
    v_pts_earned, COALESCE(p_loyalty_pts_used, 0), false, now(),
    p_note
  );

  INSERT INTO public.pos_idempotency_operations (
    id, store_id, idempotency_key, cart_fingerprint, order_id, order_number, total_amount, payment_method, status, created_at, wallet_real_used, wallet_bonus_used
  ) VALUES (
    v_pos_op_id, p_store_id, p_idempotency_key, v_cart_fingerprint, v_order_id, v_order_number, v_total_amount, p_payment_method, 'completed', now(), v_wallet_real_used, v_wallet_bonus_used
  );

  INSERT INTO public.ban_session_orders (id, store_id, session_id, order_id, created_at)
  SELECT gen_random_uuid(), p_store_id, sid, v_order_id, now()
  FROM (SELECT DISTINCT unnest(COALESCE(p_kitchen_session_ids, '{}')) sid) batches;

  UPDATE public.ban_sessions SET status = 'closed', closed_at = now()
  WHERE store_id = p_store_id AND id = ANY(COALESCE(p_kitchen_session_ids, '{}'));

  IF v_manual_discount > 0 THEN
    INSERT INTO public.qr_audit_logs (id, store_id, action, actor_user_id, details, created_at)
    VALUES (gen_random_uuid(), p_store_id, 'pos_manual_discount', v_staff.member_user_id,
      jsonb_build_object('order_id', v_order_id, 'amount', v_manual_discount, 'idempotency_key', p_idempotency_key), now());
  END IF;

  IF p_payment_method = 'wallet' THEN
    UPDATE public.customers
    SET real_balance = v_wallet_real - v_wallet_real_used,
        bonus_balance = v_wallet_bonus - v_wallet_bonus_used, updated_at = now()
    WHERE id = p_customer_id AND store_id = p_store_id;
    INSERT INTO public.balance_transactions
      (id, store_id, customer_id, order_id, type, amount, balance_after, bonus_after, note, created_at)
    SELECT gen_random_uuid(), p_store_id, p_customer_id, v_order_id, debit.kind, debit.amount,
      v_wallet_real - v_wallet_real_used, v_wallet_bonus - v_wallet_bonus_used,
      'Thanh toán POS #' || v_order_number, now()
    FROM (VALUES ('spend_real', v_wallet_real_used), ('spend_bonus', v_wallet_bonus_used)) AS debit(kind, amount)
    WHERE debit.amount > 0;
  END IF;

  -- 13. Ghi POS Coupon Redemption nếu có
  IF v_coupon_discount > 0 AND p_coupon_code IS NOT NULL THEN
    INSERT INTO public.pos_coupon_redemptions (
      id, store_id, order_id, pos_operation_id, coupon_id, coupon_code, discount_amount, customer_id, created_at
    ) VALUES (
      gen_random_uuid(), p_store_id, v_order_id, v_pos_op_id, v_coupon_id, p_coupon_code, v_coupon_discount, p_customer_id, now()
    );
  END IF;

  -- 14. Ghi Order Items & Trừ kho (Tích hợp quy đổi đa đơn vị F&B)
  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines)
  LOOP
    SELECT * INTO v_prod FROM public.products WHERE id = (v_line->>'product_id')::uuid AND store_id = p_store_id;
    v_qty := (v_line->>'quantity')::numeric;
    v_unit_price := COALESCE(v_prod.sell_price, 0);
    v_line_subtotal := v_qty * v_unit_price;
    v_order_item_id := gen_random_uuid();

    INSERT INTO public.order_items (
      id, store_id, order_id, product_id, name, product_name, qty, quantity,
      unit_price, cost_price, subtotal
    ) VALUES (
      v_order_item_id, p_store_id, v_order_id, v_prod.id, v_prod.name, v_prod.name,
      v_qty, v_qty, v_unit_price, COALESCE(v_prod.cost_price_latest, 0), v_line_subtotal
    );

    v_has_recipe := false;
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'recipes'
    ) AND EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'recipe_ingredients'
    ) THEN
      EXECUTE '
        SELECT EXISTS (
          SELECT 1 FROM public.recipes r
          JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
          WHERE r.pos_product_id::text = $1::text AND r.is_deleted = false
        )
      ' INTO v_has_recipe USING v_prod.id;
    END IF;

    IF v_has_recipe THEN
      FOR v_rec_ing IN EXECUTE '
        SELECT ri.ingredient_id, ri.quantity, ri.yield_factor, ri.unit AS recipe_unit,
               p.unit AS prod_unit, COALESCE(p.conversion_rate, 0) AS conversion_rate,
               COALESCE(p.conversion_unit, '''') AS conversion_unit, p.name AS prod_name
        FROM public.recipes r
        JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
        LEFT JOIN public.products p ON p.id::text = ri.ingredient_id::text AND p.store_id = $2
        WHERE r.pos_product_id::text = $1::text
          AND r.is_deleted = false
          AND ri.ingredient_id IS NOT NULL
      ' USING v_prod.id, p_store_id
      LOOP
        -- Quy đổi số lượng nguyên liệu chuẩn F&B theo đơn vị kho và hệ số hao hụt
        v_actual_ing_qty := public.convert_recipe_ingredient_qty_v1(
          (v_rec_ing.quantity / CASE WHEN v_rec_ing.yield_factor IS NULL OR v_rec_ing.yield_factor <= 0 THEN 1.0 ELSE v_rec_ing.yield_factor END) * v_qty,
          v_rec_ing.recipe_unit,
          v_rec_ing.prod_unit,
          v_rec_ing.conversion_rate,
          v_rec_ing.conversion_unit
        );

        INSERT INTO public.stock_movements (
          id, store_id, product_id, delta, reason, reference_id, note, created_at
        ) VALUES (
          gen_random_uuid(), p_store_id, v_rec_ing.ingredient_id::uuid,
          -v_actual_ing_qty, 'recipe_usage', v_order_id,
          'POS công thức #' || v_order_number || ': ' || v_prod.name, now()
        );

        UPDATE public.products
        SET stock_qty = COALESCE(stock_qty, 0) - v_actual_ing_qty,
            updated_at = extract(epoch from now()) * 1000
        WHERE id = v_rec_ing.ingredient_id::uuid AND store_id = p_store_id;
      END LOOP;
    ELSE
      INSERT INTO public.stock_movements (
        id, store_id, product_id, delta, reason, reference_id, note, created_at
      ) VALUES (
        gen_random_uuid(), p_store_id, v_prod.id, -v_qty, 'sale', v_order_id,
        'POS bán hàng #' || v_order_number, now()
      );
      UPDATE public.products
      SET stock_qty = COALESCE(stock_qty, 0) - v_qty,
          updated_at = extract(epoch from now()) * 1000
      WHERE id = v_prod.id AND store_id = p_store_id;
    END IF;
  END LOOP;

  -- 15. Ghi ĐÚNG 1 bản ghi finance_records
  INSERT INTO public.finance_records (
    id, store_id, type, amount, description, reference_id, is_auto, recorded_at, fund_type
  ) VALUES (
    gen_random_uuid(), p_store_id, 'income', v_total_amount,
    'Bán hàng #' || v_order_number, v_order_id, true, now(), v_fund_type
  );

  -- 16. Cập nhật Loyalty & Transactions
  IF p_customer_id IS NOT NULL THEN
    UPDATE public.customers
    SET loyalty_pts = GREATEST(0, COALESCE(loyalty_pts, 0) + v_pts_earned - COALESCE(p_loyalty_pts_used, 0)),
        total_spent = COALESCE(total_spent, 0) + v_total_amount,
        visit_count = COALESCE(visit_count, 0) + 1,
        updated_at = now()
    WHERE id = p_customer_id AND store_id = p_store_id;

    IF v_pts_earned > 0 OR COALESCE(p_loyalty_pts_used, 0) > 0 THEN
      INSERT INTO public.loyalty_transactions (
        id, store_id, customer_id, order_id, pts_earned, pts_used, note, created_at
      ) VALUES (
        gen_random_uuid(), p_store_id, p_customer_id, v_order_id,
        v_pts_earned, COALESCE(p_loyalty_pts_used, 0), 'Bán hàng #' || v_order_number, now()
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'order_id', v_order_id,
      'order_number', v_order_number,
      'subtotal', v_subtotal,
      'discount', v_authoritative_discount,
      'total_amount', v_total_amount,
      'wallet_real_used', v_wallet_real_used,
      'wallet_bonus_used', v_wallet_bonus_used,
      'payment_method', p_payment_method,
      'is_replay', false
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_pos_sale_v1(uuid, text, jsonb, text, uuid, numeric, numeric, text, text, text, text, numeric, uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_pos_sale_v1(uuid, text, jsonb, text, uuid, numeric, numeric, text, text, text, text, numeric, uuid[]) TO anon, authenticated, service_role;


-- ── 4. CẬP NHẬT FUNCTION: settle_ban_session_v5 ───────────────────────────────
CREATE OR REPLACE FUNCTION public.settle_ban_session_v5(
  p_session_id uuid,
  p_store_id uuid,
  p_payment_method text DEFAULT 'cash',
  p_idempotency_key text DEFAULT NULL,
  p_customer_id uuid DEFAULT NULL,
  p_points_used integer DEFAULT 0,
  p_discount numeric DEFAULT 0,
  p_coupon_code text DEFAULT NULL,
  p_surcharge numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $$
DECLARE
  v_staff record;
  v_session record;
  v_table record;
  v_settlement_id uuid;
  v_existing_settle record;
  v_request_fingerprint text;
  v_raw_subtotal numeric := 0;
  v_actual_points_used integer := 0;
  v_points_discount numeric := 0;
  v_redeem_rate_str text;
  v_redeem_rate numeric := 1000;
  v_coupon_id uuid;
  v_coupon_active boolean;
  v_coupon_start timestamptz;
  v_coupon_end timestamptz;
  v_coupon_type text;
  v_coupon_val numeric;
  v_coupon_min_order numeric;
  v_coupon_max_disc numeric;
  v_coupon_discount numeric := 0;
  v_discount numeric := 0;
  v_surcharge numeric := 0;
  v_final_total numeric := 0;
  v_fund_type text;
  v_order record;
  v_item record;
  v_prod record;
  v_mod jsonb;
  v_manual_order_id uuid;
  v_manual_order_num text;
  v_manual_subtotal numeric := 0;
  v_manual_item_row record;
  v_order_item_id uuid;
  v_rec_ing record;
  v_actual_ing_qty numeric;
  v_has_recipe boolean;
  v_staff_member_id uuid;
  v_user_name text;
  v_user_phone text;
  v_canonical_order_ids jsonb;
  v_order_numbers jsonb;
  v_loyalty_rate_str text;
  v_loyalty_rate numeric := 10000;
  v_pts_earned numeric := 0;
  v_customer record;
  v_current_pts numeric := 0;
  v_current_spent numeric := 0;
  v_current_visit integer := 0;
  v_current_stamps integer := 0;
  v_stamp_threshold_str text;
  v_stamp_threshold integer := 10;
  v_next_stamps integer;
  v_new_stamp_count integer;
  v_remaining_subtotal numeric;
  v_remaining_discount numeric;
  v_remaining_surcharge numeric;
  v_remaining_earned numeric;
  v_remaining_used numeric;
  v_order_waiter_id text;
  v_order_staff_id uuid;
  v_order_subtotal numeric;
  v_order_discount numeric;
  v_order_surcharge numeric;
  v_order_earned numeric;
  v_order_used numeric;
BEGIN
  -- 1. Xác thực quyền pos.checkout (100% Fail-Closed)
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);

  -- 2. Validate payload cơ bản & Whitelist Payment Method
  IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_PAYLOAD',
      'message', 'Idempotency key là bắt buộc khi quyết toán bàn'
    );
  END IF;

  p_payment_method := lower(trim(COALESCE(p_payment_method, 'cash')));
  IF p_payment_method NOT IN ('cash', 'transfer', 'card', 'bank') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_PAYMENT_METHOD',
      'message', 'Phương thức thanh toán không hợp lệ (' || p_payment_method || ')'
    );
  END IF;

  -- 3. Khóa Transaction-Scoped Advisory Lock trên Idempotency Key
  PERFORM pg_advisory_xact_lock(hashtext(p_store_id::text), hashtext('settle_ban_session:' || p_idempotency_key));

  -- 4. Khóa phiên bàn FOR UPDATE
  SELECT * INTO v_session
  FROM public.ban_sessions
  WHERE id = p_session_id AND store_id = p_store_id
  FOR UPDATE;

  IF v_session IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy phiên bàn');
  END IF;

  SELECT * INTO v_table
  FROM public.ban_dining_tables
  WHERE id = v_session.table_id::text AND store_id = p_store_id;

  -- 5. Băm Financial Intent Fingerprint SHA-256
  v_request_fingerprint := encode(digest(
    p_store_id::text || ':' ||
    p_session_id::text || ':' ||
    p_payment_method || ':' ||
    COALESCE(p_customer_id::text, '') || ':' ||
    COALESCE(p_points_used, 0)::text || ':' ||
    lower(trim(COALESCE(p_coupon_code, ''))) || ':' ||
    round(COALESCE(p_surcharge, 0), 0)::text || ':' ||
    round(COALESCE(p_discount, 0), 0)::text,
    'sha256'
  ), 'hex');

  -- 6. Lookup Idempotency Key (Ưu tiên trả Replay trước)
  SELECT * INTO v_existing_settle
  FROM public.payment_settlements
  WHERE store_id = p_store_id AND idempotency_key = p_idempotency_key
  LIMIT 1;

  IF v_existing_settle.id IS NOT NULL THEN
    IF v_existing_settle.session_id = p_session_id AND v_existing_settle.request_fingerprint = v_request_fingerprint THEN
      SELECT COALESCE(jsonb_agg(order_id), '[]'::jsonb) INTO v_canonical_order_ids
      FROM public.ban_session_orders
      WHERE session_id = p_session_id;

      SELECT COALESCE(jsonb_agg(o.order_number), '[]'::jsonb) INTO v_order_numbers
      FROM public.orders o
      JOIN public.ban_session_orders bso ON bso.order_id = o.id
      WHERE bso.session_id = p_session_id;

      RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
          'session_id', p_session_id,
          'settlement_id', v_existing_settle.id,
          'canonical_order_ids', v_canonical_order_ids,
          'order_numbers', v_order_numbers,
          'subtotal', v_existing_settle.subtotal,
          'discount', v_existing_settle.discount,
          'points_discount', v_existing_settle.points_discount,
          'coupon_discount', v_existing_settle.coupon_discount,
          'surcharge', v_existing_settle.surcharge,
          'total_amount', v_existing_settle.total_amount,
          'payment_method', v_existing_settle.payment_method,
          'customer_id', v_existing_settle.customer_id,
          'is_replay', true
        )
      );
    ELSE
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'IDEMPOTENCY_CONFLICT',
        'message', 'Idempotency key đã được sử dụng với nội dung thanh toán khác'
      );
    END IF;
  END IF;

  -- 7. Lookup Session Settlement (Phiên đã quyết toán trước đó)
  SELECT * INTO v_existing_settle
  FROM public.payment_settlements
  WHERE session_id = p_session_id
  LIMIT 1;

  IF v_existing_settle.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'SESSION_ALREADY_SETTLED',
      'message', 'Phiên bàn này đã được quyết toán trước đó'
    );
  END IF;

  -- 8. Kiểm tra trạng thái Session phải là 'open'
  IF v_session.status <> 'open' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'SESSION_NOT_OPEN',
      'message', 'Phiên bàn không ở trạng thái mở để thanh toán'
    );
  END IF;

  -- 9. Đọc Subtotal Authoritative từ ban_session_items
  SELECT COALESCE(SUM(subtotal), 0) INTO v_raw_subtotal
  FROM public.ban_session_items
  WHERE session_id = p_session_id AND store_id = p_store_id
    AND COALESCE(kitchen_status, '') <> 'huy';

  IF v_raw_subtotal <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_SESSION_ITEMS',
      'message', 'Phiên bàn không có món ăn để thanh toán'
    );
  END IF;

  -- 10. Xác thực Khách Hàng & Điểm Tích Lũy
  IF p_points_used IS NOT NULL AND p_points_used < 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_POINTS',
      'message', 'Số điểm sử dụng không hợp lệ (không thể là số âm)'
    );
  END IF;

  IF p_points_used IS NOT NULL AND p_points_used > 0 AND p_customer_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'CUSTOMER_REQUIRED',
      'message', 'Vui lòng chọn thông tin khách hàng để sử dụng điểm'
    );
  END IF;

  v_actual_points_used := 0;
  v_points_discount := 0;

  IF p_customer_id IS NOT NULL THEN
    SELECT * INTO v_customer
    FROM public.customers
    WHERE id = p_customer_id AND store_id = p_store_id AND is_deleted = false
    FOR UPDATE;

    IF v_customer IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'CUSTOMER_NOT_FOUND',
        'message', 'Khách hàng không tồn tại hoặc không thuộc cửa hàng này'
      );
    END IF;

    IF p_points_used IS NOT NULL AND p_points_used > 0 THEN
      IF p_points_used > COALESCE(v_customer.loyalty_pts, 0) THEN
        RETURN jsonb_build_object(
          'success', false,
          'error_code', 'INSUFFICIENT_POINTS',
          'message', 'Số điểm yêu cầu (' || p_points_used || ') vượt quá số dư điểm của khách (' || COALESCE(v_customer.loyalty_pts, 0) || ')'
        );
      END IF;

      SELECT value INTO v_redeem_rate_str
      FROM public.app_settings
      WHERE store_id = p_store_id AND key = 'loyalty_redeem_rate'
      LIMIT 1;

      IF v_redeem_rate_str IS NULL OR trim(v_redeem_rate_str) = '' THEN
        RETURN jsonb_build_object(
          'success', false,
          'error_code', 'INVALID_LOYALTY_CONFIG',
          'message', 'Chưa cấu hình tỷ lệ quy đổi điểm loyalty_redeem_rate trong app_settings'
        );
      END IF;

      BEGIN
        v_redeem_rate := v_redeem_rate_str::numeric;
      EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object(
          'success', false,
          'error_code', 'INVALID_LOYALTY_CONFIG',
          'message', 'Cấu hình loyalty_redeem_rate không phải là số hợp lệ'
        );
      END;

      IF v_redeem_rate <= 0 THEN
        RETURN jsonb_build_object(
          'success', false,
          'error_code', 'INVALID_LOYALTY_CONFIG',
          'message', 'Tỷ lệ quy đổi điểm loyalty_redeem_rate phải lớn hơn 0'
        );
      END IF;

      v_actual_points_used := p_points_used;
      v_points_discount := v_actual_points_used * v_redeem_rate;
    END IF;
  END IF;

  -- 11. Xác thực Mã Giảm Giá / Coupon
  v_coupon_discount := 0;
  IF p_coupon_code IS NOT NULL AND trim(p_coupon_code) <> '' THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'coupons'
    ) THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_SCHEMA_UNAVAILABLE',
        'message', 'Hệ thống voucher/coupon chưa được khởi tạo'
      );
    END IF;

    EXECUTE '
      SELECT id, is_active, start_date, end_date, discount_type, value, min_order_amount, max_discount_amount
      FROM public.coupons
      WHERE store_id = $1 AND upper(trim(code)) = upper(trim($2))
      LIMIT 1
    ' INTO v_coupon_id, v_coupon_active, v_coupon_start, v_coupon_end, v_coupon_type, v_coupon_val, v_coupon_min_order, v_coupon_max_disc
    USING p_store_id, p_coupon_code;

    IF v_coupon_id IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_NOT_FOUND',
        'message', 'Mã giảm giá không tồn tại'
      );
    END IF;

    IF v_coupon_active IS NOT TRUE THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_DISABLED',
        'message', 'Mã giảm giá hiện đang bị vô hiệu hóa'
      );
    END IF;

    IF v_coupon_start IS NOT NULL AND now() < v_coupon_start THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_NOT_STARTED',
        'message', 'Mã giảm giá chưa đến thời gian áp dụng'
      );
    END IF;

    IF v_coupon_end IS NOT NULL AND now() > v_coupon_end THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_EXPIRED',
        'message', 'Mã giảm giá đã hết hạn sử dụng'
      );
    END IF;

    IF v_coupon_min_order IS NOT NULL AND v_raw_subtotal < v_coupon_min_order THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_MIN_ORDER_NOT_MET',
        'message', 'Đơn hàng chưa đạt giá trị tối thiểu ' || v_coupon_min_order::text || 'đ để áp dụng voucher'
      );
    END IF;

    IF v_coupon_type = 'percent' THEN
      v_coupon_discount := (v_raw_subtotal * COALESCE(v_coupon_val, 0)) / 100.0;
      IF v_coupon_max_disc IS NOT NULL AND v_coupon_max_disc > 0 THEN
        v_coupon_discount := LEAST(v_coupon_discount, v_coupon_max_disc);
      END IF;
    ELSIF v_coupon_type = 'fixed' THEN
      v_coupon_discount := LEAST(v_raw_subtotal, COALESCE(v_coupon_val, 0));
    ELSE
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'INVALID_COUPON_TYPE',
        'message', 'Loại giảm giá không được hỗ trợ'
      );
    END IF;
  END IF;

  -- 12. Validate Phụ Phí
  IF p_surcharge IS NOT NULL THEN
    IF p_surcharge < 0 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'INVALID_SURCHARGE',
        'message', 'Phụ phí không thể là số âm'
      );
    END IF;
    v_surcharge := p_surcharge;
  ELSE
    v_surcharge := 0;
  END IF;

  -- 13. Tính Tổng Giảm Giá & Tổng Thanh Toán Authoritative
  v_discount := LEAST(v_raw_subtotal, v_coupon_discount + v_points_discount);
  v_final_total := GREATEST(0, (v_raw_subtotal - v_discount + v_surcharge));

  -- 14. Đối Chiếu Expected Quote Từ Client
  IF p_discount IS NOT NULL AND round(p_discount, 0) <> round(v_discount, 0) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'FINANCIAL_QUOTE_CHANGED',
      'message', 'Số tiền giảm giá trên hóa đơn đã thay đổi. Vui lòng xác nhận lại số tiền trước khi thanh toán.',
      'data', jsonb_build_object(
        'authoritative_subtotal', v_raw_subtotal,
        'authoritative_discount', v_discount,
        'authoritative_points_discount', v_points_discount,
        'authoritative_coupon_discount', v_coupon_discount,
        'authoritative_surcharge', v_surcharge,
        'authoritative_total', v_final_total
      )
    );
  END IF;

  -- 15. COMMIT ATOMIC TRONG 1 TRANSACTION DUY NHẤT
  -- 15.1. Staff Upsert
  v_staff_member_id := v_staff.store_member_id;
  SELECT display_name, phone INTO v_user_name, v_user_phone
  FROM public.user_accounts WHERE id = v_staff.member_user_id;

  INSERT INTO public.staff_members (
    id, store_id, name, role, phone, is_active, updated_at
  ) VALUES (
    v_staff_member_id, p_store_id, COALESCE(v_user_name, 'Staff'), COALESCE(v_staff.member_role, 'cashier'),
    v_user_phone, true, extract(epoch from now()) * 1000
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    role = EXCLUDED.role,
    is_active = true,
    updated_at = EXCLUDED.updated_at;

  -- 15.2. Gom món manual thành canonical order với số QN-YYYYMMDD-XXX nguyên tử
  SELECT COALESCE(SUM(subtotal), 0) INTO v_manual_subtotal
  FROM public.ban_session_items bsi
  WHERE bsi.session_id = p_session_id
    AND bsi.store_id = p_store_id AND COALESCE(bsi.kitchen_status, '') <> 'huy'
    AND NOT EXISTS (
      SELECT 1 FROM public.ban_session_order_items bsoi
      WHERE bsoi.session_item_id = bsi.id
    );

  IF v_manual_subtotal > 0 THEN
    v_manual_order_id := gen_random_uuid();
    v_manual_order_num := public.generate_daily_order_number_v1(p_store_id, 'QN');

    v_order_waiter_id := NULL;
    IF v_session.waiter_id IS NOT NULL THEN
      SELECT id::text INTO v_order_waiter_id FROM public.staff_members WHERE id::text = v_session.waiter_id;
      IF v_order_waiter_id IS NULL THEN
        v_order_waiter_id := v_session.waiter_id;
      END IF;
    END IF;

    v_order_staff_id := NULL;
    IF v_staff_member_id IS NOT NULL THEN
      SELECT id INTO v_order_staff_id FROM public.staff_members WHERE id = v_staff_member_id;
    END IF;

    INSERT INTO public.orders (
      id, store_id, order_number, subtotal, discount, tax, total, total_amount,
      payment_method, status, source_type, source_id, staff_id, waiter_id, receipt_printed, created_at, note
    ) VALUES (
      v_manual_order_id, p_store_id, v_manual_order_num, v_manual_subtotal, 0, 0, v_manual_subtotal, v_manual_subtotal,
      p_payment_method, 'completed', 'ban', v_session.table_id::text, v_order_staff_id, v_order_waiter_id, false, now(),
      'Món thanh toán tại bàn ' || COALESCE(v_table.name, v_table.label, 'bàn')
    );

    INSERT INTO public.ban_session_orders (
      id, store_id, session_id, order_id, qr_request_id, created_at
    ) VALUES (
      gen_random_uuid(), p_store_id, p_session_id, v_manual_order_id, NULL, now()
    );

    FOR v_manual_item_row IN (
      SELECT bsi.* FROM public.ban_session_items bsi
      WHERE bsi.session_id = p_session_id
        AND bsi.store_id = p_store_id AND COALESCE(bsi.kitchen_status, '') <> 'huy'
        AND NOT EXISTS (
          SELECT 1 FROM public.ban_session_order_items bsoi
          WHERE bsoi.session_item_id = bsi.id
        )
    )
    LOOP
      SELECT cost_price_latest INTO v_prod FROM public.products WHERE id = v_manual_item_row.product_id;
      v_order_item_id := gen_random_uuid();

      INSERT INTO public.order_items (
        id, store_id, order_id, product_id, name, product_name, qty, quantity,
        unit_price, cost_price, subtotal, modifiers_json
      ) VALUES (
        v_order_item_id, p_store_id, v_manual_order_id, v_manual_item_row.product_id,
        v_manual_item_row.product_name, v_manual_item_row.product_name,
        v_manual_item_row.quantity, v_manual_item_row.quantity,
        v_manual_item_row.unit_price, COALESCE(v_prod.cost_price_latest, 0),
        v_manual_item_row.subtotal,
        CASE WHEN v_manual_item_row.modifiers_json IS NOT NULL AND trim(v_manual_item_row.modifiers_json) <> ''
             THEN v_manual_item_row.modifiers_json::jsonb ELSE '[]'::jsonb END
      );

      INSERT INTO public.ban_session_order_items (
        id, store_id, session_id, session_item_id, order_id, order_item_id, source_type, created_at
      ) VALUES (
        gen_random_uuid(), p_store_id, p_session_id, v_manual_item_row.id, v_manual_order_id, v_order_item_id, 'ban_manual', now()
      );
    END LOOP;
  END IF;

  -- 15.3. Tính điểm tích lũy
  SELECT value INTO v_loyalty_rate_str
  FROM public.app_settings
  WHERE store_id = p_store_id AND key = 'loyalty_rate'
  LIMIT 1;

  IF v_loyalty_rate_str IS NOT NULL AND trim(v_loyalty_rate_str) <> '' THEN
    BEGIN
      v_loyalty_rate := COALESCE(v_loyalty_rate_str::numeric, 10000);
      IF v_loyalty_rate <= 0 THEN v_loyalty_rate := 10000; END IF;
    EXCEPTION WHEN OTHERS THEN
      v_loyalty_rate := 10000;
    END;
  END IF;

  IF p_customer_id IS NOT NULL THEN
    v_pts_earned := FLOOR(v_final_total / v_loyalty_rate);
  END IF;

  v_settlement_id := gen_random_uuid();
  v_fund_type := CASE WHEN p_payment_method IN ('transfer', 'card', 'bank') THEN 'bank' ELSE 'cash' END;

  -- 15.4. Ghi Payment Settlement
  INSERT INTO public.payment_settlements (
    id, store_id, session_id, idempotency_key, request_fingerprint, subtotal, discount,
    points_discount, coupon_discount, surcharge, total_amount, payment_method, customer_id,
    points_used, coupon_code, cashier_staff_id, status, created_at
  ) VALUES (
    v_settlement_id, p_store_id, p_session_id, p_idempotency_key, v_request_fingerprint, v_raw_subtotal, v_discount,
    v_points_discount, v_coupon_discount, v_surcharge, v_final_total, p_payment_method, p_customer_id,
    v_actual_points_used, p_coupon_code, v_staff_member_id, 'completed', now()
  );

  -- 15.5. Ghi Coupon Redemption nếu có
  IF v_coupon_discount > 0 AND p_coupon_code IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'qr_coupon_redemptions') THEN
      INSERT INTO public.qr_coupon_redemptions (
        id, store_id, session_id, settlement_id, coupon_id, coupon_code, discount_amount, created_at
      ) VALUES (
        gen_random_uuid(), p_store_id, p_session_id, v_settlement_id, v_coupon_id, p_coupon_code, v_coupon_discount, now()
      );
    END IF;
  END IF;

  -- 15.6. Chuyển toàn bộ Canonical Orders sang Completed & Trừ kho (Đa đơn vị F&B)
  UPDATE public.order_items oi
  SET qty = CASE WHEN COALESCE(bsi.kitchen_status, '') = 'huy' THEN 0 ELSE bsi.quantity END,
      quantity = CASE WHEN COALESCE(bsi.kitchen_status, '') = 'huy' THEN 0 ELSE bsi.quantity END,
      unit_price = bsi.unit_price,
      subtotal = CASE WHEN COALESCE(bsi.kitchen_status, '') = 'huy' THEN 0 ELSE bsi.subtotal END
  FROM public.ban_session_order_items link JOIN public.ban_session_items bsi ON bsi.id = link.session_item_id
  WHERE oi.id = link.order_item_id AND oi.store_id = p_store_id
    AND link.session_id = p_session_id AND link.store_id = p_store_id AND bsi.store_id = p_store_id;

  v_remaining_subtotal := v_raw_subtotal;
  v_remaining_discount := v_discount;
  v_remaining_surcharge := v_surcharge;
  v_remaining_earned := v_pts_earned;
  v_remaining_used := v_actual_points_used;

  FOR v_order IN (
    SELECT o.* FROM public.orders o
    JOIN public.ban_session_orders bso ON bso.order_id = o.id
    WHERE bso.session_id = p_session_id
      AND bso.store_id = p_store_id AND o.store_id = p_store_id ORDER BY o.id
  )
  LOOP
    SELECT COALESCE(sum(subtotal), 0) INTO v_order_subtotal FROM public.order_items
    WHERE order_id = v_order.id AND store_id = p_store_id;
    IF v_order_subtotal = v_remaining_subtotal THEN
      v_order_discount := v_remaining_discount; v_order_surcharge := v_remaining_surcharge;
      v_order_earned := v_remaining_earned; v_order_used := v_remaining_used;
    ELSE
      v_order_discount := round(v_remaining_discount * v_order_subtotal / NULLIF(v_remaining_subtotal, 0));
      v_order_surcharge := round(v_remaining_surcharge * v_order_subtotal / NULLIF(v_remaining_subtotal, 0));
      v_order_earned := floor(v_remaining_earned * v_order_subtotal / NULLIF(v_remaining_subtotal, 0));
      v_order_used := floor(v_remaining_used * v_order_subtotal / NULLIF(v_remaining_subtotal, 0));
    END IF;
    v_remaining_subtotal := v_remaining_subtotal - v_order_subtotal;
    v_remaining_discount := v_remaining_discount - v_order_discount;
    v_remaining_surcharge := v_remaining_surcharge - v_order_surcharge;
    v_remaining_earned := v_remaining_earned - v_order_earned;
    v_remaining_used := v_remaining_used - v_order_used;

    UPDATE public.orders
    SET status = 'completed',
        subtotal = v_order_subtotal, discount = v_order_discount, tax = v_order_surcharge,
        total = v_order_subtotal - v_order_discount + v_order_surcharge,
        total_amount = v_order_subtotal - v_order_discount + v_order_surcharge,
        payment_method = p_payment_method,
        customer_id = COALESCE(p_customer_id, customer_id),
        staff_id = COALESCE(
          (SELECT id FROM public.staff_members WHERE id = v_staff_member_id),
          staff_id
        ),
        loyalty_pts_earned = v_order_earned,
        loyalty_pts_used = v_order_used
    WHERE id = v_order.id;

    -- Trừ kho sản phẩm & công thức món chính
    FOR v_item IN
      SELECT oi.id, oi.product_id, bsi.product_name, bsi.quantity,
        CASE
          WHEN oi.modifiers_json IS NULL OR btrim(oi.modifiers_json::text) = ''
            THEN '[]'::jsonb
          ELSE oi.modifiers_json::jsonb
        END AS modifiers_json
      FROM public.order_items oi
      JOIN public.ban_session_order_items link ON link.order_item_id = oi.id
      JOIN public.ban_session_items bsi ON bsi.id = link.session_item_id
      WHERE oi.order_id = v_order.id AND oi.store_id = p_store_id
        AND link.session_id = p_session_id AND link.store_id = p_store_id
        AND bsi.store_id = p_store_id AND COALESCE(bsi.kitchen_status, '') <> 'huy'
    LOOP
      v_has_recipe := false;
      IF EXISTS (
        SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'recipes'
      ) AND EXISTS (
        SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'recipe_ingredients'
      ) THEN
        EXECUTE '
          SELECT EXISTS (
            SELECT 1 FROM public.recipes r
            JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
            WHERE r.pos_product_id::text = $1::text AND r.is_deleted = false
          )
        ' INTO v_has_recipe USING v_item.product_id;
      END IF;

      IF v_has_recipe THEN
        FOR v_rec_ing IN EXECUTE '
          SELECT ri.ingredient_id, ri.quantity, ri.yield_factor, ri.unit AS recipe_unit,
                 p.unit AS prod_unit, COALESCE(p.conversion_rate, 0) AS conversion_rate,
                 COALESCE(p.conversion_unit, '''') AS conversion_unit, p.name AS prod_name
          FROM public.recipes r
          JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
          LEFT JOIN public.products p ON p.id::text = ri.ingredient_id::text AND p.store_id = $2
          WHERE r.pos_product_id::text = $1::text AND r.is_deleted = false AND ri.ingredient_id IS NOT NULL
        ' USING v_item.product_id, p_store_id
        LOOP
          -- Quy đổi định lượng nguyên liệu F&B đa đơn vị
          v_actual_ing_qty := public.convert_recipe_ingredient_qty_v1(
            (v_rec_ing.quantity / CASE WHEN v_rec_ing.yield_factor IS NULL OR v_rec_ing.yield_factor <= 0 THEN 1.0 ELSE v_rec_ing.yield_factor END) * v_item.quantity,
            v_rec_ing.recipe_unit,
            v_rec_ing.prod_unit,
            v_rec_ing.conversion_rate,
            v_rec_ing.conversion_unit
          );

          INSERT INTO public.stock_movements (
            id, store_id, product_id, delta, reason, reference_id, note, created_at
          ) VALUES (
            gen_random_uuid(), p_store_id, v_rec_ing.ingredient_id::uuid, -v_actual_ing_qty,
            'recipe_usage', v_settlement_id, 'Xuất kho công thức bàn ' || COALESCE(v_table.label, v_table.name, 'bàn') || ': ' || v_item.product_name, now()
          );

          UPDATE public.products
          SET stock_qty = COALESCE(stock_qty, 0) - v_actual_ing_qty,
              updated_at = extract(epoch from now()) * 1000
          WHERE id = v_rec_ing.ingredient_id::uuid AND store_id = p_store_id;
        END LOOP;
      ELSE
        INSERT INTO public.stock_movements (
          id, store_id, product_id, delta, reason, reference_id, note, created_at
        ) VALUES (
          gen_random_uuid(), p_store_id, v_item.product_id, -v_item.quantity,
          'sale', v_settlement_id, 'Bán hàng bàn ' || COALESCE(v_table.label, v_table.name, 'bàn'), now()
        );

        UPDATE public.products
        SET stock_qty = COALESCE(stock_qty, 0) - v_item.quantity,
            updated_at = extract(epoch from now()) * 1000
        WHERE id = v_item.product_id AND store_id = p_store_id;
      END IF;

      -- Trừ kho toppings / modifiers nếu có (Tích hợp quy đổi đa đơn vị F&B)
      IF v_item.modifiers_json IS NOT NULL AND jsonb_typeof(v_item.modifiers_json) = 'array' THEN
        FOR v_mod IN SELECT * FROM jsonb_array_elements(v_item.modifiers_json)
        LOOP
          IF (v_mod->>'id') IS NOT NULL THEN
            v_has_recipe := false;
            IF EXISTS (
              SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'recipes'
            ) AND EXISTS (
              SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'recipe_ingredients'
            ) THEN
              EXECUTE '
                SELECT EXISTS (
                  SELECT 1 FROM public.recipes r
                  JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
                  WHERE r.pos_product_id::text = $1::text AND r.is_deleted = false
                )
              ' INTO v_has_recipe USING (v_mod->>'id')::uuid;
            END IF;

            IF v_has_recipe THEN
              FOR v_rec_ing IN EXECUTE '
                SELECT ri.ingredient_id, ri.quantity, ri.yield_factor, ri.unit AS recipe_unit,
                       p.unit AS prod_unit, COALESCE(p.conversion_rate, 0) AS conversion_rate,
                       COALESCE(p.conversion_unit, '''') AS conversion_unit, p.name AS prod_name
                FROM public.recipes r
                JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
                LEFT JOIN public.products p ON p.id::text = ri.ingredient_id::text AND p.store_id = $2
                WHERE r.pos_product_id::text = $1::text AND r.is_deleted = false AND ri.ingredient_id IS NOT NULL
              ' USING (v_mod->>'id')::uuid, p_store_id
              LOOP
                v_actual_ing_qty := public.convert_recipe_ingredient_qty_v1(
                  (v_rec_ing.quantity / CASE WHEN v_rec_ing.yield_factor IS NULL OR v_rec_ing.yield_factor <= 0 THEN 1.0 ELSE v_rec_ing.yield_factor END) * ((COALESCE((v_mod->>'quantity')::numeric, 1)) * v_item.quantity),
                  v_rec_ing.recipe_unit,
                  v_rec_ing.prod_unit,
                  v_rec_ing.conversion_rate,
                  v_rec_ing.conversion_unit
                );

                INSERT INTO public.stock_movements (
                  id, store_id, product_id, delta, reason, reference_id, note, created_at
                ) VALUES (
                  gen_random_uuid(), p_store_id, v_rec_ing.ingredient_id::uuid, -v_actual_ing_qty,
                  'recipe_usage', v_settlement_id, 'Xuất kho topping công thức bàn ' || COALESCE(v_table.label, v_table.name, 'bàn'), now()
                );

                UPDATE public.products
                SET stock_qty = COALESCE(stock_qty, 0) - v_actual_ing_qty,
                    updated_at = extract(epoch from now()) * 1000
                WHERE id = v_rec_ing.ingredient_id::uuid AND store_id = p_store_id;
              END LOOP;
            ELSE
              INSERT INTO public.stock_movements (
                id, store_id, product_id, delta, reason, reference_id, note, created_at
              ) VALUES (
                gen_random_uuid(), p_store_id, (v_mod->>'id')::uuid,
                -((COALESCE((v_mod->>'quantity')::numeric, 1)) * v_item.quantity),
                'sale', v_settlement_id, 'Bán topping bàn ' || COALESCE(v_table.label, v_table.name, 'bàn'), now()
              );

              UPDATE public.products
              SET stock_qty = COALESCE(stock_qty, 0) - ((COALESCE((v_mod->>'quantity')::numeric, 1)) * v_item.quantity),
                  updated_at = extract(epoch from now()) * 1000
              WHERE id = (v_mod->>'id')::uuid AND store_id = p_store_id;
            END IF;
          END IF;
        END LOOP;
      END IF;
    END LOOP;
  END LOOP;

  -- 15.7. Ghi ĐÚNG 1 bản ghi sổ quỹ finance_records với reference_id = v_settlement_id
  INSERT INTO public.finance_records (
    id, store_id, type, amount, description, reference_id, is_auto, recorded_at, fund_type
  ) VALUES (
    gen_random_uuid(), p_store_id, 'income', v_final_total,
    'Thanh toán bàn ' || COALESCE(v_table.label, v_table.name, 'bàn') || CASE WHEN p_coupon_code IS NOT NULL THEN ' [Voucher: ' || p_coupon_code || ']' ELSE '' END,
    v_settlement_id, true, now(), v_fund_type
  );

  -- 15.8. Tích điểm / Trừ điểm cho Khách hàng & Loyalty Transactions
  IF p_customer_id IS NOT NULL THEN
    v_current_pts := COALESCE(v_customer.loyalty_pts, 0);
    v_current_spent := COALESCE(v_customer.total_spent, 0);
    v_current_visit := COALESCE(v_customer.visit_count, 0);
    v_current_stamps := COALESCE(v_customer.stamp_count, 0);

    SELECT value INTO v_stamp_threshold_str
    FROM public.app_settings
    WHERE store_id = p_store_id AND key = 'stamp_threshold'
    LIMIT 1;

    IF v_stamp_threshold_str IS NOT NULL THEN
      v_stamp_threshold := COALESCE(v_stamp_threshold_str::integer, 10);
    END IF;

    v_next_stamps := v_current_stamps + 1;
    v_new_stamp_count := CASE WHEN v_next_stamps >= v_stamp_threshold THEN 0 ELSE v_next_stamps END;

    UPDATE public.customers
    SET loyalty_pts = GREATEST(0, v_current_pts + v_pts_earned - v_actual_points_used),
        total_spent = v_current_spent + v_final_total,
        visit_count = v_current_visit + 1,
        stamp_count = v_new_stamp_count,
        stamp_total = COALESCE(v_customer.stamp_total, 0) + 1,
        updated_at = now()
    WHERE id = p_customer_id;

    IF v_pts_earned > 0 OR v_actual_points_used > 0 THEN
      INSERT INTO public.loyalty_transactions (
        id, store_id, customer_id, order_id, pts_earned, pts_used, note, created_at
      ) VALUES (
        gen_random_uuid(), p_store_id, p_customer_id, v_settlement_id,
        v_pts_earned, v_actual_points_used,
        'Thanh toán bàn ' || COALESCE(v_table.label, v_table.name, 'bàn'), now()
      );
    END IF;
  END IF;

  -- 15.9. Đóng Session bàn
  UPDATE public.ban_sessions
  SET status = 'closed',
      closed_at = now(),
      total_amount = v_final_total
  WHERE id = p_session_id;

  -- 15.11. Audit log
  INSERT INTO public.qr_audit_logs (
    store_id, request_id, action, actor_user_id, details
  ) VALUES (
    p_store_id, NULL, 'settle_session_v5', v_staff.member_user_id,
    jsonb_build_object(
      'session_id', p_session_id,
      'settlement_id', v_settlement_id,
      'subtotal', v_raw_subtotal,
      'discount', v_discount,
      'points_discount', v_points_discount,
      'coupon_discount', v_coupon_discount,
      'surcharge', v_surcharge,
      'total_amount', v_final_total,
      'request_fingerprint', v_request_fingerprint,
      'idempotency_key', p_idempotency_key
    )
  );

  SELECT COALESCE(jsonb_agg(order_id), '[]'::jsonb) INTO v_canonical_order_ids
  FROM public.ban_session_orders
  WHERE session_id = p_session_id;

  SELECT COALESCE(jsonb_agg(o.order_number), '[]'::jsonb) INTO v_order_numbers
  FROM public.orders o
  JOIN public.ban_session_orders bso ON bso.order_id = o.id
  WHERE bso.session_id = p_session_id;

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'session_id', p_session_id,
      'settlement_id', v_settlement_id,
      'canonical_order_ids', v_canonical_order_ids,
      'order_numbers', v_order_numbers,
      'subtotal', v_raw_subtotal,
      'discount', v_discount,
      'points_discount', v_points_discount,
      'coupon_discount', v_coupon_discount,
      'surcharge', v_surcharge,
      'total_amount', v_final_total,
      'payment_method', p_payment_method,
      'customer_id', p_customer_id,
      'pts_earned', v_pts_earned,
      'is_replay', false
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.settle_ban_session_v5(uuid, uuid, text, text, uuid, integer, numeric, text, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.settle_ban_session_v5(uuid, uuid, text, text, uuid, integer, numeric, text, numeric) TO anon, authenticated, service_role;


-- ── 5. DATA RECONCILIATION: BÙ HOÀN TỒN KHO CHO CÁC ĐƠN HÀNG BỊ TRỪ LỖI ───────

-- ── B. Đối soát các lần trừ kho công thức đã sai đơn vị ──────────────────────
CREATE OR REPLACE FUNCTION public.reconcile_recipe_usage_units_v2(p_dry_run boolean DEFAULT true)
RETURNS TABLE (movement_id uuid, store_id uuid, ingredient text, stock_unit text, recipe_unit text, wrongly_deducted numeric, correct_deduct numeric, refund numeric, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_catalog, pg_temp AS $$
#variable_conflict use_column
DECLARE r record; v_units text[]; v_ru text; v_correct numeric; v_refund numeric;
BEGIN
  FOR r IN
    SELECT sm.id, sm.store_id, sm.product_id, sm.delta, sm.note, p.name AS pname, p.unit AS punit,
           COALESCE(p.conversion_rate,0) AS crate, COALESCE(p.conversion_unit,'') AS cunit
    FROM public.stock_movements sm JOIN public.products p ON p.id::text = sm.product_id::text
    WHERE sm.reason = 'recipe_usage' AND sm.delta < 0 ORDER BY sm.created_at
  LOOP
    movement_id := r.id; store_id := r.store_id; ingredient := r.pname; stock_unit := r.punit;
    wrongly_deducted := abs(r.delta);
    IF EXISTS (SELECT 1 FROM public.stock_movements x WHERE x.reason='reconciliation' AND x.reference_id::text = r.id::text) THEN
      recipe_unit := NULL; correct_deduct := NULL; refund := 0; status := 'đã bù trước đó'; RETURN NEXT; CONTINUE;
    END IF;
    -- Ưu tiên các dòng công thức mà số lượng trừ sai là bội số nguyên của (quantity / yield) — khớp đúng công thức đã bán
    SELECT array_agg(DISTINCT lower(trim(ri.unit))) INTO v_units
    FROM public.recipe_ingredients ri JOIN public.recipes rc ON rc.id::text = ri.recipe_id::text
    WHERE ri.ingredient_id::text = r.product_id::text AND rc.store_id::text = r.store_id::text
      AND COALESCE(ri.quantity,0) > 0
      AND abs(abs(r.delta) / (ri.quantity / CASE WHEN COALESCE(ri.yield_factor,0) <= 0 THEN 1 ELSE ri.yield_factor END)
              - round(abs(r.delta) / (ri.quantity / CASE WHEN COALESCE(ri.yield_factor,0) <= 0 THEN 1 ELSE ri.yield_factor END))) < 0.0001
      AND round(abs(r.delta) / (ri.quantity / CASE WHEN COALESCE(ri.yield_factor,0) <= 0 THEN 1 ELSE ri.yield_factor END)) >= 1;
    IF v_units IS NULL OR array_length(v_units,1) <> 1 THEN
      SELECT array_agg(DISTINCT lower(trim(ri.unit))) INTO v_units
      FROM public.recipe_ingredients ri JOIN public.recipes rc ON rc.id::text = ri.recipe_id::text
      WHERE ri.ingredient_id::text = r.product_id::text AND rc.store_id::text = r.store_id::text;
    END IF;
    IF v_units IS NULL OR array_length(v_units,1) <> 1 THEN
      recipe_unit := array_to_string(v_units, '/'); correct_deduct := NULL; refund := 0; status := 'BỎ QUA: đơn vị công thức không rõ/không duy nhất'; RETURN NEXT; CONTINUE;
    END IF;
    v_ru := v_units[1];
    v_correct := public.convert_recipe_ingredient_qty_v1(abs(r.delta), v_ru, r.punit, r.crate, r.cunit);
    v_refund := abs(r.delta) - v_correct;
    recipe_unit := v_ru; correct_deduct := v_correct; refund := v_refund;
    IF v_refund <= 0.0000001 THEN status := 'đúng đơn vị — không cần bù'; RETURN NEXT; CONTINUE; END IF;
    IF NOT p_dry_run THEN
      INSERT INTO public.stock_movements (id, store_id, product_id, delta, reason, reference_id, note, created_at)
      VALUES (gen_random_uuid(), r.store_id, r.product_id, v_refund, 'reconciliation', r.id,
              'Bù hoàn quy đổi đơn vị công thức (' || v_ru || ' → ' || r.punit || '): ' || COALESCE(r.note,''), now());
      UPDATE public.products SET stock_qty = COALESCE(stock_qty,0) + v_refund WHERE id::text = r.product_id::text;
      status := 'ĐÃ BÙ';
    ELSE status := 'sẽ bù (chạy thử)'; END IF;
    RETURN NEXT;
  END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.reconcile_recipe_usage_units_v2(boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_recipe_usage_units_v2(boolean) TO service_role;
