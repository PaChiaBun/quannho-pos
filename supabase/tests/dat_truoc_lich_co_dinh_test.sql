-- ============================================================================
-- TEST: 20261128_dat_truoc_lich_co_dinh.sql — đặt lặp hàng tuần. Một giao dịch, kết thúc ROLLBACK.
-- 02/12/2030 là Thứ Hai → 03/12 T3, 05/12 T5.
-- ============================================================================
BEGIN;
-- Như PostgREST trên máy chủ thật: UPDATE / DELETE không có WHERE bị chặn (bài học 28/11, lịch cố định).
LOAD 'safeupdate';

CREATE OR REPLACE FUNCTION public._lc_as(p_role text, p_uid uuid DEFAULT NULL, p_store uuid DEFAULT NULL)
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

CREATE OR REPLACE FUNCTION public._lc_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._lc_rpc(p_sql text)
RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE j jsonb;
BEGIN
  EXECUTE p_sql INTO j;
  RETURN j;
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('raised', SQLSTATE, 'msg', SQLERRM);
END
$f$;
GRANT EXECUTE ON FUNCTION public._lc_rpc(text) TO anon, authenticated;

DO $test$
DECLARE
  A uuid := gen_random_uuid(); K uuid := gen_random_uuid(); S uuid := gen_random_uuid();
  Z text := gen_random_uuid()::text; T1 text := gen_random_uuid()::text; T2 text := gen_random_uuid()::text;
  j jsonb; v_chuoi uuid; q text;
