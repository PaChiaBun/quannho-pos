-- ============================================================================
-- TEST: 20261124_ban_dat_truoc_v1.sql — đặt trước. Một giao dịch, kết thúc ROLLBACK.
-- Chạy trên DB đã áp 20261123_ban_tinh_gio_v1.sql và 20261124_ban_dat_truoc_v1.sql.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._dt_as(p_role text, p_uid uuid DEFAULT NULL, p_store uuid DEFAULT NULL)
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

CREATE OR REPLACE FUNCTION public._dt_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._dt_try(p_sql text)
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

CREATE OR REPLACE FUNCTION public._dt_rpc(p_sql text)
RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE j jsonb;
BEGIN
  EXECUTE p_sql INTO j;
  RETURN j;
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('raised', SQLSTATE, 'msg', SQLERRM);
END
$f$;

DO $test$
DECLARE
  A uuid := gen_random_uuid(); B uuid := gen_random_uuid(); C uuid := gen_random_uuid();
  S uuid := gen_random_uuid(); S2 uuid := gen_random_uuid();
  Z text := gen_random_uuid()::text; Z2 text := gen_random_uuid()::text;
  T1 uuid := gen_random_uuid(); T2 uuid := gen_random_uuid(); T3 uuid := gen_random_uuid();
  T4 uuid := gen_random_uuid(); TX uuid := gen_random_uuid();
  PG uuid := gen_random_uuid();
  P1 uuid := gen_random_uuid(); P2 uuid := gen_random_uuid(); P4 uuid := gen_random_uuid();
  MAI timestamptz := date_trunc('day', now()) + interval '1 day 11 hours';   -- 18:00 giờ Việt Nam ngày mai
  j jsonb; r text; d1 uuid; d2 uuid; d3 uuid; dx uuid; d9 uuid; d10 uuid; d13 uuid;
  v_tu timestamptz; v_den timestamptz; v_ten text;
  luu constant text := 'SELECT public.ban_dat_truoc_luu_v1(%L, %L, %L, %L, %L, %L, %L, %L, %L)';
