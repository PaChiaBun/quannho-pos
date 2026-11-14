-- ============================================================================
-- TEST: 20261026_va_quyen_bep_bao_cao_v1.sql
--  A. send_kitchen_ticket_v2: chỉ thành viên đúng quán; phiên bàn phải thuộc p_store_id; gọi lồng (QR) vẫn chạy
--  B. 4 RPC báo cáo *_for_range_v1: anon (kể cả kèm x-user-id thật) bị chặn; JWT thành viên xem được
-- CHỈ CHẠY TRÊN DB STAGING/DISPOSABLE đã áp migration. Một transaction, kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._vq_as(p_role text, p_sub uuid DEFAULT NULL, p_hdr_uid uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  IF p_role IN ('anon', 'authenticated', 'service_role') THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_sub::text, ''), true);
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_role = 'admin' THEN ''
         WHEN p_sub IS NULL THEN json_build_object('role', p_role)::text
         ELSE json_build_object('sub', p_sub::text, 'role', p_role)::text END, true);
  PERFORM set_config('request.headers',
    CASE WHEN p_hdr_uid IS NULL THEN '{}' ELSE json_build_object('x-user-id', p_hdr_uid::text)::text END, true);
END $f$;

CREATE OR REPLACE FUNCTION public._vq_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END $f$;

-- Gửi bếp; trả 'ok:<items_count>' hoặc 'err:<sqlstate>:<đầu thông báo>'
CREATE OR REPLACE FUNCTION public._vq_send(p_sess uuid, p_store uuid)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE j jsonb;
BEGIN
  j := public.send_kitchen_ticket_v2(p_sess, p_store, 'Ban 1', 'Khu A', NULL, NULL);
  RETURN 'ok:' || COALESCE(j->>'items_count', '?');
EXCEPTION WHEN OTHERS THEN RETURN 'err:' || SQLSTATE || ':' || split_part(SQLERRM, ':', 1);
END $f$;

