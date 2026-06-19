-- =====================================================================
-- LOYALTY FULL MIGRATION — Chạy 1 lần trên Supabase SQL Editor
-- Gồm: topup_packages + ban_session_void_logs + GRANT
-- =====================================================================

-- 1. Bảng gói nạp tiền (topup_packages)
CREATE TABLE IF NOT EXISTS public.topup_packages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,            -- 'Gói Vàng'
  min_amount  DOUBLE PRECISION NOT NULL DEFAULT 0,   -- nạp từ bao nhiêu mới áp dụng
  bonus_pct   DOUBLE PRECISION NOT NULL DEFAULT 0,   -- % thưởng thêm
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_topup_packages_store
  ON public.topup_packages(store_id, is_active, min_amount);

-- 2. Bảng log huỷ món (ban_session_void_logs)
CREATE TABLE IF NOT EXISTS public.ban_session_void_logs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  session_id    UUID,                   -- UUID phiên bàn
  table_label   TEXT,                   -- snapshot tên bàn
  product_name  TEXT NOT NULL,          -- snapshot tên món bị huỷ
  action        TEXT NOT NULL DEFAULT 'cancel',   -- 'cancel' | 'reduce'
  reason        TEXT,                   -- lý do huỷ do nhân viên chọn
  staff_name    TEXT,                   -- tên nhân viên thực hiện
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_void_logs_store
  ON public.ban_session_void_logs(store_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_void_logs_session
  ON public.ban_session_void_logs(session_id);

-- 3. GRANT quyền (đồng bộ với toàn dự án)
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.topup_packages TO anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.ban_session_void_logs TO anon, authenticated;

-- 4. Xác nhận
SELECT table_name, COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('topup_packages', 'ban_session_void_logs')
GROUP BY table_name
ORDER BY table_name;
