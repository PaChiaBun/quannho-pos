-- ============================================================================
-- MIGRATION: QR Order V4 (Quán Nhỏ POS)
-- Target: Staging & Production Compatible (Zero Drift, Strict Contract)
-- Security: SECURITY DEFINER, SET search_path = pg_catalog, public, Fail-Closed
-- Contract Verified: orders, order_items, finance_records, ban_sessions,
--                    ban_session_items, kitchen_tickets, kitchen_ticket_items,
--                    stock_movements, products, store_members, staff_members,
--                    user_accounts, app_settings, customers, loyalty_transactions.
-- ============================================================================

-- ── 0. TIỆN ÍCH EXTENSIONS ───────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── 1. CÁC BẢNG DỮ LIỆU QR V4 ───────────────────────────────────────────────

-- Bảng 1: Kênh QR (TABLE_SHARED & COUNTER_TAKEAWAY)
CREATE TABLE IF NOT EXISTS public.qr_channels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('TABLE_SHARED', 'COUNTER_TAKEAWAY', 'table', 'counter')),
  channel_code text NOT NULL,
  name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  payment_mode text NOT NULL DEFAULT 'CASHIER_CONFIRM' CHECK (payment_mode IN ('PAY_BEFORE_KITCHEN', 'CASHIER_CONFIRM')),
  pickup_counter integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_qr_channels_store_type UNIQUE (store_id, type),
  CONSTRAINT uq_qr_channels_code UNIQUE (channel_code)
);

CREATE INDEX IF NOT EXISTS idx_qr_channels_code ON public.qr_channels(channel_code);
CREATE INDEX IF NOT EXISTS idx_qr_channels_store ON public.qr_channels(store_id);

-- Bảng 2: Yêu cầu gọi món QR
CREATE TABLE IF NOT EXISTS public.qr_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  channel_id uuid NOT NULL REFERENCES public.qr_channels(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('TABLE_SHARED', 'COUNTER_TAKEAWAY', 'table', 'counter')),
  table_hint text,
  assigned_table_id uuid REFERENCES public.ban_dining_tables(id) ON DELETE SET NULL,
  assigned_session_id uuid REFERENCES public.ban_sessions(id) ON DELETE SET NULL,
  canonical_order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  pickup_code text,
  tracking_token text NOT NULL,
  idempotency_key text,
  payload_hash text,
  status text NOT NULL DEFAULT 'customer_submitted' CHECK (
    status IN (
      'customer_submitted',
      'pending_staff',
      'claimed',
      'staff_review',
      'confirmed',
      'awaiting_payment',
      'ready_for_kitchen',
      'sent_kitchen',
      'completed',
      'cancelled',
      'rejected',
      'expired'
    )
  ),
  payment_status text NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'refunded')),
  payment_method text,
  customer_note text NOT NULL DEFAULT '',
  reject_reason text,
  total_amount numeric NOT NULL DEFAULT 0,
  version integer NOT NULL DEFAULT 1,
  claimed_by_user_id uuid,
  claimed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 minutes')
);

CREATE INDEX IF NOT EXISTS idx_qr_requests_store_status ON public.qr_requests(store_id, status);
CREATE INDEX IF NOT EXISTS idx_qr_requests_tracking ON public.qr_requests(tracking_token);
CREATE INDEX IF NOT EXISTS idx_qr_requests_table ON public.qr_requests(assigned_table_id);
CREATE INDEX IF NOT EXISTS idx_qr_requests_canonical_order ON public.qr_requests(canonical_order_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_qr_requests_store_idempotency
  ON public.qr_requests (store_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- Bảng 3: Chi tiết món trong đơn QR
CREATE TABLE IF NOT EXISTS public.qr_request_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.qr_requests(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
  product_name text NOT NULL,
  unit_price numeric NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  subtotal numeric NOT NULL,
  modifiers_json jsonb NOT NULL DEFAULT '[]'::jsonb,
  note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_qr_request_items_req ON public.qr_request_items(request_id);

-- Bảng 4: Mã QR bàn giao động (Opaque CSPRNG Token Hash, TTL 30 phút, Single-Use)
CREATE TABLE IF NOT EXISTS public.qr_handoff_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  request_id uuid NOT NULL REFERENCES public.qr_requests(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'consumed', 'expired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 minutes'),
  consumed_at timestamptz,
  consumed_by_user_id uuid
);

CREATE INDEX IF NOT EXISTS idx_qr_handoff_tokens_hash ON public.qr_handoff_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_qr_handoff_tokens_req ON public.qr_handoff_tokens(request_id);

-- Bảng 5: Audit Log QR Order
CREATE TABLE IF NOT EXISTS public.qr_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  request_id uuid REFERENCES public.qr_requests(id) ON DELETE SET NULL,
  action text NOT NULL,
  actor_user_id uuid,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_qr_audit_logs_store ON public.qr_audit_logs(store_id, created_at DESC);

-- Bảng 6: Liên kết Topping với Sản Phẩm (Món chính ↔ Topping)
CREATE TABLE IF NOT EXISTS public.product_topping_links (
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  topping_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (product_id, topping_id)
);

CREATE INDEX IF NOT EXISTS idx_product_topping_links_store ON public.product_topping_links(store_id);
CREATE INDEX IF NOT EXISTS idx_product_topping_links_pid ON public.product_topping_links(product_id);
CREATE INDEX IF NOT EXISTS idx_product_topping_links_tid ON public.product_topping_links(topping_id);

-- Bảng 7: Idempotency Thanh Toán Đơn QR Mang Đi (COUNTER_TAKEAWAY)
CREATE TABLE IF NOT EXISTS public.qr_payment_idempotency (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  request_id uuid NOT NULL REFERENCES public.qr_requests(id) ON DELETE CASCADE,
  idempotency_key text NOT NULL,
  canonical_order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  order_number text NOT NULL,
  total_amount numeric NOT NULL,
  payment_method text NOT NULL,
  status text NOT NULL DEFAULT 'completed',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_qr_payment_idemp_key UNIQUE (store_id, idempotency_key),
  CONSTRAINT uq_qr_payment_idemp_req UNIQUE (request_id)
);

CREATE INDEX IF NOT EXISTS idx_qr_payment_idemp_req ON public.qr_payment_idempotency(request_id);

-- Bảng 8: Idempotency Gửi Bếp (Send Kitchen)
CREATE TABLE IF NOT EXISTS public.qr_kitchen_idempotency (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  request_id uuid NOT NULL REFERENCES public.qr_requests(id) ON DELETE CASCADE,
  idempotency_key text NOT NULL,
  ticket_id uuid NOT NULL,
  session_id uuid,
  canonical_order_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_qr_kitchen_idemp_key UNIQUE (store_id, idempotency_key),
  CONSTRAINT uq_qr_kitchen_idemp_req UNIQUE (request_id)
);

CREATE INDEX IF NOT EXISTS idx_qr_kitchen_idemp_req ON public.qr_kitchen_idempotency(request_id);

-- Bảng 9: Liên Kết Đơn Canonical QR Với Phiên Bàn (TABLE_SHARED)
CREATE TABLE IF NOT EXISTS public.ban_session_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.ban_sessions(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  qr_request_id uuid REFERENCES public.qr_requests(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_ban_session_orders_order UNIQUE (order_id)
);

CREATE INDEX IF NOT EXISTS idx_ban_session_orders_sess ON public.ban_session_orders(session_id);

-- Bảng 10: Mapping Từng Món Session Tương Ứng Với Từng Dòng Order Item (Item-level mapping chống duplicate)
CREATE TABLE IF NOT EXISTS public.ban_session_order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.ban_sessions(id) ON DELETE CASCADE,
  session_item_id uuid NOT NULL UNIQUE,
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  order_item_id uuid NOT NULL REFERENCES public.order_items(id) ON DELETE CASCADE,
  source_type text NOT NULL CHECK (source_type IN ('qr_table', 'ban_manual')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ban_session_order_items_sess ON public.ban_session_order_items(session_id);

-- Bảng 11: Quyết Toán Thanh Toán Toàn Bộ Bàn (TABLE_SHARED Settlement)
CREATE TABLE IF NOT EXISTS public.payment_settlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.ban_sessions(id) ON DELETE CASCADE,
  idempotency_key text NOT NULL,
  request_fingerprint text NOT NULL,
  subtotal numeric NOT NULL DEFAULT 0,
  discount numeric NOT NULL DEFAULT 0,
  points_discount numeric NOT NULL DEFAULT 0,
  coupon_discount numeric NOT NULL DEFAULT 0,
  surcharge numeric NOT NULL DEFAULT 0,
  total_amount numeric NOT NULL DEFAULT 0,
  payment_method text NOT NULL DEFAULT 'cash',
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  points_used integer NOT NULL DEFAULT 0,
  coupon_code text,
  status text NOT NULL DEFAULT 'completed',
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_payment_settlements_idemp UNIQUE (store_id, idempotency_key),
  CONSTRAINT uq_payment_settlements_session UNIQUE (session_id)
);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'payment_settlements') THEN
    ALTER TABLE public.payment_settlements
      ADD COLUMN IF NOT EXISTS request_fingerprint text;

    ALTER TABLE public.payment_settlements
      ADD COLUMN IF NOT EXISTS points_discount numeric NOT NULL DEFAULT 0;

    ALTER TABLE public.payment_settlements
      ADD COLUMN IF NOT EXISTS coupon_discount numeric NOT NULL DEFAULT 0;

    UPDATE public.payment_settlements
      SET request_fingerprint = encode(digest(id::text || ':' || store_id::text || ':' || session_id::text || ':' || idempotency_key, 'sha256'), 'hex')
      WHERE request_fingerprint IS NULL;

    ALTER TABLE public.payment_settlements
      ALTER COLUMN request_fingerprint SET NOT NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_payment_settlements_sess ON public.payment_settlements(session_id);
CREATE INDEX IF NOT EXISTS idx_payment_settlements_fp ON public.payment_settlements(request_fingerprint);

-- Bảng 12: Ghi Nhận Sử Dụng Mã Giảm Giá Độc Lập Cho Settlement (Coupon Redemptions)
CREATE TABLE IF NOT EXISTS public.qr_coupon_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.ban_sessions(id) ON DELETE CASCADE,
  settlement_id uuid NOT NULL REFERENCES public.payment_settlements(id) ON DELETE CASCADE,
  coupon_id uuid,
  coupon_code text NOT NULL,
  discount_amount numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_qr_coupon_redemptions_settlement UNIQUE (settlement_id)
);

CREATE INDEX IF NOT EXISTS idx_qr_coupon_redemptions_store ON public.qr_coupon_redemptions(store_id);
CREATE INDEX IF NOT EXISTS idx_qr_coupon_redemptions_sess ON public.qr_coupon_redemptions(session_id);
CREATE INDEX IF NOT EXISTS idx_qr_coupon_redemptions_settle ON public.qr_coupon_redemptions(settlement_id);


-- ── 2. ROW LEVEL SECURITY (RLS) POLICIES ─────────────────────────────────────
ALTER TABLE public.qr_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_handoff_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_topping_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_payment_idempotency ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_kitchen_idempotency ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ban_session_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ban_session_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_coupon_redemptions ENABLE ROW LEVEL SECURITY;

-- Channels
DROP POLICY IF EXISTS qr_channels_select_policy ON public.qr_channels;
CREATE POLICY qr_channels_select_policy ON public.qr_channels
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_members sm
      WHERE sm.store_id = qr_channels.store_id
        AND sm.user_id = auth.uid()
    )
  );

-- Requests
DROP POLICY IF EXISTS qr_requests_staff_select_policy ON public.qr_requests;
CREATE POLICY qr_requests_staff_select_policy ON public.qr_requests
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_members sm
      WHERE sm.store_id = qr_requests.store_id
        AND sm.user_id = auth.uid()
    )
  );

