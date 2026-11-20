-- ============================================================================
-- TEST: Chuỗi cửa hàng v1 (20261017_chuoi_cua_hang_v1.sql)
-- CHỈ CHẠY TRÊN DB STAGING/DISPOSABLE đã áp migration. Một transaction, kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._cht_as(p_role text, p_uid uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  IF p_role IN ('anon', 'authenticated') THEN
    EXECUTE format('SET LOCAL ROLE %I', p_role);
  END IF;
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_uid IS NULL THEN '{}' ELSE json_build_object('sub', p_uid::text, 'role', p_role)::text END, true);
  PERFORM set_config('request.headers', '{}', true);
END
$f$;

CREATE OR REPLACE FUNCTION public._cht_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

DO $test$
DECLARE
  A uuid := gen_random_uuid();   -- chủ S1, S2
  B uuid := gen_random_uuid();   -- chủ S3
  M uuid := gen_random_uuid();   -- quản lý S1
  S1 uuid := gen_random_uuid();
  S2 uuid := gen_random_uuid();
  S3 uuid := gen_random_uuid();
  v_from timestamptz := '2026-10-01 00:00+07';
  v_to   timestamptz := '2026-10-08 00:00+07';
  v_chain uuid;
  v_chain_b uuid;
  v_r jsonb;
  v_n int;
  v_denied boolean;
