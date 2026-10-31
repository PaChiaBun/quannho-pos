-- ============================================================================
-- TEST: Nạp ví an toàn (20261022_nap_vi_an_toan_v1.sql)
-- CHỈ CHẠY TRÊN DB STAGING/DISPOSABLE đã áp migration. Một transaction, kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._nv_as(p_role text, p_uid uuid DEFAULT NULL, p_store uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  IF p_role IN ('anon', 'authenticated') THEN
    EXECUTE format('SET LOCAL ROLE %I', p_role);
  END IF;
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_uid IS NULL THEN '{}'
         ELSE json_build_object('sub', p_uid::text, 'role', p_role, 'store_id', p_store::text)::text END, true);
  PERFORM set_config('request.headers',
    json_build_object('x-store-id', COALESCE(p_store::text, ''), 'x-user-id', COALESCE(p_uid::text, ''))::text, true);
END
$f$;

CREATE OR REPLACE FUNCTION public._nv_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

DO $test$
DECLARE
  A  uuid := gen_random_uuid();   -- chủ quán
  W  uuid := gen_random_uuid();   -- phục vụ (không quyền thu tiền)
  B  uuid := gen_random_uuid();   -- chủ quán khác
  S  uuid := gen_random_uuid();
  S2 uuid := gen_random_uuid();
  C  uuid := gen_random_uuid();   -- khách của S
  C2 uuid := gen_random_uuid();   -- khách của S2
  v  jsonb;
  v2 jsonb;
  n  int;
  v_real numeric; v_bon numeric;