BEGIN
  RAISE NOTICE '>>> LỊCH CỐ ĐỊNH: BẮT ĐẦU <<<';
  PERFORM public._lc_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*33000000)::int), 'x', 'Chu A'),
    (K, '+84' || (933000001 + (random()*33000000)::int), 'x', 'Bep K');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, created_at) VALUES
    (S, 'T' || substr(S::text, 1, 7), 'Quan test lich co dinh', A, now() - interval '1 day');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S, 'owner', true), (K, S, 'kitchen', false);
  INSERT INTO public.ban_zones (id, store_id, name) VALUES (Z, S, 'San');
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name) VALUES (T1, S, Z, 'San 1'), (T2, S, Z, 'San 2');

  q := $q$SELECT public.ban_dat_truoc_lap_v1(%L, %L, 'CLB Cau long', '0901 234 567', %L, %s, %L, %L, NULL, 200000, %L)$q$;

  -- ── Sinh đúng buổi ─────────────────────────────────────────────────────────────────────────
  PERFORM public._lc_as('authenticated', A, S);
  j := public._lc_rpc(format(q, S, T1, '2030-12-03 18:00+07', 120, '{2,4}', '2030-12-26', false));
  PERFORM public._lc_as('admin');
  v_chuoi := (j->'data'->>'chuoi_id')::uuid;
  PERFORM public._lc_ok((j->>'success')::boolean AND (j->'data'->>'so_buoi')::int = 8
    AND (SELECT count(*) FROM public.ban_dat_truoc WHERE chuoi_id = v_chuoi) = 8,
    'L1 T3, T5 từ 03/12 tới 26/12: 8 buổi cùng một chuỗi — ' || left(j::text, 120));
  PERFORM public._lc_ok((SELECT bool_and(extract(isodow FROM gio_tu AT TIME ZONE 'Asia/Ho_Chi_Minh') IN (2, 4)
      AND to_char(gio_tu AT TIME ZONE 'Asia/Ho_Chi_Minh', 'HH24:MI') = '18:00'
      AND gio_den - gio_tu = interval '120 minutes' AND trang_thai = 'da_dat' AND tien_coc = 200000
      AND sdt = '0901234567' AND table_id = T1)
    FROM public.ban_dat_truoc WHERE chuoi_id = v_chuoi), 'L2 mọi buổi đúng thứ, đúng 18:00 giờ VN, 2 giờ, chờ khách, sđt gọn');
  PERFORM public._lc_ok((SELECT max(gio_tu AT TIME ZONE 'Asia/Ho_Chi_Minh')::date FROM public.ban_dat_truoc WHERE chuoi_id = v_chuoi) = '2030-12-26',
    'L3 tính cả ngày kết thúc (T5 26/12)');

  -- ── Trùng giờ ──────────────────────────────────────────────────────────────────────────────
  PERFORM public._lc_as('authenticated', A, S);
  j := public._lc_rpc(format(q, S, T1, '2030-12-19 19:00+07', 60, '{4}', '2031-01-09', false));
  PERFORM public._lc_as('admin');
  PERFORM public._lc_ok(j->>'error_code' = 'TRUNG_GIO' AND jsonb_array_length(j->'trung') = 2
    AND (j->>'so_buoi_ghi_duoc')::int = 2
    AND (SELECT count(*) FROM public.ban_dat_truoc WHERE table_id = T1) = 8,
    'L4 có 2 buổi trùng (19/12, 26/12), chưa cho bỏ qua: không ghi gì, trả danh sách — ' || left(j::text, 160));
  PERFORM public._lc_as('authenticated', A, S);
  j := public._lc_rpc(format(q, S, T1, '2030-12-19 19:00+07', 60, '{4}', '2031-01-09', true));
  PERFORM public._lc_as('admin');
  PERFORM public._lc_ok((j->>'success')::boolean AND (j->'data'->>'so_buoi')::int = 2 AND (j->'data'->>'bo_qua')::int = 2,
    'L5 cho bỏ qua buổi trùng: ghi 2 buổi còn lại (02/01, 09/01)');
  PERFORM public._lc_as('authenticated', A, S);
  j := public._lc_rpc(format(q, S, T1, '2030-12-03 18:30+07', 30, '{2}', '2030-12-10', true));
  PERFORM public._lc_as('admin');
  PERFORM public._lc_ok(j->>'error_code' = 'TRUNG_GIO' AND (j->>'so_buoi_ghi_duoc')::int = 0,
    'L6 mọi buổi đều trùng: báo lỗi kể cả khi cho bỏ qua');
  PERFORM public._lc_as('authenticated', A, S);
  j := public._lc_rpc(format(q, S, T2, '2030-12-03 18:00+07', 120, '{2,4}', '2030-12-26', false));
  PERFORM public._lc_as('admin');
  PERFORM public._lc_ok((j->>'success')::boolean, 'L7 cùng giờ ở sân khác thì không trùng');

  -- ── Kiểm dữ liệu ───────────────────────────────────────────────────────────────────────────
  PERFORM public._lc_as('authenticated', A, S);
  j := public._lc_rpc(format(q, S, T1, '2031-02-01 08:00+07', 60, '{}', '2031-02-28', false));
  PERFORM public._lc_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'L8 không chọn thứ nào bị từ chối');
  j := public._lc_rpc(format(q, S, T1, '2031-02-01 08:00+07', 60, '{8}', '2031-02-28', false));
  PERFORM public._lc_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'L9 thứ 8 bị từ chối');
  j := public._lc_rpc(format(q, S, T1, '2031-02-01 08:00+07', 60, '{1}', '2031-01-01', false));
  PERFORM public._lc_ok(j->>'error_code' = 'INVALID_TIME', 'L10 ngày kết thúc trước ngày bắt đầu');
  j := public._lc_rpc(format(q, S, T1, '2031-02-01 08:00+07', 60, '{1}', '2032-03-01', false));
  PERFORM public._lc_ok(j->>'error_code' = 'INVALID_TIME', 'L11 quá một năm bị từ chối');
  j := public._lc_rpc(format(q, S, T1, '2031-02-01 08:00+07', 60, '{1,2,3,4,5,6,7}', '2031-07-01', false));
  PERFORM public._lc_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'L12 quá 120 buổi bị từ chối — ' || COALESCE(j->>'message', ''));
  j := public._lc_rpc(format(q, S, T1, '2031-02-01 08:00+07', 10, '{1}', '2031-02-28', false));
  PERFORM public._lc_ok(j->>'error_code' = 'INVALID_TIME', 'L13 buổi dưới 15 phút bị từ chối');
  j := public._lc_rpc(format(q, S, T1, '2020-01-06 08:00+07', 60, '{1}', '2020-02-28', false));
  PERFORM public._lc_ok(j->>'error_code' = 'INVALID_TIME', 'L14 khoảng ngày đã qua hết: không có buổi nào');
  j := public._lc_rpc(format(q, S, 'khong-co', '2031-02-01 08:00+07', 60, '{1}', '2031-02-28', false));
  PERFORM public._lc_ok(j->>'error_code' = 'INVALID_STATE', 'L15 bàn không thuộc quán');

  PERFORM public._lc_as('authenticated', K, S);
  j := public._lc_rpc(format(q, S, T2, '2031-03-03 08:00+07', 60, '{1}', '2031-03-31', false));
  PERFORM public._lc_as('admin');
  PERFORM public._lc_ok(j->>'raised' = '42501' OR j->>'error_code' IS NOT NULL AND NOT COALESCE((j->>'success')::boolean, false),
    'L16 vai bếp (không quyền thanh toán) không đặt được — ' || left(j::text, 100));

  -- ── Huỷ chuỗi từ một buổi ──────────────────────────────────────────────────────────────────
  UPDATE public.ban_dat_truoc SET trang_thai = 'da_nhan'
   WHERE chuoi_id = v_chuoi AND gio_tu = '2030-12-17 18:00+07';
  PERFORM public._lc_as('authenticated', A, S);
  j := public._lc_rpc(format($q$SELECT public.ban_dat_truoc_huy_chuoi_v1(%L, %L, %L)$q$, S, v_chuoi, '2030-12-12 00:00+07'));
  PERFORM public._lc_as('admin');
  PERFORM public._lc_ok((j->>'success')::boolean AND (j->'data'->>'so_buoi_huy')::int = 4
    AND (SELECT count(*) FILTER (WHERE trang_thai = 'da_dat') FROM public.ban_dat_truoc WHERE chuoi_id = v_chuoi) = 3
    AND (SELECT trang_thai FROM public.ban_dat_truoc WHERE chuoi_id = v_chuoi AND gio_tu = '2030-12-17 18:00+07') = 'da_nhan',
    'L17 huỷ chuỗi từ 12/12: huỷ 4 buổi chờ khách (19, 24, 26/12 và 12/12), giữ 3 buổi trước và buổi đã nhận — ' || j::text);

  -- buổi trong chuỗi vẫn sửa được bằng hàm cũ, giữ chuoi_id
  PERFORM public._lc_as('authenticated', A, S);
  j := public._lc_rpc(format($q$SELECT public.ban_dat_truoc_luu_v1(%L, (SELECT id FROM public.ban_dat_truoc WHERE chuoi_id = %L AND gio_tu = '2030-12-03 18:00+07'),
        %L, 'CLB Cau long', NULL, '2030-12-03 17:00+07', '2030-12-03 19:00+07')$q$, S, v_chuoi, T1));
  PERFORM public._lc_as('admin');
  PERFORM public._lc_ok((j->>'success')::boolean AND (j->'data'->>'chuoi_id')::uuid = v_chuoi,
    'L18 sửa một buổi bằng hàm cũ: vẫn thuộc chuỗi');

  RAISE NOTICE '>>> LỊCH CỐ ĐỊNH: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
