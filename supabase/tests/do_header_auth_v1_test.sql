-- ============================================================================
-- TEST: 20261026_do_header_auth_v1.sql (Pha 1 kế hoạch JWT — đo anon + x-user-id)
-- Gọi thẳng public.qn_pre_request() sau khi giả lập vai + header như PostgREST (hook thật chỉ chạy qua PostgREST).
-- Phần 1 (đọc-ghi) kết thúc ROLLBACK. Phần 2 (chỉ-đọc) ghi qua dblink nên TỰ COMMIT → dùng quán đánh dấu
-- eeeeeeee-…-d0d0 và phần 3 xóa lại các dòng đó. Chạy được trên bản sao; trên production chỉ để lại 0 dòng.
-- ============================================================================

-- ── Phần 1: giao dịch đọc-ghi ──
BEGIN;

CREATE OR REPLACE FUNCTION public._dh_as(p_role text, p_sub uuid, p_headers jsonb, p_method text DEFAULT 'POST', p_path text DEFAULT '/rpc/x')
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  IF p_role IN ('anon', 'authenticated', 'service_role') THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_role = 'admin' THEN ''
         WHEN p_sub IS NULL THEN json_build_object('role', p_role)::text
         ELSE json_build_object('sub', p_sub::text, 'role', p_role)::text END, true);
  PERFORM set_config('request.headers', COALESCE(p_headers::text, '{}'), true);
  PERFORM set_config('request.method', p_method, true);
  PERFORM set_config('request.path', p_path, true);
END $f$;

CREATE OR REPLACE FUNCTION public._dh_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END $f$;

CREATE OR REPLACE FUNCTION public._dh_n(p_store uuid) RETURNS bigint LANGUAGE sql AS $f$
  SELECT COALESCE(sum(so_lan), 0) FROM public.qn_header_auth_seen WHERE store_id = p_store $f$;

DO $test$
DECLARE
  A  uuid := gen_random_uuid();  -- chủ S1
  S1 uuid := gen_random_uuid();
  S9 uuid := gen_random_uuid();  -- quán không ai thuộc
  t0 timestamptz; ms numeric; n bigint; i int; r record;
  ZERO uuid := '00000000-0000-0000-0000-000000000000';
