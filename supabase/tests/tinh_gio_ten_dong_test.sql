-- ============================================================================
-- TEST: 20261127_tinh_gio_ten_dong.sql — tên dòng tiền giờ. Một giao dịch, kết thúc ROLLBACK.
-- Gọi thẳng qn_tinh_gio_ghi_dong_v1 (vai admin) với nhiều độ dài và đơn giá, xem tên ghép ra.
-- ============================================================================
BEGIN;

DO $test$
DECLARE
  A uuid := gen_random_uuid(); S uuid := gen_random_uuid(); Z text := gen_random_uuid()::text;
  T1 uuid := gen_random_uuid(); T2 uuid := gen_random_uuid();
  PG uuid := gen_random_uuid(); PV uuid := gen_random_uuid();
  P1 uuid := gen_random_uuid(); P2 uuid := gen_random_uuid();
  TZ constant text := 'Asia/Ho_Chi_Minh';
  j jsonb; v_moc timestamptz; v_ten text;

BEGIN
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*33000000)::int), 'x', 'Chu A');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, created_at) VALUES
    (S, 'T' || substr(S::text, 1, 7), 'Quan test ten dong', A, now() - interval '1 day');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S, 'owner', true);
  INSERT INTO public.ban_zones (id, store_id, name) VALUES (Z, S, 'Khu bi da');
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name, label) VALUES
    (T1::text, S, Z, 'Bi da 1', 'A 1'), (T2::text, S, Z, 'Bi da 2', NULL);
  INSERT INTO public.products (id, store_id, name, sell_price, cost_price, unit, is_available, is_active, category) VALUES
    (PG, S, 'Tiền giờ 60.000 đ', 60000,   0, 'giờ', true, true, 'Tiền giờ'),
    (PV, S, 'Giờ chơi VIP',      1250000, 0, 'giờ', true, true, 'Tiền giờ');
  UPDATE public.ban_dining_tables SET gia_gio_product_id = PG WHERE id = T1::text;
  UPDATE public.ban_dining_tables SET gia_gio_product_id = PV WHERE id = T2::text;
  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (P1, S, T1, 'open'), (P2, S, T2, 'open');

  -- N1: 90 phút, nhãn bàn "A 1": không còn tên món "Tiền giờ 60.000 đ" ở đầu
  v_moc := clock_timestamp() - interval '89 minutes 30 seconds';
  UPDATE public.ban_sessions SET gio_bat_dau = v_moc WHERE id = P1;
  j := public.qn_tinh_gio_ghi_dong_v1(S, P1);
  v_ten := j->>'ten';
  IF v_ten NOT LIKE 'Giờ chơi · A 1 · % – % · 1 giờ 30 phút × 60.000 đ/giờ' OR (j->>'thanh_tien')::numeric <> 90000 THEN
    RAISE EXCEPTION '❌ FAIL N1: %', j;
  END IF;
  IF (v_moc AT TIME ZONE TZ)::date = ((v_moc + interval '90 minutes') AT TIME ZONE TZ)::date
     AND v_ten <> 'Giờ chơi · A 1 · ' || to_char(v_moc AT TIME ZONE TZ, 'HH24:MI') || ' – '
                  || to_char((v_moc + interval '90 minutes') AT TIME ZONE TZ, 'HH24:MI')
                  || ' · 1 giờ 30 phút × 60.000 đ/giờ' THEN
    RAISE EXCEPTION '❌ FAIL N1b: %', v_ten;
  END IF;
  IF (SELECT product_name FROM public.ban_session_items WHERE id = (j->>'item_id')::uuid) <> v_ten THEN
    RAISE EXCEPTION '❌ FAIL N1c dòng trong bàn khác tên trả về';
  END IF;
  RAISE NOTICE '✅ PASS N1 90 phút: %', v_ten;

  -- N2: chốt lại (dòng cũ được ghi đè tên mới, vẫn một dòng), 45 phút
  v_moc := clock_timestamp() - interval '44 minutes 10 seconds';
  UPDATE public.ban_sessions SET gio_bat_dau = v_moc WHERE id = P1;
  j := public.qn_tinh_gio_ghi_dong_v1(S, P1);
  IF j->>'ten' NOT LIKE 'Giờ chơi · A 1 · % · 45 phút × 60.000 đ/giờ' OR (j->>'thanh_tien')::numeric <> 45000 THEN
    RAISE EXCEPTION '❌ FAIL N2: %', j;
  END IF;
  RAISE NOTICE '✅ PASS N2 45 phút: %', j->>'ten';

  -- N3: tròn 2 giờ, bàn không có nhãn dùng tên bàn, đơn giá hàng triệu có dấu chấm
  v_moc := clock_timestamp() - interval '119 minutes 30 seconds';
  UPDATE public.ban_sessions SET gio_bat_dau = v_moc WHERE id = P2;
  j := public.qn_tinh_gio_ghi_dong_v1(S, P2);
  IF j->>'ten' NOT LIKE 'Giờ chơi · Bi da 2 · % · 2 giờ × 1.250.000 đ/giờ' OR (j->>'thanh_tien')::numeric <> 2500000 THEN
    RAISE EXCEPTION '❌ FAIL N3: %', j;
  END IF;
  RAISE NOTICE '✅ PASS N3 2 giờ, 1.250.000: %', j->>'ten';

  -- N4: chạy qua ngày (24 giờ 22 phút) thì ghi kèm ngày ở cả giờ vào và giờ ra
  v_moc := clock_timestamp() - interval '24 hours 21 minutes 30 seconds';
  UPDATE public.ban_sessions SET gio_bat_dau = v_moc WHERE id = P1;
  j := public.qn_tinh_gio_ghi_dong_v1(S, P1);
  v_ten := j->>'ten';
  IF v_ten <> 'Giờ chơi · A 1 · ' || to_char(v_moc AT TIME ZONE TZ, 'DD/MM HH24:MI') || ' – '
              || to_char((v_moc + interval '1462 minutes') AT TIME ZONE TZ, 'DD/MM HH24:MI')
              || ' · 24 giờ 22 phút × 60.000 đ/giờ'
     OR (j->>'thanh_tien')::numeric <> 1462000 THEN
    RAISE EXCEPTION '❌ FAIL N4: %', j;
  END IF;
  RAISE NOTICE '✅ PASS N4 qua ngày: %', v_ten;

  -- N5: quyền giữ nguyên (app không gọi thẳng được)
  IF has_function_privilege('authenticated', 'public.qn_tinh_gio_ghi_dong_v1(uuid, uuid, boolean)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.qn_tinh_gio_ghi_dong_v1(uuid, uuid, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION '❌ FAIL N5 app gọi thẳng được hàm ghi dòng';
  END IF;
  RAISE NOTICE '✅ PASS N5 quyền: chỉ máy chủ gọi';
  RAISE NOTICE '>>> TÊN DÒNG TIỀN GIỜ: 5/5 PASS <<<';
END
$test$;

ROLLBACK;
