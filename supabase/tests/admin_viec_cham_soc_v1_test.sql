-- ============================================================================
-- TEST: /admin quán cần gọi sớm (20261108_admin_viec_cham_soc_v1.sql). Kết thúc ROLLBACK.
-- Chạy được trên dữ liệu thật: so số TRƯỚC / SAU. Quán thử tạo cũ hơn 10 phút vì có trigger chống spam.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._cs_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._cs_claims(p_user uuid, p_kind text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE now_s bigint := extract(epoch FROM now())::bigint;
BEGIN
  PERFORM set_config('request.jwt.claims', CASE p_kind
    WHEN 'admin' THEN jsonb_build_object('sub', p_user, 'role', 'qn_admin', 'token_use', 'admin', 'iat', now_s, 'exp', now_s + 3600)::text
    WHEN 'pos' THEN jsonb_build_object('sub', p_user, 'role', 'authenticated', 'exp', now_s + 3600)::text
    ELSE '' END, true);
END
$f$;
-- Thêm n đơn cho quán, lùi p_ago
CREATE OR REPLACE FUNCTION public._cs_orders(p_store uuid, n int, p_ago interval, p_status text DEFAULT 'completed', p_amt numeric DEFAULT 1000)
RETURNS void LANGUAGE sql AS $f$
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at)
  SELECT gen_random_uuid(), p_store, p_amt, p_status, now() - p_ago FROM generate_series(1, n)
$f$;
GRANT EXECUTE ON FUNCTION public._cs_ok(boolean, text), public._cs_claims(uuid, text) TO authenticated, anon, qn_admin;

DO $test$
DECLARE
  A uuid := gen_random_uuid(); OW uuid := gen_random_uuid(); OW2 uuid := gen_random_uuid();
  D_DOWN uuid := gen_random_uuid();  -- 30 → 5: giảm mạnh
  D_HALF uuid := gen_random_uuid();  -- 20 → 10: đúng một nửa, tính
  D_NEAR uuid := gen_random_uuid();  -- 20 → 11: chưa tới một nửa
  D_ZERO uuid := gen_random_uuid();  -- 30 → 0: thuộc "bỏ dùng", không lặp
  D_SMALL uuid := gen_random_uuid(); -- 19 → 1: kỳ trước quá ít
  D_CXL uuid := gen_random_uuid();   -- đơn huỷ không tính
  D_TEST uuid := gen_random_uuid();  -- quán thử
  N_MENU uuid := gen_random_uuid();  -- mới, có món, chưa bán
  N_BARE uuid := gen_random_uuid();  -- mới, chưa có món, chưa bán, chủ là thành viên
  N_OLD uuid := gen_random_uuid();   -- 20 ngày, chưa bán: quá 14 ngày
  N_SOLD uuid := gen_random_uuid();  -- mới, đã bán
  N_CXL uuid := gen_random_uuid();   -- mới, chỉ có đơn huỷ: vẫn là chưa bán
  N_LOCK uuid := gen_random_uuid();  -- mới, đang khoá
  r0 jsonb; r1 jsonb; r2 jsonb; e jsonb; t text; v_top1 numeric; v_top3 numeric;
