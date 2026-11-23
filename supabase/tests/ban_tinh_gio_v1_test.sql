-- ============================================================================
-- TEST: 20261123_ban_tinh_gio_v1.sql — bàn tính giờ. Một giao dịch, kết thúc ROLLBACK.
-- Chạy trên DB đã áp migration (bản sao, hoặc máy chủ thật: không để lại dữ liệu).
-- Mẹo giờ: đặt mốc lùi "N phút trừ 30 giây" để số phút làm tròn lên ra đúng N dù máy chạy chậm vài giây.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._tg_as(p_role text, p_uid uuid DEFAULT NULL, p_store uuid DEFAULT NULL)
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

CREATE OR REPLACE FUNCTION public._tg_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

-- Chạy một câu lệnh: 'ok:<số dòng>' hoặc 'err:<SQLSTATE>:<đầu thông báo>'.
CREATE OR REPLACE FUNCTION public._tg_try(p_sql text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE n integer;
BEGIN
  EXECUTE p_sql;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN 'ok:' || n;
EXCEPTION WHEN OTHERS THEN
  RETURN 'err:' || SQLSTATE || ':' || left(SQLERRM, 60);
END
$f$;

-- Gọi một hàm trả jsonb; lỗi văng ra thì trả {"raised": SQLSTATE, "msg": ...}.
CREATE OR REPLACE FUNCTION public._tg_rpc(p_sql text)
RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE j jsonb;
BEGIN
  EXECUTE p_sql INTO j;
  RETURN j;
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('raised', SQLSTATE, 'msg', SQLERRM);
END
$f$;

-- Mô phỏng hàm máy chủ đóng phiên mà không biết gì về tiền giờ (như app / hàm bản cũ).
CREATE OR REPLACE FUNCTION public._tg_server_close(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $f$
BEGIN
  UPDATE public.ban_sessions SET status = 'closed', closed_at = now() WHERE id = p_id;
END
$f$;
GRANT EXECUTE ON FUNCTION public._tg_server_close(uuid) TO anon, authenticated;

DO $test$
DECLARE
  A  uuid := gen_random_uuid();   -- chủ quán S
  B  uuid := gen_random_uuid();   -- phục vụ của S (thu tiền được, không phải quản lý)
  C  uuid := gen_random_uuid();   -- chủ quán khác
  S  uuid := gen_random_uuid();
  S2 uuid := gen_random_uuid();
  Z  text := gen_random_uuid()::text;
  TG1 uuid := gen_random_uuid(); TG2 uuid := gen_random_uuid(); TG3 uuid := gen_random_uuid();
  TG4 uuid := gen_random_uuid(); TG5 uuid := gen_random_uuid(); TG6 uuid := gen_random_uuid();
  TN1 uuid := gen_random_uuid(); TN2 uuid := gen_random_uuid();
  PG  uuid := gen_random_uuid();  -- Giờ bàn lỗ 60.000/giờ
  PG2 uuid := gen_random_uuid();  -- Giờ bàn VIP 70.000/giờ
  PF  uuid := gen_random_uuid();  -- Nước suối 10.000
  PX  uuid := gen_random_uuid();  -- món của quán khác
  P1 uuid := gen_random_uuid(); P2 uuid := gen_random_uuid(); P3 uuid := gen_random_uuid();
  P4 uuid := gen_random_uuid(); P5 uuid := gen_random_uuid(); P6 uuid := gen_random_uuid();
  P7 uuid := gen_random_uuid(); PN uuid := gen_random_uuid(); PN2 uuid := gen_random_uuid();
  j jsonb; r text; n integer; v_id uuid; v_id2 uuid; v_moc timestamptz; v_moc2 timestamptz;
  v_num numeric; v_s text; v_item uuid;
BEGIN
  RAISE NOTICE '>>> BÀN TÍNH GIỜ v1: BẮT ĐẦU <<<';

  PERFORM public._tg_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*33000000)::int), 'x', 'Chu A'),
    (B, '+84' || (933000001 + (random()*33000000)::int), 'x', 'Phuc vu B'),
    (C, '+84' || (966000002 + (random()*33000000)::int), 'x', 'Chu C');
  -- lùi created_at: chốt 15 quán / 10 phút (qn_rate_limit_signup)
  INSERT INTO public.stores (id, store_code, name, owner_user_id, created_at) VALUES
    (S,  'T' || substr(S::text, 1, 7),  'Quan test tinh gio', A, now() - interval '1 day'),
    (S2, 'T' || substr(S2::text, 1, 7), 'Quan khac',          C, now() - interval '1 day');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S, 'owner', true), (B, S, 'waiter', false), (C, S2, 'owner', true);
  INSERT INTO public.ban_zones (id, store_id, name) VALUES (Z, S, 'Khu bi da');
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name) VALUES
    (TG1::text, S, Z, 'Bi da 1'), (TG2::text, S, Z, 'Bi da 2'), (TG3::text, S, Z, 'Bi da 3'),
    (TG4::text, S, Z, 'Bi da 4'), (TG5::text, S, Z, 'Bi da 5'), (TG6::text, S, Z, 'Bi da 6'),
    (TN1::text, S, Z, 'Ban 1'),   (TN2::text, S, Z, 'Ban 2');
  INSERT INTO public.products (id, store_id, name, sell_price, cost_price, unit, is_available, is_active) VALUES
    (PG,  S,  'Giờ bàn lỗ',    60000, 0,    'giờ',  true, true),
    (PG2, S,  'Giờ bàn VIP',   70000, 0,    'giờ',  true, true),
    (PF,  S,  'Nước suối',     10000, 4000, 'chai', true, true),
    (PX,  S2, 'Giờ quán khác', 50000, 0,    'giờ',  true, true);

  -- ── T1: ai gắn được giá giờ cho bàn ──────────────────────────────────────────
  PERFORM public._tg_as('authenticated', B, S);
  r := public._tg_try(format($q$UPDATE public.ban_dining_tables SET gia_gio_product_id=%L WHERE id=%L$q$, PG, TG1));
  PERFORM public._tg_as('admin');
  PERFORM public._tg_ok((SELECT gia_gio_product_id IS NULL FROM public.ban_dining_tables WHERE id = TG1::text)
    AND (r LIKE 'err:42501:TINH_GIO_CHI_QUAN_LY%' OR r = 'ok:0'), 'T1a phục vụ không đặt được giá giờ (' || r || ')');

  PERFORM public._tg_as('authenticated', A, S);
  r := public._tg_try(format($q$UPDATE public.ban_dining_tables SET gia_gio_product_id=%L WHERE id=%L$q$, PX, TG1));
  PERFORM public._tg_ok(r LIKE 'err:42501:TINH_GIO_MON_SAI%', 'T1b món của quán khác bị từ chối (' || r || ')');
  r := public._tg_try(format($q$UPDATE public.ban_dining_tables SET gia_gio_product_id=%L WHERE id=%L$q$, gen_random_uuid(), TG1));
  PERFORM public._tg_ok(r LIKE 'err:42501:TINH_GIO_MON_SAI%', 'T1c món không tồn tại bị từ chối (' || r || ')');
  r := public._tg_try(format($q$UPDATE public.ban_dining_tables SET gia_gio_product_id=%L WHERE id=%L$q$, PG, TG1));
  PERFORM public._tg_ok(r = 'ok:1', 'T1d chủ quán đặt giá giờ cho bàn (' || r || ')');

  PERFORM public._tg_as('admin');
  UPDATE public.ban_dining_tables SET gia_gio_product_id = PG  WHERE id IN (TG3::text, TG5::text, TG6::text);
  UPDATE public.ban_dining_tables SET gia_gio_product_id = PG2 WHERE id IN (TG2::text, TG4::text);

  -- ── T2: mở bàn — mốc giờ do máy chủ đặt ─────────────────────────────────────
  PERFORM public._tg_as('authenticated', A, S);
  r := public._tg_try(format($q$INSERT INTO public.ban_sessions (id, store_id, table_id, status, gio_bat_dau)
    VALUES (%L, %L, %L, 'open', '2020-01-01')$q$, P1, S, TG1));
  PERFORM public._tg_as('admin');
  SELECT gio_bat_dau INTO v_moc FROM public.ban_sessions WHERE id = P1;
  PERFORM public._tg_ok(r = 'ok:1' AND v_moc > clock_timestamp() - interval '1 minute',
    'T2a mở bàn tính giờ: mốc là giờ máy chủ, bỏ qua giờ app gửi (' || r || ', ' || COALESCE(v_moc::text, 'NULL') || ')');

  PERFORM public._tg_as('authenticated', A, S);
  r := public._tg_try(format($q$INSERT INTO public.ban_sessions (id, store_id, table_id, status, gio_bat_dau)
    VALUES (%L, %L, %L, 'open', now())$q$, PN, S, TN1));
  PERFORM public._tg_as('admin');
  PERFORM public._tg_ok(r = 'ok:1' AND (SELECT gio_bat_dau IS NULL FROM public.ban_sessions WHERE id = PN),
    'T2b mở bàn thường: không có mốc giờ dù app gửi (' || r || ')');

  -- ── T3: app không sửa được mốc ──────────────────────────────────────────────
  PERFORM public._tg_as('authenticated', A, S);
  r := public._tg_try(format($q$UPDATE public.ban_sessions SET gio_bat_dau='2020-01-01', guest_count=2 WHERE id=%L$q$, P1));
  PERFORM public._tg_as('admin');
  PERFORM public._tg_ok(r = 'ok:1' AND (SELECT gio_bat_dau = v_moc AND guest_count = 2 FROM public.ban_sessions WHERE id = P1),
    'T3 app sửa mốc giờ: mốc giữ nguyên, cột khác vẫn sửa được (' || r || ')');

  -- ── T4: app không tự ghi dòng tiền giờ ───────────────────────────────────────
  INSERT INTO public.ban_session_items (store_id, session_id, product_id, product_name, unit_price, price, subtotal, quantity, kitchen_status)
    VALUES (S, P1, PF, 'Nước suối', 10000, 10000, 10000, 1, 'da_gui') RETURNING id INTO v_item;
  PERFORM public._tg_as('authenticated', A, S);
  r := public._tg_try(format($q$INSERT INTO public.ban_session_items (store_id, session_id, product_id, product_name, unit_price, subtotal, quantity, kitchen_status, gio_tu, gio_den)
    VALUES (%L, %L, %L, 'Giờ tự chế', 1000, 1000, 1, 'chua_gui', now() - interval '3 hours', now())$q$, S, P1, PG));
  PERFORM public._tg_ok(r LIKE 'err:42501:TINH_GIO_DONG_KHOA%', 'T4a app chèn dòng tiền giờ bị chặn (' || r || ')');
  r := public._tg_try(format($q$UPDATE public.ban_session_items SET gio_tu=now() WHERE id=%L$q$, v_item));
  PERFORM public._tg_ok(r LIKE 'err:42501:TINH_GIO_DONG_KHOA%', 'T4b app biến món thường thành dòng tiền giờ bị chặn (' || r || ')');

  -- ── T5: chốt giờ 90 phút × 60.000/giờ = 90.000 ─────────────────────────────────
  PERFORM public._tg_as('admin');
  v_moc := clock_timestamp() - interval '89 minutes 30 seconds';
  UPDATE public.ban_sessions SET gio_bat_dau = v_moc WHERE id = P1;
  PERFORM public._tg_as('authenticated', A, S);
  j := public._tg_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P1, S));
  PERFORM public._tg_as('admin');
  v_id := (j->'data'->>'item_id')::uuid;
  PERFORM public._tg_ok((j->>'success')::boolean AND (j->'data'->>'so_phut')::int = 90
    AND (j->'data'->>'thanh_tien')::numeric = 90000, 'T5a chốt 90 phút ra 90.000 — ' || left(j::text, 220));
  PERFORM public._tg_ok((SELECT count(*) = 1 AND bool_and(kitchen_status = 'xong' AND product_id = PG AND quantity = 1
      AND subtotal = 90000 AND unit_price = 90000 AND gio_tu = v_moc AND gio_den > gio_tu)
    FROM public.ban_session_items WHERE session_id = P1 AND gio_tu IS NOT NULL),
    'T5b đúng một dòng tiền giờ: món thật, số lượng 1, trạng thái xong, có giờ vào / ra');
  PERFORM public._tg_ok((SELECT total_amount = 100000 FROM public.ban_sessions WHERE id = P1),
    'T5c tổng bàn = nước 10.000 + giờ 90.000');
  PERFORM public._tg_ok((SELECT product_name LIKE 'Giờ bàn lỗ · Bi da 1 · %(1g30)' FROM public.ban_session_items WHERE id = v_id),
    'T5d tên dòng có món, bàn, giờ vào–ra, thời lượng — ' || (SELECT product_name FROM public.ban_session_items WHERE id = v_id));

  -- ── T6: bấm chốt lần nữa (người khác) không sinh dòng thứ hai ────────────────────
  PERFORM public._tg_as('authenticated', B, S);
  j := public._tg_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P1, S));
  PERFORM public._tg_as('admin');
  PERFORM public._tg_ok((j->>'success')::boolean AND (j->'data'->>'item_id')::uuid = v_id
    AND (SELECT count(*) = 1 FROM public.ban_session_items WHERE session_id = P1 AND gio_tu IS NOT NULL),
    'T6 chốt lại: vẫn một dòng, cùng mã dòng — ' || left(j::text, 120));

  -- ── T7: làm tròn lên 1.000đ: 61 phút × 70.000/giờ = 71.166,7 → 72.000 ───────────
  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (P2, S, TG2, 'open');
  PERFORM public._tg_ok((SELECT gio_bat_dau IS NOT NULL FROM public.ban_sessions WHERE id = P2),
    'T7a phiên do máy chủ mở trên bàn tính giờ cũng có mốc');
  UPDATE public.ban_sessions SET gio_bat_dau = clock_timestamp() - interval '60 minutes 30 seconds' WHERE id = P2;
  PERFORM public._tg_as('authenticated', A, S);
  j := public._tg_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P2, S));
  PERFORM public._tg_ok((j->'data'->>'so_phut')::int = 61 AND (j->'data'->>'thanh_tien')::numeric = 72000,
    'T7b 61 phút × 70.000 làm tròn lên 72.000 — ' || left(j::text, 200));

  -- ── T8: app không sửa tiền / xoá dòng tiền giờ ────────────────────────────────
  r := public._tg_try(format($q$UPDATE public.ban_session_items SET subtotal=1000, unit_price=1000 WHERE id=%L$q$, v_id));
  PERFORM public._tg_ok(r LIKE 'err:42501:%', 'T8a app sửa tiền dòng giờ bị chặn (' || r || ')');
  r := public._tg_try(format($q$DELETE FROM public.ban_session_items WHERE id=%L$q$, v_id));
  PERFORM public._tg_ok(r LIKE 'err:42501:%', 'T8b app xoá dòng giờ bị chặn (' || r || ')');
  r := public._tg_try(format($q$UPDATE public.ban_session_items SET session_id=%L WHERE id=%L$q$, PN, v_id));
  PERFORM public._tg_ok(r LIKE 'err:42501:%', 'T8c app dời dòng giờ sang bàn khác bị chặn (' || r || ')');
  PERFORM public._tg_as('admin');
  PERFORM public._tg_ok((SELECT subtotal = 90000 AND session_id = P1 FROM public.ban_session_items WHERE id = v_id),
    'T8d dòng giờ còn nguyên sau ba lần thử');

  -- ── T9: chưa chốt giờ thì không đóng / thanh toán được; chốt rồi thì báo cáo thấy ───────
  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (P3, S, TG3, 'open');
  UPDATE public.ban_sessions SET gio_bat_dau = clock_timestamp() - interval '29 minutes 30 seconds' WHERE id = P3;
  INSERT INTO public.ban_session_items (store_id, session_id, product_id, product_name, unit_price, price, subtotal, quantity, kitchen_status)
    VALUES (S, P3, PF, 'Nước suối', 10000, 10000, 10000, 1, 'xong');
  PERFORM public._tg_as('authenticated', A, S);
  r := public._tg_try(format('SELECT public._tg_server_close(%L)', P3));
  PERFORM public._tg_ok(r LIKE 'err:%:CHUA_CHOT_GIO%', 'T9a hàm máy chủ kiểu cũ không đóng được bàn chưa chốt giờ (' || r || ')');
  j := public._tg_rpc(format($q$SELECT public.settle_ban_session_v5(%L, %L, 'cash', %L)$q$, P3, S, 'tinh-gio-test-a-' || P3::text));
  PERFORM public._tg_as('admin');
  PERFORM public._tg_ok(j::text LIKE '%CHUA_CHOT_GIO%'
    AND (SELECT status = 'open' FROM public.ban_sessions WHERE id = P3)
    AND NOT EXISTS (SELECT 1 FROM public.payment_settlements WHERE session_id = P3)
    AND NOT EXISTS (SELECT 1 FROM public.orders WHERE store_id = S),
    'T9b thanh toán thật khi chưa chốt: báo lỗi, bàn vẫn mở, không sinh hoá đơn — ' || left(j::text, 160));

  PERFORM public._tg_as('authenticated', A, S);
  j := public._tg_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P3, S));
  PERFORM public._tg_ok((j->'data'->>'thanh_tien')::numeric = 30000, 'T9c chốt 30 phút ra 30.000 — ' || left(j::text, 120));
  j := public._tg_rpc(format($q$SELECT public.settle_ban_session_v5(%L, %L, 'cash', %L)$q$, P3, S, 'tinh-gio-test-b-' || P3::text));
  PERFORM public._tg_ok((j->>'success')::boolean AND (j->'data'->>'total_amount')::numeric = 40000,
    'T9d chốt rồi thanh toán được, tổng 40.000 — ' || left(j::text, 200));
  SELECT total_revenue INTO v_num FROM public.get_top_products_for_range_v1(S, now() - interval '1 hour', now() + interval '1 hour')
    WHERE product_id = PG::text;
  PERFORM public._tg_as('admin');
  PERFORM public._tg_ok(v_num = 30000 AND (SELECT status = 'closed' FROM public.ban_sessions WHERE id = P3)
    AND (SELECT count(*) = 1 FROM public.order_items oi JOIN public.orders o ON o.id = oi.order_id
         WHERE o.store_id = S AND oi.product_id = PG AND oi.subtotal = 30000),
    'T9e hoá đơn có dòng tiền giờ và báo cáo món bán chạy (không sửa) thấy 30.000 — ' || COALESCE(v_num::text, 'NULL'));

  -- ── T10: chốt đã quá 15 phút → phải tính lại ──────────────────────────────────
  UPDATE public.ban_session_items SET gio_den = clock_timestamp() - interval '20 minutes'
   WHERE session_id = P2 AND gio_tu IS NOT NULL;
  PERFORM public._tg_as('authenticated', A, S);
  r := public._tg_try(format('SELECT public._tg_server_close(%L)', P2));
  PERFORM public._tg_ok(r LIKE 'err:%:CHOT_GIO_QUA_CU%', 'T10a chốt đã cũ 20 phút: không đóng được (' || r || ')');
  j := public._tg_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P2, S));
  r := public._tg_try(format('SELECT public._tg_server_close(%L)', P2));
  PERFORM public._tg_as('admin');
  PERFORM public._tg_ok(r = 'ok:1' AND (SELECT status = 'closed' FROM public.ban_sessions WHERE id = P2),
    'T10b tính lại giờ rồi đóng được (' || r || ')');

  -- ── T11: app tự đổi bàn ───────────────────────────────────────────────────
  PERFORM public._tg_as('authenticated', A, S);
  r := public._tg_try(format($q$UPDATE public.ban_sessions SET table_id=%L WHERE id=%L$q$, TN2, P1));
  PERFORM public._tg_ok(r LIKE 'err:42501:TINH_GIO_CHUYEN_BAN%', 'T11a app tự chuyển bàn đang tính giờ bị chặn (' || r || ')');
  r := public._tg_try(format($q$UPDATE public.ban_sessions SET table_id=%L WHERE id=%L$q$, TG4, PN));
  PERFORM public._tg_ok(r LIKE 'err:42501:TINH_GIO_CHUYEN_BAN%', 'T11b app tự chuyển bàn thường sang bàn tính giờ bị chặn (' || r || ')');
  r := public._tg_try(format($q$UPDATE public.ban_sessions SET table_id=%L WHERE id=%L$q$, TN2, PN));
  PERFORM public._tg_ok(r = 'ok:1', 'T11c bàn thường sang bàn thường vẫn chạy như cũ (' || r || ')');

  -- ── T12: chuyển bàn tính giờ → bàn tính giờ khác giá ──────────────────────────────
  j := public._tg_rpc(format('SELECT public.ban_chuyen_ban_tinh_gio_v1(%L, %L, %L)', P1, S, TG4::text));
  PERFORM public._tg_as('admin');
  SELECT gio_bat_dau INTO v_moc2 FROM public.ban_sessions WHERE id = P1;
  PERFORM public._tg_ok((j->>'success')::boolean AND j->'data'->>'kieu' = 'chuyen'
    AND (SELECT table_id = TG4 FROM public.ban_sessions WHERE id = P1)
    AND v_moc2 > v_moc AND v_moc2 > clock_timestamp() - interval '1 minute',
    'T12a chuyển sang Bi da 4: đổi bàn, mốc giờ mới — ' || left(j::text, 140));
  PERFORM public._tg_ok((SELECT subtotal IN (90000, 91000) AND product_id = PG AND gio_tu = v_moc
    FROM public.ban_session_items WHERE id = v_id), 'T12b đoạn ở bàn cũ giữ giá bàn cũ');
  UPDATE public.ban_sessions SET gio_bat_dau = clock_timestamp() - interval '29 minutes 30 seconds' WHERE id = P1;
  PERFORM public._tg_as('authenticated', A, S);
  j := public._tg_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P1, S));
  PERFORM public._tg_as('admin');
  v_id2 := (j->'data'->>'item_id')::uuid;
  PERFORM public._tg_ok(v_id2 <> v_id AND (j->'data'->>'thanh_tien')::numeric = 35000
    AND (SELECT product_id = PG2 FROM public.ban_session_items WHERE id = v_id2)
    AND (SELECT count(*) = 2 FROM public.ban_session_items WHERE session_id = P1 AND gio_tu IS NOT NULL),
    'T12c đoạn ở bàn mới là dòng riêng theo giá bàn mới (30 phút × 70.000 = 35.000) — ' || left(j::text, 120));

  -- ── T13: chuyển bàn tính giờ → bàn thường ──────────────────────────────────────
  PERFORM public._tg_as('authenticated', B, S);
  j := public._tg_rpc(format('SELECT public.ban_chuyen_ban_tinh_gio_v1(%L, %L, %L)', P1, S, TN1::text));
  r := public._tg_try(format('SELECT public._tg_server_close(%L)', P1));
  PERFORM public._tg_as('admin');
  PERFORM public._tg_ok((j->>'success')::boolean
    AND (SELECT gio_bat_dau IS NULL AND table_id = TN1 FROM public.ban_sessions WHERE id = P1)
    AND (SELECT count(*) = 2 FROM public.ban_session_items WHERE session_id = P1 AND gio_tu IS NOT NULL)
    AND r = 'ok:1',
    'T13 sang bàn thường: hết tính giờ, hai dòng giờ cũ còn nguyên, đóng được như bàn thường (' || r || ')');

  -- ── T14: gộp bàn tính giờ vào bàn đang có khách ───────────────────────────────────
  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (P4, S, TG5, 'open');
  UPDATE public.ban_sessions SET gio_bat_dau = clock_timestamp() - interval '59 minutes 30 seconds' WHERE id = P4;
  INSERT INTO public.ban_session_items (store_id, session_id, product_id, product_name, unit_price, price, subtotal, quantity, kitchen_status)
    VALUES (S, P4, PF, 'Nước suối', 10000, 10000, 10000, 1, 'da_gui');
  PERFORM public._tg_as('authenticated', A, S);
  j := public._tg_rpc(format('SELECT public.ban_chuyen_ban_tinh_gio_v1(%L, %L, %L)', P4, S, TN2::text));
  PERFORM public._tg_as('admin');
  PERFORM public._tg_ok((j->>'success')::boolean AND j->'data'->>'kieu' = 'gop'
    AND (SELECT status = 'closed' AND gio_bat_dau IS NULL FROM public.ban_sessions WHERE id = P4)
    AND (SELECT count(*) = 2 AND sum(subtotal) = 70000 FROM public.ban_session_items WHERE session_id = PN)
    AND (SELECT total_amount = 70000 FROM public.ban_sessions WHERE id = PN)
    AND NOT EXISTS (SELECT 1 FROM public.ban_session_items WHERE session_id = P4),
    'T14 gộp: giờ bàn nguồn chốt 60.000, món dời sang bàn đích, bàn nguồn đóng — ' || left(j::text, 120));

  -- ── T15: người của quán khác ────────────────────────────────────────────────
  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (P5, S, TG6, 'open');
  UPDATE public.ban_sessions SET gio_bat_dau = clock_timestamp() - interval '29 minutes 30 seconds' WHERE id = P5;
  PERFORM public._tg_as('authenticated', C, S2);
  j := public._tg_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P5, S));
  PERFORM public._tg_ok(j->>'raised' = '42501', 'T15a chủ quán khác chốt giờ quán này: bị từ chối — ' || left(j::text, 120));
  j := public._tg_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P5, S2));
  PERFORM public._tg_ok((j->>'success')::boolean IS FALSE, 'T15b gọi bằng quán của mình với phiên quán khác: không thấy phiên — ' || left(j::text, 120));
  j := public._tg_rpc(format('SELECT public.ban_chuyen_ban_tinh_gio_v1(%L, %L, %L)', P5, S, TG1::text));
  PERFORM public._tg_as('admin');
  PERFORM public._tg_ok(j->>'raised' = '42501'
    AND NOT EXISTS (SELECT 1 FROM public.ban_session_items WHERE session_id = P5),
    'T15c chủ quán khác chuyển bàn quán này: bị từ chối, không ghi gì');

  -- ── T16: không đổi giá giờ khi bàn đang chạy ───────────────────────────────────
  PERFORM public._tg_as('authenticated', A, S);
  r := public._tg_try(format($q$UPDATE public.ban_dining_tables SET gia_gio_product_id=%L WHERE id=%L$q$, PG2, TG6));
  PERFORM public._tg_ok(r LIKE 'err:42501:TINH_GIO_BAN_DANG_CHAY%', 'T16a đổi giá giờ bàn đang có khách bị chặn (' || r || ')');
  r := public._tg_try(format($q$UPDATE public.ban_dining_tables SET gia_gio_product_id=NULL WHERE id=%L$q$, TG6));
  PERFORM public._tg_ok(r LIKE 'err:42501:TINH_GIO_BAN_DANG_CHAY%', 'T16b gỡ giá giờ bàn đang có khách bị chặn (' || r || ')');
  r := public._tg_try(format($q$UPDATE public.ban_dining_tables SET name='Bi da 6 moi' WHERE id=%L$q$, TG6));
  PERFORM public._tg_ok(r = 'ok:1', 'T16c đổi tên bàn đang có khách vẫn được (' || r || ')');

  -- ── T17: Quản lý huỷ dòng tiền giờ → không ghi lại, bàn đóng được ───────────────────
  j := public._tg_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P5, S));
  v_id := (j->'data'->>'item_id')::uuid;
  PERFORM public._tg_as('authenticated', B, S);
  r := public._tg_try(format($q$UPDATE public.ban_session_items SET kitchen_status='huy' WHERE id=%L$q$, v_id));
  PERFORM public._tg_ok(r LIKE 'err:42501:VOID_APPROVAL_REQUIRED%', 'T17a phục vụ tự huỷ dòng tiền giờ: cần Quản lý duyệt (' || r || ')');
  PERFORM public._tg_as('authenticated', A, S);
  r := public._tg_try(format($q$UPDATE public.ban_session_items SET kitchen_status='huy' WHERE id=%L$q$, v_id));
  PERFORM public._tg_ok(r = 'ok:1', 'T17b chủ quán huỷ dòng tiền giờ (' || r || ')');
  j := public._tg_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P5, S));
  r := public._tg_try(format('SELECT public._tg_server_close(%L)', P5));
  PERFORM public._tg_as('admin');
  PERFORM public._tg_ok((j->'data'->>'da_huy')::boolean AND r = 'ok:1'
    AND (SELECT count(*) = 1 AND bool_and(kitchen_status = 'huy') FROM public.ban_session_items WHERE session_id = P5)
    AND EXISTS (SELECT 1 FROM public.ban_item_void_server_logs WHERE item_id = v_id),
    'T17c đã huỷ thì chốt không ghi lại, có nhật ký huỷ, bàn đóng được — ' || left(j::text, 100));

  -- ── T18: huỷ bàn tính giờ ───────────────────────────────────────────────────
  PERFORM public._tg_as('authenticated', A, S);
  r := public._tg_try(format($q$INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (%L, %L, %L, 'open')$q$, P6, S, TG1));
  PERFORM public._tg_as('admin');
  UPDATE public.ban_sessions SET gio_bat_dau = clock_timestamp() - interval '10 minutes' WHERE id = P6;
  PERFORM public._tg_as('authenticated', B, S);
  r := public._tg_try(format($q$UPDATE public.ban_sessions SET status='cancelled', closed_at=now() WHERE id=%L$q$, P6));
  PERFORM public._tg_ok(r LIKE 'err:42501:TINH_GIO_HUY_CAN_CHOT%', 'T18a huỷ bàn tính giờ đã chơi 10 phút mà chưa chốt: bị chặn (' || r || ')');
  j := public._tg_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P6, S));
  r := public._tg_try(format($q$UPDATE public.ban_sessions SET status='cancelled', closed_at=now() WHERE id=%L$q$, P6));
  PERFORM public._tg_ok(r LIKE 'err:42501:CANCEL_APPROVAL_REQUIRED%', 'T18b chốt rồi, phục vụ huỷ bàn: cần Quản lý duyệt như huỷ món đã làm (' || r || ')');
  r := public._tg_try(format($q$INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (%L, %L, %L, 'open')$q$, P7, S, TG3));
  r := r || ' / ' || public._tg_try(format($q$UPDATE public.ban_sessions SET status='cancelled', closed_at=now() WHERE id=%L$q$, P7));
  PERFORM public._tg_ok(r = 'ok:1 / ok:1', 'T18c mở nhầm bàn tính giờ, huỷ ngay trong 5 phút: được (' || r || ')');

  -- ── T19: hàm nội bộ không gọi được từ app ───────────────────────────────────────
  r := public._tg_try(format('SELECT public.qn_tinh_gio_ghi_dong_v1(%L, %L)', S, P6));
  PERFORM public._tg_ok(r LIKE 'err:42501:%', 'T19a app không gọi thẳng được hàm ghi dòng tiền giờ (' || r || ')');
  r := public._tg_try(format('SELECT public.qn_tinh_gio_mon_cua_ban_v1(%L, %L)', S, TG1::text));
  PERFORM public._tg_ok(r LIKE 'err:%:TRIGGER_ONLY%', 'T19b hàm phụ chỉ chạy trong trigger (' || r || ')');

  -- ── T20: bàn thường không bị ảnh hưởng ─────────────────────────────────────────
  PERFORM public._tg_as('authenticated', A, S);
  r := public._tg_try(format($q$UPDATE public.ban_dining_tables SET gia_gio_product_id=NULL WHERE id=%L$q$, TG4));   -- bàn trống: gỡ được
  PERFORM public._tg_as('authenticated', B, S);
  r := r || ' / ' || public._tg_try(format($q$INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (%L, %L, %L, 'open')$q$, PN2, S, TG4));
  r := r || ' / ' || public._tg_try(format($q$INSERT INTO public.ban_session_items (store_id, session_id, product_id, product_name, unit_price, price, subtotal, quantity, kitchen_status)
    VALUES (%L, %L, %L, 'Nước suối', 10000, 10000, 10000, 1, 'chua_gui')$q$, S, PN2, PF));
  r := r || ' / ' || public._tg_try(format($q$DELETE FROM public.ban_session_items WHERE session_id=%L$q$, PN2));
  r := r || ' / ' || public._tg_try(format($q$UPDATE public.ban_sessions SET status='closed', closed_at=now() WHERE id=%L$q$, PN2));
  PERFORM public._tg_as('admin');
  PERFORM public._tg_ok(r = 'ok:1 / ok:1 / ok:1 / ok:1 / ok:1'
    AND (SELECT gio_bat_dau IS NULL AND status = 'closed' FROM public.ban_sessions WHERE id = PN2),
    'T20 gỡ giá giờ bàn trống rồi bàn chạy như bàn thường: mở, thêm món, xoá món, đóng bàn trống (' || r || ')');

  RAISE NOTICE '>>> BÀN TÍNH GIỜ v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
