-- ═══════════════════════════════════════════════════════════════════════════
-- BAN TABLES SYNC — Quản lý bàn real-time giữa chủ quán và nhân viên
-- Chạy trong Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Khu vực (zones) — Trong nhà, Ngoài trời, VIP...
CREATE TABLE IF NOT EXISTS public.ban_zones (
  id          text        PRIMARY KEY,
  store_id    uuid        NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name        text        NOT NULL,
  color       text        NOT NULL DEFAULT '#1C2151',
  icon_code   integer     NOT NULL DEFAULT 59672, -- 0xe318 = Icons.home_outlined
  sort_order  integer     NOT NULL DEFAULT 0,
  is_active   boolean     NOT NULL DEFAULT true,
  canvas_x    float8      NOT NULL DEFAULT 40,
  canvas_y    float8      NOT NULL DEFAULT 40,
  canvas_width  float8    NOT NULL DEFAULT 220,
  canvas_height float8    NOT NULL DEFAULT 160,
  created_at  bigint      NOT NULL,
  updated_at  bigint
);

-- 2. Bàn ăn
CREATE TABLE IF NOT EXISTS public.ban_dining_tables (
  id           text       PRIMARY KEY,
  store_id     uuid       NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  zone_id      text       NOT NULL REFERENCES public.ban_zones(id) ON DELETE CASCADE,
  name         text       NOT NULL,
  capacity     integer    NOT NULL DEFAULT 4,
  pos_x        float8     NOT NULL DEFAULT 100,
  pos_y        float8     NOT NULL DEFAULT 100,
  shape        text       NOT NULL DEFAULT 'rect',
  table_width  float8     NOT NULL DEFAULT 90,
  table_height float8     NOT NULL DEFAULT 65,
  qr_token     text,
  sort_order   integer    NOT NULL DEFAULT 0,
  is_active    boolean    NOT NULL DEFAULT true,
  created_at   bigint     NOT NULL,
  updated_at   bigint
);

-- ─── RLS ─────────────────────────────────────────────────────────────────────
ALTER TABLE public.ban_zones         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ban_dining_tables ENABLE ROW LEVEL SECURITY;

-- Tất cả thành viên quán đều ĐỌC được
CREATE POLICY "ban_zones: members read"
  ON public.ban_zones FOR SELECT
  USING (store_id IN (
    SELECT store_id FROM public.store_members WHERE user_id = auth.uid()
  ));

CREATE POLICY "ban_dining_tables: members read"
  ON public.ban_dining_tables FOR SELECT
  USING (store_id IN (
    SELECT store_id FROM public.store_members WHERE user_id = auth.uid()
  ));

-- Chỉ owner/manager được SỬA
CREATE POLICY "ban_zones: owner/manager write"
  ON public.ban_zones FOR ALL
  USING (store_id IN (
    SELECT store_id FROM public.store_members
    WHERE user_id = auth.uid() AND role IN ('owner', 'manager')
  ));

CREATE POLICY "ban_dining_tables: owner/manager write"
  ON public.ban_dining_tables FOR ALL
  USING (store_id IN (
    SELECT store_id FROM public.store_members
    WHERE user_id = auth.uid() AND role IN ('owner', 'manager')
  ));

-- ─── REALTIME ─────────────────────────────────────────────────────────────────
-- Chạy lệnh này để bật Realtime (hoặc enable qua Dashboard > Database > Replication)
ALTER PUBLICATION supabase_realtime ADD TABLE public.ban_zones;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ban_dining_tables;