-- Request items
DROP POLICY IF EXISTS qr_request_items_staff_select_policy ON public.qr_request_items;
CREATE POLICY qr_request_items_staff_select_policy ON public.qr_request_items
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.qr_requests qr
      JOIN public.store_members sm ON sm.store_id = qr.store_id
      WHERE qr.id = qr_request_items.request_id
        AND sm.user_id = auth.uid()
    )
  );

-- Audit logs
DROP POLICY IF EXISTS qr_audit_logs_staff_select_policy ON public.qr_audit_logs;
CREATE POLICY qr_audit_logs_staff_select_policy ON public.qr_audit_logs
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_members sm
      WHERE sm.store_id = qr_audit_logs.store_id
        AND sm.user_id = auth.uid()
    )
  );

-- Product Topping Links
DROP POLICY IF EXISTS product_topping_links_select_policy ON public.product_topping_links;
CREATE POLICY product_topping_links_select_policy ON public.product_topping_links
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_members sm
      WHERE sm.store_id = product_topping_links.store_id
        AND sm.user_id = auth.uid()
    )
  );

-- QR Payment Idempotency
DROP POLICY IF EXISTS qr_payment_idemp_select_policy ON public.qr_payment_idempotency;
CREATE POLICY qr_payment_idemp_select_policy ON public.qr_payment_idempotency
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_members sm
      WHERE sm.store_id = qr_payment_idempotency.store_id
        AND sm.user_id = auth.uid()
    )
  );

-- QR Kitchen Idempotency
DROP POLICY IF EXISTS qr_kitchen_idemp_select_policy ON public.qr_kitchen_idempotency;
CREATE POLICY qr_kitchen_idemp_select_policy ON public.qr_kitchen_idempotency
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_members sm
      WHERE sm.store_id = qr_kitchen_idempotency.store_id
        AND sm.user_id = auth.uid()
    )
  );

-- Ban Session Orders
DROP POLICY IF EXISTS ban_session_orders_select_policy ON public.ban_session_orders;
CREATE POLICY ban_session_orders_select_policy ON public.ban_session_orders
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_members sm
      WHERE sm.store_id = ban_session_orders.store_id
        AND sm.user_id = auth.uid()
    )
  );

-- Ban Session Order Items
DROP POLICY IF EXISTS ban_session_order_items_select_policy ON public.ban_session_order_items;
CREATE POLICY ban_session_order_items_select_policy ON public.ban_session_order_items
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_members sm
      WHERE sm.store_id = ban_session_order_items.store_id
        AND sm.user_id = auth.uid()
    )
  );

-- Payment Settlements
DROP POLICY IF EXISTS payment_settlements_select_policy ON public.payment_settlements;
CREATE POLICY payment_settlements_select_policy ON public.payment_settlements
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_members sm
      WHERE sm.store_id = payment_settlements.store_id
        AND sm.user_id = auth.uid()
    )
  );

-- Coupon Redemptions
DROP POLICY IF EXISTS qr_coupon_redemptions_select_policy ON public.qr_coupon_redemptions;
CREATE POLICY qr_coupon_redemptions_select_policy ON public.qr_coupon_redemptions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.store_members sm
      WHERE sm.store_id = qr_coupon_redemptions.store_id
        AND sm.user_id = auth.uid()
    )
  );


-- ── 3. HELPER: XÁC THỰC PHÂN QUYỀN NHÂN VIÊN (100% FAIL-CLOSED) ───────────────
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
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_uid uuid;
  v_sm_id uuid;
  v_role text;
  v_is_owner boolean;
  v_perms_val text;
  v_perms_json jsonb;
  v_has_checkout boolean := false;
  v_has_manage boolean := false;
BEGIN
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
    RAISE EXCEPTION 'PERMISSION_DENIED: auth.uid is null' USING ERRCODE = '42501';
  END IF;

  IF p_store_id IS NULL THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: store_id is required' USING ERRCODE = '42501';
  END IF;

  SELECT sm.id, sm.role, COALESCE(sm.is_owner, false)
  INTO v_sm_id, v_role, v_is_owner
  FROM public.store_members sm
  WHERE sm.store_id = p_store_id AND sm.user_id = v_uid
  LIMIT 1;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: not a member of this store' USING ERRCODE = '42501';
  END IF;

  -- 1. Chủ quán (owner) luôn có toàn quyền
  IF v_is_owner OR v_role = 'owner' THEN
    member_user_id := v_uid;
    member_role := v_role;
    store_member_id := v_sm_id;
    is_owner_member := true;
    RETURN NEXT;
    RETURN;
  END IF;

  -- 2. Kiểm tra quyền quản lý kênh (manage)
  IF p_require_manage THEN
    IF v_role IN ('manager', 'admin') THEN
      v_has_manage := true;
    END IF;

    IF NOT v_has_manage THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: manage channel permission required (owner or manager only)' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- 3. Kiểm tra quyền thanh toán (pos.checkout): 100% FAIL-CLOSED
  IF p_require_checkout THEN
    SELECT s.value INTO v_perms_val
    FROM public.app_settings s
    WHERE s.store_id = p_store_id AND s.key = 'action_perms_' || v_role
    LIMIT 1;

    IF v_perms_val IS NOT NULL AND trim(v_perms_val) <> '' THEN
      BEGIN
        v_perms_json := v_perms_val::jsonb;
        IF jsonb_typeof(v_perms_json) = 'array' THEN
          SELECT EXISTS (
            SELECT 1 FROM jsonb_array_elements_text(v_perms_json) elem
            WHERE elem = 'pos.checkout'
          ) INTO v_has_checkout;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        v_has_checkout := false;
      END;
    END IF;

    IF NOT v_has_checkout THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: pos.checkout permission required' USING ERRCODE = '42501';
    END IF;
  END IF;

  member_user_id := v_uid;
  member_role := v_role;
  store_member_id := v_sm_id;
  is_owner_member := false;
  RETURN NEXT;
END;
$$;


-- ── 4. RPC PUBLIC 1: GET CHANNEL INFO ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_qr_channel_info_v4(
  p_channel_code text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_channel record;
  v_store record;
BEGIN
  SELECT * INTO v_channel
  FROM public.qr_channels
  WHERE channel_code = p_channel_code AND is_active = true
  LIMIT 1;

  IF v_channel IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'CHANNEL_DISABLED',
      'message', 'Kênh gọi món này hiện đang tạm đóng hoặc không tồn tại'
    );
  END IF;

  SELECT name INTO v_store FROM public.stores WHERE id = v_channel.store_id;

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'id', v_channel.id,
      'channel_id', v_channel.id,
      'store_id', v_channel.store_id,
      'store_name', COALESCE(v_store.name, 'Quán Nhỏ'),
      'type', v_channel.type,
      'channel_code', v_channel.channel_code,
      'name', v_channel.name,
      'payment_mode', v_channel.payment_mode,
      'is_active', v_channel.is_active,
      'created_at', v_channel.created_at
    )
  );
END;
$$;


-- ── 5. RPC PUBLIC 2: GET QR MENU & TOPPINGS ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_qr_menu_v4(
  p_channel_code text,
  p_category text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_channel record;
  v_store record;
  v_products jsonb;
  v_toppings jsonb;
  v_topping_links jsonb;
BEGIN
  SELECT * INTO v_channel
  FROM public.qr_channels
  WHERE channel_code = p_channel_code AND is_active = true
  LIMIT 1;

  IF v_channel IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'CHANNEL_DISABLED',
      'message', 'Kênh gọi món này hiện đang tạm đóng'
    );
  END IF;

  SELECT name INTO v_store FROM public.stores WHERE id = v_channel.store_id;

  -- 1. Lấy danh sách món chính
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'name', p.name,
      'category', p.category,
      'sell_price', p.sell_price,
      'image_url', p.image_url,
      'is_active', p.is_active
    ) ORDER BY p.category, p.name
  ), '[]'::jsonb) INTO v_products
  FROM public.products p
  WHERE p.store_id = v_channel.store_id
    AND p.is_active = true
    AND p.is_deleted = false
    AND COALESCE(p.is_topping, false) = false
    AND (p_category IS NULL OR p.category = p_category);

  -- 2. Lấy danh sách topping hợp lệ
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'name', p.name,
      'sell_price', p.sell_price,
      'unit', p.unit,
      'topping_unit', p.topping_unit,
      'is_active', p.is_active
    ) ORDER BY p.name
  ), '[]'::jsonb) INTO v_toppings
  FROM public.products p
  WHERE p.store_id = v_channel.store_id
    AND p.is_active = true
    AND p.is_deleted = false
    AND p.is_topping = true;

  -- 3. Lấy mapping món chính ↔ topping
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'product_id', ptl.product_id,
      'topping_id', ptl.topping_id
    )
  ), '[]'::jsonb) INTO v_topping_links
  FROM public.product_topping_links ptl
  WHERE ptl.store_id = v_channel.store_id;

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'store_id', v_channel.store_id,
      'store_name', COALESCE(v_store.name, 'Quán Nhỏ'),
      'channel_type', v_channel.type,
      'channel_code', v_channel.channel_code,
      'payment_mode', v_channel.payment_mode,
      'products', v_products,
      'toppings', v_toppings,
      'topping_links', v_topping_links
    )
  );
END;
$$;


