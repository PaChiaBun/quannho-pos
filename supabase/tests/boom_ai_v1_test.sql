-- ============================================================================
-- TEST: Boom AI v1 (20261023_boom_ai_v1.sql) — sổ hỏi đáp, giữ chỗ hạn mức, 👍/👎. Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._ba_app(p_uid uuid, p_store uuid)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.headers',
    json_build_object('x-store-id', p_store::text, 'x-user-id', p_uid::text)::text, true);
END
$f$;

CREATE OR REPLACE FUNCTION public._ba_jwt(p_uid uuid, p_store uuid)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'authenticated', 'sub', p_uid::text)::text, true);
  PERFORM set_config('request.headers', json_build_object('x-store-id', p_store::text)::text, true);
END
$f$;

CREATE OR REPLACE FUNCTION public._ba_admin()
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.headers', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
END
$f$;

CREATE OR REPLACE FUNCTION public._ba_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._ba_try(p_sql text)
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

CREATE OR REPLACE FUNCTION public._ba_reserve(p_store uuid, p_user uuid, p_mode text DEFAULT 'answer')
RETURNS jsonb LANGUAGE sql AS $f$
  SELECT public.boom_ai_reserve_v1(p_store, p_user, 'huỷ món', '{quan-ly-ban#a}', p_mode, 2, 1, 0.5, 3, 10)
$f$;

DO $test$
DECLARE
  A  uuid := gen_random_uuid();   -- chủ quán S
  W  uuid := gen_random_uuid();   -- phục vụ S
  X  uuid := gen_random_uuid();   -- chủ quán S2
  S  uuid := gen_random_uuid();
  S2 uuid := gen_random_uuid();
  S3 uuid := gen_random_uuid();   -- quán bị khoá
  r  jsonb; r2 jsonb;
  t  text;
  n  integer;
  b  boolean;
