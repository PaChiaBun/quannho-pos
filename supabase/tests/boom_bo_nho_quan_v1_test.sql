-- ============================================================================
-- TEST: bộ nhớ riêng từng quán (20261107_boom_bo_nho_quan_v1.sql). Kết thúc ROLLBACK, không để lại dữ liệu.
-- Trọng tâm theo kế hoạch: KHÔNG LỘ cho nhân viên, KHÔNG LẪN giữa các quán (phải đạt 100%), giữ lịch sử khi sửa,
-- sang nhượng xoá điều riêng của chủ cũ.
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

-- 2 quán: A (chủ uA, nhân viên uN), B (chủ uB)
INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
  ('a0000000-0000-0000-0000-00000000000a', 'QN-TBNA', 'Quán A thử', 'a0000000-0000-0000-0000-0000000000a1'),
  ('b0000000-0000-0000-0000-00000000000b', 'QN-TBNB', 'Quán B thử', 'b0000000-0000-0000-0000-0000000000b1');
INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
  ('a0000000-0000-0000-0000-0000000000a2', 'a0000000-0000-0000-0000-00000000000a', 'staff', false);
INSERT INTO public.boom_quan_ghi_nho (id, store_id, noi_dung, loai, nguon, trang_thai, muc_xem) VALUES
  ('a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-00000000000a', 'Quán gần trường THCS', 'su_that', 'chu_quan_noi', 'xac_nhan', 'ca_quan'),
  ('a1000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-00000000000a', 'Đang tính cho nghỉ một bạn bán thời gian', 'su_that', 'chu_quan_noi', 'xac_nhan', 'chu_quan'),
  ('b1000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-00000000000b', 'Khách chính là văn phòng', 'su_that', 'boom_doan', 'doan', 'ca_quan');

-- Không lộ: app (authenticated) không đọc thẳng bảng
SET LOCAL ROLE authenticated;
SELECT pg_temp._as('a0000000-0000-0000-0000-0000000000a2');
DO $$ BEGIN
  PERFORM 1 FROM public.boom_quan_ghi_nho LIMIT 1;
  RAISE EXCEPTION '❌ FAIL: nhân viên đọc thẳng được bảng ghi nhớ';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE '✅ PASS: app không đọc thẳng được bảng ghi nhớ';
END $$;
SELECT pg_temp._ok(public.boom_bo_nho_xem_v1('a0000000-0000-0000-0000-00000000000a') IS NULL, 'nhân viên không xem được bộ nhớ quán');
SELECT pg_temp._ok(public.boom_bo_nho_sua_v1('a1000000-0000-0000-0000-000000000002', 'Không cho nghỉ ai') IS NULL, 'nhân viên không sửa được');
SELECT pg_temp._ok(NOT public.boom_bo_nho_xoa_v1('a1000000-0000-0000-0000-000000000002'), 'nhân viên không xoá được');
SELECT pg_temp._ok(NOT public.boom_bo_nho_tat_v1('a0000000-0000-0000-0000-00000000000a', true), 'nhân viên không tắt được');

-- Chủ quán A xem quán mình
SELECT pg_temp._as('a0000000-0000-0000-0000-0000000000a1');
SELECT pg_temp._ok(jsonb_array_length(public.boom_bo_nho_xem_v1('a0000000-0000-0000-0000-00000000000a')->'ghi_nho') = 2, 'chủ quán A thấy 2 ghi nhớ của quán A');
-- Không lẫn: chủ A không xem, sửa, xoá, tắt được quán B
SELECT pg_temp._ok(public.boom_bo_nho_xem_v1('b0000000-0000-0000-0000-00000000000b') IS NULL, 'chủ A không xem được quán B');
SELECT pg_temp._ok(public.boom_bo_nho_sua_v1('b1000000-0000-0000-0000-000000000001', 'Khách chính là học sinh') IS NULL, 'chủ A không sửa được ghi nhớ quán B');
SELECT pg_temp._ok(NOT public.boom_bo_nho_xoa_v1('b1000000-0000-0000-0000-000000000001'), 'chủ A không xoá được ghi nhớ quán B');
SELECT pg_temp._ok(NOT public.boom_bo_nho_tat_v1('b0000000-0000-0000-0000-00000000000b', true), 'chủ A không tắt được bộ nhớ quán B');

-- Sửa giữ lịch sử
SELECT pg_temp._ok(public.boom_bo_nho_sua_v1('a1000000-0000-0000-0000-000000000001', 'Quán đã dời sang khu văn phòng') IS NOT NULL, 'chủ A sửa được');
SELECT pg_temp._ok(public.boom_bo_nho_tat_v1('a0000000-0000-0000-0000-00000000000a', true), 'chủ A tắt được bộ nhớ quán mình');
RESET ROLE;
SELECT pg_temp._ok((SELECT trang_thai FROM public.boom_quan_ghi_nho WHERE id = 'a1000000-0000-0000-0000-000000000001') = 'het_hieu_luc', 'dòng cũ hết hiệu lực, không bị xoá');
SELECT pg_temp._ok((SELECT count(*) FROM public.boom_quan_ghi_nho WHERE thay_cho = 'a1000000-0000-0000-0000-000000000001'
  AND nguon = 'chu_quan_noi' AND trang_thai = 'xac_nhan') = 1, 'dòng mới trỏ về dòng cũ, chủ quán nói, đã xác nhận');