-- ── 6. RPC PUBLIC 3: SUBMIT ORDER (ATOMIC ADVISORY LOCK & SHA-256 VALIDATION) ──
CREATE OR REPLACE FUNCTION public.submit_qr_order_v4(
  p_channel_code text,
  p_items jsonb,
  p_table_hint text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL,
  p_payload_hash text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_channel record;
  v_req_id uuid;
  v_tracking_token text;
  v_raw_handoff_token text;
  v_token_hash text;
  v_pickup_code text := NULL;
  v_pickup_num integer;
  v_total_amount numeric := 0;
  v_item jsonb;
  v_mod jsonb;
  v_prod record;
  v_topping_prod record;
  v_item_subtotal numeric;
  v_item_unit_price numeric;
  v_toppings_total numeric;
  v_existing_req record;
  v_clean_items jsonb := '[]'::jsonb;
  v_item_mods jsonb;
  v_seen_toppings uuid[];
  v_item_qty integer;
  v_top_qty integer;
  v_mod_id uuid;
BEGIN
  -- Bắt buộc idempotency key
  IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_PAYLOAD',
      'message', 'Idempotency key là bắt buộc'
    );
  END IF;

  -- Bắt buộc payload hash đúng định dạng SHA-256 hex 64 ký tự
  IF p_payload_hash IS NULL OR trim(p_payload_hash) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_PAYLOAD',
      'message', 'Payload hash SHA-256 là bắt buộc'
    );
  END IF;

  p_payload_hash := lower(trim(p_payload_hash));

  IF NOT (p_payload_hash ~ '^[0-9a-f]{64}$') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_PAYLOAD',
      'message', 'Payload hash không đúng định dạng SHA-256 hex (64 ký tự 0-9, a-f)'
    );
  END IF;

  SELECT * INTO v_channel
  FROM public.qr_channels
  WHERE channel_code = p_channel_code AND is_active = true
  LIMIT 1;

  IF v_channel IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'CHANNEL_DISABLED',
      'message', 'Kênh gọi món này hiện đang tạm đóng'
    );
  END IF;

  -- 1. ATOMIC ADVISORY LOCK TRÊN IDEMPOTENCY KEY TRƯỚC MỌI SIDE EFFECT
  PERFORM pg_advisory_xact_lock(hashtext(v_channel.store_id::text), hashtext('submit_qr:' || p_idempotency_key));

  -- 2. Idempotency Pre-Check: Tìm request đã tồn tại theo (store_id, idempotency_key)
  SELECT * INTO v_existing_req
  FROM public.qr_requests
  WHERE store_id = v_channel.store_id AND idempotency_key = p_idempotency_key
  FOR UPDATE;

  IF v_existing_req IS NOT NULL THEN
    IF v_existing_req.payload_hash IS NOT NULL AND v_existing_req.payload_hash <> p_payload_hash THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'IDEMPOTENCY_CONFLICT',
        'message', 'Yêu cầu bị trùng lặp với nội dung khác'
      );
    END IF;

    -- Xoay vòng handoff token an toàn: vô hiệu hóa toàn bộ token cũ và tạo token mới
    UPDATE public.qr_handoff_tokens
    SET status = 'expired', consumed_at = now()
    WHERE request_id = v_existing_req.id AND status = 'active';

    v_raw_handoff_token := 'QRN_' || upper(encode(gen_random_bytes(16), 'hex'));
    v_token_hash := encode(digest(v_raw_handoff_token, 'sha256'), 'hex');

    INSERT INTO public.qr_handoff_tokens (id, store_id, request_id, token_hash, status, expires_at)
    VALUES (gen_random_uuid(), v_channel.store_id, v_existing_req.id, v_token_hash, 'active', now() + interval '30 minutes');

    RETURN jsonb_build_object(
      'success', true,
      'data', jsonb_build_object(
        'request_id', v_existing_req.id,
        'tracking_token', v_existing_req.tracking_token,
        'raw_handoff_token', v_raw_handoff_token,
        'pickup_code', v_existing_req.pickup_code,
        'total_amount', v_existing_req.total_amount,
        'status', v_existing_req.status,
        'is_replay', true
      )
    );
  END IF;

  -- 3. Validate Items & Authoritative Pricing
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_PAYLOAD',
      'message', 'Đơn hàng phải có ít nhất một món'
    );
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    BEGIN
      v_item_qty := (v_item->>'quantity')::integer;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'INVALID_PAYLOAD',
        'message', 'Số lượng món không hợp lệ'
      );
    END;

    IF v_item_qty IS NULL OR v_item_qty < 1 OR v_item_qty > 100 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'INVALID_PAYLOAD',
        'message', 'Số lượng món phải từ 1 đến 100'
      );
    END IF;

    SELECT * INTO v_prod
    FROM public.products
    WHERE id = (v_item->>'product_id')::uuid
      AND store_id = v_channel.store_id
      AND is_active = true
      AND is_deleted = false
      AND COALESCE(is_topping, false) = false;

    IF v_prod IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'PRODUCT_NOT_AVAILABLE',
        'message', 'Món ăn không tồn tại hoặc đã ngừng phục vụ: ' || COALESCE(v_item->>'product_name', '')
      );
    END IF;

    v_toppings_total := 0;
    v_item_mods := '[]'::jsonb;
    v_seen_toppings := ARRAY[]::uuid[];

    IF v_item ? 'modifiers_json' AND jsonb_typeof(v_item->'modifiers_json') = 'array' AND jsonb_array_length(v_item->'modifiers_json') > 0 THEN
      FOR v_mod IN SELECT * FROM jsonb_array_elements(v_item->'modifiers_json')
      LOOP
        BEGIN
          v_mod_id := (v_mod->>'id')::uuid;
          v_top_qty := COALESCE((v_mod->>'quantity')::integer, 1);
        EXCEPTION WHEN OTHERS THEN
          RETURN jsonb_build_object(
            'success', false,
            'error_code', 'INVALID_PAYLOAD',
            'message', 'Topping không đúng định dạng UUID hoặc số lượng không hợp lệ'
          );
        END;

        IF v_top_qty < 1 OR v_top_qty > 20 THEN
          RETURN jsonb_build_object(
            'success', false,
            'error_code', 'INVALID_PAYLOAD',
            'message', 'Số lượng topping phải từ 1 đến 20'
          );
        END IF;

        IF v_mod_id = ANY(v_seen_toppings) THEN
          RETURN jsonb_build_object(
            'success', false,
            'error_code', 'INVALID_PAYLOAD',
            'message', 'Topping bị lặp lại trong cùng một món ăn'
          );
        END IF;
        v_seen_toppings := array_append(v_seen_toppings, v_mod_id);

        SELECT * INTO v_topping_prod
        FROM public.products
        WHERE id = v_mod_id
          AND store_id = v_channel.store_id
          AND is_active = true
          AND is_deleted = false
          AND is_topping = true;

        IF v_topping_prod IS NULL THEN
          RETURN jsonb_build_object(
            'success', false,
            'error_code', 'PRODUCT_NOT_AVAILABLE',
            'message', 'Topping không hợp lệ hoặc đã ngừng phục vụ'
          );
        END IF;

        IF NOT EXISTS (
          SELECT 1 FROM public.product_topping_links
          WHERE store_id = v_channel.store_id
            AND product_id = v_prod.id
            AND topping_id = v_topping_prod.id
        ) THEN
          RETURN jsonb_build_object(
            'success', false,
            'error_code', 'PRODUCT_NOT_AVAILABLE',
            'message', 'Topping ' || v_topping_prod.name || ' không áp dụng cho món ' || v_prod.name
          );
        END IF;

        v_toppings_total := v_toppings_total + (v_topping_prod.sell_price * v_top_qty);
        v_item_mods := v_item_mods || jsonb_build_object(
          'id', v_topping_prod.id,
          'name', v_topping_prod.name,
          'price', v_topping_prod.sell_price,
          'quantity', v_top_qty
        );
      END LOOP;
    END IF;

    v_item_unit_price := v_prod.sell_price + v_toppings_total;
    v_item_subtotal := v_item_unit_price * v_item_qty;
    v_total_amount := v_total_amount + v_item_subtotal;

    v_clean_items := v_clean_items || jsonb_build_object(
      'product_id', v_prod.id,
      'product_name', v_prod.name,
      'unit_price', v_item_unit_price,
      'quantity', v_item_qty,
      'subtotal', v_item_subtotal,
      'modifiers_json', v_item_mods,
      'note', COALESCE(v_item->>'note', '')
    );
  END LOOP;

  -- 4. Sinh mã nhận món nếu là COUNTER_TAKEAWAY
  IF v_channel.type IN ('COUNTER_TAKEAWAY', 'counter') THEN
    UPDATE public.qr_channels
    SET pickup_counter = (pickup_counter % 99) + 1
    WHERE id = v_channel.id
    RETURNING pickup_counter INTO v_pickup_num;

    v_pickup_code := '#Q' || lpad(v_pickup_num::text, 2, '0');
  END IF;

  -- 5. Tạo token ngẫu nhiên CSPRNG
  v_req_id := gen_random_uuid();
  v_tracking_token := 'TRK_' || upper(encode(gen_random_bytes(16), 'hex'));
  v_raw_handoff_token := 'QRN_' || upper(encode(gen_random_bytes(16), 'hex'));
  v_token_hash := encode(digest(v_raw_handoff_token, 'sha256'), 'hex');

  -- 6. Insert qr_requests
  INSERT INTO public.qr_requests (
    id, store_id, channel_id, type, table_hint, pickup_code,
    tracking_token, idempotency_key, payload_hash, status, payment_status,
    total_amount, expires_at
  ) VALUES (
    v_req_id, v_channel.store_id, v_channel.id, v_channel.type, p_table_hint, v_pickup_code,
    v_tracking_token, p_idempotency_key, p_payload_hash, 'customer_submitted', 'unpaid',
    v_total_amount, now() + interval '30 minutes'
  );

  -- 7. Insert items & handoff token
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_clean_items)
  LOOP
    INSERT INTO public.qr_request_items (
      request_id, product_id, product_name, unit_price, quantity, subtotal, modifiers_json, note
    ) VALUES (
      v_req_id, (v_item->>'product_id')::uuid, v_item->>'product_name',
      (v_item->>'unit_price')::numeric, (v_item->>'quantity')::integer,
      (v_item->>'subtotal')::numeric, v_item->'modifiers_json', v_item->>'note'
    );
  END LOOP;

  INSERT INTO public.qr_handoff_tokens (
    id, store_id, request_id, token_hash, status, expires_at
  ) VALUES (
    gen_random_uuid(), v_channel.store_id, v_req_id, v_token_hash, 'active', now() + interval '30 minutes'
  );

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'request_id', v_req_id,
      'tracking_token', v_tracking_token,
      'raw_handoff_token', v_raw_handoff_token,
      'pickup_code', v_pickup_code,
      'total_amount', v_total_amount,
      'status', 'customer_submitted',
      'is_replay', false
    )
  );
END;
$$;


-- ── 7. RPC PUBLIC 4: GET REQUEST STATUS ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_qr_request_status_v4(
  p_tracking_token text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_req record;
  v_items jsonb;
  v_table_label text := NULL;
BEGIN
  SELECT * INTO v_req
  FROM public.qr_requests
  WHERE tracking_token = p_tracking_token
  LIMIT 1;

  IF v_req IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_STATE',
      'message', 'Không tìm thấy đơn hàng'
    );
  END IF;

  IF v_req.expires_at < now() AND v_req.status = 'customer_submitted' THEN
    UPDATE public.qr_requests SET status = 'expired' WHERE id = v_req.id;
    v_req.status := 'expired';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'product_id', product_id,
      'product_name', product_name,
      'unit_price', unit_price,
      'quantity', quantity,
      'subtotal', subtotal,
      'modifiers_json', modifiers_json,
      'note', note
    ) ORDER BY created_at
  ), '[]'::jsonb) INTO v_items
  FROM public.qr_request_items
  WHERE request_id = v_req.id;

  IF v_req.assigned_table_id IS NOT NULL THEN
    SELECT label INTO v_table_label
    FROM public.ban_dining_tables
    WHERE id = v_req.assigned_table_id AND store_id = v_req.store_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'id', v_req.id,
      'store_id', v_req.store_id,
      'channel_id', v_req.channel_id,
      'type', v_req.type,
      'status', v_req.status,
      'payment_status', v_req.payment_status,
      'payment_mode', (SELECT qc.payment_mode FROM public.qr_channels qc WHERE qc.id = v_req.channel_id),
      'pickup_code', v_req.pickup_code,
      'table_hint', v_req.table_hint,
      'assigned_table_id', v_req.assigned_table_id,
      'assigned_table_name', v_table_label,
      'assigned_session_id', v_req.assigned_session_id,
      'tracking_token', v_req.tracking_token,
      'customer_note', v_req.customer_note,
      'total_amount', v_req.total_amount,
      'version', v_req.version,
      'reject_reason', v_req.reject_reason,
      'created_at', v_req.created_at,
      'expires_at', v_req.expires_at,
      'items', v_items
    )
  );
END;
$$;


-- ── 8. RPC PUBLIC 5: REGENERATE HANDOFF TOKEN ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.regenerate_handoff_token_v4(
  p_tracking_token text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_req record;
  v_raw_token text;
  v_hash text;
BEGIN
  SELECT * INTO v_req
  FROM public.qr_requests
  WHERE tracking_token = p_tracking_token
  FOR UPDATE;

  IF v_req IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy đơn hàng');
  END IF;

  IF v_req.status NOT IN ('customer_submitted', 'pending_staff') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Đơn hàng đã được nhân viên tiếp nhận hoặc đã hoàn tất');
  END IF;

  UPDATE public.qr_handoff_tokens
  SET status = 'expired', consumed_at = now()
  WHERE request_id = v_req.id AND status = 'active';

  v_raw_token := 'QRN_' || upper(encode(gen_random_bytes(16), 'hex'));
  v_hash := encode(digest(v_raw_token, 'sha256'), 'hex');

  INSERT INTO public.qr_handoff_tokens (id, store_id, request_id, token_hash, status, expires_at)
  VALUES (gen_random_uuid(), v_req.store_id, v_req.id, v_hash, 'active', now() + interval '30 minutes');

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'raw_handoff_token', v_raw_token,
      'expires_at', now() + interval '30 minutes'
    )
  );
END;
$$;


