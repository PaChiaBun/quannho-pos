-- Migration 00: Comprehensive Fail-Fast Preflight Validation for QR V3 Architecture
-- File: supabase/migrations/20260814090000_qr_v3_00_preflight.sql

DO $$
DECLARE
  v_col_missing text;
  v_func_conflict text;
  v_table_conflict text;
BEGIN
  -- 1. Check pgcrypto functions
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'digest') THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Function digest() from pgcrypto extension is missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'gen_random_bytes') THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Function gen_random_bytes() is missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'gen_random_uuid') THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Function gen_random_uuid() is missing';
  END IF;

  -- 2. Verify existence and exact columns of required core tables
  -- stores(id, store_code)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'stores' AND column_name = 'store_code') THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column stores.store_code is missing';
  END IF;

  -- devices(id, store_id, device_name, device_role, last_seen, created_at)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'devices' AND column_name = 'device_name') THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column devices.device_name is missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'devices' AND column_name = 'device_role') THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column devices.device_role is missing';
  END IF;

  -- products(id, store_id, name, sell_price, is_available, is_active, is_deleted, is_topping, station_code, category)
  SELECT column_name INTO v_col_missing
  FROM (VALUES ('id'), ('store_id'), ('name'), ('sell_price'), ('is_available'), ('is_active'), ('is_deleted'), ('is_topping'), ('station_code')) AS c(column_name)
  WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'products' AND column_name = c.column_name)
  LIMIT 1;
  IF v_col_missing IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column products.% is missing', v_col_missing;
  END IF;

  -- ban_dining_tables(id, store_id, zone_id, name)
  SELECT column_name INTO v_col_missing
  FROM (VALUES ('id'), ('store_id'), ('zone_id'), ('name')) AS c(column_name)
  WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ban_dining_tables' AND column_name = c.column_name)
  LIMIT 1;
  IF v_col_missing IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column ban_dining_tables.% is missing', v_col_missing;
  END IF;

  -- ban_zones(id, store_id, name)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ban_zones' AND column_name = 'name') THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column ban_zones.name is missing';
  END IF;

  -- ban_sessions(id, store_id, table_id, status, opened_at, guest_count, waiter_id)
  SELECT column_name INTO v_col_missing
  FROM (VALUES ('id'), ('store_id'), ('table_id'), ('status'), ('opened_at'), ('guest_count'), ('waiter_id')) AS c(column_name)
  WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ban_sessions' AND column_name = c.column_name)
  LIMIT 1;
  IF v_col_missing IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column ban_sessions.% is missing', v_col_missing;
  END IF;

  -- ban_session_items(id, store_id, session_id, product_id, product_name, unit_price, quantity, subtotal, modifiers_json, added_by, kitchen_status)
  SELECT column_name INTO v_col_missing
  FROM (VALUES ('id'), ('store_id'), ('session_id'), ('product_id'), ('product_name'), ('unit_price'), ('quantity'), ('subtotal'), ('modifiers_json'), ('added_by'), ('kitchen_status')) AS c(column_name)
  WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ban_session_items' AND column_name = c.column_name)
  LIMIT 1;
  IF v_col_missing IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column ban_session_items.% is missing', v_col_missing;
  END IF;

  -- orders(id, store_id, device_id, staff_id, source_type, source_id, total, status, note)
  SELECT column_name INTO v_col_missing
  FROM (VALUES ('id'), ('store_id'), ('device_id'), ('staff_id'), ('source_type'), ('source_id'), ('total'), ('status'), ('note')) AS c(column_name)
  WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = c.column_name)
  LIMIT 1;
  IF v_col_missing IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column orders.% is missing', v_col_missing;
  END IF;

  -- order_items(id, store_id, order_id, product_id, name, qty, unit_price, note, modifiers_json)
  SELECT column_name INTO v_col_missing
  FROM (VALUES ('id'), ('store_id'), ('order_id'), ('product_id'), ('name'), ('qty'), ('unit_price'), ('note'), ('modifiers_json')) AS c(column_name)
  WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'order_items' AND column_name = c.column_name)
  LIMIT 1;
  IF v_col_missing IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column order_items.% is missing', v_col_missing;
  END IF;

  -- kitchen_tickets(id, store_id, order_id, session_id, table_label, zone_label, round, station_code, status, sent_at)
  SELECT column_name INTO v_col_missing
  FROM (VALUES ('id'), ('store_id'), ('order_id'), ('session_id'), ('table_label'), ('zone_label'), ('round'), ('station_code'), ('status'), ('sent_at')) AS c(column_name)
  WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'kitchen_tickets' AND column_name = c.column_name)
  LIMIT 1;
  IF v_col_missing IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column kitchen_tickets.% is missing', v_col_missing;
  END IF;

  -- kitchen_ticket_items(id, store_id, ticket_id, session_item_id, product_id, name, product_name, qty, quantity, status, modifiers_json, station_code)
  SELECT column_name INTO v_col_missing
  FROM (VALUES ('id'), ('store_id'), ('ticket_id'), ('session_item_id'), ('product_id'), ('name'), ('product_name'), ('qty'), ('quantity'), ('status'), ('modifiers_json'), ('station_code')) AS c(column_name)
  WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'kitchen_ticket_items' AND column_name = c.column_name)
  LIMIT 1;
  IF v_col_missing IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column kitchen_ticket_items.% is missing', v_col_missing;
  END IF;

  -- staff_members(id, store_id, name, role, pin_hash, is_active)
  SELECT column_name INTO v_col_missing
  FROM (VALUES ('id'), ('store_id'), ('name'), ('role'), ('pin_hash'), ('is_active')) AS c(column_name)
  WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'staff_members' AND column_name = c.column_name)
  LIMIT 1;
  IF v_col_missing IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column staff_members.% is missing', v_col_missing;
  END IF;

  -- store_members(id, user_id, store_id, role, is_owner)
  SELECT column_name INTO v_col_missing
  FROM (VALUES ('id'), ('user_id'), ('store_id'), ('role'), ('is_owner')) AS c(column_name)
  WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'store_members' AND column_name = c.column_name)
  LIMIT 1;
  IF v_col_missing IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column store_members.% is missing', v_col_missing;
  END IF;

  -- user_accounts(id, phone, password_hash, quick_pin)
  SELECT column_name INTO v_col_missing
  FROM (VALUES ('id'), ('phone'), ('password_hash'), ('quick_pin')) AS c(column_name)
  WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_accounts' AND column_name = c.column_name)
  LIMIT 1;
  IF v_col_missing IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column user_accounts.% is missing', v_col_missing;
  END IF;

  -- app_settings(id, store_id, key, value)
  SELECT column_name INTO v_col_missing
  FROM (VALUES ('id'), ('store_id'), ('key'), ('value')) AS c(column_name)
  WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'app_settings' AND column_name = c.column_name)
  LIMIT 1;
  IF v_col_missing IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Column app_settings.% is missing', v_col_missing;
  END IF;

  -- 3. Exact Function Signatures Preflight Check (using pg_proc & pg_namespace)
  SELECT p.proname INTO v_func_conflict
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'get_qr_menu_v3', 'submit_qr_order_v3', 'get_qr_request_status_v3',
      'bootstrap_first_pos_device_v3', 'generate_pos_pairing_code_v3', 'pair_pos_device_v3',
      'issue_pos_device_session_v3', 'revoke_pos_device_session_v3', 'admin_revoke_device_session_v3',
      'list_pos_device_sessions_v3', 'get_pending_qr_requests_v3', 'claim_qr_request_v3',
      'confirm_qr_request_v3', 'reject_qr_request_v3', 'send_to_kitchen_qr_v3',
      'list_qr_channels_v3', 'upsert_qr_channel_v3', 'rotate_qr_channel_v3',
      'set_qr_channel_active_v3', 'get_qr_settings_v3', 'save_qr_settings_v3',
      'cleanup_expired_qr_requests_v3', 'cleanup_pos_auth_attempts_v3',
      'hash_pos_credential_v3', 'verify_pos_token_internal', 'check_pos_staff_action_permission'
    )
  LIMIT 1;

  IF v_func_conflict IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Routine public.% already exists in schema', v_func_conflict;
  END IF;

  -- 4. Check no conflicting tables exist
  SELECT table_name INTO v_table_conflict
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN ('qr_channels', 'qr_requests', 'qr_request_items', 'qr_audit_logs', 'product_topping_links', 'pos_device_sessions', 'pos_store_bootstrap_state', 'store_pairing_codes', 'pos_auth_attempts')
  LIMIT 1;

  IF v_table_conflict IS NOT NULL THEN
    RAISE EXCEPTION 'PREFLIGHT_FAIL: Table public.% already exists in schema', v_table_conflict;
  END IF;

  RAISE NOTICE 'PREFLIGHT_SUCCESS: Target database catalog and core dependencies are clean and fully verified for QR V3 installation';
END $$;
