-- HOÀN TÁC 20261105_boom_xung_ho_mo_rong.sql — về chỉ 'anh' / 'chi'. Người đã chọn cách gọi khác bị đưa về "chưa chọn" (NULL).
BEGIN;
UPDATE public.user_accounts SET boom_xung_ho = NULL WHERE boom_xung_ho IS NOT NULL AND boom_xung_ho NOT IN ('anh', 'chi');
ALTER TABLE public.user_accounts DROP CONSTRAINT IF EXISTS user_accounts_boom_xung_ho_check;
ALTER TABLE public.user_accounts ADD CONSTRAINT user_accounts_boom_xung_ho_check
  CHECK (boom_xung_ho IS NULL OR boom_xung_ho IN ('anh', 'chi'));
CREATE OR REPLACE FUNCTION public.boom_xung_ho_set_v1(p_xung_ho text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE n integer;
BEGIN
  IF auth.uid() IS NULL OR (p_xung_ho IS NOT NULL AND p_xung_ho NOT IN ('anh', 'chi')) THEN RETURN false; END IF;
  UPDATE public.user_accounts SET boom_xung_ho = p_xung_ho WHERE id = auth.uid();
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n = 1;
END
$$;
COMMIT;
NOTIFY pgrst, 'reload schema';
