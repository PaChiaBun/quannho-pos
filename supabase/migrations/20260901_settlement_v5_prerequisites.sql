-- Settlement V5 prerequisites for the live Quán Nhỏ schema.
-- This intentionally does not deploy the blocked QR V4 proposal: production
-- dining-table identifiers are text while that proposal assumed UUID.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Current production predates recipe yield tracking. Settlement V5 uses this
-- factor only when a recipe exists; default 1 preserves all legacy recipes.
ALTER TABLE public.recipe_ingredients
  ADD COLUMN IF NOT EXISTS yield_factor numeric NOT NULL DEFAULT 1;

CREATE TABLE IF NOT EXISTS public.qr_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  request_id uuid,
  action text NOT NULL,
  actor_user_id uuid,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.qr_audit_logs
  ADD COLUMN IF NOT EXISTS actor_user_id uuid,
  ADD COLUMN IF NOT EXISTS details jsonb NOT NULL DEFAULT '{}'::jsonb;
CREATE INDEX IF NOT EXISTS idx_qr_audit_logs_store_created
  ON public.qr_audit_logs(store_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.ban_session_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.ban_sessions(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  qr_request_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_ban_session_orders_order UNIQUE (order_id)
);
CREATE INDEX IF NOT EXISTS idx_ban_session_orders_session
  ON public.ban_session_orders(session_id);

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
CREATE INDEX IF NOT EXISTS idx_ban_session_order_items_session
  ON public.ban_session_order_items(session_id);

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
  CONSTRAINT uq_payment_settlements_idempotency UNIQUE (store_id, idempotency_key),
  CONSTRAINT uq_payment_settlements_session UNIQUE (session_id)
);
ALTER TABLE public.payment_settlements
  ADD COLUMN IF NOT EXISTS request_fingerprint text,
  ADD COLUMN IF NOT EXISTS points_discount numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS coupon_discount numeric NOT NULL DEFAULT 0;
UPDATE public.payment_settlements
SET request_fingerprint = encode(
  digest(id::text || ':' || store_id::text || ':' || session_id::text || ':' || idempotency_key, 'sha256'),
  'hex'
)
WHERE request_fingerprint IS NULL;
ALTER TABLE public.payment_settlements
  ALTER COLUMN request_fingerprint SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_payment_settlements_idempotency_idx
  ON public.payment_settlements(store_id, idempotency_key);
CREATE UNIQUE INDEX IF NOT EXISTS uq_payment_settlements_session_idx
  ON public.payment_settlements(session_id);
CREATE INDEX IF NOT EXISTS idx_payment_settlements_fingerprint
  ON public.payment_settlements(request_fingerprint);

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

  SELECT sm.id, sm.role, COALESCE(sm.is_owner, false)
  INTO v_sm_id, v_role, v_is_owner
  FROM public.store_members sm
  WHERE sm.store_id = p_store_id AND sm.user_id = v_uid
  LIMIT 1;
  IF v_role IS NULL THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: not a member of this store'
      USING ERRCODE = '42501';
  END IF;

  IF p_require_manage AND NOT (v_is_owner OR v_role IN ('owner', 'manager', 'admin')) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: manage permission required'
      USING ERRCODE = '42501';
  END IF;

  IF p_require_checkout AND NOT (v_is_owner OR v_role = 'owner') THEN
    -- 1. Ưu tiên vai trò chuẩn (owner, manager, cashier, admin hoặc tiếng Việt)
    IF v_role IN ('owner', 'manager', 'cashier', 'admin')
       OR lower(trim(v_role)) LIKE '%thu ngân%'
       OR lower(trim(v_role)) LIKE '%quản lý%'
       OR lower(trim(v_role)) LIKE '%quầy%' THEN
      v_has_checkout := true;
    END IF;

    -- 2. Kiểm tra modules từ store_roles (Nguồn sự thật Lego Modules)
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

    -- 3. Kiểm tra modules cá nhân từ staff_members nếu có
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
  -- staff_members.id is canonically the authenticated user-account UUID in the
  -- live schema. Some old store_members rows use a different surrogate id;
  -- returning that id would create a duplicate cashier profile at checkout.
  store_member_id := v_uid;
  is_owner_member := v_is_owner OR v_role = 'owner';
  RETURN NEXT;
END;
$$;

ALTER TABLE public.qr_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ban_session_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ban_session_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_coupon_redemptions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.qr_audit_logs, public.ban_session_orders,
  public.ban_session_order_items, public.payment_settlements,
  public.qr_coupon_redemptions FROM PUBLIC;

GRANT SELECT ON public.qr_audit_logs, public.ban_session_orders,
  public.ban_session_order_items, public.payment_settlements,
  public.qr_coupon_redemptions TO anon, authenticated, service_role;

DROP POLICY IF EXISTS payment_settlements_all ON public.payment_settlements;
CREATE POLICY payment_settlements_all ON public.payment_settlements
  FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS ban_session_orders_all ON public.ban_session_orders;
CREATE POLICY ban_session_orders_all ON public.ban_session_orders
  FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS ban_session_order_items_all ON public.ban_session_order_items;
CREATE POLICY ban_session_order_items_all ON public.ban_session_order_items
  FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS qr_audit_logs_all ON public.qr_audit_logs;
CREATE POLICY qr_audit_logs_all ON public.qr_audit_logs
  FOR ALL TO public USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS qr_coupon_redemptions_all ON public.qr_coupon_redemptions;
CREATE POLICY qr_coupon_redemptions_all ON public.qr_coupon_redemptions
  FOR ALL TO public USING (true) WITH CHECK (true);

REVOKE ALL ON FUNCTION public.verify_staff_qr_membership_v4(uuid, boolean, boolean)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_staff_qr_membership_v4(uuid, boolean, boolean)
  TO anon, authenticated, service_role;

COMMIT;