-- Giả lập đường QR: hàm SECURITY DEFINER (chủ = người tạo test, giống approve_and_send_table_v4) gọi lồng
CREATE OR REPLACE FUNCTION public._vq_nested_send(p_sess uuid, p_store uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $f$
BEGIN
  RETURN public.send_kitchen_ticket_v2(p_sess, p_store, 'Ban QR', 'Khu A', 'Đơn QR', NULL);
END $f$;
GRANT EXECUTE ON FUNCTION public._vq_nested_send(uuid, uuid) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public._vq_report(p_fn int, p_store uuid)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_from timestamptz := '2026-10-01 00:00+07'; v_to timestamptz := '2026-10-08 00:00+07'; n int; j jsonb;
BEGIN
  IF p_fn = 1 THEN j := public.get_report_stats_for_range_v1(p_store, v_from, v_to); RETURN 'ok';
  ELSIF p_fn = 2 THEN SELECT count(*) INTO n FROM public.get_daily_revenue_for_range_v1(p_store, v_from, v_to); RETURN 'ok:' || n;
  ELSIF p_fn = 3 THEN SELECT count(*) INTO n FROM public.get_top_products_for_range_v1(p_store, v_from, v_to, NULL, 20); RETURN 'ok:' || n;
  ELSE SELECT count(*) INTO n FROM public.get_sold_categories_for_range_v1(p_store, v_from, v_to); RETURN 'ok:' || n;
  END IF;
EXCEPTION WHEN insufficient_privilege THEN RETURN 'denied';
END $f$;

DO $test$
DECLARE
  A  uuid := gen_random_uuid();  -- chủ S1
  M  uuid := gen_random_uuid();  -- nhân viên S1
  B  uuid := gen_random_uuid();  -- chủ S3 (người ngoài với S1)
  S1 uuid := gen_random_uuid();
  S3 uuid := gen_random_uuid();
  SS1 uuid := gen_random_uuid(); -- phiên bàn của S1
  SS3 uuid := gen_random_uuid(); -- phiên bàn của S3
  r text; j jsonb; n int; fn int;
  sig text := 'public.send_kitchen_ticket_v2(uuid,uuid,text,text,text,uuid[])';
  names text[] := ARRAY['get_report_stats','get_daily_revenue','get_top_products','get_sold_categories'];
  rpt text[] := ARRAY['public.get_report_stats_for_range_v1(uuid,timestamptz,timestamptz)',
                      'public.get_daily_revenue_for_range_v1(uuid,timestamptz,timestamptz,text)',
                      'public.get_top_products_for_range_v1(uuid,timestamptz,timestamptz,text,integer)',
                      'public.get_sold_categories_for_range_v1(uuid,timestamptz,timestamptz)'];
BEGIN
  RAISE NOTICE '>>> VÁ QUYỀN BẾP + BÁO CÁO: BẮT ĐẦU <<<';
  PERFORM public._vq_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A'),
    (M, '+84' || (700000000 + (random()*99999999)::int), 'x', 'NV M'),
    (B, '+84' || (800000000 + (random()*99999999)::int), 'x', 'Chu B');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
    (S1, 'T' || substr(S1::text, 1, 7), 'Quan 1', A),
    (S3, 'T' || substr(S3::text, 1, 7), 'Quan 3', B);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S1, 'owner', true), (M, S1, 'waiter', false), (B, S3, 'owner', true);
  INSERT INTO public.ban_sessions (id, store_id, status) VALUES (SS1, S1, 'open'), (SS3, S3, 'open');
  INSERT INTO public.ban_session_items (store_id, session_id, product_name, unit_price, price, quantity, subtotal, kitchen_status) VALUES
    (S1, SS1, 'Tra da', 5000, 5000, 1, 5000, 'chua_gui'),
    (S3, SS3, 'Ca phe', 20000, 20000, 1, 20000, 'chua_gui');
  INSERT INTO public.orders (id, store_id, status, total_amount, total, payment_method, discount, created_at) VALUES
    (gen_random_uuid(), S1, 'completed', 100000, 100000, 'cash', 0, '2026-10-02 10:00+07');

  -- ── A. Quyền hàm gửi bếp ──
  PERFORM public._vq_ok(NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
                                    WHERE p.oid = to_regprocedure(sig) AND a.grantee = 0),
                        'A0 send_kitchen_ticket_v2 không còn quyền PUBLIC');
  PERFORM public._vq_ok(has_function_privilege('authenticated', sig, 'EXECUTE')
                        AND has_function_privilege('service_role', sig, 'EXECUTE'), 'A0b authenticated + service_role gọi được');

  -- A1 kẻ lạ: anon không header
  PERFORM public._vq_as('anon');
  r := public._vq_send(SS1, S1);
  PERFORM public._vq_ok(r LIKE 'err:42501:KITCHEN_FORBIDDEN%', 'A1 anon không header bị chặn (' || r || ')');
  -- A2 anon + x-user-id người ngoài
  PERFORM public._vq_as('anon', NULL, B);
  r := public._vq_send(SS1, S1);
  PERFORM public._vq_ok(r LIKE 'err:42501:%', 'A2 anon + x-user-id người ngoài bị chặn (' || r || ')');
  -- A3 JWT của quán khác nhắm vào S1
  PERFORM public._vq_as('authenticated', B);
  r := public._vq_send(SS1, S1);
  PERFORM public._vq_ok(r LIKE 'err:42501:KITCHEN_FORBIDDEN%', 'A3 JWT quán S3 gửi bếp S1 bị chặn (' || r || ')');
  -- A4 JWT S3 khai p_store_id=S3 nhưng phiên là của S1
  r := public._vq_send(SS1, S3);
  PERFORM public._vq_ok(r LIKE 'err:42501:KITCHEN_SESSION_NOT_IN_STORE%', 'A4 phiên S1 + p_store_id S3 bị chặn (' || r || ')');
  -- A5 JWT S1 khai p_store_id=S1 cho phiên của S3
  PERFORM public._vq_as('authenticated', A);
  r := public._vq_send(SS3, S1);
  PERFORM public._vq_ok(r LIKE 'err:42501:KITCHEN_SESSION_NOT_IN_STORE%', 'A5 chủ S1 không gửi bếp phiên S3 (' || r || ')');

  PERFORM public._vq_as('admin');
  PERFORM public._vq_ok((SELECT count(*) FROM public.kitchen_tickets WHERE session_id IN (SS1, SS3)) = 0
                        AND (SELECT count(*) FROM public.ban_session_items WHERE session_id IN (SS1, SS3) AND kitchen_status = 'chua_gui') = 2,
                        'A6 các lần bị chặn không tạo phiếu, không đổi trạng thái món');

  -- A7 nhân viên S1 có JWT: gửi được, phiếu mang store_id S1
  PERFORM public._vq_as('authenticated', M);
  r := public._vq_send(SS1, S1);
  PERFORM public._vq_ok(r = 'ok:1', 'A7 nhân viên S1 (JWT) gửi bếp được (' || r || ')');
  -- A8 bấm đúp: idempotent như cũ
  r := public._vq_send(SS1, S1);
  PERFORM public._vq_ok(r = 'ok:0', 'A8 gửi lại không tạo phiếu trùng (' || r || ')');
  PERFORM public._vq_as('admin');
  PERFORM public._vq_ok((SELECT count(*) FROM public.kitchen_tickets WHERE session_id = SS1 AND store_id = S1) = 1
                        AND (SELECT count(*) FROM public.kitchen_ticket_items i JOIN public.kitchen_tickets t ON t.id = i.ticket_id
                             WHERE t.session_id = SS1 AND i.store_id = S1) = 1
                        AND (SELECT kitchen_status FROM public.ban_session_items WHERE session_id = SS1) = 'da_gui',
                        'A9 đúng 1 phiếu + 1 món của S1, món chuyển da_gui');

  -- A10 TƯƠNG THÍCH app cũ / mở app lúc mất mạng: anon + x-user-id thành viên thật vẫn gửi được
  INSERT INTO public.ban_session_items (store_id, session_id, product_name, unit_price, price, quantity, subtotal, kitchen_status)
    VALUES (S1, SS1, 'Banh mi', 15000, 15000, 1, 15000, 'chua_gui');
  PERFORM public._vq_as('anon', NULL, A);
  r := public._vq_send(SS1, S1);
  PERFORM public._vq_ok(r = 'ok:1', 'A10 app cũ anon + x-user-id chủ S1 vẫn gửi bếp quán mình (' || r || ')');

  -- A11 đường QR: hàm SECURITY DEFINER gọi lồng, người gọi là nhân viên (JWT) → chạy; người ngoài → chặn
  PERFORM public._vq_as('admin');
  INSERT INTO public.ban_session_items (store_id, session_id, product_name, unit_price, price, quantity, subtotal, kitchen_status)
    VALUES (S1, SS1, 'Mon QR', 10000, 10000, 2, 20000, 'chua_gui');
  PERFORM public._vq_as('authenticated', B);
  BEGIN j := public._vq_nested_send(SS1, S1); r := 'ok'; EXCEPTION WHEN OTHERS THEN r := 'err:' || SQLSTATE; END;
  PERFORM public._vq_ok(r = 'err:42501', 'A11 gọi lồng với người ngoài vẫn bị chặn (' || r || ')');
  PERFORM public._vq_as('authenticated', M);
  j := public._vq_nested_send(SS1, S1);
  PERFORM public._vq_ok((j->>'items_count')::int = 1 AND (j->>'round')::int = 3, 'A12 gọi lồng kiểu QR bằng nhân viên S1 chạy (round 3)');

  -- A13 service_role (script máy chủ) không cần là thành viên
  PERFORM public._vq_as('admin');
  INSERT INTO public.ban_session_items (store_id, session_id, product_name, unit_price, price, quantity, subtotal, kitchen_status)
    VALUES (S3, SS3, 'Mon SR', 1000, 1000, 1, 1000, 'chua_gui');
  PERFORM public._vq_as('service_role');
  r := public._vq_send(SS3, S3);
  PERFORM public._vq_ok(r = 'ok:2', 'A13 service_role gửi bếp được (' || r || ')');
  -- …nhưng service_role vẫn không ghép được phiên với quán khác
  r := public._vq_send(SS3, S1);
  PERFORM public._vq_ok(r LIKE 'err:42501:KITCHEN_SESSION_NOT_IN_STORE%', 'A14 service_role cũng không ghép phiên S3 vào S1 (' || r || ')');

  -- ── B. RPC báo cáo ──
  PERFORM public._vq_as('admin');
  FOR fn IN 1..4 LOOP
    PERFORM public._vq_ok(NOT has_function_privilege('anon', rpt[fn], 'EXECUTE')
                          AND NOT EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
                                          WHERE p.oid = to_regprocedure(rpt[fn]) AND a.grantee = 0)
                          AND has_function_privilege('authenticated', rpt[fn], 'EXECUTE')
                          AND has_function_privilege('service_role', rpt[fn], 'EXECUTE'),
                          names[fn] || ': B0 chỉ authenticated + service_role có quyền');
  END LOOP;
  FOR fn IN 1..4 LOOP
    PERFORM public._vq_as('anon');
    PERFORM public._vq_ok(public._vq_report(fn, S1) = 'denied', names[fn] || ': B1 anon không header bị chặn');
    -- đây là lỗ QC 26/10: anon + x-user-id của chủ thật trước đây xem được
    PERFORM public._vq_as('anon', NULL, A);
    PERFORM public._vq_ok(public._vq_report(fn, S1) = 'denied', names[fn] || ': B2 anon + x-user-id chủ thật bị chặn');
    PERFORM public._vq_as('authenticated', A);
    r := public._vq_report(fn, S1);
    PERFORM public._vq_ok(r LIKE 'ok%', names[fn] || ': B3 chủ S1 (JWT) xem được (' || r || ')');
    PERFORM public._vq_as('authenticated', M);
    PERFORM public._vq_ok(public._vq_report(fn, S1) LIKE 'ok%', names[fn] || ': B4 nhân viên S1 (JWT) xem được');
    PERFORM public._vq_as('authenticated', B);
    PERFORM public._vq_ok(public._vq_report(fn, S1) = 'denied', names[fn] || ': B5 JWT quán khác bị chặn');
    PERFORM public._vq_as('authenticated', B, A);
    PERFORM public._vq_ok(public._vq_report(fn, S1) = 'denied', names[fn] || ': B6 JWT B + header x-user-id=A vẫn bị chặn');
  END LOOP;
  -- B7 số liệu vẫn đúng với JWT
  PERFORM public._vq_as('authenticated', A);
  SELECT count(*) INTO n FROM public.get_daily_revenue_for_range_v1(S1, '2026-10-01 00:00+07', '2026-10-08 00:00+07');
  PERFORM public._vq_ok(n >= 1, 'B7 doanh thu theo ngày của S1 có dữ liệu (' || n || ' dòng)');

  PERFORM public._vq_as('admin');
  RAISE NOTICE '>>> VÁ QUYỀN BẾP + BÁO CÁO: TẤT CẢ ĐẠT <<<';
END
$test$;

ROLLBACK;
