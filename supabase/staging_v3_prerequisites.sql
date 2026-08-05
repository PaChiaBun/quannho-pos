-- ═══════════════════════════════════════════════════════════════════════════
-- STAGING MIGRATION V3 PREREQUISITES SCRIPT
-- File: supabase/staging_v3_prerequisites.sql
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Base Column Amendments
ALTER TABLE stores ADD COLUMN IF NOT EXISTS slug text UNIQUE;
ALTER TABLE user_accounts ADD COLUMN IF NOT EXISTS quick_pin text;
ALTER TABLE products ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE products ADD COLUMN IF NOT EXISTS image_url text;
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_featured boolean DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS public_badge text;
ALTER TABLE products ADD COLUMN IF NOT EXISTS public_sort_order integer DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_topping boolean DEFAULT false;

-- 2. Product Topping Links Table
CREATE TABLE IF NOT EXISTS product_topping_links (
  product_id uuid NOT NULL,
  topping_id uuid NOT NULL,
  sort_order integer DEFAULT 0,
  PRIMARY KEY (product_id, topping_id)
);

CREATE INDEX IF NOT EXISTS idx_ptl_product ON product_topping_links(product_id);
CREATE INDEX IF NOT EXISTS idx_ptl_topping ON product_topping_links(topping_id);

-- 3. QR Channels Table
CREATE TABLE IF NOT EXISTS qr_channels (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id     uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  type         text NOT NULL DEFAULT 'table' CHECK (type IN ('table', 'counter')),
  table_id     text REFERENCES ban_dining_tables(id) ON DELETE SET NULL,
  channel_code text UNIQUE NOT NULL,
  name         text NOT NULL,
  is_active    boolean DEFAULT true,
  created_at   timestamptz DEFAULT now()
);

-- 4. QR Requests Table
CREATE TABLE IF NOT EXISTS qr_requests (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id         uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  channel_id       uuid REFERENCES qr_channels(id) ON DELETE SET NULL,
  type             text NOT NULL DEFAULT 'table' CHECK (type IN ('table', 'counter')),
  table_id         text,
  table_name       text,
  pickup_code      text,
  tracking_token   text UNIQUE NOT NULL,
  idempotency_key  text,
  status           text DEFAULT 'pending_staff',
  note             text,
  total_amount     numeric(12,0) DEFAULT 0,
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now()
);

-- Drop legacy status check constraints if existing
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN (
    SELECT conname 
    FROM pg_constraint 
    WHERE conrelid = 'public.qr_requests'::regclass AND contype = 'c'
  ) LOOP
    EXECUTE format('ALTER TABLE public.qr_requests DROP CONSTRAINT IF EXISTS %I', r.conname);
  END LOOP;
END $$;

-- Add Canonical V3 Status Constraint allowing 'confirmed'
ALTER TABLE public.qr_requests 
  ADD CONSTRAINT qr_requests_status_v3_check 
  CHECK (status IN ('pending_staff', 'processing', 'confirmed', 'sent_kitchen', 'rejected', 'expired'));

-- 5. QR Request Items Table
CREATE TABLE IF NOT EXISTS qr_request_items (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  request_id   uuid NOT NULL REFERENCES qr_requests(id) ON DELETE CASCADE,
  product_id   uuid NOT NULL,
  product_name text NOT NULL,
  unit_price   numeric(12,0) NOT NULL,
  quantity     integer NOT NULL CHECK (quantity > 0),
  subtotal     numeric(12,0) NOT NULL,
  note         text,
  toppings     jsonb DEFAULT '[]'::jsonb,
  created_at   timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE qr_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE qr_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE qr_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_topping_links ENABLE ROW LEVEL SECURITY;
