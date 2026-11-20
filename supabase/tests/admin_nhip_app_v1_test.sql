-- ============================================================================
-- TEST: /admin nhịp app đợt 2 (20261107_admin_nhip_app_v1.sql). Kết thúc ROLLBACK.
-- Chạy được trên dữ liệu thật: so số TRƯỚC / SAU khi thêm dữ liệu thử.
-- created_at của quán thử lùi 20 phút vì production có trigger chống spam (từ 15 quán / 10 phút là chặn).
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._nh_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._nh_claims(p_user uuid, p_kind text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE now_s bigint := extract(epoch FROM now())::bigint;
BEGIN
  PERFORM set_config('request.jwt.claims', CASE p_kind
    WHEN 'admin' THEN jsonb_build_object('sub', p_user, 'role', 'qn_admin', 'token_use', 'admin', 'iat', now_s, 'exp', now_s + 3600)::text
    WHEN 'pos' THEN jsonb_build_object('sub', p_user, 'role', 'authenticated', 'exp', now_s + 3600)::text
    ELSE '' END, true);
END
$f$;
GRANT EXECUTE ON FUNCTION public._nh_ok(boolean, text), public._nh_claims(uuid, text) TO authenticated, anon, qn_admin;

DO $test$
DECLARE
  A uuid := gen_random_uuid();
  OW uuid := gen_random_uuid(); ST uuid := gen_random_uuid(); OUTSIDE uuid := gen_random_uuid();
  S1 uuid := gen_random_uuid();   -- quán chính: có nhịp, có đơn
  S2 uuid := gen_random_uuid();   -- có đơn, không có nhịp → "chưa báo nhịp"
  S3 uuid := gen_random_uuid();   -- quán thử: có nhịp, có đơn, có lỗi → không tính
  S4 uuid := gen_random_uuid();   -- quán khoá
  S5 uuid := gen_random_uuid();   -- quán cũ 100 ngày, có nguồn → ngoài 90 ngày
  S6 uuid := gen_random_uuid();   -- đơn huỷ, nhịp cũ 10 ngày → không phải đang bán
  S7 uuid := gen_random_uuid();   -- có đơn, nhịp gần nhất đã 10 ngày → vẫn tính là chưa báo nhịp
  v_today date := public.qn_vn_day(now());
  r0 jsonb; r_start jsonb; r1 jsonb; r2 jsonb; r3 jsonb; x jsonb; t text; n int;
  v_v jsonb;
BEGIN
  RAISE NOTICE '>>> NHIP APP: BẮT ĐẦU <<<';
  INSERT INTO public.platform_admin_accounts (id, username, password_hash, display_name, updated_at)
  VALUES (A, 'qt_nh_' || substr(A::text, 1, 6), '$2a$x', 'QT Nhịp', now() - interval '1 hour');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name)
  SELECT u, '+84' || (900000000 + (random() * 99999999)::int), 'x', 'Người ' || u FROM unnest(ARRAY[OW, ST, OUTSIDE]) u;

  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._nh_claims(A, 'admin');
  r0 := public.admin_app_health_v1(false);
  r_start := r0;
  EXECUTE 'RESET ROLE';
  PERFORM public._nh_ok((r0->>'ok')::boolean AND jsonb_array_length(r0->'days') = 30
                        AND (r0->'days'->29->>'day')::date = v_today, '1 vé quản trị đọc được, đủ 30 ngày, ngày cuối là hôm nay giờ VN');

  INSERT INTO public.stores (id, store_code, name, owner_user_id, status, plan, trial_ends_at, created_at, signup_source)
  VALUES (S1, 'N' || substr(S1::text, 1, 7), 'NH Một', OW, 'trial', 'free', now() + interval '30 days', now() - interval '20 minutes', NULL),
         (S2, 'N' || substr(S2::text, 1, 7), 'NH Hai', OW, 'trial', 'free', now() + interval '30 days', now() - interval '20 minutes', 'google'),
         (S3, 'N' || substr(S3::text, 1, 7), 'NH Thử', OW, 'trial', 'free', now() + interval '30 days', now() - interval '20 minutes', 'google'),
         (S4, 'N' || substr(S4::text, 1, 7), 'NH Khoá', OW, 'locked', 'free', now() + interval '30 days', now() - interval '20 minutes', NULL),
         (S5, 'N' || substr(S5::text, 1, 7), 'NH Cũ', NULL, 'trial', 'free', now() + interval '30 days', now() - interval '100 days', 'facebook'),
         (S6, 'N' || substr(S6::text, 1, 7), 'NH Sáu', NULL, 'trial', 'free', now() + interval '30 days', now() - interval '20 minutes', NULL);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (OW, S1, 'owner', true), (ST, S1, 'cashier', false), (OW, S4, 'owner', true), (ST, S4, 'cashier', false);
  INSERT INTO public.admin_test_stores (store_id, marked_by) VALUES (S3, A);

  -- ===== NHỊP =====
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._nh_claims(ST, 'pos');
  x := public.app_heartbeat_v1(S1, 'dev-a', 'android', '1.0.6', 24);
  PERFORM public._nh_ok((x->>'ok')::boolean, '2 nhân viên trong quán báo nhịp được');
  PERFORM public.app_heartbeat_v1(S1, 'dev-a', 'android', '1.0.7', 25);
  EXECUTE 'RESET ROLE';
  SELECT count(*), max(app_version) INTO n, t FROM public.app_device_days WHERE store_id = S1 AND device_id = 'dev-a';
  PERFORM public._nh_ok(n = 1 AND t = '1.0.7', '3 gọi 2 lần trong ngày chỉ 1 dòng, phiên bản được cập nhật');
  PERFORM public._nh_ok((SELECT day FROM public.app_device_days WHERE store_id = S1 AND device_id = 'dev-a') = v_today, '4 ngày tính theo giờ VN');

  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._nh_claims(OUTSIDE, 'pos');
  PERFORM public._nh_ok(public.app_heartbeat_v1(S1, 'dev-x', 'android', '1.0', 1)->>'error' = 'FORBIDDEN', '5 người ngoài quán bị chặn');
  PERFORM public._nh_claims(ST, 'pos');
  PERFORM public._nh_ok(public.app_heartbeat_v1(S4, 'dev-x', 'android', '1.0', 1)->>'error' = 'FORBIDDEN', '6 quán đang khoá bị chặn');
  PERFORM public._nh_ok(public.app_heartbeat_v1(NULL, 'dev-x', 'android', '1.0', 1)->>'error' = 'FORBIDDEN', '6b thiếu mã quán bị chặn');
  PERFORM public._nh_claims(NULL, '');
  PERFORM set_config('request.headers', jsonb_build_object('x-user-id', ST)::text, true);
  PERFORM public._nh_ok(public.app_heartbeat_v1(S1, 'dev-x', 'android', '1.0', 1)->>'error' = 'FORBIDDEN', '7 không có vé, chỉ khai header x-user-id bị chặn');
  PERFORM set_config('request.headers', '', true);
  PERFORM public._nh_claims(ST, 'pos');
  PERFORM public._nh_ok(public.app_heartbeat_v1(S1, 'dev-x', 'tivi', '1.0', 1)->>'error' = 'BAD_PARAMS', '8 nền tảng lạ bị từ chối');
  PERFORM public._nh_ok(public.app_heartbeat_v1(S1, 'dev x;DROP', 'android', '1.0', 1)->>'error' = 'BAD_PARAMS', '9 mã máy lạ bị từ chối');
  PERFORM public._nh_ok(public.app_heartbeat_v1(S1, repeat('a', 65), 'android', '1.0', 1)->>'error' = 'BAD_PARAMS', '9b mã máy quá dài bị từ chối');
  PERFORM public._nh_ok(public.app_heartbeat_v1(S1, 'dev-x', 'android', repeat('1', 21), 1)->>'error' = 'BAD_PARAMS', '10 phiên bản quá dài bị từ chối');
  PERFORM public._nh_ok(public.app_heartbeat_v1(S1, 'dev-x', 'android', '1.0', -1)->>'error' = 'BAD_PARAMS', '10b build âm bị từ chối');
  BEGIN PERFORM 1 FROM public.app_device_days LIMIT 1; t := 'ok'; EXCEPTION WHEN insufficient_privilege THEN t := 'denied'; END;
  PERFORM public._nh_ok(t = 'denied', '11 người đăng nhập không đọc thẳng được bảng nhịp');
  BEGIN PERFORM public.admin_app_health_v1(false); t := 'ok'; EXCEPTION WHEN insufficient_privilege THEN t := 'denied'; END;
  PERFORM public._nh_ok(t = 'denied', '12 vé quán không gọi được hàm quản trị');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM public._nh_claims(NULL, '');
  BEGIN PERFORM public.app_heartbeat_v1(S1, 'dev-z', 'web', '1.0', 1); t := 'ok'; EXCEPTION WHEN insufficient_privilege THEN t := 'denied'; END;
  PERFORM public._nh_ok(t = 'denied', '13 khoá công khai không gọi được');
  EXECUTE 'RESET ROLE';

  -- Giới hạn 50 máy / quán / ngày
  INSERT INTO public.app_device_days (day, store_id, device_id, platform, app_version, build)
  SELECT v_today, S6, 'cap-' || i, 'web', '1', 1 FROM generate_series(1, 50) i;
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (ST, S6, 'cashier', false);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._nh_claims(ST, 'pos');
  PERFORM public._nh_ok(public.app_heartbeat_v1(S6, 'cap-51', 'web', '1', 1)->>'error' = 'TOO_MANY_DEVICES', '14 máy thứ 51 trong ngày bị chặn');
  PERFORM public._nh_ok((public.app_heartbeat_v1(S6, 'cap-1', 'web', '2', 2)->>'ok')::boolean, '14b máy đã có trong ngày vẫn cập nhật được');
  EXECUTE 'RESET ROLE';
  DELETE FROM public.app_device_days WHERE store_id = S6;

  -- ===== NGUỒN KHÁCH =====
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._nh_claims(ST, 'pos');
  PERFORM public._nh_ok(public.store_signup_source_set_v1(S1, 'friend')->>'error' = 'OWNER_ONLY', '15 nhân viên không ghi được nguồn');
  PERFORM public._nh_claims(OW, 'pos');
  PERFORM public._nh_ok(public.store_signup_source_set_v1(S1, 'tivi')->>'error' = 'BAD_SOURCE', '16 nguồn lạ bị từ chối');
  PERFORM public._nh_ok((public.store_signup_source_set_v1(S1, 'friend')->>'ok')::boolean, '17 chủ quán ghi được');
  PERFORM public._nh_ok(public.store_signup_source_set_v1(S1, 'google')->>'error' = 'ALREADY_SET', '18 không ghi đè');
  EXECUTE 'RESET ROLE';
  PERFORM public._nh_ok((SELECT signup_source FROM public.stores WHERE id = S1) = 'friend', '18b vẫn giữ nguồn đầu tiên');

  -- ===== SỐ TRÊN TRANG =====
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._nh_claims(A, 'admin');
  r0 := public.admin_app_health_v1(false);
  EXECUTE 'RESET ROLE';
  -- dev-a đã nhịp ở trên và đang là phiên bản 1.0.7; thêm:
  INSERT INTO public.app_device_days (day, store_id, device_id, platform, app_version, build) VALUES
    (v_today - 2, S1, 'dev-b', 'windows', '9.9.1', 901),  -- hôm kia bản cũ
    (v_today,     S1, 'dev-b', 'windows', '9.9.2', 902),  -- hôm nay đã cập nhật → chỉ tính 9.9.2
    (v_today - 1, S1, 'dev-c', 'windows', '9.9.1', 901),  -- vẫn bản cũ
    (v_today - 10, S6, 'dev-old', 'web', '9.9.0', 900),   -- ngoài 7 ngày, vẫn trong 30 ngày
    (v_today - 40, S6, 'dev-older', 'web', '9.8.0', 800), -- ngoài 30 ngày
    (v_today,     S3, 'dev-t', 'windows', '9.9.9', 999);  -- quán thử
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at) VALUES
    (gen_random_uuid(), S1, 1000, 'completed', now() - interval '1 day'),
    (gen_random_uuid(), S2, 1000, 'completed', now() - interval '1 day'),
    (gen_random_uuid(), S3, 1000, 'completed', now() - interval '1 day'),
    (gen_random_uuid(), S6, 1000, 'cancelled', now() - interval '1 day');
  INSERT INTO public.app_logs (store_id, device_id, level, tag, message, created_at) VALUES
    (S1, 'dev-a', 'ERROR', 'uncaught', 'Lỗi văng cũ', now() - interval '3 days'),
    (S1, 'dev-a', 'ERROR', 'uncaught', 'Lỗi văng mới <b>x</b>', now() - interval '1 hour'),
    (S2, 'dev-a', 'ERROR', 'nh_print', 'In lỗi', now() - interval '2 days'),
    (S1, 'dev-a', 'ERROR', 'nh_print', 'In lỗi kỳ trước', now() - interval '10 days'),
    (S1, 'dev-a', 'ERROR', 'nh_print', 'Quá cũ', now() - interval '20 days'),
    (S1, 'dev-a', 'INFO', 'uncaught', 'Không phải lỗi', now() - interval '1 hour'),
    (S3, 'dev-t', 'ERROR', 'nh_test', 'Quán thử', now() - interval '1 hour');
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._nh_claims(A, 'admin');
  r1 := public.admin_app_health_v1(false);
  r2 := public.admin_app_health_v1(true);
  EXECUTE 'RESET ROLE';

  -- Hôm nay: dev-b (+1 máy, quán S1 đã có sẵn dev-a nên 0 quán)
  PERFORM public._nh_ok((r1->'days'->29->>'devices')::int - (r0->'days'->29->>'devices')::int = 1
                        AND (r1->'days'->29->>'stores')::int = (r0->'days'->29->>'stores')::int, '19 số máy và quán hôm nay đếm đúng, không tính quán thử');
  PERFORM public._nh_ok((r1->'days'->19->>'devices')::int - (r0->'days'->19->>'devices')::int = 1
                        AND (r1->'days'->19->>'stores')::int - (r0->'days'->19->>'stores')::int = 1, '20 máy 10 ngày trước nằm đúng ngày');
  SELECT e INTO v_v FROM jsonb_array_elements(r1->'versions') e WHERE e->>'platform' = 'windows' AND e->>'app_version' = '9.9.2';
  PERFORM public._nh_ok((v_v->>'devices')::int = 1, '21 máy đã cập nhật chỉ tính bản mới');
  SELECT e INTO v_v FROM jsonb_array_elements(r1->'versions') e WHERE e->>'platform' = 'windows' AND e->>'app_version' = '9.9.1';
  -- Không kiểm is_latest ở đây: production có dòng Windows thật trong app_versions, build thử 901 vẫn cao hơn. Xem ca 40, 40b.
  PERFORM public._nh_ok((v_v->>'devices')::int = 1 AND (v_v->>'stores')::int = 1, '22 máy còn bản cũ được đếm');
  PERFORM public._nh_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r1->'versions') e WHERE e->>'app_version' IN ('9.9.0', '9.8.0', '9.9.9')),
                        '23 máy ngoài 7 ngày và quán thử không vào bảng phiên bản');
  PERFORM public._nh_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(r2->'versions') e WHERE e->>'app_version' = '9.9.9' AND (e->>'is_latest')::boolean),
                        '24 bật quán thử thì có; nền tảng không có dòng phát hành mới hơn thì bản cao nhất được đánh dấu');
  PERFORM public._nh_ok((r1#>>'{coverage,selling_7d}')::int - (r0#>>'{coverage,selling_7d}')::int = 2, '25 đếm quán có đơn, không tính đơn huỷ và quán thử');
  PERFORM public._nh_ok((r1#>>'{coverage,silent_7d}')::int - (r0#>>'{coverage,silent_7d}')::int = 1, '26 chỉ S2 có đơn mà chưa báo nhịp');
  PERFORM public._nh_ok((r1#>>'{errors,n_7d}')::int - (r0#>>'{errors,n_7d}')::int = 3, '27 lỗi 7 ngày: chỉ mức ERROR, không tính quán thử');
  PERFORM public._nh_ok((r1#>>'{errors,n_prev7}')::int - (r0#>>'{errors,n_prev7}')::int = 1, '28 lỗi 7 ngày trước đó, không tính lỗi 20 ngày');
  PERFORM public._nh_ok((r1#>>'{errors,uncaught_7d}')::int - (r0#>>'{errors,uncaught_7d}')::int = 2, '29 tách riêng lỗi văng');
  PERFORM public._nh_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(r1#>'{errors,top}') e WHERE e->>'tag' = 'uncaught' AND e->>'sample' LIKE 'Lỗi văng mới%'),
                        '30 bảng lỗi hiện mẫu mới nhất');
  PERFORM public._nh_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r1#>'{errors,top}') e WHERE e->>'tag' = 'nh_test'), '31 lỗi quán thử không vào bảng');
  PERFORM public._nh_ok(jsonb_array_length(r1#>'{errors,top}') <= 10, '31b tối đa 10 loại lỗi');
  -- Nguồn: S1 friend, S2 google, S4 + S6 chưa rõ; S3 quán thử, S5 quá 90 ngày
  PERFORM public._nh_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(r1->'sources') e WHERE e->>'source' = 'friend')
                        AND EXISTS (SELECT 1 FROM jsonb_array_elements(r1->'sources') e WHERE e->>'source' = 'unknown'), '32 có nguồn đã chọn và nguồn chưa rõ');
  PERFORM public._nh_ok(COALESCE((SELECT (e->>'n')::int FROM jsonb_array_elements(r2->'sources') e WHERE e->>'source' = 'google'), 0)
                        - COALESCE((SELECT (e->>'n')::int FROM jsonb_array_elements(r1->'sources') e WHERE e->>'source' = 'google'), 0) = 1, '33 quán thử chỉ tính khi bật công tắc');
  PERFORM public._nh_ok(COALESCE((SELECT (e->>'n')::int FROM jsonb_array_elements(r1->'sources') e WHERE e->>'source' = 'facebook'), 0)
                        = COALESCE((SELECT (e->>'n')::int FROM jsonb_array_elements(r_start->'sources') e WHERE e->>'source' = 'facebook'), 0), '34 quán tạo quá 90 ngày không tính');

  -- ===== MỘT MÁY NHIỀU QUÁN, BẢN CÔNG BỐ, CHE SỐ =====
  INSERT INTO public.app_device_days (day, store_id, device_id, platform, app_version, build) VALUES
    (v_today - 1, S2, 'dev-two', 'windows', '7.7.7', 777),  -- hôm qua ở S2
    (v_today,     S6, 'dev-two', 'windows', '7.7.7', 777),  -- hôm nay sang S6
    (v_today,     S1, 'dev-mac', 'macos', '4.9.9', 4999),   -- thấp hơn bản đã công bố
    (v_today,     S1, 'dev-l1', 'linux', '3.0.1', 301),     -- linux không có dòng trong app_versions (CHECK của bảng không cho phép)
    (v_today,     S1, 'dev-l2', 'linux', '3.0.2', 302);
  INSERT INTO public.app_versions (platform, version_name, build_number) VALUES ('macos', '5.0.0', 5000);
  INSERT INTO public.stores (id, store_code, name, status, plan, trial_ends_at, created_at)
  VALUES (S7, 'N' || substr(S7::text, 1, 7), 'NH Bảy', 'trial', 'free', now() + interval '30 days', now() - interval '20 minutes');
  INSERT INTO public.app_device_days (day, store_id, device_id, platform, app_version, build) VALUES (v_today - 10, S7, 'dev-s7', 'web', '1', 1);
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at) VALUES (gen_random_uuid(), S7, 1000, 'completed', now() - interval '1 day');
  INSERT INTO public.app_logs (store_id, device_id, level, tag, message, created_at)
  VALUES (S1, 'dev-a', 'ERROR', 'nh_phone', 'Lỗi uri=?phone=eq.0901234567 kết thúc', now());
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._nh_claims(A, 'admin');
  r3 := public.admin_app_health_v1(false);
  EXECUTE 'RESET ROLE';
  -- r0 đã có sẵn trước các quán thử; S2 nay có nhịp (hết thiếu), S7 nhịp đã cũ (mới thiếu)
  PERFORM public._nh_ok((r3#>>'{coverage,silent_7d}')::int - (r0#>>'{coverage,silent_7d}')::int = 1,
                        '38 máy đã sang quán khác: quán cũ vẫn tính đã báo nhịp; nhịp quá 7 ngày thì tính chưa báo');
  SELECT e INTO v_v FROM jsonb_array_elements(r3->'versions') e WHERE e->>'app_version' = '7.7.7';
  PERFORM public._nh_ok((v_v->>'devices')::int = 1 AND (v_v->>'stores')::int = 2, '39 một máy hai quán: 1 máy, 2 quán');
  SELECT e INTO v_v FROM jsonb_array_elements(r3->'versions') e WHERE e->>'app_version' = '4.9.9';
  PERFORM public._nh_ok(NOT (v_v->>'is_latest')::boolean, '40 thấp hơn bản đã công bố thì không phải mới nhất, dù cao nhất đang chạy');
  PERFORM public._nh_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(r3->'versions') e WHERE e->>'app_version' = '3.0.2' AND (e->>'is_latest')::boolean)
                        AND EXISTS (SELECT 1 FROM jsonb_array_elements(r3->'versions') e WHERE e->>'app_version' = '3.0.1' AND NOT (e->>'is_latest')::boolean),
                        '40b nền tảng chưa công bố bản nào: lấy bản cao nhất đang chạy');
  PERFORM public._nh_ok((SELECT e->>'sample' FROM jsonb_array_elements(r3#>'{errors,top}') e WHERE e->>'tag' = 'nh_phone') = 'Lỗi uri=?phone=eq.*** kết thúc',
                        '41 mẫu lỗi che dãy số dài');

  -- ===== QUYỀN =====
  PERFORM public._nh_ok(NOT has_function_privilege('anon', 'public.admin_app_health_v1(boolean)', 'execute')
                        AND NOT has_function_privilege('authenticated', 'public.admin_app_health_v1(boolean)', 'execute')
                        AND NOT has_function_privilege('anon', 'public.store_signup_source_set_v1(uuid,text)', 'execute')
                        AND NOT has_function_privilege('qn_admin', 'public.app_heartbeat_v1(uuid,text,text,text,int)', 'execute')
                        AND has_function_privilege('authenticated', 'public.app_heartbeat_v1(uuid,text,text,text,int)', 'execute'), '35 quyền đúng thiết kế');
  PERFORM public._nh_ok((SELECT provolatile = 's' FROM pg_proc WHERE oid = 'public.admin_app_health_v1(boolean)'::regprocedure), '36 hàm quản trị chỉ đọc');
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._nh_claims(OW, 'admin');
  PERFORM public._nh_ok(public.admin_app_health_v1(false)->>'error' = 'FORBIDDEN', '37 vé quản trị mang mã người lạ bị chặn');
  EXECUTE 'RESET ROLE';

  RAISE NOTICE '>>> NHIP APP: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
