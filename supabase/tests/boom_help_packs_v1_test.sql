-- ============================================================================
-- TEST: boom_help_packs v1 — chạy kiểu app thật (anon + header / authenticated + JWT). Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._bh_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._bh_try(p_sql text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE n integer;
BEGIN
  EXECUTE p_sql;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN 'ok:' || n;
EXCEPTION WHEN OTHERS THEN
  RETURN 'err:' || SQLSTATE;
END
$f$;

DO $test$
DECLARE t text; n integer;
BEGIN
  RAISE NOTICE '>>> BOOM HELP PACKS v1: BẮT ĐẦU <<<';
  -- quản trị đăng bản
  t := public._bh_try($q$INSERT INTO public.boom_help_packs (version, content, note)
        VALUES (202610230001, '{"version": 202610230001, "chunks": [{"id":"a"},{"id":"b"}]}', 'test')$q$);
  PERFORM public._bh_ok(t = 'ok:1', '1 quản trị đăng được bản hướng dẫn (' || t || ')');
  PERFORM public._bh_ok((SELECT chunk_count FROM public.boom_help_packs WHERE version = 202610230001) = 2,
    '1b tự đếm số đoạn');
  t := public._bh_try($q$INSERT INTO public.boom_help_packs (version, content)
        VALUES (202610230002, '{"version": 1, "chunks": []}')$q$);
  PERFORM public._bh_ok(t = 'err:23514', '1c version trong nội dung phải khớp (' || t || ')');
  t := public._bh_try($q$INSERT INTO public.boom_help_packs (version, content)
        VALUES (202610230003, '{"version": 202610230003, "chunks": "x"}')$q$);
  PERFORM public._bh_ok(t IN ('err:23514', 'err:22023'), '1d chunks phải là danh sách (' || t || ')');

  -- app (anon + header)
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM set_config('request.headers', '{"x-store-id":"00000000-0000-0000-0000-000000000001"}', true);
  SELECT count(*) INTO n FROM public.boom_help_packs WHERE version = 202610230001;
  PERFORM public._bh_ok(n = 1, '2 app đọc được bản hướng dẫn');
  t := public._bh_try($q$INSERT INTO public.boom_help_packs (version, content)
        VALUES (202610239999, '{"version": 202610239999, "chunks": []}')$q$);
  PERFORM public._bh_ok(t = 'err:42501', '3 app không đăng bản giả được (' || t || ')');
  t := public._bh_try($q$UPDATE public.boom_help_packs SET note = 'x'$q$);
  PERFORM public._bh_ok(t = 'err:42501', '4 app không sửa được (' || t || ')');
  t := public._bh_try($q$DELETE FROM public.boom_help_packs$q$);
  PERFORM public._bh_ok(t = 'err:42501', '5 app không xoá được (' || t || ')');

  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM set_config('request.jwt.claims', '{"role":"authenticated","sub":"00000000-0000-0000-0000-000000000002"}', true);
  SELECT count(*) INTO n FROM public.boom_help_packs WHERE version = 202610230001;
  PERFORM public._bh_ok(n = 1, '6 máy đăng nhập JWT đọc được');
  t := public._bh_try($q$INSERT INTO public.boom_help_packs (version, content)
        VALUES (202610239998, '{"version": 202610239998, "chunks": []}')$q$);
  PERFORM public._bh_ok(t = 'err:42501', '7 máy JWT không đăng được (' || t || ')');
  EXECUTE 'RESET ROLE';

  RAISE NOTICE '>>> BOOM HELP PACKS v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