-- ── 9. RPC STAFF 6: CLAIM HANDOFF TOKEN (ATOMIC SINGLE-USE) ───────────────────
CREATE OR REPLACE FUNCTION public.claim_qr_handoff_v4(
  p_token text,
  p_store_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_staff record;
  v_hash text;
  v_token_rec record;
  v_req record;
  v_items jsonb;
  v_table_label text := NULL;
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id);

  IF p_token IS NULL OR trim(p_token) = '' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_QR', 'message', 'Mã QR không hợp lệ');
  END IF;

  v_hash := encode(digest(p_token, 'sha256'), 'hex');

  -- Transaction-scoped advisory lock theo token hash
  PERFORM pg_advisory_xact_lock(hashtext(p_store_id::text), hashtext('claim_token:' || v_hash));

  SELECT * INTO v_token_rec
  FROM public.qr_handoff_tokens
  WHERE token_hash = v_hash
  FOR UPDATE;

  IF v_token_rec IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_QR', 'message', 'Mã QR không tồn tại hoặc không hợp lệ');
  END IF;

  IF v_token_rec.store_id <> p_store_id THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'WRONG_STORE', 'message', 'Mã QR này thuộc cửa hàng khác');
  END IF;

  IF v_token_rec.status = 'consumed' OR v_token_rec.consumed_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'TOKEN_ALREADY_USED', 'message', 'Mã QR này đã được tiếp nhận trước đó');
  END IF;

  IF v_token_rec.expires_at < now() OR v_token_rec.status = 'expired' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'REQUEST_EXPIRED', 'message', 'Mã QR đã hết hạn');
  END IF;

  SELECT * INTO v_req
  FROM public.qr_requests
  WHERE id = v_token_rec.request_id
  FOR UPDATE;

  IF v_req.status IN ('claimed', 'staff_review', 'confirmed', 'ready_for_kitchen', 'sent_kitchen', 'completed') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'ALREADY_CLAIMED', 'message', 'Đơn hàng này đã được nhân viên tiếp nhận');
  END IF;

  IF v_req.status IN ('cancelled', 'rejected', 'expired') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Đơn hàng đã bị hủy hoặc hết hạn');
  END IF;

  UPDATE public.qr_handoff_tokens
  SET status = 'consumed',
      consumed_at = now(),
      consumed_by_user_id = v_staff.member_user_id
  WHERE id = v_token_rec.id;

  UPDATE public.qr_requests
  SET status = 'claimed',
      claimed_by_user_id = v_staff.member_user_id,
      claimed_at = now(),
      version = version + 1
  WHERE id = v_req.id;

  INSERT INTO public.qr_audit_logs (
    store_id, request_id, action, actor_user_id, details
  ) VALUES (
    p_store_id, v_req.id, 'claim_handoff', v_staff.member_user_id,
    jsonb_build_object('token_hash', v_hash)
  );

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'product_id', product_id,
      'product_name', product_name,
      'unit_price', unit_price,
      'quantity', quantity,
      'subtotal', subtotal,
      'modifiers_json', modifiers_json,
      'note', note
    ) ORDER BY created_at
  ), '[]'::jsonb) INTO v_items
  FROM public.qr_request_items
  WHERE request_id = v_req.id;

  IF v_req.assigned_table_id IS NOT NULL THEN
    SELECT label INTO v_table_label
    FROM public.ban_dining_tables
    WHERE id = v_req.assigned_table_id AND store_id = v_req.store_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'request_id', v_req.id,
      'store_id', v_req.store_id,
      'channel_id', v_req.channel_id,
      'type', v_req.type,
      'table_hint', v_req.table_hint,
      'assigned_table_id', v_req.assigned_table_id,
      'assigned_table_name', v_table_label,
      'assigned_session_id', v_req.assigned_session_id,
      'pickup_code', v_req.pickup_code,
      'tracking_token', v_req.tracking_token,
      'status', 'claimed',
      'payment_status', v_req.payment_status,
      'payment_mode', (SELECT qc.payment_mode FROM public.qr_channels qc WHERE qc.id = v_req.channel_id),
      'customer_note', v_req.customer_note,
      'total_amount', v_req.total_amount,
      'version', v_req.version + 1,
      'created_at', v_req.created_at,
      'expires_at', v_req.expires_at,
      'items', v_items
    )
  );
END;
$$;


-- ── 10. RPC STAFF 7: GET REQUEST DETAIL ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_qr_request_detail_v4(
  p_request_id uuid,
  p_store_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_staff record;
  v_req record;
  v_items jsonb;
  v_table_label text := NULL;
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id);

  SELECT * INTO v_req
  FROM public.qr_requests
  WHERE id = p_request_id AND store_id = p_store_id;

  IF v_req IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy đơn hàng');
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'product_id', product_id,
      'product_name', product_name,
      'unit_price', unit_price,
      'quantity', quantity,
      'subtotal', subtotal,
      'modifiers_json', modifiers_json,
      'note', note
    ) ORDER BY created_at
  ), '[]'::jsonb) INTO v_items
  FROM public.qr_request_items
  WHERE request_id = v_req.id;

  IF v_req.assigned_table_id IS NOT NULL THEN
    SELECT label INTO v_table_label
    FROM public.ban_dining_tables
    WHERE id = v_req.assigned_table_id AND store_id = v_req.store_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'id', v_req.id,
      'store_id', v_req.store_id,
      'channel_id', v_req.channel_id,
      'type', v_req.type,
      'table_hint', v_req.table_hint,
      'assigned_table_id', v_req.assigned_table_id,
      'assigned_table_name', v_table_label,
      'assigned_session_id', v_req.assigned_session_id,
      'pickup_code', v_req.pickup_code,
      'tracking_token', v_req.tracking_token,
      'status', v_req.status,
      'payment_status', v_req.payment_status,
      'payment_mode', (SELECT qc.payment_mode FROM public.qr_channels qc WHERE qc.id = v_req.channel_id),
      'customer_note', v_req.customer_note,
      'total_amount', v_req.total_amount,
      'version', v_req.version,
      'created_at', v_req.created_at,
      'expires_at', v_req.expires_at,
      'items', v_items
    )
  );
END;
$$;


-- ── 11. RPC STAFF 8: UPDATE ORDER ITEMS (OPTIMISTIC LOCK & TOPPING VALIDATION) ─
CREATE OR REPLACE FUNCTION public.update_qr_order_items_v4(
  p_request_id uuid,
  p_store_id uuid,
  p_expected_version integer,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_staff record;
  v_req record;
  v_item jsonb;
  v_mod jsonb;
  v_prod record;
  v_topping_prod record;
  v_item_subtotal numeric;
  v_item_unit_price numeric;
  v_toppings_total numeric;
  v_total_amount numeric := 0;
  v_clean_items jsonb := '[]'::jsonb;
  v_item_mods jsonb;
  v_seen_toppings uuid[];
  v_item_qty integer;
  v_top_qty integer;
  v_mod_id uuid;
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id);

  SELECT * INTO v_req
  FROM public.qr_requests
  WHERE id = p_request_id AND store_id = p_store_id
  FOR UPDATE;

  IF v_req IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_STATE',
      'message', 'Không tìm thấy đơn hàng'
    );
  END IF;

  IF v_req.version <> p_expected_version THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'VERSION_CONFLICT',
      'message', 'Đơn hàng đã được cập nhật từ thiết bị khác. Vui lòng tải lại.'
    );
  END IF;

  IF v_req.status IN ('sent_kitchen', 'completed', 'cancelled', 'rejected') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_STATE',
      'message', 'Đơn hàng đã gửi bếp hoặc hoàn tất, không thể chỉnh sửa'
    );
  END IF;

  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_PAYLOAD',
      'message', 'Đơn hàng phải có ít nhất một món'
    );
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    BEGIN
      v_item_qty := (v_item->>'quantity')::integer;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'INVALID_PAYLOAD',
        'message', 'Số lượng món không hợp lệ'
      );
    END;

    IF v_item_qty IS NULL OR v_item_qty < 1 OR v_item_qty > 100 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'INVALID_PAYLOAD',
        'message', 'Số lượng món phải từ 1 đến 100'
      );
    END IF;

    SELECT * INTO v_prod
    FROM public.products
    WHERE id = (v_item->>'product_id')::uuid
      AND store_id = p_store_id
      AND is_active = true
      AND is_deleted = false
      AND COALESCE(is_topping, false) = false;

    IF v_prod IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'PRODUCT_NOT_AVAILABLE',
        'message', 'Món ăn không tồn tại hoặc đã ngừng phục vụ'
      );
    END IF;

    v_toppings_total := 0;
    v_item_mods := '[]'::jsonb;
    v_seen_toppings := ARRAY[]::uuid[];

    IF v_item ? 'modifiers_json' AND jsonb_typeof(v_item->'modifiers_json') = 'array' AND jsonb_array_length(v_item->'modifiers_json') > 0 THEN
      FOR v_mod IN SELECT * FROM jsonb_array_elements(v_item->'modifiers_json')
      LOOP
        BEGIN
          v_mod_id := (v_mod->>'id')::uuid;
          v_top_qty := COALESCE((v_mod->>'quantity')::integer, 1);
        EXCEPTION WHEN OTHERS THEN
          RETURN jsonb_build_object(
            'success', false,
            'error_code', 'INVALID_PAYLOAD',
            'message', 'Topping không đúng định dạng UUID hoặc số lượng không hợp lệ'
          );
        END;

        IF v_top_qty < 1 OR v_top_qty > 20 THEN
          RETURN jsonb_build_object(
            'success', false,
            'error_code', 'INVALID_PAYLOAD',
            'message', 'Số lượng topping phải từ 1 đến 20'
          );
        END IF;

        IF v_mod_id = ANY(v_seen_toppings) THEN
          RETURN jsonb_build_object(
            'success', false,
            'error_code', 'INVALID_PAYLOAD',
            'message', 'Topping bị lặp lại trong cùng một món ăn'
          );
        END IF;
        v_seen_toppings := array_append(v_seen_toppings, v_mod_id);

        SELECT * INTO v_topping_prod
        FROM public.products
        WHERE id = v_mod_id
          AND store_id = p_store_id
          AND is_active = true
          AND is_deleted = false
          AND is_topping = true;

        IF v_topping_prod IS NULL THEN
          RETURN jsonb_build_object(
            'success', false,
            'error_code', 'PRODUCT_NOT_AVAILABLE',
            'message', 'Topping không hợp lệ hoặc đã ngừng phục vụ'
          );
        END IF;

        IF NOT EXISTS (
          SELECT 1 FROM public.product_topping_links
          WHERE store_id = p_store_id
            AND product_id = v_prod.id
            AND topping_id = v_topping_prod.id
        ) THEN
          RETURN jsonb_build_object(
            'success', false,
            'error_code', 'PRODUCT_NOT_AVAILABLE',
            'message', 'Topping ' || v_topping_prod.name || ' không áp dụng cho món ' || v_prod.name
          );
        END IF;

        v_toppings_total := v_toppings_total + (v_topping_prod.sell_price * v_top_qty);
        v_item_mods := v_item_mods || jsonb_build_object(
          'id', v_topping_prod.id,
          'name', v_topping_prod.name,
          'price', v_topping_prod.sell_price,
          'quantity', v_top_qty
        );
      END LOOP;
    END IF;

    v_item_unit_price := v_prod.sell_price + v_toppings_total;
    v_item_subtotal := v_item_unit_price * v_item_qty;
    v_total_amount := v_total_amount + v_item_subtotal;

    v_clean_items := v_clean_items || jsonb_build_object(
      'product_id', v_prod.id,
      'product_name', v_prod.name,
      'unit_price', v_item_unit_price,
      'quantity', v_item_qty,
      'subtotal', v_item_subtotal,
      'modifiers_json', v_item_mods,
      'note', COALESCE(v_item->>'note', '')
    );
  END LOOP;

  DELETE FROM public.qr_request_items WHERE request_id = v_req.id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_clean_items)
  LOOP
    INSERT INTO public.qr_request_items (
      request_id, product_id, product_name, unit_price, quantity, subtotal, modifiers_json, note
    ) VALUES (
      v_req.id, (v_item->>'product_id')::uuid, v_item->>'product_name',
      (v_item->>'unit_price')::numeric, (v_item->>'quantity')::integer,
      (v_item->>'subtotal')::numeric, v_item->'modifiers_json', v_item->>'note'
    );
  END LOOP;

  UPDATE public.qr_requests
  SET total_amount = v_total_amount,
      version = version + 1
  WHERE id = v_req.id;

  INSERT INTO public.qr_audit_logs (
    store_id, request_id, action, actor_user_id, details
  ) VALUES (
    p_store_id, v_req.id, 'update_items', v_staff.member_user_id,
    jsonb_build_object('total_amount', v_total_amount, 'items_count', jsonb_array_length(v_clean_items))
  );

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'request_id', v_req.id,
      'total_amount', v_total_amount,
      'version', v_req.version + 1,
      'items', v_clean_items
    )
  );
