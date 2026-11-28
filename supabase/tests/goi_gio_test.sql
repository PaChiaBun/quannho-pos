-- ============================================================================
-- TEST: 20261128_goi_gio.sql — gói giờ. Một giao dịch, kết thúc ROLLBACK.
-- Bộ ca (.docs/ke-hoach-goi-gio.md) dùng chung với test Dart test/modules/tinh_gio/goi_gio_test.dart.
-- 30/11/2026 là Thứ Hai. Giá gốc 60.000; gói 120 phút = 100.000.
-- ============================================================================
BEGIN;
-- Như PostgREST trên máy chủ thật: UPDATE / DELETE không có WHERE bị chặn (bài học 28/11, lịch cố định).
LOAD 'safeupdate';

CREATE OR REPLACE FUNCTION public._gg_as(p_role text, p_uid uuid DEFAULT NULL, p_store uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  IF p_role IN ('anon', 'authenticated') THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_uid IS NULL THEN '{}'
         ELSE json_build_object('sub', p_uid::text, 'role', p_role, 'store_id', p_store::text)::text END, true);
  PERFORM set_config('request.headers',
    json_build_object('x-store-id', COALESCE(p_store::text, ''), 'x-user-id', COALESCE(p_uid::text, ''))::text, true);
END
$f$;

