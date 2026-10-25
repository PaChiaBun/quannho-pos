-- ============================================================================
-- TEST: Boom AI v4 (20261024_boom_ai_v4_cham_diem.sql) — 👍/👎 câu trả lời không gọi GPT. Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._cd_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._cd_try(p_sql text)
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
  S uuid := gen_random_uuid();
  r jsonb;
  t text;
BEGIN
  RAISE NOTICE '>>> BOOM AI v4: BẮT ĐẦU <<<';
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu CD');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status) VALUES (S, 'D' || substr(S::text, 1, 7), 'Quan CD', A, 'trial');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S, 'owner', true);

  EXECUTE 'SET LOCAL ROLE service_role';
  r := public.boom_feedback_v1(S, A, 'doanh thu tháng này', 'Tháng này đạt 0đ', 'down', 'sai kỳ', 'orders_summary_read_only', 2);
  PERFORM public._cd_ok((r->>'ok')::boolean, '1 ghi phiếu chấm câu số liệu');
  PERFORM public._cd_ok((SELECT status = 'feedback' AND rating = 'down' AND rating_reason = 'sai kỳ'
                         AND model = 'orders_summary_read_only' AND cost_usd = 0 AND rated_at IS NOT NULL
                         FROM public.boom_qa_log WHERE id = (r->>'id')::uuid), '2 dòng feedback đủ thông tin, chi phí 0');
  r := public.boom_feedback_v1(S, A, 'x', 'y', 'meh', NULL, NULL, 9);
  PERFORM public._cd_ok(r->>'status' = 'bad_request', '3 chấm giá trị lạ bị từ chối');
  r := public.boom_feedback_v1(S, A, 'x', 'y', NULL, NULL, NULL, 9);
  PERFORM public._cd_ok(r->>'status' = 'bad_request', '3b chấm rỗng bị từ chối');
  r := public.boom_feedback_v1(S, A, 'câu 2', 'y', 'up', NULL, NULL, 2);
  r := public.boom_feedback_v1(S, A, 'câu 3', 'y', 'up', NULL, NULL, 2);
  PERFORM public._cd_ok(r->>'status' = 'rate_limited', '4 hạn mức / người / giờ');

  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'authenticated', 'sub', A::text)::text, true);
  t := public._cd_try(format('SELECT public.boom_feedback_v1(%L, %L, %L, %L, %L, NULL, NULL, 99)', S, A, 'q', 'a', 'up'));
  PERFORM public._cd_ok(t LIKE 'err:42501', '5 app không tự ghi phiếu (chỉ qua hàm máy chủ) (' || t || ')');

  EXECUTE 'RESET ROLE';
  RAISE NOTICE '>>> BOOM AI v4: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
