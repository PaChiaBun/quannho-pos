-- ============================================================================
-- TEST: Củng cố P0 v3 (20261022_cung_co_p0_v3.sql) — chạy đúng kiểu app thật (anon + header).
-- CHỈ CHẠY TRÊN DB đã áp migration. Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._v3_app(p_uid uuid, p_store uuid)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.headers',
    json_build_object('x-store-id', p_store::text, 'x-user-id', p_uid::text)::text, true);
END
$f$;

CREATE OR REPLACE FUNCTION public._v3_admin()
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.headers', '', true);
END
$f$;

CREATE OR REPLACE FUNCTION public._v3_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._v3_try(p_sql text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE n integer;
BEGIN
  EXECUTE p_sql;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN 'ok:' || n;
EXCEPTION WHEN OTHERS THEN
  RETURN 'err:' || SQLSTATE;
END
$f$;

DO $test$
DECLARE
  A  uuid := gen_random_uuid();   -- chủ quán
  M  uuid := gen_random_uuid();   -- quản lý
  W  uuid := gen_random_uuid();   -- phục vụ
  C  uuid := gen_random_uuid();   -- thu ngân (mã 'cashier'; vai trò quán "Thu ngân" có Thu Chi)
  K  uuid := gen_random_uuid();   -- vai trò tuỳ chỉnh "Kế Toán" có Thu Chi
  W2 uuid := gen_random_uuid();   -- phục vụ được gán riêng module Thu Chi
  S  uuid := gen_random_uuid();
  Z  uuid := gen_random_uuid();
  T1 uuid := gen_random_uuid();
  T2 uuid := gen_random_uuid();
  T3 uuid := gen_random_uuid();
  T4 uuid := gen_random_uuid();   -- bàn trống để thử chuyển bàn
  PC uuid := gen_random_uuid();   -- phiên đã thanh toán
  PO uuid := gen_random_uuid();   -- phiên đang mở
  PM uuid := gen_random_uuid();   -- phiên nguồn gộp bàn (rỗng)
  t  text;
BEGIN
  RAISE NOTICE '>>> CỦNG CỐ P0 v3: BẮT ĐẦU <<<';
  PERFORM public._v3_admin();
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A'),
    (M, '+84' || (600000000 + (random()*99999999)::int), 'x', 'Quan ly M'),
    (W, '+84' || (800000000 + (random()*99999999)::int), 'x', 'Phuc vu W'),
    (C, '+84' || (700000000 + (random()*99999999)::int), 'x', 'Thu ngan C'),
    (K, '+84' || (500000000 + (random()*99999999)::int), 'x', 'Ke toan K'),
    (W2, '+84' || (400000000 + (random()*99999999)::int), 'x', 'Phuc vu W2');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES (S, 'T' || substr(S::text, 1, 7), 'Quan v3', A);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S, 'owner', true), (M, S, 'manager', false), (W, S, 'waiter', false),
    (C, S, 'cashier', false), (K, S, 'Kế Toán', false), (W2, S, 'waiter', false);
  INSERT INTO public.store_roles (store_id, name, modules) VALUES
    (S, 'Thu ngân', '["pos","ban","report","finance"]'),
    (S, 'Phục vụ', '["pos","ban"]'),
    (S, 'Kế Toán', '["finance"]');
  INSERT INTO public.staff_members (id, store_id, name, role, modules) VALUES
    (W2, S, 'Phuc vu W2', 'waiter', '["ban","finance"]'::jsonb);
  INSERT INTO public.ban_zones (id, store_id, name) VALUES (Z, S, 'Khu v3');
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name) VALUES
    (T1::text, S, Z, 'Ban 1'), (T2::text, S, Z, 'Ban 2'), (T3::text, S, Z, 'Ban 3'), (T4::text, S, Z, 'Ban 4');
  INSERT INTO public.ban_sessions (id, store_id, table_id, status, total_amount) VALUES
    (PC, S, T1, 'closed', 150000), (PO, S, T2, 'open', 0), (PM, S, T3, 'open', 0);

  -- K1–K3: app (anon) không gọi được
  PERFORM public._v3_app(W, S);
  t := public._v3_try($q$SELECT public.publish_app_version_v1('windows','9.9.9',999,'https://evil.example/x.exe','fake',true)$q$);
  PERFORM public._v3_ok(t = 'err:42501', 'K1 app không đăng được bản cập nhật giả (' || t || ')');
  t := public._v3_try($q$SELECT public.lookup_staff_by_phone('+84900000000')$q$);
  PERFORM public._v3_ok(t = 'err:42501', 'K2 app không tra được nhân viên theo số điện thoại (' || t || ')');
  t := public._v3_try(format($q$SELECT public.revoke_store_member(%L, %L, %L)$q$, S, M, A));
  PERFORM public._v3_ok(t = 'err:42501', 'K3 app không gọi được revoke_store_member (' || t || ')');

  -- A: phục vụ không tự cấp quyền; vẫn ghi được cài đặt thường
  t := public._v3_try(format($q$INSERT INTO public.app_settings (store_id, key, value) VALUES (%L, 'action_perms_waiter', '["pos.checkout"]')$q$, S));
  PERFORM public._v3_ok(t = 'err:42501', 'A1 phục vụ không tự ghi action_perms (' || t || ')');
  t := public._v3_try(format($q$INSERT INTO public.app_settings (store_id, key, value) VALUES (%L, 'perm_waiter', '["finance"]')$q$, S));
  PERFORM public._v3_ok(t = 'err:42501', 'A2 phục vụ không tự ghi perm_ (' || t || ')');
  t := public._v3_try(format($q$INSERT INTO public.app_settings (store_id, key, value) VALUES (%L, 'v3_test_setting', 'x')$q$, S));
  PERFORM public._v3_ok(t = 'ok:1', 'A3 cài đặt thường vẫn ghi được (' || t || ')');
  -- A4: quản lý ghi được phân quyền
  PERFORM public._v3_app(M, S);
  t := public._v3_try(format($q$INSERT INTO public.app_settings (store_id, key, value) VALUES (%L, 'action_perms_Phục vụ', '["pos.checkout"]')$q$, S));
  PERFORM public._v3_ok(t = 'ok:1', 'A4 quản lý ghi được phân quyền (' || t || ')');
  -- A5: phục vụ không sửa / xoá được dòng phân quyền đã có
  PERFORM public._v3_app(W, S);
  t := public._v3_try(format($q$UPDATE public.app_settings SET value = '[]' WHERE store_id = %L AND key = 'action_perms_Phục vụ'$q$, S));
  PERFORM public._v3_ok(t = 'err:42501', 'A5 phục vụ không sửa phân quyền (' || t || ')');
  t := public._v3_try(format($q$DELETE FROM public.app_settings WHERE store_id = %L AND key = 'action_perms_Phục vụ'$q$, S));
  PERFORM public._v3_ok(t = 'err:42501', 'A5b phục vụ không xoá phân quyền (' || t || ')');

  -- B: phiên đã đóng bị khoá; luồng thật vẫn chạy
  t := public._v3_try(format($q$UPDATE public.ban_sessions SET total_amount = 1, total = 1 WHERE id = %L$q$, PC));
  PERFORM public._v3_ok(t = 'err:42501', 'B1 không sửa tổng tiền bill đã đóng (' || t || ')');
  t := public._v3_try(format($q$UPDATE public.ban_sessions SET guest_count = 99, waiter_id = %L WHERE id = %L$q$, M, PC));
  PERFORM public._v3_ok(t = 'err:42501', 'B2 không sửa số khách / người phục vụ bill đã đóng (' || t || ')');
  t := public._v3_try(format($q$UPDATE public.ban_sessions SET total_amount = 50000 WHERE id = %L$q$, PO));
  PERFORM public._v3_ok(t = 'ok:1', 'B3 phiên đang mở vẫn cập nhật tổng (' || t || ')');
  t := public._v3_try(format($q$UPDATE public.ban_sessions SET table_id = %L WHERE id = %L$q$, T4, PO));
  PERFORM public._v3_ok(t = 'ok:1', 'B4 chuyển bàn phiên đang mở vẫn chạy (' || t || ')');
  t := public._v3_try(format($q$UPDATE public.ban_sessions SET status = 'closed', closed_at = now(), total_amount = 0 WHERE id = %L$q$, PM));
  PERFORM public._v3_ok(t = 'ok:1', 'B5 gộp bàn: đóng phiên nguồn rỗng vẫn chạy (' || t || ')');
  t := public._v3_try(format($q$UPDATE public.ban_sessions SET status = 'cancelled', closed_at = now() WHERE id = %L$q$, PO));
  PERFORM public._v3_ok(t = 'ok:1', 'B6 huỷ bàn vẫn chạy (' || t || ')');
  t := public._v3_try(format($q$UPDATE public.ban_sessions SET guest_count = 7 WHERE id = %L$q$, PO));
  PERFORM public._v3_ok(t = 'err:42501', 'B7 phiên vừa huỷ cũng bị khoá (' || t || ')');

  -- F: phiếu thu chi nhập tay chỉ cho người có quyền Thu Chi; phiếu tự động vẫn mở
  PERFORM public._v3_app(W, S);
  t := public._v3_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, is_auto, fund_type) VALUES (%L, 'income', 50000000, 'phiếu tay giả', false, 'cash')$q$, S));
  PERFORM public._v3_ok(t = 'err:42501', 'F1 phục vụ không ghi được phiếu tay (' || t || ')');
  t := public._v3_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, fund_type) VALUES (%L, 'expense', 1000, 'không ghi is_auto', 'cash')$q$, S));
  PERFORM public._v3_ok(t = 'err:42501', 'F1b bỏ trống is_auto cũng bị coi là phiếu tay (' || t || ')');
  t := public._v3_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, is_auto, fund_type) VALUES (%L, 'income', 45000, 'Bán hàng', true, 'cash')$q$, S));
  PERFORM public._v3_ok(t = 'ok:1', 'F2 phiếu tự động (bán hàng) vẫn ghi được (' || t || ')');
  PERFORM public._v3_app(C, S);
  t := public._v3_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, is_auto, fund_type) VALUES (%L, 'expense', 20000, 'Mua đá', false, 'cash')$q$, S));
  PERFORM public._v3_ok(t = 'ok:1', 'F3 thu ngân (mã cashier ↔ vai trò "Thu ngân" có Thu Chi) ghi được (' || t || ')');
  PERFORM public._v3_app(K, S);
  t := public._v3_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, is_auto, fund_type) VALUES (%L, 'expense', 30000, 'Điện', false, 'bank')$q$, S));
  PERFORM public._v3_ok(t = 'ok:1', 'F4 vai trò tuỳ chỉnh "Kế Toán" có Thu Chi ghi được (' || t || ')');
  PERFORM public._v3_app(W2, S);
  t := public._v3_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, is_auto, fund_type) VALUES (%L, 'income', 10000, 'Thu khác', false, 'cash')$q$, S));
  PERFORM public._v3_ok(t = 'ok:1', 'F5 nhân viên được gán riêng module Thu Chi ghi được (' || t || ')');
  PERFORM public._v3_app(M, S);
  t := public._v3_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, description, is_auto, fund_type) VALUES (%L, 'expense', 40000, 'Gas', false, 'cash')$q$, S));
  PERFORM public._v3_ok(t = 'ok:1', 'F6 quản lý ghi được (' || t || ')');

  -- C: quản trị không bị chặn
  PERFORM public._v3_admin();
  t := public._v3_try(format($q$UPDATE public.ban_sessions SET guest_count = 2 WHERE id = %L$q$, PC));
  PERFORM public._v3_ok(t = 'ok:1', 'C quản trị vẫn sửa được (' || t || ')');

  RAISE NOTICE '>>> CỦNG CỐ P0 v3: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
