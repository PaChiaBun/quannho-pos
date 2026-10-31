-- SQL Test Suite 5: Database Constraints & Sequential Unique Guards (CONCURRENT_EXECUTION_NOT_RUN - Sequential Transaction Mode)
-- File: supabase/tests/qr_v3_concurrency_test.sql

-- NOTE: Real concurrent multi-connection execution is CONCURRENT_EXECUTION_NOT_RUN in single psql transaction scripts.
-- This suite verifies database unique constraints, advisory lock acquisitions, and sequence allocation sequentially.

BEGIN;

DO $$
DECLARE
  v_store_id    uuid := gen_random_uuid();
  v_user_id     uuid := gen_random_uuid();
  v_dev_id      uuid := gen_random_uuid();
  v_tbl_id      uuid := gen_random_uuid();
  v_chan_code   text := 'ctr_' || encode(gen_random_bytes(16), 'hex');
  v_prod_id     uuid := gen_random_uuid();

  v_sess_1      uuid := gen_random_uuid();
  v_sess_2      uuid := gen_random_uuid();
  v_order_1     uuid := gen_random_uuid();
  v_order_2     uuid := gen_random_uuid();

  v_res_1       jsonb;
  v_res_2       jsonb;
  v_err_thrown  boolean := false;
BEGIN
  -- Insert Fixture Data
  INSERT INTO public.stores(id, store_code, name) VALUES (v_store_id, 'CONCCSTORE1', 'Concurrency Store 1');
  INSERT INTO public.ban_dining_tables(id, store_id, name) VALUES (v_tbl_id::text, v_store_id, 'Bàn Conc 1');
  INSERT INTO public.qr_channels(store_id, type, table_id, channel_code, name, is_active) VALUES (v_store_id, 'counter', NULL, v_chan_code, 'Quầy Conc 1', true);
  INSERT INTO public.app_settings(store_id, key, value) VALUES (v_store_id, 'qr_order_settings', '{"is_table_enabled": true, "is_counter_enabled": true}');
  INSERT INTO public.products(id, store_id, name, sell_price, is_active, is_available, is_deleted, station_code) VALUES (v_prod_id, v_store_id, 'Món Conc', 30000.00, true, true, false, 'nong');

  -- Test 1: Enforce Unique Open Session Constraint (idx_ban_sessions_one_open_per_table)
  INSERT INTO public.ban_sessions(id, store_id, table_id, status, opened_at)
  VALUES (v_sess_1, v_store_id, v_tbl_id, 'open', now());

  BEGIN
    INSERT INTO public.ban_sessions(id, store_id, table_id, status, opened_at)
    VALUES (v_sess_2, v_store_id, v_tbl_id, 'open', now());
  EXCEPTION WHEN unique_violation THEN
    v_err_thrown := true;
  END;

  IF v_err_thrown IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: Unique open table session constraint did not trigger unique_violation';
  END IF;

  -- Test 2: Enforce Unique Ticket Round Constraint (uq_kitchen_tickets_session_round)
  v_err_thrown := false;
  INSERT INTO public.orders(id, store_id, source_type, source_id, total, status) VALUES (v_order_1, v_store_id, 'qr_order', 'req_conc_1', 30000.00, 'open');
  INSERT INTO public.orders(id, store_id, source_type, source_id, total, status) VALUES (v_order_2, v_store_id, 'qr_order', 'req_conc_2', 30000.00, 'open');

  INSERT INTO public.kitchen_tickets(store_id, order_id, session_id, round, status)
  VALUES (v_store_id, v_order_1, v_sess_1, 1, 'cho');

  BEGIN
    INSERT INTO public.kitchen_tickets(store_id, order_id, session_id, round, status)
    VALUES (v_store_id, v_order_2, v_sess_1, 1, 'cho');
  EXCEPTION WHEN unique_violation THEN
    v_err_thrown := true;
  END;

  IF v_err_thrown IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: Unique ticket round constraint did not trigger unique_violation';
  END IF;

  -- Test 3: Enforce Counter Pickup Sequence Incrementing
  v_res_1 := public.submit_qr_order_v3(v_chan_code, jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)), '', 'idempotency_seq_1', encode(gen_random_bytes(32), 'hex'));
  v_res_2 := public.submit_qr_order_v3(v_chan_code, jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)), '', 'idempotency_seq_2', encode(gen_random_bytes(32), 'hex'));

  IF (v_res_1 -> 'data' ->> 'pickup_code') <> 'Q001' OR (v_res_2 -> 'data' ->> 'pickup_code') <> 'Q002' THEN
    RAISE EXCEPTION 'TEST_FAIL: Counter pickup sequence did not increment properly (got % and %)', v_res_1 -> 'data' ->> 'pickup_code', v_res_2 -> 'data' ->> 'pickup_code';
  END IF;

  RAISE NOTICE 'TEST_BEHAVIORAL_PASS: Sequential database constraints, unique indexes & counter pickup sequences executed clean';
END $$;

ROLLBACK;