END;
$$;


-- ── 12. RPC STAFF 9: ASSIGN TABLE ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.assign_qr_order_table_v4(
  p_request_id uuid,
  p_table_id uuid,
  p_store_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_staff record;
  v_req record;
  v_table record;
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id);

  SELECT r.*, c.type AS channel_type INTO v_req
  FROM public.qr_requests r
  JOIN public.qr_channels c
    ON c.id = r.channel_id
   AND c.store_id = r.store_id
  WHERE r.id = p_request_id AND r.store_id = p_store_id
  FOR UPDATE OF r;

  IF v_req IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy đơn');
  END IF;

  -- Gán bàn chỉ thuộc luồng TABLE_SHARED. COUNTER_TAKEAWAY tuyệt đối không
  -- được biến thành đơn tại bàn bằng cách gọi RPC trực tiếp.
  IF v_req.channel_type NOT IN ('TABLE_SHARED', 'table') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_STATE',
      'message', 'Đơn mang đi không được gán bàn'
    );
  END IF;

  -- Chỉ đúng nhân viên đã claim QR động mới được xác nhận bàn, và chỉ trong
  -- giai đoạn review trước khi gửi bếp.
  IF v_req.claimed_by_user_id IS DISTINCT FROM v_staff.member_user_id
     OR v_req.status NOT IN ('claimed', 'staff_review', 'confirmed') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_STATE',
      'message', 'Đơn chưa được nhân viên này tiếp nhận hoặc không còn cho phép gán bàn'
    );
  END IF;

  SELECT * INTO v_table
  FROM public.ban_dining_tables
  WHERE id = p_table_id AND store_id = p_store_id;

  IF v_table IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'TABLE_NOT_FOUND', 'message', 'Bàn không tồn tại');
  END IF;

  -- Double tap/retry cùng bàn là replay an toàn: không tăng version và không
  -- ghi thêm audit log.
  IF v_req.assigned_table_id = p_table_id THEN
    RETURN jsonb_build_object(
      'success', true,
      'data', jsonb_build_object(
        'request_id', v_req.id,
        'assigned_table_id', p_table_id,
        'assigned_table_name', v_table.label,
        'version', v_req.version,
        'is_replay', true
      )
    );
  END IF;

  UPDATE public.qr_requests
  SET assigned_table_id = p_table_id,
      version = version + 1
  WHERE id = v_req.id;

  INSERT INTO public.qr_audit_logs (
    store_id, request_id, action, actor_user_id, details
  ) VALUES (
    p_store_id, v_req.id, 'assign_table', v_staff.member_user_id,
    jsonb_build_object('table_id', p_table_id, 'table_label', v_table.label)
  );

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'request_id', v_req.id,
      'assigned_table_id', p_table_id,
      'assigned_table_name', v_table.label,
      'version', v_req.version + 1
    )
  );
END;
$$;


-- ── 13. RPC STAFF 10: MARK PAID (COUNTER_TAKEAWAY & ATOMIC ADVISORY LOCK) ─────
CREATE OR REPLACE FUNCTION public.mark_qr_order_paid_v4(
  p_request_id uuid,
  p_store_id uuid,
  p_payment_method text DEFAULT 'cash',
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_staff record;
  v_req record;
  v_order_id uuid;
  v_order_num text;
  v_item record;
  v_prod record;
  v_mod jsonb;
  v_fund_type text;
  v_staff_member_id uuid;
  v_user_name text;
  v_user_phone text;
  v_existing_idemp record;
  v_rec_ing record;
  v_actual_ing_qty numeric;
  v_has_recipe boolean;
BEGIN
  -- Bắt buộc quyền pos.checkout
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);

  IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_PAYLOAD',
      'message', 'Idempotency key là bắt buộc khi thực hiện thanh toán'
    );
  END IF;

  -- 1. ATOMIC ADVISORY LOCK TRÊN KEY TRƯỚC MỌI SIDE EFFECT
  PERFORM pg_advisory_xact_lock(hashtext(p_store_id::text), hashtext('mark_qr_paid:' || p_idempotency_key));

  SELECT * INTO v_req
  FROM public.qr_requests
  WHERE id = p_request_id AND store_id = p_store_id
  FOR UPDATE;

  IF v_req IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy đơn');
  END IF;

  IF v_req.type NOT IN ('COUNTER_TAKEAWAY', 'counter') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_STATE',
      'message', 'Chỉ đơn mang đi tại quầy mới thanh toán trực tiếp qua RPC này. Đơn tại bàn thanh toán khi trả bàn.'
    );
  END IF;

  -- 2. Idempotency Pre-Check (Zero Side Effects if conflict/replay)
  SELECT * INTO v_existing_idemp
  FROM public.qr_payment_idempotency
  WHERE store_id = p_store_id AND idempotency_key = p_idempotency_key
  LIMIT 1;

  IF v_existing_idemp IS NOT NULL THEN
    IF v_existing_idemp.request_id = v_req.id THEN
      RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
          'request_id', v_req.id,
          'order_id', v_existing_idemp.canonical_order_id,
          'order_number', v_existing_idemp.order_number,
          'payment_status', 'paid',
          'status', v_req.status,
          'is_replay', true
        )
      );
    ELSE
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'IDEMPOTENCY_CONFLICT',
        'message', 'Idempotency key đã được sử dụng cho giao dịch thanh toán khác'
      );
    END IF;
  END IF;

  SELECT * INTO v_existing_idemp
  FROM public.qr_payment_idempotency
  WHERE request_id = v_req.id
  LIMIT 1;

  IF v_existing_idemp IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'data', jsonb_build_object(
        'request_id', v_req.id,
        'order_id', v_existing_idemp.canonical_order_id,
        'order_number', v_existing_idemp.order_number,
        'payment_status', 'paid',
        'status', v_req.status,
        'is_replay', true
      )
    );
  END IF;

  -- 3. Resolve staff_members.id
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

  -- 4. Tạo canonical order trong bảng orders
  v_order_id := gen_random_uuid();
  v_order_num := 'QR' || to_char(now(), 'YYMMDD') || '-' || upper(encode(gen_random_bytes(3), 'hex'));

  INSERT INTO public.orders (
    id, store_id, order_number, subtotal, discount, tax, total, total_amount,
    payment_method, status, source_type, source_id, staff_id, receipt_printed, created_at, note
  ) VALUES (
    v_order_id, p_store_id, v_order_num, v_req.total_amount, 0, 0, v_req.total_amount, v_req.total_amount,
    p_payment_method, 'completed', 'qr_counter', v_req.id::text, v_staff_member_id, false, now(),
    'Đơn QR Quầy Mang Đi ' || COALESCE(v_req.pickup_code, '')
  );

  -- 5. Ghi order_items và trừ kho/recipe linh hoạt
  FOR v_item IN SELECT * FROM public.qr_request_items WHERE request_id = v_req.id
  LOOP
    SELECT cost_price_latest, stock_qty INTO v_prod FROM public.products WHERE id = v_item.product_id;

    INSERT INTO public.order_items (
      id, store_id, order_id, product_id, name, product_name, qty, quantity,
      unit_price, cost_price, subtotal, modifiers_json
    ) VALUES (
      gen_random_uuid(), p_store_id, v_order_id, v_item.product_id, v_item.product_name, v_item.product_name,
      v_item.quantity, v_item.quantity, v_item.unit_price, COALESCE(v_prod.cost_price_latest, 0),
      v_item.subtotal, v_item.modifiers_json
    );

    -- Dynamic check bảng recipes
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
          WHERE r.pos_product_id = $1 AND r.is_deleted = false
        )
      ' INTO v_has_recipe USING v_item.product_id;
    END IF;

    IF v_has_recipe THEN
      FOR v_rec_ing IN EXECUTE '
        SELECT ri.ingredient_id, ri.quantity, ri.yield_factor
        FROM public.recipes r
        JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
        WHERE r.pos_product_id = $1 AND r.is_deleted = false AND ri.ingredient_id IS NOT NULL
      ' USING v_item.product_id
      LOOP
        v_actual_ing_qty := (v_rec_ing.quantity / COALESCE(NULLIF(v_rec_ing.yield_factor, 0), 1.0)) * v_item.quantity;
        
        INSERT INTO public.stock_movements (
          id, store_id, product_id, delta, reason, reference_id, note, created_at
        ) VALUES (
          gen_random_uuid(), p_store_id, v_rec_ing.ingredient_id, -v_actual_ing_qty,
          'recipe_usage', v_order_id, 'Xuất kho công thức #' || v_order_num || ': ' || v_item.product_name, now()
        );

        UPDATE public.products
        SET stock_qty = COALESCE(stock_qty, 0) - v_actual_ing_qty,
            updated_at = extract(epoch from now()) * 1000
        WHERE id = v_rec_ing.ingredient_id AND store_id = p_store_id;
      END LOOP;
    ELSE
      INSERT INTO public.stock_movements (
        id, store_id, product_id, delta, reason, reference_id, note, created_at
      ) VALUES (
        gen_random_uuid(), p_store_id, v_item.product_id, -v_item.quantity,
        'sale', v_order_id, 'Bán hàng QR #' || v_order_num, now()
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
                WHERE r.pos_product_id = $1 AND r.is_deleted = false
              )
            ' INTO v_has_recipe USING (v_mod->>'id')::uuid;
          END IF;

          IF v_has_recipe THEN
            FOR v_rec_ing IN EXECUTE '
              SELECT ri.ingredient_id, ri.quantity, ri.yield_factor
              FROM public.recipes r
              JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
              WHERE r.pos_product_id = $1 AND r.is_deleted = false AND ri.ingredient_id IS NOT NULL
            ' USING (v_mod->>'id')::uuid
            LOOP
              v_actual_ing_qty := (v_rec_ing.quantity / COALESCE(NULLIF(v_rec_ing.yield_factor, 0), 1.0)) * ((COALESCE((v_mod->>'quantity')::numeric, 1)) * v_item.quantity);
              
              INSERT INTO public.stock_movements (
                id, store_id, product_id, delta, reason, reference_id, note, created_at
              ) VALUES (
                gen_random_uuid(), p_store_id, v_rec_ing.ingredient_id, -v_actual_ing_qty,
                'recipe_usage', v_order_id, 'Xuất kho topping công thức: ' || COALESCE(v_mod->>'name', 'Topping'), now()
              );

              UPDATE public.products
              SET stock_qty = COALESCE(stock_qty, 0) - v_actual_ing_qty,
                  updated_at = extract(epoch from now()) * 1000
              WHERE id = v_rec_ing.ingredient_id AND store_id = p_store_id;
            END LOOP;
          ELSE
            INSERT INTO public.stock_movements (
              id, store_id, product_id, delta, reason, reference_id, note, created_at
            ) VALUES (
              gen_random_uuid(), p_store_id, (v_mod->>'id')::uuid,
              -((COALESCE((v_mod->>'quantity')::numeric, 1)) * v_item.quantity),
              'sale', v_order_id, 'Bán topping QR #' || v_order_num, now()
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

  -- 6. Ghi finance_records
  v_fund_type := CASE WHEN p_payment_method IN ('transfer', 'card', 'bank') THEN 'bank' ELSE 'cash' END;

  INSERT INTO public.finance_records (
    id, store_id, type, amount, description, reference_id, is_auto, recorded_at, fund_type
  ) VALUES (
    gen_random_uuid(), p_store_id, 'income', v_req.total_amount,
    'Bán hàng mang đi #' || v_order_num || ' (' || COALESCE(v_req.pickup_code, 'QR') || ')',
    v_order_id, true, now(), v_fund_type
  );

  -- 7. Ghi bản ghi idempotency thanh toán
  INSERT INTO public.qr_payment_idempotency (
    id, store_id, request_id, idempotency_key, canonical_order_id, order_number, total_amount, payment_method, status
  ) VALUES (
    gen_random_uuid(), p_store_id, v_req.id, p_idempotency_key, v_order_id, v_order_num, v_req.total_amount, p_payment_method, 'completed'
  );

  -- 8. Cập nhật trạng thái qr_requests
  UPDATE public.qr_requests
  SET payment_status = 'paid',
      payment_method = p_payment_method,
      canonical_order_id = v_order_id,
      status = CASE WHEN status = 'sent_kitchen' THEN 'sent_kitchen' ELSE 'ready_for_kitchen' END,
      version = version + 1
  WHERE id = v_req.id;

  INSERT INTO public.qr_audit_logs (
    store_id, request_id, action, actor_user_id, details
  ) VALUES (
    p_store_id, v_req.id, 'mark_paid', v_staff.member_user_id,
    jsonb_build_object('order_id', v_order_id, 'amount', v_req.total_amount, 'payment_method', p_payment_method, 'idempotency_key', p_idempotency_key)
  );

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'request_id', v_req.id,
      'order_id', v_order_id,
      'order_number', v_order_num,
      'payment_status', 'paid',
      'status', CASE WHEN v_req.status = 'sent_kitchen' THEN 'sent_kitchen' ELSE 'ready_for_kitchen' END,
      'is_replay', false
    )
  );
