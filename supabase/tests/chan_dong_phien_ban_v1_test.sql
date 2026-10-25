-- ============================================================================
-- TEST: Chặn client tự đóng phiên bàn (20261022_chan_dong_phien_ban_v1.sql)
-- CHỈ CHẠY TRÊN DB STAGING/DISPOSABLE đã áp migration. Một transaction, kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._bt_as(p_role text, p_uid uuid DEFAULT NULL, p_store uuid DEFAULT NULL)
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

CREATE OR REPLACE FUNCTION public._bt_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

-- Chạy một câu lệnh, trả 'ok:<số dòng>' hoặc 'err:<SQLSTATE>'.
CREATE OR REPLACE FUNCTION public._bt_try(p_sql text)
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

-- Mô phỏng một RPC SECURITY DEFINER của máy chủ (như settle_ban_session_v5).
CREATE OR REPLACE FUNCTION public._bt_server_close(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $f$
BEGIN
  UPDATE public.ban_sessions SET status = 'closed', closed_at = now() WHERE id = p_id;
END
$f$;
GRANT EXECUTE ON FUNCTION public._bt_server_close(uuid) TO anon, authenticated;

DO $test$
DECLARE
  A  uuid := gen_random_uuid();
  S  uuid := gen_random_uuid();
  Z  text := gen_random_uuid()::text;
  -- Mỗi bàn chỉ có 1 phiên mở (uq_ban_sessions_one_open_per_table) → mỗi phiên một bàn.
  T1 uuid := gen_random_uuid();
  T2 uuid := gen_random_uuid();
  T3 uuid := gen_random_uuid();
  T4 uuid := gen_random_uuid();
  T5 uuid := gen_random_uuid();
  T6 uuid := gen_random_uuid();
  T7 uuid := gen_random_uuid();
  T8 uuid := gen_random_uuid();   -- bàn trống để thử chuyển bàn
  P1 uuid := gen_random_uuid();   -- còn món  → X cũ phải bị chặn
  P2 uuid := gen_random_uuid();   -- gộp bàn: nguồn
  P3 uuid := gen_random_uuid();   -- gộp bàn: đích
  P4 uuid := gen_random_uuid();   -- huỷ bàn kiểu app cũ
  P5 uuid := gen_random_uuid();   -- máy chủ thanh toán
  P6 uuid := gen_random_uuid();   -- xoá phiên còn món
  P7 uuid := gen_random_uuid();   -- món đã huỷ hết
  T9 uuid := gen_random_uuid();
  P8 uuid := gen_random_uuid();   -- thanh toán thật qua settle_ban_session_v5
  PR uuid := gen_random_uuid();
  v_j jsonb;
  v_r text;
  v_s text;
BEGIN
  RAISE NOTICE '>>> CHẶN ĐÓNG PHIÊN BÀN v1: BẮT ĐẦU <<<';

  PERFORM public._bt_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name)
    VALUES (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A');
  INSERT INTO public.stores (id, store_code, name, owner_user_id)
    VALUES (S, 'T' || substr(S::text, 1, 7), 'Quan test ban', A);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S, 'owner', true);
  INSERT INTO public.ban_zones (id, store_id, name) VALUES (Z, S, 'Khu test');
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name) VALUES
    (T1::text, S, Z, 'Ban 1'), (T2::text, S, Z, 'Ban 2'), (T3::text, S, Z, 'Ban 3'),
    (T4::text, S, Z, 'Ban 4'), (T5::text, S, Z, 'Ban 5'), (T6::text, S, Z, 'Ban 6'),
    (T7::text, S, Z, 'Ban 7'), (T8::text, S, Z, 'Ban 8');
  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES
    (P1, S, T1, 'open'), (P2, S, T2, 'open'), (P3, S, T3, 'open'), (P4, S, T4, 'open'),
    (P5, S, T5, 'open'), (P6, S, T6, 'open'), (P7, S, T7, 'open');
  INSERT INTO public.ban_session_items (store_id, session_id, product_name, unit_price, subtotal, quantity, kitchen_status) VALUES
    (S, P1, 'Tra sua', 30000, 30000, 1, 'da_gui'),
    (S, P1, 'Banh', 20000, 20000, 1, 'chua_gui'),
    (S, P2, 'Ca phe', 25000, 25000, 1, 'da_gui'),
    (S, P4, 'Com', 50000, 50000, 1, 'xong'),
    (S, P5, 'Pho', 60000, 60000, 1, 'xong'),
    (S, P6, 'Bun', 40000, 40000, 1, 'chua_gui'),
    (S, P7, 'Nuoc', 15000, 15000, 1, 'huy');

  -- T0: client thấy được phiên của quán mình (để các ca "được phép" có nghĩa)
  PERFORM public._bt_as('authenticated', A, S);
  PERFORM public._bt_ok((SELECT count(*) FROM public.ban_sessions WHERE id IN (P1,P2,P3,P4,P5,P6,P7)) = 7,
    'T0 authenticated thấy 7 phiên thử');

  -- T1: lỗ hổng cũ — authenticated đặt closed khi bàn còn món → bị chặn
  v_r := public._bt_try(format($q$UPDATE public.ban_sessions SET status='closed', closed_at=now(), total_amount=50000 WHERE id=%L$q$, P1));
  PERFORM public._bt_as('admin');
  SELECT status INTO v_s FROM public.ban_sessions WHERE id = P1;
  PERFORM public._bt_ok(v_r = 'err:42501' AND v_s = 'open', 'T1 authenticated đóng bàn còn món bị chặn (' || v_r || ', status=' || v_s || ')');

  -- T2: như T1 nhưng vai trò anon (app cũ chưa JWT, gửi x-user-id)
  PERFORM public._bt_as('anon', A, S);
  v_r := public._bt_try(format($q$UPDATE public.ban_sessions SET status='closed' WHERE id=%L$q$, P1));
  PERFORM public._bt_as('admin');
  SELECT status INTO v_s FROM public.ban_sessions WHERE id = P1;
  PERFORM public._bt_ok(v_s = 'open' AND v_r IN ('err:42501', 'ok:0'), 'T2 anon đóng bàn còn món không thành (' || v_r || ')');

  -- T3: gộp bàn — chuyển hết món P2 → P3 rồi đóng P2 → được phép
  PERFORM public._bt_as('authenticated', A, S);
  v_r := public._bt_try(format($q$UPDATE public.ban_session_items SET session_id=%L WHERE session_id=%L$q$, P3, P2));
  PERFORM public._bt_ok(v_r = 'ok:1', 'T3a chuyển món sang bàn đích (' || v_r || ')');
  v_r := public._bt_try(format($q$UPDATE public.ban_sessions SET status='closed', closed_at=now(), total_amount=0 WHERE id=%L$q$, P2));
  PERFORM public._bt_ok(v_r = 'ok:1', 'T3b đóng phiên nguồn rỗng sau khi gộp (' || v_r || ')');

  -- T4: huỷ bàn kiểu app cũ (đặt cancelled trước khi huỷ món) → vẫn được phép
  v_r := public._bt_try(format($q$UPDATE public.ban_sessions SET status='cancelled', closed_at=now() WHERE id=%L$q$, P4));
  PERFORM public._bt_ok(v_r = 'ok:1', 'T4 huỷ bàn (cancelled) vẫn chạy cho app cũ (' || v_r || ')');

  -- T5: phiên đã kết thúc không mở lại / đổi trạng thái được
  v_r := public._bt_try(format($q$UPDATE public.ban_sessions SET status='open' WHERE id=%L$q$, P4));
  PERFORM public._bt_ok(v_r = 'err:42501', 'T5a không mở lại phiên đã huỷ (' || v_r || ')');
  v_r := public._bt_try(format($q$UPDATE public.ban_sessions SET status='cancelled' WHERE id=%L$q$, P2));
  PERFORM public._bt_ok(v_r = 'err:42501', 'T5b không đổi phiên đã đóng sang cancelled (' || v_r || ')');

  -- T6: trạng thái lạ từ client bị chặn
  v_r := public._bt_try(format($q$UPDATE public.ban_sessions SET status='paid' WHERE id=%L$q$, P1));
  PERFORM public._bt_ok(v_r = 'err:42501', 'T6 client không đặt status=paid (' || v_r || ')');

  -- T7: RPC máy chủ (SECURITY DEFINER) đóng bàn còn món → KHÔNG bị chặn
  v_r := public._bt_try(format($q$SELECT public._bt_server_close(%L)$q$, P5));
  PERFORM public._bt_as('admin');
  SELECT status INTO v_s FROM public.ban_sessions WHERE id = P5;
  PERFORM public._bt_ok(v_s = 'closed', 'T7 RPC máy chủ vẫn đóng được bàn khi thanh toán (' || v_r || ')');

  -- T8: client xoá phiên còn món → bị chặn
  PERFORM public._bt_as('authenticated', A, S);
  v_r := public._bt_try(format($q$DELETE FROM public.ban_sessions WHERE id=%L$q$, P6));
  PERFORM public._bt_as('admin');
  PERFORM public._bt_ok(EXISTS (SELECT 1 FROM public.ban_sessions WHERE id = P6),
    'T8 client không xoá được phiên còn món (' || v_r || ')');

  -- T9: các cột khác vẫn sửa được (tổng tiền, số khách, chuyển bàn)
  PERFORM public._bt_as('authenticated', A, S);
  v_r := public._bt_try(format($q$UPDATE public.ban_sessions SET total_amount=99000, guest_count=3, table_id=%L WHERE id=%L$q$, T8, P1));
  PERFORM public._bt_ok(v_r = 'ok:1', 'T9 sửa tổng tiền / số khách / chuyển bàn không bị ảnh hưởng (' || v_r || ')');

  -- T10: bàn mà mọi món đã huỷ → đóng được (không còn gì để thu)
  v_r := public._bt_try(format($q$UPDATE public.ban_sessions SET status='closed' WHERE id=%L$q$, P7));
  PERFORM public._bt_ok(v_r = 'ok:1', 'T10 đóng bàn chỉ còn món đã huỷ (' || v_r || ')');

  -- T11: admin/service (không phải client) không bị trigger chặn
  PERFORM public._bt_as('admin');
  v_r := public._bt_try(format($q$UPDATE public.ban_sessions SET status='closed' WHERE id=%L$q$, P6));
  PERFORM public._bt_ok(v_r = 'ok:1', 'T11 vai trò quản trị không bị chặn (' || v_r || ')');

  -- T12: thanh toán bàn THẬT qua settle_ban_session_v5 (gọi bằng vai trò client) vẫn đóng được bàn
  PERFORM public._bt_as('admin');
  INSERT INTO public.products (id, store_id, name, sell_price, cost_price, unit, is_available, is_active)
    VALUES (PR, S, 'Mon test', 45000, 10000, 'phần', true, true);
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name) VALUES (T9::text, S, Z, 'Ban 9');
  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (P8, S, T9, 'open');
  INSERT INTO public.ban_session_items (store_id, session_id, product_id, product_name, unit_price, price, subtotal, quantity, kitchen_status)
    VALUES (S, P8, PR, 'Mon test', 45000, 45000, 45000, 1, 'xong');
  PERFORM public._bt_as('authenticated', A, S);
  v_j := public.settle_ban_session_v5(P8, S, 'cash', 'chan-dong-test-' || P8::text);
  PERFORM public._bt_as('admin');
  SELECT status INTO v_s FROM public.ban_sessions WHERE id = P8;
  PERFORM public._bt_ok((v_j->>'success')::boolean IS TRUE AND v_s = 'closed',
    'T12 settle_ban_session_v5 thật vẫn thu tiền và đóng bàn (status=' || COALESCE(v_s, '?') || ', kq=' || left(v_j::text, 160) || ')');

  RAISE NOTICE '>>> CHẶN ĐÓNG PHIÊN BÀN v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
