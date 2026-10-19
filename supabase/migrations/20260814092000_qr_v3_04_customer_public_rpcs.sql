-- Migration 04: Customer Public RPCs (Menu, Canonical Idempotency Submit, Track Status)
-- File: supabase/migrations/20260814092000_qr_v3_04_customer_public_rpcs.sql

-- Preflight
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_qr_menu_v3') THEN
    RAISE EXCEPTION 'MIGRATION_04_PREFLIGHT_FAIL: Function get_qr_menu_v3 already exists';
  END IF;
END $$;

-- 1. get_qr_menu_v3 (Fail-Closed Settings Parsing)
CREATE OR REPLACE FUNCTION public.get_qr_menu_v3(
  p_channel_code text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_chan         RECORD;
  v_settings_val text;
  v_settings     jsonb;
  v_key          text;
  v_domain       text;
  v_table_en     boolean := false;
  v_counter_en   boolean := false;
  v_prods        jsonb;
  v_cats         jsonb;
BEGIN
  IF p_channel_code IS NULL OR TRIM(p_channel_code) = '' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_CHANNEL_CODE', 'message', 'Mã kênh QR không hợp lệ');
  END IF;

  SELECT c.id, c.store_id, c.type, c.table_id, c.name, c.is_active
  INTO v_chan
  FROM public.qr_channels c
  WHERE c.channel_code = p_channel_code;

  IF v_chan.id IS NULL OR v_chan.is_active IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'CHANNEL_INACTIVE', 'message', 'Kênh QR không tồn tại hoặc đã bị tắt');
  END IF;

  -- Fail-closed settings check
  SELECT value INTO v_settings_val FROM public.app_settings WHERE store_id = v_chan.store_id AND key = 'qr_order_settings';
  IF v_settings_val IS NOT NULL THEN
    BEGIN
      v_settings := v_settings_val::jsonb;
      IF jsonb_typeof(v_settings) <> 'object' THEN
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Cài đặt QR của cửa hàng bị lỗi định dạng');
      END IF;

      FOR v_key IN SELECT jsonb_object_keys(v_settings) LOOP
        IF v_key NOT IN ('is_table_enabled', 'is_counter_enabled', 'auto_claim', 'sound_enabled', 'public_domain') THEN
          RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Cài đặt chứa thuộc tính không hợp lệ: ' || v_key);
        END IF;
      END LOOP;

      IF (v_settings ? 'is_table_enabled' AND jsonb_typeof(v_settings -> 'is_table_enabled') <> 'boolean') OR
         (v_settings ? 'is_counter_enabled' AND jsonb_typeof(v_settings -> 'is_counter_enabled') <> 'boolean') OR
         (v_settings ? 'auto_claim' AND jsonb_typeof(v_settings -> 'auto_claim') <> 'boolean') OR
         (v_settings ? 'sound_enabled' AND jsonb_typeof(v_settings -> 'sound_enabled') <> 'boolean') OR
         (v_settings ? 'public_domain' AND jsonb_typeof(v_settings -> 'public_domain') <> 'string') THEN
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Dữ liệu cài đặt có kiểu thuộc tính không hợp lệ');
      END IF;

      v_domain := TRIM(COALESCE(v_settings ->> 'public_domain', ''));
      IF length(v_domain) > 255 OR (v_domain <> '' AND v_domain !~ '^https://[a-zA-Z0-9.-]+(:[0-9]+)?$') THEN
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Dữ liệu tên miền cài đặt không hợp lệ');
      END IF;

      v_table_en := COALESCE((v_settings ->> 'is_table_enabled')::boolean, false);
      v_counter_en := COALESCE((v_settings ->> 'is_counter_enabled')::boolean, false);
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Cài đặt QR của cửa hàng bị lỗi định dạng');
    END;
  END IF;

  IF v_chan.type = 'table' AND v_table_en IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'TABLE_QR_DISABLED', 'message', 'Tính năng QR Gọi tại bàn đang tạm tắt');
  END IF;

  IF v_chan.type = 'counter' AND v_counter_en IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'COUNTER_QR_DISABLED', 'message', 'Tính năng QR Gọi tại quầy đang tạm tắt');
  END IF;

  -- Active, available products & toppings
  SELECT jsonb_agg(jsonb_build_object(
    'product_id', p.id,
    'name', p.name,
    'sell_price', p.sell_price,
    'station_code', p.station_code,
    'toppings', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'topping_id', t.id,
        'name', t.name,
        'sell_price', t.sell_price
      )), '[]'::jsonb)
      FROM public.product_topping_links l
      JOIN public.products t ON t.id = l.topping_id
      WHERE l.product_id = p.id
        AND t.store_id = v_chan.store_id
        AND t.is_active = true
        AND t.is_available = true
        AND t.is_deleted = false
        AND t.is_topping = true
    )
  )) INTO v_prods
  FROM public.products p
  WHERE p.store_id = v_chan.store_id
    AND p.is_active = true
    AND p.is_available = true
    AND p.is_deleted = false
    AND (p.is_topping IS NOT TRUE OR p.is_topping = false);

  -- Active categories
  SELECT jsonb_agg(DISTINCT jsonb_build_object('id', category, 'name', category))
  INTO v_cats
  FROM public.products
  WHERE store_id = v_chan.store_id AND is_active = true AND is_available = true AND is_deleted = false AND category IS NOT NULL AND category <> '';

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'channel', jsonb_build_object('channel_id', v_chan.id, 'type', v_chan.type, 'name', v_chan.name, 'table_id', v_chan.table_id),
      'categories', COALESCE(v_cats, '[]'::jsonb),
      'products', COALESCE(v_prods, '[]'::jsonb)
    ),
    'error_code', NULL,
    'message', NULL
  );