END;
$$;


-- ── 14. RPC STAFF 11: SEND TO KITCHEN (ATOMIC ADVISORY LOCK & CANONICAL MAPPING) ──
CREATE OR REPLACE FUNCTION public.send_qr_order_to_kitchen_v4(
  p_request_id uuid,
  p_store_id uuid,
  p_idempotency_key text,
  p_order_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_staff record;
  v_req record;
  v_channel record;
  v_table record;
  v_session_id uuid;
  v_ticket_id uuid;
  v_session_item_id uuid;
  v_order_id uuid;
  v_order_item_id uuid;
  v_order_num text;
  v_item record;
  v_prod record;
  v_station text;
  v_table_label text;
  v_staff_member_id uuid;
  v_user_name text;
  v_user_phone text;
  v_existing_k_idemp record;
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id);

  IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_PAYLOAD',
      'message', 'Idempotency key là bắt buộc khi gửi bếp'
    );
  END IF;

  -- 1. ATOMIC ADVISORY LOCK TRÊN KEY TRƯỚC MỌI SIDE EFFECT
  PERFORM pg_advisory_xact_lock(hashtext(p_store_id::text), hashtext('send_kitchen:' || p_idempotency_key));

  SELECT * INTO v_req
  FROM public.qr_requests
  WHERE id = p_request_id AND store_id = p_store_id
  FOR UPDATE;

  IF v_req IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy đơn');
  END IF;

  SELECT * INTO v_channel FROM public.qr_channels WHERE id = v_req.channel_id;

  -- 2. Idempotency Pre-Check (Zero Side Effects if conflict/replay)
  SELECT * INTO v_existing_k_idemp
  FROM public.qr_kitchen_idempotency
  WHERE store_id = p_store_id AND idempotency_key = p_idempotency_key
  LIMIT 1;

  IF v_existing_k_idemp IS NOT NULL THEN
    IF v_existing_k_idemp.request_id = v_req.id THEN
      RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
          'request_id', v_req.id,
          'ticket_id', v_existing_k_idemp.ticket_id,
          'session_id', v_existing_k_idemp.session_id,
          'canonical_order_id', v_existing_k_idemp.canonical_order_id,
          'status', 'sent_kitchen',
          'is_replay', true
        )
      );
    ELSE
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'IDEMPOTENCY_CONFLICT',
        'message', 'Idempotency key đã được sử dụng cho thao tác gửi bếp khác'
      );
    END IF;
  END IF;

  SELECT * INTO v_existing_k_idemp
  FROM public.qr_kitchen_idempotency
  WHERE request_id = v_req.id
  LIMIT 1;

  IF v_existing_k_idemp IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'data', jsonb_build_object(
        'request_id', v_req.id,
        'ticket_id', v_existing_k_idemp.ticket_id,
        'session_id', v_existing_k_idemp.session_id,
        'canonical_order_id', v_existing_k_idemp.canonical_order_id,
        'status', 'sent_kitchen',
        'is_replay', true
      )
    );
  END IF;

  -- 3. Resolve staff_members.id
  v_staff_member_id := v_staff.store_member_id;
  SELECT display_name, phone INTO v_user_name, v_user_phone
  FROM public.user_accounts WHERE id = v_staff.member_user_id;

  INSERT INTO public.staff_members (
    id, store_id, name, role, phone, is_active, updated_at
  ) VALUES (
    v_staff_member_id, p_store_id, COALESCE(v_user_name, 'Staff'), COALESCE(v_staff.member_role, 'waiter'),
    v_user_phone, true, extract(epoch from now()) * 1000
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    role = EXCLUDED.role,
    is_active = true,
    updated_at = EXCLUDED.updated_at;

  -- 4. Xử lý đơn TABLE_SHARED: Bắt buộc đã gán bàn
  IF v_req.type IN ('TABLE_SHARED', 'table') THEN
    IF v_req.assigned_table_id IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'TABLE_NOT_FOUND',
        'message', 'Vui lòng chọn bàn trước khi gửi bếp'
      );
    END IF;

    SELECT * INTO v_table FROM public.ban_dining_tables WHERE id = v_req.assigned_table_id;
    v_table_label := COALESCE(v_table.label, 'Bàn');

    -- Tìm hoặc tạo ban_sessions với status = 'open'
    SELECT id INTO v_session_id
    FROM public.ban_sessions
    WHERE table_id = v_req.assigned_table_id
      AND store_id = p_store_id
      AND status = 'open'
    ORDER BY opened_at DESC
    LIMIT 1;

    IF v_session_id IS NULL THEN
      v_session_id := gen_random_uuid();
      INSERT INTO public.ban_sessions (
        id, store_id, table_id, status, opened_at, total_amount, guest_count
      ) VALUES (
        v_session_id, p_store_id, v_req.assigned_table_id, 'open', now(), 0, 1
      );
    END IF;

    -- Tạo Canonical Order cho TABLE_SHARED
    v_order_id := gen_random_uuid();
    v_order_num := 'QRT-' || to_char(now(), 'YYMMDD') || '-' || upper(encode(gen_random_bytes(3), 'hex'));

    INSERT INTO public.orders (
      id, store_id, order_number, subtotal, discount, tax, total, total_amount,
      payment_method, status, source_type, source_id, staff_id, receipt_printed, created_at, note
    ) VALUES (
      v_order_id, p_store_id, v_order_num, v_req.total_amount, 0, 0, v_req.total_amount, v_req.total_amount,
      'unpaid', 'open', 'qr_table', v_req.id::text, v_staff_member_id, false, now(),
      'Đơn QR Bàn ' || v_table_label
    );

    -- Liên kết order với session
    INSERT INTO public.ban_session_orders (
      id, store_id, session_id, order_id, qr_request_id, created_at
    ) VALUES (
      gen_random_uuid(), p_store_id, v_session_id, v_order_id, v_req.id, now()
    );

  -- 5. Xử lý đơn COUNTER_TAKEAWAY
  ELSE
    -- COUNTER luôn thu đủ tiền tại Thu ngân trước khi gửi Bếp. payment_mode chỉ
    -- còn là trường tương thích dữ liệu cũ, không được dùng để bỏ qua cổng này.
    IF v_req.payment_status <> 'paid' THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'PAYMENT_REQUIRED',
        'message', 'Đơn mang đi yêu cầu thanh toán trước khi gửi bếp'
      );
    END IF;

    v_table_label := 'Mang đi (' || COALESCE(v_req.pickup_code, '#Q01') || ')';
    v_session_id := NULL;
    v_order_id := v_req.canonical_order_id;
  END IF;

  -- 6. Tạo kitchen_tickets
  v_ticket_id := gen_random_uuid();
  INSERT INTO public.kitchen_tickets (
    id, store_id, session_id, table_label, round, sent_at, status, note
  ) VALUES (
    v_ticket_id, p_store_id, v_session_id, v_table_label,
    1, now(), 'cho', COALESCE(p_order_note, 'Đơn QR: ' || COALESCE(v_req.pickup_code, v_req.table_hint, ''))
  );

  -- 7. Ghi ban_session_items, order_items, ban_session_order_items, kitchen_ticket_items
  FOR v_item IN SELECT * FROM public.qr_request_items WHERE request_id = v_req.id
  LOOP
    SELECT category, cost_price_latest INTO v_prod FROM public.products WHERE id = v_item.product_id;
    v_station := CASE WHEN v_prod.category = 'Đồ uống' THEN 'nuoc' ELSE 'nong' END;

    IF v_session_id IS NOT NULL THEN
      v_session_item_id := gen_random_uuid();
      INSERT INTO public.ban_session_items (
        id, store_id, session_id, product_id, product_name, unit_price, price,
        quantity, subtotal, kitchen_status, added_at, note, modifiers_json
      ) VALUES (
        v_session_item_id, p_store_id, v_session_id, v_item.product_id, v_item.product_name,
        v_item.unit_price, v_item.unit_price, v_item.quantity, v_item.subtotal,
        'da_gui', now(), v_item.note, v_item.modifiers_json::text
      );

      v_order_item_id := gen_random_uuid();
      INSERT INTO public.order_items (
        id, store_id, order_id, product_id, name, product_name, qty, quantity,
        unit_price, cost_price, subtotal, modifiers_json
      ) VALUES (
        v_order_item_id, p_store_id, v_order_id, v_item.product_id, v_item.product_name, v_item.product_name,
        v_item.quantity, v_item.quantity, v_item.unit_price, COALESCE(v_prod.cost_price_latest, 0),
        v_item.subtotal, v_item.modifiers_json
      );

      INSERT INTO public.ban_session_order_items (
        id, store_id, session_id, session_item_id, order_id, order_item_id, source_type, created_at
      ) VALUES (
        gen_random_uuid(), p_store_id, v_session_id, v_session_item_id, v_order_id, v_order_item_id, 'qr_table', now()
      );
    ELSE
      v_session_item_id := NULL;
    END IF;

    INSERT INTO public.kitchen_ticket_items (
      id, store_id, ticket_id, session_item_id, product_id, name, product_name, qty, quantity,
      status, station_code, free_note, kitchen_note, modifiers_json, done
    ) VALUES (
      gen_random_uuid(), p_store_id, v_ticket_id, v_session_item_id, v_item.product_id,
      v_item.product_name, v_item.product_name, v_item.quantity, v_item.quantity,
      'cho', v_station, v_item.note, v_item.modifiers_json::text, v_item.modifiers_json::text, false
    );
  END LOOP;

  -- 8. Lưu idempotency gửi bếp
  INSERT INTO public.qr_kitchen_idempotency (
    id, store_id, request_id, idempotency_key, ticket_id, session_id, canonical_order_id, created_at
  ) VALUES (
    gen_random_uuid(), p_store_id, v_req.id, p_idempotency_key, v_ticket_id, v_session_id, v_order_id, now()
  );

  -- 9. Cập nhật trạng thái qr_requests
  UPDATE public.qr_requests
  SET status = 'sent_kitchen',
      assigned_session_id = v_session_id,
      canonical_order_id = COALESCE(v_order_id, canonical_order_id),
      version = version + 1
  WHERE id = v_req.id;

  INSERT INTO public.qr_audit_logs (
    store_id, request_id, action, actor_user_id, details
  ) VALUES (
    p_store_id, v_req.id, 'send_kitchen', v_staff.member_user_id,
    jsonb_build_object('ticket_id', v_ticket_id, 'session_id', v_session_id, 'canonical_order_id', v_order_id, 'idempotency_key', p_idempotency_key)
  );

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'request_id', v_req.id,
      'ticket_id', v_ticket_id,
      'session_id', v_session_id,
      'canonical_order_id', v_order_id,
      'status', 'sent_kitchen',
      'is_replay', false
    )
  );
