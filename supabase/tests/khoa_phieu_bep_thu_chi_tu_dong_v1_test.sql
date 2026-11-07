-- ============================================================================
-- TEST: Khoá phiếu bếp + phiếu thu chi tự động v1 (20261023_khoa_phieu_bep_thu_chi_tu_dong_v1.sql)
-- Chạy kiểu app thật (anon + header). CHỈ CHẠY TRÊN DB đã áp migration. Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._pb_app(p_uid uuid, p_store uuid)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.headers',
    json_build_object('x-store-id', p_store::text, 'x-user-id', p_uid::text)::text, true);
END
$f$;

CREATE OR REPLACE FUNCTION public._pb_admin()
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.headers', '', true);
END
$f$;

CREATE OR REPLACE FUNCTION public._pb_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._pb_try(p_sql text)
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
  A  uuid := gen_random_uuid();   -- chủ quán S
  W  uuid := gen_random_uuid();   -- phục vụ S
  X  uuid := gen_random_uuid();   -- chủ quán S2
  S  uuid := gen_random_uuid();
  S2 uuid := gen_random_uuid();
  SS uuid := gen_random_uuid();   -- bàn đang mở
  SC uuid := gen_random_uuid();   -- bàn đã đóng
  SX uuid := gen_random_uuid();   -- bàn quán khác
  B1 uuid := gen_random_uuid(); B2 uuid := gen_random_uuid(); B3 uuid := gen_random_uuid();
  T1 uuid := gen_random_uuid(); T2 uuid := gen_random_uuid();
  K1 uuid := gen_random_uuid(); K2 uuid := gen_random_uuid();
  M1 uuid := gen_random_uuid(); M2 uuid := gen_random_uuid();
  P1 uuid := gen_random_uuid(); P2 uuid := gen_random_uuid(); P3 uuid := gen_random_uuid();
  C1 uuid := gen_random_uuid(); C2 uuid := gen_random_uuid();
  PR uuid := gen_random_uuid(); M3 uuid := gen_random_uuid();
  B4 uuid := gen_random_uuid(); B5 uuid := gen_random_uuid(); T3 uuid := gen_random_uuid();
  t  text;
  v  text;
  d  boolean;
