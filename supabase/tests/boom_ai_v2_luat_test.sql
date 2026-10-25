-- ============================================================================
-- TEST: Boom AI v2 (20261024_boom_ai_v2_luat.sql) — ghi sổ câu bị chặn ('blocked'), hạn mức chung với
-- câu "không có hướng dẫn", chế độ tư vấn ('advice') tính như lượt có gọi GPT. Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._bl_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._bl_reserve(p_store uuid, p_user uuid, p_mode text)
RETURNS jsonb LANGUAGE sql AS $f$
  SELECT public.boom_ai_reserve_v1(p_store, p_user, 'câu thử', '{}', p_mode, 2, 2, 0.5, 3, 10)
$f$;

DO $test$
DECLARE
  A uuid := gen_random_uuid();
  S uuid := gen_random_uuid();
  r jsonb;
  n integer;
BEGIN
  RAISE NOTICE '>>> BOOM AI v2: BẮT ĐẦU <<<';
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu BL');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status) VALUES
    (S, 'L' || substr(S::text, 1, 7), 'Quan BL', A, 'trial');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S, 'owner', true);

  EXECUTE 'SET LOCAL ROLE service_role';
  r := public._bl_reserve(S, A, 'blocked');
  PERFORM public._bl_ok(NOT (r->>'ok')::boolean AND r->>'status' = 'blocked' AND r->>'id' IS NOT NULL,
    '1 câu bị chặn được ghi sổ (không phải lượt GPT)');
  PERFORM public._bl_ok((SELECT status = 'blocked' AND cost_usd = 0 FROM public.boom_qa_log WHERE id = (r->>'id')::uuid),
    '2 dòng blocked, chi phí 0');
  r := public._bl_reserve(S, A, 'log_only');
  PERFORM public._bl_ok(r->>'status' = 'no_context', '3 câu không có hướng dẫn vẫn ghi');
  r := public._bl_reserve(S, A, 'blocked');
  PERFORM public._bl_ok(r->>'status' = 'rate_limited' AND r->>'id' IS NULL,
    '4 hạn mức chung (2/giờ) cho câu bị chặn + câu không có hướng dẫn — hết thì không ghi thêm');
  r := public._bl_reserve(S, A, 'log_only');
  PERFORM public._bl_ok(r->>'status' = 'rate_limited', '5 câu không có hướng dẫn cũng bị chặn khi đủ hạn mức chung');
  r := public._bl_reserve(S, A, 'advice');
  PERFORM public._bl_ok((r->>'ok')::boolean AND r->>'status' = 'pending', '6 tư vấn = lượt có gọi GPT (giữ chỗ, tính hạn mức người dùng)');
  r := public._bl_reserve(S, A, 'advice');
  PERFORM public._bl_ok((r->>'ok')::boolean, '7 lượt 2');
  r := public._bl_reserve(S, A, 'advice');
  PERFORM public._bl_ok(r->>'status' = 'rate_limited', '8 lượt 3 hết hạn mức người dùng (câu bị chặn không ăn lượt GPT)');

  EXECUTE 'RESET ROLE';
  BEGIN
    INSERT INTO public.boom_qa_log (store_id, user_id, question, status) VALUES (S, A, 'x', 'la_lung');
    RAISE EXCEPTION '❌ FAIL: 9 trạng thái lạ vẫn ghi được';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE '✅ PASS: 9 trạng thái lạ bị chặn';
  END;
  SELECT count(*) INTO n FROM public.boom_qa_log WHERE store_id = S;
  PERFORM public._bl_ok(n = 4, '10 tổng 4 dòng (1 blocked, 1 no_context, 2 pending) — ' || n);

  RAISE NOTICE '>>> BOOM AI v2: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
