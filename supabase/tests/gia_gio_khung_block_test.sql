-- ============================================================================
-- TEST: 20261128_gia_gio_khung_block.sql — khung giá + làm tròn block. Một giao dịch, kết thúc ROLLBACK.
-- Bộ ca (mục 5 kế hoạch) dùng chung với test Dart test/modules/tinh_gio/gia_gio_khung_test.dart.
-- 30/11/2026 là Thứ Hai.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._gk_as(p_role text, p_uid uuid DEFAULT NULL, p_store uuid DEFAULT NULL)
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

CREATE OR REPLACE FUNCTION public._gk_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._gk_rpc(p_sql text)
RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE j jsonb;
BEGIN
  EXECUTE p_sql INTO j;
  RETURN j;
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('raised', SQLSTATE, 'msg', SQLERRM);
END
$f$;
GRANT EXECUTE ON FUNCTION public._gk_rpc(text) TO anon, authenticated;

-- tiền theo cài đặt của bàn p_ban
CREATE OR REPLACE FUNCTION public._gk_tien(p_ban text, p_vao timestamptz, p_phut int, p_goc numeric DEFAULT 60000)
RETURNS jsonb LANGUAGE sql AS $f$ SELECT public.qn_tinh_gio_tinh_tien_v2(p_ban, p_goc, p_vao, p_phut) $f$;

DO $test$
DECLARE
  A uuid := gen_random_uuid(); B uuid := gen_random_uuid(); S uuid := gen_random_uuid();
  Z text := gen_random_uuid()::text;
  T0 text := gen_random_uuid()::text; T1 text := gen_random_uuid()::text; T2 text := gen_random_uuid()::text;
  T3 text := gen_random_uuid()::text; T4 text := gen_random_uuid()::text;
  PG uuid := gen_random_uuid(); P1 uuid := gen_random_uuid();
  j jsonb; v_ten text; i int; v_phut int; v_gia numeric; v_vao timestamptz; v_sai int := 0;
  GIA_MAU numeric[] := ARRAY[60000, 35000, 12345.67, 0, 150000, 1000, 99999]::numeric[];
