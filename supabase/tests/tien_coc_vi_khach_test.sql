-- ============================================================================
-- TEST: 20261128_tien_coc_vi_khach.sql — cọc = ví khách, thanh toán bàn v6. Một giao dịch, kết thúc ROLLBACK.
-- Cần đã áp 20261128_dat_truoc_lich_co_dinh.sql. Gọi như máy chủ thật: đặt request.jwt.claim.sub = người dùng.
-- ============================================================================
BEGIN;
-- Như PostgREST trên máy chủ thật: UPDATE / DELETE không có WHERE bị chặn (bài học 28/11, lịch cố định).
LOAD 'safeupdate';

CREATE OR REPLACE FUNCTION public._tc_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._tc_la(p_uid uuid) RETURNS void LANGUAGE sql AS $f$
  SELECT set_config('request.jwt.claim.sub', p_uid::text, true)
$f$;
CREATE OR REPLACE FUNCTION public._tc_rpc(p_sql text) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE j jsonb;
BEGIN
  EXECUTE p_sql INTO j; RETURN j;
EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('raised', SQLSTATE, 'msg', SQLERRM);
END
$f$;

DO $test$
DECLARE
  A uuid := gen_random_uuid(); W uuid := gen_random_uuid(); S uuid := gen_random_uuid();
  Z text := 'tc-zone-' || substr(gen_random_uuid()::text, 1, 8);
  T1 text := gen_random_uuid()::text; T2 text := gen_random_uuid()::text; T3 text := gen_random_uuid()::text;
  T4 text := gen_random_uuid()::text; T5 text := gen_random_uuid()::text;
  PF uuid := gen_random_uuid(); K uuid := gen_random_uuid(); K2 uuid := gen_random_uuid();
  P0 uuid := gen_random_uuid(); P1 uuid := gen_random_uuid(); P2 uuid := gen_random_uuid();
  P3 uuid := gen_random_uuid(); P4 uuid := gen_random_uuid(); P5 uuid := gen_random_uuid();
  D1 uuid; D2 uuid; D3a uuid; D3b uuid; D4 uuid; D6 uuid; D7 uuid; P6 uuid := gen_random_uuid(); P7 uuid := gen_random_uuid();
  K3 uuid := gen_random_uuid(); j jsonb; v_set uuid; v_vi numeric; v_chuoi uuid := gen_random_uuid();