BEGIN
  RAISE NOTICE '>>> ĐO HEADER v1: BẮT ĐẦU <<<';
  PERFORM public._dh_as('admin', NULL, NULL);
  -- Q0 quyền
  PERFORM public._dh_ok(has_function_privilege('anon', 'public.qn_pre_request()', 'EXECUTE')
                        AND has_function_privilege('authenticated', 'public.qn_pre_request()', 'EXECUTE')
                        AND has_function_privilege('service_role', 'public.qn_pre_request()', 'EXECUTE'),
                        'Q0 anon/authenticated/service_role gọi được hook');
  PERFORM public._dh_ok(NOT has_table_privilege('anon', 'public.qn_header_auth_seen', 'SELECT')
                        AND NOT has_table_privilege('authenticated', 'public.qn_header_auth_seen', 'SELECT')
                        AND NOT has_table_privilege('anon', 'public.qn_header_auth_seen', 'INSERT')
                        AND NOT has_function_privilege('authenticated', 'public.qn_header_auth_ghi(timestamptz,uuid,boolean,text,text,text,text,boolean)', 'EXECUTE')
                        AND NOT has_function_privilege('authenticated', 'extensions.dblink_exec(text,text)', 'EXECUTE')
                        AND NOT has_function_privilege('anon', 'extensions.dblink_connect_u(text)', 'EXECUTE'),
                        'Q0b bảng số đo, thủ tục ghi và dblink đều kín với anon/authenticated');
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qn_admin') THEN
    PERFORM public._dh_ok(has_function_privilege('qn_admin', 'public.qn_pre_request()', 'EXECUTE'), 'Q0c vé quản trị (qn_admin) gọi được hook');
  END IF;

  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES (S1, 'T' || substr(S1::text, 1, 7), 'Quan 1', A);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S1, 'owner', true);

  -- Q1 JWT thật kèm x-user-id (app hiện nay): không đo
  PERFORM public._dh_as('authenticated', A, jsonb_build_object('x-user-id', A, 'x-store-id', S1));
  PERFORM public.qn_pre_request();
  PERFORM public._dh_as('admin', NULL, NULL);
  PERFORM public._dh_ok(public._dh_n(S1) = 0, 'Q1 authenticated + header: không ghi số đo');

  -- Q2 anon + x-user-id thành viên thật (app cũ / mở app lúc mất mạng): đếm, la_thanh_vien = true; gọi 2 lần → so_lan 2
  PERFORM public._dh_as('anon', NULL, jsonb_build_object('x-user-id', A, 'x-store-id', S1, 'x-client-info', 'supabase-flutter/2.8.0', 'user-agent', 'Dart/3.5 (dart:io)'), 'POST', '/rpc/send_kitchen_ticket_v2');
  PERFORM public.qn_pre_request();
  PERFORM public.qn_pre_request();
  PERFORM public._dh_as('admin', NULL, NULL);
  SELECT * INTO r FROM public.qn_header_auth_seen WHERE store_id = S1;
  PERFORM public._dh_ok(r.so_lan = 2 AND r.la_thanh_vien AND r.method = 'POST' AND r.path = '/rpc/send_kitchen_ticket_v2'
                        AND r.client_info = 'supabase-flutter/2.8.0' AND r.user_agent = 'Dart/3.5 (dart:io)' AND NOT r.chi_doc
                        AND r.gio = date_trunc('hour', now()),
                        'Q2 anon + x-user-id chủ thật: 1 dòng, so_lan=2, đúng method/path/client');
  PERFORM public._dh_ok(NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public'
                                    AND table_name = 'qn_header_auth_seen' AND column_name ILIKE '%user%id%'),
                        'Q2b bảng không có cột lưu x-user-id');

  -- Q3 anon + x-user-id giả (uuid không thuộc quán) → la_thanh_vien = false
  PERFORM public._dh_as('anon', NULL, jsonb_build_object('x-user-id', gen_random_uuid(), 'x-store-id', S9));
  PERFORM public.qn_pre_request();
  PERFORM public._dh_as('admin', NULL, NULL);
  PERFORM public._dh_ok((SELECT bool_and(NOT la_thanh_vien) AND sum(so_lan) = 1 FROM public.qn_header_auth_seen WHERE store_id = S9),
                        'Q3 x-user-id giả: đếm với la_thanh_vien=false');

  -- Q4 x-user-id không phải uuid, thiếu x-store-id → quán 0000…, không lỗi
  n := public._dh_n(ZERO);
  PERFORM public._dh_as('anon', NULL, jsonb_build_object('x-user-id', 'abc'' OR 1=1 --'));
  PERFORM public.qn_pre_request();
  PERFORM public._dh_as('admin', NULL, NULL);
  PERFORM public._dh_ok(public._dh_n(ZERO) = n + 1, 'Q4 x-user-id rác + thiếu x-store-id: đếm vào quán 0000…');

  -- Q5 path lạ / chuỗi dài: path gộp '/?', user-agent cắt 120 ký tự, ký tự $ và ' không phá câu lệnh
  PERFORM public._dh_as('anon', NULL, jsonb_build_object('x-user-id', A, 'x-store-id', S1, 'user-agent', repeat('$q$''x', 100)), 'GET', '/orders?select=*;drop');
  PERFORM public.qn_pre_request();
  PERFORM public._dh_as('admin', NULL, NULL);
  PERFORM public._dh_ok(EXISTS (SELECT 1 FROM public.qn_header_auth_seen WHERE store_id = S1 AND path = '/?' AND length(user_agent) = 120),
                        'Q5 path lạ → ''/?'', user-agent cắt 120 ký tự');

  -- Q6 anon KHÔNG header (QR khách, đăng nhập): không đo, không ghi gì
  n := (SELECT COALESCE(sum(so_lan), 0) FROM public.qn_header_auth_seen);
  PERFORM public._dh_as('anon', NULL, jsonb_build_object('x-client-info', 'qr-web', 'x-store-id', S1), 'POST', '/rpc/submit_qr_order_v4');
  PERFORM public.qn_pre_request();
  PERFORM public._dh_as('admin', NULL, NULL);
  PERFORM public._dh_ok((SELECT COALESCE(sum(so_lan), 0) FROM public.qn_header_auth_seen) = n, 'Q6 anon không header (QR): không ghi số đo');

  -- Q7 header hỏng / claims hỏng: không bao giờ ném lỗi
  PERFORM public._dh_as('anon', NULL, NULL);
  PERFORM set_config('request.headers', 'không phải json', true);
  PERFORM public.qn_pre_request();
  PERFORM set_config('request.jwt.claims', '{hỏng', true);
  PERFORM public.qn_pre_request();
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.headers', '', true);
  PERFORM public.qn_pre_request();
  PERFORM public._dh_as('admin', NULL, NULL);
  PERFORM public._dh_ok(true, 'Q7 header/claims hỏng hoặc rỗng: hook không ném lỗi');

  -- Q8 service_role + header: không đo
  n := public._dh_n(S1);
  PERFORM public._dh_as('service_role', NULL, jsonb_build_object('x-user-id', A, 'x-store-id', S1));
  PERFORM public.qn_pre_request();
  PERFORM public._dh_as('admin', NULL, NULL);
  PERFORM public._dh_ok(public._dh_n(S1) = n, 'Q8 service_role: không ghi số đo');

  -- Q9 chặn phình: > 5000 tổ hợp trong 1 giờ thì tổ hợp MỚI bị bỏ, tổ hợp cũ vẫn cộng
  FOR i IN 1..5005 LOOP
    CALL public.qn_header_auth_ghi(date_trunc('hour', now()) - interval '3 hour', S9, false, 'GET', '/t', '', 'ua' || i, false);
  END LOOP;
  CALL public.qn_header_auth_ghi(date_trunc('hour', now()) - interval '3 hour', S9, false, 'GET', '/t', '', 'ua1', false);
  PERFORM public._dh_ok((SELECT count(*) FROM public.qn_header_auth_seen WHERE gio = date_trunc('hour', now()) - interval '3 hour') = 5000
                        AND (SELECT so_lan FROM public.qn_header_auth_seen WHERE gio = date_trunc('hour', now()) - interval '3 hour' AND user_agent = 'ua1') = 2,
                        'Q9 tối đa 5000 dòng/giờ, dòng đã có vẫn cộng');

  -- Q10 tốc độ: đường authenticated (99% yêu cầu) và anon không header đọc
  PERFORM public._dh_as('authenticated', A, jsonb_build_object('x-user-id', A, 'x-store-id', S1));
  t0 := clock_timestamp();
  FOR i IN 1..10000 LOOP PERFORM public.qn_pre_request(); END LOOP;
  ms := extract(epoch FROM clock_timestamp() - t0) * 1000 / 10000;
  PERFORM public._dh_as('admin', NULL, NULL);
  PERFORM public._dh_ok(ms < 0.1, 'Q10 authenticated: ' || round(ms, 4) || ' ms/lần (< 0,1 ms)');
  PERFORM public._dh_as('anon', NULL, jsonb_build_object('x-client-info', 'qr-web'), 'POST', '/rpc/get_qr_menu_v4');
  t0 := clock_timestamp();
  FOR i IN 1..10000 LOOP PERFORM public.qn_pre_request(); END LOOP;
  ms := extract(epoch FROM clock_timestamp() - t0) * 1000 / 10000;
  PERFORM public._dh_as('admin', NULL, NULL);
  PERFORM public._dh_ok(ms < 0.1, 'Q10b anon không header (QR): ' || round(ms, 4) || ' ms/lần (< 0,1 ms)');

  RAISE NOTICE '>>> ĐO HEADER v1 (phần 1): TẤT CẢ ĐẠT <<<';