BEGIN
  RAISE NOTICE '>>> BOOM AI v1: BẮT ĐẦU <<<';
  PERFORM public._ba_admin();
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A'),
    (W, '+84' || (800000000 + (random()*99999999)::int), 'x', 'Phuc vu W'),
    (X, '+84' || (700000000 + (random()*99999999)::int), 'x', 'Chu X');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status) VALUES
    (S,  'B' || substr(S::text, 1, 7),  'Quan BA',  A, 'trial'),
    (S2, 'B' || substr(S2::text, 1, 7), 'Quan BA2', X, 'active'),
    (S3, 'B' || substr(S3::text, 1, 7), 'Quan BA3', X, 'suspended');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S, 'owner', true), (W, S, 'waiter', false), (X, S2, 'owner', true);

  -- ── Hàm máy chủ (service_role): giữ chỗ / ghi kết quả ──
  EXECUTE 'SET LOCAL ROLE service_role';
  r := public._ba_reserve(S, W);
  PERFORM public._ba_ok((r->>'ok')::boolean AND r->>'status' = 'pending', '1 giữ chỗ lượt 1');
  b := public.boom_ai_finish_v1((r->>'id')::uuid, 'ok', 'Bấm "Huỷ món"', 'gpt-4o-mini', 1500, 200, 0.000345, 900);
  PERFORM public._ba_ok(b, '2 ghi kết quả vào lượt đã giữ chỗ');
  b := public.boom_ai_finish_v1((r->>'id')::uuid, 'ok', 'ghi đè', 'x', 1, 1, 9, 1);
  PERFORM public._ba_ok(NOT b, '3 không ghi đè lượt đã xong');
  r2 := public._ba_reserve(S, W);
  PERFORM public._ba_ok((r2->>'ok')::boolean, '4 giữ chỗ lượt 2 (đang chờ GPT)');
  r2 := public._ba_reserve(S, W);
  PERFORM public._ba_ok(r2->>'status' = 'rate_limited', '5 lượt 3 bị chặn — lượt đang chờ cũng tính (chống gửi dồn)');
  SELECT count(*) INTO n FROM public.boom_qa_log WHERE user_id = W AND status = 'rate_limited';
  PERFORM public._ba_ok(n = 0 AND r2->>'id' IS NULL, '5b lượt bị chặn không ghi dòng (gửi lặp không làm phình sổ)');
  PERFORM public._ba_ok((SELECT cost_usd FROM public.boom_qa_log WHERE status = 'pending' AND user_id = W LIMIT 1) = 0.001,
    '5c lượt đang chờ tính tạm chi phí ước lượng');
  r2 := public._ba_reserve(S, W, 'log_only');
  PERFORM public._ba_ok(r2->>'status' = 'no_context', '6 câu không có hướng dẫn: ghi hàng chờ');
  r2 := public._ba_reserve(S, W, 'log_only');
  PERFORM public._ba_ok(NOT (r2->>'ok')::boolean AND r2->>'status' = 'rate_limited' AND r2->>'id' IS NULL,
    '7 hàng chờ có hạn mức riêng, quá thì không ghi thêm dòng');
  r2 := public._ba_reserve(S3, X);
  PERFORM public._ba_ok(r2->>'status' = 'inactive_store', '8 quán bị khoá không dùng GPT');
  INSERT INTO public.boom_qa_log (store_id, user_id, question, cost_usd, status) VALUES (S2, X, 'cũ', 3, 'ok');
  r2 := public._ba_reserve(S2, X);
  PERFORM public._ba_ok(r2->>'status' = 'budget', '9 hết hạn mức tiền của quán trong tháng');
  INSERT INTO public.boom_qa_log (store_id, user_id, question, status, created_at)
    VALUES (S, W, 'rất cũ', 'ok', now() - interval '200 days');
  r2 := public._ba_reserve(S, A, 'log_only');
  SELECT count(*) INTO n FROM public.boom_qa_log WHERE store_id = S AND question = 'rất cũ';
  PERFORM public._ba_ok(n = 0, '10 sổ quá 180 ngày tự dọn');
  PERFORM public._ba_admin();

  -- ── App ──
  PERFORM public._ba_app(W, S);
  t := public._ba_try(format($q$INSERT INTO public.boom_qa_log (store_id, user_id, question, status) VALUES (%L, %L, 'gia', 'ok')$q$, S, W));
  PERFORM public._ba_ok(t = 'err:42501', '11 app không ghi sổ được (' || t || ')');
  t := public._ba_try(format($q$SELECT public.boom_ai_reserve_v1(%L, %L, 'x', '{}', 'answer', 99, 99, 9, 9, 99)$q$, S, W));
  PERFORM public._ba_ok(t = 'err:42501', '12 app không tự giữ chỗ / nới hạn mức (' || t || ')');
  t := public._ba_try(format($q$SELECT public.boom_ai_finish_v1(%L, 'ok', 'x', 'x', 0, 0, 0, 0)$q$, (r->>'id')));
  PERFORM public._ba_ok(t = 'err:42501', '13 app không ghi kết quả (' || t || ')');

  PERFORM public._ba_app(A, S);   -- chủ quán nhưng KHÔNG có vé JWT (giả header)
  t := public._ba_try($q$SELECT 1 FROM public.boom_qa_log$q$);
  PERFORM public._ba_ok(t = 'err:42501', '14 giả header (không JWT) không đọc được sổ (' || t || ')');
  t := public._ba_try(format($q$SELECT public.boom_rate_answer_v1(%L, 'up')$q$, (r->>'id')));
  PERFORM public._ba_ok(t = 'err:42501', '15 giả header không chấm được (' || t || ')');

  PERFORM public._ba_jwt(A, S);
  SELECT count(*) INTO n FROM public.boom_qa_log;
  PERFORM public._ba_ok(n >= 3, '16 chủ quán đăng nhập JWT đọc được sổ quán mình (' || n || ')');
  b := public.boom_rate_answer_v1((r->>'id')::uuid, 'up');
  PERFORM public._ba_ok(NOT b, '17 không chấm thay câu của người khác');
  PERFORM public._ba_jwt(W, S);
  SELECT count(*) INTO n FROM public.boom_qa_log;
  PERFORM public._ba_ok(n = 0, '18 phục vụ không đọc sổ (' || n || ')');
  b := public.boom_rate_answer_v1((r->>'id')::uuid, 'down', 'sai tên nút');
  PERFORM public._ba_ok(b, '19 người hỏi chấm 👎 câu của mình');
  b := public.boom_rate_answer_v1((r->>'id')::uuid, 'tuyet', NULL);
  PERFORM public._ba_ok(NOT b, '20 không chấm giá trị lạ');
  PERFORM public._ba_jwt(X, S2);
  SELECT count(*) INTO n FROM public.boom_qa_log WHERE store_id = S;
  PERFORM public._ba_ok(n = 0, '21 quán khác không đọc được (' || n || ')');

  PERFORM public._ba_admin();
  PERFORM public._ba_ok((SELECT rating = 'down' AND rating_reason = 'sai tên nút' FROM public.boom_qa_log WHERE id = (r->>'id')::uuid),
    '22 👎 + lý do được lưu');

  RAISE NOTICE '>>> BOOM AI v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
