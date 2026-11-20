-- SQL Test Suite 4: Kitchen Dispatch, Per-Item Station Routing & Zero-Core-Row Unknown Station Tests
-- File: supabase/tests/qr_v3_kitchen_dispatch_test.sql

BEGIN;

DO $$
DECLARE
  v_store_id    uuid := gen_random_uuid();
  v_user_id     uuid := gen_random_uuid();
  v_dev_id      uuid := gen_random_uuid();
  v_zone_id     uuid := gen_random_uuid();
  v_tbl_id      uuid := gen_random_uuid();

  v_tbl_chan_code text := 'tbl_' || encode(gen_random_bytes(16), 'hex');
  v_ctr_chan_code text := 'ctr_' || encode(gen_random_bytes(16), 'hex');

  v_prod_nong   uuid := gen_random_uuid();
  v_prod_bar    uuid := gen_random_uuid();
  v_prod_bad    uuid := gen_random_uuid();

  v_token       text;
  v_hash        text;
  v_res         jsonb;
  v_req_id      uuid;
  v_order_id    uuid;
  v_ticket_id   uuid;
  v_tkt_station text;
  v_zone_lbl    text;
  v_item_st_nong text;
  v_item_st_bar  text;
  v_order_cnt   integer;
  v_ticket_cnt  integer;