BEGIN
  RAISE NOTICE '>>> NẠP VÍ AN TOÀN v1: BẮT ĐẦU <<<';
  PERFORM public._nv_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A'),
    (W, '+84' || (800000000 + (random()*99999999)::int), 'x', 'Phuc vu W'),
    (B, '+84' || (700000000 + (random()*99999999)::int), 'x', 'Chu B');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
    (S,  'T' || substr(S::text, 1, 7),  'Quan nap vi', A),
    (S2, 'T' || substr(S2::text, 1, 7), 'Quan khac',   B);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S, 'owner', true), (W, S, 'waiter', false), (B, S2, 'owner', true);
  INSERT INTO public.customers (id, store_id, name, phone, real_balance, bonus_balance, total_topup) VALUES
    (C,  S,  'Khach C',  '0900000001', 100000, 5000, 100000),
    (C2, S2, 'Khach C2', '0900000002', 0, 0, 0);
  INSERT INTO public.topup_packages (store_id, name, min_amount, bonus_pct, is_active) VALUES
    (S, 'Goi Bac', 200000, 10, true), (S, 'Goi Vang', 500000, 15, true), (S, 'Goi Tat', 300000, 50, false);

  -- T1: chủ quán nạp 500.000 tiền gửi → bonus máy chủ tính 15% = 75.000
  PERFORM public._nv_as('authenticated', A, S);
  v := public.topup_customer_wallet_v1(S, C, 500000, 'bank', 'key-t1-00000001', 12, 75000);
  PERFORM public._nv_ok((v->>'success')::boolean AND (v#>>'{data,bonus_amount}')::numeric = 75000
    AND (v#>>'{data,real_balance}')::numeric = 600000 AND (v#>>'{data,bonus_balance}')::numeric = 80000,
    'T1 nạp 500k: bonus 75k do máy chủ tính, số dư 600k + 80k (' || left(v::text, 120) || ')');
  PERFORM public._nv_as('admin');
  SELECT count(*) INTO n FROM public.finance_records WHERE store_id = S AND reference_id = C AND fund_type = 'bank' AND amount = 500000 AND is_auto;
  PERFORM public._nv_ok(n = 1, 'T1b ghi đúng 1 khoản thu quỹ Tiền gửi');
  SELECT count(*) INTO n FROM public.balance_transactions WHERE customer_id = C;
  PERFORM public._nv_ok(n = 2, 'T1c lịch sử ví: 1 dòng nạp + 1 dòng bonus');
  PERFORM public._nv_ok((SELECT bonus_expires_at IS NOT NULL FROM public.customers WHERE id = C), 'T1d có hạn bonus');

  -- T2: gửi lại cùng mã (sau lỗi mạng) → không nạp trùng, trả lại kết quả cũ
  PERFORM public._nv_as('authenticated', A, S);
  v2 := public.topup_customer_wallet_v1(S, C, 500000, 'bank', 'key-t1-00000001', 12, 75000);
  PERFORM public._nv_as('admin');
  SELECT COALESCE(real_balance,0), COALESCE(bonus_balance,0) INTO v_real, v_bon FROM public.customers WHERE id = C;
  SELECT count(*) INTO n FROM public.finance_records WHERE store_id = S AND reference_id = C;
  PERFORM public._nv_ok((v2#>>'{data,is_replay}')::boolean AND v_real = 600000 AND v_bon = 80000 AND n = 1,
    'T2 gửi lại cùng mã: is_replay, số dư và thu chi không đổi');

  -- T3: cùng mã nhưng khác số tiền → IDEMPOTENCY_CONFLICT
  PERFORM public._nv_as('authenticated', A, S);
  v := public.topup_customer_wallet_v1(S, C, 900000, 'bank', 'key-t1-00000001');
  PERFORM public._nv_ok(v->>'error_code' = 'IDEMPOTENCY_CONFLICT', 'T3 cùng mã khác số tiền bị chặn');

  -- T4: client gửi bonus sai (muốn tặng 500k) → QUOTE_CHANGED, không ghi gì
  v := public.topup_customer_wallet_v1(S, C, 200000, 'cash', 'key-t4-00000001', NULL, 500000);
  PERFORM public._nv_as('admin');
  SELECT COALESCE(real_balance,0) INTO v_real FROM public.customers WHERE id = C;
  PERFORM public._nv_ok(v->>'error_code' = 'QUOTE_CHANGED' AND v_real = 600000, 'T4 bonus do client bịa bị từ chối, số dư không đổi');

  -- T5: gói tắt không được dùng; nạp 300k → gói Bạc 10% = 30k (không phải 50%)
  PERFORM public._nv_as('authenticated', A, S);
  v := public.topup_customer_wallet_v1(S, C, 300000, 'cash', 'key-t5-00000001');
  PERFORM public._nv_ok((v#>>'{data,bonus_amount}')::numeric = 30000, 'T5 bỏ qua gói đang tắt, bonus 30k');

  -- T6: nạp dưới mọi gói → bonus 0
  v := public.topup_customer_wallet_v1(S, C, 50000, 'cash', 'key-t6-00000001');
  PERFORM public._nv_ok((v->>'success')::boolean AND (v#>>'{data,bonus_amount}')::numeric = 0, 'T6 nạp 50k không có bonus');

  -- T7: phục vụ (không quyền thu tiền) bị chặn
  PERFORM public._nv_as('authenticated', W, S);
  v := public.topup_customer_wallet_v1(S, C, 100000, 'cash', 'key-t7-00000001');
  PERFORM public._nv_ok(v->>'error_code' = 'PAYMENT_PERMISSION_DENIED', 'T7 phục vụ không có quyền thu tiền bị chặn (' || COALESCE(v->>'error_code','?') || ')');

  -- T8: chủ quán S không nạp được cho khách quán S2
  PERFORM public._nv_as('authenticated', A, S);
  v := public.topup_customer_wallet_v1(S, C2, 100000, 'cash', 'key-t8-00000001');
  PERFORM public._nv_ok(v->>'error_code' = 'CUSTOMER_NOT_FOUND', 'T8 không nạp được cho khách quán khác');
  v := public.topup_customer_wallet_v1(S2, C2, 100000, 'cash', 'key-t8-00000002');
  PERFORM public._nv_ok((v->>'success')::boolean IS NOT TRUE, 'T8b không gọi được với quán mình không thuộc (' || COALESCE(v->>'error_code','?') || ')');

  -- T9: dữ liệu sai
  v := public.topup_customer_wallet_v1(S, C, 0, 'cash', 'key-t9-00000001');
  PERFORM public._nv_ok(v->>'error_code' = 'INVALID_AMOUNT', 'T9a số tiền 0 bị chặn');
  v := public.topup_customer_wallet_v1(S, C, 100000.5, 'cash', 'key-t9-00000002');
  PERFORM public._nv_ok(v->>'error_code' = 'INVALID_AMOUNT', 'T9b số tiền lẻ bị chặn');
  v := public.topup_customer_wallet_v1(S, C, 100000, 'wallet', 'key-t9-00000003');
  PERFORM public._nv_ok(v->>'error_code' = 'INVALID_FUND', 'T9c quỹ lạ bị chặn');
  v := public.topup_customer_wallet_v1(S, C, 100000, 'cash', 'short');
  PERFORM public._nv_ok(v->>'error_code' = 'INVALID_PAYLOAD', 'T9d thiếu mã chống trùng bị chặn');
  v := public.topup_customer_wallet_v1(S, C, 100000, 'cash', 'key-t9-00000004', 7);
  PERFORM public._nv_ok(v->>'error_code' = 'INVALID_PAYLOAD', 'T9e thời hạn bonus lạ bị chặn');

  -- T10: anon (app cũ không JWT, chỉ header) — không có header user hợp lệ thì bị chặn
  PERFORM public._nv_as('anon', NULL, S);
  v := public.topup_customer_wallet_v1(S, C, 100000, 'cash', 'key-t10-0000001');
  PERFORM public._nv_ok((v->>'success')::boolean IS NOT TRUE, 'T10 anon không danh tính bị chặn (' || COALESCE(v->>'error_code','?') || ')');

  -- T11: client không đọc được bảng chống trùng
  PERFORM public._nv_as('authenticated', A, S);
  BEGIN
    PERFORM count(*) FROM public.wallet_topup_operations;
    PERFORM public._nv_ok(false, 'T11 client không được đọc wallet_topup_operations');
  EXCEPTION WHEN insufficient_privilege THEN
    PERFORM public._nv_ok(true, 'T11 client không được đọc wallet_topup_operations');
  END;

  -- T12: tổng kết số dư cuối: 100k + 500k + 300k + 50k = 950k thật; 5k + 75k + 30k = 110k bonus
  PERFORM public._nv_as('admin');
  SELECT COALESCE(real_balance,0), COALESCE(bonus_balance,0) INTO v_real, v_bon FROM public.customers WHERE id = C;
  PERFORM public._nv_ok(v_real = 950000 AND v_bon = 110000, 'T12 số dư cuối đúng (' || v_real || ' + ' || v_bon || ')');

  RAISE NOTICE '>>> NẠP VÍ AN TOÀN v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
