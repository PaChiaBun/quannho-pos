-- ============================================================================
-- TEST: bộ nhớ quán bản 2 (20261111_boom_bo_nho_quan_v2.sql) — hạng mục, chi tiết. Kết thúc ROLLBACK.
-- Chạy sau khi đã áp v2 (hoặc trong cùng giao dịch thử với nội dung v2).
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp._ok(p_cond boolean, p_msg text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION pg_temp._as(p_sub uuid) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', p_sub, 'role', 'authenticated')::text, true);
END
$f$;

DO $$ BEGIN
  IF to_regclass('public.user_accounts') IS NOT NULL THEN
    EXECUTE $q$INSERT INTO public.user_accounts (id, phone, password_hash) VALUES
      ('a0000000-0000-0000-0000-0000000000a1', '0900000a01', 'x')$q$;
  END IF;
END $$;
INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
  ('a0000000-0000-0000-0000-00000000000a', 'QN-TBNA', 'Quán A thử', 'a0000000-0000-0000-0000-0000000000a1');

-- Ghi đủ hạng mục và chi tiết như mã boom-chat bản 2 ghi
INSERT INTO public.boom_quan_ghi_nho (id, store_id, noi_dung, loai, nguon, trang_thai, muc_xem, hang_muc, chi_tiet) VALUES
  ('a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-00000000000a', 'Đã chạy quảng cáo Facebook tháng 9, không thêm khách',
   'da_thu', 'chu_quan_noi', 'xac_nhan', 'chu_quan', 'da_thu', '{"kenh":"Facebook","thang":"2026-09","ket_qua":"không thêm khách"}'),
  ('a1000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-00000000000a', 'Quán gần trường THCS',
   'su_that', 'chu_quan_noi', 'xac_nhan', 'ca_quan', 'ho_so', NULL);
-- Ghi nhớ cũ không hạng mục vẫn hợp lệ
INSERT INTO public.boom_quan_ghi_nho (store_id, noi_dung, loai, nguon) VALUES
  ('a0000000-0000-0000-0000-00000000000a', 'Ghi nhớ bản 1', 'so_thich', 'boom_doan');
SELECT pg_temp._ok(true, 'ghi được hạng mục, chi tiết; ghi nhớ không hạng mục vẫn hợp lệ');

DO $$ BEGIN
  INSERT INTO public.boom_quan_ghi_nho (store_id, noi_dung, loai, nguon, hang_muc)
  VALUES ('a0000000-0000-0000-0000-00000000000a', 'Hạng mục lạ', 'su_that', 'boom_doan', 'tiep_thi');
  RAISE EXCEPTION '❌ FAIL: ghi được hạng mục ngoài danh sách';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '✅ PASS: chặn hạng mục ngoài danh sách';
END $$;
DO $$ BEGIN
  INSERT INTO public.boom_quan_ghi_nho (store_id, noi_dung, loai, nguon, hang_muc, muc_xem)
  VALUES ('a0000000-0000-0000-0000-00000000000a', 'Đang vay ngân hàng 100 triệu', 'su_that', 'chu_quan_noi', 'nhan_su_tien', 'ca_quan');
  RAISE EXCEPTION '❌ FAIL: chuyện tiền nong để cả quán thấy';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '✅ PASS: nhân sự, tiền nong luôn chỉ chủ quán thấy';
END $$;
DO $$ BEGIN
  INSERT INTO public.boom_quan_ghi_nho (store_id, noi_dung, loai, nguon, hang_muc, chi_tiet)
  VALUES ('a0000000-0000-0000-0000-00000000000a', 'Chi tiết sai dạng', 'su_that', 'boom_doan', 'ho_so', '["a"]');
  RAISE EXCEPTION '❌ FAIL: chi tiết không phải object';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '✅ PASS: chi tiết phải là object';
END $$;
DO $$ BEGIN
  INSERT INTO public.boom_quan_ghi_nho (store_id, noi_dung, loai, nguon, hang_muc, chi_tiet)
  VALUES ('a0000000-0000-0000-0000-00000000000a', 'Chi tiết quá dài', 'su_that', 'boom_doan', 'ho_so', jsonb_build_object('x', repeat('a', 700)));
  RAISE EXCEPTION '❌ FAIL: chi tiết quá dài';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '✅ PASS: chặn chi tiết quá dài';
END $$;

-- Chủ quán xem thấy hạng mục; sửa thì dòng mới giữ hạng mục
SET LOCAL ROLE authenticated;
SELECT pg_temp._as('a0000000-0000-0000-0000-0000000000a1');
SELECT pg_temp._ok((SELECT count(*) FROM jsonb_array_elements(public.boom_bo_nho_xem_v1('a0000000-0000-0000-0000-00000000000a')->'ghi_nho') e
  WHERE e->>'hang_muc' = 'da_thu' AND e->'chi_tiet'->>'kenh' = 'Facebook') = 1, 'xem trả hạng mục và chi tiết');
SELECT pg_temp._ok(public.boom_bo_nho_sua_v1('a1000000-0000-0000-0000-000000000002', 'Quán gần trường cấp 3') IS NOT NULL, 'chủ quán sửa được');
RESET ROLE;
SELECT pg_temp._ok((SELECT hang_muc FROM public.boom_quan_ghi_nho WHERE thay_cho = 'a1000000-0000-0000-0000-000000000002') = 'ho_so', 'sửa giữ hạng mục');

ROLLBACK;