END;
$$;


-- ── 15. RPC STAFF 12: SETTLE BAN SESSION (ATOMIC ADVISORY LOCK & FINANCIAL ENGINE) ──
CREATE OR REPLACE FUNCTION public.settle_ban_session_v4(
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
SET search_path = pg_catalog, public
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
BEGIN
  -- 1. Bắt buộc quyền pos.checkout (100% Fail-Closed)
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);

  -- 2. Xác thực định dạng payload cơ bản & Whitelist Payment Method
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

  -- 3. Khóa Transaction-Scoped Advisory Lock trên Idempotency Key trước mọi side-effect
  PERFORM pg_advisory_xact_lock(hashtext(p_store_id::text), hashtext('settle_ban_session:' || p_idempotency_key));

  -- 4. Khóa phiên bàn FOR UPDATE & Kiểm tra tồn tại
  SELECT * INTO v_session
  FROM public.ban_sessions
  WHERE id = p_session_id AND store_id = p_store_id
  FOR UPDATE;

  IF v_session IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy phiên bàn');
  END IF;

  SELECT * INTO v_table FROM public.ban_dining_tables WHERE id = v_session.table_id;

  -- 5. Tạo Financial Intent Fingerprint (SHA-256 từ các tham số tài chính chuẩn hóa)
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

  -- 6. Idempotency Pre-Check (Zero Side Effects nếu replay hoặc conflict)
  SELECT * INTO v_existing_settle
  FROM public.payment_settlements
  WHERE store_id = p_store_id AND idempotency_key = p_idempotency_key
  LIMIT 1;

  IF v_existing_settle IS NOT NULL THEN
    IF v_existing_settle.session_id = p_session_id AND v_existing_settle.request_fingerprint = v_request_fingerprint THEN
      SELECT COALESCE(jsonb_agg(order_id), '[]'::jsonb) INTO v_canonical_order_ids
      FROM public.ban_session_orders
      WHERE session_id = p_session_id;

      RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
          'session_id', p_session_id,
          'settlement_id', v_existing_settle.id,
          'canonical_order_ids', v_canonical_order_ids,
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

  SELECT * INTO v_existing_settle
  FROM public.payment_settlements
  WHERE session_id = p_session_id
  LIMIT 1;

  IF v_existing_settle IS NOT NULL THEN
    IF v_existing_settle.idempotency_key = p_idempotency_key AND v_existing_settle.request_fingerprint = v_request_fingerprint THEN
      SELECT COALESCE(jsonb_agg(order_id), '[]'::jsonb) INTO v_canonical_order_ids
      FROM public.ban_session_orders
      WHERE session_id = p_session_id;

      RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
          'session_id', p_session_id,
          'settlement_id', v_existing_settle.id,
          'canonical_order_ids', v_canonical_order_ids,
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
        'error_code', 'SESSION_ALREADY_SETTLED',
        'message', 'Phiên bàn này đã được quyết toán trước đó'
      );
    END IF;
  END IF;

  IF v_session.status <> 'open' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Phiên bàn không ở trạng thái mở để thanh toán');
  END IF;

  -- 7. Đọc Subtotal Authoritative từ cơ sở dữ liệu
  SELECT COALESCE(SUM(subtotal), 0) INTO v_raw_subtotal
  FROM public.ban_session_items
  WHERE session_id = p_session_id;

  IF v_raw_subtotal <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_SESSION_ITEMS',
      'message', 'Phiên bàn không có món ăn để thanh toán'
    );
  END IF;

  -- 8. Xác thực Khách Hàng & Điểm Tích Lũy (100% Fail-Closed)
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

  -- 9. Xác thực Mã Giảm Giá / Coupon (100% Fail-Closed)
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
      SELECT id, discount_type, value, min_order_amount, max_discount_amount, is_active, start_date, end_date
      FROM public.coupons
      WHERE store_id = $1 AND lower(trim(code)) = lower(trim($2))
      LIMIT 1
    ' INTO v_coupon_id, v_coupon_type, v_coupon_val, v_coupon_min_order, v_coupon_max_disc, v_coupon_active, v_coupon_start, v_coupon_end
    USING p_store_id, p_coupon_code;

    IF v_coupon_id IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_NOT_FOUND',
        'message', 'Mã giảm giá không tồn tại hoặc không thuộc quán'
      );
    END IF;

    IF v_coupon_active IS NOT TRUE THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_DISABLED',
        'message', 'Mã giảm giá hiện đang bị tạm khóa'
      );
    END IF;

    IF v_coupon_start IS NOT NULL AND v_coupon_start > now() THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_NOT_STARTED',
        'message', 'Mã giảm giá chưa đến ngày áp dụng'
      );
    END IF;

    IF v_coupon_end IS NOT NULL AND v_coupon_end < now() THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_EXPIRED',
        'message', 'Mã giảm giá đã hết hạn sử dụng'
      );
    END IF;

    IF v_raw_subtotal < COALESCE(v_coupon_min_order, 0) THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_MIN_ORDER_NOT_MET',
        'message', 'Đơn hàng chưa đạt giá trị tối thiểu ' || COALESCE(v_coupon_min_order, 0) || 'đ để áp dụng mã'
      );
    END IF;

    IF v_coupon_type = 'percent' THEN
      IF v_coupon_val <= 0 OR v_coupon_val > 100 THEN
        RETURN jsonb_build_object(
          'success', false,
          'error_code', 'INVALID_COUPON_VALUE',
          'message', 'Giá trị phần trăm giảm giá của mã không hợp lệ'
        );
      END IF;
      v_coupon_discount := (v_raw_subtotal * v_coupon_val / 100);
      IF v_coupon_max_disc IS NOT NULL AND v_coupon_max_disc > 0 THEN
        v_coupon_discount := LEAST(v_coupon_discount, v_coupon_max_disc);
      END IF;
    ELSIF v_coupon_type = 'fixed' THEN
      IF v_coupon_val <= 0 THEN
        RETURN jsonb_build_object(
          'success', false,
          'error_code', 'INVALID_COUPON_VALUE',
          'message', 'Số tiền giảm giá cố định của mã không hợp lệ'
        );
      END IF;
      v_coupon_discount := v_coupon_val;
    ELSE
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'INVALID_COUPON_TYPE',
        'message', 'Loại giảm giá không được hệ thống hỗ trợ'
      );
    END IF;

    v_coupon_discount := LEAST(v_coupon_discount, v_raw_subtotal);
  END IF;

  -- 10. Xác thực Phụ Phí / Surcharge (100% Fail-Closed)
  IF p_surcharge IS NOT NULL THEN
    IF p_surcharge < 0 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'INVALID_SURCHARGE',
        'message', 'Phụ phí không thể là số âm'
      );
    END IF;
    IF p_surcharge > 100000000 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'INVALID_SURCHARGE',
        'message', 'Phụ phí vượt quá giới hạn tối đa cho phép (100.000.000đ)'
      );
    END IF;
    v_surcharge := p_surcharge;
  ELSE
    v_surcharge := 0;
  END IF;

  -- 11. Tính Tổng Giảm Giá & Tổng Thanh Toán Authoritative
  v_discount := LEAST(v_raw_subtotal, v_coupon_discount + v_points_discount);
  v_final_total := GREATEST(0, (v_raw_subtotal - v_discount + v_surcharge));

  -- 12. Đối Chiếu Expected Quote Từ Client (Chống stale UI / giá thay đổi)
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

  -- 13. CHỈ THỰC HIỆN SIDE EFFECT SAU KHI 100% VALIDATION ĐÃ PASS
  -- 13.1. Staff Members Upsert
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

  -- 13.2. Bàn hỗn hợp: Gom món manual thành canonical order
  SELECT COALESCE(SUM(subtotal), 0) INTO v_manual_subtotal
  FROM public.ban_session_items bsi
  WHERE bsi.session_id = p_session_id
    AND NOT EXISTS (
      SELECT 1 FROM public.ban_session_order_items bsoi
      WHERE bsoi.session_item_id = bsi.id
    );

  IF v_manual_subtotal > 0 THEN
    v_manual_order_id := gen_random_uuid();
    v_manual_order_num := 'QRM-' || to_char(now(), 'YYMMDD') || '-' || upper(encode(gen_random_bytes(3), 'hex'));

    INSERT INTO public.orders (
      id, store_id, order_number, subtotal, discount, tax, total, total_amount,
      payment_method, status, source_type, source_id, staff_id, receipt_printed, created_at, note
    ) VALUES (
      v_manual_order_id, p_store_id, v_manual_order_num, v_manual_subtotal, 0, 0, v_manual_subtotal, v_manual_subtotal,
      p_payment_method, 'completed', 'ban_manual', p_session_id::text, v_staff_member_id, false, now(),
      'Món nhân viên thêm tại bàn ' || COALESCE(v_table.label, 'bàn')
    );

    INSERT INTO public.ban_session_orders (
      id, store_id, session_id, order_id, qr_request_id, created_at
    ) VALUES (
      gen_random_uuid(), p_store_id, p_session_id, v_manual_order_id, NULL, now()
    );

    FOR v_manual_item_row IN (
      SELECT bsi.* FROM public.ban_session_items bsi
      WHERE bsi.session_id = p_session_id
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

  -- 13.3. Loyalty rate calculation for earned points
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

  -- 13.4. Insert Payment Settlements (Authoritative Financial Record with Fingerprint)
  INSERT INTO public.payment_settlements (
    id, store_id, session_id, idempotency_key, request_fingerprint, subtotal, discount,
    points_discount, coupon_discount, surcharge, total_amount, payment_method, customer_id,
    points_used, coupon_code, status, created_at
  ) VALUES (
    v_settlement_id, p_store_id, p_session_id, p_idempotency_key, v_request_fingerprint, v_raw_subtotal, v_discount,
    v_points_discount, v_coupon_discount, v_surcharge, v_final_total, p_payment_method, p_customer_id,
    v_actual_points_used, p_coupon_code, 'completed', now()
  );

  -- 13.5. Insert Coupon Redemption Record if Coupon Applied
  IF v_coupon_discount > 0 AND p_coupon_code IS NOT NULL THEN
    INSERT INTO public.qr_coupon_redemptions (
      id, store_id, session_id, settlement_id, coupon_id, coupon_code, discount_amount, created_at
    ) VALUES (
      gen_random_uuid(), p_store_id, p_session_id, v_settlement_id, v_coupon_id, p_coupon_code, v_coupon_discount, now()
    );
  END IF;

  -- 13.6. Mark All Canonical Orders as Completed
  FOR v_order IN (
    SELECT o.* FROM public.orders o
    JOIN public.ban_session_orders bso ON bso.order_id = o.id
    WHERE bso.session_id = p_session_id
  )
  LOOP
    UPDATE public.orders
    SET status = 'completed',
        payment_method = p_payment_method,
        customer_id = COALESCE(p_customer_id, customer_id),
        loyalty_pts_earned = v_pts_earned,
        loyalty_pts_used = v_actual_points_used
    WHERE id = v_order.id;

    -- Deduct stock & recipe movements
    FOR v_item IN SELECT * FROM public.order_items WHERE order_id = v_order.id
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
            WHERE r.pos_product_id = $1 AND r.is_deleted = false
          )
        ' INTO v_has_recipe USING v_item.product_id;
      END IF;

      IF v_has_recipe THEN
        FOR v_rec_ing IN EXECUTE '
          SELECT ri.ingredient_id, ri.quantity, ri.yield_factor
          FROM public.recipes r
          JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
          WHERE r.pos_product_id = $1 AND r.is_deleted = false AND ri.ingredient_id IS NOT NULL
        ' USING v_item.product_id
        LOOP
          v_actual_ing_qty := (v_rec_ing.quantity / COALESCE(NULLIF(v_rec_ing.yield_factor, 0), 1.0)) * v_item.quantity;
          
          INSERT INTO public.stock_movements (
            id, store_id, product_id, delta, reason, reference_id, note, created_at
          ) VALUES (
            gen_random_uuid(), p_store_id, v_rec_ing.ingredient_id, -v_actual_ing_qty,
            'recipe_usage', v_settlement_id, 'Xuất kho công thức bàn ' || COALESCE(v_table.label, 'bàn') || ': ' || v_item.product_name, now()
          );

          UPDATE public.products
          SET stock_qty = COALESCE(stock_qty, 0) - v_actual_ing_qty,
              updated_at = extract(epoch from now()) * 1000
          WHERE id = v_rec_ing.ingredient_id AND store_id = p_store_id;
        END LOOP;
      ELSE
        INSERT INTO public.stock_movements (
          id, store_id, product_id, delta, reason, reference_id, note, created_at
        ) VALUES (
          gen_random_uuid(), p_store_id, v_item.product_id, -v_item.quantity,
          'sale', v_settlement_id, 'Bán hàng bàn ' || COALESCE(v_table.label, 'bàn'), now()
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
                  WHERE r.pos_product_id = $1 AND r.is_deleted = false
                )
              ' INTO v_has_recipe USING (v_mod->>'id')::uuid;
            END IF;

            IF v_has_recipe THEN
              FOR v_rec_ing IN EXECUTE '
                SELECT ri.ingredient_id, ri.quantity, ri.yield_factor
                FROM public.recipes r
                JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
                WHERE r.pos_product_id = $1 AND r.is_deleted = false AND ri.ingredient_id IS NOT NULL
              ' USING (v_mod->>'id')::uuid
              LOOP
                v_actual_ing_qty := (v_rec_ing.quantity / COALESCE(NULLIF(v_rec_ing.yield_factor, 0), 1.0)) * ((COALESCE((v_mod->>'quantity')::numeric, 1)) * v_item.quantity);
                
                INSERT INTO public.stock_movements (
                  id, store_id, product_id, delta, reason, reference_id, note, created_at
                ) VALUES (
                  gen_random_uuid(), p_store_id, v_rec_ing.ingredient_id, -v_actual_ing_qty,
                  'recipe_usage', v_settlement_id, 'Xuất kho topping công thức bàn ' || COALESCE(v_table.label, 'bàn'), now()
                );

                UPDATE public.products
                SET stock_qty = COALESCE(stock_qty, 0) - v_actual_ing_qty,
                    updated_at = extract(epoch from now()) * 1000
                WHERE id = v_rec_ing.ingredient_id AND store_id = p_store_id;
              END LOOP;
            ELSE
              INSERT INTO public.stock_movements (
                id, store_id, product_id, delta, reason, reference_id, note, created_at
              ) VALUES (
                gen_random_uuid(), p_store_id, (v_mod->>'id')::uuid,
                -((COALESCE((v_mod->>'quantity')::numeric, 1)) * v_item.quantity),
                'sale', v_settlement_id, 'Bán topping bàn ' || COALESCE(v_table.label, 'bàn'), now()
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

  -- 13.7. Ghi ĐÚNG 1 bản ghi sổ quỹ finance_records với final total
  INSERT INTO public.finance_records (
    id, store_id, type, amount, description, reference_id, is_auto, recorded_at, fund_type
  ) VALUES (
    gen_random_uuid(), p_store_id, 'income', v_final_total,
    'Thanh toán bàn ' || COALESCE(v_table.label, 'bàn') || CASE WHEN p_coupon_code IS NOT NULL THEN ' [Voucher: ' || p_coupon_code || ']' ELSE '' END,
    v_settlement_id, true, now(), v_fund_type
  );

  -- 13.8. Tích điểm / Trừ điểm cho Khách hàng & Loyalty Transactions
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
        'Thanh toán bàn ' || COALESCE(v_table.label, 'bàn'), now()
      );
    END IF;
  END IF;

  -- 13.9. Cập nhật Bàn ăn về trạng thái 'empty'
  IF v_session.table_id IS NOT NULL THEN
    UPDATE public.ban_dining_tables
    SET status = 'empty'
    WHERE id = v_session.table_id AND store_id = p_store_id;
  END IF;

  -- 13.10. Đóng Session bàn
  UPDATE public.ban_sessions
  SET status = 'closed',
      closed_at = now(),
      total_amount = v_final_total
  WHERE id = p_session_id;

  INSERT INTO public.qr_audit_logs (
    store_id, request_id, action, actor_user_id, details
  ) VALUES (
    p_store_id, NULL, 'settle_session', v_staff.member_user_id,
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

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'session_id', p_session_id,
      'settlement_id', v_settlement_id,
      'canonical_order_ids', v_canonical_order_ids,
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


-- ── 16. RPC STAFF 13: CANCEL ORDER ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cancel_qr_order_v4(
  p_request_id uuid,
  p_store_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_staff record;
  v_req record;
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id);

  SELECT * INTO v_req
  FROM public.qr_requests
  WHERE id = p_request_id AND store_id = p_store_id
  FOR UPDATE;

  IF v_req IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy đơn');
  END IF;

  IF v_req.status IN ('completed', 'cancelled', 'rejected') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Đơn hàng đã hoàn tất hoặc đã bị hủy trước đó');
  END IF;

  UPDATE public.qr_requests
  SET status = 'cancelled',
      reject_reason = p_reason,
      version = version + 1
  WHERE id = v_req.id;

  UPDATE public.qr_handoff_tokens
  SET status = 'expired', consumed_at = now()
  WHERE request_id = v_req.id AND status = 'active';

  INSERT INTO public.qr_audit_logs (
    store_id, request_id, action, actor_user_id, details
  ) VALUES (
    p_store_id, v_req.id, 'cancel_order', v_staff.member_user_id,
    jsonb_build_object('reason', p_reason)
  );

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object('request_id', v_req.id, 'status', 'cancelled')
  );
