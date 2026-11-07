-- Hoàn tác 20261022_nap_vi_an_toan_v1.sql. Không đụng số dư khách / lịch sử ví / thu chi đã ghi.
-- Bảng wallet_topup_operations giữ lại để còn dấu vết (xoá tay nếu chắc chắn không cần).
DROP FUNCTION IF EXISTS public.topup_customer_wallet_v1(uuid, uuid, numeric, text, text, integer, numeric, text);