END;
$$;
ALTER FUNCTION public.get_qr_menu_v3(text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_qr_menu_v3(text) FROM PUBLIC, anon, authenticated;

-- 2. submit_qr_order_v3 (Fail-Closed Settings & Canonical Idempotency)
CREATE OR REPLACE FUNCTION public.submit_qr_order_v3(
  p_channel_code    text,
  p_items           jsonb,
  p_note            text,
  p_idempotency_key text,
  p_tracking_token  text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_chan           RECORD;
  v_settings_val   text;
  v_settings       jsonb;
  v_key            text;
  v_domain         text;
  v_table_en       boolean := false;
  v_counter_en     boolean := false;
  v_token_hash     bytea;
  v_payload_hash   bytea;
  v_existing_req   RECORD;

  -- Phase 1 Input Canonicalization Variables
  v_item_elem      jsonb;
  v_item_key       text;
  v_pid            uuid;
  v_qty            integer;
  v_top_elem_text  text;
  v_prev_top_id    text;
  v_top_id         uuid;

  v_sorted_toppings_text jsonb;
  v_raw_items_buf   jsonb := '[]'::jsonb;
  v_item_signature  text;
  v_prev_item_sig   text;
  v_item_sort_rec   RECORD;

  v_canonical_intent jsonb;
  v_clean_note      text;

  -- Phase 2 Live Server Data Validation Variables
  v_prod_rec       RECORD;
  v_top_rec        RECORD;
  v_item_unit_price numeric(12,2);
  v_item_subtotal   numeric(12,2);
  v_req_total       numeric(12,2) := 0.00;
  v_toppings_snap   jsonb;
  v_insert_items    jsonb := '[]'::jsonb;

  -- Phase 3 Mutation Variables
  v_req_id         uuid;
  v_date           date;
  v_seq            integer;
  v_pickup_code    text := NULL;
  v_ins_item       jsonb;
BEGIN
  -- Basic Input Validation
  IF p_tracking_token IS NULL OR p_tracking_token !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TRACKING_TOKEN_FORMAT', 'message', 'Mã tracking token không đúng định dạng 64 ký tự hex');
  END IF;

  IF p_idempotency_key IS NULL OR length(p_idempotency_key) NOT BETWEEN 1 AND 64 OR p_idempotency_key !~ '^[ -~]+$' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_IDEMPOTENCY_KEY', 'message', 'Khóa idempotency key không hợp lệ');
  END IF;

  SELECT c.id, c.store_id, c.type, c.table_id, c.name, c.is_active
  INTO v_chan
  FROM public.qr_channels c
  WHERE c.channel_code = p_channel_code;

  IF v_chan.id IS NULL OR v_chan.is_active IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'CHANNEL_INACTIVE', 'message', 'Kênh QR không tồn tại hoặc đã bị tắt');
  END IF;

  -- Fail-closed settings check
  SELECT value INTO v_settings_val FROM public.app_settings WHERE store_id = v_chan.store_id AND key = 'qr_order_settings';
  IF v_settings_val IS NOT NULL THEN
    BEGIN
      v_settings := v_settings_val::jsonb;
      IF jsonb_typeof(v_settings) <> 'object' THEN
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Cài đặt QR của cửa hàng bị lỗi định dạng');
      END IF;

      FOR v_key IN SELECT jsonb_object_keys(v_settings) LOOP
        IF v_key NOT IN ('is_table_enabled', 'is_counter_enabled', 'auto_claim', 'sound_enabled', 'public_domain') THEN
          RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Cài đặt chứa thuộc tính không hợp lệ: ' || v_key);
        END IF;
      END LOOP;

      IF (v_settings ? 'is_table_enabled' AND jsonb_typeof(v_settings -> 'is_table_enabled') <> 'boolean') OR
         (v_settings ? 'is_counter_enabled' AND jsonb_typeof(v_settings -> 'is_counter_enabled') <> 'boolean') OR
         (v_settings ? 'auto_claim' AND jsonb_typeof(v_settings -> 'auto_claim') <> 'boolean') OR
         (v_settings ? 'sound_enabled' AND jsonb_typeof(v_settings -> 'sound_enabled') <> 'boolean') OR
         (v_settings ? 'public_domain' AND jsonb_typeof(v_settings -> 'public_domain') <> 'string') THEN
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Dữ liệu cài đặt có kiểu thuộc tính không hợp lệ');
      END IF;

      v_domain := TRIM(COALESCE(v_settings ->> 'public_domain', ''));
      IF length(v_domain) > 255 OR (v_domain <> '' AND v_domain !~ '^https://[a-zA-Z0-9.-]+(:[0-9]+)?$') THEN
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Dữ liệu tên miền cài đặt không hợp lệ');
      END IF;

      v_table_en := COALESCE((v_settings ->> 'is_table_enabled')::boolean, false);
      v_counter_en := COALESCE((v_settings ->> 'is_counter_enabled')::boolean, false);
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'QR_SETTINGS_INVALID', 'message', 'Cài đặt QR của cửa hàng bị lỗi định dạng');
    END;
  END IF;

  IF v_chan.type = 'table' AND v_table_en IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'TABLE_QR_DISABLED', 'message', 'Tính năng QR Gọi tại bàn đang tạm tắt');
  END IF;

  IF v_chan.type = 'counter' AND v_counter_en IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'COUNTER_QR_DISABLED', 'message', 'Tính năng QR Gọi tại quầy đang tạm tắt');
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_ITEMS', 'message', 'Giỏ hàng trống hoặc không đúng định dạng danh sách');
  END IF;

  -- =========================================================================
  -- PHASE 1: INPUT CANONICALIZATION (CLIENT INTENT ONLY - NO PRODUCT NAMES / LIVE PRICES)
  -- =========================================================================

  v_clean_note := TRIM(COALESCE(p_note, ''));

  FOR v_item_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    IF jsonb_typeof(v_item_elem) <> 'object' THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PAYLOAD_FORMAT', 'message', 'Mỗi món ăn phải là một đối tượng JSON');
    END IF;

    -- Reject unknown keys
    FOR v_item_key IN SELECT jsonb_object_keys(v_item_elem) LOOP
      IF v_item_key NOT IN ('product_id', 'quantity', 'modifiers') THEN
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PAYLOAD_FORMAT', 'message', 'Món ăn chứa trường không hợp lệ: ' || v_item_key);
      END IF;
    END LOOP;

    -- Parse product_id
    BEGIN
      v_pid := (v_item_elem ->> 'product_id')::uuid;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PAYLOAD_FORMAT', 'message', 'Mã sản phẩm product_id không đúng định dạng UUID');
    END;

    -- Parse quantity
    BEGIN
      v_qty := (v_item_elem ->> 'quantity')::integer;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PAYLOAD_FORMAT', 'message', 'Số lượng sản phẩm không đúng định dạng số nguyên');
    END;

    IF v_qty IS NULL OR v_qty <= 0 THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_ITEMS', 'message', 'Số lượng sản phẩm phải lớn hơn 0');
    END IF;

    -- Normalize & sort topping UUIDs for this item
    v_sorted_toppings_text := '[]'::jsonb;
    v_prev_top_id := NULL;

    IF v_item_elem ? 'modifiers' THEN
      IF jsonb_typeof(v_item_elem -> 'modifiers') <> 'array' THEN
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PAYLOAD_FORMAT', 'message', 'Danh sách modifiers phải là một mảng JSON');
      END IF;

      FOR v_top_elem_text IN
        SELECT LOWER(jsonb_array_elements_text(v_item_elem -> 'modifiers')) ORDER BY 1
      LOOP
        BEGIN
          v_top_id := v_top_elem_text::uuid;
        EXCEPTION WHEN OTHERS THEN
          RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PAYLOAD_FORMAT', 'message', 'Mã topping không đúng định dạng UUID');
        END;

        IF v_prev_top_id IS NOT NULL AND v_prev_top_id = v_top_id::text THEN
          RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_PAYLOAD_FORMAT', 'message', 'Danh sách topping của món không được chứa mã trùng lặp');
        END IF;
        v_prev_top_id := v_top_id::text;

        v_sorted_toppings_text := v_sorted_toppings_text || to_jsonb(v_top_id::text);
      END LOOP;
    END IF;

    v_raw_items_buf := v_raw_items_buf || jsonb_build_object(
      'product_id', v_pid::text,
      'quantity', v_qty,
      'modifiers', v_sorted_toppings_text,
      'item_signature', v_pid::text || ':' || v_sorted_toppings_text::text
    );
  END LOOP;

  -- Sort items by product_id + modifiers string, and check for duplicate item signatures
  v_canonical_intent := '[]'::jsonb;
  v_prev_item_sig := NULL;

  FOR v_item_sort_rec IN
    SELECT (elem ->> 'product_id')::uuid AS pid, (elem ->> 'quantity')::integer AS qty, (elem -> 'modifiers') AS mods, (elem ->> 'item_signature') AS sig
    FROM jsonb_array_elements(v_raw_items_buf) AS elem
    ORDER BY (elem ->> 'item_signature')
  LOOP
    IF v_prev_item_sig IS NOT NULL AND v_prev_item_sig = v_item_sort_rec.sig THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'DUPLICATE_PAYLOAD_ITEM', 'message', 'Giỏ hàng chứa sản phẩm trùng lặp cùng lựa chọn topping. Vui lòng gộp số lượng');
    END IF;
    v_prev_item_sig := v_item_sort_rec.sig;

    v_canonical_intent := v_canonical_intent || jsonb_build_object(
      'product_id', v_item_sort_rec.pid::text,
      'quantity', v_item_sort_rec.qty,
      'modifiers', v_item_sort_rec.mods
    );
  END LOOP;

  -- Compute Hashes
  v_token_hash := digest(convert_to(p_tracking_token, 'UTF8'), 'sha256');
  v_payload_hash := digest(convert_to(jsonb_build_object('items', v_canonical_intent, 'note', v_clean_note)::text, 'UTF8'), 'sha256');

  -- =========================================================================
  -- PHASE 2: IDEMPOTENCY LOOKUP (RUNS BEFORE LIVE PRICE / AVAILABILITY VALIDATION)
  -- =========================================================================

  SELECT r.id, r.pickup_code, r.status, r.total_amount, r.quote_version, r.created_at, r.tracking_token_hash, r.request_payload_hash
  INTO v_existing_req
  FROM public.qr_requests r
  WHERE r.channel_id = v_chan.id AND r.idempotency_key = p_idempotency_key;

  IF v_existing_req.id IS NOT NULL THEN
    IF v_existing_req.tracking_token_hash IS DISTINCT FROM v_token_hash THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'IDEMPOTENCY_TOKEN_MISMATCH', 'message', 'Mã tracking token không khớp với đơn đã chèn trước đó');
    END IF;
    IF v_existing_req.request_payload_hash IS DISTINCT FROM v_payload_hash THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'IDEMPOTENCY_MISMATCH', 'message', 'Khóa idempotency đã được dùng cho đơn có món ăn khác');
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'data', jsonb_build_object(
        'request_id', v_existing_req.id,
        'status', v_existing_req.status,
        'pickup_code', v_existing_req.pickup_code,
        'total_amount', v_existing_req.total_amount,
        'quote_version', v_existing_req.quote_version,
        'created_at', v_existing_req.created_at,
        'is_duplicate', true
      ),
      'error_code', NULL,
      'message', NULL
    );
  END IF;

  -- =========================================================================
  -- PHASE 3: LIVE SERVER DATA VALIDATION & CALCULATIONS (FOR NEW REQUESTS ONLY)
  -- =========================================================================

  FOR v_item_sort_rec IN
    SELECT (elem ->> 'product_id')::uuid AS pid, (elem ->> 'quantity')::integer AS qty, (elem -> 'modifiers') AS mods
    FROM jsonb_array_elements(v_canonical_intent) AS elem
  LOOP
    SELECT id, name, sell_price, is_active, is_available, is_deleted INTO v_prod_rec
    FROM public.products
    WHERE id = v_item_sort_rec.pid AND store_id = v_chan.store_id FOR SHARE;

    IF v_prod_rec.id IS NULL OR v_prod_rec.is_active IS NOT TRUE OR v_prod_rec.is_available IS NOT TRUE OR v_prod_rec.is_deleted IS TRUE THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'ITEM_UNAVAILABLE', 'message', 'Sản phẩm không tồn tại hoặc đã tạm dừng bán');
    END IF;

    v_item_unit_price := v_prod_rec.sell_price;
    v_toppings_snap := '[]'::jsonb;

    FOR v_top_elem_text IN SELECT jsonb_array_elements_text(v_item_sort_rec.mods) LOOP
      v_top_id := v_top_elem_text::uuid;

      SELECT t.id, t.name, t.sell_price INTO v_top_rec
      FROM public.product_topping_links l
      JOIN public.products t ON t.id = l.topping_id
      WHERE l.product_id = v_item_sort_rec.pid
        AND l.topping_id = v_top_id
        AND t.store_id = v_chan.store_id
        AND t.is_active = true
        AND t.is_available = true
        AND t.is_deleted = false
        AND t.is_topping = true FOR SHARE;

      IF v_top_rec.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'ITEM_UNAVAILABLE', 'message', 'Topping chọn kèm không hợp lệ hoặc đã tạm dừng bán');
      END IF;

      v_item_unit_price := v_item_unit_price + v_top_rec.sell_price;
      v_toppings_snap := v_toppings_snap || jsonb_build_object('topping_id', v_top_rec.id, 'name', v_top_rec.name, 'unit_price', v_top_rec.sell_price);
    END LOOP;

    v_item_subtotal := v_item_unit_price * v_item_sort_rec.qty;
    v_req_total := v_req_total + v_item_subtotal;

    v_insert_items := v_insert_items || jsonb_build_object(
      'product_id', v_item_sort_rec.pid,
      'product_name', v_prod_rec.name,
      'unit_price', v_item_unit_price,
      'quantity', v_item_sort_rec.qty,
      'subtotal', v_item_subtotal,
      'modifiers_json', v_toppings_snap
    );
  END LOOP;

  -- =========================================================================
  -- PHASE 4: ATOMIC MUTATION (NEW REQUEST INSERTION)
  -- =========================================================================

  v_date := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
  IF v_chan.type = 'counter' THEN
    PERFORM pg_advisory_xact_lock(hashtext(v_chan.store_id::text || '_counter_seq_' || v_date::text));

    SELECT COALESCE(MAX(pickup_number), 0) + 1 INTO v_seq
    FROM public.qr_requests
    WHERE store_id = v_chan.store_id AND pickup_business_date = v_date AND type = 'counter';

    v_pickup_code := 'Q' || LPAD(v_seq::text, 3, '0');
  END IF;

  BEGIN
    INSERT INTO public.qr_requests (
      store_id, channel_id, type, table_id, table_name, pickup_business_date, pickup_number, pickup_code,
      tracking_token_hash, idempotency_key, request_payload_hash, status, note, total_amount
    ) VALUES (
      v_chan.store_id, v_chan.id, v_chan.type, v_chan.table_id, v_chan.name,
      CASE WHEN v_chan.type = 'counter' THEN v_date ELSE NULL END,
      CASE WHEN v_chan.type = 'counter' THEN v_seq ELSE NULL END,
      v_pickup_code, v_token_hash, p_idempotency_key, v_payload_hash, 'pending_staff', v_clean_note, v_req_total
    ) RETURNING id INTO v_req_id;
  EXCEPTION WHEN unique_violation THEN
    -- Section 5 Rethrow Unrelated Unique Violations: Re-query by (channel_id, idempotency_key)
    SELECT r.id, r.pickup_code, r.status, r.total_amount, r.quote_version, r.created_at, r.tracking_token_hash, r.request_payload_hash
    INTO v_existing_req
    FROM public.qr_requests r
    WHERE r.channel_id = v_chan.id AND r.idempotency_key = p_idempotency_key;

    IF v_existing_req.id IS NULL THEN
      -- Unrelated unique violation (e.g. tracking token collision with another request) -> RAISE original exception!
      RAISE;
    END IF;

    IF v_existing_req.tracking_token_hash IS DISTINCT FROM v_token_hash THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'IDEMPOTENCY_TOKEN_MISMATCH', 'message', 'Mã tracking token không khớp với đơn đã chèn trước đó');
    END IF;
    IF v_existing_req.request_payload_hash IS DISTINCT FROM v_payload_hash THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'IDEMPOTENCY_MISMATCH', 'message', 'Khóa idempotency đã được dùng cho đơn có món ăn khác');
    END IF;

    RETURN jsonb_build_object(
      'success', true,
      'data', jsonb_build_object(
        'request_id', v_existing_req.id,
        'status', v_existing_req.status,
        'pickup_code', v_existing_req.pickup_code,
        'total_amount', v_existing_req.total_amount,
        'quote_version', v_existing_req.quote_version,
        'created_at', v_existing_req.created_at,
        'is_duplicate', true
      ),
      'error_code', NULL,
      'message', NULL
    );
  END;

  -- Insert Items from memory buffer
  FOR v_ins_item IN SELECT * FROM jsonb_array_elements(v_insert_items) LOOP
    INSERT INTO public.qr_request_items(request_id, product_id, product_name, unit_price, quantity, subtotal, modifiers_json)
    VALUES (v_req_id, (v_ins_item ->> 'product_id')::uuid, v_ins_item ->> 'product_name', (v_ins_item ->> 'unit_price')::numeric, (v_ins_item ->> 'quantity')::integer, (v_ins_item ->> 'subtotal')::numeric, v_ins_item -> 'modifiers_json');
  END LOOP;

  INSERT INTO public.qr_audit_logs(store_id, request_id, actor_type, action, to_status, payload)
  VALUES (v_chan.store_id, v_req_id, 'customer', 'submit_request', 'pending_staff', jsonb_build_object('total_amount', v_req_total, 'pickup_code', v_pickup_code));

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'request_id', v_req_id,
      'status', 'pending_staff',
      'pickup_code', v_pickup_code,
      'total_amount', v_req_total,
      'quote_version', 1,
      'created_at', now(),
      'is_duplicate', false
    ),
    'error_code', NULL,
    'message', NULL
  );
