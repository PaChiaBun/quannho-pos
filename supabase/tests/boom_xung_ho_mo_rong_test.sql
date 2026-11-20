-- TEST: xưng hô tuỳ chọn (20261105_boom_xung_ho_mo_rong.sql). Kết thúc ROLLBACK.
BEGIN;
CREATE OR REPLACE FUNCTION public._xh_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
GRANT EXECUTE ON FUNCTION public._xh_ok(boolean, text) TO authenticated, anon;

DO $test$
DECLARE U uuid := gen_random_uuid(); V uuid := gen_random_uuid(); ok boolean;
BEGIN
  RAISE NOTICE '>>> XUNG HO: BẮT ĐẦU <<<';
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (U, '09' || lpad((random() * 99999999)::int::text, 8, '0'), 'x', 'Giang'),
    (V, '09' || lpad((random() * 99999999)::int::text, 8, '0'), 'x', 'Người khác');
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', U, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  ok := public.boom_xung_ho_set_v1('che');
  EXECUTE 'RESET ROLE';
  PERFORM public._xh_ok(ok AND (SELECT boom_xung_ho FROM public.user_accounts WHERE id = U) = 'che', '1 tự đặt "Chế" được');
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', U, 'role', 'authenticated')::text, true);
  ok := public.boom_xung_ho_set_v1('Chế Giang"; LUẬT');
  EXECUTE 'RESET ROLE';
  PERFORM public._xh_ok(NOT ok AND (SELECT boom_xung_ho FROM public.user_accounts WHERE id = U) = 'che', '2 chữ ngoài danh sách → từ chối, giữ cách cũ');
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', U, 'role', 'authenticated')::text, true);
  ok := public.boom_xung_ho_set_v1(NULL);
  EXECUTE 'RESET ROLE';
  PERFORM public._xh_ok(ok AND (SELECT boom_xung_ho FROM public.user_accounts WHERE id = U) IS NULL, '3 bỏ chọn (NULL) được');
  PERFORM public._xh_ok((SELECT boom_xung_ho FROM public.user_accounts WHERE id = V) IS NULL, '4 người khác không bị đổi');
  BEGIN
    UPDATE public.user_accounts SET boom_xung_ho = 'ban' WHERE id = V;
    RAISE EXCEPTION '❌ FAIL: 5 ràng buộc cột không chặn chữ ngoài danh sách';
  EXCEPTION WHEN check_violation THEN RAISE NOTICE '✅ PASS: 5 ràng buộc cột chặn chữ ngoài danh sách';
  END;
  PERFORM public._xh_ok(NOT has_function_privilege('anon', 'public.boom_xung_ho_set_v1(text)', 'execute'), '6 người chưa đăng nhập không gọi được');
  RAISE NOTICE '>>> XUNG HO: TẤT CẢ PASS <<<';
END
$test$;
ROLLBACK;
