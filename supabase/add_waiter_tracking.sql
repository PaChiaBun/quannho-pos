-- ═══════════════════════════════════════════════════════════════════════════
-- ADD WAITER TRACKING — Thêm cột waiter_id vào ban_sessions và orders
-- Chạy trong Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Thêm cột waiter_id vào bảng ban_sessions (nhân viên mở bàn)
ALTER TABLE public.ban_sessions 
ADD COLUMN IF NOT EXISTS waiter_id uuid REFERENCES public.staff_members(id);

-- 2. Thêm cột waiter_id vào bảng orders (nhân viên order)
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS waiter_id uuid REFERENCES public.staff_members(id);

-- 3. Tạo index để tối ưu hoá truy vấn thống kê
CREATE INDEX IF NOT EXISTS idx_orders_waiter ON public.orders(waiter_id);
CREATE INDEX IF NOT EXISTS idx_ban_sessions_waiter ON public.ban_sessions(waiter_id);
