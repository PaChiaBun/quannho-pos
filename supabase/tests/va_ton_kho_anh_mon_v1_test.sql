-- ============================================================================
-- TEST: 20261026_va_ton_kho_anh_mon_v1.sql + v2 (S8: số lẻ)
--  S. adjust_product_stock: chỉ thành viên đúng quán / service_role; anon không gọi được; quán khoá bị chặn
--  I. Xoá ảnh product-images: chỉ khi mọi món dùng ảnh đều thuộc quán mình; ảnh dùng chung / ảnh rác bị chặn
-- CHỈ CHẠY TRÊN DB STAGING/DISPOSABLE đã áp migration. Một transaction, kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._vt_as(p_role text, p_sub uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  IF p_role IN ('anon', 'authenticated', 'service_role') THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_sub::text, ''), true);
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_role = 'admin' THEN ''
         WHEN p_sub IS NULL THEN json_build_object('role', p_role)::text
         ELSE json_build_object('sub', p_sub::text, 'role', p_role)::text END, true);
  PERFORM set_config('request.headers', '{}', true);
END $f$;

CREATE OR REPLACE FUNCTION public._vt_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END $f$;

-- Sửa tồn kho; trả 'ok' hoặc 'err:<sqlstate>'
CREATE OR REPLACE FUNCTION public._vt_adj(p_prod text, p_delta real, p_store text)
RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM public.adjust_product_stock(p_prod, p_delta, p_store);
  RETURN 'ok';
EXCEPTION WHEN OTHERS THEN RETURN 'err:' || SQLSTATE;
END $f$;

-- Xoá ảnh như Storage API làm (DELETE trên storage.objects bằng quyền người gọi); trả số dòng xoá được
CREATE OR REPLACE FUNCTION public._vt_del(p_name text)
RETURNS int LANGUAGE plpgsql AS $f$
DECLARE n int;
BEGIN
  PERFORM set_config('storage.allow_delete_query', 'true', true);
  DELETE FROM storage.objects WHERE bucket_id = 'product-images' AND name = p_name;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $f$;
GRANT EXECUTE ON FUNCTION public._vt_as(text, uuid), public._vt_ok(boolean, text), public._vt_adj(text, real, text), public._vt_del(text)
  TO anon, authenticated, service_role;

DO $test$
DECLARE
  A  uuid := gen_random_uuid();  -- chủ S1
  M  uuid := gen_random_uuid();  -- nhân viên S1
  B  uuid := gen_random_uuid();  -- chủ S3 (người ngoài với S1)
  S1 uuid := gen_random_uuid();
  S3 uuid := gen_random_uuid();
  P1 uuid := gen_random_uuid();  P1b uuid := gen_random_uuid();
  P3 uuid := gen_random_uuid();  P3b uuid := gen_random_uuid();
  X1 text := gen_random_uuid() || '.jpg';   -- ảnh riêng S1
  X3 text := gen_random_uuid() || '.png';   -- ảnh riêng S3
  XS text := gen_random_uuid() || '.jpg';   -- ảnh S1 + S3 dùng chung
  XO text := gen_random_uuid() || '.webp';  -- ảnh rác (không món nào dùng)
  base text := 'https://quannho.lpm.vn/supabase/storage/v1/object/public/product-images/';
  sig text := 'public.adjust_product_stock(text,real,text)';
  r text; q numeric; n int;