BEGIN
  RAISE NOTICE '>>> CHUỖI CỬA HÀNG v1: BẮT ĐẦU <<<';

  -- Dữ liệu nền (quyền admin)
  PERFORM public._cht_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A'),
    (B, '+84' || (800000000 + (random()*99999999)::int), 'x', 'Chu B'),
    (M, '+84' || (700000000 + (random()*99999999)::int), 'x', 'Quan ly M');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
    (S1, 'T' || substr(S1::text, 1, 7), 'Quan 1', A),
    (S2, 'T' || substr(S2::text, 1, 7), 'Quan 2', A),
    (S3, 'T' || substr(S3::text, 1, 7), 'Quan 3', B);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S1, 'owner', true), (A, S2, 'owner', true), (B, S3, 'owner', true), (M, S1, 'manager', false);
  INSERT INTO public.orders (id, store_id, status, total_amount, total, payment_method, discount, created_at) VALUES
    (gen_random_uuid(), S1, 'completed', 100000, 100000, 'cash',     5000, '2026-10-02 10:00+07'),
    (gen_random_uuid(), S1, 'completed',  50000,  50000, 'transfer',    0, '2026-10-03 11:00+07'),
    (gen_random_uuid(), S1, 'cancelled',  99999,  99999, 'cash',        0, '2026-10-03 12:00+07'),
    (gen_random_uuid(), S1, 'completed',  70000,  70000, 'cash',        0, '2026-10-08 00:00+07'),  -- đúng mốc p_to: loại
    (gen_random_uuid(), S2, 'completed', 200000, 200000, 'card',        0, '2026-10-02 09:00+07'),
    (gen_random_uuid(), S3, 'completed', 777000, 777000, 'cash',        0, '2026-10-02 09:00+07');

  -- T1: anon không gọi được
  PERFORM public._cht_as('anon');
  v_denied := false;
  BEGIN PERFORM public.create_store_chain_v1('X'); EXCEPTION WHEN insufficient_privilege THEN v_denied := true; END;
  PERFORM public._cht_ok(v_denied, 'T1 anon không gọi được create_store_chain_v1');
  v_denied := false;
  BEGIN PERFORM public.get_chain_report_v1(gen_random_uuid(), v_from, v_to); EXCEPTION WHEN insufficient_privilege THEN v_denied := true; END;
  PERFORM public._cht_ok(v_denied, 'T1 anon không gọi được get_chain_report_v1');

  -- T2: quản lý (không phải chủ) không tạo được chuỗi
  PERFORM public._cht_as('authenticated', M);
  v_r := public.create_store_chain_v1('Chuoi cua M');
  PERFORM public._cht_ok(v_r->>'error' = 'OWNER_ONLY', 'T2 quản lý bị chặn tạo chuỗi (OWNER_ONLY)');

  -- T3: chủ tạo chuỗi; tên rỗng/trùng bị từ chối
  PERFORM public._cht_as('authenticated', A);
  v_r := public.create_store_chain_v1('  ');
  PERFORM public._cht_ok(v_r->>'error' = 'INVALID_NAME', 'T3 tên rỗng bị từ chối');
  v_r := public.create_store_chain_v1('Chuoi A');
  PERFORM public._cht_ok((v_r->>'success')::boolean, 'T3 chủ A tạo chuỗi');
  v_chain := (v_r->>'chain_id')::uuid;
  v_r := public.create_store_chain_v1('chuoi a');
  PERFORM public._cht_ok(v_r->>'error' = 'DUPLICATE_NAME', 'T3 trùng tên (không phân biệt hoa thường) bị từ chối');

  -- T4: thêm cửa hàng
  v_r := public.add_store_to_chain_v1(v_chain, S1);
  PERFORM public._cht_ok((v_r->>'success')::boolean, 'T4 thêm S1 vào chuỗi');
  v_r := public.add_store_to_chain_v1(v_chain, S2);
  PERFORM public._cht_ok((v_r->>'success')::boolean, 'T4 thêm S2 vào chuỗi');
  v_r := public.add_store_to_chain_v1(v_chain, S3);
  PERFORM public._cht_ok(v_r->>'error' = 'STORE_OWNER_ONLY', 'T4 không thêm được cửa hàng của chủ khác (S3)');
  v_r := public.add_store_to_chain_v1(v_chain, S1);
  PERFORM public._cht_ok(v_r->>'error' = 'STORE_ALREADY_IN_CHAIN', 'T4 thêm trùng S1 bị từ chối');

  -- T5: người khác không thao tác được chuỗi của A
  PERFORM public._cht_as('authenticated', M);
  v_r := public.add_store_to_chain_v1(v_chain, S1);
  PERFORM public._cht_ok(v_r->>'error' = 'CHAIN_NOT_FOUND', 'T5 quản lý không thêm được vào chuỗi của chủ');
  v_r := public.remove_store_from_chain_v1(v_chain, S1);
  PERFORM public._cht_ok(v_r->>'error' = 'CHAIN_NOT_FOUND', 'T5 quản lý không gỡ được cửa hàng khỏi chuỗi');
  PERFORM public._cht_as('authenticated', B);
  v_r := public.create_store_chain_v1('Chuoi B');
  v_chain_b := (v_r->>'chain_id')::uuid;
  v_r := public.add_store_to_chain_v1(v_chain_b, S1);
  PERFORM public._cht_ok(v_r->>'error' = 'STORE_OWNER_ONLY', 'T5 B không kéo S1 (của A) vào chuỗi B');
  v_r := public.add_store_to_chain_v1(v_chain, S3);
  PERFORM public._cht_ok(v_r->>'error' = 'CHAIN_NOT_FOUND', 'T5 B không thêm S3 vào chuỗi của A');

  -- T6: báo cáo tổng hợp đúng số; S3 (ngoài chuỗi), đơn hủy, đơn đúng mốc p_to đều bị loại
  PERFORM public._cht_as('authenticated', A);
  v_r := public.get_chain_report_v1(v_chain, v_from, v_to);
  PERFORM public._cht_ok((v_r->>'success')::boolean, 'T6 chủ A đọc được báo cáo chuỗi');
  PERFORM public._cht_ok((v_r->'totals'->>'revenue')::numeric = 350000, 'T6 tổng doanh thu = 350.000 (S1 150k + S2 200k)');
  PERFORM public._cht_ok((v_r->'totals'->>'orders')::int = 3, 'T6 tổng đơn = 3 (bỏ đơn hủy, đơn đúng mốc p_to)');
  PERFORM public._cht_ok((v_r->'totals'->>'store_count')::int = 2, 'T6 có 2 cửa hàng, không lẫn S3');
  PERFORM public._cht_ok((v_r->'totals'->>'cash_revenue')::numeric = 100000
     AND (v_r->'totals'->>'transfer_revenue')::numeric = 50000
     AND (v_r->'totals'->>'card_revenue')::numeric = 200000, 'T6 tách tiền mặt/chuyển khoản/thẻ đúng');
  PERFORM public._cht_ok((v_r->'totals'->>'discount')::numeric = 5000, 'T6 tổng giảm giá = 5.000');
  PERFORM public._cht_ok((v_r->'stores'->0->>'store_id')::uuid = S2, 'T6 sắp xếp theo doanh thu giảm dần (S2 trước)');
  PERFORM public._cht_ok(jsonb_array_length(v_r->'daily') = 3, 'T6 doanh thu theo ngày có 3 dòng (S1×2 ngày, S2×1 ngày)');

  -- T7: người khác không đọc được báo cáo chuỗi của A
  PERFORM public._cht_as('authenticated', B);
  v_r := public.get_chain_report_v1(v_chain, v_from, v_to);
  PERFORM public._cht_ok(v_r->>'error' = 'CHAIN_NOT_FOUND', 'T7 chủ khác không đọc được báo cáo chuỗi của A');
  PERFORM public._cht_as('authenticated', M);
  v_r := public.get_chain_report_v1(v_chain, v_from, v_to);
  PERFORM public._cht_ok(v_r->>'error' = 'CHAIN_NOT_FOUND', 'T7 quản lý không đọc được báo cáo chuỗi');

  -- T8: khoảng thời gian sai
  PERFORM public._cht_as('authenticated', A);
  v_r := public.get_chain_report_v1(v_chain, v_to, v_from);
  PERFORM public._cht_ok(v_r->>'error' = 'INVALID_RANGE', 'T8 from > to bị từ chối');
  v_r := public.get_chain_report_v1(v_chain, v_from, v_from + interval '400 days');
  PERFORM public._cht_ok(v_r->>'error' = 'INVALID_RANGE', 'T8 khoảng > 367 ngày bị từ chối');

  -- T9: RLS bảng — B chỉ thấy chuỗi của B; không ghi trực tiếp
  PERFORM public._cht_as('authenticated', B);
  SELECT count(*) INTO v_n FROM public.store_chains;
  PERFORM public._cht_ok(v_n = 1, 'T9 B chỉ thấy 1 chuỗi (của mình) qua RLS');
  SELECT count(*) INTO v_n FROM public.store_chain_stores;
  PERFORM public._cht_ok(v_n = 0, 'T9 B không thấy cửa hàng-chuỗi của A');
  v_denied := false;
  BEGIN INSERT INTO public.store_chains (name, owner_user_id) VALUES ('hack', B);
  EXCEPTION WHEN insufficient_privilege THEN v_denied := true; END;
  PERFORM public._cht_ok(v_denied, 'T9 authenticated không INSERT trực tiếp được store_chains');

  -- T10: mất quyền chủ ở S2 -> S2 bị loại khỏi báo cáo, được liệt kê excluded
  PERFORM public._cht_as('admin');
  DELETE FROM public.store_members WHERE user_id = A AND store_id = S2;
  UPDATE public.stores SET owner_user_id = B WHERE id = S2;
  PERFORM public._cht_as('authenticated', A);
  v_r := public.get_chain_report_v1(v_chain, v_from, v_to);
  PERFORM public._cht_ok((v_r->'totals'->>'revenue')::numeric = 150000 AND (v_r->'totals'->>'store_count')::int = 1,
    'T10 mất quyền chủ S2: báo cáo chỉ còn S1 (150.000)');
  PERFORM public._cht_ok(jsonb_array_length(v_r->'excluded_stores') = 1
     AND (v_r->'excluded_stores'->0->>'store_id')::uuid = S2, 'T10 S2 nằm trong excluded_stores');

  -- T11: gỡ S1 khỏi chuỗi, giữ lịch sử, rồi chuỗi B nhận S1? (B không phải chủ S1 -> vẫn bị chặn)
  v_r := public.remove_store_from_chain_v1(v_chain, S1);
  PERFORM public._cht_ok((v_r->>'success')::boolean, 'T11 gỡ S1 khỏi chuỗi');
  v_r := public.remove_store_from_chain_v1(v_chain, S1);
  PERFORM public._cht_ok(v_r->>'error' = 'STORE_NOT_IN_CHAIN', 'T11 gỡ lần 2 báo STORE_NOT_IN_CHAIN');
  v_r := public.get_chain_report_v1(v_chain, v_from, v_to);
  PERFORM public._cht_ok((v_r->'totals'->>'store_count')::int = 0 AND (v_r->'totals'->>'revenue')::numeric = 0,
    'T11 sau khi gỡ, báo cáo chuỗi không còn S1');
  v_r := public.add_store_to_chain_v1(v_chain, S1);
  PERFORM public._cht_ok((v_r->>'success')::boolean, 'T11 thêm lại S1 được (lịch sử cũ giữ nguyên)');
  PERFORM public._cht_as('admin');
  SELECT count(*) INTO v_n FROM public.store_chain_stores WHERE store_id = S1;
  PERFORM public._cht_ok(v_n = 2, 'T11 lịch sử giữ 2 dòng cho S1 (1 đã rời, 1 đang hoạt động)');

  -- T12: audit đủ
  SELECT count(*) INTO v_n FROM public.store_chain_audit_logs WHERE chain_id = v_chain;
  PERFORM public._cht_ok(v_n = 5, 'T12 audit chuỗi A có 5 dòng (create, add×2, remove, add)');

  -- T13: list_my_chains
  PERFORM public._cht_as('authenticated', A);
  v_r := public.list_my_chains_v1();
  PERFORM public._cht_ok(jsonb_array_length(v_r->'chains') = 1 AND jsonb_array_length(v_r->'owned_stores') = 1,
    'T13 list_my_chains: 1 chuỗi, 1 cửa hàng đang sở hữu (S1)');

  RAISE NOTICE '>>> CHUỖI CỬA HÀNG v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
