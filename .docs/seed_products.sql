-- MIGRATION: Tạo stock_movements, suppliers, finance_records
-- Chạy trên: https://supabase.com/dashboard → SQL Editor

-- ── 1. STOCK MOVEMENTS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stock_movements (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    UUID        NOT NULL,
  product_id  UUID        NOT NULL,
  delta       NUMERIC     NOT NULL,
  reason      TEXT        NOT NULL DEFAULT 'manual',
  note        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sm_store   ON stock_movements(store_id);
CREATE INDEX IF NOT EXISTS idx_sm_product ON stock_movements(product_id);

-- ── 2. SUPPLIERS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS suppliers (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id   UUID        NOT NULL,
  name       TEXT        NOT NULL,
  phone      TEXT,
  address    TEXT,
  note       TEXT,
  is_deleted BOOLEAN     NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sup_store ON suppliers(store_id);

-- ── 3. FINANCE RECORDS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS finance_records (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    UUID        NOT NULL,
  type        TEXT        NOT NULL,
  amount      NUMERIC     NOT NULL,
  description TEXT,
  is_auto     BOOLEAN     NOT NULL DEFAULT false,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_fr_store ON finance_records(store_id);
CREATE INDEX IF NOT EXISTS idx_fr_date  ON finance_records(recorded_at);

-- Reload schema
NOTIFY pgrst, 'reload schema';

-- Kiểm tra
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('stock_movements', 'suppliers', 'finance_records')
ORDER BY table_name;
