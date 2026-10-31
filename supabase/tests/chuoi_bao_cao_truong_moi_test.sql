-- ============================================================================
-- TEST: Báo cáo chuỗi v1.1 — trường mới (20261018_chuoi_bao_cao_them_truong_v1.sql)
-- CHỈ CHẠY TRÊN DB STAGING/DISPOSABLE đã áp 20261017 + 20261018. Một transaction, kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._chv_as(p_role text, p_uid uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  IF p_role IN ('anon', 'authenticated') THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_uid IS NULL THEN '{}' ELSE json_build_object('sub', p_uid::text, 'role', p_role)::text END, true);
  PERFORM set_config('request.headers', '{}', true);
END
$f$;

CREATE OR REPLACE FUNCTION public._chv_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

DO $test$
DECLARE
  A uuid := gen_random_uuid();   -- chủ S1, S2 (chuỗi)
  B uuid := gen_random_uuid();   -- chủ S3 (ngoài chuỗi)
  S1 uuid := gen_random_uuid();
  S2 uuid := gen_random_uuid();
  S3 uuid := gen_random_uuid();
  v_from timestamptz := '2026-10-01 00:00+07';
  v_to   timestamptz := '2026-10-08 00:00+07';
  v_chain uuid;
  v_r jsonb;
  r1 jsonb; r2 jsonb;
  v_denied boolean;
