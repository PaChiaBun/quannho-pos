-- ============================================================================
-- XƯNG HÔ TUỲ CHỌN cho Bé Boom (Chủ Quán 26/10 chấm sai "Gọi chế xưng bé" bị từ chối — trước chỉ 'anh' / 'chi').
-- Danh sách CỐ ĐỊNH (giống app boom_xung_ho.dart + hàm boom-chat DANH_XUNG): anh, chi, em, co, chu, bac, che, ong, ba, di, thay.
-- Chỉ đổi ràng buộc cột + hàm tự đặt; người dùng vẫn chỉ đặt được cho CHÍNH mình. Hoàn tác: …_ROLLBACK.sql.
-- ============================================================================
BEGIN;

ALTER TABLE public.user_accounts DROP CONSTRAINT IF EXISTS user_accounts_boom_xung_ho_check;
ALTER TABLE public.user_accounts ADD CONSTRAINT user_accounts_boom_xung_ho_check
  CHECK (boom_xung_ho IS NULL OR boom_xung_ho IN ('anh', 'chi', 'em', 'co', 'chu', 'bac', 'che', 'ong', 'ba', 'di', 'thay'));

CREATE OR REPLACE FUNCTION public.boom_xung_ho_set_v1(p_xung_ho text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE n integer;
BEGIN
  IF auth.uid() IS NULL OR (p_xung_ho IS NOT NULL
       AND p_xung_ho NOT IN ('anh', 'chi', 'em', 'co', 'chu', 'bac', 'che', 'ong', 'ba', 'di', 'thay')) THEN
    RETURN false;
  END IF;
  UPDATE public.user_accounts SET boom_xung_ho = p_xung_ho WHERE id = auth.uid();
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n = 1;
END
$$;

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.boom_xung_ho_set_v1(text)', 'execute')
     OR NOT has_function_privilege('authenticated', 'public.boom_xung_ho_set_v1(text)', 'execute') THEN
    RAISE EXCEPTION 'XUNG HO: quyền không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
