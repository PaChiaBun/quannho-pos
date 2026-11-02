-- Hoàn tác 20261103_boom_sales_raw_v1.sql — hàm boom-chat chế độ 'ask' sẽ trả số bán hàng trống (vẫn trả lời bằng 5 mục).
DROP FUNCTION IF EXISTS public.boom_sales_raw_v1(uuid, timestamptz, timestamptz);
NOTIFY pgrst, 'reload schema';