END;
$$;


-- ── 17. RPC STAFF 14: MANAGE QR CHANNEL (GLOBAL UNIQUE CODE GENERATION) ────────
CREATE OR REPLACE FUNCTION public.manage_qr_channel_v4(
  p_store_id uuid,
  p_type text,
  p_is_active boolean DEFAULT true,
  p_payment_mode text DEFAULT 'CASHIER_CONFIRM'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_staff record;
  v_prefix text;
  v_code text;
  v_name text;
  v_channel record;
  v_attempts integer := 0;
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_manage => true);

  IF p_type NOT IN ('TABLE_SHARED', 'COUNTER_TAKEAWAY', 'table', 'counter') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Loại kênh không hợp lệ');
  END IF;

  IF p_payment_mode NOT IN ('PAY_BEFORE_KITCHEN', 'CASHIER_CONFIRM') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Chế độ thanh toán không hợp lệ');
  END IF;

  SELECT * INTO v_channel
  FROM public.qr_channels
  WHERE store_id = p_store_id AND type = p_type
  LIMIT 1;

  IF v_channel IS NOT NULL THEN
    UPDATE public.qr_channels
    SET is_active = p_is_active,
        payment_mode = p_payment_mode
    WHERE id = v_channel.id
    RETURNING * INTO v_channel;
  ELSE
    v_prefix := CASE WHEN p_type IN ('TABLE_SHARED', 'table') THEN 'TBL' ELSE 'CTR' END;
    
    LOOP
      v_code := v_prefix || '_' || upper(encode(gen_random_bytes(6), 'hex'));
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.qr_channels WHERE channel_code = v_code);
      v_attempts := v_attempts + 1;
      IF v_attempts > 10 THEN
        RAISE EXCEPTION 'Failed to generate unique channel code';
      END IF;
    END LOOP;

    v_name := CASE WHEN p_type IN ('TABLE_SHARED', 'table') THEN 'QR Dùng Chung Tại Bàn' ELSE 'Quầy Thu Ngân' END;

    INSERT INTO public.qr_channels (
      store_id, type, channel_code, name, is_active, payment_mode
    ) VALUES (
      p_store_id, p_type, v_code, v_name, p_is_active, p_payment_mode
    )
    RETURNING * INTO v_channel;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'id', v_channel.id,
      'store_id', v_channel.store_id,
      'type', v_channel.type,
      'channel_code', v_channel.channel_code,
      'name', v_channel.name,
      'is_active', v_channel.is_active,
      'payment_mode', v_channel.payment_mode,
      'pickup_counter', v_channel.pickup_counter,
      'created_at', v_channel.created_at
    )
  );
END;
$$;


-- ── 18. QUYỀN TRUY CẬP (EXPLICIT REVOKE ALL & LEAST PRIVILEGE GRANTS) ──────────

-- 18.1. Thu hồi ALL mặc định trên TOÀN BỘ BẢNG
REVOKE ALL ON TABLE public.qr_channels FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.qr_requests FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.qr_request_items FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.qr_handoff_tokens FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.qr_audit_logs FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.product_topping_links FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.qr_payment_idempotency FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.qr_kitchen_idempotency FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.ban_session_orders FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.ban_session_order_items FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.payment_settlements FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.qr_coupon_redemptions FROM PUBLIC, anon, authenticated;

-- 18.2. Thu hồi ALL mặc định trên TOÀN BỘ FUNCTIONS khỏi PUBLIC, anon, authenticated
REVOKE ALL ON FUNCTION public.verify_staff_qr_membership_v4(uuid, boolean, boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_qr_channel_info_v4(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_qr_menu_v4(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.submit_qr_order_v4(text, jsonb, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_qr_request_status_v4(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.regenerate_handoff_token_v4(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.claim_qr_handoff_v4(text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_qr_request_detail_v4(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_qr_order_items_v4(uuid, uuid, integer, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assign_qr_order_table_v4(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.mark_qr_order_paid_v4(uuid, uuid, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.send_qr_order_to_kitchen_v4(uuid, uuid, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.settle_ban_session_v4(uuid, uuid, text, text, uuid, integer, numeric, text, numeric) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cancel_qr_order_v4(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.manage_qr_channel_v4(uuid, text, boolean, text) FROM PUBLIC, anon, authenticated;

-- 18.3. Cấp SELECT cho staff (authenticated)
GRANT SELECT ON TABLE public.qr_channels TO authenticated;
GRANT SELECT ON TABLE public.qr_requests TO authenticated;
GRANT SELECT ON TABLE public.qr_request_items TO authenticated;
GRANT SELECT ON TABLE public.qr_audit_logs TO authenticated;
GRANT SELECT ON TABLE public.product_topping_links TO authenticated;
GRANT SELECT ON TABLE public.qr_payment_idempotency TO authenticated;
GRANT SELECT ON TABLE public.qr_kitchen_idempotency TO authenticated;
GRANT SELECT ON TABLE public.ban_session_orders TO authenticated;
GRANT SELECT ON TABLE public.ban_session_order_items TO authenticated;
GRANT SELECT ON TABLE public.payment_settlements TO authenticated;
GRANT SELECT ON TABLE public.qr_coupon_redemptions TO authenticated;

-- 18.4. Cấp quyền thực thi RPC
-- Public RPCs: Cấp anon & authenticated
GRANT EXECUTE ON FUNCTION public.get_qr_channel_info_v4(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_qr_menu_v4(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_qr_order_v4(text, jsonb, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_qr_request_status_v4(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.regenerate_handoff_token_v4(text) TO anon, authenticated;

-- Staff RPCs: CHỈ cấp authenticated (Bên trong hàm có verify_staff_qr_membership_v4)
GRANT EXECUTE ON FUNCTION public.claim_qr_handoff_v4(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_qr_request_detail_v4(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_qr_order_items_v4(uuid, uuid, integer, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_qr_order_table_v4(uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_qr_order_paid_v4(uuid, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_qr_order_to_kitchen_v4(uuid, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.settle_ban_session_v4(uuid, uuid, text, text, uuid, integer, numeric, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_qr_order_v4(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.manage_qr_channel_v4(uuid, text, boolean, text) TO authenticated;
