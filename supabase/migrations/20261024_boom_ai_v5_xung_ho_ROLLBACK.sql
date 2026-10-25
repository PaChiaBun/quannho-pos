-- HOÀN TÁC 20261024_boom_ai_v5_xung_ho.sql — đưa hàm boom-chat bản trước về TRƯỚC (hàm mới đọc cột boom_xung_ho).
BEGIN;
DROP FUNCTION IF EXISTS public.boom_xung_ho_set_v1(text);
DROP FUNCTION IF EXISTS public.boom_xung_ho_get_v1();
ALTER TABLE public.user_accounts DROP COLUMN IF EXISTS boom_xung_ho;
COMMIT;
NOTIFY pgrst, 'reload schema';
