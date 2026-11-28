-- =============================================================================
-- Migration: 20261001_fix_purchase_orders_total_cost_and_amount.sql
-- Mục tiêu: Khắc phục lỗi vi phạm ràng buộc NOT NULL total_cost (mã 23502) khi tạo
--           phiếu nhập hàng; đảm bảo tính tương thích hai chiều giữa total_cost 
--           và total_amount trên bảng purchase_orders và purchase_items.
-- Quy chuẩn: Idempotent, Non-destructive, Backward & Forward Compatible.
-- =============================================================================

-- 1. Đảm bảo cột total_amount tồn tại và có giá trị mặc định là 0
ALTER TABLE public.purchase_orders 
  ADD COLUMN IF NOT EXISTS total_amount numeric DEFAULT 0;

-- 2. Đảm bảo cột total_cost tồn tại và có giá trị mặc định là 0
ALTER TABLE public.purchase_orders 
  ADD COLUMN IF NOT EXISTS total_cost numeric DEFAULT 0;

-- 3. Nới lỏng ràng buộc NOT NULL của total_cost và thiết lập DEFAULT 0
ALTER TABLE public.purchase_orders 
  ALTER COLUMN total_cost DROP NOT NULL;

ALTER TABLE public.purchase_orders 
  ALTER COLUMN total_cost SET DEFAULT 0;

ALTER TABLE public.purchase_orders 
  ALTER COLUMN total_amount SET DEFAULT 0;

-- 4. Bổ sung các cột mở rộng nếu CSDL môi trường cũ chưa có
ALTER TABLE public.purchase_orders 
  ADD COLUMN IF NOT EXISTS po_number text,
  ADD COLUMN IF NOT EXISTS supplier_name text DEFAULT '',
  ADD COLUMN IF NOT EXISTS invoice_image_url text;

-- 5. Đồng bộ dữ liệu cũ (Backfill) giữa 2 cột để không bị hụt số liệu báo cáo
UPDATE public.purchase_orders 
  SET total_amount = COALESCE(total_cost, 0) 
  WHERE total_amount IS NULL OR total_amount = 0;

UPDATE public.purchase_orders 
  SET total_cost = COALESCE(total_amount, 0) 
  WHERE total_cost IS NULL;

-- 6. Tương thích cấu trúc purchase_items (hỗ trợ cả po_id lẫn purchase_id và subtotal)
ALTER TABLE public.purchase_items 
  ADD COLUMN IF NOT EXISTS po_id uuid REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS subtotal numeric DEFAULT 0;

-- Backfill po_id từ purchase_id nếu cột purchase_id đang lưu dữ liệu cũ
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'purchase_items' AND column_name = 'purchase_id'
  ) THEN
    UPDATE public.purchase_items 
    SET po_id = purchase_id 
    WHERE po_id IS NULL AND purchase_id IS NOT NULL;
  END IF;
END $$;

-- 7. Cấp quyền truy cập cho anon, authenticated, service_role
GRANT SELECT, INSERT, UPDATE, DELETE ON public.purchase_orders TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.purchase_items TO anon, authenticated, service_role;