END
$test$;

ROLLBACK;

-- ── Phần 2: giao dịch CHỈ-ĐỌC (như GET của PostgREST) → ghi qua dblink ──
BEGIN READ ONLY;
DO $ro$
DECLARE
  M uuid := 'eeeeeeee-0000-4000-8000-00000000d0d0';   -- quán đánh dấu cho test (không tồn tại)
  n0 bigint; n1 bigint; t0 timestamptz; ms numeric;
BEGIN
  SELECT COALESCE(sum(so_lan), 0) INTO n0 FROM public.qn_header_auth_seen WHERE store_id = M;
  SET LOCAL ROLE anon;
  PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
  PERFORM set_config('request.headers', json_build_object('x-user-id', gen_random_uuid(), 'x-store-id', M, 'user-agent', 'test-ro')::text, true);
  PERFORM set_config('request.method', 'GET', true);
  PERFORM set_config('request.path', '/orders', true);
  t0 := clock_timestamp();
  PERFORM public.qn_pre_request();
  ms := extract(epoch FROM clock_timestamp() - t0) * 1000;
  PERFORM public.qn_pre_request();          -- lần 2 cùng phiên (khóa tư vấn tái nhập được) → đếm tiếp
  RESET ROLE;
  SELECT COALESCE(sum(so_lan), 0) INTO n1 FROM public.qn_header_auth_seen WHERE store_id = M AND chi_doc AND path = '/orders';
  IF current_setting('transaction_read_only') <> 'on' THEN RAISE EXCEPTION '❌ FAIL: R0 giao dịch không phải chỉ-đọc'; END IF;
  IF n1 - n0 <> 2 THEN RAISE EXCEPTION '❌ FAIL: R1 GET chỉ-đọc phải đếm 2 lần qua dblink (được %)', n1 - n0; END IF;
  RAISE NOTICE '✅ PASS: R1 GET chỉ-đọc: đếm qua dblink (lần đầu % ms)', round(ms, 1);
  IF ms > 200 THEN RAISE EXCEPTION '❌ FAIL: R2 dblink chậm % ms', round(ms, 1); END IF;
  RAISE NOTICE '✅ PASS: R2 dblink < 200 ms';

