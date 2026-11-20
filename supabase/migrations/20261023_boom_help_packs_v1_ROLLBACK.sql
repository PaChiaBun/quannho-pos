-- HOÀN TÁC 20261023_boom_help_packs_v1.sql — app tự quay về bộ hướng dẫn đóng gói.
BEGIN;
DROP TABLE IF EXISTS public.boom_help_packs;
COMMIT;
NOTIFY pgrst, 'reload schema';
