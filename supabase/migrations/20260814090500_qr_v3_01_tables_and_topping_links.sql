-- Migration 01: Core QR Tables and Product Topping Links DDL with Immediate RLS Hardening
-- File: supabase/migrations/20260814090500_qr_v3_01_tables_and_topping_links.sql

-- Preflight
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'qr_channels') THEN
    RAISE EXCEPTION 'MIGRATION_01_PREFLIGHT_FAIL: Table public.qr_channels already exists';
  END IF;
END $$;

-- 1. qr_channels
CREATE TABLE public.qr_channels (
  id           uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id     uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  type         text NOT NULL,
  table_id     text REFERENCES public.ban_dining_tables(id) ON DELETE RESTRICT,
  channel_code text NOT NULL,
  name         text NOT NULL,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_qr_channels PRIMARY KEY (id),
  CONSTRAINT uq_qr_channels_code UNIQUE (channel_code),
  CONSTRAINT chk_qr_channels_type CHECK (type IN ('table', 'counter')),
  CONSTRAINT chk_qr_channels_table_binding CHECK (
    (type = 'table' AND table_id IS NOT NULL) OR
    (type = 'counter' AND table_id IS NULL)
  ),
  CONSTRAINT chk_qr_channels_name CHECK (name = TRIM(name) AND length(name) BETWEEN 1 AND 100),
  CONSTRAINT chk_qr_channels_code_format CHECK (
    (type = 'table' AND channel_code ~ '^tbl_[0-9a-f]{32}$')
    OR
    (type = 'counter' AND channel_code ~ '^ctr_[0-9a-f]{32}$')
  )
);
CREATE INDEX idx_qr_channels_store ON public.qr_channels(store_id);

CREATE UNIQUE INDEX idx_qr_channels_active_table
ON public.qr_channels(store_id, table_id)
WHERE type = 'table' AND is_active = true;

CREATE UNIQUE INDEX idx_qr_channels_active_counter
ON public.qr_channels(store_id)
WHERE type = 'counter' AND is_active = true;

ALTER TABLE public.qr_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_channels FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.qr_channels FROM PUBLIC, anon, authenticated;

-- 2. qr_requests
CREATE TABLE public.qr_requests (
  id                         uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id                   uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  channel_id                 uuid NOT NULL REFERENCES public.qr_channels(id) ON DELETE CASCADE,
  type                       text NOT NULL,
  table_id                   text,
  table_name                 text,
  pickup_business_date       date,
  pickup_number              integer,
  pickup_code                text,
  tracking_token_hash        bytea NOT NULL,
  idempotency_key            text NOT NULL,
  request_payload_hash       bytea NOT NULL,
  quote_version              integer NOT NULL DEFAULT 1,
  status                     text NOT NULL DEFAULT 'pending_staff',
  note                       text NOT NULL DEFAULT '',
  total_amount               numeric(12,2) NOT NULL DEFAULT 0.00,
  claimed_by_user_account_id uuid REFERENCES public.user_accounts(id) ON DELETE SET NULL,
  claimed_by_staff_id        uuid REFERENCES public.staff_members(id) ON DELETE SET NULL,
  reject_reason              text,
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_qr_requests PRIMARY KEY (id),
  CONSTRAINT uq_qr_requests_token_hash UNIQUE (tracking_token_hash),
  CONSTRAINT uq_qr_requests_channel_idempotency UNIQUE (channel_id, idempotency_key),
  CONSTRAINT uq_qr_requests_pickup_sequence UNIQUE (store_id, pickup_business_date, pickup_number),
  CONSTRAINT chk_qr_requests_status CHECK (status IN ('pending_staff', 'processing', 'confirmed', 'sent_kitchen', 'rejected', 'expired')),
  CONSTRAINT chk_qr_requests_type CHECK (type IN ('table', 'counter')),
  CONSTRAINT chk_qr_requests_table_binding CHECK (
    (type = 'table' AND table_id IS NOT NULL) OR
    (type = 'counter' AND table_id IS NULL)
  ),
  CONSTRAINT chk_qr_requests_quote_version CHECK (quote_version > 0),
  CONSTRAINT chk_qr_requests_total_amount CHECK (total_amount >= 0.00),
  CONSTRAINT chk_qr_requests_idempotency_key CHECK (length(idempotency_key) BETWEEN 1 AND 64 AND idempotency_key ~ '^[ -~]+$'),
  CONSTRAINT chk_qr_requests_pickup_mode CHECK (
    (type = 'counter' AND pickup_business_date IS NOT NULL AND pickup_number IS NOT NULL AND pickup_code IS NOT NULL)
    OR
    (type = 'table' AND pickup_business_date IS NULL AND pickup_number IS NULL AND pickup_code IS NULL)
  ),
  CONSTRAINT chk_qr_requests_pickup_number_positive CHECK (pickup_number IS NULL OR pickup_number > 0),
  CONSTRAINT chk_qr_requests_pickup_code_format CHECK (pickup_code IS NULL OR pickup_code ~ '^Q[0-9]{3,}$'),
  CONSTRAINT chk_qr_requests_claimed_principal CHECK (
    (claimed_by_user_account_id IS NOT NULL AND claimed_by_staff_id IS NULL) OR
    (claimed_by_user_account_id IS NULL AND claimed_by_staff_id IS NOT NULL) OR
    (claimed_by_user_account_id IS NULL AND claimed_by_staff_id IS NULL)
  )
);
CREATE INDEX idx_qr_requests_store_status ON public.qr_requests(store_id, status);

