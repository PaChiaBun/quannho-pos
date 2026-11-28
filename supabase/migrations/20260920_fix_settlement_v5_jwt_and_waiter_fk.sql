-- ============================================================================
-- MIGRATION: 20260920_fix_settlement_v5_jwt_and_waiter_fk.sql
-- Mục đích:
--   1. Cập nhật verify_staff_qr_membership_v4 hỗ trợ PostgREST 10+ claims JSON (request.jwt.claims ->> 'sub'),
--      fallback stores.owner_user_id, và nhận diện vai trò waiter/phục vụ cho phép pos.checkout.
--   2. Cập nhật settle_ban_session_v5 phòng vệ khóa ngoại orders.waiter_id và orders.staff_id,
--      tránh Exception làm gián đoạn transaction thanh toán bàn.
-- ============================================================================

BEGIN;

-- ── 1. CẬP NHẬT FUNCTION: verify_staff_qr_membership_v4 ───────────────────────
CREATE OR REPLACE FUNCTION public.verify_staff_qr_membership_v4(
  p_store_id uuid,
  p_require_checkout boolean DEFAULT false,
  p_require_manage boolean DEFAULT false
)
RETURNS TABLE (
  member_user_id uuid,
  member_role text,
  store_member_id uuid,
  is_owner_member boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $$
DECLARE
  v_uid uuid;
  v_sm_id uuid;
  v_role text;
  v_is_owner boolean;
  v_perms_json jsonb;
  v_has_checkout boolean := false;
BEGIN
  -- Trích xuất User ID qua auth.uid() hoặc JWT context đa tầng
  BEGIN
    v_uid := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_uid := NULL;
  END;

  IF v_uid IS NULL THEN
    BEGIN
      v_uid := NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_uid := NULL;
    END;
  END IF;

  IF v_uid IS NULL THEN
    BEGIN
      v_uid := NULLIF(((current_setting('request.jwt.claims', true)::jsonb)->>'sub'), '')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_uid := NULL;
    END;
  END IF;

  IF v_uid IS NULL THEN
    BEGIN
      v_uid := NULLIF((current_setting('request.headers', true)::jsonb)->>'x-user-id', '')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_uid := NULL;
    END;
  END IF;

  IF v_uid IS NULL THEN
    BEGIN
      v_uid := NULLIF(current_setting('request.header.x-user-id', true), '')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_uid := NULL;
    END;
  END IF;

  IF v_uid IS NULL OR p_store_id IS NULL THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: authenticated store context is required'
      USING ERRCODE = '42501';
  END IF;

  -- 1. Tìm thông tin trong store_members
  SELECT sm.id, sm.role, COALESCE(sm.is_owner, false)
  INTO v_sm_id, v_role, v_is_owner
  FROM public.store_members sm
  WHERE sm.store_id = p_store_id AND sm.user_id = v_uid
  LIMIT 1;

  -- 2. Fallback: Nếu không có trong store_members, kiểm tra stores (Owner)
  IF v_role IS NULL THEN
    SELECT 'owner', true
    INTO v_role, v_is_owner
    FROM public.stores
    WHERE id = p_store_id AND (owner_user_id = v_uid OR owner_id = v_uid)
    LIMIT 1;
  END IF;

  -- 3. Fallback: Kiểm tra trực tiếp trong staff_members
  IF v_role IS NULL THEN
    SELECT sm.role, false
    INTO v_role, v_is_owner
    FROM public.staff_members sm
    WHERE sm.store_id = p_store_id AND sm.id = v_uid
    LIMIT 1;
  END IF;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: not a member of this store'
      USING ERRCODE = '42501';
  END IF;

  IF p_require_manage AND NOT (v_is_owner OR v_role IN ('owner', 'manager', 'admin')) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: manage permission required'
      USING ERRCODE = '42501';
  END IF;

  IF p_require_checkout AND NOT (v_is_owner OR v_role = 'owner') THEN
    -- 1. Ưu tiên vai trò chuẩn (owner, manager, cashier, admin, waiter) hoặc tiếng Việt
    IF v_role IN ('owner', 'manager', 'cashier', 'admin', 'waiter')
       OR lower(trim(v_role)) LIKE '%thu ngân%'
       OR lower(trim(v_role)) LIKE '%quản lý%'
       OR lower(trim(v_role)) LIKE '%quầy%'
       OR lower(trim(v_role)) LIKE '%phục vụ%'
       OR lower(trim(v_role)) LIKE '%chạy bàn%'
       OR lower(trim(v_role)) LIKE '%bán hàng%' THEN
      v_has_checkout := true;
    END IF;

    -- 2. Kiểm tra modules từ store_roles (Lego Modules)
    IF NOT v_has_checkout THEN
      BEGIN
        SELECT EXISTS (
          SELECT 1
          FROM public.store_roles sr,
               LATERAL jsonb_array_elements_text(
                 CASE
                   WHEN sr.modules IS NULL OR btrim(sr.modules::text) = '' THEN '[]'::jsonb
                   WHEN jsonb_typeof(sr.modules::jsonb) = 'array' THEN sr.modules::jsonb
                   ELSE '[]'::jsonb
                 END
               ) AS m(module_name)
          WHERE sr.store_id = p_store_id
            AND (sr.name = v_role OR lower(trim(sr.name)) = lower(trim(v_role)))
            AND m.module_name IN ('pos', 'ban')
        ) INTO v_has_checkout;
      EXCEPTION WHEN OTHERS THEN
        v_has_checkout := false;
      END;
    END IF;

    -- 3. Kiểm tra modules từ staff_members
    IF NOT v_has_checkout THEN
      BEGIN
        SELECT EXISTS (
          SELECT 1
          FROM public.staff_members sm,
               LATERAL jsonb_array_elements_text(
                 CASE
                   WHEN sm.modules IS NULL OR btrim(sm.modules::text) = '' THEN '[]'::jsonb
                   WHEN jsonb_typeof(sm.modules::jsonb) = 'array' THEN sm.modules::jsonb
                   ELSE '[]'::jsonb
                 END
               ) AS m(module_name)
          WHERE sm.store_id = p_store_id
            AND sm.id = v_uid
            AND m.module_name IN ('pos', 'ban')
        ) INTO v_has_checkout;
      EXCEPTION WHEN OTHERS THEN
        v_has_checkout := false;
      END;
    END IF;

    -- 4. Fallback kiểm tra app_settings (action_perms_*)
    IF NOT v_has_checkout THEN
      SELECT CASE
        WHEN s.value IS NULL OR btrim(s.value) = '' THEN '[]'::jsonb
        ELSE s.value::jsonb
      END
      INTO v_perms_json
      FROM public.app_settings s
      WHERE s.store_id = p_store_id
        AND (s.key = 'action_perms_' || v_role OR s.key = 'action_perms_cashier')
      LIMIT 1;
      IF jsonb_typeof(COALESCE(v_perms_json, '[]'::jsonb)) = 'array' THEN
        SELECT EXISTS (
          SELECT 1 FROM jsonb_array_elements_text(v_perms_json) permission
          WHERE permission = 'pos.checkout'
        ) INTO v_has_checkout;
      END IF;
    END IF;

    IF NOT v_has_checkout THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: pos.checkout permission required'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  member_user_id := v_uid;
  member_role := v_role;
  store_member_id := v_uid;
  is_owner_member := v_is_owner OR v_role = 'owner';
  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.verify_staff_qr_membership_v4(uuid, boolean, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_staff_qr_membership_v4(uuid, boolean, boolean) TO anon, authenticated, service_role;

-- ── 2. CẬP NHẬT FUNCTION: settle_ban_session_v5 ───────────────────────────────
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

  -- Live schema keeps dining-table ids as text while ban_sessions.table_id is
  -- UUID for historical compatibility. Compare through the canonical text id.
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

    -- Safe waiter_id lookup (orders.waiter_id is text; staff_members.id is uuid)
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

  -- 15.6. Chuyển toàn bộ Canonical Orders sang Completed & Trừ kho
  -- Canonical item totals follow the payable session snapshot, not stale QR
  -- quantities. Cancelled quantities remain intact in ban_session_items/audit.
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

    -- Trừ kho sản phẩm & công thức
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
          SELECT ri.ingredient_id, ri.quantity, ri.yield_factor
          FROM public.recipes r
          JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
          WHERE r.pos_product_id::text = $1::text AND r.is_deleted = false AND ri.ingredient_id IS NOT NULL
        ' USING v_item.product_id
        LOOP
          v_actual_ing_qty := (v_rec_ing.quantity / COALESCE(NULLIF(v_rec_ing.yield_factor, 0), 1.0)) * v_item.quantity;
          
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

      -- Trừ kho toppings nếu có
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
                SELECT ri.ingredient_id, ri.quantity, ri.yield_factor
                FROM public.recipes r
                JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
                WHERE r.pos_product_id::text = $1::text AND r.is_deleted = false AND ri.ingredient_id IS NOT NULL
              ' USING (v_mod->>'id')::uuid
              LOOP
                v_actual_ing_qty := (v_rec_ing.quantity / COALESCE(NULLIF(v_rec_ing.yield_factor, 0), 1.0)) * ((COALESCE((v_mod->>'quantity')::numeric, 1)) * v_item.quantity);
                
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

  -- 15.9. Đóng Session bàn. Trạng thái bàn được suy ra từ phiên đang mở;
  -- production ban_dining_tables không có cột status.
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

COMMIT;

-- Reload schema cache cho PostgREST
NOTIFY pgrst, 'reload schema';
