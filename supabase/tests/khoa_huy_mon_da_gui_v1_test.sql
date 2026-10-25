-- ============================================================================
-- TEST: Khoá huỷ / giảm món đã gửi bếp v1 (20261023_khoa_huy_mon_da_gui_v1.sql)
-- Chạy kiểu app thật: anon + header (máy chưa JWT) và authenticated + JWT (kiểm PIN).
-- CHỈ CHẠY TRÊN DB đã áp migration. Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._kh_app(p_uid uuid, p_store uuid)
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

CREATE OR REPLACE FUNCTION public._kh_jwt(p_uid uuid, p_store uuid)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('role', 'authenticated', 'sub', p_uid::text)::text, true);
  PERFORM set_config('request.headers', json_build_object('x-store-id', p_store::text)::text, true);
END
$f$;

CREATE OR REPLACE FUNCTION public._kh_admin()
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.headers', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
END
$f$;

CREATE OR REPLACE FUNCTION public._kh_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._kh_try(p_sql text)
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

CREATE OR REPLACE FUNCTION public._kh_item(p_id uuid)
RETURNS public.ban_session_items LANGUAGE sql AS $f$
  SELECT * FROM public.ban_session_items WHERE id = p_id
$f$;

DO $test$
DECLARE
  A  uuid := gen_random_uuid();   -- chủ quán S
  M  uuid := gen_random_uuid();   -- quản lý S (có PIN 246810)
  W  uuid := gen_random_uuid();   -- phục vụ S
  W2 uuid := gen_random_uuid();   -- phục vụ S khác
  X  uuid := gen_random_uuid();   -- chủ quán S2
  S  uuid := gen_random_uuid();
  S2 uuid := gen_random_uuid();
  SS uuid := gen_random_uuid();   -- phiên bàn đang mở
  SB uuid := gen_random_uuid();   -- phiên bàn thứ 2 (gộp bàn)
  I1 uuid := gen_random_uuid(); I2 uuid := gen_random_uuid(); I3 uuid := gen_random_uuid();
  I4 uuid := gen_random_uuid(); I5 uuid := gen_random_uuid(); I6 uuid := gen_random_uuid();
  I7 uuid := gen_random_uuid(); I8 uuid := gen_random_uuid();
  SD uuid := gen_random_uuid(); SE uuid := gen_random_uuid(); SC uuid := gen_random_uuid();
  I9 uuid := gen_random_uuid(); I10 uuid := gen_random_uuid(); I11 uuid := gen_random_uuid();
  I12 uuid := gen_random_uuid(); I13 uuid := gen_random_uuid();
  Q  uuid := gen_random_uuid();   -- vai trò tên tiếng Việt "Quản lý ca"
  O3 uuid := gen_random_uuid();   -- chủ quán S3 chỉ qua stores.owner_user_id
  S3 uuid := gen_random_uuid(); S3S uuid := gen_random_uuid(); I14 uuid := gen_random_uuid();
  t  text;
  j  jsonb;
  n  integer;
  r  record;