BEGIN
  RAISE NOTICE '>>> TIỀN CỌC = VÍ KHÁCH: BẮT ĐẦU <<<';
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*33000000)::int), 'x', 'Chu A'),
    (W, '+84' || (933000001 + (random()*33000000)::int), 'x', 'Phuc vu W');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, created_at) VALUES
    (S, 'T' || substr(S::text, 1, 7), 'Quan test tien coc', A, now() - interval '1 day');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S, 'owner', true), (W, S, 'waiter', false);
  INSERT INTO public.ban_zones (id, store_id, name, created_at) VALUES (Z, S, 'San', extract(epoch FROM now())::bigint * 1000);
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name, label, is_active) VALUES
    (T1, S, Z, 'San 1', 'Sân 1', true), (T2, S, Z, 'San 2', 'Sân 2', true), (T3, S, Z, 'San 3', 'Sân 3', true),
    (T4, S, Z, 'San 4', 'Sân 4', true), (T5, S, Z, 'San 5', 'Sân 5', true);
  INSERT INTO public.products (id, store_id, name, sell_price, cost_price_latest, stock_qty) VALUES (PF, S, 'Nuoc', 480000, 1000, 1000);
  INSERT INTO public.customers (id, store_id, name, phone, real_balance, bonus_balance) VALUES
    (K, S, 'Anh Nam', '0901111222', 0, 0), (K2, S, 'Chi Lan', '0903333444', 100000, 0);

  -- ── R: hồi quy — phiên không đặt, không cọc ────────────────────────────────────────────────
  INSERT INTO public.ban_sessions (id, store_id, table_id, status, waiter_id, total_amount) VALUES
    (P0, S, T5::uuid, 'open', A::text, 480000);
  INSERT INTO public.ban_session_items (store_id, session_id, product_id, product_name, unit_price, quantity, subtotal, kitchen_status, modifiers_json)
    VALUES (S, P0, PF, 'Nuoc', 480000, 1, 480000, 'da_gui', '[]');
  PERFORM public._tc_la(A);
  j := public.settle_ban_session_v6(P0, S, 'cash', 'tc-key-r0-0001', NULL, 0, 0, NULL, 0, 0);
  v_set := (j->'data'->>'settlement_id')::uuid;
  PERFORM public._tc_ok((j->>'success')::boolean AND (j->'data'->>'vi_da_tru')::numeric = 0
    AND (j->'data'->>'total_amount')::numeric = 480000
    AND (SELECT count(*) = 1 AND sum(amount) = 480000 AND bool_and(fund_type = 'cash')
         FROM public.finance_records WHERE store_id = S AND (reference_id = v_set OR fund_type = 'wallet')),
    'R1 không cọc, không ví: v6 = v5 (1 phiếu thu 480.000 tiền mặt) — ' || left(j::text, 160));

  -- ── Nhận cọc ───────────────────────────────────────────────────────────────────────────────
  INSERT INTO public.ban_dat_truoc (store_id, table_id, ten_khach, gio_tu, gio_den) VALUES
    (S, T1, 'Anh Nam', now() + interval '1 day', now() + interval '1 day 2 hours') RETURNING id INTO D1;
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_nhan_coc_v1(%L, %L, 200000, 'cash', 'tc-coc-d1-0001')$q$, S, D1));
  PERFORM public._tc_ok(j->>'error_code' = 'CAN_KHACH_HANG', 'C1 chưa gắn khách thì không nhận cọc');
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_gan_khach_v1(%L, %L, %L)$q$, S, D1, K));
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_nhan_coc_v1(%L, %L, 200000, 'cash', 'tc-coc-d1-0001')$q$, S, D1));
  PERFORM public._tc_ok((j->>'success')::boolean
    AND (SELECT real_balance FROM public.customers WHERE id = K) = 200000
    AND (SELECT count(*) FROM public.balance_transactions WHERE customer_id = K AND type = 'topup_real' AND amount = 200000 AND note LIKE 'Cọc đặt Sân 1%') = 1
    AND (SELECT count(*) FROM public.finance_records WHERE reference_id = D1 AND type = 'income' AND amount = 200000 AND fund_type = 'cash' AND description LIKE 'Cọc đặt sân: Anh Nam · Sân 1%') = 1
    AND (SELECT coc_trang_thai = 'da_thu' AND tien_coc = 200000 AND customer_id = K FROM public.ban_dat_truoc WHERE id = D1)
    AND (SELECT COALESCE(bonus_balance, 0) FROM public.customers WHERE id = K) = 0,
    'C2 nhận cọc 200.000 tiền mặt: ví khách +200.000 (không thưởng), lịch sử ví, phiếu thu Thu Chi ngay — ' || j::text);
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_nhan_coc_v1(%L, %L, 200000, 'cash', 'tc-coc-d1-0001')$q$, S, D1));
  PERFORM public._tc_ok((j->'data'->>'is_replay')::boolean AND (SELECT real_balance FROM public.customers WHERE id = K) = 200000,
    'C3 gửi lại cùng mã: không cộng ví lần nữa');
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_nhan_coc_v1(%L, %L, 50000, 'cash', 'tc-coc-d1-0002')$q$, S, D1));
  PERFORM public._tc_ok(j->>'error_code' = 'INVALID_STATE', 'C4 đã có cọc thì không nhận thêm');
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_gan_khach_v1(%L, %L, %L)$q$, S, D1, K2));
  PERFORM public._tc_ok(j->>'error_code' = 'INVALID_STATE', 'C5 đã có cọc thì không đổi khách');

  -- ── Thanh toán bàn có cọc ──────────────────────────────────────────────────────────────────
  INSERT INTO public.ban_sessions (id, store_id, table_id, status, waiter_id, total_amount) VALUES (P1, S, T1::uuid, 'open', A::text, 480000);
  INSERT INTO public.ban_session_items (store_id, session_id, product_id, product_name, unit_price, quantity, subtotal, kitchen_status, modifiers_json)
    VALUES (S, P1, PF, 'Nuoc', 480000, 1, 480000, 'da_gui', '[]');
  UPDATE public.ban_dat_truoc SET trang_thai = 'da_nhan', session_id = P1 WHERE id = D1;
  j := public.settle_ban_session_v5(P1, S, 'cash', 'tc-key-p1-old1', NULL, 0, 0, NULL, 0);
  PERFORM public._tc_ok(j->>'error_code' = 'COC_CAN_CAP_NHAT_APP'
    AND (SELECT status FROM public.ban_sessions WHERE id = P1) = 'open',
    'C6 máy cũ gọi thẳng v5 bàn có cọc: chặn, bàn vẫn mở');
  j := public.settle_ban_session_v6(P1, S, 'cash', 'tc-key-p1-0001', K2, 0, 0, NULL, 0, 0);
  PERFORM public._tc_ok(j->>'error_code' = 'COC_KHAC_KHACH', 'C7 chọn khách khác khách có cọc: báo lỗi, không trừ nhầm ví');
  j := public.settle_ban_session_v6(P1, S, 'cash', 'tc-key-p1-0001', NULL, 0, 0, NULL, 0, 0);
  v_set := (j->'data'->>'settlement_id')::uuid;
  PERFORM public._tc_ok((j->>'success')::boolean AND (j->'data'->>'vi_da_tru')::numeric = 200000
    AND (j->'data'->>'khach_tra_them')::numeric = 280000 AND (j->'data'->>'customer_id')::uuid = K
    AND (SELECT total_amount FROM public.orders o JOIN public.ban_session_orders b ON b.order_id = o.id WHERE b.session_id = P1) = 480000
    AND (SELECT amount FROM public.finance_records WHERE reference_id = v_set AND type = 'income') = 280000
    AND (SELECT count(*) FROM public.finance_records WHERE store_id = S AND fund_type = 'wallet' AND amount = 200000 AND description LIKE 'Trả bằng ví khách: Anh Nam · Sân 1%') = 1
    AND (SELECT real_balance FROM public.customers WHERE id = K) = 0
    AND (SELECT customer_id FROM public.payment_settlements WHERE id = v_set) = K
    AND (SELECT vi_da_tru FROM public.payment_settlements WHERE id = v_set) = 200000
    AND (SELECT coc_trang_thai = 'da_tru' AND coc_settlement_id = v_set FROM public.ban_dat_truoc WHERE id = D1),
    'C8 v6: đơn ghi đủ 480.000, phiếu thu lúc trả 280.000, phần ví 200.000 quỹ ví, ví về 0, gắn khách, cọc đã trừ — ' || left(j::text, 200));
  PERFORM public._tc_ok((SELECT sum(amount) FROM public.finance_records WHERE store_id = S AND type = 'income' AND fund_type IN ('cash', 'bank')
                         AND (reference_id = D1 OR reference_id = v_set)) = 480000,
    'C9 Thu Chi tiền mặt của lượt này = 200.000 cọc + 280.000 lúc trả = 480.000 (không đếm cọc hai lần)');
  j := public.settle_ban_session_v6(P1, S, 'cash', 'tc-key-p1-0001', NULL, 0, 0, NULL, 0, 0);
  PERFORM public._tc_ok((j->'data'->>'is_replay')::boolean AND (j->'data'->>'vi_da_tru')::numeric = 200000
    AND (SELECT real_balance FROM public.customers WHERE id = K) = 0
    AND (SELECT count(*) FROM public.balance_transactions WHERE customer_id = K AND type = 'spend_real') = 1,
    'C10 bấm thanh toán lại cùng mã: trả kết quả cũ, không trừ ví lần hai');

  -- ── Huỷ / không đến ────────────────────────────────────────────────────────────────────────
  INSERT INTO public.ban_dat_truoc (store_id, table_id, ten_khach, gio_tu, gio_den, customer_id) VALUES
    (S, T2, 'Chi Lan', now() + interval '2 day', now() + interval '2 day 1 hour', K2) RETURNING id INTO D2;
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_nhan_coc_v1(%L, %L, 50000, 'bank', 'tc-coc-d2-0001')$q$, S, D2));
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_xu_ly_coc_v1(%L, %L, 'quan_giu')$q$, S, D2));
  PERFORM public._tc_ok(j->>'error_code' = 'INVALID_STATE', 'H1 lượt còn chờ khách: chưa xử lý cọc được');
  UPDATE public.ban_dat_truoc SET trang_thai = 'khong_den' WHERE id = D2;
  PERFORM public._tc_la(W);
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_xu_ly_coc_v1(%L, %L, 'hoan', 'bank')$q$, S, D2));
  PERFORM public._tc_ok(j->>'raised' = '42501', 'H2 phục vụ không hoàn cọc được — ' || j::text);
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_xu_ly_coc_v1(%L, %L, 'quan_giu')$q$, S, D2));
  PERFORM public._tc_ok((j->>'success')::boolean AND (SELECT real_balance FROM public.customers WHERE id = K2) = 100000
    AND (SELECT coc_trang_thai FROM public.ban_dat_truoc WHERE id = D2) = 'quan_giu'
    AND (SELECT count(*) FROM public.finance_records WHERE reference_id = D2) = 1,
    'H3 quán giữ cọc: trừ 50.000 khỏi ví (còn 100.000 có sẵn), Thu Chi giữ phiếu thu cọc, không thêm phiếu');
  PERFORM public._tc_la(A);
  INSERT INTO public.ban_dat_truoc (store_id, table_id, ten_khach, gio_tu, gio_den, customer_id) VALUES
    (S, T2, 'Chi Lan', now() + interval '3 day', now() + interval '3 day 1 hour', K2) RETURNING id INTO D4;
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_nhan_coc_v1(%L, %L, 70000, 'cash', 'tc-coc-d4-0001')$q$, S, D4));
  UPDATE public.ban_dat_truoc SET trang_thai = 'huy' WHERE id = D4;
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_xu_ly_coc_v1(%L, %L, 'hoan', 'cash')$q$, S, D4));
  PERFORM public._tc_ok((j->>'success')::boolean AND (SELECT real_balance FROM public.customers WHERE id = K2) = 100000
    AND (SELECT count(*) FROM public.finance_records WHERE reference_id = D4 AND type = 'expense' AND amount = 70000 AND fund_type = 'cash') = 1
    AND (SELECT coc_trang_thai FROM public.ban_dat_truoc WHERE id = D4) = 'da_hoan',
    'H4 chủ quán hoàn cọc 70.000 tiền mặt: trừ ví, phiếu chi "Hoàn cọc"');

  -- ── Lịch cố định: cọc ở một buổi, trừ ở buổi đầu khách đến ─────────────────────────────────
  INSERT INTO public.ban_dat_truoc (store_id, table_id, ten_khach, gio_tu, gio_den, customer_id, chuoi_id) VALUES
    (S, T3, 'Anh Nam', now() + interval '4 day', now() + interval '4 day 1 hour', K, v_chuoi) RETURNING id INTO D3a;
  INSERT INTO public.ban_dat_truoc (store_id, table_id, ten_khach, gio_tu, gio_den, customer_id, chuoi_id) VALUES
    (S, T3, 'Anh Nam', now() + interval '11 day', now() + interval '11 day 1 hour', K, v_chuoi) RETURNING id INTO D3b;
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_nhan_coc_v1(%L, %L, 100000, 'cash', 'tc-coc-d3-0001')$q$, S, D3b));
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_nhan_coc_v1(%L, %L, 100000, 'cash', 'tc-coc-d3-0002')$q$, S, D3a));
  PERFORM public._tc_ok(j->>'error_code' = 'INVALID_STATE', 'L1 lịch cố định chỉ một lần cọc');
  INSERT INTO public.ban_sessions (id, store_id, table_id, status, waiter_id, total_amount) VALUES (P3, S, T3::uuid, 'open', A::text, 480000);
  INSERT INTO public.ban_session_items (store_id, session_id, product_id, product_name, unit_price, quantity, subtotal, kitchen_status, modifiers_json)
    VALUES (S, P3, PF, 'Nuoc', 480000, 1, 480000, 'da_gui', '[]');
  UPDATE public.ban_dat_truoc SET trang_thai = 'da_nhan', session_id = P3 WHERE id = D3a;
  j := public.settle_ban_session_v6(P3, S, 'bank', 'tc-key-p3-0001', NULL, 0, 0, NULL, 0, 0);
  PERFORM public._tc_ok((j->>'success')::boolean AND (j->'data'->>'vi_da_tru')::numeric = 100000
    AND (SELECT coc_trang_thai FROM public.ban_dat_truoc WHERE id = D3b) = 'da_tru',
    'L2 buổi đầu khách đến trừ cọc của lịch (cọc ghi ở buổi khác): ví −100.000');

  -- ── Trả thêm bằng ví (không cọc) ───────────────────────────────────────────────────────────
  INSERT INTO public.ban_sessions (id, store_id, table_id, status, waiter_id, total_amount) VALUES (P4, S, T4::uuid, 'open', A::text, 50000);
  INSERT INTO public.ban_session_items (store_id, session_id, product_id, product_name, unit_price, quantity, subtotal, kitchen_status, modifiers_json)
    VALUES (S, P4, PF, 'Nuoc nho', 50000, 1, 50000, 'da_gui', '[]');
  j := public.settle_ban_session_v6(P4, S, 'cash', 'tc-key-p4-0001', NULL, 0, 0, NULL, 0, 50000);
  PERFORM public._tc_ok(j->>'error_code' = 'CAN_KHACH_HANG', 'V1 trả bằng ví mà chưa chọn khách: báo lỗi');
  j := public.settle_ban_session_v6(P4, S, 'cash', 'tc-key-p4-0001', K2, 0, 0, NULL, 0, 50000);
  v_set := (j->'data'->>'settlement_id')::uuid;
  PERFORM public._tc_ok((j->>'success')::boolean AND (j->'data'->>'vi_da_tru')::numeric = 50000
    AND (j->'data'->>'khach_tra_them')::numeric = 0
    AND NOT EXISTS (SELECT 1 FROM public.finance_records WHERE reference_id = v_set)
    AND (SELECT real_balance FROM public.customers WHERE id = K2) = 50000,
    'V2 trả hết bằng ví: không còn phiếu thu tiền mặt, ví −50.000 — ' || left(j::text, 160));

  -- ── QC 28/11 (20261128_tinh_gio_qc_sua.sql) ──────────────────────────────────────────────────
  PERFORM public._tc_la(A);
  INSERT INTO public.ban_sessions (id, store_id, table_id, status, waiter_id, total_amount) VALUES (P6, S, T5::uuid, 'open', A::text, 0);
  INSERT INTO public.ban_dat_truoc (store_id, table_id, ten_khach, gio_tu, gio_den, customer_id) VALUES
    (S, T5, 'Chi Lan', now() + interval '3 day', now() + interval '3 day 1 hour', K2) RETURNING id INTO D6;
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_nhan_coc_v1(%L, %L, 30000, 'cash', 'tc-coc-d6-0001')$q$, S, D6));
  UPDATE public.ban_dat_truoc SET trang_thai = 'da_nhan', session_id = P6 WHERE id = D6;
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_xu_ly_coc_v1(%L, %L, 'trong_vi')$q$, S, D6));
  PERFORM public._tc_ok(j->>'error_code' = 'INVALID_STATE', 'Q1 bàn của lượt còn mở: chưa xử lý cọc (thanh toán sẽ trừ) — ' || j::text);
  UPDATE public.ban_sessions SET status = 'closed', closed_at = now() WHERE id = P6;   -- như bị gộp sang bàn khác
  j := public._tc_rpc(format($q$SELECT public.ban_dat_truoc_xu_ly_coc_v1(%L, %L, 'trong_vi')$q$, S, D6));
  PERFORM public._tc_ok((j->>'success')::boolean AND (SELECT coc_trang_thai FROM public.ban_dat_truoc WHERE id = D6) = 'trong_vi',
    'Q2 phiên đã đóng (gộp / huỷ bàn) mà cọc chưa trừ: xử lý được, cọc không kẹt — ' || j::text);
  INSERT INTO public.customers (id, store_id, name, phone, real_balance, bonus_balance, is_deleted) VALUES
    (K3, S, 'Khach da xoa', '0905555666', 0, 0, true);
  INSERT INTO public.ban_sessions (id, store_id, table_id, status, waiter_id, total_amount) VALUES (P7, S, T5::uuid, 'open', A::text, 480000);
  INSERT INTO public.ban_session_items (store_id, session_id, product_id, product_name, unit_price, quantity, subtotal, kitchen_status, modifiers_json)
    VALUES (S, P7, PF, 'Nuoc', 480000, 1, 480000, 'da_gui', '[]');
  INSERT INTO public.ban_dat_truoc (store_id, table_id, ten_khach, gio_tu, gio_den, customer_id, trang_thai, session_id) VALUES
    (S, T5, 'Khach da xoa', now() - interval '1 hour', now() + interval '1 hour', K3, 'da_nhan', P7) RETURNING id INTO D7;
  j := public.settle_ban_session_v6(P7, S, 'cash', 'tc-key-p7-0001', NULL, 0, 0, NULL, 0, 0);
  PERFORM public._tc_ok((j->>'success')::boolean, 'Q3 khách của lượt đặt (không cọc) đã xoá: vẫn thanh toán được — ' || left(j::text, 160));

  RAISE NOTICE '>>> TIỀN CỌC = VÍ KHÁCH: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
