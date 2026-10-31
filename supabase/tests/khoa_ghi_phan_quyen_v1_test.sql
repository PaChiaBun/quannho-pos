-- ============================================================================
-- TEST: Khóa ghi phân quyền v1 (20261022_khoa_ghi_phan_quyen_v1.sql)
-- CHỈ CHẠY TRÊN DB STAGING/DISPOSABLE đã áp migration. Một transaction, kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._kg_as(p_role text, p_uid uuid DEFAULT NULL, p_store uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  IF p_role IN ('anon', 'authenticated') THEN
    EXECUTE format('SET LOCAL ROLE %I', p_role);
  END IF;
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_uid IS NULL THEN '{}' ELSE json_build_object('sub', p_uid::text, 'role', p_role)::text END, true);
  PERFORM set_config('request.headers',
    CASE WHEN p_store IS NULL THEN '{}' ELSE json_build_object('x-store-id', p_store::text)::text END, true);
END
$f$;

CREATE OR REPLACE FUNCTION public._kg_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

DO $test$
DECLARE
  A  uuid := gen_random_uuid();  -- chủ S1
  M  uuid := gen_random_uuid();  -- quản lý S1
  M2 uuid := gen_random_uuid();  -- quản lý khác S1
  W  uuid := gen_random_uuid();  -- phục vụ S1 (có hồ sơ)
  W2 uuid := gen_random_uuid();  -- phục vụ S1 (chưa có hồ sơ staff_members)
  C  uuid := gen_random_uuid();  -- thu ngân S1
  B  uuid := gen_random_uuid();  -- chủ S2
  S1 uuid := gen_random_uuid();
  S2 uuid := gen_random_uuid();
  v_role uuid; v_role2 uuid;
  v_hint text; v_n int; v_r record; v_res jsonb;
