-- ============================================================================
-- MIGRATION: 20260902_atomic_settlement_v5.sql
-- Mục đích: Khắc phục triệt để lỗi P0 thanh toán trùng bill trên Quán Nhỏ POS
-- Tính năng:
--   1. Bảng daily_order_counters & Function generate_daily_order_number_v1 nguyên tử
--   2. Bảng pos_idempotency_operations quản lý idempotency POS bán nhanh
--   3. Bảng pos_coupon_redemptions với Conditional FK an toàn theo schema coupons
--   4. Preflight Fail-Safe & Partial Unique Index trên finance_records
--   5. RPC settle_ban_session_v5: Hợp nhất bàn thường + QR, 1 transaction commit
--   6. RPC reconcile_ban_settlement_v1: Query đối chiếu trạng thái sau timeout
--   7. RPC complete_pos_sale_v1: Atomic POS bán nhanh Fail-Closed
-- ============================================================================

BEGIN;

-- ── 1. BẢNG BỘ ĐẾM SỐ ĐƠN NGUYÊN TỬ THEO NGÀY ────────────────────────────────
CREATE TABLE IF NOT EXISTS public.daily_order_counters (
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  business_date date NOT NULL,
  prefix text NOT NULL DEFAULT 'QN',
  last_seq integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (store_id, business_date, prefix)
);

CREATE INDEX IF NOT EXISTS idx_daily_order_counters_store_date 
ON public.daily_order_counters(store_id, business_date);

REVOKE ALL ON public.daily_order_counters FROM PUBLIC, anon, authenticated;

-- ── 2. FUNCTION SINH SỐ ĐƠN NGUYÊN TỬ (ATOMIC ORDER NUMBER) ───────────────────
CREATE OR REPLACE FUNCTION public.generate_daily_order_number_v1(
  p_store_id uuid,
  p_prefix text DEFAULT 'QN',
  p_tz text DEFAULT 'Asia/Ho_Chi_Minh'
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $$
DECLARE
  v_staff record;
  v_today date;
  v_seq integer;
  v_existing_max integer := 0;
  v_start_of_day timestamptz;
  v_end_of_day timestamptz;
  v_clean_prefix text;
BEGIN
  IF p_store_id IS NULL THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: store_id is required' USING ERRCODE = '42501';
  END IF;

  -- 1. Xác thực thành viên cửa hàng (Fail-Closed)
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => false);

  v_clean_prefix := upper(trim(COALESCE(p_prefix, 'QN')));
  
  -- 2. Xác định ngày kinh doanh theo múi giờ cửa hàng
  BEGIN
    v_today := (now() AT TIME ZONE p_tz)::date;
    v_start_of_day := (v_today::text || ' 00:00:00')::timestamp AT TIME ZONE p_tz;
    v_end_of_day := (v_today::text || ' 23:59:59.999999')::timestamp AT TIME ZONE p_tz;
  EXCEPTION WHEN OTHERS THEN
    v_today := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
    v_start_of_day := (v_today::text || ' 00:00:00')::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh';
    v_end_of_day := (v_today::text || ' 23:59:59.999999')::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh';
  END;

  -- 3. Kiểm tra nếu dòng counter chưa tồn tại: Seed từ số max hiện hữu trong orders
  IF NOT EXISTS (
    SELECT 1 FROM public.daily_order_counters
    WHERE store_id = p_store_id AND business_date = v_today AND prefix = v_clean_prefix
  ) THEN
    SELECT COALESCE(
      MAX(NULLIF(regexp_replace(order_number, '^.*-', ''), '')::integer), 0
    ) INTO v_existing_max
    FROM public.orders
    WHERE store_id = p_store_id
      AND created_at >= v_start_of_day
      AND created_at <= v_end_of_day
      AND order_number ~ ('^' || v_clean_prefix || '-\d{8}-\d+$');
  END IF;

  -- 4. Atomic Upsert
  INSERT INTO public.daily_order_counters (
    store_id, business_date, prefix, last_seq, updated_at
  ) VALUES (
    p_store_id, v_today, v_clean_prefix, GREATEST(1, v_existing_max + 1), now()
  )
  ON CONFLICT (store_id, business_date, prefix)
  DO UPDATE SET
    last_seq = daily_order_counters.last_seq + 1,
    updated_at = now()
  RETURNING last_seq INTO v_seq;

  RETURN v_clean_prefix || '-' || to_char(v_today, 'YYYYMMDD') || '-' || lpad(v_seq::text, GREATEST(3, length(v_seq::text)), '0');
