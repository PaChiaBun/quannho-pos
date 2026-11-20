-- ============================================================================
-- TEST: Boom AI v3 (20261024_boom_ai_v3_bo_nho.sql) — bộ nhớ câu trả lời đã duyệt. Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._bn_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._bn_as(p_role text, p_uid uuid)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_uid IS NULL THEN '' ELSE json_build_object('role', 'authenticated', 'sub', p_uid::text)::text END, true);
  PERFORM set_config('request.headers', '', true);
  IF p_role IS NOT NULL THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
END
$f$;

CREATE OR REPLACE FUNCTION public._bn_try(p_sql text)
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
DECLARE
  A uuid := gen_random_uuid();   -- chủ quán
  W uuid := gen_random_uuid();   -- phục vụ cùng quán
  X uuid := gen_random_uuid();   -- chủ quán khác
  S uuid := gen_random_uuid();
  S2 uuid := gen_random_uuid();
  S3 uuid := gen_random_uuid();
  r3 jsonb; r4 jsonb;
  C uuid;
  r jsonb; r2 jsonb;
  t text;
  n integer;
BEGIN
  RAISE NOTICE '>>> BOOM AI v3: BẮT ĐẦU <<<';
  PERFORM public._bn_as(NULL, NULL);
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu BN'),
    (W, '+84' || (800000000 + (random()*99999999)::int), 'x', 'NV BN'),
    (X, '+84' || (700000000 + (random()*99999999)::int), 'x', 'Chu BN2');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status) VALUES
    (S, 'N' || substr(S::text, 1, 7), 'Quan BN', A, 'trial'),
    (S2, 'M' || substr(S2::text, 1, 7), 'Quan BN2', X, 'active');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S, 'owner', true), (W, S, 'waiter', false), (X, S2, 'owner', true);
  UPDATE public.stores SET created_at = now() - interval '30 days' WHERE id IN (S, S2);   -- quán cũ: phiếu được tính

  -- Script duyệt (supabase_admin) thêm câu đã duyệt
  INSERT INTO public.boom_answer_cache (kind, questions, chunk_ids, chunk_hash, answer, approved_by)
  VALUES ('guide', '{"huỷ món đã gửi bếp"}', '{quan-ly-ban#huy}', 'abc', '1. Bấm "Huỷ món".', 'claude')
  RETURNING id INTO C;
  t := public._bn_try($$INSERT INTO public.boom_answer_cache (kind, questions, answer, approved_by) VALUES ('guide', '{x}', 'y', 'z')$$);
  PERFORM public._bn_ok(t LIKE 'err:23514', '1 câu loại hướng dẫn bắt buộc có mã đoạn + mã băm (' || t || ')');

  -- Hàm máy chủ
  PERFORM public._bn_as('service_role', NULL);
  r := public.boom_cache_hit_v1(S, A, 'huỷ món đã gửi bếp', C, 3);
  PERFORM public._bn_ok((r->>'ok')::boolean AND r->>'answer' = '1. Bấm "Huỷ món".', '2 trả câu đã duyệt');
  PERFORM public._bn_ok((SELECT status = 'cached' AND cost_usd = 0 AND cache_id = C AND model = 'cache' AND answer IS NOT NULL
                         FROM public.boom_qa_log WHERE id = (r->>'id')::uuid), '3 ghi sổ cached, chi phí 0');
  PERFORM public._bn_ok((SELECT hits FROM public.boom_answer_cache WHERE id = C) = 1, '4 đếm lượt dùng');
  r2 := public.boom_cache_hit_v1(S, W, 'huỷ món đã gửi bếp', C, 3);
  PERFORM public._bn_ok((r2->>'ok')::boolean, '5 người thứ hai dùng được');
  r3 := public.boom_cache_hit_v1(S2, X, 'huỷ món đã gửi bếp', C, 3);
  PERFORM public._bn_ok((r3->>'ok')::boolean, '5b quán khác dùng chung câu đã duyệt');
  t := public._bn_try($$UPDATE public.boom_answer_cache SET answer = 'x'$$);
  PERFORM public._bn_ok(t LIKE 'err:42501', '5c hàm máy chủ chỉ đọc bộ nhớ, không sửa (' || t || ')');

  -- App (JWT) không đọc / ghi bộ nhớ
  PERFORM public._bn_as('authenticated', A);
  t := public._bn_try('SELECT 1 FROM public.boom_answer_cache');
  PERFORM public._bn_ok(t LIKE 'err:42501', '6 app không đọc bộ nhớ (' || t || ')');
  t := public._bn_try($$UPDATE public.boom_answer_cache SET answer = 'x'$$);
  PERFORM public._bn_ok(t LIKE 'err:42501', '7 app không sửa bộ nhớ (' || t || ')');
  t := public._bn_try(format('SELECT public.boom_cache_hit_v1(%L, %L, %L, %L, 99)', S, A, 'x', C));
  PERFORM public._bn_ok(t LIKE 'err:42501', '8 app không tự ghi lượt bộ nhớ (' || t || ')');

  -- 👍/👎: chấm lại không đếm hai lần; 2 người 👎 → tự gỡ
  PERFORM public._bn_ok(public.boom_rate_answer_v1((r->>'id')::uuid, 'down', NULL), '9 chủ quán 👎 câu từ bộ nhớ');
  PERFORM public._bn_ok(public.boom_rate_answer_v1((r->>'id')::uuid, 'up', NULL), '10 đổi thành 👍');
  PERFORM public._bn_ok(public.boom_rate_answer_v1((r->>'id')::uuid, 'down', NULL), '11 đổi lại 👎');
  PERFORM public._bn_as(NULL, NULL);
  PERFORM public._bn_ok((SELECT ups = 0 AND downs = 1 AND status = 'approved' FROM public.boom_answer_cache WHERE id = C),
    '12 chấm lại không đếm hai lần: 0 👍, 1 👎, chưa gỡ');
  PERFORM public._bn_as('authenticated', W);
  PERFORM public._bn_ok(NOT public.boom_rate_answer_v1((r->>'id')::uuid, 'down', NULL), '13 không chấm hộ câu người khác');
  PERFORM public._bn_ok(public.boom_rate_answer_v1((r2->>'id')::uuid, 'down', 'sai'), '14 người thứ hai CÙNG QUÁN 👎');
  PERFORM public._bn_as(NULL, NULL);
  PERFORM public._bn_ok((SELECT status = 'approved' AND downs = 1 FROM public.boom_answer_cache WHERE id = C),
    '14b một quán chê nhiều lần chỉ tính 1 → chưa gỡ (chống một người gỡ câu dùng chung)');
  -- Chủ quán A mở thêm quán S3 rồi 👎 ở đó: vẫn chỉ tính 1 phiếu
  PERFORM public._bn_as(NULL, NULL);
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status) VALUES (S3, 'P' || substr(S3::text, 1, 7), 'Quan BN3', A, 'trial');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S3, 'owner', true);
  PERFORM public._bn_as('service_role', NULL);
  r4 := public.boom_cache_hit_v1(S3, A, 'huỷ món đã gửi bếp', C, 9);
  PERFORM public._bn_as('authenticated', A);
  PERFORM public._bn_ok(public.boom_rate_answer_v1((r4->>'id')::uuid, 'down', NULL), '14d chủ quán A 👎 ở quán thứ hai của mình');
  PERFORM public._bn_as(NULL, NULL);
  PERFORM public._bn_ok((SELECT status = 'approved' AND downs = 1 FROM public.boom_answer_cache WHERE id = C),
    '14e quán mới mở (< 7 ngày) / một người nhiều quán không thêm phiếu → chưa gỡ');
  PERFORM public._bn_as('authenticated', X);
  PERFORM public._bn_ok(public.boom_rate_answer_v1((r3->>'id')::uuid, 'down', NULL), '14c chủ quán khác 👎');
  PERFORM public._bn_as(NULL, NULL);
  PERFORM public._bn_ok((SELECT status = 'retired' AND downs = 2 FROM public.boom_answer_cache WHERE id = C), '15 👎 từ 2 chủ quán → tự gỡ');

  PERFORM public._bn_as('service_role', NULL);
  r := public.boom_cache_hit_v1(S2, X, 'huỷ món đã gửi bếp', C, 9);
  PERFORM public._bn_ok(r->>'status' = 'retired' AND r->>'id' IS NULL, '16 câu đã gỡ không trả nữa, không ghi dòng');

  -- Hạn mức "không tốn tiền" dùng chung (câu bị chặn / chưa có hướng dẫn / bộ nhớ)
  PERFORM public._bn_as(NULL, NULL);
  UPDATE public.boom_answer_cache SET status = 'approved' WHERE id = C;
  PERFORM public._bn_as('service_role', NULL);
  r := public.boom_ai_reserve_v1(S, A, 'câu lạ', '{}', 'blocked', 30, 3, 0.5, 3, 10);
  r := public.boom_cache_hit_v1(S, A, 'huỷ món', C, 2);
  PERFORM public._bn_ok(r->>'status' = 'rate_limited', '17 hạn mức bộ nhớ tính cả câu bị chặn → đủ lượt/giờ thì chặn');

  -- 👍 vẫn chấm được câu GPT thường
  PERFORM public._bn_as(NULL, NULL);
  INSERT INTO public.boom_qa_log (store_id, user_id, question, status) VALUES (S, A, 'q', 'ok') RETURNING id INTO C;
  PERFORM public._bn_as('authenticated', A);
  PERFORM public._bn_ok(public.boom_rate_answer_v1(C, 'up', NULL), '18 chấm câu GPT thường như cũ');

  PERFORM public._bn_as(NULL, NULL);
  RAISE NOTICE '>>> BOOM AI v3: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
