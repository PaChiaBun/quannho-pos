-- Hoàn tác 20261112_boom_bo_nho_quan_v3.sql (chỉ bỏ cột mốc dọn; ghi nhớ không đổi).
BEGIN;
ALTER TABLE public.boom_quan_ho_so DROP COLUMN IF EXISTS don_luc;
COMMIT;
