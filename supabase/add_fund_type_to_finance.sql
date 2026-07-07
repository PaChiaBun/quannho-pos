-- 1. Thêm cột fund_type vào bảng finance_records
ALTER TABLE public.finance_records 
ADD COLUMN IF NOT EXISTS fund_type text NOT NULL DEFAULT 'cash';

-- 2. Tối ưu hóa: Tạo index để truy vấn theo quỹ nhanh hơn
CREATE INDEX IF NOT EXISTS idx_finance_fund_type ON public.finance_records(store_id, fund_type);

-- 3. Khôi phục/Cập nhật dữ liệu cũ (Backfill)
-- Đối với các giao dịch tự động liên quan đến đơn hàng (orders) thanh toán bằng chuyển khoản hoặc thẻ ngân hàng:
UPDATE public.finance_records fr
SET fund_type = 'bank'
FROM public.orders o
WHERE fr.reference_id = o.id 
  AND o.payment_method IN ('transfer', 'card');
