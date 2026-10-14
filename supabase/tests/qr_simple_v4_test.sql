-- ============================================================================
-- TEST: QR Gọi Món đơn giản hóa (20261013_qr_order_simple_v4.sql)
--
-- CHỈ CHẠY TRÊN DB STAGING/DISPOSABLE đã áp: V5 prerequisites + settlement V5 + fix09 +
-- send_kitchen_ticket_v2 + 20261013_qr_order_simple_v4.sql. KHÔNG chạy trên production.
-- Toàn bộ nằm trong một transaction và kết thúc bằng ROLLBACK (không để lại dữ liệu).
--
-- Chạy:  psql "$STAGING_URL" -v ON_ERROR_STOP=1 -f supabase/tests/qr_simple_v4_test.sql
--
-- Phụ thuộc fixture (chỉnh nếu schema staging khác):
--   stores(id,name,created_at); user_accounts(id,phone,display_name);
--   store_members(id,store_id,user_id,role,created_at); ban_zones(id,store_id,name);
--   ban_dining_tables(id text,store_id,zone_id,<name|label>,is_active);
--   products(id,store_id,name,category,sell_price,cost_price_latest,stock_qty,is_topping,is_active,is_deleted);
--   app_settings(id,store_id,key,value); product_topping_links(product_id,topping_id).
--
-- "Đua nhận đơn": trong 1 transaction chỉ mô phỏng tuần tự (kiểm ALREADY_CLAIMED). Để đua thật,
-- chạy 2 phiên psql song song trên cùng request đã submit và gọi claim_qr_request_v4 cùng lúc
-- với 2 user khác nhau: đúng 1 phiên success, phiên kia ALREADY_CLAIMED (hàng bị FOR UPDATE).
-- ============================================================================

BEGIN;

-- Helper test: chuyển vai (anon / authenticated + user / reset về superuser)
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

-- Đọc tồn kho bỏ qua RLS (trên production, chính sách products chặn vai authenticated trong test).
CREATE OR REPLACE FUNCTION public._qrt_stock(p_id uuid)
RETURNS numeric LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS
$f$ SELECT stock_qty FROM public.products WHERE id = p_id $f$;

DO $test$
DECLARE
  v_store_a uuid := gen_random_uuid();
  v_store_b uuid := gen_random_uuid();
  v_owner_a uuid := gen_random_uuid();
  v_waiter_a uuid := gen_random_uuid();
  v_cashier_a uuid := gen_random_uuid();
  v_owner_b uuid := gen_random_uuid();
  v_zone uuid := gen_random_uuid();
  v_tbl_a1 text := gen_random_uuid()::text;
  v_tbl_a2 text := gen_random_uuid()::text;
  v_tbl_b1 text := gen_random_uuid()::text;
  v_food uuid := gen_random_uuid();
  v_drink uuid := gen_random_uuid();
  v_top uuid := gen_random_uuid();
  v_has_name boolean;
  v_namecol text;

  v_tcode text;
  v_ccode text;
  v_r jsonb;
  v_r2 jsonb;
  v_items jsonb;
  v_t1 uuid; v_t1_tok text; v_t1_ver int;
  v_t2 uuid; v_t3 uuid; v_t4 uuid;
  v_c1 uuid; v_c2 uuid; v_c3 uuid; v_c4 uuid; v_c1_ver int; v_c3_ver int;
  v_c3_orig jsonb;
  v_sess1 uuid; v_sess2 uuid;
  v_order uuid; v_ticket uuid;
  v_n int;
  v_stock_before numeric; v_stock_after numeric;
  v_tbl_hash_before text; v_tbl_hash_after text;
  v_found_rl boolean := false;
  i int;