END;
$$;

-- ── 3. BẢNG QUẢN LÝ IDEMPOTENCY CHO POS BÁN NHANH ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.pos_idempotency_operations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  idempotency_key text NOT NULL,
  cart_fingerprint text NOT NULL,
  order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
  order_number text NOT NULL,
  total_amount numeric NOT NULL DEFAULT 0,
  payment_method text NOT NULL DEFAULT 'cash',
  status text NOT NULL DEFAULT 'completed',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_pos_idemp_key UNIQUE (store_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_pos_idemp_store_key ON public.pos_idempotency_operations(store_id, idempotency_key);
ALTER TABLE public.pos_idempotency_operations
  ADD COLUMN IF NOT EXISTS wallet_real_used numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS wallet_bonus_used numeric NOT NULL DEFAULT 0;
REVOKE ALL ON public.pos_idempotency_operations FROM PUBLIC, anon, authenticated;

-- Gắn rõ thu ngân đã commit settlement để báo cáo không suy đoán từ orders.
ALTER TABLE public.payment_settlements
ADD COLUMN IF NOT EXISTS cashier_staff_id uuid;

CREATE INDEX IF NOT EXISTS idx_payment_settlements_store_cashier_created
ON public.payment_settlements(store_id, cashier_staff_id, created_at);

-- ── 4. BẢNG POS COUPON REDEMPTIONS (CONDITIONAL FOREIGN KEY AN TOÀN) ──────────
CREATE TABLE IF NOT EXISTS public.pos_coupon_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  pos_operation_id uuid REFERENCES public.pos_idempotency_operations(id) ON DELETE CASCADE,
  coupon_id uuid,
  coupon_code text NOT NULL,
  discount_amount numeric NOT NULL DEFAULT 0,
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_pos_coupon_redemption_order UNIQUE (store_id, order_id)
);

CREATE INDEX IF NOT EXISTS idx_pos_coupon_redemptions_store_order ON public.pos_coupon_redemptions(store_id, order_id);
REVOKE ALL ON public.pos_coupon_redemptions FROM PUBLIC, anon, authenticated;