BEGIN
  RAISE NOTICE '>>> ĐẶT TRƯỚC v1: BẮT ĐẦU <<<';
  PERFORM public._dt_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*33000000)::int), 'x', 'Chu A'),
    (B, '+84' || (933000001 + (random()*33000000)::int), 'x', 'Phuc vu B'),
    (C, '+84' || (966000002 + (random()*33000000)::int), 'x', 'Chu C');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, created_at) VALUES
    (S,  'T' || substr(S::text, 1, 7),  'Quan test dat truoc', A, now() - interval '1 day'),
    (S2, 'T' || substr(S2::text, 1, 7), 'Quan khac',           C, now() - interval '1 day');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S, 'owner', true), (B, S, 'waiter', false), (C, S2, 'owner', true);
  INSERT INTO public.ban_zones (id, store_id, name) VALUES (Z, S, 'Khu san'), (Z2, S2, 'Khu khac');
  INSERT INTO public.products (id, store_id, name, sell_price, cost_price, unit, is_available, is_active)
    VALUES (PG, S, 'Giờ sân', 60000, 0, 'giờ', true, true);
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name, gia_gio_product_id) VALUES
    (T1::text, S, Z, 'San 1', PG), (T2::text, S, Z, 'San 2', PG), (T4::text, S, Z, 'San 4', PG);
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name) VALUES
    (T3::text, S, Z, 'Ban thuong'), (TX::text, S2, Z2, 'San quan khac');

  -- ── D1: phục vụ đặt được; số điện thoại được dọn; ghi tên người đặt ────────────────────────────
  PERFORM public._dt_as('authenticated', B, S);
  j := public._dt_rpc(format(luu, S, NULL, T1::text, '  Anh Nam ', '0901 234-567', MAI, MAI + interval '1 hour', 'đặt qua điện thoại', 50000));
  d1 := (j->'data'->>'id')::uuid;
  PERFORM public._dt_ok((j->>'success')::boolean AND j->'data'->>'ten_khach' = 'Anh Nam'
    AND j->'data'->>'sdt' = '0901234567' AND j->'data'->>'nguoi_tao_ten' = 'Phuc vu B'
    AND j->'data'->>'trang_thai' = 'da_dat' AND (j->'data'->>'tien_coc')::numeric = 50000,
    'D1 phục vụ đặt Sân 1 mai 18:00–19:00 — ' || left(j::text, 200));

  -- ── D2–D3: trùng giờ bị chặn, sát giờ và bàn khác thì được ───────────────────────────────────
  j := public._dt_rpc(format(luu, S, NULL, T1::text, 'Chị Lan', '', MAI + interval '30 minutes', MAI + interval '90 minutes', NULL, 0));
  PERFORM public._dt_ok(j->>'error_code' = 'TRUNG_GIO' AND j->>'message' LIKE '%Anh Nam%',
    'D2 đặt chồng 18:30–19:30 bị chặn, báo trùng với ai — ' || left(j::text, 160));
  j := public._dt_rpc(format(luu, S, NULL, T1::text, 'Chị Lan', '', MAI + interval '1 hour', MAI + interval '2 hours', NULL, 0));
  d2 := (j->'data'->>'id')::uuid;
  PERFORM public._dt_ok((j->>'success')::boolean, 'D3a đặt sát giờ 19:00–20:00 cùng sân: được');
  j := public._dt_rpc(format(luu, S, NULL, T2::text, 'Anh Tú', '', MAI, MAI + interval '1 hour', NULL, 0));
  d3 := (j->'data'->>'id')::uuid;
  PERFORM public._dt_ok((j->>'success')::boolean, 'D3b cùng giờ nhưng sân khác: được');

  -- ── D4: dữ liệu sai ─────────────────────────────────────────────────────────────────────
  j := public._dt_rpc(format(luu, S, NULL, T2::text, 'X', '', MAI + interval '5 hours', MAI + interval '4 hours', NULL, 0));
  PERFORM public._dt_ok(j->>'error_code' = 'INVALID_TIME', 'D4a giờ kết thúc trước giờ bắt đầu: từ chối');
  j := public._dt_rpc(format(luu, S, NULL, T2::text, 'X', '', now() - interval '3 hours', now() - interval '2 hours', NULL, 0));
  PERFORM public._dt_ok(j->>'error_code' = 'INVALID_TIME', 'D4b khung giờ đã qua: từ chối');
  j := public._dt_rpc(format(luu, S, NULL, T2::text, '   ', '', MAI + interval '5 hours', MAI + interval '6 hours', NULL, 0));
  PERFORM public._dt_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'D4c thiếu tên khách: từ chối');
  j := public._dt_rpc(format(luu, S, NULL, TX::text, 'X', '', MAI + interval '5 hours', MAI + interval '6 hours', NULL, 0));
  PERFORM public._dt_ok(j->>'error_code' = 'INVALID_STATE', 'D4d bàn của quán khác: từ chối');

  -- ── D5: người ngoài quán ──────────────────────────────────────────────────────────────────
  PERFORM public._dt_as('authenticated', C, S2);
  j := public._dt_rpc(format(luu, S, NULL, T2::text, 'Ke la', '', MAI + interval '5 hours', MAI + interval '6 hours', NULL, 0));
  PERFORM public._dt_ok(j->>'raised' = '42501', 'D5a chủ quán khác đặt vào quán này: bị từ chối');
  PERFORM public._dt_ok((SELECT count(*) FROM public.ban_dat_truoc WHERE store_id = S) = 0,
    'D5b chủ quán khác không đọc được lượt đặt (tên, số điện thoại) của quán này');
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_doi_trang_thai_v1(%L, %L, %L)', S, d1, 'huy'));
  PERFORM public._dt_ok(j->>'raised' = '42501', 'D5c chủ quán khác huỷ lượt đặt quán này: bị từ chối');
  PERFORM public._dt_as('anon', A, S);
  r := public._dt_try('SELECT count(*) FROM public.ban_dat_truoc');
  PERFORM public._dt_ok(r LIKE 'err:42501:%', 'D5d vai anon không đọc được bảng lượt đặt (' || r || ')');

  -- ── D6: app không ghi thẳng vào bảng ──────────────────────────────────────────────────────────
  PERFORM public._dt_as('authenticated', A, S);
  PERFORM public._dt_ok((SELECT count(*) FROM public.ban_dat_truoc WHERE store_id = S) = 3, 'D6a chủ quán đọc được 3 lượt đặt của quán mình');
  r := public._dt_try(format($q$INSERT INTO public.ban_dat_truoc (store_id, table_id, ten_khach, gio_tu, gio_den) VALUES (%L, %L, 'chen thang', now(), now() + interval '1 hour')$q$, S, T2::text));
  PERFORM public._dt_ok(r LIKE 'err:42501:%', 'D6b app chèn thẳng bị chặn (' || r || ')');
  r := public._dt_try(format($q$UPDATE public.ban_dat_truoc SET gio_den = gio_den + interval '5 hours' WHERE id = %L$q$, d1));
  PERFORM public._dt_ok(r LIKE 'err:42501:%', 'D6c app sửa thẳng bị chặn (' || r || ')');
  r := public._dt_try(format($q$DELETE FROM public.ban_dat_truoc WHERE id = %L$q$, d1));
  PERFORM public._dt_ok(r LIKE 'err:42501:%', 'D6d app xoá thẳng bị chặn (' || r || ')');

  -- ── D7: đã nhắc; sửa lượt đặt ───────────────────────────────────────────────────────────────
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_da_nhac_v1(%L, %L)', S, d1));
  PERFORM public._dt_ok((j->>'success')::boolean AND j->'data'->>'nhac_boi' = 'Chu A', 'D7a đánh dấu đã nhắc, ghi tên người nhắc');
  PERFORM public._dt_as('authenticated', B, S);
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_da_nhac_v1(%L, %L)', S, d1));
  PERFORM public._dt_ok(j->'data'->>'nhac_boi' = 'Chu A', 'D7b người bấm sau không ghi đè người nhắc đầu tiên');
  j := public._dt_rpc(format(luu, S, d1, T1::text, 'Anh Nam', '0901234567', MAI + interval '30 minutes', MAI + interval '90 minutes', NULL, 0));
  PERFORM public._dt_ok(j->>'error_code' = 'TRUNG_GIO', 'D7c sửa giờ đè lên lượt 19:00–20:00: bị chặn');
  j := public._dt_rpc(format(luu, S, d1, T1::text, 'Anh Nam (đổi tên)', '0901234567', MAI, MAI + interval '1 hour', 'ghi chú mới', 0));
  PERFORM public._dt_ok((j->>'success')::boolean AND j->'data'->>'ten_khach' = 'Anh Nam (đổi tên)'
    AND j->'data'->>'nhac_boi' = 'Chu A', 'D7d sửa tên, giữ giờ: vẫn giữ dấu đã nhắc');
  j := public._dt_rpc(format(luu, S, d1, T1::text, 'Anh Nam', '0901234567', MAI - interval '2 hours', MAI - interval '1 hour', NULL, 0));
  PERFORM public._dt_ok((j->>'success')::boolean AND j->'data'->>'nhac_luc' IS NULL, 'D7e đổi giờ đặt: xoá dấu đã nhắc để nhắc lại');

  -- ── D8: huỷ / không đến thì trả khung giờ ───────────────────────────────────────────────────
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_doi_trang_thai_v1(%L, %L, %L)', S, d2, 'huy'));
  PERFORM public._dt_ok((j->>'success')::boolean, 'D8a huỷ lượt 19:00–20:00');
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_doi_trang_thai_v1(%L, %L, %L)', S, d2, 'huy'));
  PERFORM public._dt_ok((j->>'success')::boolean, 'D8b bấm huỷ lần nữa: không lỗi');
  j := public._dt_rpc(format(luu, S, NULL, T1::text, 'Khách mới', '', MAI + interval '1 hour', MAI + interval '2 hours', NULL, 0));
  PERFORM public._dt_ok((j->>'success')::boolean, 'D8c khung giờ vừa huỷ đặt lại được');
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_doi_trang_thai_v1(%L, %L, %L)', S, d3, 'khong_den'));
  PERFORM public._dt_ok((j->>'success')::boolean, 'D8d đánh dấu khách không đến');
  j := public._dt_rpc(format(luu, S, d3, T2::text, 'Anh Tú', '', MAI, MAI + interval '1 hour', NULL, 0));
  PERFORM public._dt_ok(j->>'error_code' = 'INVALID_STATE', 'D8e lượt đã "không đến" không sửa được nữa');
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_doi_trang_thai_v1(%L, %L, %L)', S, d1, 'xoa'));
  PERFORM public._dt_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'D8f trạng thái lạ bị từ chối');

  -- ── D9: khách đến TRỄ 20 phút, khung 60 phút → tính đủ 60 phút = 60.000 ─────────────────────────
  v_tu := clock_timestamp() - interval '20 minutes';
  j := public._dt_rpc(format(luu, S, NULL, T1::text, 'Khách trễ', '0912', v_tu, v_tu + interval '60 minutes', NULL, 0));
  d9 := (j->'data'->>'id')::uuid;
  PERFORM public._dt_ok((j->>'success')::boolean, 'D9a đặt khung đang diễn ra (bắt đầu 20 phút trước) được — ' || left(j::text, 90));
  PERFORM public._dt_as('admin');
  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (P1, S, T1, 'open');
  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (P2, S, T2, 'open');
  PERFORM public._dt_as('authenticated', B, S);
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_nhan_v1(%L, %L, %L)', S, d9, P2));
  PERFORM public._dt_ok(j->>'error_code' = 'INVALID_STATE', 'D9b nhận vào phiên của sân khác: bị từ chối');
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_nhan_v1(%L, %L, %L)', S, d9, P1));
  PERFORM public._dt_as('admin');
  PERFORM public._dt_ok((j->>'success')::boolean
    AND (SELECT gio_bat_dau = v_tu FROM public.ban_sessions WHERE id = P1)
    AND (SELECT trang_thai = 'da_nhan' AND session_id = P1 FROM public.ban_dat_truoc WHERE id = d9),
    'D9c nhận sân: lượt đặt gắn phiên, mốc giờ lùi về giờ đặt');
  PERFORM public._dt_as('authenticated', B, S);
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_nhan_v1(%L, %L, %L)', S, d9, P1));
  PERFORM public._dt_ok((j->'data'->>'lap_lai')::boolean, 'D9d bấm nhận lần nữa: không làm gì thêm');
  j := public._dt_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P1, S));
  v_ten := j->'data'->>'ten';
  PERFORM public._dt_ok((j->'data'->>'so_phut')::int = 60 AND (j->'data'->>'thanh_tien')::numeric = 60000
    AND (j->'data'->>'theo_khung_dat')::boolean,
    'D9e chốt lúc khách mới chơi 0 phút: vẫn tính đủ khung 60 phút = 60.000 — ' || left(j::text, 150));
  PERFORM public._dt_ok(v_ten LIKE '% (1g00)'
    AND v_ten LIKE '%' || to_char(v_tu AT TIME ZONE 'Asia/Ho_Chi_Minh', 'HH24:MI') || '–'
        || to_char((v_tu + interval '60 minutes') AT TIME ZONE 'Asia/Ho_Chi_Minh', 'HH24:MI') || ' (1g00)',
    'D9f tên dòng: giờ ra = giờ vào + số phút tính tiền — ' || v_ten);
  j := public._dt_rpc(format(luu, S, d9, T1::text, 'Sua sau khi nhan', '', v_tu, v_tu + interval '60 minutes', NULL, 0));
  PERFORM public._dt_ok(j->>'error_code' = 'INVALID_STATE', 'D9g lượt đã nhận không sửa được');
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_doi_trang_thai_v1(%L, %L, %L)', S, d9, 'huy'));
  PERFORM public._dt_ok(j->>'error_code' = 'INVALID_STATE', 'D9h lượt đã nhận không huỷ được');

  -- ── D10: chơi LỐ: khung đã hết 30 phút trước → tính tới lúc chốt (90 phút = 90.000) ───────────────
  j := public._dt_rpc(format(luu, S, NULL, T2::text, 'Khách lố', '', clock_timestamp() - interval '10 minutes', clock_timestamp() + interval '50 minutes', NULL, 0));
  d10 := (j->'data'->>'id')::uuid;
  PERFORM public._dt_as('admin');
  v_tu := clock_timestamp() - interval '89 minutes 30 seconds';
  UPDATE public.ban_dat_truoc SET gio_tu = v_tu, gio_den = v_tu + interval '60 minutes' WHERE id = d10;
  PERFORM public._dt_as('authenticated', A, S);
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_nhan_v1(%L, %L, %L)', S, d10, P2));
  j := public._dt_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P2, S));
  PERFORM public._dt_ok((j->'data'->>'so_phut')::int = 90 AND (j->'data'->>'thanh_tien')::numeric = 90000
    AND (j->'data'->>'theo_khung_dat')::boolean IS FALSE,
    'D10a chơi lố 30 phút: tính theo giờ thực 90 phút = 90.000 — ' || left(j::text, 150));
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_nhan_v1(%L, %L, %L)', S, d1, P2));
  PERFORM public._dt_ok((j->>'success')::boolean IS FALSE, 'D10b một phiên không nhận hai lượt đặt — ' || left(j::text, 110));

  -- ── D12: chuyển bàn giữa khung đặt → đoạn bàn cũ chỉ tính tới lúc chuyển ──────────────────────────
  j := public._dt_rpc(format('SELECT public.ban_chuyen_ban_tinh_gio_v1(%L, %L, %L)', P1, S, T3::text));
  PERFORM public._dt_as('admin');
  PERFORM public._dt_ok((j->>'success')::boolean AND (j->'data'->'chot'->>'so_phut')::int IN (20, 21)
    AND (j->'data'->'chot'->>'theo_khung_dat')::boolean IS FALSE
    AND (SELECT count(*) = 1 AND bool_and(subtotal IN (20000, 21000)) FROM public.ban_session_items WHERE session_id = P1 AND gio_tu IS NOT NULL),
    'D12 chuyển sang bàn thường: dòng tiền giờ ghi lại theo 20 phút đã chơi, không kéo tới hết khung — ' || left(j->'data'->'chot'->>'ten', 60));

  -- ── D13: khách đến SỚM 30 phút → tính từ lúc đến tới hết khung (90 phút) ─────────────────────────
  PERFORM public._dt_as('authenticated', B, S);
  v_tu := clock_timestamp() + interval '30 minutes';
  j := public._dt_rpc(format(luu, S, NULL, T4::text, 'Khách sớm', '', v_tu, v_tu + interval '60 minutes', NULL, 0));
  d13 := (j->'data'->>'id')::uuid;
  PERFORM public._dt_as('admin');
  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (P4, S, T4, 'open');
  PERFORM public._dt_as('authenticated', B, S);
  j := public._dt_rpc(format('SELECT public.ban_dat_truoc_nhan_v1(%L, %L, %L)', S, d13, P4));
  j := public._dt_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P4, S));
  PERFORM public._dt_as('admin');
  PERFORM public._dt_ok((j->'data'->>'so_phut')::int IN (90, 91) AND (j->'data'->>'theo_khung_dat')::boolean
    AND (SELECT gio_bat_dau > clock_timestamp() - interval '1 minute' FROM public.ban_sessions WHERE id = P4),
    'D13 đến sớm: mốc giữ lúc đến, tính tới hết khung (90 phút) — ' || left(j::text, 150));

  -- ── D14: bàn tính giờ không có lượt đặt vẫn tính theo giờ thực ──────────────────────────────────
  UPDATE public.ban_dat_truoc SET trang_thai = 'huy' WHERE id = d13;
  UPDATE public.ban_sessions SET gio_bat_dau = clock_timestamp() - interval '29 minutes 30 seconds' WHERE id = P4;
  PERFORM public._dt_as('authenticated', B, S);
  j := public._dt_rpc(format('SELECT public.ban_chot_gio_v1(%L, %L)', P4, S));
  PERFORM public._dt_ok((j->'data'->>'so_phut')::int = 30 AND (j->'data'->>'thanh_tien')::numeric = 30000
    AND (j->'data'->>'theo_khung_dat')::boolean IS FALSE,
    'D14 không còn lượt đặt hiệu lực: tính theo giờ thực 30 phút = 30.000');

  RAISE NOTICE '>>> ĐẶT TRƯỚC v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