BEGIN
  RAISE NOTICE '>>> GIÁ KHUNG GIỜ + BLOCK: BẮT ĐẦU <<<';
  PERFORM public._gk_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*33000000)::int), 'x', 'Chu A'),
    (B, '+84' || (933000001 + (random()*33000000)::int), 'x', 'Phuc vu B');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, created_at) VALUES
    (S, 'T' || substr(S::text, 1, 7), 'Quan test gia khung', A, now() - interval '1 day');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S, 'owner', true), (B, S, 'waiter', false);
  INSERT INTO public.ban_zones (id, store_id, name) VALUES (Z, S, 'Khu bi da');
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name) VALUES
    (T0, S, Z, 'Ban 0'), (T1, S, Z, 'Ban 1'), (T2, S, Z, 'Ban 2'), (T3, S, Z, 'Ban 3'), (T4, S, Z, 'Ban 4');
  INSERT INTO public.products (id, store_id, name, sell_price, cost_price, unit, is_available, is_active, category) VALUES
    (PG, S, 'Giờ chơi 60.000 đ/giờ', 60000, 0, 'giờ', true, true, 'Tiền giờ');
  UPDATE public.ban_dining_tables SET gia_gio_product_id = PG WHERE id IN (T0, T1, T2, T3, T4);

  -- ── Không cài gì: như công thức cũ ─────────────────────────────────────────────────────────
  j := public._gk_tien(T0, '2026-11-30 14:05+07', 90);
  PERFORM public._gk_ok((j->>'thanh_tien')::numeric = 90000 AND (j->>'so_phut_tinh')::int = 90
    AND jsonb_array_length(j->'doan') = 1, 'C1 không cài gì: 90 phút × 60.000 = 90.000 — ' || j::text);
  j := public._gk_tien(T0, '2026-11-30 14:05+07', 45);
  PERFORM public._gk_ok((j->>'thanh_tien')::numeric = 45000, 'C2 45 phút = 45.000');

  FOR i IN 1 .. 2000 LOOP
    v_phut := 1 + floor(random() * 3000)::int;
    v_gia := GIA_MAU[1 + floor(random() * array_length(GIA_MAU, 1))::int];
    v_vao := '2026-11-01 00:00+07'::timestamptz + make_interval(secs => floor(random() * 86400 * 60));
    IF (public._gk_tien(T0, v_vao, v_phut, v_gia)->>'thanh_tien')::numeric
       <> ceil(v_phut * GREATEST(v_gia, 0) / 60.0 / 1000.0) * 1000 THEN
      v_sai := v_sai + 1;
    END IF;
  END LOOP;
  PERFORM public._gk_ok(v_sai = 0, 'HỒI QUY 2.000 lượt ngẫu nhiên, bàn không cài gì: khớp công thức cũ từng đồng (sai ' || v_sai || ')');

  -- ── Khung giá ──────────────────────────────────────────────────────────────────────────────
  INSERT INTO public.ban_gia_gio_khung (store_id, table_id, thu, tu, den, gia, thu_tu) VALUES
    (S, T1, '{1,2,3,4,5,6,7}', '17:00', '00:00', 80000, 0);
  j := public._gk_tien(T1, '2026-11-30 16:30+07', 60);
  PERFORM public._gk_ok((j->>'thanh_tien')::numeric = 70000 AND jsonb_array_length(j->'doan') = 2
    AND (j->'doan'->0->>'phut')::int = 30 AND (j->'doan'->1->>'gia')::numeric = 80000,
    'C3 vắt khung 16:30–17:30: 30 phút × 60.000 + 30 phút × 80.000 = 70.000 — ' || (j->'doan')::text);
  j := public._gk_tien(T1, '2026-11-30 16:59:30+07', 2);
  PERFORM public._gk_ok((j->>'thanh_tien')::numeric = 3000 AND (j->'doan'->0->>'gia')::numeric = 60000,
    'C15 có giây: phút bắt đầu 16:59:30 giá gốc, 17:00:30 giá khung → 140.000/60 làm tròn 3.000');

  INSERT INTO public.ban_gia_gio_khung (store_id, table_id, thu, tu, den, gia, thu_tu) VALUES
    (S, T2, '{1,2,3,4,5,6,7}', '22:00', '02:00', 90000, 0);
  j := public._gk_tien(T2, '2026-11-30 23:00+07', 120);
  PERFORM public._gk_ok((j->>'thanh_tien')::numeric = 180000 AND jsonb_array_length(j->'doan') = 1,
    'C4 khung qua đêm 22:00–02:00, chơi 23:00–01:00: 120 phút × 90.000 = 180.000');
  j := public._gk_tien(T2, '2026-12-01 01:30+07', 60);
  PERFORM public._gk_ok((j->>'thanh_tien')::numeric = 75000,
    'C4b phần sau nửa đêm thuộc khung của hôm trước: 30 × 90.000 + 30 × 60.000 = 75.000');

  INSERT INTO public.ban_gia_gio_khung (store_id, table_id, thu, tu, den, gia, thu_tu) VALUES
    (S, T3, '{6,7}', '00:00', '00:00', 100000, 0);
  j := public._gk_tien(T3, '2026-12-04 23:30+07', 60);   -- Thứ Sáu 23:30 → Thứ Bảy 00:30
  PERFORM public._gk_ok((j->>'thanh_tien')::numeric = 80000,
    'C5 khung cả ngày T7, CN: T6 23:30–T7 00:30 = 30 × 60.000 + 30 × 100.000 = 80.000');
  j := public._gk_tien(T3, '2026-11-30 10:00+07', 60);
  PERFORM public._gk_ok((j->>'thanh_tien')::numeric = 60000, 'C5b thứ Hai không vào khung cuối tuần');

  -- hai khung chồng nhau: khung đứng trên thắng
  INSERT INTO public.ban_gia_gio_khung (store_id, table_id, thu, tu, den, gia, thu_tu) VALUES
    (S, T4, '{1,2,3,4,5,6,7}', '18:00', '20:00', 90000, 0),
    (S, T4, '{1,2,3,4,5,6,7}', '17:00', '00:00', 80000, 1);
  j := public._gk_tien(T4, '2026-11-30 18:00+07', 60);
  PERFORM public._gk_ok((j->>'thanh_tien')::numeric = 90000, 'C14 hai khung chồng nhau: khung đứng trên (90.000) thắng');
  j := public._gk_tien(T4, '2026-11-30 17:30+07', 60);
  PERFORM public._gk_ok((j->>'thanh_tien')::numeric = 85000, 'C14b 17:30–18:30: 30 × 80.000 + 30 × 90.000 = 85.000');

  j := public._gk_tien(T1, '2026-11-30 10:00+07', 60, 0);
  PERFORM public._gk_ok((j->>'thanh_tien')::numeric = 0, 'C13 giá gốc 0 ngoài khung: 0 đ, không lỗi');

  -- ── Làm tròn ───────────────────────────────────────────────────────────────────────────────
  INSERT INTO public.ban_gia_gio_cau_hinh (table_id, store_id, block_phut, toi_thieu_phut, an_han_phut)
    VALUES (T0, S, 30, 0, 0);
  j := public._gk_tien(T0, '2026-11-30 14:00+07', 47);
  PERFORM public._gk_ok((j->>'so_phut_tinh')::int = 60 AND (j->>'thanh_tien')::numeric = 60000,
    'C6 block 30: chơi 47 phút tính 60 phút');
  j := public._gk_tien(T0, '2026-11-30 14:00+07', 3);
  PERFORM public._gk_ok((j->>'so_phut_tinh')::int = 30, 'C6b block 30: chơi 3 phút vẫn tính trọn một block');
  UPDATE public.ban_gia_gio_cau_hinh SET an_han_phut = 5 WHERE table_id = T0;
  j := public._gk_tien(T0, '2026-11-30 14:00+07', 33);
  PERFORM public._gk_ok((j->>'so_phut_tinh')::int = 30, 'C7 block 30 ân hạn 5: chơi 33 phút tính 30');
  j := public._gk_tien(T0, '2026-11-30 14:00+07', 36);
  PERFORM public._gk_ok((j->>'so_phut_tinh')::int = 60, 'C8 block 30 ân hạn 5: chơi 36 phút tính 60');
  j := public._gk_tien(T0, '2026-11-30 14:00+07', 4);
  PERFORM public._gk_ok((j->>'so_phut_tinh')::int = 30, 'C8b ân hạn không làm chơi 4 phút thành 0 phút');
  UPDATE public.ban_gia_gio_cau_hinh SET block_phut = 1, an_han_phut = 0, toi_thieu_phut = 60 WHERE table_id = T0;
  j := public._gk_tien(T0, '2026-11-30 14:00+07', 20);
  PERFORM public._gk_ok((j->>'so_phut_tinh')::int = 60 AND (j->>'thanh_tien')::numeric = 60000, 'C9 tối thiểu 60: chơi 20 phút tính 60');
  j := public._gk_tien(T0, '2026-11-30 14:00+07', 75);
  PERFORM public._gk_ok((j->>'so_phut_tinh')::int = 75, 'C9b quá tối thiểu thì tính theo phút');
  UPDATE public.ban_gia_gio_cau_hinh SET block_phut = 30, toi_thieu_phut = 0 WHERE table_id = T0;
  j := public._gk_tien(T0, '2026-11-30 14:00+07', 120);
  PERFORM public._gk_ok((j->>'so_phut_tinh')::int = 120, 'C10 khung đặt trước 2 giờ (ghi_dong đã kéo tới hết khung) + block 30: 120');

  INSERT INTO public.ban_gia_gio_cau_hinh (table_id, store_id, block_phut) VALUES (T1, S, 30);
  j := public._gk_tien(T1, '2026-11-30 16:50+07', 25);
  PERFORM public._gk_ok((j->>'so_phut_tinh')::int = 30 AND (j->>'thanh_tien')::numeric = 37000,
    'C11 khung + block: 16:50 chơi 25 phút → 30 phút = 10 × 60.000 + 20 × 80.000 → 36.667 làm tròn 37.000');

  -- ── Lưu cài đặt qua hàm app ────────────────────────────────────────────────────────────────
  PERFORM public._gk_as('authenticated', B, S);
  j := public._gk_rpc(format($q$SELECT public.ban_gia_gio_luu_v1(%L, ARRAY[%L], 30, 0, 0, '[]'::jsonb)$q$, S, T2));
  PERFORM public._gk_ok(j->>'raised' = '42501', 'L1 phục vụ không lưu được giá giờ — ' || j::text);
  PERFORM public._gk_as('authenticated', A, S);
  j := public._gk_rpc(format($q$SELECT public.ban_gia_gio_luu_v1(%L, ARRAY[%L, %L], 15, 30, 5,
        '[{"thu":[6,7],"tu":"17:00","den":"23:00","gia":90000},{"thu":[1,2,3,4,5],"tu":"17:00","den":"23:00","gia":70000}]'::jsonb)$q$, S, T2, T3));
  PERFORM public._gk_as('admin');
  PERFORM public._gk_ok((j->>'success')::boolean
    AND (SELECT count(*) FROM public.ban_gia_gio_khung WHERE table_id IN (T2, T3)) = 4
    AND (SELECT bool_and(block_phut = 15 AND toi_thieu_phut = 30 AND an_han_phut = 5) FROM public.ban_gia_gio_cau_hinh WHERE table_id IN (T2, T3))
    AND (SELECT thu_tu = 0 AND gia = 90000 FROM public.ban_gia_gio_khung WHERE table_id = T2 AND thu = '{6,7}'),
    'L2 chủ quán lưu cho hai bàn ("Cả khu"): thay khung cũ, giữ thứ tự — ' || j::text);
  PERFORM public._gk_as('authenticated', A, S);
  j := public._gk_rpc(format($q$SELECT public.ban_gia_gio_luu_v1(%L, ARRAY[%L], 30, 0, 30, '[]'::jsonb)$q$, S, T2));
  PERFORM public._gk_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'L3 ân hạn ≥ block bị từ chối');
  j := public._gk_rpc(format($q$SELECT public.ban_gia_gio_luu_v1(%L, ARRAY[%L], 7, 0, 0, '[]'::jsonb)$q$, S, T2));
  PERFORM public._gk_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'L4 block 7 phút không có trong danh sách');
  j := public._gk_rpc(format($q$SELECT public.ban_gia_gio_luu_v1(%L, ARRAY[%L], 1, 0, 0,
        '[{"thu":[9],"tu":"17:00","den":"23:00","gia":1}]'::jsonb)$q$, S, T2));
  PERFORM public._gk_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'L5 thứ 9 không hợp lệ (thứ 8 = Ngày lễ từ đợt 6)');
  j := public._gk_rpc(format($q$SELECT public.ban_gia_gio_luu_v1(%L, ARRAY['khong-co'], 1, 0, 0, '[]'::jsonb)$q$, S));
  PERFORM public._gk_ok(j->>'error_code' = 'INVALID_STATE', 'L6 bàn không thuộc quán bị từ chối');
  j := public._gk_rpc(format($q$SELECT public.ban_gia_gio_luu_v1(%L, ARRAY[%L], 1, 0, 0, '[]'::jsonb)$q$, S, T3));
  PERFORM public._gk_as('admin');
  PERFORM public._gk_ok((j->>'success')::boolean AND (j->'data'->>'mac_dinh')::boolean
    AND NOT EXISTS (SELECT 1 FROM public.ban_gia_gio_cau_hinh WHERE table_id = T3)
    AND NOT EXISTS (SELECT 1 FROM public.ban_gia_gio_khung WHERE table_id = T3),
    'L7 lưu mặc định = xoá cài đặt, bàn tính như cũ');

  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES (P1, S, T2::uuid, 'open');
  UPDATE public.ban_sessions SET gio_bat_dau = clock_timestamp() - interval '46 minutes 30 seconds' WHERE id = P1;
  PERFORM public._gk_as('authenticated', A, S);
  j := public._gk_rpc(format($q$SELECT public.ban_gia_gio_luu_v1(%L, ARRAY[%L], 1, 0, 0, '[]'::jsonb)$q$, S, T2));
  PERFORM public._gk_as('admin');
  PERFORM public._gk_ok(j->>'error_code' = 'TINH_GIO_BAN_DANG_CHAY', 'L8 bàn đang chạy giờ thì không đổi giá được — ' || j::text);

  -- ── Tên dòng trên hoá đơn ──────────────────────────────────────────────────────────────────
  DELETE FROM public.ban_gia_gio_khung WHERE table_id = T2;
  UPDATE public.ban_gia_gio_cau_hinh SET block_phut = 30, toi_thieu_phut = 0, an_han_phut = 0 WHERE table_id = T2;
  j := public.qn_tinh_gio_ghi_dong_v1(S, P1);
  v_ten := j->>'ten';
  PERFORM public._gk_ok(v_ten LIKE 'Giờ chơi · Ban 2 · % – % · chơi 47 phút, tính 1 giờ × 60.000 đ/giờ'
    AND (j->>'thanh_tien')::numeric = 60000 AND (j->>'so_phut')::int = 60 AND (j->>'so_phut_choi')::int = 47,
    'N1 làm tròn: "chơi 47 phút, tính 1 giờ × 60.000 đ/giờ" — ' || v_ten);
  DELETE FROM public.ban_gia_gio_cau_hinh WHERE table_id = T2;
  INSERT INTO public.ban_gia_gio_khung (store_id, table_id, thu, tu, den, gia) VALUES
    (S, T2, '{1,2,3,4,5,6,7}',
     date_trunc('minute', (clock_timestamp() - interval '20 minutes') AT TIME ZONE 'Asia/Ho_Chi_Minh')::time,
     date_trunc('minute', (clock_timestamp() + interval '60 minutes') AT TIME ZONE 'Asia/Ho_Chi_Minh')::time, 90000);
  j := public.qn_tinh_gio_ghi_dong_v1(S, P1);
  v_ten := j->>'ten';
  PERFORM public._gk_ok(v_ten ~ '· 4[78] phút \(2[5-8] phút × 60\.000 \+ (19|2[0-3]) phút × 90\.000 đ/giờ\)$'
    AND jsonb_array_length(j->'doan') = 2
    AND (SELECT count(*) FROM public.ban_session_items WHERE session_id = P1 AND gio_tu IS NOT NULL) = 1,
    'N2 hai giá: một dòng có chi tiết, vẫn đúng một dòng tiền giờ — ' || v_ten);

  RAISE NOTICE '>>> GIÁ KHUNG GIỜ + BLOCK: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