-- Thêm Foreign Key có điều kiện nếu public.coupons tồn tại trong database
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'coupons'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_schema = 'public' 
      AND table_name = 'pos_coupon_redemptions' 
      AND constraint_name = 'fk_pos_coupon_redemptions_coupons'
  ) THEN
    ALTER TABLE public.pos_coupon_redemptions
    ADD CONSTRAINT fk_pos_coupon_redemptions_coupons
    FOREIGN KEY (coupon_id) REFERENCES public.coupons(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ── 5. PREFLIGHT FAIL-SAFE & PARTIAL UNIQUE INDEX TRÊN FINANCE_RECORDS ────────
-- Wallet top-ups legitimately reuse customer_id as reference_id. Only a
-- canonical checkout reference participates in the uniqueness constraint.
ALTER TABLE public.finance_records ADD COLUMN IF NOT EXISTS checkout_reference_id uuid;
CREATE OR REPLACE FUNCTION public.classify_checkout_income_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_catalog, pg_temp AS $$
BEGIN
  NEW.checkout_reference_id := NULL;
  IF NEW.is_auto AND NEW.type = 'income' AND (
    EXISTS (SELECT 1 FROM public.orders WHERE id = NEW.reference_id AND store_id = NEW.store_id)
    OR EXISTS (SELECT 1 FROM public.payment_settlements WHERE id = NEW.reference_id AND store_id = NEW.store_id)
  ) THEN
    NEW.checkout_reference_id := NEW.reference_id;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS classify_checkout_income_v1 ON public.finance_records;
CREATE TRIGGER classify_checkout_income_v1 BEFORE INSERT OR UPDATE ON public.finance_records
FOR EACH ROW EXECUTE FUNCTION public.classify_checkout_income_v1();
DROP INDEX IF EXISTS public.uq_finance_auto_settlement_income;
UPDATE public.finance_records SET checkout_reference_id = reference_id
WHERE is_auto AND type = 'income' AND (
  EXISTS (SELECT 1 FROM public.orders o WHERE o.id = reference_id AND o.store_id = finance_records.store_id)
  OR EXISTS (SELECT 1 FROM public.payment_settlements s WHERE s.id = reference_id AND s.store_id = finance_records.store_id)
);
DO $$
DECLARE
  v_dup_count integer := 0;
BEGIN
  SELECT count(*) INTO v_dup_count
  FROM (
    SELECT store_id, checkout_reference_id, count(*)
    FROM public.finance_records
    WHERE checkout_reference_id IS NOT NULL
    GROUP BY store_id, checkout_reference_id
    HAVING count(*) > 1
  ) dups;

  IF v_dup_count > 0 THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Found % duplicate auto-income records in finance_records. Must reconcile before applying unique index!', v_dup_count USING ERRCODE = '23505';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_finance_auto_settlement_income
ON public.finance_records (store_id, checkout_reference_id)
WHERE checkout_reference_id IS NOT NULL;

-- ── 6. RPC READ-ONLY: RECONCILE BAN SETTLEMENT ────────────────────────────────
-- Serialize financial item changes with checkout's parent-session lock.
-- Kitchen progress after payment remains allowed; cancel/quantity/price do not.
CREATE OR REPLACE FUNCTION public.guard_ban_item_financial_change_v5()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_catalog, pg_temp AS $$
DECLARE v_status text; v_store uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF ROW(NEW.store_id, NEW.session_id, NEW.product_id, NEW.quantity, NEW.unit_price, NEW.subtotal, NEW.modifiers_json,
           COALESCE(NEW.kitchen_status, '') = 'huy') IS NOT DISTINCT FROM
       ROW(OLD.store_id, OLD.session_id, OLD.product_id, OLD.quantity, OLD.unit_price, OLD.subtotal, OLD.modifiers_json,
           COALESCE(OLD.kitchen_status, '') = 'huy') THEN RETURN NEW; END IF;
    IF NEW.store_id <> OLD.store_id THEN RAISE EXCEPTION 'CROSS_STORE_ITEM_MOVE'; END IF;
    IF NEW.session_id <> OLD.session_id THEN
      PERFORM 1 FROM public.ban_sessions WHERE id IN (OLD.session_id, NEW.session_id) ORDER BY id FOR UPDATE;
      SELECT status INTO v_status FROM public.ban_sessions WHERE id = OLD.session_id;
      IF v_status IS DISTINCT FROM 'open' THEN RAISE EXCEPTION 'SESSION_NOT_OPEN'; END IF;
    END IF;
  END IF;
  SELECT status, store_id INTO v_status, v_store FROM public.ban_sessions
  WHERE id = CASE WHEN TG_OP = 'DELETE' THEN OLD.session_id ELSE NEW.session_id END FOR UPDATE;
  IF NOT FOUND AND TG_OP = 'DELETE' THEN RETURN OLD; END IF; -- parent cascade
  IF v_status IS DISTINCT FROM 'open' OR v_store IS DISTINCT FROM
     (CASE WHEN TG_OP = 'DELETE' THEN OLD.store_id ELSE NEW.store_id END) THEN
    RAISE EXCEPTION 'SESSION_NOT_OPEN: financial items cannot change after checkout';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS guard_ban_item_financial_change_v5 ON public.ban_session_items;
CREATE TRIGGER guard_ban_item_financial_change_v5 BEFORE INSERT OR UPDATE OR DELETE ON public.ban_session_items
FOR EACH ROW EXECUTE FUNCTION public.guard_ban_item_financial_change_v5();

CREATE OR REPLACE FUNCTION public.reconcile_ban_settlement_v1(
  p_store_id uuid,
  p_session_id uuid,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $$
DECLARE
  v_staff record;
  v_settle record;
  v_other_sess uuid;
  v_other_key text;
  v_session record;
  v_canonical_order_ids jsonb;
  v_order_numbers jsonb;
BEGIN
  -- 1. Xác thực quyền thành viên
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => false);

  -- 2. Validate consistency khi cả session_id và idempotency_key cùng được cung cấp
  IF p_session_id IS NOT NULL AND p_idempotency_key IS NOT NULL AND trim(p_idempotency_key) <> '' THEN
    SELECT * INTO v_settle
    FROM public.payment_settlements
    WHERE store_id = p_store_id AND session_id = p_session_id AND idempotency_key = p_idempotency_key
    LIMIT 1;

    IF v_settle.id IS NULL THEN
      -- Kiểm tra xem idempotency_key có thuộc session khác không
      SELECT session_id INTO v_other_sess
      FROM public.payment_settlements
      WHERE store_id = p_store_id AND idempotency_key = p_idempotency_key
      LIMIT 1;

      IF v_other_sess IS NOT NULL THEN
        RETURN jsonb_build_object(
          'success', false,
          'is_settled', false,
          'error_code', 'IDEMPOTENCY_CONFLICT',
          'message', 'Idempotency key này thuộc về một phiên bàn khác'
        );
      END IF;

      -- Kiểm tra xem session đã settle với key khác chưa
      SELECT idempotency_key INTO v_other_key
      FROM public.payment_settlements
      WHERE store_id = p_store_id AND session_id = p_session_id
      LIMIT 1;

      IF v_other_key IS NOT NULL THEN
        RETURN jsonb_build_object(
          'success', false,
          'is_settled', false,
          'error_code', 'IDEMPOTENCY_CONFLICT',
          'message', 'Phiên bàn đã được thanh toán dưới một idempotency key khác'
        );
      END IF;
    END IF;
  ELSIF p_session_id IS NOT NULL THEN
    SELECT * INTO v_settle FROM public.payment_settlements WHERE store_id = p_store_id AND session_id = p_session_id LIMIT 1;
  ELSIF p_idempotency_key IS NOT NULL AND trim(p_idempotency_key) <> '' THEN
    SELECT * INTO v_settle FROM public.payment_settlements WHERE store_id = p_store_id AND idempotency_key = p_idempotency_key LIMIT 1;
  ELSE
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'session_id hoặc idempotency_key là bắt buộc');
  END IF;

  IF v_settle.id IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(order_id), '[]'::jsonb) INTO v_canonical_order_ids
    FROM public.ban_session_orders
    WHERE session_id = v_settle.session_id;

    SELECT COALESCE(jsonb_agg(o.order_number), '[]'::jsonb) INTO v_order_numbers
    FROM public.orders o
    JOIN public.ban_session_orders bso ON bso.order_id = o.id
    WHERE bso.session_id = v_settle.session_id;

    RETURN jsonb_build_object(
      'success', true,
      'is_settled', true,
      'data', jsonb_build_object(
        'session_id', v_settle.session_id,
        'settlement_id', v_settle.id,
        'canonical_order_ids', v_canonical_order_ids,
        'order_numbers', v_order_numbers,
        'subtotal', v_settle.subtotal,
        'discount', v_settle.discount,
        'points_discount', v_settle.points_discount,
        'coupon_discount', v_settle.coupon_discount,
        'surcharge', v_settle.surcharge,
        'total_amount', v_settle.total_amount,
        'payment_method', v_settle.payment_method,
        'customer_id', v_settle.customer_id,
        'points_used', v_settle.points_used,
        'coupon_code', v_settle.coupon_code,
        'created_at', v_settle.created_at,
        'is_replay', true
      )
    );
  END IF;

  -- 3. Nếu chưa settle: Kiểm tra trạng thái phiên bàn
  IF p_session_id IS NOT NULL THEN
    SELECT * INTO v_session
    FROM public.ban_sessions
    WHERE id = p_session_id AND store_id = p_store_id;

    IF v_session.id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'success', true,
        'is_settled', false,
        'status', v_session.status,
        'message', 'Phiên bàn chưa thanh toán'
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', false,
    'is_settled', false,
    'error_code', 'NOT_FOUND',
    'message', 'Không tìm thấy thông tin quyết toán hoặc phiên bàn'
  );