ALTER TABLE public.qr_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_requests FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.qr_requests FROM PUBLIC, anon, authenticated;

-- 3. qr_request_items
CREATE TABLE public.qr_request_items (
  id             uuid NOT NULL DEFAULT gen_random_uuid(),
  request_id     uuid NOT NULL REFERENCES public.qr_requests(id) ON DELETE CASCADE,
  product_id     uuid NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
  product_name   text NOT NULL,
  unit_price     numeric(12,2) NOT NULL,
  quantity       integer NOT NULL,
  subtotal       numeric(12,2) NOT NULL,
  modifiers_json jsonb NOT NULL DEFAULT '[]'::jsonb,
  note           text NOT NULL DEFAULT '',
  created_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_qr_request_items PRIMARY KEY (id),
  CONSTRAINT chk_qr_request_items_qty CHECK (quantity > 0),
  CONSTRAINT chk_qr_request_items_unit_price CHECK (unit_price >= 0.00),
  CONSTRAINT chk_qr_request_items_subtotal CHECK (subtotal >= 0.00 AND subtotal = unit_price * quantity),
  CONSTRAINT chk_qr_request_items_modifiers_array CHECK (jsonb_typeof(modifiers_json) = 'array')
);
CREATE INDEX idx_qr_request_items_request ON public.qr_request_items(request_id);

ALTER TABLE public.qr_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_request_items FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.qr_request_items FROM PUBLIC, anon, authenticated;

-- 4. qr_audit_logs
CREATE TABLE public.qr_audit_logs (
  id                      uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id                uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  request_id              uuid REFERENCES public.qr_requests(id) ON DELETE SET NULL,
  actor_type              text NOT NULL,
  actor_user_account_id   uuid REFERENCES public.user_accounts(id) ON DELETE SET NULL,
  actor_staff_id          uuid REFERENCES public.staff_members(id) ON DELETE SET NULL,
  action                  text NOT NULL,
  from_status             text,
  to_status               text,
  payload                 jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_qr_audit_logs PRIMARY KEY (id),
  CONSTRAINT chk_qr_audit_actor_type CHECK (actor_type IN ('customer', 'staff', 'system')),
  CONSTRAINT chk_qr_audit_actor_principal CHECK (
    (actor_type IN ('customer', 'system') AND actor_user_account_id IS NULL AND actor_staff_id IS NULL)
    OR
    (actor_type = 'staff' AND (
      (actor_user_account_id IS NOT NULL AND actor_staff_id IS NULL) OR
      (actor_user_account_id IS NULL AND actor_staff_id IS NOT NULL)
    ))
  )
);
CREATE INDEX idx_qr_audit_logs_store ON public.qr_audit_logs(store_id, created_at);

ALTER TABLE public.qr_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_audit_logs FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.qr_audit_logs FROM PUBLIC, anon, authenticated;

-- 5. product_topping_links
CREATE TABLE public.product_topping_links (
  product_id  uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  topping_id  uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  sort_order  integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_product_topping_links PRIMARY KEY (product_id, topping_id),
  CONSTRAINT chk_topping_self_reference CHECK (product_id <> topping_id)
);
CREATE INDEX idx_topping_links_topping ON public.product_topping_links(topping_id);

ALTER TABLE public.product_topping_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_topping_links FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.product_topping_links FROM PUBLIC, anon, authenticated;

-- Postflight Integrity Verification for ALL 5 created tables
DO $$
DECLARE
  v_tbl text;
BEGIN
  FOR v_tbl IN VALUES ('qr_channels'), ('qr_requests'), ('qr_request_items'), ('qr_audit_logs'), ('product_topping_links') LOOP
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = v_tbl) THEN
      RAISE EXCEPTION 'MIGRATION_01_POSTFLIGHT_FAIL: Table public.% missing', v_tbl;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = v_tbl AND c.relrowsecurity = true AND c.relforcerowsecurity = true
    ) THEN
      RAISE EXCEPTION 'MIGRATION_01_POSTFLIGHT_FAIL: RLS not enabled/forced on public.%', v_tbl;
    END IF;
  END LOOP;
END $$;
