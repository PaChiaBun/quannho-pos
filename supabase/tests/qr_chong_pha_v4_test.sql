-- ============================================================================
-- TEST: QR chống phá (20261014_qr_chong_pha_v4.sql)
-- CHỈ CHẠY TRÊN DB STAGING/DISPOSABLE đã áp 20261013_qr_order_simple_v4.sql + 20261014_qr_chong_pha_v4.sql.
-- Một transaction, kết thúc ROLLBACK (không để lại dữ liệu).
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._qrt_as(p_role text, p_uid uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  IF p_role IN ('anon', 'authenticated') THEN
    EXECUTE format('SET LOCAL ROLE %I', p_role);
  END IF;
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_uid IS NULL THEN '{}' ELSE json_build_object('sub', p_uid::text, 'role', p_role)::text END, true);
END
$f$;

CREATE OR REPLACE FUNCTION public._qrt_hdr(p_ip text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM set_config('request.headers',
    CASE WHEN p_ip IS NULL THEN '{}' ELSE json_build_object('x-qn-client-ip', p_ip)::text END, true);
END
$f$;

-- ký vé như cổng cấp vé (python) sẽ làm
CREATE OR REPLACE FUNCTION public._qrt_ticket(p_code text, p_key text, p_exp bigint)
RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path = public, extensions, pg_temp AS $f$
  SELECT p_exp::text || '.' || encode(hmac(convert_to(p_code || '|' || p_exp::text || '|' || p_key, 'UTF8'),
         convert_to((SELECT value FROM public.qr_security_config WHERE key = 'ticket_secret'), 'UTF8'), 'sha256'), 'hex')
$f$;

CREATE OR REPLACE FUNCTION public._qrt_cfg(p_key text, p_val text)
RETURNS void LANGUAGE sql AS $f$
  UPDATE public.qr_security_config SET value = p_val WHERE key = p_key
$f$;

DO $test$
DECLARE
  v_store uuid := gen_random_uuid();
  v_owner uuid := gen_random_uuid();
  v_waiter uuid := gen_random_uuid();
  v_zone uuid := gen_random_uuid();
  v_tbl text := gen_random_uuid()::text;
  v_food uuid := gen_random_uuid();
  v_has_name boolean;
  v_namecol text;
  v_code text;
  v_old_code text;
  v_items jsonb;
  v_r jsonb;
  v_ch jsonb;
  v_n int;
  v_exp bigint;
  i int;
BEGIN
  RAISE NOTICE '>>> QR CHỐNG PHÁ: BẮT ĐẦU <<<';
  PERFORM public._qrt_as('reset');

  INSERT INTO public.stores (id, store_code, name, created_at)
  VALUES (v_store, 'QRCP-' || substr(v_store::text, 1, 8), 'QR Chong Pha', now());
  INSERT INTO public.user_accounts (id, phone, display_name, password_hash) VALUES
    (v_owner, '0900000901', 'Owner CP', 'x'), (v_waiter, '0900000902', 'Waiter CP', 'x');
  INSERT INTO public.store_members (id, store_id, user_id, role, created_at) VALUES
    (gen_random_uuid(), v_store, v_owner, 'owner', now()),
    (gen_random_uuid(), v_store, v_waiter, 'waiter', now());
  INSERT INTO public.ban_zones (id, store_id, name) VALUES (v_zone, v_store, 'Tầng 1');
  SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='name')
    INTO v_has_name;
  v_namecol := CASE WHEN v_has_name THEN 'name' ELSE 'label' END;
  EXECUTE format('INSERT INTO public.ban_dining_tables (id, store_id, zone_id, %I, is_active) VALUES ($1,$2,$3,$4,true)', v_namecol)
    USING v_tbl, v_store, v_zone, 'Bàn CP1';
  INSERT INTO public.products (id, store_id, name, category, sell_price, cost_price_latest, stock_qty, is_topping, is_active, is_deleted)
  VALUES (v_food, v_store, 'Cơm Chiên', 'Món Chính', 65000, 30000, 50, false, true, false);
  v_items := jsonb_build_array(jsonb_build_object('product_id', v_food, 'quantity', 1));

  -- kênh TABLE do chủ quán tạo
  PERFORM public._qrt_as('authenticated', v_owner);
  v_r := public.manage_qr_channel_v4(v_store, 'TABLE_SHARED', true, 'CASHIER_CONFIRM');
  ASSERT (v_r->>'success')::boolean, 'tạo kênh: ' || v_r::text;
  v_code := v_r->'data'->>'channel_code';
  PERFORM public._qrt_as('reset');
  -- cấu hình mặc định hợp lý
  ASSERT public.qr_cfg_v4('flood_per_min') = '100', 'flood mặc định 100';
  ASSERT public.qr_cfg_v4('require_ticket') = 'false', 'require_ticket mặc định tắt';
  PERFORM public._qrt_cfg('flood_per_min', '1000');

  -- ── T1: không có header IP => vẫn gửi được (bỏ qua lớp IP) ───────────────────
  PERFORM public._qrt_as('anon');
  PERFORM public._qrt_hdr(NULL);
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-no-ip-0001', NULL);
  ASSERT (v_r->>'success')::boolean, 'T1 không IP phải gửi được: ' || v_r::text;
  PERFORM public._qrt_as('reset');
  ASSERT (SELECT ip_hash FROM public.qr_requests WHERE idempotency_key = 'cp-key-no-ip-0001') IS NULL, 'T1 ip_hash NULL';

  -- ── T2: IP bị giới hạn theo phút; IP khác không bị ảnh hưởng; IP không lưu dạng gốc ──
  PERFORM public._qrt_cfg('ip_per_min', '3');
  PERFORM public._qrt_cfg('ip_pending', '50');
  PERFORM public._qrt_as('anon');
  PERFORM public._qrt_hdr('203.0.113.9');
  FOR i IN 1..3 LOOP
    v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-ip9-' || lpad(i::text, 4, '0') || 'aaaa', NULL);
    ASSERT (v_r->>'success')::boolean, 'T2 lượt ' || i || ' phải qua: ' || v_r::text;
  END LOOP;
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-ip9-0004aaaa', NULL);
  ASSERT NOT (v_r->>'success')::boolean AND v_r->>'error_code' = 'RATE_LIMITED', 'T2 lượt 4 phải RATE_LIMITED: ' || v_r::text;
  PERFORM public._qrt_hdr('203.0.113.77');
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-ip77-0001a', NULL);
  ASSERT (v_r->>'success')::boolean, 'T2 IP khác vẫn gửi được: ' || v_r::text;
  PERFORM public._qrt_as('reset');
  ASSERT NOT EXISTS (SELECT 1 FROM public.qr_requests WHERE ip_hash LIKE '%203.0.113%'), 'T2 không lưu IP gốc';
  ASSERT (SELECT count(DISTINCT ip_hash) FROM public.qr_requests WHERE idempotency_key LIKE 'cp-key-ip%') = 2, 'T2 hai IP băm khác nhau';

  -- ── T3: giới hạn số đơn chờ theo IP ───────────────────────────────────────
  UPDATE public.qr_requests SET status = 'expired' WHERE store_id = v_store;  -- tránh trần 5 đơn chờ / bàn của lớp cũ
  PERFORM public._qrt_cfg('ip_per_min', '1000');
  PERFORM public._qrt_cfg('ip_pending', '2');
  PERFORM public._qrt_as('anon');
  PERFORM public._qrt_hdr('198.51.100.5');
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-pend-0001aa', NULL);
  ASSERT (v_r->>'success')::boolean, 'T3 đơn 1: ' || v_r::text;
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-pend-0002aa', NULL);
  ASSERT (v_r->>'success')::boolean, 'T3 đơn 2: ' || v_r::text;
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-pend-0003aa', NULL);
  ASSERT v_r->>'error_code' = 'RATE_LIMITED', 'T3 đơn 3 phải RATE_LIMITED: ' || v_r::text;
  -- retry đúng khoá cũ vẫn trả đơn cũ (idempotency không bị lớp mới chặn)
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-pend-0001aa', NULL);
  ASSERT (v_r->>'success')::boolean AND (v_r->'data'->>'is_replay')::boolean, 'T3 replay vẫn được: ' || v_r::text;
  PERFORM public._qrt_as('reset');
  PERFORM public._qrt_cfg('ip_pending', '1000');

  -- ── T4: tự khoá khi quá ngưỡng trong 1 phút ───────────────────────────────
  UPDATE public.qr_requests SET status = 'expired' WHERE store_id = v_store;
  DELETE FROM public.qr_submit_attempts;
  PERFORM public._qrt_cfg('flood_per_min', '5');
  PERFORM public._qrt_as('anon');
  PERFORM public._qrt_hdr(NULL);
  FOR i IN 1..4 LOOP
    v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-flood-' || lpad(i::text, 4, '0') || 'aa', NULL);
    ASSERT (v_r->>'success')::boolean OR v_r->>'error_code' = 'RATE_LIMITED', 'T4 lượt ' || i || ': ' || v_r::text;
  END LOOP;
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-flood-0005aaaa', NULL);
  ASSERT v_r->>'error_code' = 'CHANNEL_LOCKED', 'T4 lượt 5 phải khoá kênh: ' || v_r::text;
  PERFORM public._qrt_as('reset');
  ASSERT (SELECT NOT is_active AND locked_at IS NOT NULL AND locked_reason = 'flood'
            FROM public.qr_channels WHERE channel_code = v_code), 'T4 kênh phải bị khoá';
  ASSERT EXISTS (SELECT 1 FROM public.qr_audit_logs WHERE store_id = v_store AND action = 'channel_locked_flood'), 'T4 phải ghi audit';
  -- khách vào trang khi đã khoá
  PERFORM public._qrt_as('anon');
  v_r := public.get_qr_channel_info_v4(v_code);
  ASSERT v_r->>'error_code' = 'CHANNEL_LOCKED', 'T4 info phải CHANNEL_LOCKED: ' || v_r::text;
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-flood-0006aaaa', NULL);
  ASSERT v_r->>'error_code' = 'CHANNEL_LOCKED', 'T4 gửi tiếp vẫn CHANNEL_LOCKED: ' || v_r::text;

  -- ── T5: không bật lại bằng mã cũ; phải xoay mã mới ────────────────────────
  PERFORM public._qrt_as('authenticated', v_owner);
  v_r := public.manage_qr_channel_v4(v_store, 'TABLE_SHARED', true, 'CASHIER_CONFIRM');
  ASSERT v_r->>'error_code' = 'LOCKED_NEEDS_NEW_CODE', 'T5 bật lại mã cũ phải bị chặn: ' || v_r::text;
  PERFORM public._qrt_as('authenticated', v_waiter);
  v_r := public.rotate_qr_channel_v4(v_store, 'TABLE_SHARED');
  ASSERT NOT (v_r->>'success')::boolean, 'T5 phục vụ không được xoay mã: ' || v_r::text;
  PERFORM public._qrt_as('authenticated', v_owner);
  v_old_code := v_code;
  v_r := public.rotate_qr_channel_v4(v_store, 'TABLE_SHARED');
  ASSERT (v_r->>'success')::boolean, 'T5 chủ xoay mã: ' || v_r::text;
  v_code := v_r->'data'->>'channel_code';
  ASSERT v_code <> v_old_code AND v_code LIKE 'TBL\_%', 'T5 mã mới khác mã cũ';
  ASSERT (v_r->'data'->>'is_active')::boolean AND (v_r->'data'->>'locked_at') IS NULL, 'T5 kênh mở khoá';
  PERFORM public._qrt_as('anon');
  v_r := public.submit_qr_order_v4(v_old_code, v_items, v_tbl, 'cp-key-oldcode-001aa', NULL);
  ASSERT NOT (v_r->>'success')::boolean, 'T5 mã cũ phải vô hiệu: ' || v_r::text;
  PERFORM public._qrt_as('reset');
  PERFORM public._qrt_cfg('flood_per_min', '1000');
  PERFORM public._qrt_as('anon');
  PERFORM public._qrt_hdr(NULL);
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-newcode-001aa', NULL);
  ASSERT (v_r->>'success')::boolean, 'T5 mã mới gửi được: ' || v_r::text;
  PERFORM public._qrt_as('reset');
  ASSERT (SELECT count(*) FROM public.qr_requests WHERE status = 'submitted' AND channel_id =
            (SELECT id FROM public.qr_channels WHERE channel_code = v_code)) = 1,
         'T5 chỉ còn đơn mới trong hàng chờ (đơn cũ đã hết hạn)';

  -- ── T6: vé xác minh người thật ────────────────────────────────────────────
  UPDATE public.qr_requests SET status = 'expired' WHERE store_id = v_store;
  PERFORM public._qrt_cfg('require_ticket', 'true');
  PERFORM public._qrt_cfg('turnstile_site_key', '1x00000000000000000000AA');
  PERFORM public._qrt_as('anon');
  v_r := public.get_qr_channel_info_v4(v_code);
  ASSERT (v_r->'data'->>'require_ticket')::boolean AND v_r->'data'->>'turnstile_site_key' = '1x00000000000000000000AA',
         'T6 info trả require_ticket + site key: ' || v_r::text;
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-tk-0001aaaaa', NULL, NULL);
  ASSERT v_r->>'error_code' = 'TICKET_INVALID', 'T6 thiếu vé: ' || v_r::text;
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-tk-0001aaaaa', NULL, 'rac');
  ASSERT v_r->>'error_code' = 'TICKET_INVALID', 'T6 vé rác: ' || v_r::text;
  PERFORM public._qrt_as('reset');
  v_exp := extract(epoch FROM now())::bigint + 300;
  PERFORM public._qrt_as('anon');
  -- vé cho khoá khác không dùng được cho khoá này
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-tk-0001aaaaa', NULL,
           (SELECT public._qrt_ticket(v_code, 'khoa-khac-hoan-toan', v_exp)));
  ASSERT v_r->>'error_code' = 'TICKET_INVALID', 'T6 vé sai khoá: ' || v_r::text;
  -- vé hết hạn
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-tk-0001aaaaa', NULL,
           (SELECT public._qrt_ticket(v_code, 'cp-key-tk-0001aaaaa', extract(epoch FROM now())::bigint - 10)));
  ASSERT v_r->>'error_code' = 'TICKET_INVALID', 'T6 vé hết hạn: ' || v_r::text;
  -- vé hạn quá xa (giả mạo hạn dài)
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-tk-0001aaaaa', NULL,
           (SELECT public._qrt_ticket(v_code, 'cp-key-tk-0001aaaaa', extract(epoch FROM now())::bigint + 99999)));
  ASSERT v_r->>'error_code' = 'TICKET_INVALID', 'T6 vé hạn quá dài: ' || v_r::text;
  -- vé đúng
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-tk-0001aaaaa', NULL,
           (SELECT public._qrt_ticket(v_code, 'cp-key-tk-0001aaaaa', v_exp)));
  ASSERT (v_r->>'success')::boolean, 'T6 vé đúng phải qua: ' || v_r::text;
  -- retry đúng khoá không cần vé nữa (đơn đã tạo)
  v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-tk-0001aaaaa', NULL, NULL);
  ASSERT (v_r->>'success')::boolean AND (v_r->'data'->>'is_replay')::boolean, 'T6 replay không cần vé: ' || v_r::text;
  PERFORM public._qrt_as('reset');
  -- lượt bị từ chối vì thiếu vé KHÔNG tính vào ngưỡng khoá (tránh bot không vé khoá kênh của khách thật)
  DELETE FROM public.qr_submit_attempts;
  PERFORM public._qrt_cfg('flood_per_min', '3');
  PERFORM public._qrt_as('anon');
  FOR i IN 1..10 LOOP
    v_r := public.submit_qr_order_v4(v_code, v_items, v_tbl, 'cp-key-nt-' || lpad(i::text, 4, '0') || 'aaaaa', NULL, NULL);
    ASSERT v_r->>'error_code' = 'TICKET_INVALID', 'T6 không vé #' || i || ': ' || v_r::text;
  END LOOP;
  PERFORM public._qrt_as('reset');
  ASSERT (SELECT is_active AND locked_at IS NULL FROM public.qr_channels WHERE channel_code = v_code),
         'T6 bot không vé không được làm khoá kênh';
  PERFORM public._qrt_cfg('require_ticket', 'false');

  -- ── T7: quyền truy cập ────────────────────────────────────────────────────
  PERFORM public._qrt_as('anon');
  BEGIN
    PERFORM 1 FROM public.qr_security_config LIMIT 1;
    ASSERT false, 'T7 anon KHÔNG được đọc qr_security_config';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM 1 FROM public.qr_submit_attempts LIMIT 1;
    ASSERT false, 'T7 anon KHÔNG được đọc qr_submit_attempts';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.qr_cfg_v4('ticket_secret');
    ASSERT false, 'T7 anon KHÔNG được gọi qr_cfg_v4';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.rotate_qr_channel_v4(v_store, 'TABLE_SHARED');
    ASSERT false, 'T7 anon KHÔNG được xoay mã';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM public._qrt_as('authenticated', v_waiter);
  BEGIN
    PERFORM 1 FROM public.qr_security_config LIMIT 1;
    ASSERT false, 'T7 nhân viên KHÔNG được đọc qr_security_config';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM public._qrt_as('reset');
  ASSERT has_function_privilege('anon', 'public.submit_qr_order_v4(text,jsonb,text,text,text,text)', 'EXECUTE'), 'T7 anon gọi được submit (6 tham số)';
  ASSERT NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'submit_qr_order_v4' AND pronargs = 5), 'T7 hàm 5 tham số cũ đã bị bỏ';

  RAISE NOTICE '✅ QR CHỐNG PHÁ: TẤT CẢ ĐẠT';
END
$test$;

ROLLBACK;