CREATE OR REPLACE FUNCTION public._gg_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._gg_rpc(p_sql text)
RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE j jsonb;
BEGIN
  EXECUTE p_sql INTO j;
  RETURN j;
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('raised', SQLSTATE, 'msg', SQLERRM);
END
$f$;
GRANT EXECUTE ON FUNCTION public._gg_rpc(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public._gg_tien(p_ban text, p_vao timestamptz, p_phut int, p_goi int, p_goi_gia numeric)
RETURNS jsonb LANGUAGE sql AS $f$ SELECT public.qn_tinh_gio_tinh_tien_v3(p_ban, 60000, p_vao, p_phut, p_goi, p_goi_gia) $f$;

DO $test$
DECLARE
  A uuid := gen_random_uuid(); B uuid := gen_random_uuid(); S uuid := gen_random_uuid();
  Z text := gen_random_uuid()::text;
  T0 text := gen_random_uuid()::text; T1 text := gen_random_uuid()::text; T2 text := gen_random_uuid()::text;
  T3 text := gen_random_uuid()::text; T4 text := gen_random_uuid()::text;
  PG uuid := gen_random_uuid(); P1 uuid := gen_random_uuid(); P2 uuid := gen_random_uuid();
  G120 uuid; G180 uuid;
  j jsonb; v_ten text; i int; v_phut int; v_vao timestamptz; v_sai int := 0; v_dong record;
BEGIN
  RAISE NOTICE '>>> GÓI GIỜ: BẮT ĐẦU <<<';
  PERFORM public._gg_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*33000000)::int), 'x', 'Chu A'),
    (B, '+84' || (933000001 + (random()*33000000)::int), 'x', 'Phuc vu B');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, created_at) VALUES
    (S, 'T' || substr(S::text, 1, 7), 'Quan test goi gio', A, now() - interval '1 day');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S, 'owner', true), (B, S, 'waiter', false);
  INSERT INTO public.ban_zones (id, store_id, name) VALUES (Z, S, 'Khu karaoke');
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name) VALUES
    (T0, S, Z, 'P0'), (T1, S, Z, 'P1'), (T2, S, Z, 'P2'), (T3, S, Z, 'P3'), (T4, S, Z, 'P4');
  INSERT INTO public.products (id, store_id, name, sell_price, cost_price, unit, is_available, is_active, category) VALUES
    (PG, S, 'Giờ hát 60.000 đ/giờ', 60000, 0, 'giờ', true, true, 'Tiền giờ');
  UPDATE public.ban_dining_tables SET gia_gio_product_id = PG WHERE id IN (T0, T1, T2, T3, T4);

  -- ── Phép tính ──────────────────────────────────────────────────────────────────────────────
  j := public._gg_tien(T0, '2026-11-30 14:00+07', 90, 120, 100000);
  PERFORM public._gg_ok((j->>'thanh_tien')::numeric = 100000 AND (j->>'so_phut_tinh')::int = 120
    AND jsonb_array_length(j->'doan') = 0, 'G1 về sớm 90 phút: đủ gói 100.000, tính 120 phút — ' || j::text);
  PERFORM public._gg_ok((public._gg_tien(T0, '2026-11-30 14:00+07', 120, 120, 100000)->>'thanh_tien')::numeric = 100000, 'G2 đúng 120 phút: 100.000');
  j := public._gg_tien(T0, '2026-11-30 14:00+07', 137, 120, 100000);
  PERFORM public._gg_ok((j->>'thanh_tien')::numeric = 117000 AND (j->'doan'->0->>'phut')::int = 17
    AND (j->'doan'->0->>'tu')::timestamptz = '2026-11-30 16:00+07', 'G3 lố 17 phút: 100.000 + 17.000 — ' || j::text);

  INSERT INTO public.ban_gia_gio_cau_hinh (table_id, store_id, block_phut, an_han_phut) VALUES (T1, S, 30, 0);
  PERFORM public._gg_ok((public._gg_tien(T1, '2026-11-30 14:00+07', 137, 120, 100000)->>'thanh_tien')::numeric = 130000,
    'G4 gói + block 30: lố 17 phút tính 30 = 130.000');
  UPDATE public.ban_gia_gio_cau_hinh SET an_han_phut = 5 WHERE table_id = T1;
  PERFORM public._gg_ok((public._gg_tien(T1, '2026-11-30 14:00+07', 123, 120, 100000)->>'thanh_tien')::numeric = 100000,
    'G5 gói + block 30 ân hạn 5: lố 3 phút không tính');

  INSERT INTO public.ban_gia_gio_khung (store_id, table_id, thu, tu, den, gia, thu_tu) VALUES
    (S, T2, '{1,2,3,4,5,6,7}', '17:00', '23:00', 80000, 0);
  PERFORM public._gg_ok((public._gg_tien(T2, '2026-11-30 16:00+07', 150, 120, 100000)->>'thanh_tien')::numeric = 140000,
    'G6 gói + khung 17–23 giá 80.000: lố 30 phút trong khung = 140.000');

  PERFORM public._gg_ok((public._gg_tien(T0, '2026-11-30 14:00+07', 30, 50, 0)->>'thanh_tien')::numeric = 0,
    'G7 phần gói còn 50 phút giá 0, chơi 30 phút: 0 đ');
  PERFORM public._gg_ok((public._gg_tien(T0, '2026-11-30 14:00+07', 70, 50, 0)->>'thanh_tien')::numeric = 20000,
    'G8 phần gói còn 50 phút, chơi 70 phút: lố 20 phút = 20.000');

  INSERT INTO public.ban_gia_gio_cau_hinh (table_id, store_id, toi_thieu_phut) VALUES (T3, S, 180);
  PERFORM public._gg_ok((public._gg_tien(T3, '2026-11-30 14:00+07', 90, 120, 100000)->>'thanh_tien')::numeric = 160000,
    'G9 gói 120 + tối thiểu 180: 100.000 + 60 phút = 160.000');
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'qn_tinh_gio_tinh_tien_v3' AND prosrc LIKE '%thay cho "chơi tối%') THEN
    PERFORM public._gg_ok((public._gg_tien(T3, '2026-11-30 14:00+07', 30, 50, 0)->>'thanh_tien')::numeric = 0
      AND (public._gg_tien(T3, '2026-11-30 14:00+07', 70, 50, 0)->>'thanh_tien')::numeric = 20000,
      'G9b phần gói còn lại (giá 0) thay tối thiểu 180: chơi 30 phút 0 đ, chơi 70 phút lố 20 = 20.000');
  END IF;

  FOR i IN 1 .. 2000 LOOP
    v_phut := 1 + floor(random() * 3000)::int;
    v_vao := '2026-11-01 00:00+07'::timestamptz + make_interval(secs => floor(random() * 86400 * 60));
    IF public._gg_tien(T2, v_vao, v_phut, NULL, NULL) - 'goi_phut' - 'goi_gia'
       <> public.qn_tinh_gio_tinh_tien_v2(T2, 60000, v_vao, v_phut) - 'goi_phut' - 'goi_gia'
       OR (public.qn_tinh_gio_tinh_tien_v2(T0, 60000, v_vao, v_phut)->>'thanh_tien')::numeric
          <> ceil(v_phut * 60000 / 60.0 / 1000.0) * 1000 THEN
      v_sai := v_sai + 1;
    END IF;
  END LOOP;
  PERFORM public._gg_ok(v_sai = 0, 'G10 HỒI QUY 2.000 lượt: không gói = v2, bàn không cài = công thức cũ (sai ' || v_sai || ')');

  -- ── Lưu gói ────────────────────────────────────────────────────────────────────────────────
  PERFORM public._gg_as('authenticated', B, S);
  j := public._gg_rpc(format($q$SELECT public.ban_goi_gio_luu_v1(%L, ARRAY[%L], '[{"so_phut":120,"gia":100000}]'::jsonb)$q$, S, T4));
  PERFORM public._gg_ok(j->>'raised' = '42501', 'G14 phục vụ không lưu được gói — ' || j::text);
  PERFORM public._gg_as('authenticated', A, S);
  j := public._gg_rpc(format($q$SELECT public.ban_goi_gio_luu_v1(%L, ARRAY[%L], '[{"so_phut":60,"gia":1},{"so_phut":90,"gia":1},{"so_phut":120,"gia":1},{"so_phut":150,"gia":1},{"so_phut":180,"gia":1},{"so_phut":240,"gia":1},{"so_phut":300,"gia":1}]'::jsonb)$q$, S, T4));
  PERFORM public._gg_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'G14b 7 gói bị từ chối');
  j := public._gg_rpc(format($q$SELECT public.ban_goi_gio_luu_v1(%L, ARRAY[%L], '[{"so_phut":120,"gia":1},{"so_phut":120,"gia":2}]'::jsonb)$q$, S, T4));
  PERFORM public._gg_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'G14c hai gói trùng số giờ bị từ chối');
  j := public._gg_rpc(format($q$SELECT public.ban_goi_gio_luu_v1(%L, ARRAY[%L], '[{"so_phut":10,"gia":1}]'::jsonb)$q$, S, T4));
  PERFORM public._gg_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'G14d gói 10 phút bị từ chối');
  j := public._gg_rpc(format($q$SELECT public.ban_goi_gio_luu_v1(%L, ARRAY[%L, %L],
        '[{"so_phut":120,"gia":100000},{"so_phut":180,"gia":140000}]'::jsonb)$q$, S, T0, T4));
  PERFORM public._gg_as('admin');
  PERFORM public._gg_ok((j->>'success')::boolean
    AND (SELECT count(*) FROM public.ban_goi_gio WHERE table_id IN (T0, T4)) = 4,
    'G14e chủ quán lưu 2 gói cho hai bàn ("Cả khu") — ' || j::text);
  SELECT id INTO G120 FROM public.ban_goi_gio WHERE table_id = T0 AND so_phut = 120;
  SELECT id INTO G180 FROM public.ban_goi_gio WHERE table_id = T0 AND so_phut = 180;

  -- ── Chọn gói cho bàn đang chơi ─────────────────────────────────────────────────────────────
  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (P1, S, T0::uuid, 'open');
  UPDATE public.ban_sessions SET gio_bat_dau = clock_timestamp() - interval '89 minutes 30 seconds' WHERE id = P1;
  PERFORM public._gg_as('authenticated', B, S);
  j := public._gg_rpc(format($q$SELECT public.ban_chon_goi_gio_v1(%L, %L, %L)$q$, S, P1, G120));
  PERFORM public._gg_ok((j->>'success')::boolean, 'G12 phục vụ chọn gói lần đầu — ' || j::text);
  j := public._gg_rpc(format($q$SELECT public.ban_chon_goi_gio_v1(%L, %L, %L)$q$, S, P1, G180));
  PERFORM public._gg_ok(j->>'raised' = '42501', 'G12b phục vụ không đổi được gói đã chọn');
  j := public._gg_rpc(format($q$SELECT public.ban_chon_goi_gio_v1(%L, %L, NULL)$q$, S, P1));
  PERFORM public._gg_ok(j->>'raised' = '42501', 'G12c phục vụ không bỏ được gói đã chọn');
  j := public._gg_rpc(format($q$UPDATE public.ban_sessions SET goi_phut = 600, goi_gia = 1 WHERE id = %L RETURNING jsonb_build_object('ok', 1)$q$, P1));
  PERFORM public._gg_as('admin');
  PERFORM public._gg_ok((SELECT goi_phut = 120 AND goi_gia = 100000 FROM public.ban_sessions WHERE id = P1),
    'G15 app ghi thẳng ban_sessions không đổi được gói — ' || COALESCE(j::text, 'null'));
  PERFORM public._gg_as('authenticated', A, S);
  j := public._gg_rpc(format($q$SELECT public.ban_chon_goi_gio_v1(%L, %L, %L)$q$, S, P1, (SELECT id FROM public.ban_goi_gio WHERE table_id = T4 LIMIT 1)));
  PERFORM public._gg_ok(j->>'error_code' = 'INVALID_STATE', 'G12d gói của bàn khác bị từ chối');
  j := public._gg_rpc(format($q$SELECT public.ban_chon_goi_gio_v1(%L, %L, NULL)$q$, S, P1));
  PERFORM public._gg_as('admin');
  PERFORM public._gg_ok((j->>'success')::boolean AND (SELECT goi_phut IS NULL FROM public.ban_sessions WHERE id = P1),
    'G12e chủ quán bỏ gói');
  UPDATE public.ban_sessions SET goi_phut = 120, goi_gia = 100000 WHERE id = P1;

  -- ── Ghi dòng ───────────────────────────────────────────────────────────────────────────────
  j := public.qn_tinh_gio_ghi_dong_v1(S, P1);
  v_ten := j->>'ten';
  PERFORM public._gg_ok((j->>'thanh_tien')::numeric = 100000
    AND v_ten LIKE 'Giờ chơi · P0 · % – % · chơi 1 giờ 30 phút · gói 2 giờ 100.000 đ',
    'G11 trong gói: "chơi 1 giờ 30 phút · gói 2 giờ 100.000 đ" — ' || v_ten);
  UPDATE public.ban_sessions SET gio_bat_dau = clock_timestamp() - interval '136 minutes 30 seconds' WHERE id = P1;
  DELETE FROM public.ban_session_items WHERE session_id = P1;
  j := public.qn_tinh_gio_ghi_dong_v1(S, P1);
  v_ten := j->>'ten';
  PERFORM public._gg_ok((j->>'thanh_tien')::numeric = 117000
    AND v_ten LIKE '% · chơi 2 giờ 17 phút · gói 2 giờ 100.000 đ + 17 phút × 60.000 đ/giờ'
    AND (SELECT count(*) FROM public.ban_session_items WHERE session_id = P1 AND gio_tu IS NOT NULL) = 1,
    'G11b lố: "gói 2 giờ 100.000 đ + 17 phút × 60.000 đ/giờ", một dòng — ' || v_ten);

  -- ── Chuyển bàn khi có gói ──────────────────────────────────────────────────────────────────
  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (P2, S, T4::uuid, 'open');
  UPDATE public.ban_sessions SET gio_bat_dau = clock_timestamp() - interval '39 minutes 30 seconds',
    goi_phut = 120, goi_gia = 100000 WHERE id = P2;
  PERFORM public._gg_as('authenticated', A, S);
  j := public._gg_rpc(format($q$SELECT public.ban_chuyen_ban_tinh_gio_v1(%L, %L, %L)$q$, P2, S, T3));
  PERFORM public._gg_as('admin');
  SELECT * INTO v_dong FROM public.ban_session_items WHERE session_id = P2 AND gio_tu IS NOT NULL ORDER BY gio_tu LIMIT 1;
  PERFORM public._gg_ok((j->>'success')::boolean AND v_dong.subtotal = 100000
    AND (SELECT goi_phut = 80 AND goi_gia = 0 AND table_id = T3::uuid FROM public.ban_sessions WHERE id = P2),
    'G13 chuyển bàn sau 40 phút: bàn cũ 100.000, bàn mới còn gói 80 phút giá 0 — ' || j::text);
  UPDATE public.ban_sessions SET gio_bat_dau = clock_timestamp() - interval '199 minutes 30 seconds' WHERE id = P2;
  j := public.qn_tinh_gio_ghi_dong_v1(S, P2);
  PERFORM public._gg_ok((j->>'thanh_tien')::numeric = 120000 AND (j->>'ten') LIKE '% · chơi 3 giờ 20 phút · phần còn của gói 1 giờ 20 phút + 2 giờ × 60.000 đ/giờ',
    'G13b bàn mới (tối thiểu 180): 200 phút, gói còn 80 → lố 120 phút = 120.000 — ' || (j->>'ten'));

  -- ── QC 28/11: đổi gói sau khi đã chốt giờ thì dòng tiền giờ được chốt lại ─────────────────────
  IF to_regproc('public.qn_tinh_gio_ghi_lai_neu_da_chot_v1') IS NOT NULL THEN
    UPDATE public.ban_sessions SET goi_phut = NULL, goi_gia = NULL, gio_bat_dau = clock_timestamp() - interval '89 minutes 30 seconds'
     WHERE id = P1;
    DELETE FROM public.ban_session_items WHERE session_id = P1;
    j := public.qn_tinh_gio_ghi_dong_v1(S, P1);   -- chốt khi chưa có gói: 90 phút × 60.000 = 90.000
    PERFORM public._gg_as('authenticated', A, S);
    j := public._gg_rpc(format($q$SELECT public.ban_chon_goi_gio_v1(%L, %L, %L)$q$, S, P1, G120));
    PERFORM public._gg_as('admin');
    PERFORM public._gg_ok((j->>'success')::boolean
      AND (SELECT subtotal FROM public.ban_session_items WHERE session_id = P1 AND gio_tu IS NOT NULL) = 100000,
      'G16 chọn gói sau khi đã chốt: dòng tiền giờ chốt lại thành 100.000 (không giữ 90.000 cũ) — ' || j::text);
  END IF;

  RAISE NOTICE '>>> GÓI GIỜ: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