BEGIN
  RAISE NOTICE '>>> QUAN CAN GOI: BẮT ĐẦU <<<';
  INSERT INTO public.platform_admin_accounts (id, username, password_hash, display_name, updated_at)
  VALUES (A, 'qt_cs_' || substr(A::text, 1, 6), '$2a$x', 'QT Chăm sóc', now() - interval '1 hour');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name)
  VALUES (OW, '+84' || (900000000 + (random() * 99999999)::int), 'x', 'Chủ CS'),
         (OW2, '+84' || (900000000 + (random() * 99999999)::int), 'x', 'Chủ CS hai');

  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._cs_claims(A, 'admin');
  r0 := public.admin_care_v1(false);
  EXECUTE 'RESET ROLE';
  PERFORM public._cs_ok((r0->>'ok')::boolean, '1 vé quản trị gọi được');

  INSERT INTO public.stores (id, store_code, name, owner_user_id, status, plan, trial_ends_at, created_at)
  SELECT id, 'K' || substr(id::text, 1, 7), nm, owner_ref, st, 'free', now() + interval '30 days', ts
    FROM (VALUES
      (D_DOWN, 'CS Giảm', OW, 'trial', now() - interval '60 days'),
      (D_HALF, 'CS Một nửa', NULL::uuid, 'trial', now() - interval '60 days'),
      (D_NEAR, 'CS Gần nửa', NULL, 'trial', now() - interval '60 days'),
      (D_ZERO, 'CS Về 0', NULL, 'trial', now() - interval '60 days'),
      (D_SMALL, 'CS Ít đơn', NULL, 'trial', now() - interval '60 days'),
      (D_CXL, 'CS Đơn huỷ', NULL, 'trial', now() - interval '60 days'),
      (D_TEST, 'CS Thử', NULL, 'trial', now() - interval '60 days'),
      (N_MENU, 'CS Mới có món', NULL, 'trial', now() - interval '3 days'),
      (N_BARE, 'CS Mới trống', NULL, 'trial', now() - interval '2 days'),
      (N_OLD, 'CS Cũ chưa bán', NULL, 'trial', now() - interval '20 days'),
      (N_SOLD, 'CS Mới đã bán', NULL, 'trial', now() - interval '3 days'),
      (N_CXL, 'CS Mới đơn huỷ', NULL, 'trial', now() - interval '3 days'),
      (N_LOCK, 'CS Mới khoá', NULL, 'locked', now() - interval '3 days')
    ) v(id, nm, owner_ref, st, ts);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (OW2, N_BARE, 'owner', true);
  INSERT INTO public.admin_test_stores (store_id, marked_by) VALUES (D_TEST, A);
  INSERT INTO public.products (id, store_id, name) VALUES (gen_random_uuid(), N_MENU, 'Cà phê');
  INSERT INTO public.products (id, store_id, name, is_deleted) VALUES (gen_random_uuid(), N_BARE, 'Món đã xoá', true);
  PERFORM public._cs_orders(D_DOWN, 30, interval '10 days'), public._cs_orders(D_DOWN, 5, interval '1 day');
  PERFORM public._cs_orders(D_HALF, 20, interval '10 days'), public._cs_orders(D_HALF, 10, interval '1 day');
  PERFORM public._cs_orders(D_NEAR, 20, interval '10 days'), public._cs_orders(D_NEAR, 11, interval '1 day');
  PERFORM public._cs_orders(D_SMALL, 30, interval '20 days');  -- ngoài kỳ trước: nếu tính nhầm thì 49 → 1
  PERFORM public._cs_orders(D_ZERO, 30, interval '10 days');
  PERFORM public._cs_orders(D_SMALL, 19, interval '10 days'), public._cs_orders(D_SMALL, 1, interval '1 day');
  -- Đơn huỷ: nếu tính nhầm thì 30 → 5
  PERFORM public._cs_orders(D_CXL, 30, interval '10 days', 'cancelled'), public._cs_orders(D_CXL, 5, interval '1 day', 'cancelled');
  PERFORM public._cs_orders(D_TEST, 30, interval '10 days'), public._cs_orders(D_TEST, 5, interval '1 day');
  PERFORM public._cs_orders(N_SOLD, 1, interval '1 day');
  PERFORM public._cs_orders(N_CXL, 1, interval '1 day', 'cancelled');

  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._cs_claims(A, 'admin');
  r1 := public.admin_care_v1(false);
  r2 := public.admin_care_v1(true);
  EXECUTE 'RESET ROLE';

  -- ===== GIẢM MẠNH =====
  PERFORM public._cs_ok((r1#>>'{declining,total}')::int - (r0#>>'{declining,total}')::int = 2, '2 đúng 2 quán giảm mạnh: đơn huỷ, quán thử, về 0, ít đơn, chưa tới nửa đều không tính');
  SELECT x INTO e FROM jsonb_array_elements(r1#>'{declining,rows}') x WHERE x->>'id' = D_DOWN::text;
  PERFORM public._cs_ok((e->>'orders_7d')::int = 5 AND (e->>'orders_prev7')::int = 30 AND (e->>'drop_pct')::int = 83, '3 đúng số đơn và % giảm');
  PERFORM public._cs_ok(e->>'owner_name' = 'Chủ CS' AND e->>'owner_phone' IS NOT NULL, '4 có tên và số điện thoại chủ để gọi');
  PERFORM public._cs_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(r1#>'{declining,rows}') x WHERE x->>'id' = D_HALF::text), '5 giảm đúng một nửa thì tính');
  PERFORM public._cs_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r1#>'{declining,rows}') x WHERE x->>'id' IN (D_NEAR::text, D_ZERO::text, D_SMALL::text, D_CXL::text, D_TEST::text)), '6 các quán còn lại không có trong danh sách');
  PERFORM public._cs_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(r2#>'{declining,rows}') x WHERE x->>'id' = D_TEST::text), '7 bật quán thử thì có');
  -- ===== MỚI CHƯA BÁN =====
  PERFORM public._cs_ok((r1#>>'{new_idle,total}')::int - (r0#>>'{new_idle,total}')::int = 3, '8 đúng 3 quán mới chưa bán: quá 14 ngày, đã bán, đang khoá không tính');
  SELECT x INTO e FROM jsonb_array_elements(r1#>'{new_idle,rows}') x WHERE x->>'id' = N_MENU::text;
  PERFORM public._cs_ok((e->>'has_menu')::boolean, '9 có món');
  SELECT x INTO e FROM jsonb_array_elements(r1#>'{new_idle,rows}') x WHERE x->>'id' = N_BARE::text;
  PERFORM public._cs_ok(NOT (e->>'has_menu')::boolean AND e->>'owner_name' = 'Chủ CS hai', '10 chưa có món; chủ lấy từ thành viên khi quán không ghi chủ');
  PERFORM public._cs_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(r1#>'{new_idle,rows}') x WHERE x->>'id' = N_CXL::text), '11 chỉ có đơn huỷ vẫn là chưa bán');
  -- ===== TẬP TRUNG: đáp án tính độc lập =====
  WITH p AS (SELECT o.store_id, sum(COALESCE(o.total_amount, o.total, 0)) r FROM public.orders o
              WHERE o.status = 'completed' AND o.created_at > now() - interval '30 days'
                AND NOT EXISTS (SELECT 1 FROM public.admin_test_stores t WHERE t.store_id = o.store_id)
              GROUP BY 1 HAVING sum(COALESCE(o.total_amount, o.total, 0)) > 0)
  SELECT round(100 * max(r) / sum(r)), round(100 * (SELECT sum(r) FROM (SELECT r FROM p ORDER BY r DESC LIMIT 3) x) / sum(r)) INTO v_top1, v_top3 FROM p;
  PERFORM public._cs_ok((r1#>>'{concentration,top1_pct}')::numeric = v_top1 AND (r1#>>'{concentration,top3_pct}')::numeric = v_top3,
                        '12 % tập trung khớp phép tính độc lập, không tính quán thử và đơn huỷ');
  -- ===== QUYỀN =====
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._cs_claims(OW, 'pos');
  BEGIN PERFORM public.admin_care_v1(false); t := 'ok'; EXCEPTION WHEN insufficient_privilege THEN t := 'denied'; END;
  PERFORM public._cs_ok(t = 'denied', '13 vé quán không gọi được');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM public._cs_claims(NULL, '');
  BEGIN PERFORM public.admin_care_v1(false); t := 'ok'; EXCEPTION WHEN insufficient_privilege THEN t := 'denied'; END;
  PERFORM public._cs_ok(t = 'denied', '14 khoá công khai không gọi được');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._cs_claims(OW, 'admin');
  PERFORM public._cs_ok(public.admin_care_v1(false)->>'error' = 'FORBIDDEN', '15 vé quản trị mang mã người lạ bị chặn');
  EXECUTE 'RESET ROLE';
  PERFORM public._cs_ok((SELECT provolatile = 's' FROM pg_proc WHERE oid = 'public.admin_care_v1(boolean)'::regprocedure), '16 hàm chỉ đọc');
  RAISE NOTICE '>>> QUAN CAN GOI: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