BEGIN
  RAISE NOTICE '>>> CHUỖI v1.1 TRƯỜNG MỚI: BẮT ĐẦU <<<';

  PERFORM public._chv_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A'),
    (B, '+84' || (800000000 + (random()*99999999)::int), 'x', 'Chu B');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
    (S1, 'T' || substr(S1::text, 1, 7), 'Quan 1', A),
    (S2, 'T' || substr(S2::text, 1, 7), 'Quan 2', A),
    (S3, 'T' || substr(S3::text, 1, 7), 'Quan 3', B);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S1, 'owner', true), (A, S2, 'owner', true), (B, S3, 'owner', true);

  -- Dữ liệu thật: total_amount = (giá trước giảm) − discount. Đơn 1: gross 110.000, giảm 10.000.
  INSERT INTO public.orders (id, store_id, status, total_amount, total, payment_method, discount, created_at) VALUES
    (gen_random_uuid(), S1, 'completed', 100000, 100000, 'cash',     10000, '2026-10-02 10:00+07'),
    (gen_random_uuid(), S1, 'completed',  50000,  50000, 'transfer',     0, '2026-10-03 11:00+07'),
    (gen_random_uuid(), S1, 'completed',  70000,  70000, 'cash',         0, '2026-09-01 09:00+07'),  -- TRƯỚC kỳ: first_order_at phải lấy đơn này
    (gen_random_uuid(), S2, 'completed', 200000, 200000, 'card',         0, '2026-10-02 09:00+07'),
    (gen_random_uuid(), S2, 'completed',  30000,  30000, 'wallet',    5000, '2026-10-04 09:00+07'),
    (gen_random_uuid(), S3, 'completed', 777000, 777000, 'cash',         0, '2026-10-02 09:00+07');

  INSERT INTO public.void_audit_logs (store_id, void_type, reason, amount, created_at, requested_by_name) VALUES
    (S1, 'void_item',    'Hết món',        20000, '2026-10-02 12:00+07', 'NV1'),
    (S1, 'cancel_table', 'Mở nhầm bàn',        0, '2026-10-05 12:00+07', 'NV2'),
    (S1, 'void_item',    'Khác',           99000, '2026-09-20 12:00+07', 'NV1'),  -- ngoài kỳ: không tính
    (S1, 'void_item',    'Khác',           88000, '2026-10-08 00:00+07', 'NV1'),  -- đúng mốc p_to: không tính
    (S3, 'void_item',    'Khác',           55000, '2026-10-02 12:00+07', 'NV3');  -- quán ngoài chuỗi: không tính

  PERFORM public._chv_as('authenticated', A);
  v_r := public.create_store_chain_v1('Chuoi A');
  v_chain := (v_r->>'chain_id')::uuid;
  PERFORM public.add_store_to_chain_v1(v_chain, S1);
  PERFORM public.add_store_to_chain_v1(v_chain, S2);

  v_r := public.get_chain_report_v1(v_chain, v_from, v_to);
  PERFORM public._chv_ok((v_r->>'success')::boolean, 'T1 báo cáo v1.1 vẫn chạy');
  SELECT e INTO r1 FROM jsonb_array_elements(v_r->'stores') e WHERE (e->>'store_id')::uuid = S1;
  SELECT e INTO r2 FROM jsonb_array_elements(v_r->'stores') e WHERE (e->>'store_id')::uuid = S2;

  -- Tương thích ngược: các khóa & giá trị cũ không đổi
  PERFORM public._chv_ok((r1->>'revenue')::numeric = 150000 AND (r1->>'orders')::int = 2, 'T2 revenue/orders cũ không đổi (S1 = 150.000, 2 đơn)');
  PERFORM public._chv_ok((v_r->'totals'->>'revenue')::numeric = 380000, 'T2 tổng doanh thu cũ không đổi (380.000)');

  -- gross_revenue
  PERFORM public._chv_ok((r1->>'gross_revenue')::numeric = 160000, 'T3 S1 gross = 150.000 + 10.000 giảm giá = 160.000');
  PERFORM public._chv_ok((r2->>'gross_revenue')::numeric = 235000, 'T3 S2 gross = 230.000 + 5.000 = 235.000');
  PERFORM public._chv_ok((v_r->'totals'->>'gross_revenue')::numeric = 395000, 'T3 tổng gross = 395.000');
  PERFORM public._chv_ok(((r1->>'gross_revenue')::numeric - (r1->>'revenue')::numeric) = (r1->>'discount')::numeric, 'T3 gross − revenue = discount (S1)');

  -- void: đúng kỳ, đúng quán, không lẫn quán ngoài chuỗi, không tính mốc p_to
  PERFORM public._chv_ok((r1->>'void_count')::int = 2 AND (r1->>'void_amount')::numeric = 20000, 'T4 S1: 2 lần hủy, 20.000 (bỏ ngoài kỳ + đúng mốc p_to)');
  PERFORM public._chv_ok((r2->>'void_count')::int = 0 AND (r2->>'void_amount')::numeric = 0, 'T4 S2: không có hủy');
  PERFORM public._chv_ok((v_r->'totals'->>'void_count')::int = 2, 'T4 tổng hủy = 2, KHÔNG lẫn hủy 55.000 của quán ngoài chuỗi');

  -- wallet + bất biến tổng các nhóm thanh toán
  PERFORM public._chv_ok((r2->>'wallet_revenue')::numeric = 30000, 'T5 S2 wallet = 30.000');
  PERFORM public._chv_ok(
    ((v_r->'totals'->>'cash_revenue')::numeric + (v_r->'totals'->>'transfer_revenue')::numeric
     + (v_r->'totals'->>'card_revenue')::numeric + (v_r->'totals'->>'wallet_revenue')::numeric) = (v_r->'totals'->>'revenue')::numeric,
    'T5 tiền mặt + chuyển khoản + thẻ + ví = doanh thu (hết lệch do ví)');

  -- first_order_at là mốc TOÀN THỜI GIAN, không phụ thuộc kỳ báo cáo
  PERFORM public._chv_ok((r1->>'first_order_at')::timestamptz = '2026-09-01 09:00+07'::timestamptz, 'T6 S1 first_order_at = đơn đầu tiên (trước kỳ)');
  PERFORM public._chv_ok((r2->>'first_order_at')::timestamptz = '2026-10-02 09:00+07'::timestamptz, 'T6 S2 first_order_at đúng');

  -- Quán chưa từng có đơn: first_order_at = null (không phải lỗi)
  PERFORM public._chv_as('admin');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES (gen_random_uuid(), 'E' || substr(gen_random_uuid()::text, 1, 7), 'Quan trong', A)
    RETURNING id INTO S2;  -- tái dùng biến: quán trống mới
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S2, 'owner', true);
  PERFORM public._chv_as('authenticated', A);
  PERFORM public.add_store_to_chain_v1(v_chain, S2);
  v_r := public.get_chain_report_v1(v_chain, v_from, v_to);
  SELECT e INTO r2 FROM jsonb_array_elements(v_r->'stores') e WHERE (e->>'store_id')::uuid = S2;
  PERFORM public._chv_ok(r2->'first_order_at' = 'null'::jsonb AND (r2->>'orders')::int = 0 AND (r2->>'gross_revenue')::numeric = 0,
    'T7 quán chưa có đơn: first_order_at = null, các số = 0');

  -- Quyền không đổi
  PERFORM public._chv_as('anon');
  v_denied := false;
  BEGIN PERFORM public.get_chain_report_v1(v_chain, v_from, v_to); EXCEPTION WHEN insufficient_privilege THEN v_denied := true; END;
  PERFORM public._chv_ok(v_denied, 'T8 anon vẫn không gọi được báo cáo chuỗi');
  PERFORM public._chv_as('authenticated', B);
  v_r := public.get_chain_report_v1(v_chain, v_from, v_to);
  PERFORM public._chv_ok(v_r->>'error' = 'CHAIN_NOT_FOUND', 'T8 chủ khác vẫn không đọc được (dù có thêm trường mới)');

  -- Không lộ dữ liệu cá nhân nhân viên trong kết quả
  PERFORM public._chv_as('authenticated', A);
  v_r := public.get_chain_report_v1(v_chain, v_from, v_to);
  PERFORM public._chv_ok(position('NV1' in v_r::text) = 0 AND position('requested_by' in v_r::text) = 0 AND position('Hết món' in v_r::text) = 0,
    'T9 kết quả KHÔNG chứa tên người hủy hay lý do hủy (không có KPI cá nhân xuyên chuỗi)');

  PERFORM public._chv_as('admin');
  PERFORM public._chv_ok(to_regclass('public.idx_void_audit_store_created') IS NOT NULL, 'T10 có chỉ mục void_audit_logs(store_id, created_at)');

  RAISE NOTICE '>>> CHUỖI v1.1 TRƯỜNG MỚI: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