BEGIN
  -- Insert Fixture Data
  INSERT INTO public.stores(id, store_code, name) VALUES (v_store_id, 'KITCHENSTORE1', 'Kitchen Store 1');

  v_hash := public.hash_pos_credential_v3('0933333333', '333333');
  INSERT INTO public.user_accounts(id, phone, password_hash, quick_pin) VALUES (v_user_id, '0933333333', v_hash, v_hash);
  INSERT INTO public.store_members(user_id, store_id, role, is_owner) VALUES (v_user_id, v_store_id, 'owner', true);
  INSERT INTO public.devices(id, store_id, device_name, device_role) VALUES (v_dev_id, v_store_id, 'POS Kitchen 1', 'manager');

  INSERT INTO public.ban_zones(id, store_id, name) VALUES (v_zone_id, v_store_id, 'Khu Vực VIP 1');
  INSERT INTO public.ban_dining_tables(id, store_id, zone_id, name) VALUES (v_tbl_id::text, v_store_id, v_zone_id, 'Bàn K1');

  INSERT INTO public.qr_channels(store_id, type, table_id, channel_code, name, is_active) VALUES (v_store_id, 'table', v_tbl_id::text, v_tbl_chan_code, 'Bàn K1', true);
  INSERT INTO public.qr_channels(store_id, type, table_id, channel_code, name, is_active) VALUES (v_store_id, 'counter', NULL, v_ctr_chan_code, 'Quầy Thu Ngân', true);

  INSERT INTO public.app_settings(store_id, key, value) VALUES (v_store_id, 'qr_order_settings', '{"is_table_enabled": true, "is_counter_enabled": true}');

  INSERT INTO public.products(id, store_id, name, sell_price, is_active, is_available, is_deleted, station_code) VALUES (v_prod_nong, v_store_id, 'Lẩu Nấm Hot', 200000.00, true, true, false, 'bep_nong');
  INSERT INTO public.products(id, store_id, name, sell_price, is_active, is_available, is_deleted, station_code) VALUES (v_prod_bar, v_store_id, 'Bia Sài Gòn Bar', 20000.00, true, true, false, 'nuoc');
  INSERT INTO public.products(id, store_id, name, sell_price, is_active, is_available, is_deleted, station_code) VALUES (v_prod_bad, v_store_id, 'Món Lỗi Station', 50000.00, true, true, false, 'unknown_station_xyz');

  v_res := public.issue_pos_device_session_v3('KITCHENSTORE1', 'owner_password', v_user_id, '333333', v_dev_id);
  v_token := v_res -> 'data' ->> 'session_token';

  -- Test 1: Table Dispatch with Mixed Stations (Nong + Bar)
  v_res := public.submit_qr_order_v3(
    v_tbl_chan_code,
    jsonb_build_array(
      jsonb_build_object('product_id', v_prod_nong, 'quantity', 1),
      jsonb_build_object('product_id', v_prod_bar, 'quantity', 4)
    ),
    'Ghi chú mixed station',
    'idempotency_kitch_1',
    encode(gen_random_bytes(32), 'hex')
  );
  v_req_id := (v_res -> 'data' ->> 'request_id')::uuid;

  PERFORM public.claim_qr_request_v3(v_req_id, v_token);
  PERFORM public.confirm_qr_request_v3(v_req_id, v_token);

  v_res := public.send_to_kitchen_qr_v3(v_req_id, v_token);
  IF (v_res ->> 'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: send_to_kitchen_qr_v3 failed for mixed station table request: %', v_res;
  END IF;

  v_order_id := (v_res -> 'data' ->> 'order_id')::uuid;

  -- Assert Ticket Created with NULL station_code for mixed items and correct Zone Label
  SELECT id, station_code, zone_label INTO v_ticket_id, v_tkt_station, v_zone_lbl
  FROM public.kitchen_tickets WHERE order_id = v_order_id;

  IF v_tkt_station IS NOT NULL THEN
    RAISE EXCEPTION 'TEST_FAIL: Expected NULL ticket station_code for mixed items, got %', v_tkt_station;
  END IF;

  IF v_zone_lbl <> 'Khu Vực VIP 1' THEN
    RAISE EXCEPTION 'TEST_FAIL: Expected zone_label = "Khu Vực VIP 1", got %', v_zone_lbl;
  END IF;

  -- Section D.5 Assertion: Verify per-item station_code routing on kitchen_ticket_items
  SELECT station_code INTO v_item_st_nong FROM public.kitchen_ticket_items WHERE ticket_id = v_ticket_id AND product_id = v_prod_nong::text;
  SELECT station_code INTO v_item_st_bar FROM public.kitchen_ticket_items WHERE ticket_id = v_ticket_id AND product_id = v_prod_bar::text;

  IF v_item_st_nong <> 'nong' THEN
    RAISE EXCEPTION 'TEST_FAIL: Expected kitchen_ticket_item station_code = "nong", got %', v_item_st_nong;
  END IF;
  IF v_item_st_bar <> 'bar' THEN
    RAISE EXCEPTION 'TEST_FAIL: Expected kitchen_ticket_item station_code = "bar", got %', v_item_st_bar;
  END IF;

  -- Assert Duplicate Dispatch Idempotency does NOT increase order/ticket count
  SELECT COUNT(*) INTO v_order_cnt FROM public.orders WHERE store_id = v_store_id;
  SELECT COUNT(*) INTO v_ticket_cnt FROM public.kitchen_tickets WHERE store_id = v_store_id;

  v_res := public.send_to_kitchen_qr_v3(v_req_id, v_token);
  IF (v_res -> 'data' ->> 'is_duplicate_dispatch')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: Duplicate dispatch failed to return is_duplicate_dispatch = true';
  END IF;

  IF (SELECT COUNT(*) FROM public.orders WHERE store_id = v_store_id) <> v_order_cnt OR
     (SELECT COUNT(*) FROM public.kitchen_tickets WHERE store_id = v_store_id) <> v_ticket_cnt THEN
    RAISE EXCEPTION 'TEST_FAIL: Duplicate dispatch mutated database count!';
  END IF;

  -- Test 2: Unknown Station Code Fail-Closed (PRODUCES ZERO CORE ROWS)
  v_res := public.submit_qr_order_v3(
    v_tbl_chan_code,
    jsonb_build_array(jsonb_build_object('product_id', v_prod_bad, 'quantity', 1)),
    '',
    'idempotency_kitch_bad',
    encode(gen_random_bytes(32), 'hex')
  );
  v_req_id := (v_res -> 'data' ->> 'request_id')::uuid;

  PERFORM public.claim_qr_request_v3(v_req_id, v_token);
  PERFORM public.confirm_qr_request_v3(v_req_id, v_token);

  SELECT COUNT(*) INTO v_order_cnt FROM public.orders WHERE store_id = v_store_id;
  SELECT COUNT(*) INTO v_ticket_cnt FROM public.kitchen_tickets WHERE store_id = v_store_id;

  v_res := public.send_to_kitchen_qr_v3(v_req_id, v_token);
  IF (v_res ->> 'error_code') <> 'UNKNOWN_STATION_CODE' THEN
    RAISE EXCEPTION 'TEST_FAIL: Unknown station code did not fail closed (expected UNKNOWN_STATION_CODE, got %)', v_res;
  END IF;

  -- Assert ZERO core rows created for unknown station fail-closed
  IF (SELECT COUNT(*) FROM public.orders WHERE store_id = v_store_id) <> v_order_cnt OR
     (SELECT COUNT(*) FROM public.kitchen_tickets WHERE store_id = v_store_id) <> v_ticket_cnt THEN
    RAISE EXCEPTION 'TEST_FAIL: Unknown station fail-closed created partial core rows!';
  END IF;

  -- Test 3: Price Discrepancy Gate (ORDER_RECONFIRM_REQUIRED)
  v_res := public.submit_qr_order_v3(
    v_tbl_chan_code,
    jsonb_build_array(jsonb_build_object('product_id', v_prod_nong, 'quantity', 1)),
    '',
    'idempotency_kitch_disc',
    encode(gen_random_bytes(32), 'hex')
  );
  v_req_id := (v_res -> 'data' ->> 'request_id')::uuid;

  PERFORM public.claim_qr_request_v3(v_req_id, v_token);
  PERFORM public.confirm_qr_request_v3(v_req_id, v_token);

  -- Admin changes server price on product after staff confirmation
  UPDATE public.products SET sell_price = 250000.00 WHERE id = v_prod_nong;

  v_res := public.send_to_kitchen_qr_v3(v_req_id, v_token);
  IF (v_res ->> 'error_code') <> 'ORDER_RECONFIRM_REQUIRED' THEN
    RAISE EXCEPTION 'TEST_FAIL: Price discrepancy did not trigger ORDER_RECONFIRM_REQUIRED (got %)', v_res;
  END IF;

  RAISE NOTICE 'TEST_BEHAVIORAL_PASS: Kitchen dispatch, per-item station routing & zero-core-row unknown station executed clean';
END $$;

ROLLBACK;