BEGIN
  RAISE NOTICE '>>> VÁ TỒN KHO + ẢNH MÓN: BẮT ĐẦU <<<';
  PERFORM public._vt_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A'),
    (M, '+84' || (700000000 + (random()*99999999)::int), 'x', 'NV M'),
    (B, '+84' || (800000000 + (random()*99999999)::int), 'x', 'Chu B');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
    (S1, 'T' || substr(S1::text, 1, 7), 'Quan 1', A),
    (S3, 'T' || substr(S3::text, 1, 7), 'Quan 3', B);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S1, 'owner', true), (M, S1, 'waiter', false), (B, S3, 'owner', true);
  INSERT INTO public.products (id, store_id, name, stock_qty, is_deleted, image_url) VALUES
    (P1,  S1, 'Tra da', 10, false, base || X1),
    (P1b, S1, 'Ca phe', 10, false, base || XS),
    (P3,  S3, 'Banh mi', 10, false, base || X3),
    (P3b, S3, 'Ca phe 3', 10, false, base || XS);
  INSERT INTO storage.objects (bucket_id, name) VALUES
    ('product-images', X1), ('product-images', X3), ('product-images', XS), ('product-images', XO);

  -- ── S. Quyền + chốt adjust_product_stock ──
  PERFORM public._vt_ok(NOT has_function_privilege('anon', sig, 'EXECUTE')
                        AND has_function_privilege('authenticated', sig, 'EXECUTE')
                        AND has_function_privilege('service_role', sig, 'EXECUTE'), 'S0 anon không gọi được; authenticated + service_role được');
  PERFORM public._vt_ok((SELECT proconfig FROM pg_proc WHERE oid = to_regprocedure(sig)) @> ARRAY['search_path=public, pg_temp'],
                        'S0b search_path cố định');

  PERFORM public._vt_as('authenticated', A);
  r := public._vt_adj(P1::text, 5, S1::text);
  PERFORM public._vt_as('admin'); SELECT stock_qty INTO q FROM public.products WHERE id = P1;
  PERFORM public._vt_ok(r = 'ok' AND q = 15, 'S1 chủ quán cộng tồn kho món quán mình (' || r || ', còn ' || q || ')');

  PERFORM public._vt_as('authenticated', M);
  r := public._vt_adj(P1::text, -100, S1::text);
  PERFORM public._vt_as('admin'); SELECT stock_qty INTO q FROM public.products WHERE id = P1;
  PERFORM public._vt_ok(r = 'ok' AND q = 0, 'S2 nhân viên trừ quá tay → dừng ở 0 (' || r || ', còn ' || q || ')');

  PERFORM public._vt_as('authenticated', B);
  r := public._vt_adj(P1::text, 7, S1::text);
  PERFORM public._vt_as('admin'); SELECT stock_qty INTO q FROM public.products WHERE id = P1;
  PERFORM public._vt_ok(r = 'err:42501' AND q = 0, 'S3 chủ quán khác sửa tồn kho S1 bị chặn (' || r || ')');

  PERFORM public._vt_as('authenticated', B);
  r := public._vt_adj(P1::text, 7, S3::text);
  PERFORM public._vt_as('admin'); SELECT stock_qty INTO q FROM public.products WHERE id = P1;
  PERFORM public._vt_ok(q = 0, 'S4 khai quán mình nhưng id món quán khác → không đổi gì (' || r || ')');

  PERFORM public._vt_as('anon');
  r := public._vt_adj(P1::text, 7, S1::text);
  PERFORM public._vt_ok(r = 'err:42501', 'S5 anon bị chặn (' || r || ')');

  PERFORM public._vt_as('service_role');
  r := public._vt_adj(P1::text, 3, S1::text);
  PERFORM public._vt_as('admin'); SELECT stock_qty INTO q FROM public.products WHERE id = P1;
  PERFORM public._vt_ok(r = 'ok' AND q = 3, 'S6 service_role sửa được (' || r || ')');

  PERFORM public._vt_as('authenticated', A);
  r := public._vt_adj('khong-phai-uuid', 1, S1::text);
  PERFORM public._vt_ok(r = 'err:22P02', 'S7 id món sai định dạng → lỗi rõ ràng (' || r || ')');

  -- S8 (v2): số lẻ không dính rác dấu phẩy động
  PERFORM public._vt_as('admin'); UPDATE public.products SET stock_qty = 10.25 WHERE id = P1;
  PERFORM public._vt_as('authenticated', A);
  r := public._vt_adj(P1::text, 0.1, S1::text);
  PERFORM public._vt_as('admin'); SELECT stock_qty INTO q FROM public.products WHERE id = P1;
  PERFORM public._vt_ok(r = 'ok' AND q = 10.35, 'S8 10.25 + 0.1 = đúng 10.35 (' || r || ', còn ' || q || ')');
  UPDATE public.products SET stock_qty = 3 WHERE id = P1;

  -- ── I. Xoá ảnh ──
  PERFORM public._vt_ok(NOT has_function_privilege('anon', 'public.qn_product_image_deletable(text)', 'EXECUTE'),
                        'I0 anon không gọi được hàm kiểm ảnh');
  PERFORM public._vt_as('authenticated', B);
  n := public._vt_del(X1);
  PERFORM public._vt_ok(n = 0, 'I1 chủ quán khác xoá ảnh riêng của S1 → 0 dòng');
  PERFORM public._vt_as('authenticated', A);
  n := public._vt_del(XS);
  PERFORM public._vt_ok(n = 0, 'I2 ảnh S1 + S3 dùng chung → S1 không xoá được');
  n := public._vt_del(XO);
  PERFORM public._vt_ok(n = 0, 'I3 ảnh rác (không món nào dùng) → thành viên không xoá được');
  PERFORM public._vt_as('authenticated', M);
  n := public._vt_del(X1);
  PERFORM public._vt_ok(n = 1, 'I4 nhân viên S1 xoá ảnh món S1 (đúng luồng gỡ ảnh trong app) → 1 dòng');
  PERFORM public._vt_as('authenticated', B);
  n := public._vt_del(X3);
  PERFORM public._vt_ok(n = 1, 'I5 chủ S3 xoá ảnh món S3 → 1 dòng');
  PERFORM public._vt_as('service_role');
  n := public._vt_del(XO);
  PERFORM public._vt_ok(n = 1, 'I6 service_role (bộ dọn ảnh rác) xoá được ảnh rác');
  PERFORM public._vt_as('admin');
  PERFORM public._vt_ok((SELECT count(*) FROM storage.objects WHERE name IN (X1, X3, XS, XO)) = 1
                        AND EXISTS (SELECT 1 FROM storage.objects WHERE name = XS), 'I7 chỉ còn ảnh dùng chung');

  -- ── L. Quán bị khoá ──
  UPDATE public.stores SET status = 'locked' WHERE id = S1;
  PERFORM public._vt_as('authenticated', A);
  r := public._vt_adj(P1::text, 1, S1::text);
  PERFORM public._vt_ok(r = 'err:42501', 'L1 quán bị khoá → chủ quán cũng không sửa tồn kho (' || r || ')');

  PERFORM public._vt_as('admin');
  RAISE NOTICE '>>> VÁ TỒN KHO + ẢNH MÓN: HẾT (tất cả PASS) <<<';
END $test$;

ROLLBACK;