BEGIN
  RAISE NOTICE '>>> KHOA GHI PHAN QUYEN v1: BẮT ĐẦU <<<';
  PERFORM public._kg_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name)
  SELECT u, '+84' || (100000000 + (random()*899999999)::bigint), 'x', 'U'
  FROM unnest(ARRAY[A, M, M2, W, W2, C, B]) AS u;
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
    (S1, 'K' || substr(S1::text, 1, 7), 'Quan 1', A),
    (S2, 'K' || substr(S2::text, 1, 7), 'Quan 2', B);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S1, 'owner', true), (M, S1, 'manager', false), (M2, S1, 'manager', false),
    (W, S1, 'waiter', false), (W2, S1, 'waiter', false), (C, S1, 'cashier', false), (B, S2, 'owner', true);
  INSERT INTO public.staff_members (id, store_id, name, role, modules, hourly_rate, is_active) VALUES
    (A,  S1, 'Chu', 'owner', '[]', 0, true),
    (M,  S1, 'QL M', 'manager', '[]', 0, true),
    (M2, S1, 'QL M2', 'manager', '[]', 0, true),
    (W,  S1, 'PV W', 'waiter', '["pos"]', 20000, true),
    (C,  S1, 'TN C', 'cashier', '[]', 25000, true);
  INSERT INTO public.store_roles (id, store_id, name, modules) VALUES
    (gen_random_uuid(), S1, 'Phục vụ T', '["ban"]') RETURNING id INTO v_role;
  INSERT INTO public.store_roles (id, store_id, name, modules) VALUES
    (gen_random_uuid(), S2, 'Phục vụ S2', '["ban"]') RETURNING id INTO v_role2;

  -- ───────── store_roles ─────────
  PERFORM public._kg_as('authenticated', W, S1);
  BEGIN UPDATE public.store_roles SET modules = '["pos","kho","staff"]' WHERE id = v_role; v_hint := 'KHONG_CHAN';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
  PERFORM public._kg_ok(v_hint = 'QN_ROLES_WRITE_FORBIDDEN', 'T1 phục vụ KHÔNG sửa được store_roles.modules');

  BEGIN INSERT INTO public.store_roles (store_id, name, modules) VALUES (S1, 'Tu cap', '["pos"]'); v_hint := 'KHONG_CHAN';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
  PERFORM public._kg_ok(v_hint = 'QN_ROLES_WRITE_FORBIDDEN', 'T2 phục vụ KHÔNG tạo được vai trò');

  BEGIN DELETE FROM public.store_roles WHERE id = v_role; v_hint := 'KHONG_CHAN';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
  PERFORM public._kg_ok(v_hint = 'QN_ROLES_WRITE_FORBIDDEN', 'T3 phục vụ KHÔNG xóa được vai trò');

  PERFORM public._kg_as('authenticated', M, S1);
  UPDATE public.store_roles SET modules = '["ban","pos"]' WHERE id = v_role;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  PERFORM public._kg_ok(v_n = 1, 'T4 quản lý sửa được vai trò quán mình');

  PERFORM public._kg_as('authenticated', A, S1);
  INSERT INTO public.store_roles (store_id, name, modules) VALUES (S1, 'Moi', '["pos"]');
  PERFORM public._kg_ok(true, 'T5 chủ quán tạo được vai trò');

  PERFORM public._kg_as('authenticated', M, S1);
  UPDATE public.store_roles SET modules = '["x"]' WHERE id = v_role2;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  PERFORM public._kg_ok(v_n = 0, 'T6 quản lý KHÔNG đụng được vai trò của quán khác (RLS)');

  PERFORM public._kg_as('anon', NULL, NULL);
  BEGIN UPDATE public.store_roles SET modules = '["pos"]' WHERE id = v_role; GET DIAGNOSTICS v_n = ROW_COUNT; v_hint := CASE WHEN v_n = 0 THEN 'CHAN' ELSE 'KHONG_CHAN' END;
  EXCEPTION WHEN OTHERS THEN v_hint := 'CHAN'; END;
  PERFORM public._kg_ok(v_hint = 'CHAN', 'T7 anon KHÔNG sửa được vai trò');

  -- ───────── staff_members: người thường ─────────
  PERFORM public._kg_as('authenticated', W, S1);
  UPDATE public.staff_members
     SET name = 'PV W moi', role = 'manager', modules = '["pos","kho","staff"]', hourly_rate = 999999, is_active = false
   WHERE id = W;
  SELECT * INTO v_r FROM public.staff_members WHERE id = W;
  PERFORM public._kg_ok(v_r.name = 'PV W moi', 'T8 phục vụ sửa được tên hồ sơ của mình');
  PERFORM public._kg_ok(v_r.role = 'waiter', 'T9 phục vụ KHÔNG tự đổi vai trò (bị ép về vai trò thật)');
  PERFORM public._kg_ok(v_r.modules = '["pos"]'::jsonb, 'T10 phục vụ KHÔNG tự đổi modules');
  PERFORM public._kg_ok(v_r.hourly_rate = 20000, 'T11 phục vụ KHÔNG tự tăng lương/giờ');
  PERFORM public._kg_ok(v_r.is_active = true, 'T12 phục vụ KHÔNG tự đổi trạng thái hoạt động');

  BEGIN UPDATE public.staff_members SET name = 'hack' WHERE id = C; v_hint := 'KHONG_CHAN';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
  PERFORM public._kg_ok(v_hint = 'QN_STAFF_WRITE_FORBIDDEN', 'T13 phục vụ KHÔNG sửa hồ sơ người khác');

  BEGIN DELETE FROM public.staff_members WHERE id = W; v_hint := 'KHONG_CHAN';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
  PERFORM public._kg_ok(v_hint = 'QN_STAFF_WRITE_FORBIDDEN', 'T14 phục vụ KHÔNG xóa được hồ sơ');

  PERFORM public._kg_as('authenticated', W2, S1);
  INSERT INTO public.staff_members (id, store_id, name, phone, role, is_active, modules, hourly_rate)
  VALUES (W2, S1, 'PV W2', '0900', 'cashier', true, '["kho","staff"]', 99999)
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, role = EXCLUDED.role;
  SELECT * INTO v_r FROM public.staff_members WHERE id = W2;
  PERFORM public._kg_ok(v_r.role = 'waiter' AND v_r.modules = '[]'::jsonb AND v_r.hourly_rate = 0,
    'T15 luồng đồng bộ hồ sơ của nhân viên mới chạy được nhưng bị ép role thật/modules rỗng/lương 0');

  BEGIN INSERT INTO public.staff_members (id, store_id, name, role) VALUES (gen_random_uuid(), S1, 'ma', 'owner'); v_hint := 'KHONG_CHAN';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
  PERFORM public._kg_ok(v_hint = 'QN_STAFF_WRITE_FORBIDDEN', 'T16 phục vụ KHÔNG tạo hồ sơ owner giả');

  -- ───────── staff_members: quản lý ─────────
  PERFORM public._kg_as('authenticated', M, S1);
  UPDATE public.staff_members SET role = 'kitchen', modules = '["kitchen"]' WHERE id = C;
  SELECT * INTO v_r FROM public.staff_members WHERE id = C;
  PERFORM public._kg_ok(v_r.role = 'kitchen', 'T17 quản lý đổi được vai trò/modules nhân viên cấp dưới');

  BEGIN UPDATE public.staff_members SET role = 'manager' WHERE id = C; v_hint := 'KHONG_CHAN';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
  PERFORM public._kg_ok(v_hint = 'QN_STAFF_HIERARCHY', 'T18 quản lý KHÔNG nâng ai lên Quản lý');

  BEGIN UPDATE public.staff_members SET name = 'x' WHERE id = A; v_hint := 'KHONG_CHAN';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
  PERFORM public._kg_ok(v_hint = 'QN_STAFF_HIERARCHY', 'T19 quản lý KHÔNG sửa được Chủ quán');

  BEGIN DELETE FROM public.staff_members WHERE id = M2; v_hint := 'KHONG_CHAN';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT; END;
  PERFORM public._kg_ok(v_hint = 'QN_STAFF_HIERARCHY', 'T20 quản lý KHÔNG xóa Quản lý khác');

  UPDATE public.staff_members SET name = 'QL M moi' WHERE id = M;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  PERFORM public._kg_ok(v_n = 1, 'T21 quản lý sửa được hồ sơ của chính mình');

  -- ───────── Chủ quán ─────────
  PERFORM public._kg_as('authenticated', A, S1);
  UPDATE public.staff_members SET role = 'manager' WHERE id = C;
  SELECT * INTO v_r FROM public.staff_members WHERE id = C;
  PERFORM public._kg_ok(v_r.role = 'manager', 'T22 chủ quán nâng được người lên Quản lý');

  -- ───────── Đường hợp lệ khác không bị chặn ─────────
  PERFORM public._kg_as('authenticated', A, S1);
  v_res := public.admin_update_staff_role_v4(S1, W, 'kitchen');
  PERFORM public._kg_ok((v_res->>'success')::boolean IS TRUE, 'T23 RPC admin_update_staff_role_v4 (SECURITY DEFINER) vẫn chạy: ' || v_res::text);

  PERFORM public._kg_as('admin');
  UPDATE public.store_roles SET modules = '["ban","pos"]' WHERE id = v_role;
  UPDATE public.staff_members SET hourly_rate = 21000 WHERE id = W;
  PERFORM public._kg_ok(true, 'T24 quyền admin/service (migration, sửa tay) không bị trigger chặn');

  PERFORM public._kg_as('admin');
  RAISE NOTICE '>>> KHOA GHI PHAN QUYEN v1: TẤT CẢ ĐẠT <<<';
END
$test$;

ROLLBACK;