END;
$$;
ALTER FUNCTION public.submit_qr_order_v3(text, jsonb, text, text, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.submit_qr_order_v3(text, jsonb, text, text, text) FROM PUBLIC, anon, authenticated;

-- 3. get_qr_request_status_v3
CREATE OR REPLACE FUNCTION public.get_qr_request_status_v3(
  p_tracking_token text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_token_hash bytea;
  v_req        RECORD;
  v_items      jsonb;
BEGIN
  IF p_tracking_token IS NULL OR p_tracking_token !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TRACKING_TOKEN_FORMAT', 'message', 'Mã tracking token không đúng định dạng 64 ký tự hex');
  END IF;

  v_token_hash := digest(convert_to(p_tracking_token, 'UTF8'), 'sha256');

  SELECT r.id, r.status, r.pickup_code, r.total_amount, r.created_at
  INTO v_req
  FROM public.qr_requests r
  WHERE r.tracking_token_hash = v_token_hash;

  IF v_req.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'REQUEST_NOT_FOUND', 'message', 'Không tìm thấy đơn hàng tương ứng');
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'product_name', product_name,
    'quantity', quantity,
    'unit_price', unit_price,
    'subtotal', subtotal
  )) INTO v_items
  FROM public.qr_request_items
  WHERE request_id = v_req.id;

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'request_id', v_req.id,
      'status', v_req.status,
      'pickup_code', v_req.pickup_code,
      'total_amount', v_req.total_amount,
      'items', COALESCE(v_items, '[]'::jsonb)
    ),
    'error_code', NULL,
    'message', NULL
  );
END;
$$;
ALTER FUNCTION public.get_qr_request_status_v3(text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_qr_request_status_v3(text) FROM PUBLIC, anon, authenticated;

-- Postflight Exact Function Signatures Check
DO $$
DECLARE
  v_func text;
BEGIN
  FOR v_func IN VALUES ('get_qr_menu_v3'), ('submit_qr_order_v3'), ('get_qr_request_status_v3') LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = v_func) THEN
      RAISE EXCEPTION 'MIGRATION_04_POSTFLIGHT_FAIL: Function public.% missing', v_func;
    END IF;
  END LOOP;
END $$;
