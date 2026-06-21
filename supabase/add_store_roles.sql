-- ═══════════════════════════════════════════════════════════════════════════
-- STORE ROLES — Custom role system
-- Chạy trong Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS store_roles (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id   uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  name       text NOT NULL,              -- "Thu ngân", "Barista", "Lễ tân"
  icon       text DEFAULT 'badge',       -- tên Material icon (vd: 'star', 'kitchen')
  color      text DEFAULT '#1C2151',     -- hex color
  modules    text DEFAULT '[]',          -- JSON: ["pos","ban",...]
  sort_order int  DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE (store_id, name)
);

-- Index
CREATE INDEX IF NOT EXISTS idx_store_roles_store ON store_roles(store_id, sort_order);

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON store_roles TO anon, authenticated;
ALTER TABLE store_roles DISABLE ROW LEVEL SECURITY;
