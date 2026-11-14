-- TEST: Boom AI v5 (20261024_boom_ai_v5_xung_ho.sql) — Anh / Chị theo tài khoản. Kết thúc ROLLBACK.
BEGIN;
CREATE OR REPLACE FUNCTION public._xh_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._xh_try(p_sql text)
RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE p_sql;
  RETURN 'ok';
EXCEPTION WHEN OTHERS THEN
  RETURN 'err:' || SQLSTATE;
END
$f$;
DO $test$
DECLARE
  A uuid := gen_random_uuid();
  B uuid := gen_random_uuid();
  t text;
BEGIN
  RAISE NOTICE '>>> BOOM AI v5: BẮT ĐẦU <<<';
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Nguyễn Văn An'),
    (B, '+84' || (800000000 + (random()*99999999)::int), 'x', 'Lê Bình');
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'authenticated', 'sub', A::text)::text, true);
  PERFORM public._xh_ok((public.boom_xung_ho_get_v1()->>'ten') = 'Nguyễn Văn An'
                        AND public.boom_xung_ho_get_v1()->'xung_ho' = 'null'::jsonb, '1 chưa chọn → xung_ho null, có tên');
  PERFORM public._xh_ok(public.boom_xung_ho_set_v1('anh'), '2 tự đặt "anh"');
  PERFORM public._xh_ok(public.boom_xung_ho_get_v1()->>'xung_ho' = 'anh', '3 đọc lại "anh"');
  PERFORM public._xh_ok(NOT public.boom_xung_ho_set_v1('ong'), '4 giá trị lạ bị từ chối');
  PERFORM public._xh_ok(public.boom_xung_ho_set_v1(NULL), '5 bỏ chọn được');
  PERFORM public._xh_ok(public.boom_xung_ho_set_v1('chi'), '6 đổi sang "chi"');
  -- cột mới không đọc / sửa thẳng qua bảng được (chỉ qua 2 hàm)
  t := public._xh_try('SELECT boom_xung_ho FROM public.user_accounts LIMIT 1');
  PERFORM public._xh_ok(t LIKE 'err:42501', '6b không đọc thẳng cột qua bảng (' || t || ')');
  t := public._xh_try(format('UPDATE public.user_accounts SET boom_xung_ho = %L WHERE id = %L', 'anh', B));
  PERFORM public._xh_ok(t LIKE 'err:42501', '6c không sửa thẳng của người khác (' || t || ')');
  -- chỉ đặt cho chính mình
  EXECUTE 'RESET ROLE';
  PERFORM public._xh_ok((SELECT boom_xung_ho FROM public.user_accounts WHERE id = B) IS NULL, '7 không đụng tài khoản người khác');
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM set_config('request.jwt.claims', '', true);
  t := public._xh_try('SELECT public.boom_xung_ho_set_v1(''anh'')');
  PERFORM public._xh_ok(t LIKE 'err:42501', '8 khách (anon) không gọi được (' || t || ')');
  EXECUTE 'RESET ROLE';
  RAISE NOTICE '>>> BOOM AI v5: TẤT CẢ PASS <<<';
END
$test$;
ROLLBACK;