END
$ro$;
ROLLBACK;


-- ── Phần 2b: giao dịch chỉ-đọc MỚI (chưa giữ khóa) trong khi phiên khác đang ghi ──
BEGIN READ ONLY;
DO $ro2$
DECLARE
  M uuid := 'eeeeeeee-0000-4000-8000-00000000d0d0';
  n0 bigint; n1 bigint; t0 timestamptz; ms numeric;
BEGIN
  PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
  PERFORM set_config('request.headers', json_build_object('x-user-id', gen_random_uuid(), 'x-store-id', M, 'user-agent', 'test-ro')::text, true);
  PERFORM set_config('request.method', 'GET', true);
  PERFORM set_config('request.path', '/orders', true);
  SELECT COALESCE(sum(so_lan), 0) INTO n0 FROM public.qn_header_auth_seen WHERE store_id = M AND chi_doc AND path = '/orders';
  IF 'qn_dh_giu_khoa' = ANY (COALESCE(extensions.dblink_get_connections(), '{}')) THEN
    PERFORM extensions.dblink_disconnect('qn_dh_giu_khoa');
  END IF;
  -- R3 phiên KHÁC đang giữ khóa (đang ghi qua dblink) → lần này bỏ qua, không chờ, không lỗi
  PERFORM extensions.dblink_connect('qn_dh_giu_khoa', format('host=127.0.0.1 port=5432 dbname=%s user=%s', current_database(), current_user));
  PERFORM extensions.dblink_exec('qn_dh_giu_khoa', 'BEGIN');
  PERFORM extensions.dblink_exec('qn_dh_giu_khoa', 'DO $k$BEGIN PERFORM pg_advisory_xact_lock(726102610); END$k$');
  SET LOCAL ROLE anon;
  t0 := clock_timestamp();
  PERFORM public.qn_pre_request();
  ms := extract(epoch FROM clock_timestamp() - t0) * 1000;
  RESET ROLE;
  PERFORM extensions.dblink_exec('qn_dh_giu_khoa', 'ROLLBACK');
  PERFORM extensions.dblink_disconnect('qn_dh_giu_khoa');
  SELECT COALESCE(sum(so_lan), 0) INTO n1 FROM public.qn_header_auth_seen WHERE store_id = M AND chi_doc AND path = '/orders';
  IF n0 <> n1 OR ms > 50 THEN RAISE EXCEPTION '❌ FAIL: R3 khóa bận phải bỏ qua ngay (đếm thêm %, % ms)', n0 - n1, round(ms, 1); END IF;
  RAISE NOTICE '✅ PASS: R3 phiên khác đang ghi → bỏ qua ngay (% ms), không đếm, không lỗi', round(ms, 2);
END
$ro2$;
ROLLBACK;

-- ── Phần 3: dọn dòng test đã tự commit qua dblink ──
DELETE FROM public.qn_header_auth_seen WHERE store_id = 'eeeeeeee-0000-4000-8000-00000000d0d0';
DO $c$ BEGIN
  IF EXISTS (SELECT 1 FROM public.qn_header_auth_seen WHERE store_id = 'eeeeeeee-0000-4000-8000-00000000d0d0') THEN
    RAISE EXCEPTION '❌ FAIL: R4 còn dòng test';
  END IF;
  RAISE NOTICE '✅ PASS: R4 đã dọn dòng test';
  RAISE NOTICE '>>> ĐO HEADER v1: hết (đạt nếu không có dòng FAIL nào) <<<';
END $c$;
