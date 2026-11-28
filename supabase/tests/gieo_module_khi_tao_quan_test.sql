-- ============================================================================
-- TEST: 20261121_gieo_module_khi_tao_quan.sql — quán mới có sẵn cấu hình module. Kết thúc ROLLBACK.
-- Chạy được ngay trên máy chủ thật (trong giao dịch). Quán thử tạo bằng tài khoản chủ quán Demo;
-- quán chèn thẳng thì lùi created_at để không chạm chốt 15 quán / 10 phút (qn_rate_limit_signup).
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._gm_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

-- Chèn quán bằng quyền chủ hàm nhưng GIỮ vai của người gọi (như một lệnh từ app không có danh tính).
CREATE OR REPLACE FUNCTION public._gm_chen_quan(p_id uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
  INSERT INTO public.stores (id, name, store_code, status, created_at)
  VALUES (p_id, 'Quán thử gieo C', 'QN-GMC1', 'trial', now() - interval '1 day');
$f$;

DO $test$
DECLARE
  DEMO uuid := '00000000-0000-0000-0000-000000009999';
  A uuid;
  S1 uuid := gen_random_uuid();
  S2 uuid;
  S3 uuid := gen_random_uuid();
  r jsonb;
  v text;
  n integer;
  MAC_DINH constant text := '["pos","report","finance","kho"]';
BEGIN
  RAISE NOTICE '>>> GIEO MODULE KHI TẠO QUÁN: BẮT ĐẦU <<<';
  SELECT owner_user_id INTO A FROM public.stores WHERE id = DEMO;
  IF A IS NULL THEN RAISE EXCEPTION '❌ FAIL: không thấy chủ quán Demo'; END IF;

  -- 1. Vai quản trị chèn thẳng một quán
  INSERT INTO public.stores (id, name, store_code, status, created_at)
  VALUES (S1, 'Quán thử gieo A', 'QN-GMA1', 'trial', now() - interval '1 day');
  SELECT value INTO v FROM public.app_settings WHERE store_id = S1 AND key = 'module_config_v2';
  PERFORM public._gm_ok(v = MAC_DINH, '1 quán chèn thẳng có cấu hình mặc định — ' || COALESCE(v, 'NULL'));

  -- 2. Đường thật: chủ quán gọi hàm tạo quán bằng phiên đăng nhập (chưa có phiên của quán mới)
  PERFORM set_config('request.jwt.claims', json_build_object('role', 'authenticated', 'sub', A)::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.create_store_with_owner_v4('Quán thử gieo B');
  EXECUTE 'RESET ROLE';
  PERFORM public._gm_ok((r->>'success')::boolean, '2a tạo quán qua hàm thành công — ' || r::text);
  S2 := (r->>'store_id')::uuid;
  SELECT value INTO v FROM public.app_settings WHERE store_id = S2 AND key = 'module_config_v2';
  PERFORM public._gm_ok(v = MAC_DINH, '2b quán tạo qua hàm có cấu hình mặc định dù app chưa gieo');

  -- 3. App gieo lại (upsert của seedDefaults) bằng phiên của quán mới: không lỗi, không sinh dòng thứ hai
  PERFORM set_config('request.jwt.claims',
    json_build_object('role', 'authenticated', 'sub', A, 'store_id', S2)::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO public.app_settings (store_id, key, value) VALUES (S2, 'module_config_v2', MAC_DINH)
    ON CONFLICT (store_id, key) DO UPDATE SET value = EXCLUDED.value;
  -- 4. Chủ quán bật thêm module trên quán vừa tạo (việc trước đây bị app bỏ qua vì không thấy dòng)
  UPDATE public.app_settings SET value = '["pos","report","finance","kho","staff"]'
   WHERE store_id = S2 AND key = 'module_config_v2';
  GET DIAGNOSTICS n = ROW_COUNT;
  EXECUTE 'RESET ROLE';
  PERFORM public._gm_ok(n = 1, '4 chủ quán bật thêm module trên quán mới: ghi được 1 dòng');
  SELECT count(*) INTO n FROM public.app_settings WHERE store_id = S2 AND key = 'module_config_v2';
  PERFORM public._gm_ok(n = 1, '3 app gieo lại không sinh dòng trùng');

  -- 5. Gieo bị chốt "chỉ Chủ quán" từ chối (lệnh không có danh tính) thì quán vẫn được tạo
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.headers', '', true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._gm_chen_quan(S3);
  EXECUTE 'RESET ROLE';
  PERFORM public._gm_ok(EXISTS (SELECT 1 FROM public.stores WHERE id = S3),
    '5a gieo lỗi không làm hỏng việc tạo quán');
  PERFORM public._gm_ok(NOT EXISTS (SELECT 1 FROM public.app_settings WHERE store_id = S3),
    '5b lệnh không danh tính không gieo được (chốt chỉ Chủ quán vẫn giữ)');

  -- 6. Không đụng quán cũ
  PERFORM public._gm_ok(
    (SELECT count(*) FROM public.module_config_history
      WHERE at >= now() AND store_id NOT IN (S1, S2, S3)) = 0,
    '6 không ghi gì lên cấu hình của quán khác');
  RAISE NOTICE '>>> GIEO MODULE KHI TẠO QUÁN: XONG <<<';
END
$test$;

ROLLBACK;
