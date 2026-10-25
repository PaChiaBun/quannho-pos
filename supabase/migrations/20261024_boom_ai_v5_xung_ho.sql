-- ============================================================================
-- Boom AI v5 (24/10/2026) — Bé Boom gọi người dùng "Anh" / "Chị" + tên (Chủ Quán chốt: Boom hỏi một lần, nhớ theo
-- tài khoản — app chưa có giới tính, KHÔNG đoán theo tên).
-- • user_accounts.boom_xung_ho: 'anh' / 'chi' / NULL (chưa chọn → Boom gọi "Anh/Chị + tên").
-- • boom_xung_ho_get_v1(): tên hiển thị + cách xưng hô của CHÍNH người đăng nhập (JWT thật).
-- • boom_xung_ho_set_v1(p_xung_ho): người đăng nhập tự đặt cho mình ('anh' / 'chi' / NULL = bỏ chọn).
-- Hàm boom-chat (service_role) đọc thẳng cột để đưa vào câu dặn GPT.
-- ============================================================================
BEGIN;

ALTER TABLE public.user_accounts ADD COLUMN IF NOT EXISTS boom_xung_ho text
  CHECK (boom_xung_ho IS NULL OR boom_xung_ho IN ('anh', 'chi'));

CREATE OR REPLACE FUNCTION public.boom_xung_ho_get_v1()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE r record;
BEGIN
  IF auth.uid() IS NULL THEN RETURN NULL; END IF;
  SELECT display_name, boom_xung_ho INTO r FROM public.user_accounts WHERE id = auth.uid();
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN jsonb_build_object('ten', r.display_name, 'xung_ho', r.boom_xung_ho);
END
$$;

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

REVOKE ALL ON FUNCTION public.boom_xung_ho_get_v1() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.boom_xung_ho_set_v1(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.boom_xung_ho_get_v1() TO authenticated;
GRANT EXECUTE ON FUNCTION public.boom_xung_ho_set_v1(text) TO authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