BEGIN
  RAISE NOTICE '>>> QR SIMPLE V4: BẮT ĐẦU <<<';

  -- ── FIXTURES (superuser) ─────────────────────────────────────────────────
  PERFORM public._qrt_as('reset');
  INSERT INTO public.stores (id, store_code, name, created_at) VALUES
    (v_store_a, 'QRTA-' || substr(v_store_a::text, 1, 8), 'QR Test A', now()),
    (v_store_b, 'QRTB-' || substr(v_store_b::text, 1, 8), 'QR Test B', now());
  INSERT INTO public.user_accounts (id, phone, display_name, password_hash) VALUES
    (v_owner_a, '0900000101', 'Owner A', 'x'), (v_waiter_a, '0900000102', 'Waiter A', 'x'),
    (v_cashier_a, '0900000103', 'Cashier A', 'x'), (v_owner_b, '0900000104', 'Owner B', 'x');
  INSERT INTO public.store_members (id, store_id, user_id, role, created_at) VALUES
    (gen_random_uuid(), v_store_a, v_owner_a, 'owner', now()),
    (gen_random_uuid(), v_store_a, v_waiter_a, 'waiter', now()),
    (gen_random_uuid(), v_store_a, v_cashier_a, 'cashier', now()),
    (gen_random_uuid(), v_store_b, v_owner_b, 'owner', now());
  -- Có cấu hình thu ngân ở quán A: phục vụ vẫn KHÔNG được thu tiền (chặn fallback action_perms_cashier)
  INSERT INTO public.app_settings (id, store_id, key, value)
  VALUES (gen_random_uuid(), v_store_a, 'action_perms_cashier', '["pos.checkout"]');

  INSERT INTO public.ban_zones (id, store_id, name) VALUES (v_zone, v_store_a, 'Tầng 1');
  SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='name')
    INTO v_has_name;
  v_namecol := CASE WHEN v_has_name THEN 'name' ELSE 'label' END;
  EXECUTE format('INSERT INTO public.ban_dining_tables (id, store_id, zone_id, %I, is_active) VALUES ($1,$2,$3,$4,true)', v_namecol)
    USING v_tbl_a1, v_store_a, v_zone, 'Bàn A1';
  EXECUTE format('INSERT INTO public.ban_dining_tables (id, store_id, zone_id, %I, is_active) VALUES ($1,$2,$3,$4,true)', v_namecol)
    USING v_tbl_a2, v_store_a, v_zone, 'Bàn A2';
  EXECUTE format('INSERT INTO public.ban_dining_tables (id, store_id, zone_id, %I, is_active) VALUES ($1,$2,$3,$4,true)', v_namecol)
    USING v_tbl_b1, v_store_b, v_zone, 'Bàn B1';

  INSERT INTO public.products (id, store_id, name, category, sell_price, cost_price_latest, stock_qty, is_topping, is_active, is_deleted) VALUES
    (v_food,  v_store_a, 'Cơm Chiên', 'Món Chính', 65000, 30000, 50, false, true, false),
    (v_drink, v_store_a, 'Trà Sữa',   'Đồ uống',   35000, 12000, 100, false, true, false),
    (v_top,   v_store_a, 'Trân Châu', 'Topping',   10000, 3000, 200, true, true, false);
  INSERT INTO public.product_topping_links (product_id, topping_id) VALUES (v_drink, v_top);

  -- ── T0: QUYỀN HÀM / BẢNG ────────────────────────────────────────────────
  ASSERT has_function_privilege('anon', 'public.get_qr_channel_info_v4(text)', 'EXECUTE'), 'anon phải gọi được channel_info';
  ASSERT has_function_privilege('anon', 'public.get_qr_menu_v4(text)', 'EXECUTE'), 'anon phải gọi được menu';
  ASSERT has_function_privilege('anon', 'public.submit_qr_order_v4(text,jsonb,text,text,text,text)', 'EXECUTE'), 'anon phải gọi được submit';
  ASSERT has_function_privilege('anon', 'public.get_qr_request_status_v4(text)', 'EXECUTE'), 'anon phải gọi được status';
  ASSERT NOT has_function_privilege('anon', 'public.claim_qr_request_v4(uuid,uuid)', 'EXECUTE'), 'anon KHÔNG được claim';
  ASSERT NOT has_function_privilege('anon', 'public.get_qr_request_detail_v4(uuid,uuid)', 'EXECUTE'), 'anon KHÔNG được detail';
  ASSERT NOT has_function_privilege('anon', 'public.update_qr_order_items_v4(uuid,uuid,integer,jsonb)', 'EXECUTE'), 'anon KHÔNG được update_items';
  ASSERT NOT has_function_privilege('anon', 'public.set_qr_order_table_v4(uuid,uuid,text)', 'EXECUTE'), 'anon KHÔNG được set_table';
  ASSERT NOT has_function_privilege('anon', 'public.approve_and_send_table_v4(uuid,uuid,integer)', 'EXECUTE'), 'anon KHÔNG được approve';
  ASSERT NOT has_function_privilege('anon', 'public.pay_and_send_counter_v4(uuid,uuid,integer,text)', 'EXECUTE'), 'anon KHÔNG được pay';
  ASSERT NOT has_function_privilege('anon', 'public.cancel_qr_order_v4(uuid,uuid,text)', 'EXECUTE'), 'anon KHÔNG được cancel';
  ASSERT NOT has_function_privilege('anon', 'public.manage_qr_channel_v4(uuid,text,boolean,text)', 'EXECUTE'), 'anon KHÔNG được manage';
  ASSERT NOT has_function_privilege('anon', 'public.qr_staff_ctx_v4(uuid,boolean,boolean)', 'EXECUTE'), 'anon KHÔNG được hàm nội bộ ctx';
  ASSERT NOT has_function_privilege('authenticated', 'public.qr_staff_ctx_v4(uuid,boolean,boolean)', 'EXECUTE'), 'authenticated KHÔNG được hàm nội bộ ctx';
  ASSERT NOT has_function_privilege('authenticated', 'public.qr_deduct_stock_v4(uuid,uuid,text,uuid,numeric,text)', 'EXECUTE'), 'authenticated KHÔNG được qr_deduct_stock';
  ASSERT NOT has_table_privilege('anon', 'public.qr_requests', 'SELECT'), 'anon KHÔNG đọc qr_requests';
  ASSERT NOT has_table_privilege('anon', 'public.qr_request_items', 'SELECT'), 'anon KHÔNG đọc qr_request_items';
  ASSERT NOT has_table_privilege('anon', 'public.qr_channels', 'SELECT'), 'anon KHÔNG đọc qr_channels';
  ASSERT NOT has_table_privilege('authenticated', 'public.qr_requests', 'INSERT'), 'authenticated KHÔNG ghi trực tiếp qr_requests';
  ASSERT (SELECT bool_and(relrowsecurity) FROM pg_class WHERE oid IN
          ('public.qr_channels'::regclass, 'public.qr_requests'::regclass,
           'public.qr_request_items'::regclass, 'public.qr_pickup_counters'::regclass)), 'RLS phải bật cho bảng QR';
  RAISE NOTICE 'T0 quyền: OK';

  -- ── T1: KÊNH (owner / thiếu quyền / quán khác) ─────────────────────────
  PERFORM public._qrt_as('authenticated', v_waiter_a);
  v_r := public.manage_qr_channel_v4(v_store_a, 'TABLE_SHARED', true, 'CASHIER_CONFIRM');
  ASSERT (v_r->>'success')::boolean = false AND v_r->>'error_code' = 'PERMISSION_DENIED', 'phục vụ không quản kênh: ' || v_r::text;
  PERFORM public._qrt_as('authenticated', v_owner_b);
  v_r := public.manage_qr_channel_v4(v_store_a, 'TABLE_SHARED', true, 'CASHIER_CONFIRM');
  ASSERT (v_r->>'success')::boolean = false AND v_r->>'error_code' = 'PERMISSION_DENIED', 'owner quán B không quản kênh quán A: ' || v_r::text;

  PERFORM public._qrt_as('authenticated', v_owner_a);
  v_r := public.manage_qr_channel_v4(v_store_a, 'TABLE_SHARED', true, 'CASHIER_CONFIRM');
  ASSERT (v_r->>'success')::boolean, 'owner tạo kênh bàn: ' || v_r::text;
  v_tcode := v_r->'data'->>'channel_code';
  v_r := public.manage_qr_channel_v4(v_store_a, 'COUNTER_TAKEAWAY', true, 'CASHIER_CONFIRM');
  ASSERT (v_r->>'success')::boolean, 'owner tạo kênh quầy: ' || v_r::text;
  v_ccode := v_r->'data'->>'channel_code';
  v_r := public.manage_qr_channel_v4(v_store_a, 'TABLE_SHARED', true, 'CASHIER_CONFIRM');
  ASSERT v_r->'data'->>'channel_code' = v_tcode, 'gọi lại manage không đổi mã / không vỡ unique';
  PERFORM public._qrt_as('reset');
  ASSERT (SELECT count(*) FROM public.qr_channels WHERE store_id = v_store_a) = 2, 'mỗi quán đúng 1 kênh mỗi loại';
  RAISE NOTICE 'T1 kênh: OK';

  -- ── T2: ANON — info / menu / đọc trực tiếp ─────────────────────────────
  PERFORM public._qrt_as('anon');
  v_r := public.get_qr_channel_info_v4(v_tcode);
  ASSERT (v_r->>'success')::boolean AND v_r->'data'->>'type' = 'TABLE_SHARED', 'channel_info: ' || v_r::text;
  v_r := public.get_qr_menu_v4(v_tcode);
  ASSERT (v_r->>'success')::boolean, 'menu: ' || v_r::text;
  ASSERT v_r->'data'->>'channel_type' = 'TABLE_SHARED', 'menu có channel_type';
  ASSERT jsonb_array_length(v_r->'data'->'tables') = 2, 'menu bàn: đúng 2 bàn của quán A: ' || (v_r->'data'->'tables')::text;
  ASSERT NOT (v_r->'data'->'tables')::text LIKE '%' || v_tbl_b1 || '%', 'không lộ bàn quán khác';
  v_r := public.get_qr_menu_v4(v_ccode);
  ASSERT jsonb_array_length(v_r->'data'->'tables') = 0, 'COUNTER trả mảng bàn rỗng';
  v_r := public.get_qr_channel_info_v4('KHONG_TON_TAI');
  ASSERT v_r->>'error_code' = 'CHANNEL_DISABLED', 'kênh không tồn tại';

  BEGIN
    PERFORM count(*) FROM public.qr_requests;
    ASSERT false, 'anon đọc được qr_requests trực tiếp!';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM public.claim_qr_request_v4(gen_random_uuid(), v_store_a);
    ASSERT false, 'anon gọi được claim!';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RAISE NOTICE 'T2 anon info/menu/đọc trực tiếp: OK';

  -- ── T3: SUBMIT (bàn bắt buộc, chéo quán, payload xấu, giá server, idempotency) ──
  v_items := jsonb_build_array(jsonb_build_object('product_id', v_food, 'quantity', 2, 'unit_price', 1, 'note', 'it cay'));

  v_r := public.submit_qr_order_v4(v_tcode, v_items, NULL, 'key-no-table-0001', NULL);
  ASSERT v_r->>'error_code' = 'TABLE_REQUIRED', 'thiếu bàn: ' || v_r::text;
  v_r := public.submit_qr_order_v4(v_tcode, v_items, v_tbl_b1, 'key-other-store-01', NULL);
  ASSERT v_r->>'error_code' = 'TABLE_NOT_FOUND', 'bàn thuộc quán khác bị chặn: ' || v_r::text;
  v_r := public.submit_qr_order_v4(v_tcode, v_items, 'khong-co-ban-nay', 'key-bad-table-001', NULL);
  ASSERT v_r->>'error_code' = 'TABLE_NOT_FOUND', 'bàn không tồn tại: ' || v_r::text;
  v_r := public.submit_qr_order_v4(v_tcode, jsonb_build_array(jsonb_build_object('product_id', 'not-a-uuid', 'quantity', 1)),
                                   v_tbl_a1, 'key-bad-uuid-0001', NULL);
  ASSERT v_r->>'error_code' = 'INVALID_PAYLOAD', 'uuid xấu trả lỗi chuẩn, không văng exception: ' || v_r::text;
  v_r := public.submit_qr_order_v4(v_tcode, jsonb_build_array(jsonb_build_object('product_id', v_food, 'quantity', 'abc')),
                                   v_tbl_a1, 'key-bad-qty-00001', NULL);
  ASSERT v_r->>'error_code' = 'INVALID_PAYLOAD', 'số lượng xấu: ' || v_r::text;
  v_r := public.submit_qr_order_v4(v_tcode, jsonb_build_array(jsonb_build_object('product_id', v_food, 'quantity', 1, 'note', repeat('x', 301))),
                                   v_tbl_a1, 'key-long-note-001', NULL);
  ASSERT v_r->>'error_code' = 'INVALID_PAYLOAD', 'ghi chú > 300 ký tự: ' || v_r::text;
  v_r := public.submit_qr_order_v4(v_tcode,
           (SELECT jsonb_agg(jsonb_build_object('product_id', v_food, 'quantity', 1)) FROM generate_series(1, 51)),
           v_tbl_a1, 'key-too-many-01', NULL);
  ASSERT v_r->>'error_code' = 'INVALID_PAYLOAD', '> 50 dòng: ' || v_r::text;
  v_r := public.submit_qr_order_v4(v_tcode, v_items, v_tbl_a1, 'short', NULL);
  ASSERT v_r->>'error_code' = 'INVALID_PAYLOAD', 'idempotency key quá ngắn';
  v_r := public.submit_qr_order_v4(v_tcode, '[]'::jsonb, v_tbl_a1, 'key-empty-items-1', NULL);
  ASSERT v_r->>'error_code' = 'INVALID_PAYLOAD', 'giỏ rỗng';

  v_r := public.submit_qr_order_v4(v_tcode, v_items, v_tbl_a1, 'key-t1-aaaaaaaa', repeat('a', 64));
  ASSERT (v_r->>'success')::boolean, 'submit hợp lệ: ' || v_r::text;
  ASSERT (v_r->'data'->>'total_amount')::numeric = 130000, 'giá do server tính (65000 x 2), bỏ qua unit_price client';
  ASSERT v_r->'data'->>'table_name' IS NOT NULL AND v_r->'data'->>'pickup_code' IS NULL, 'TABLE có table_name, không pickup_code';
  v_t1 := (v_r->'data'->>'request_id')::uuid;
  v_t1_tok := v_r->'data'->>'tracking_token';

  v_r2 := public.submit_qr_order_v4(v_tcode, v_items, v_tbl_a1, 'key-t1-aaaaaaaa', repeat('a', 64));
  ASSERT (v_r2->'data'->>'request_id')::uuid = v_t1 AND (v_r2->'data'->>'is_replay')::boolean, 'cùng key trả đơn cũ';
  v_r2 := public.submit_qr_order_v4(v_tcode, v_items, v_tbl_a1, 'key-t1-aaaaaaaa', repeat('b', 64));
  ASSERT v_r2->>'error_code' = 'IDEMPOTENCY_CONFLICT', 'cùng key khác nội dung';

  -- topping: đúng liên kết tính giá; topping không gắn với món -> PRODUCT_NOT_AVAILABLE
  v_r := public.submit_qr_order_v4(v_tcode,
           jsonb_build_array(jsonb_build_object('product_id', v_drink, 'quantity', 1,
             'modifiers_json', jsonb_build_array(jsonb_build_object('id', v_top, 'quantity', 2)))),
           v_tbl_a2, 'key-topping-0001', NULL);
  ASSERT (v_r->>'success')::boolean AND (v_r->'data'->>'total_amount')::numeric = 55000, 'giá có topping: ' || v_r::text;
  v_t3 := (v_r->'data'->>'request_id')::uuid;
  v_r := public.submit_qr_order_v4(v_tcode,
           jsonb_build_array(jsonb_build_object('product_id', v_food, 'quantity', 1,
             'modifiers_json', jsonb_build_array(jsonb_build_object('id', v_top, 'quantity', 1)))),
           v_tbl_a2, 'key-topping-0002', NULL);
  ASSERT v_r->>'error_code' = 'PRODUCT_NOT_AVAILABLE', 'topping không gắn với món: ' || v_r::text;

  -- status công khai theo token
  v_r := public.get_qr_request_status_v4(v_t1_tok);
  ASSERT (v_r->>'success')::boolean AND v_r->'data'->>'status' = 'submitted'
         AND v_r->'data'->>'payment_status' = 'unpaid' AND v_r->'data'->>'table_name' IS NOT NULL, 'status: ' || v_r::text;
  v_r := public.get_qr_request_status_v4('TRK_KHONG_CO');
  ASSERT (v_r->>'success')::boolean = false, 'token lạ';

  -- COUNTER bỏ qua p_table_id; pickup code
  v_r := public.submit_qr_order_v4(v_ccode, v_items, v_tbl_b1, 'key-c1-aaaaaaaa', NULL);
  ASSERT (v_r->>'success')::boolean AND v_r->'data'->>'table_id' IS NULL AND v_r->'data'->>'pickup_code' = '#Q01', 'COUNTER #Q01 bỏ qua bàn: ' || v_r::text;
  v_c1 := (v_r->'data'->>'request_id')::uuid;
  v_r := public.submit_qr_order_v4(v_ccode, v_items, NULL, 'key-c2-aaaaaaaa', NULL);
  ASSERT v_r->'data'->>'pickup_code' = '#Q02', 'COUNTER #Q02: ' || v_r::text;
  v_c2 := (v_r->'data'->>'request_id')::uuid;
  RAISE NOTICE 'T3 submit: OK';

  -- ── T4: PICKUP CODE THEO NGÀY (+ vượt 99) ────────────────────────────────
  PERFORM public._qrt_as('reset');
  UPDATE public.qr_requests SET pickup_date = pickup_date - 1 WHERE id IN (v_c1, v_c2);
  UPDATE public.qr_pickup_counters SET pickup_date = pickup_date - 1 WHERE store_id = v_store_a;
  PERFORM public._qrt_as('anon');
  v_r := public.submit_qr_order_v4(v_ccode, v_items, NULL, 'key-c3-aaaaaaaa', NULL);
  ASSERT v_r->'data'->>'pickup_code' = '#Q01', 'sang ngày mới đếm lại #Q01, không vi phạm UNIQUE: ' || v_r::text;
  v_c3 := (v_r->'data'->>'request_id')::uuid;
  PERFORM public._qrt_as('reset');
  UPDATE public.qr_pickup_counters SET last_seq = 99 WHERE store_id = v_store_a AND pickup_date = (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
  PERFORM public._qrt_as('anon');
  v_r := public.submit_qr_order_v4(v_ccode, v_items, NULL, 'key-c4-aaaaaaaa', NULL);
  ASSERT v_r->'data'->>'pickup_code' = '#Q100', 'không giới hạn 99: ' || v_r::text;
  v_c4 := (v_r->'data'->>'request_id')::uuid;
  RAISE NOTICE 'T4 pickup theo ngày: OK';

  -- ── T5: CLAIM (chéo quán, đua nhận, idempotent) ─────────────────────────
  PERFORM public._qrt_as('authenticated', v_owner_b);
  v_r := public.claim_qr_request_v4(v_t1, v_store_b);
  ASSERT (v_r->>'success')::boolean = false AND v_r->>'error_code' = 'INVALID_STATE', 'đơn quán A không thấy từ quán B: ' || v_r::text;
  v_r := public.claim_qr_request_v4(v_t1, v_store_a);
  ASSERT (v_r->>'success')::boolean = false AND v_r->>'error_code' = 'PERMISSION_DENIED', 'nhân viên quán B không nhận đơn quán A: ' || v_r::text;
  v_r := public.get_qr_request_detail_v4(v_t1, v_store_a);
  ASSERT v_r->>'error_code' = 'PERMISSION_DENIED', 'detail chéo quán bị chặn';
  ASSERT (SELECT count(*) FROM public.qr_requests WHERE store_id = v_store_a) = 0, 'RLS: quán B không đọc được hàng chờ quán A';

  PERFORM public._qrt_as('authenticated', v_waiter_a);
  ASSERT (SELECT count(*) FROM public.qr_requests WHERE store_id = v_store_a) > 0, 'RLS: nhân viên quán A đọc được hàng chờ';
  v_r := public.claim_qr_request_v4(v_t1, v_store_a);
  ASSERT (v_r->>'success')::boolean AND v_r->'data'->>'status' = 'claimed' AND (v_r->'data'->>'claimed_by')::uuid = v_waiter_a, 'waiter nhận: ' || v_r::text;
  v_t1_ver := (v_r->'data'->>'version')::int;
  PERFORM public._qrt_as('authenticated', v_cashier_a);
  v_r := public.claim_qr_request_v4(v_t1, v_store_a);
  ASSERT v_r->>'error_code' = 'ALREADY_CLAIMED', 'người thứ hai nhận -> ALREADY_CLAIMED: ' || v_r::text;
  PERFORM public._qrt_as('authenticated', v_waiter_a);
  v_r := public.claim_qr_request_v4(v_t1, v_store_a);
  ASSERT (v_r->>'success')::boolean AND (v_r->'data'->>'version')::int = v_t1_ver, 'nhận lại bởi chính mình: idempotent, không tăng version';
  PERFORM public._qrt_as('reset');
  ASSERT (SELECT count(*) FROM public.qr_audit_logs WHERE request_id = v_t1 AND action = 'claim') = 1, 'claim chỉ ghi audit một lần';
  RAISE NOTICE 'T5 claim: OK';

  -- ── T6: APPROVE TABLE ────────────────────────────────────────────────────
  -- chưa nhận -> chặn
  PERFORM public._qrt_as('authenticated', v_cashier_a);
  v_r := public.approve_and_send_table_v4(v_t3, v_store_a, 1);
  ASSERT v_r->>'error_code' = 'INVALID_STATE', 'duyệt đơn chưa nhận bị chặn: ' || v_r::text;
  -- không phải người nhận (cashier không phải owner/manager)
  v_r := public.approve_and_send_table_v4(v_t1, v_store_a, v_t1_ver);
  ASSERT v_r->>'error_code' = 'NOT_CLAIMER', 'không phải người nhận: ' || v_r::text;
  -- pay không áp dụng cho đơn TABLE
  v_r := public.pay_and_send_counter_v4(v_t1, v_store_a, v_t1_ver, 'cash');
  ASSERT v_r->>'error_code' IN ('NOT_CLAIMER', 'INVALID_STATE'), 'pay trên đơn TABLE bị chặn: ' || v_r::text;

  PERFORM public._qrt_as('authenticated', v_waiter_a);
  v_r := public.approve_and_send_table_v4(v_t1, v_store_a, v_t1_ver + 5);
  ASSERT v_r->>'error_code' = 'VERSION_CONFLICT', 'sai version: ' || v_r::text;
  v_r := public.set_qr_order_table_v4(v_t1, v_store_a, v_tbl_b1);
  ASSERT v_r->>'error_code' = 'TABLE_NOT_FOUND', 'đổi sang bàn quán khác bị chặn: ' || v_r::text;
  -- ép dữ liệu xấu (bàn quán khác) bằng superuser rồi duyệt -> vẫn bị chặn
  PERFORM public._qrt_as('reset');
  UPDATE public.qr_requests SET table_id = v_tbl_b1 WHERE id = v_t1;
  PERFORM public._qrt_as('authenticated', v_waiter_a);
  v_r := public.approve_and_send_table_v4(v_t1, v_store_a, v_t1_ver);
  ASSERT v_r->>'error_code' = 'TABLE_NOT_FOUND', 'approve với bàn thuộc quán khác bị chặn: ' || v_r::text;
  PERFORM public._qrt_as('reset');
  UPDATE public.qr_requests SET table_id = v_tbl_a1 WHERE id = v_t1;
  ASSERT (SELECT count(*) FROM public.orders WHERE source_id = v_t1::text) = 0, 'các lần bị chặn không sinh order';

  v_stock_before := public._qrt_stock(v_food);
  SELECT md5(t::text) INTO v_tbl_hash_before FROM public.ban_dining_tables t WHERE t.id = v_tbl_a1;

  PERFORM public._qrt_as('authenticated', v_waiter_a);
  v_r := public.approve_and_send_table_v4(v_t1, v_store_a, v_t1_ver);
  ASSERT (v_r->>'success')::boolean AND v_r->'data'->>'status' = 'sent_kitchen', 'approve: ' || v_r::text;
  v_sess1 := (v_r->'data'->>'session_id')::uuid;
  v_order := (v_r->'data'->>'order_id')::uuid;
  v_ticket := (v_r->'data'->>'ticket_id')::uuid;
  -- gọi lại: kết quả cũ, không trùng
  v_r2 := public.approve_and_send_table_v4(v_t1, v_store_a, v_t1_ver);
  ASSERT (v_r2->>'success')::boolean AND (v_r2->'data'->>'is_replay')::boolean
         AND (v_r2->'data'->>'order_id')::uuid = v_order AND (v_r2->'data'->>'ticket_id')::uuid = v_ticket, 'approve gọi lại trả kết quả cũ: ' || v_r2::text;
  v_r2 := public.approve_and_send_table_v4(v_t1, v_store_a, 999);
  ASSERT (v_r2->>'success')::boolean AND (v_r2->'data'->>'is_replay')::boolean, 'gọi lại với version cũ vẫn idempotent';

  PERFORM public._qrt_as('reset');
  ASSERT (SELECT count(*) FROM public.orders WHERE source_id = v_t1::text) = 1, 'đúng 1 order';
  ASSERT (SELECT count(*) FROM public.ban_session_orders WHERE qr_request_id = v_t1) = 1, 'đúng 1 liên kết session-order';
  ASSERT (SELECT count(*) FROM public.kitchen_tickets WHERE id = v_ticket) = 1, 'đúng 1 vé bếp';
  ASSERT (SELECT count(*) FROM public.kitchen_tickets WHERE session_id = v_sess1) = 1, 'phiên chỉ có 1 vé bếp (không nhân đôi khi gọi lại)';
  ASSERT (SELECT count(*) FROM public.kitchen_ticket_items WHERE ticket_id = v_ticket) = 1, 'vé bếp có đúng 1 dòng món';
  ASSERT (SELECT count(*) FROM public.ban_session_items WHERE session_id = v_sess1) = 1, 'đúng 1 dòng ban_session_items';
  v_stock_after := public._qrt_stock(v_food);
  ASSERT v_stock_after = v_stock_before, 'TABLE không trừ kho ở approve (chỉ settle V5)';
  SELECT md5(t::text) INTO v_tbl_hash_after FROM public.ban_dining_tables t WHERE t.id = v_tbl_a1;
  ASSERT v_tbl_hash_after = v_tbl_hash_before, 'ban_dining_tables không bị UPDATE';
  ASSERT (SELECT count(*) FROM public.ban_sessions WHERE store_id = v_store_a AND status = 'open' AND table_id::text = v_tbl_a1) = 1, 'một phiên mở cho bàn';
  ASSERT (SELECT status FROM public.qr_requests WHERE id = v_t1) = 'sent_kitchen', 'trạng thái sent_kitchen';

  -- đơn thứ hai cùng bàn: dùng lại đúng phiên mở
  PERFORM public._qrt_as('anon');
  v_r := public.submit_qr_order_v4(v_tcode, v_items, v_tbl_a1, 'key-t2-aaaaaaaa', NULL);
  v_t2 := (v_r->'data'->>'request_id')::uuid;
  PERFORM public._qrt_as('authenticated', v_waiter_a);
  v_r := public.claim_qr_request_v4(v_t2, v_store_a);
  v_r := public.approve_and_send_table_v4(v_t2, v_store_a, (v_r->'data'->>'version')::int);
  ASSERT (v_r->>'success')::boolean, 'approve đơn 2: ' || v_r::text;
  v_sess2 := (v_r->'data'->>'session_id')::uuid;
  ASSERT v_sess2 = v_sess1, 'đơn thứ hai dùng lại phiên mở của bàn';
  PERFORM public._qrt_as('reset');
  ASSERT (SELECT count(*) FROM public.ban_sessions WHERE store_id = v_store_a AND status = 'open' AND table_id::text = v_tbl_a1) = 1, 'vẫn đúng 1 phiên mở';
  ASSERT (SELECT count(*) FROM public.kitchen_tickets WHERE session_id = v_sess1) = 2, 'phiên có 2 vé bếp (round 1, 2)';

  -- approve trên đơn COUNTER bị chặn
  PERFORM public._qrt_as('authenticated', v_cashier_a);
  v_r := public.claim_qr_request_v4(v_c3, v_store_a);
  v_c3_ver := (v_r->'data'->>'version')::int;
  v_c3_orig := v_r->'data'->'original_items';
  v_r := public.approve_and_send_table_v4(v_c3, v_store_a, v_c3_ver);
  ASSERT v_r->>'error_code' = 'INVALID_STATE', 'approve_table trên đơn COUNTER bị chặn: ' || v_r::text;
  RAISE NOTICE 'T6 approve table: OK';

  -- ── T7: COUNTER — thu tiền ───────────────────────────────────────────────
  -- (a) chưa claim -> chặn, không sinh order/finance
  PERFORM public._qrt_as('authenticated', v_cashier_a);
  v_r := public.pay_and_send_counter_v4(v_c4, v_store_a, 1, 'cash');
  ASSERT v_r->>'error_code' = 'INVALID_STATE', 'thu tiền khi chưa claim bị chặn: ' || v_r::text;
  PERFORM public._qrt_as('reset');
  ASSERT (SELECT count(*) FROM public.orders WHERE source_id = v_c4::text) = 0, 'không order khi chưa claim';
  ASSERT (SELECT count(*) FROM public.finance_records WHERE description LIKE '%#Q100%') = 0, 'không finance khi chưa claim';

  -- (b) phục vụ (không có quyền thu tiền) nhận đơn rồi thu -> PAYMENT_PERMISSION_DENIED
  PERFORM public._qrt_as('authenticated', v_waiter_a);
  v_r := public.claim_qr_request_v4(v_c2, v_store_a);
  ASSERT (v_r->>'success')::boolean, 'waiter nhận đơn quầy: ' || v_r::text;
  v_r := public.pay_and_send_counter_v4(v_c2, v_store_a, (v_r->'data'->>'version')::int, 'cash');
  ASSERT v_r->>'error_code' = 'PAYMENT_PERMISSION_DENIED', 'thiếu quyền thu tiền bị chặn ở server: ' || v_r::text;
  -- cashier không phải người nhận
  PERFORM public._qrt_as('authenticated', v_cashier_a);
  v_r := public.pay_and_send_counter_v4(v_c2, v_store_a, 2, 'cash');
  ASSERT v_r->>'error_code' = 'NOT_CLAIMER', 'thu tiền đơn người khác nhận bị chặn: ' || v_r::text;
  -- hủy bởi không phải người nhận -> chặn; owner hủy được
  PERFORM public._qrt_as('authenticated', v_cashier_a);
  v_r := public.cancel_qr_order_v4(v_c2, v_store_a, 'khách đổi ý');
  ASSERT v_r->>'error_code' = 'NOT_CLAIMER', 'hủy đơn người khác nhận bị chặn: ' || v_r::text;
  PERFORM public._qrt_as('authenticated', v_owner_a);
  v_r := public.cancel_qr_order_v4(v_c2, v_store_a, 'khách đổi ý');
  ASSERT (v_r->>'success')::boolean AND v_r->'data'->>'status' = 'cancelled', 'owner hủy: ' || v_r::text;
  v_r := public.pay_and_send_counter_v4(v_c2, v_store_a, 3, 'cash');
  ASSERT v_r->>'error_code' = 'INVALID_STATE', 'đơn đã hủy không thu tiền được: ' || v_r::text;

  -- (c) cashier nhận + sửa món (giữ snapshot) + thu tiền
  PERFORM public._qrt_as('authenticated', v_waiter_a);
  v_r := public.update_qr_order_items_v4(v_c3, v_store_a, v_c3_ver,
           jsonb_build_array(jsonb_build_object('product_id', v_food, 'quantity', 1)));
  ASSERT v_r->>'error_code' = 'NOT_CLAIMER', 'sửa món đơn người khác nhận bị chặn: ' || v_r::text;
  PERFORM public._qrt_as('authenticated', v_cashier_a);
  v_r := public.update_qr_order_items_v4(v_c3, v_store_a, v_c3_ver + 7,
           jsonb_build_array(jsonb_build_object('product_id', v_food, 'quantity', 1)));
  ASSERT v_r->>'error_code' = 'VERSION_CONFLICT', 'sửa món sai version';
  v_r := public.update_qr_order_items_v4(v_c3, v_store_a, v_c3_ver,
           jsonb_build_array(jsonb_build_object('product_id', v_food, 'quantity', 1)));
  ASSERT (v_r->>'success')::boolean AND (v_r->'data'->>'total_amount')::numeric = 65000, 'sửa món: ' || v_r::text;
  v_c1_ver := (v_r->'data'->>'version')::int;
  v_r := public.get_qr_request_detail_v4(v_c3, v_store_a);
  ASSERT v_r->'data'->'original_items' = v_c3_orig, 'snapshot món khách gửi không đổi';

  v_stock_before := public._qrt_stock(v_food);
  v_r := public.pay_and_send_counter_v4(v_c3, v_store_a, v_c1_ver, 'khong-hop-le');
  ASSERT v_r->>'error_code' = 'INVALID_PAYMENT_METHOD', 'phương thức lạ: ' || v_r::text;
  v_r := public.pay_and_send_counter_v4(v_c3, v_store_a, v_c1_ver + 3, 'cash');
  ASSERT v_r->>'error_code' = 'VERSION_CONFLICT', 'thu tiền sai version';
  v_r := public.pay_and_send_counter_v4(v_c3, v_store_a, v_c1_ver, 'cash');
  ASSERT (v_r->>'success')::boolean AND v_r->'data'->>'payment_status' = 'paid' AND v_r->'data'->>'status' = 'sent_kitchen', 'thu tiền & gửi bếp: ' || v_r::text;
  v_order := (v_r->'data'->>'order_id')::uuid;
  v_ticket := (v_r->'data'->>'ticket_id')::uuid;
  -- gọi lại: không trừ kho / không ghi finance / không vé bếp thêm
  v_r2 := public.pay_and_send_counter_v4(v_c3, v_store_a, v_c1_ver, 'cash');
  ASSERT (v_r2->>'success')::boolean AND (v_r2->'data'->>'is_replay')::boolean AND (v_r2->'data'->>'order_id')::uuid = v_order, 'pay gọi lại trả kết quả cũ: ' || v_r2::text;
  v_r2 := public.pay_and_send_counter_v4(v_c3, v_store_a, 12345, 'transfer');
  ASSERT (v_r2->>'success')::boolean AND (v_r2->'data'->>'is_replay')::boolean, 'pay gọi lại (version/phương thức khác) vẫn idempotent';

  PERFORM public._qrt_as('reset');
  v_stock_after := public._qrt_stock(v_food);
  ASSERT v_stock_before - v_stock_after = 1, 'COUNTER trừ kho đúng 1 lần (1 phần): trước=' || COALESCE(v_stock_before::text,'NULL') || ' sau=' || COALESCE(v_stock_after::text,'NULL');
  ASSERT (SELECT count(*) FROM public.orders WHERE source_id = v_c3::text AND status = 'completed') = 1, 'đúng 1 order completed';
  ASSERT (SELECT count(*) FROM public.finance_records WHERE reference_id::text = v_order::text) = 1, 'đúng 1 finance_records';
  ASSERT (SELECT amount FROM public.finance_records WHERE reference_id::text = v_order::text) = 65000, 'finance đúng số tiền';
  ASSERT (SELECT count(*) FROM public.kitchen_tickets WHERE id = v_ticket) = 1, 'đúng 1 vé bếp';
  ASSERT (SELECT count(*) FROM public.kitchen_ticket_items WHERE ticket_id = v_ticket) = 1, 'vé bếp đúng 1 dòng';
  ASSERT (SELECT payment_status FROM public.qr_requests WHERE id = v_c3) = 'paid', 'payment_status=paid';
  RAISE NOTICE 'T7 counter thu tiền: OK';

  -- ── T8: CANCEL / REJECT / ĐÃ VÀO BẾP ────────────────────────────────────
  PERFORM public._qrt_as('authenticated', v_waiter_a);
  v_r := public.cancel_qr_order_v4(v_t1, v_store_a, 'x');
  ASSERT v_r->>'error_code' = 'ALREADY_SENT', 'không hủy đơn đã vào bếp: ' || v_r::text;
  v_r := public.cancel_qr_order_v4(v_t3, v_store_a, 'khách không muốn');
  ASSERT (v_r->>'success')::boolean AND v_r->'data'->>'status' = 'rejected', 'submitted -> rejected: ' || v_r::text;
  v_r := public.cancel_qr_order_v4(v_t3, v_store_a, 'khách không muốn');
  ASSERT (v_r->>'success')::boolean AND (v_r->'data'->>'is_replay')::boolean, 'hủy lặp idempotent';
  v_r := public.claim_qr_request_v4(v_t3, v_store_a);
  ASSERT v_r->>'error_code' = 'INVALID_STATE', 'không nhận đơn đã từ chối: ' || v_r::text;
  RAISE NOTICE 'T8 hủy/từ chối: OK';

  -- ── T9: HẾT HẠN theo giờ server ────────────────────────────────────────
  PERFORM public._qrt_as('reset');
  UPDATE public.qr_requests SET expires_at = now() - interval '1 minute' WHERE id = v_c4;
  DECLARE v_tok text;
  BEGIN
    SELECT tracking_token INTO v_tok FROM public.qr_requests WHERE id = v_c4;
    PERFORM public._qrt_as('anon');
    v_r := public.get_qr_request_status_v4(v_tok);
    ASSERT v_r->'data'->>'status' = 'expired', 'submitted quá hạn được đánh expired khi đọc: ' || v_r::text;
  END;
  PERFORM public._qrt_as('authenticated', v_cashier_a);
  v_r := public.claim_qr_request_v4(v_c4, v_store_a);
  ASSERT v_r->>'error_code' IN ('REQUEST_EXPIRED', 'INVALID_STATE'), 'không nhận đơn hết hạn: ' || v_r::text;
  RAISE NOTICE 'T9 hết hạn: OK';

  -- ── T10: GIỚI HẠN TẦN SUẤT THEO KÊNH ────────────────────────────────────
  PERFORM public._qrt_as('anon');
  FOR i IN 1..40 LOOP
    v_r := public.submit_qr_order_v4(v_tcode, v_items, v_tbl_a2, 'key-rl-' || lpad(i::text, 6, '0') || '-xx', NULL);
    IF v_r->>'error_code' = 'RATE_LIMITED' THEN v_found_rl := true; EXIT; END IF;
  END LOOP;
  ASSERT v_found_rl, 'phải gặp RATE_LIMITED khi spam một kênh/bàn';
  RAISE NOTICE 'T10 rate limit: OK';

  -- ── T11: INDEX MỘT PHIÊN MỞ / BÀN (nếu migration tạo được) ─────────────
  PERFORM public._qrt_as('reset');
  IF to_regclass('public.uq_ban_sessions_one_open_per_table') IS NULL THEN
    RAISE NOTICE 'T11: uq_ban_sessions_one_open_per_table CHƯA có (DB có dữ liệu phiên trùng) — chỉ advisory lock bảo vệ';
  ELSE
    BEGIN
      INSERT INTO public.ban_sessions (id, store_id, table_id, status, opened_at, total_amount, guest_count)
      SELECT gen_random_uuid(), v_store_a, bs.table_id, 'open', now(), 0, 1
      FROM public.ban_sessions bs WHERE bs.id = v_sess1;
      ASSERT false, 'index một-phiên-mở không chặn phiên thứ hai';
    EXCEPTION WHEN unique_violation THEN NULL;
    END;
    RAISE NOTICE 'T11 unique phiên mở: OK';
  END IF;

  -- ── T12: BÀN HỆ THỐNG (id không phải uuid, vd 'sys-table-takeaway' của POS) ──
  PERFORM public._qrt_as('reset');
  INSERT INTO public.ban_zones (id, store_id, name) VALUES ('sys-zone-qrtest', v_store_a, 'POS');
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name, is_active)
  VALUES ('sys-table-qrtest', v_store_a, 'sys-zone-qrtest', 'Mang đi', true);
  PERFORM public._qrt_as('anon');
  v_r := public.get_qr_menu_v4(v_tcode);
  ASSERT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_r->'data'->'tables') e WHERE e->>'id' = 'sys-table-qrtest'),
    'bàn hệ thống không được hiện trong danh sách bàn cho khách chọn';
  v_r := public.submit_qr_order_v4(v_tcode, v_items, 'sys-table-qrtest', 'key-sys-aaaaaaaa', NULL);
  ASSERT (v_r->>'success')::boolean = false AND v_r->>'error_code' = 'TABLE_NOT_FOUND', 'chọn bàn hệ thống phải bị từ chối: ' || v_r::text;
  RAISE NOTICE 'T12 bàn hệ thống: OK';

  RAISE NOTICE '>>> QR SIMPLE V4: TẤT CẢ PASS <<<';
END
$test$;

RESET ROLE;
ROLLBACK;