BEGIN
  RAISE NOTICE '>>> KHOÁ PHIẾU BẾP + THU CHI TỰ ĐỘNG v1: BẮT ĐẦU <<<';
  PERFORM public._pb_admin();
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A'),
    (W, '+84' || (800000000 + (random()*99999999)::int), 'x', 'Phuc vu W'),
    (X, '+84' || (700000000 + (random()*99999999)::int), 'x', 'Chu X');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
    (S,  'P' || substr(S::text, 1, 7),  'Quan PB',  A),
    (S2, 'P' || substr(S2::text, 1, 7), 'Quan PB2', X);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S, 'owner', true), (W, S, 'waiter', false), (X, S2, 'owner', true);
  INSERT INTO public.ban_sessions (id, store_id, status) VALUES (SS, S, 'open'), (SC, S, 'open'), (SX, S2, 'open');
  INSERT INTO public.ban_session_items (id, store_id, session_id, product_name, unit_price, price, quantity, subtotal, kitchen_status) VALUES
    (B1, S, SS, 'Tra sua', 30000, 30000, 2, 60000, 'da_gui'),
    (B2, S, SS, 'Ca phe',  20000, 20000, 1, 20000, 'da_gui'),
    (B3, S, SS, 'Banh',    15000, 15000, 3, 45000, 'da_gui');
  UPDATE public.ban_sessions SET status = 'closed' WHERE id = SC;

  -- ── 1. Thêm phiếu bếp (đúng luồng gửi bếp mang đi ở quầy) ──
  PERFORM public._pb_app(W, S);
  t := public._pb_try(format($q$INSERT INTO public.kitchen_tickets (id, store_id, session_id, table_label, zone_label, round, sent_at, status)
        VALUES (%L, %L, %L, 'Mang đi', 'Mang đi', 1, now(), 'cho')$q$, T1, S, SS));
  PERFORM public._pb_ok(t = 'ok:1', '1a gửi bếp: thêm phiếu cho bàn đang mở (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.kitchen_tickets (id, store_id, session_id, status) VALUES (gen_random_uuid(), %L, %L, 'cho')$q$, S, SC));
  PERFORM public._pb_ok(t = 'err:42501', '1b không thêm phiếu cho bàn đã đóng (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.kitchen_tickets (id, store_id, session_id, status) VALUES (gen_random_uuid(), %L, %L, 'cho')$q$, S, SX));
  PERFORM public._pb_ok(t = 'err:42501', '1c không thêm phiếu cho bàn quán khác (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.kitchen_tickets (id, store_id, session_id, status) VALUES (gen_random_uuid(), %L, %L, 'xong')$q$, S, SS));
  PERFORM public._pb_ok(t = 'err:42501', '1d phiếu mới không đặt sẵn "xong" (' || t || ')');

  -- ── 2. Thêm món vào phiếu ──
  t := public._pb_try(format($q$INSERT INTO public.kitchen_ticket_items (id, store_id, ticket_id, session_item_id, name, product_name, quantity, done)
        VALUES (%L, %L, %L, %L, 'Tra sua', 'Tra sua', 2, false)$q$, K1, S, T1, B1));
  PERFORM public._pb_ok(t = 'ok:1', '2a thêm món đúng số lượng món bàn (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.kitchen_ticket_items (id, store_id, ticket_id, session_item_id, name, quantity, done)
        VALUES (gen_random_uuid(), %L, %L, %L, 'Ca phe', 5, false)$q$, S, T1, B2));
  PERFORM public._pb_ok(t = 'err:42501', '2b không thêm món sai số lượng (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.kitchen_ticket_items (id, store_id, ticket_id, session_item_id, name, quantity, done)
        VALUES (gen_random_uuid(), %L, %L, %L, 'Tra sua', 2, false)$q$, S, T1, B1));
  PERFORM public._pb_ok(t = 'err:42501', '2c không thêm món đã có trên phiếu (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.kitchen_ticket_items (id, store_id, ticket_id, name, quantity, done)
        VALUES (gen_random_uuid(), %L, %L, 'Mon gia', 9, false)$q$, S, T1));
  PERFORM public._pb_ok(t = 'err:42501', '2d không thêm món không có ở bàn (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.kitchen_ticket_items (id, store_id, ticket_id, session_item_id, name, quantity, done)
        VALUES (%L, %L, %L, %L, 'Ca phe', 1, false)$q$, K2, S, T1, B2));
  PERFORM public._pb_ok(t = 'ok:1', '2e thêm món thứ hai (' || t || ')');

  -- ── 3. Bếp làm phiếu ──
  t := public._pb_try(format($q$UPDATE public.kitchen_tickets SET status='dang_lam', started_at=now() WHERE id=%L$q$, T1));
  PERFORM public._pb_ok(t = 'ok:1', '3a bếp bắt đầu làm (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.kitchen_ticket_items SET done=true WHERE ticket_id=%L$q$, T1));
  PERFORM public._pb_ok(t = 'ok:2', '3b tick xong từng món (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.kitchen_tickets SET status='xong', done_at=now() WHERE id=%L$q$, T1));
  PERFORM public._pb_ok(t = 'ok:1', '3c xong phiếu (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.kitchen_tickets SET status='dang_lam', done_at=NULL WHERE id=%L$q$, T1));
  PERFORM public._pb_ok(t = 'ok:1', '3d mở lại phiếu (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.kitchen_tickets SET done_at=now() - interval '1 day' WHERE id=%L$q$, T1));
  PERFORM public._pb_ok(t = 'ok:1', '3e dọn phiếu (lùi giờ xong) (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.kitchen_ticket_items SET kitchen_note='it duong', free_note='mang ve' WHERE id=%L$q$, K1));
  PERFORM public._pb_ok(t = 'ok:1', '3f sửa ghi chú món (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.kitchen_tickets SET table_label='Ban 9' WHERE id=%L$q$, T1));
  PERFORM public._pb_ok(t = 'err:42501', '3g không đổi tên bàn của phiếu (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.kitchen_tickets SET status='bat_ky' WHERE id=%L$q$, T1));
  PERFORM public._pb_ok(t = 'err:42501', '3h không đặt trạng thái lạ (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.kitchen_ticket_items SET product_name='Mon khac' WHERE id=%L$q$, K1));
  PERFORM public._pb_ok(t = 'err:42501', '3i không đổi tên món trên phiếu (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.kitchen_ticket_items SET quantity=5 WHERE id=%L$q$, K1));
  PERFORM public._pb_ok(t = 'err:42501', '3j không tăng số lượng món bếp (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.kitchen_ticket_items SET quantity=1 WHERE id=%L$q$, K1));
  PERFORM public._pb_ok(t = 'err:42501', '3k không tự giảm số lượng khi món bàn chưa giảm (' || t || ')');

  -- ── 4. Giảm / huỷ món có duyệt (món bàn đổi trước — mô phỏng bằng quản trị) ──
  PERFORM public._pb_admin();
  UPDATE public.ban_session_items SET quantity = 1, subtotal = 30000 WHERE id = B1;
  PERFORM public._pb_app(W, S);
  t := public._pb_try(format($q$UPDATE public.kitchen_ticket_items SET quantity=1 WHERE id=%L$q$, K1));
  PERFORM public._pb_ok(t = 'ok:1', '4a giảm số lượng món bếp theo món bàn đã giảm (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.kitchen_tickets SET status='huy' WHERE id=%L$q$, T1));
  PERFORM public._pb_ok(t = 'err:42501', '4b không huỷ phiếu khi chưa có món nào bị huỷ (' || t || ')');
  PERFORM public._pb_admin();
  UPDATE public.ban_session_items SET kitchen_status = 'huy' WHERE id IN (B1, B2);
  PERFORM public._pb_app(W, S);
  t := public._pb_try(format($q$UPDATE public.kitchen_ticket_items SET done=false WHERE ticket_id=%L$q$, T1));
  PERFORM public._pb_admin();
  PERFORM public._pb_ok(t = 'ok:2' AND (SELECT bool_and(done) FROM public.kitchen_ticket_items WHERE ticket_id = T1),
    '4c "mở lại" không làm sống lại món đã huỷ (' || t || ')');
  PERFORM public._pb_app(W, S);
  t := public._pb_try(format($q$UPDATE public.kitchen_tickets SET status='huy', done_at=now() WHERE id=%L$q$, T1));
  PERFORM public._pb_ok(t = 'ok:1', '4d huỷ phiếu khi món đã huỷ (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.kitchen_tickets SET status='xong' WHERE id=%L$q$, T1));
  PERFORM public._pb_admin();
  SELECT status INTO v FROM public.kitchen_tickets WHERE id = T1;
  PERFORM public._pb_ok(t = 'ok:1' AND v = 'huy', '4e bếp bấm "Xong" trễ: phiếu vẫn huỷ, không báo lỗi (' || t || ')');

  -- ── 5. Xoá ──
  PERFORM public._pb_app(W, S);
  t := public._pb_try(format($q$DELETE FROM public.kitchen_ticket_items WHERE id=%L$q$, K2));
  PERFORM public._pb_ok(t = 'err:42501', '5a không xoá món trên phiếu bếp (' || t || ')');
  t := public._pb_try(format($q$DELETE FROM public.kitchen_tickets WHERE id=%L$q$, T1));
  PERFORM public._pb_ok(t = 'err:42501', '5b không xoá phiếu bếp (' || t || ')');
  PERFORM public._pb_admin();
  t := public._pb_try(format($q$DELETE FROM public.kitchen_tickets WHERE id=%L$q$, T1));
  PERFORM public._pb_ok(t = 'ok:1', '5c quản trị / hàm máy chủ vẫn xoá được (' || t || ')');

  -- ── 6. Phiếu thu chi tự động (chủ quán A có mọi module; phục vụ W không có Kho / Khách hàng) ──
  INSERT INTO public.products (id, store_id, name, cost_price_latest) VALUES (PR, S, 'Sua dac', 12000);
  INSERT INTO public.stock_movements (id, store_id, product_id, delta, reason, created_at) VALUES
    (M1, S, PR, 10, 'purchase', now()), (M2, S, PR, 10, 'purchase', now() - interval '1 hour');
  INSERT INTO public.purchase_orders (id, store_id, status, total_amount, total_cost) VALUES
    (P1, S, 'received', 100000, 90000), (P2, S, 'cancelled', 50000, 50000), (P3, S, 'cancelled', 70000, 70000);
  INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto, fund_type)
    VALUES (S, 'expense', 50000, 'Nhập hàng PO gốc', P2, true, 'cash');
  INSERT INTO public.customers (id, store_id, name) VALUES (C1, S, 'Khach C');
  INSERT INTO public.balance_transactions (store_id, customer_id, type, amount, balance_after, bonus_after)
    VALUES (S, C1, 'topup_real', 200000, 200000, 0);

  PERFORM public._pb_app(W, S);
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto, fund_type)
        VALUES (%L, 'income', 5000000, 'Bán hàng giả', %L, true, 'cash')$q$, S, SS));
  PERFORM public._pb_ok(t = 'err:42501', '6a không ghi được phiếu thu "tự động" giả (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto)
        VALUES (%L, 'income', 5000000, 'Thu không nguồn', NULL, true)$q$, S));
  PERFORM public._pb_ok(t = 'err:42501', '6b không ghi phiếu thu tự động không có nguồn (' || t || ')');
  -- QC F3: phục vụ (không có module Kho) tự tạo phiếu kho rồi ghi chi khống
  t := public._pb_try(format($q$INSERT INTO public.stock_movements (id, store_id, product_id, delta, reason) VALUES (%L, %L, %L, 0.001, 'purchase')$q$, M3, S, PR));
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto)
        VALUES (%L, 'expense', 50000000, 'Nhập hàng: khống', %L, true)$q$, S, M3));
  PERFORM public._pb_ok(t = 'err:42501', '6c phục vụ không có module Kho: không ghi chi nhập hàng khống (' || t || ')');
  -- QC F1: phục vụ (không có module Khách hàng) tự tạo giao dịch nạp rồi ghi thu khống
  t := public._pb_try(format($q$INSERT INTO public.customers (id, store_id, name) VALUES (%L, %L, 'Khach gia')$q$, C2, S));
  t := public._pb_try(format($q$INSERT INTO public.balance_transactions (store_id, customer_id, type, amount, balance_after, bonus_after)
        VALUES (%L, %L, 'topup_real', 9000000, 9000000, 0)$q$, S, C2));
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto)
        VALUES (%L, 'income', 9000000, 'Nạp ví: gia', %L, true)$q$, S, C2));
  PERFORM public._pb_ok(t = 'err:42501', '6d phục vụ không có module Khách hàng: không ghi thu nạp ví khống (' || t || ')');

  PERFORM public._pb_app(A, S);
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto, fund_type, recorded_at)
        VALUES (%L, 'expense', 120000, 'Nhập hàng: Sua dac', %L, true, 'cash', now() - interval '20 minutes')$q$, S, M1));
  PERFORM public._pb_ok(t = 'ok:1', '6e nhập kho nhanh: 10 × 12.000 = 120.000 (kể cả đồng hồ máy lệch 20 phút) (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto, fund_type)
        VALUES (%L, 'expense', 120000, 'Nhập hàng: Sua dac', %L, true, 'cash')$q$, S, M1));
  PERFORM public._pb_ok(t = 'err:42501', '6f không ghi trùng phiếu chi cho cùng phiếu kho (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto, fund_type)
        VALUES (%L, 'expense', 9999999, 'Nhập hàng: thổi giá', %L, true, 'cash')$q$, S, M2));
  PERFORM public._pb_ok(t = 'err:42501', '6g nhập kho: số tiền khác số lượng × giá nhập bị chặn (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto, fund_type)
        VALUES (%L, 'expense', 80000, 'Nhập hàng PO sai tiền', %L, true, 'cash')$q$, S, P1));
  PERFORM public._pb_ok(t = 'err:42501', '6h phiếu nhập: sai tổng tiền bị chặn (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto, fund_type, recorded_at)
        VALUES (%L, 'expense', 100000, 'Nhập hàng PO-1', %L, true, 'bank', now() - interval '3 days')$q$, S, P1));
  PERFORM public._pb_ok(t = 'ok:1', '6i phiếu nhập: đúng tổng tiền, ngày nhập lùi được (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto, fund_type)
        VALUES (%L, 'income', 50000, 'Huỷ nhập hàng PO-2', %L, true, 'cash')$q$, S, P2));
  PERFORM public._pb_ok(t = 'ok:1', '6j huỷ phiếu nhập: thu hoàn (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto, fund_type)
        VALUES (%L, 'income', 50000, 'Huỷ nhập hàng PO-2 lần 2', %L, true, 'cash')$q$, S, P2));
  PERFORM public._pb_ok(t = 'err:42501', '6k không thu hoàn hai lần (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto, fund_type)
        VALUES (%L, 'income', 70000, 'Huỷ nhập hàng PO-3', %L, true, 'cash')$q$, S, P3));
  PERFORM public._pb_ok(t = 'err:42501', '6l không thu hoàn khi chưa từng ghi chi (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto, fund_type)
        VALUES (%L, 'income', 200000, 'Nạp ví: Khach C', %L, true, 'cash')$q$, S, C1));
  PERFORM public._pb_ok(t = 'ok:1', '6m app cũ nạp ví: ghi thu khớp giao dịch nạp (' || t || ')');
  -- QC R1: phát lại lần nạp thật với ngày lùi
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto, fund_type, recorded_at)
        VALUES (%L, 'income', 200000, 'Nạp ví: Khach C', %L, true, 'cash', now() - interval '30 days')$q$, S, C1));
  PERFORM public._pb_ok(t = 'err:42501', '6n không ghi lại lần nạp cũ với ngày lùi (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto)
        VALUES (%L, 'expense', 45000, 'Giá vốn NL: Banh × 3 phần', %L, true)$q$, S, SS));
  PERFORM public._pb_ok(t = 'err:42501', '6o chặn "Giá vốn NL" app cũ ghi khi huỷ món (lỗi tính trùng) (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, is_auto, fund_type)
        VALUES (%L, 'expense', 300000, 'Tiền điện', false, 'cash')$q$, S));
  PERFORM public._pb_ok(t = 'ok:1', '6p chủ quán ghi tay vẫn được (' || t || ')');
  PERFORM public._pb_admin();
  t := public._pb_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, reference_id, is_auto)
        VALUES (%L, 'income', 60000, 'Bán hàng #1', %L, true)$q$, S, SS));
  PERFORM public._pb_ok(t = 'ok:1', '6q hàm máy chủ (bán hàng) vẫn ghi được (' || t || ')');

  -- ── 7. Lách bằng món ở bàn "chưa gửi" (QC K1, K1b, K2, K3) ──
  PERFORM public._pb_app(W, S);
  t := public._pb_try(format($q$INSERT INTO public.kitchen_tickets (id, store_id, session_id, status, sent_at) VALUES (%L, %L, %L, 'cho', now())$q$, T3, S, SS));
  t := public._pb_try(format($q$INSERT INTO public.ban_session_items (id, store_id, session_id, product_name, unit_price, quantity, subtotal, kitchen_status)
        VALUES (%L, %L, %L, 'Bia', 20000, 10, 200000, 'chua_gui')$q$, B4, S, SS));
  t := public._pb_try(format($q$INSERT INTO public.kitchen_ticket_items (id, store_id, ticket_id, session_item_id, name, quantity, done)
        VALUES (gen_random_uuid(), %L, %L, %L, 'Bia', 10, false)$q$, S, T3, B4));
  PERFORM public._pb_ok(t = 'ok:1', '7a (chuẩn bị) món chưa gửi được gắn lên phiếu bếp (' || t || ')');
  t := public._pb_try(format($q$DELETE FROM public.ban_session_items WHERE id=%L$q$, B4));
  PERFORM public._pb_ok(t = 'err:42501', '7b món đã lên phiếu bếp không xoá khỏi bàn được (bếp làm mà bill không tính) (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.ban_session_items SET quantity=1, subtotal=20000 WHERE id=%L$q$, B4));
  PERFORM public._pb_ok(t = 'err:42501', '7c món đã lên phiếu bếp không giảm khi không có duyệt (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.ban_session_items SET note='it da' WHERE id=%L$q$, B4));
  PERFORM public._pb_ok(t = 'ok:1', '7d vẫn sửa ghi chú được (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.ban_session_items (id, store_id, session_id, product_name, unit_price, quantity, subtotal, kitchen_status)
        VALUES (%L, %L, %L, 'Mon huy', 1000, 1, 1000, 'huy')$q$, B5, S, SS));
  PERFORM public._pb_ok(t = 'err:42501', '7e không thêm thẳng món ở trạng thái huỷ (' || t || ')');
  PERFORM public._pb_admin();
  INSERT INTO public.ban_session_items (id, store_id, session_id, product_name, unit_price, quantity, subtotal, kitchen_status)
    VALUES (B5, S, SS, 'Mon huy', 1000, 1, 1000, 'huy');
  PERFORM public._pb_app(W, S);
  t := public._pb_try(format($q$INSERT INTO public.kitchen_ticket_items (id, store_id, ticket_id, session_item_id, name, quantity, done)
        VALUES (gen_random_uuid(), %L, %L, %L, 'Mon huy', 1, false)$q$, S, T3, B5));
  PERFORM public._pb_ok(t = 'err:42501', '7f không đưa món đã huỷ lên phiếu bếp (để huỷ phiếu không duyệt) (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.kitchen_tickets SET status='huy' WHERE id=%L$q$, T3));
  PERFORM public._pb_ok(t = 'err:42501', '7g vẫn không huỷ được phiếu khi chưa huỷ món thật (' || t || ')');
  t := public._pb_try(format($q$INSERT INTO public.ban_session_items (store_id, session_id, product_name, unit_price, quantity, subtotal, kitchen_status)
        VALUES (%L, %L, 'Tra da', 5000, 1, 5000, 'da_gui')$q$, S, SS));
  PERFORM public._pb_ok(t = 'ok:1', '7h quầy bán mang đi: thêm món "đã gửi bếp" vẫn được (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.ban_session_items SET session_id=%L WHERE id=%L$q$, SC, B3));
  PERFORM public._pb_ok(t = 'err:42501', '7i không chuyển món đã gửi sang bàn đã đóng (' || t || ')');
  t := public._pb_try(format($q$UPDATE public.ban_session_items SET session_id=%L WHERE id=%L$q$, SX, B3));
  PERFORM public._pb_ok(t LIKE 'err:%' OR t = 'ok:0', '7j không chuyển món sang bàn quán khác (' || t || ')');

  RAISE NOTICE '>>> KHOÁ PHIẾU BẾP + THU CHI TỰ ĐỘNG v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