END;
$$;

-- ── 7. RPC CHÍNH: ATOMIC BAN SESSION SETTLEMENT V5 ─────────────────────────────
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

    INSERT INTO public.orders (
      id, store_id, order_number, subtotal, discount, tax, total, total_amount,
      payment_method, status, source_type, source_id, staff_id, waiter_id, receipt_printed, created_at, note
    ) VALUES (
      v_manual_order_id, p_store_id, v_manual_order_num, v_manual_subtotal, 0, 0, v_manual_subtotal, v_manual_subtotal,
      p_payment_method, 'completed', 'ban_manual', p_session_id::text, v_staff_member_id, v_session.waiter_id, false, now(),
      'Món thanh toán tại bàn ' || COALESCE(v_table.label, v_table.name, 'bàn')
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
        staff_id = COALESCE(v_staff_member_id, staff_id),
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

-- ── 8. RPC: ATOMIC POS QUICK SALE V1 (100% FAIL-CLOSED) ───────────────────────
-- Remove only obsolete draft signatures (migration is not deployed yet).
DROP FUNCTION IF EXISTS public.complete_pos_sale_v1(uuid, text, jsonb, text, uuid, numeric, numeric, text, text, text, text);
DROP FUNCTION IF EXISTS public.complete_pos_sale_v1(uuid, text, jsonb, text, uuid, numeric, numeric, text, text, text, text, numeric);
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
  -- A batch paid by either route must never be charged by the other route.
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
  -- Lock every selected customer, including wallet-only and earn-only sales.
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

  -- 8. Validate Coupon nếu có (100% Fail-Closed)
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
  -- Client POS truyền expected coupon/manual discount; điểm là quantity riêng
  -- và được server quy đổi theo loyalty_redeem_rate.
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
  -- Validate wallet before any writes. Customer lock serializes distinct keys.
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
  -- store_members is the auth membership; maintain its canonical staff mirror
  -- before orders.staff_id references it. Never overwrite existing permissions.
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

  -- 14. Ghi Order Items & Trừ kho
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
        SELECT ri.ingredient_id, ri.quantity, ri.yield_factor
        FROM public.recipes r
        JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
        WHERE r.pos_product_id::text = $1::text
          AND r.is_deleted = false
          AND ri.ingredient_id IS NOT NULL
      ' USING v_prod.id
      LOOP
        v_actual_ing_qty :=
          (v_rec_ing.quantity /
            COALESCE(NULLIF(v_rec_ing.yield_factor, 0), 1.0)) * v_qty;
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

-- ── 9. GRANTS VÀ PHÂN QUYỀN CHẶT CHẼ ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.reconcile_pos_sale_v1(p_store_id uuid, p_idempotency_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_catalog, pg_temp AS $$
DECLARE v_result jsonb;
BEGIN
  PERFORM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);
  PERFORM pg_advisory_xact_lock(hashtext(p_store_id::text), hashtext('pos_sale:' || p_idempotency_key));
  SELECT jsonb_build_object('order_id', op.order_id, 'order_number', op.order_number,
    'total_amount', op.total_amount, 'subtotal', o.subtotal, 'discount', o.discount,
    'payment_method', op.payment_method, 'wallet_real_used', op.wallet_real_used,
    'wallet_bonus_used', op.wallet_bonus_used, 'is_replay', true)
  INTO v_result FROM public.pos_idempotency_operations op
  JOIN public.orders o ON o.id = op.order_id AND o.store_id = op.store_id
  WHERE op.store_id = p_store_id AND op.idempotency_key = p_idempotency_key;
  IF v_result IS NULL THEN RETURN jsonb_build_object('success', false, 'error_code', 'RESULT_NOT_FOUND'); END IF;
  RETURN jsonb_build_object('success', true, 'data', v_result);
END $$;
REVOKE ALL ON FUNCTION public.reconcile_pos_sale_v1(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconcile_pos_sale_v1(uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.generate_daily_order_number_v1(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_daily_order_number_v1(uuid, text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.reconcile_ban_settlement_v1(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconcile_ban_settlement_v1(uuid, uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.settle_ban_session_v5(uuid, uuid, text, text, uuid, integer, numeric, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.settle_ban_session_v5(uuid, uuid, text, text, uuid, integer, numeric, text, numeric) TO authenticated;

REVOKE ALL ON FUNCTION public.complete_pos_sale_v1(uuid, text, jsonb, text, uuid, numeric, numeric, text, text, text, text, numeric, uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_pos_sale_v1(uuid, text, jsonb, text, uuid, numeric, numeric, text, text, text, text, numeric, uuid[]) TO authenticated;

COMMIT;