SELECT pg_temp._ok((SELECT tat FROM public.boom_quan_ho_so WHERE store_id = 'a0000000-0000-0000-0000-00000000000a'), 'công tắc tắt đã lưu');

-- Xoá kéo theo lịch sử (lấy mã dòng mới trước khi đổi vai: vai app không đọc được bảng)
SELECT set_config('tam.id_moi', (SELECT id::text FROM public.boom_quan_ghi_nho WHERE thay_cho = 'a1000000-0000-0000-0000-000000000001'), true);
SET LOCAL ROLE authenticated;
SELECT pg_temp._as('a0000000-0000-0000-0000-0000000000a1');
SELECT pg_temp._ok(public.boom_bo_nho_xoa_v1(current_setting('tam.id_moi')::uuid), 'chủ A xoá được');
RESET ROLE;
SELECT pg_temp._ok(NOT EXISTS (SELECT 1 FROM public.boom_quan_ghi_nho WHERE id = 'a1000000-0000-0000-0000-000000000001'), 'xoá cả dòng lịch sử cũ');

-- Chỉ chủ quán nói mới "đã xác nhận"
DO $$ BEGIN
  INSERT INTO public.boom_quan_ghi_nho (store_id, noi_dung, loai, nguon, trang_thai)
  VALUES ('a0000000-0000-0000-0000-00000000000a', 'Boom đoán mà ghi đã xác nhận', 'su_that', 'boom_doan', 'xac_nhan');
  RAISE EXCEPTION '❌ FAIL: Boom đoán mà ghi được đã xác nhận';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '✅ PASS: Boom đoán không ghi được là đã xác nhận';
END $$;

-- Sang nhượng: chủ mới không thấy điều riêng của chủ cũ, điều chung của quán còn
INSERT INTO public.boom_quan_ghi_nho (store_id, noi_dung, loai, nguon, trang_thai, muc_xem)
VALUES ('a0000000-0000-0000-0000-00000000000a', 'Giờ mở 6h đến 14h', 'su_that', 'chu_quan_noi', 'xac_nhan', 'ca_quan');
INSERT INTO public.boom_quan_loi_khuyen (store_id, noi_dung, chi_so, moc_dau, ngay_do)
VALUES ('a0000000-0000-0000-0000-00000000000a', 'Thử combo trưa 2 tuần', 'so_don_trua', 40, current_date + 14);
UPDATE public.stores SET owner_user_id = 'a0000000-0000-0000-0000-0000000000a3' WHERE id = 'a0000000-0000-0000-0000-00000000000a';
SELECT pg_temp._ok(NOT EXISTS (SELECT 1 FROM public.boom_quan_ghi_nho WHERE store_id = 'a0000000-0000-0000-0000-00000000000a' AND muc_xem = 'chu_quan'), 'sang nhượng: xoá ghi nhớ riêng của chủ cũ');
SELECT pg_temp._ok(EXISTS (SELECT 1 FROM public.boom_quan_ghi_nho WHERE noi_dung = 'Giờ mở 6h đến 14h'), 'sang nhượng: giữ điều chung của quán');
SELECT pg_temp._ok(NOT EXISTS (SELECT 1 FROM public.boom_quan_loi_khuyen WHERE store_id = 'a0000000-0000-0000-0000-00000000000a'), 'sang nhượng: xoá lời khuyên cũ');
SET LOCAL ROLE authenticated;
SELECT pg_temp._as('a0000000-0000-0000-0000-0000000000a1');
SELECT pg_temp._ok(public.boom_bo_nho_xem_v1('a0000000-0000-0000-0000-00000000000a') IS NULL, 'chủ cũ không xem được nữa');
RESET ROLE;

-- Giới hạn 200 ghi nhớ còn hiệu lực mỗi quán
INSERT INTO public.boom_quan_ghi_nho (store_id, noi_dung, loai, nguon)
SELECT 'b0000000-0000-0000-0000-00000000000b', 'Ghi nhớ thử ' || i, 'so_thich', 'boom_doan' FROM generate_series(1, 199) i;
DO $$ BEGIN
  INSERT INTO public.boom_quan_ghi_nho (store_id, noi_dung, loai, nguon)
  VALUES ('b0000000-0000-0000-0000-00000000000b', 'Ghi nhớ thứ 201', 'so_thich', 'boom_doan');
  RAISE EXCEPTION '❌ FAIL: vượt 200 ghi nhớ';
EXCEPTION WHEN check_violation THEN RAISE NOTICE '✅ PASS: chặn ghi nhớ thứ 201';
END $$;

-- Xoá quán: xoá hết bộ nhớ
DELETE FROM public.stores WHERE id = 'b0000000-0000-0000-0000-00000000000b';
SELECT pg_temp._ok(NOT EXISTS (SELECT 1 FROM public.boom_quan_ghi_nho WHERE store_id = 'b0000000-0000-0000-0000-00000000000b'), 'xoá quán thì xoá bộ nhớ');

ROLLBACK;
