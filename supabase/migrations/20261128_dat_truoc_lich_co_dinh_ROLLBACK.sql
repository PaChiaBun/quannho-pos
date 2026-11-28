-- Hoàn tác 20261128_dat_truoc_lich_co_dinh.sql: bỏ hai hàm và cột chuoi_id (các buổi đã đặt vẫn còn, thành lượt lẻ).
DROP FUNCTION IF EXISTS public.ban_dat_truoc_lap_v1(uuid, text, text, text, timestamptz, integer, integer[], date, text, numeric, boolean);
DROP FUNCTION IF EXISTS public.ban_dat_truoc_huy_chuoi_v1(uuid, uuid, timestamptz);
DROP INDEX IF EXISTS public.ban_dat_truoc_chuoi_idx;
ALTER TABLE public.ban_dat_truoc DROP COLUMN IF EXISTS chuoi_id;