BEGIN
  RAISE NOTICE '>>> KHOÁ HUỶ MÓN ĐÃ GỬI v1: BẮT ĐẦU <<<';
  PERFORM public._kh_admin();
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name, quick_pin) VALUES
    (A,  '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A', NULL),
    (M,  '+84' || (910000000 + (random()*9999999)::int),  'x', 'Quan ly M', extensions.crypt('246810', extensions.gen_salt('bf', 4))),
    (W,  '+84' || (800000000 + (random()*99999999)::int), 'x', 'Phuc vu W', NULL),
    (W2, '+84' || (810000000 + (random()*9999999)::int),  'x', 'Phuc vu W2', NULL),
    (X,  '+84' || (700000000 + (random()*99999999)::int), 'x', 'Chu X', NULL);
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
    (S,  'K' || substr(S::text, 1, 7),  'Quan KH',  A),
    (S2, 'K' || substr(S2::text, 1, 7), 'Quan KH2', X);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S, 'owner', true), (M, S, 'manager', false), (W, S, 'waiter', false),
    (W2, S, 'waiter', false), (X, S2, 'owner', true);
  INSERT INTO public.ban_sessions (id, store_id, status) VALUES (SS, S, 'open'), (SB, S, 'open');
  INSERT INTO public.ban_session_items (id, store_id, session_id, product_name, unit_price, price, quantity, subtotal, kitchen_status) VALUES
    (I1, S, SS, 'Tra da',   5000, 5000, 3, 15000, 'da_gui'),
    (I2, S, SS, 'Ca phe',  20000, 20000, 2, 40000, 'da_gui'),
    (I3, S, SS, 'Banh mi', 15000, 15000, 1, 15000, 'chua_gui'),
    (I4, S, SS, 'Pho',     40000, 40000, 1, 40000, 'xong'),
    (I5, S, SS, 'Bun',     35000, 35000, 1, 35000, 'huy'),
    (I6, S, SS, 'Nuoc cam',25000, 25000, 1, 25000, 'dang_lam'),
    (I7, S, SS, 'Xoi',     10000, 10000, 2, 20000, 'chua_gui'),
    (I8, S, SS, 'Che',     12000, 12000, 1, 12000, 'da_gui');

  -- ── 1. Nhân viên không có duyệt: không huỷ / giảm / xoá / phá món đã gửi ──
  PERFORM public._kh_app(W, S);
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='huy' WHERE id=%L$q$, I1));
  PERFORM public._kh_ok(t = 'err:42501', '1a phục vụ không duyệt không huỷ được món đã gửi (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET quantity=2, subtotal=10000 WHERE id=%L$q$, I1));
  PERFORM public._kh_ok(t = 'err:42501', '1b không giảm được số lượng món đã gửi (' || t || ')');
  t := public._kh_try(format($q$DELETE FROM public.ban_session_items WHERE id=%L$q$, I1));
  PERFORM public._kh_ok(t = 'err:42501', '1c không xoá được món đã gửi (' || t || ')');
  t := public._kh_try(format($q$DELETE FROM public.ban_session_items WHERE id=%L$q$, I5));
  PERFORM public._kh_ok(t = 'err:42501', '1d không xoá được món đã huỷ (xoá dấu vết) (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='chua_gui' WHERE id=%L$q$, I1));
  PERFORM public._kh_ok(t = 'err:42501', '1e không kéo món đã gửi về "chưa gửi" (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET unit_price=1000, price=1000, subtotal=3000 WHERE id=%L$q$, I1));
  PERFORM public._kh_ok(t = 'err:42501', '1f không đổi giá món đã gửi (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET subtotal=1 WHERE id=%L$q$, I1));
  PERFORM public._kh_ok(t = 'err:42501', '1g không đổi thành tiền món đã gửi (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET quantity=5, subtotal=25000 WHERE id=%L$q$, I1));
  PERFORM public._kh_ok(t = 'err:42501', '1h không tăng số lượng món đã gửi qua API (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET quantity=0, subtotal=0 WHERE id=%L$q$, I1));
  PERFORM public._kh_ok(t = 'err:42501', '1i không đặt số lượng 0 (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='huy' WHERE session_id=%L AND kitchen_status<>'huy'$q$, SS));
  PERFORM public._kh_ok(t = 'err:42501', '1j không huỷ cả bàn khi không có duyệt (' || t || ')');
  PERFORM public._kh_admin();
  PERFORM public._kh_ok((public._kh_item(I1)).kitchen_status = 'da_gui' AND (public._kh_item(I1)).quantity = 3
    AND (SELECT count(*) FROM public.ban_session_items WHERE session_id = SS) = 8,
    '1k dữ liệu không đổi sau các lần bị chặn');

  -- ── 2. Việc thường ngày vẫn chạy ──
  PERFORM public._kh_app(W, S);
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET note='it da' WHERE id=%L$q$, I1));
  PERFORM public._kh_ok(t = 'ok:1', '2a sửa ghi chú món đã gửi (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET added_by='W' WHERE session_id=%L AND added_by IS NULL$q$, SS));
  PERFORM public._kh_ok(t LIKE 'ok:%', '2b đóng dấu người thêm món (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='dang_lam' WHERE id IN (%L,%L)$q$, I1, I4));
  PERFORM public._kh_ok(t = 'ok:2', '2c bếp đổi tiến độ (đang làm / làm lại món xong) (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='xong' WHERE id IN (%L,%L)$q$, I1, I6));
  PERFORM public._kh_ok(t = 'ok:2', '2d bếp tick xong (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET quantity=3, subtotal=45000 WHERE id=%L$q$, I3));
  PERFORM public._kh_ok(t = 'ok:1', '2e +/- món chưa gửi tự do (' || t || ')');
  t := public._kh_try(format($q$DELETE FROM public.ban_session_items WHERE id=%L$q$, I3));
  PERFORM public._kh_ok(t = 'ok:1', '2f xoá món chưa gửi (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET session_id=%L WHERE id=%L$q$, SB, I4));
  PERFORM public._kh_ok(t = 'ok:1', '2g gộp bàn: chuyển món đã gửi sang phiên khác (' || t || ')');

  -- ── 3. Món đã huỷ: app bếp cũ ghi đè trạng thái → giữ 'huy', không báo lỗi; không sửa số ──
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='dang_lam' WHERE id IN (%L,%L)$q$, I5, I8));
  PERFORM public._kh_admin();
  PERFORM public._kh_ok(t = 'ok:2' AND (public._kh_item(I5)).kitchen_status = 'huy'
    AND (public._kh_item(I8)).kitchen_status = 'dang_lam',
    '3a bếp cập nhật cả phiếu: món đã huỷ vẫn là huỷ, món khác đổi bình thường (' || t || ')');
  PERFORM public._kh_app(W, S);
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET quantity=2, subtotal=70000 WHERE id=%L$q$, I5));
  PERFORM public._kh_ok(t = 'err:42501', '3b món đã huỷ không sửa số lượng được (' || t || ')');

  -- ── 4. Chủ quán / Quản lý tự duyệt: huỷ được, máy chủ ghi sổ ──
  PERFORM public._kh_app(A, S);
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='huy' WHERE id=%L$q$, I1));
  PERFORM public._kh_ok(t = 'ok:1', '4a chủ quán huỷ món đã gửi (' || t || ')');
  PERFORM public._kh_admin();
  SELECT * INTO r FROM public.ban_item_void_server_logs WHERE item_id = I1;
  PERFORM public._kh_ok(FOUND AND r.action = 'huy' AND r.approval_kind = 'quan_ly' AND r.caller_id = A
    AND r.approver_id = A AND r.old_qty = 3 AND r.new_qty = 0 AND r.amount = 15000 AND r.old_status = 'xong',
    '4b sổ máy chủ ghi đúng: huỷ, chủ quán tự duyệt, 3 → 0, 15.000đ');
  PERFORM public._kh_app(M, S);
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET quantity=1, subtotal=40000 WHERE id=%L$q$, I6));
  PERFORM public._kh_ok(t = 'err:42501', '4c quản lý cũng không tăng số món đã gửi (' || t || ')');

  -- ── 5. Phục vụ + PIN quản lý (JWT, đúng luồng app) ──
  PERFORM public._kh_jwt(W, S);
  j := public.verify_manager_quick_pin_v4(S, '111111');
  PERFORM public._kh_ok((j->>'success')::boolean IS NOT TRUE, '5a PIN sai: không duyệt');
  PERFORM public._kh_admin();
  PERFORM public._kh_ok(NOT EXISTS (SELECT 1 FROM public.ban_item_void_grants WHERE caller_id = W),
    '5b PIN sai không tạo lượt duyệt');
  PERFORM public._kh_jwt(W, S);
  j := public.verify_manager_quick_pin_v4(S, '246810');
  PERFORM public._kh_ok((j->>'success')::boolean AND (j->>'manager_id')::uuid = M,
    '5c PIN đúng: hàm kiểm PIN vẫn trả quản lý như cũ');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET quantity=1, subtotal=20000 WHERE id=%L$q$, I2));
  PERFORM public._kh_ok(t = 'ok:1', '5d có PIN: giảm món đã gửi 2 → 1 (' || t || ')');
  PERFORM public._kh_admin();
  SELECT * INTO r FROM public.ban_item_void_server_logs WHERE item_id = I2;
  PERFORM public._kh_ok(FOUND AND r.action = 'giam' AND r.approval_kind = 'pin' AND r.caller_id = W
    AND r.approver_id = M AND r.approver_name = 'Quan ly M' AND r.old_qty = 2 AND r.new_qty = 1 AND r.amount = 20000,
    '5e sổ máy chủ ghi: giảm, W làm, M duyệt PIN, 2 → 1, 20.000đ');
  -- Lượt duyệt đã dùng ở request trước (giả lập request khác: đổi txid đã dùng)
  UPDATE public.ban_item_void_grants SET used_txid = 1 WHERE caller_id = W;
  PERFORM public._kh_jwt(W, S);
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='huy' WHERE id=%L$q$, I8));
  PERFORM public._kh_ok(t = 'err:42501', '5f mỗi lượt PIN chỉ dùng cho 1 thao tác (' || t || ')');
  -- Lượt duyệt của W không dùng được cho W2
  PERFORM public._kh_admin();
  UPDATE public.ban_item_void_grants SET used_txid = NULL WHERE caller_id = W;
  PERFORM public._kh_jwt(W2, S);
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='huy' WHERE id=%L$q$, I8));
  PERFORM public._kh_ok(t = 'err:42501', '5g lượt duyệt của người khác không dùng được (' || t || ')');
  -- Lượt duyệt quá 5 phút
  PERFORM public._kh_admin();
  UPDATE public.ban_item_void_grants SET created_at = now() - interval '11 minutes' WHERE caller_id = W;
  PERFORM public._kh_jwt(W, S);
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='huy' WHERE id=%L$q$, I8));
  PERFORM public._kh_ok(t = 'err:42501', '5h lượt duyệt quá 5 phút hết hạn (' || t || ')');
  -- PIN mới → huỷ cả bàn trong 1 câu lệnh (đúng luồng "Huỷ bàn")
  j := public.verify_manager_quick_pin_v4(S, '246810');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='huy' WHERE session_id=%L AND kitchen_status<>'huy'$q$, SS));
  PERFORM public._kh_admin();
  PERFORM public._kh_ok(t LIKE 'ok:%' AND NOT EXISTS (SELECT 1 FROM public.ban_session_items WHERE session_id = SS AND kitchen_status <> 'huy'),
    '5i một lần PIN huỷ được cả bàn trong một câu lệnh (' || t || ')');
  SELECT count(*) INTO n FROM public.ban_item_void_server_logs WHERE session_id = SS AND approval_kind = 'pin' AND action = 'huy';
  PERFORM public._kh_ok(n = 3, '5j sổ máy chủ ghi từng món đã gửi bị huỷ (I2, I6, I8; món chưa gửi không ghi) (' || n || ')');

  -- ── 6. Không lách bằng gọi thẳng hàm / bảng phụ ──
  PERFORM public._kh_app(W, S);
  t := public._kh_try(format($q$SELECT public.qn_ban_item_void_check_v1(%L, 'huy', 0, 0)$q$, I4));
  PERFORM public._kh_ok(t = 'err:P0001', '6a gọi thẳng hàm kiểm duyệt bị chặn (' || t || ')');
  t := public._kh_try($q$SELECT 1 FROM public.ban_item_void_grants$q$);
  PERFORM public._kh_ok(t = 'err:42501', '6b app không đọc bảng lượt duyệt (' || t || ')');
  t := public._kh_try(format($q$INSERT INTO public.ban_item_void_grants (store_id, caller_id) VALUES (%L, %L)$q$, S, W));
  PERFORM public._kh_ok(t = 'err:42501', '6c app không tự tạo lượt duyệt (' || t || ')');
  t := public._kh_try(format($q$INSERT INTO public.ban_item_void_server_logs (store_id, item_id, action, approval_kind) VALUES (%L, %L, 'huy', 'pin')$q$, S, I4));
  PERFORM public._kh_ok(t = 'err:42501', '6d app không ghi giả sổ máy chủ (' || t || ')');
  t := public._kh_try(format($q$DELETE FROM public.ban_item_void_server_logs WHERE store_id=%L$q$, S));
  PERFORM public._kh_ok(t = 'err:42501', '6e app không xoá sổ máy chủ (' || t || ')');
  t := public._kh_try($q$SELECT public.qn_is_store_manager_v1(NULL, NULL)$q$);
  PERFORM public._kh_ok(t = 'err:42501', '6f app không gọi hàm kiểm vai trò (' || t || ')');

  -- ── 7. Đọc sổ máy chủ: đúng quán ──
  PERFORM public._kh_app(A, S);
  SELECT count(*) INTO n FROM public.ban_item_void_server_logs;
  PERFORM public._kh_ok(n = 5, '7a chủ quán S đọc được 5 dòng sổ của quán mình (' || n || ')');
  PERFORM public._kh_app(X, S2);
  SELECT count(*) INTO n FROM public.ban_item_void_server_logs;
  PERFORM public._kh_ok(n = 0, '7b quán khác không thấy (' || n || ')');

  -- ── 8. Sổ huỷ do app ghi: chỉ thêm ──
  PERFORM public._kh_app(W, S);
  t := public._kh_try(format($q$INSERT INTO public.void_audit_logs (store_id, void_type, reference_id, amount) VALUES (%L, 'void_item', %L, 1)$q$, S, I2));
  PERFORM public._kh_ok(t = 'ok:1', '8a app vẫn thêm void_audit_logs (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.void_audit_logs SET amount=0 WHERE store_id=%L$q$, S));
  PERFORM public._kh_ok(t = 'err:42501', '8b không sửa void_audit_logs (' || t || ')');
  t := public._kh_try(format($q$DELETE FROM public.void_audit_logs WHERE store_id=%L$q$, S));
  PERFORM public._kh_ok(t = 'err:42501', '8c không xoá void_audit_logs (' || t || ')');
  t := public._kh_try(format($q$INSERT INTO public.ban_session_void_logs (store_id, session_id, product_name, action) VALUES (%L, %L, 'x', 'cancel')$q$, S, SS));
  PERFORM public._kh_ok(t = 'ok:1', '8d app vẫn thêm ban_session_void_logs (' || t || ')');
  t := public._kh_try(format($q$DELETE FROM public.ban_session_void_logs WHERE store_id=%L$q$, S));
  PERFORM public._kh_ok(t = 'err:42501', '8e không xoá ban_session_void_logs (' || t || ')');

  -- ── 9. Quản trị / hàm máy chủ không bị chặn ──
  PERFORM public._kh_admin();
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET quantity=9 WHERE id=%L$q$, I4));
  PERFORM public._kh_ok(t = 'ok:1', '9a quản trị (không phải anon) sửa được (' || t || ')');


  -- ── 10. Góp ý QC: một PIN chỉ một bàn; huỷ bàn qua trạng thái; số âm; thành tiền khi giảm ──
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (Q,  '+84' || (920000000 + (random()*9999999)::int), 'x', 'QL ca Q'),
    (O3, '+84' || (930000000 + (random()*9999999)::int), 'x', 'Chu O3');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (Q, S, 'Quản lý ca', false);
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES (S3, 'K' || substr(S3::text, 1, 7), 'Quan KH3', O3);
  INSERT INTO public.ban_sessions (id, store_id, status) VALUES (SD, S, 'open'), (SE, S, 'open'), (SC, S, 'open'), (S3S, S3, 'open');
  INSERT INTO public.ban_session_items (id, store_id, session_id, product_name, unit_price, price, quantity, subtotal, kitchen_status) VALUES
    (I9,  S, SD, 'Mon D', 10000, 10000, 1, 10000, 'da_gui'),
    (I10, S, SB, 'Mon B', 10000, 10000, 1, 10000, 'da_gui'),
    (I11, S, SE, 'Mon E', 10000, 10000, 2, 20000, 'xong'),
    (I12, S, SC, 'Mon C', 10000, 10000, 1, 10000, 'huy'),
    (I13, S, SD, 'Mon D2', 8000, 8000, 3, 24000, 'da_gui'),
    (I14, S3, S3S, 'Mon 3', 9000, 9000, 1, 9000, 'da_gui'),
    (gen_random_uuid(), S, SD, 'Mon chua gui', 7000, 7000, 1, 7000, 'chua_gui');
  UPDATE public.ban_sessions SET status = 'closed' WHERE id = SC;

  PERFORM public._kh_jwt(W, S);
  j := public.verify_manager_quick_pin_v4(S, '246810');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='huy' WHERE id=%L$q$, I9));
  PERFORM public._kh_ok(t = 'ok:1', '10a PIN huỷ món ở bàn D (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='huy' WHERE id=%L$q$, I10));
  PERFORM public._kh_ok(t = 'err:42501', '10b cùng lượt PIN không huỷ được món bàn khác (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET quantity=2, subtotal=10000 WHERE id=%L$q$, I13));
  PERFORM public._kh_ok(t = 'err:42501', '10c giảm có duyệt nhưng thành tiền sai (2 × 8.000 ≠ 10.000) bị chặn (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET quantity=2, subtotal=16000 WHERE id=%L$q$, I13));
  PERFORM public._kh_ok(t = 'ok:1', '10d giảm có duyệt, thành tiền đúng, cùng bàn D (' || t || ')');

  PERFORM public._kh_app(W, S);
  t := public._kh_try(format($q$UPDATE public.ban_sessions SET status='cancelled' WHERE id=%L$q$, SE));
  PERFORM public._kh_ok(t = 'err:42501', '10e phục vụ không huỷ bàn còn món đã gửi bằng cách đổi trạng thái (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_sessions SET status='cancelled' WHERE id=%L$q$, SB));
  PERFORM public._kh_ok(t = 'err:42501', '10f gộp món sang bàn khác rồi huỷ bàn đó cũng bị chặn (' || t || ')');
  PERFORM public._kh_app(A, S);
  t := public._kh_try(format($q$UPDATE public.ban_sessions SET status='cancelled' WHERE id=%L$q$, SE));
  PERFORM public._kh_ok(t = 'ok:1', '10g chủ quán huỷ bàn được (' || t || ')');
  PERFORM public._kh_admin();
  SELECT count(*) INTO n FROM public.ban_item_void_server_logs WHERE session_id = SE AND action = 'huy_ban';
  PERFORM public._kh_ok(n = 1, '10h sổ máy chủ ghi món bị huỷ theo bàn (' || n || ')');

  PERFORM public._kh_app(W, S);
  t := public._kh_try(format($q$INSERT INTO public.ban_session_items (store_id, session_id, product_name, unit_price, quantity, subtotal) VALUES (%L, %L, 'tru tien', 5000, -3, -15000)$q$, S, SD));
  PERFORM public._kh_ok(t = 'err:23514', '10i không chèn được dòng số lượng âm để trừ bill (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET subtotal=-5000 WHERE session_id=%L AND product_name='Mon chua gui'$q$, SD));
  PERFORM public._kh_ok(t = 'err:23514', '10j không sửa món chưa gửi thành tiền âm (' || t || ')');
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='xong' WHERE id=%L$q$, I12));
  PERFORM public._kh_admin();
  PERFORM public._kh_ok(t = 'ok:1' AND (public._kh_item(I12)).kitchen_status = 'huy',
    '10k bếp cũ ghi đè món đã huỷ ở bàn ĐÃ ĐÓNG: không lỗi, vẫn huỷ (' || t || ')');

  PERFORM public._kh_app(Q, S);
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='huy' WHERE id=%L$q$, I10));
  PERFORM public._kh_ok(t = 'ok:1', '10l vai trò "Quản lý ca" tự duyệt như app (' || t || ')');
  PERFORM public._kh_app(O3, S3);
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET kitchen_status='huy' WHERE id=%L$q$, I14));
  PERFORM public._kh_ok(t = 'ok:1', '10m chủ quán chỉ có ở stores.owner_user_id tự duyệt được (' || t || ')');
  PERFORM public._kh_jwt(A, S);
  t := public._kh_try(format($q$UPDATE public.ban_session_items SET quantity=1, subtotal=8000 WHERE id=%L$q$, I13));
  PERFORM public._kh_ok(t = 'ok:1', '10n chủ quán đăng nhập JWT giảm món được (' || t || ')');
  PERFORM public._kh_admin();
  PERFORM public._kh_ok((SELECT amount FROM public.ban_item_void_server_logs WHERE item_id = I13 AND new_qty = 1) = 8000,
    '10o sổ ghi số tiền theo thành tiền giảm (16.000 → 8.000)');

  RAISE NOTICE '>>> KHOÁ HUỶ MÓN ĐÃ GỬI v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
