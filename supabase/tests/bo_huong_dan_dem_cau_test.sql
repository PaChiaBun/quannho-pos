-- ============================================================================
-- TEST: Bộ hướng dẫn /admin đếm đúng số câu hỏi theo module (20261102_bo_huong_dan_dem_cau.sql). Kết thúc ROLLBACK.
-- Chạy được trên dữ liệu thật: so số liệu TRƯỚC / SAU khi thêm câu hỏi thử.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._hd_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._hd_claims(p_user uuid, p_kind text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE now_s bigint := extract(epoch FROM now())::bigint;
BEGIN
  PERFORM set_config('request.jwt.claims', CASE p_kind
    WHEN 'admin' THEN jsonb_build_object('sub', p_user, 'role', 'qn_admin', 'token_use', 'admin', 'iat', now_s, 'exp', now_s + 3600)::text
    WHEN 'pos' THEN jsonb_build_object('sub', p_user, 'role', 'authenticated', 'exp', now_s + 3600)::text
    ELSE '' END, true);
END
$f$;
GRANT EXECUTE ON FUNCTION public._hd_ok(boolean, text), public._hd_claims(uuid, text) TO authenticated, anon, qn_admin;

-- số liệu một module trong kết quả (0 nếu không có dòng)
CREATE OR REPLACE FUNCTION public._hd_mod(r jsonb, m text, k text)
RETURNS int LANGUAGE sql IMMUTABLE AS $f$
  SELECT COALESCE((SELECT (x->>k)::int FROM jsonb_array_elements(r->'modules') x WHERE x->>'module' = m), 0)
$f$;
CREATE OR REPLACE FUNCTION public._hd_chunk(r jsonb, id text)
RETURNS int LANGUAGE sql IMMUTABLE AS $f$
  SELECT COALESCE((SELECT (x->>'uses')::int FROM jsonb_array_elements(r->'chunks') x WHERE x->>'id' = id), 0)
$f$;

DO $test$
DECLARE
  A uuid := gen_random_uuid(); B uuid := gen_random_uuid(); S uuid := gen_random_uuid(); FAKE uuid := gen_random_uuid();
  M text; M2 text; C1 text; C2 text; C3 text;
  r0 jsonb; r1 jsonb; t text;
BEGIN
  RAISE NOTICE '>>> BO HUONG DAN DEM CAU: BẮT ĐẦU <<<';
  -- 2 đoạn cùng module M + 1 đoạn module khác, lấy từ bản hướng dẫn mới nhất đang đăng
  SELECT c->>'module_name', c->>'id' INTO M, C1
    FROM public.boom_help_packs p, jsonb_array_elements(p.content->'chunks') c
   WHERE p.version = (SELECT max(version) FROM public.boom_help_packs) ORDER BY c->>'id' LIMIT 1;
  SELECT c->>'id' INTO C2
    FROM public.boom_help_packs p, jsonb_array_elements(p.content->'chunks') c
   WHERE p.version = (SELECT max(version) FROM public.boom_help_packs) AND c->>'module_name' = M AND c->>'id' <> C1 LIMIT 1;
  SELECT c->>'module_name', c->>'id' INTO M2, C3
    FROM public.boom_help_packs p, jsonb_array_elements(p.content->'chunks') c
   WHERE p.version = (SELECT max(version) FROM public.boom_help_packs) AND c->>'module_name' <> M LIMIT 1;
  PERFORM public._hd_ok(C1 IS NOT NULL AND C2 IS NOT NULL AND C3 IS NOT NULL, '0 có bản hướng dẫn với ≥ 2 module để thử');

  INSERT INTO public.platform_admin_accounts (id, username, password_hash, display_name, updated_at)
  VALUES (A, 'qt_hd_' || substr(A::text, 1, 6), '$2a$x', 'QT Hướng dẫn', now() - interval '1 hour');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name)
  VALUES (B, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chủ HD');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status, plan, trial_ends_at)
  VALUES (S, 'Q' || substr(S::text, 1, 7), 'Quán HD Thử', B, 'trial', 'free', now() + interval '20 days');

  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._hd_claims(A, 'admin');
  r0 := public.admin_boom_knowledge_v1();
  EXECUTE 'RESET ROLE';
  PERFORM public._hd_ok((r0->>'ok')::boolean AND jsonb_typeof(r0->'modules') = 'array', '1 vé quản trị gọi được, có khoá modules');

  INSERT INTO public.boom_qa_log (store_id, user_id, question, chunk_ids, status, rating, created_at) VALUES
    (S, B, 'hd thử 1: 3 đoạn, 2 cùng module', ARRAY[C1, C2, C3], 'ok', 'up', now()),
    (S, B, 'hd thử 2', ARRAY[C1], 'ok', 'down', now()),
    (S, B, 'hd thử 3: trả từ bộ nhớ', ARRAY[C1, C2], 'cached', NULL, now()),
    (S, B, 'hd thử 4: lỗi → không tính', ARRAY[C1, C2], 'error', 'down', now()),
    (S, B, 'hd thử 5: mã đoạn đã bỏ → không tính', ARRAY['khong-con#doan-cu'], 'ok', 'up', now());

  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._hd_claims(A, 'admin');
  r1 := public.admin_boom_knowledge_v1();
  EXECUTE 'RESET ROLE';

  PERFORM public._hd_ok(public._hd_mod(r1, M, 'questions') - public._hd_mod(r0, M, 'questions') = 3,
    '2 module M: 3 câu (câu 1 gửi 2 đoạn cùng module chỉ tính 1; câu lỗi không tính)');
  PERFORM public._hd_ok((public._hd_chunk(r1, C1) - public._hd_chunk(r0, C1)) + (public._hd_chunk(r1, C2) - public._hd_chunk(r0, C2)) = 5,
    '3 cùng dữ liệu đó, cộng lượt từng đoạn ra 5 — đúng lỗi cũ /admin hiện');
  PERFORM public._hd_ok(public._hd_mod(r1, M, 'ups') - public._hd_mod(r0, M, 'ups') = 1
    AND public._hd_mod(r1, M, 'downs') - public._hd_mod(r0, M, 'downs') = 1, '4 👍 / 👎 theo câu: +1 / +1 (👎 của câu lỗi không tính)');
  PERFORM public._hd_ok(public._hd_mod(r1, M2, 'questions') - public._hd_mod(r0, M2, 'questions') = 1, '5 module khác: +1 câu');
  PERFORM public._hd_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r1->'modules') x WHERE x->>'module' IS NULL),
    '6 mã đoạn không còn trong bản hướng dẫn → không tạo module rỗng');
  PERFORM public._hd_ok(jsonb_array_length(r1->'chunks') = jsonb_array_length(r0->'chunks')
    AND r1->'packs' = r0->'packs' AND r1 ? 'cache' AND r1 ? 'changelog', '7 các khoá cũ giữ nguyên');

  -- quyền
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public._hd_claims(B, 'pos');
    PERFORM public.admin_boom_knowledge_v1();
    EXECUTE 'RESET ROLE';
    RAISE EXCEPTION '❌ FAIL: 8 vé app gọi được';
  EXCEPTION WHEN insufficient_privilege THEN
    EXECUTE 'RESET ROLE';
    RAISE NOTICE '✅ PASS: 8 vé app → 42501';
  END;
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    PERFORM public.admin_boom_knowledge_v1();
    EXECUTE 'RESET ROLE';
    RAISE EXCEPTION '❌ FAIL: 9 anon gọi được';
  EXCEPTION WHEN insufficient_privilege THEN
    EXECUTE 'RESET ROLE';
    RAISE NOTICE '✅ PASS: 9 anon → 42501';
  END;
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._hd_claims(FAKE, 'admin');
  t := public.admin_boom_knowledge_v1()->>'error';
  EXECUTE 'RESET ROLE';
  PERFORM public._hd_ok(t = 'FORBIDDEN', '10 vé quản trị giả (không có tài khoản) → FORBIDDEN');

  RAISE NOTICE '>>> BO HUONG DAN DEM CAU: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
