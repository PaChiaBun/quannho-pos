-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION: 20260731_create_qr_public_rpc_v3.sql
-- Module: Architecture v3 Public Customer Anonymous RPCs
-- Status: DRAFT_CREATED_NOT_EXECUTED (Draft SQL for Staging review only)
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. get_qr_menu_v3(p_channel_code text)
CREATE OR REPLACE FUNCTION public.get_qr_menu_v3(p_channel_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_channel       record;
  v_table_name    text;
  v_products      jsonb;
  v_toppings      jsonb;
  v_topping_links jsonb;
  v_result        jsonb;
BEGIN
  IF p_channel_code IS NULL OR TRIM(p_channel_code) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_CHANNEL',
      'message', 'Mã QR không hợp lệ.'
    );
  END IF;

  -- Validate channel
  SELECT c.id, c.store_id, c.type, c.table_id, c.channel_code, c.is_active, s.store_code, s.name AS store_name
  INTO v_channel
  FROM public.qr_channels c
  JOIN public.stores s ON s.id = c.store_id
  WHERE c.channel_code = TRIM(p_channel_code) AND c.is_active = true
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_CHANNEL',
      'message', 'Mã QR không tồn tại hoặc đã tạm dừng.'
    );
  END IF;

  -- Get table_name if channel is table
  IF v_channel.table_id IS NOT NULL THEN
    SELECT COALESCE(name, label, id) INTO v_table_name
    FROM public.ban_dining_tables
    WHERE id = v_channel.table_id;
  ELSE
    v_table_name := 'Quầy Thu Ngân';
  END IF;

  -- Fetch main products ONLY (is_topping IS NOT TRUE)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'name', p.name,
      'sell_price', p.sell_price,
      'category', p.category,
      'unit', p.unit,
      'is_available', p.is_available,
      'is_topping', false,
      'image_url', p.image_url
    )
  ), '[]'::jsonb)
  INTO v_products
  FROM public.products p
  WHERE p.store_id = v_channel.store_id 
    AND (p.is_topping IS NOT TRUE)
    AND (p.is_available IS TRUE OR p.is_available IS NULL)
    AND (p.is_active IS TRUE OR p.is_active IS NULL)
    AND (p.is_deleted IS FALSE OR p.is_deleted IS NULL);

  -- Fetch toppings ONLY (is_topping IS TRUE)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', p.id,
      'name', p.name,
      'sell_price', p.sell_price,
      'category', p.category,
      'unit', p.unit,
      'is_available', p.is_available,
      'is_topping', true,
      'image_url', p.image_url
    )
  ), '[]'::jsonb)
  INTO v_toppings
  FROM public.products p
  WHERE p.store_id = v_channel.store_id 
    AND (p.is_topping IS TRUE)
    AND (p.is_available IS TRUE OR p.is_available IS NULL)
    AND (p.is_active IS TRUE OR p.is_active IS NULL)
    AND (p.is_deleted IS FALSE OR p.is_deleted IS NULL);

  -- Fetch valid topping links if product_topping_links table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'product_topping_links') THEN
    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'product_id', valid_link.product_id,
        'topping_id', valid_link.topping_id,
        'sort_order', valid_link.sort_order
      ) ORDER BY valid_link.sort_order ASC, valid_link.topping_id
    ), '[]'::jsonb)
    INTO v_topping_links
    FROM (
      SELECT DISTINCT ON (ptl.product_id, ptl.topping_id)
        ptl.product_id,
        ptl.topping_id,
        COALESCE(ptl.sort_order, 0) AS sort_order
      FROM public.product_topping_links ptl
      JOIN public.products main_product ON main_product.id = ptl.product_id
      JOIN public.products topping ON topping.id = ptl.topping_id
      WHERE main_product.store_id = v_channel.store_id
        AND topping.store_id = v_channel.store_id
        AND main_product.is_topping IS NOT TRUE
        AND topping.is_topping IS TRUE
        AND (main_product.is_active IS TRUE OR main_product.is_active IS NULL)
        AND (main_product.is_deleted IS FALSE OR main_product.is_deleted IS NULL)
        AND (topping.is_available IS TRUE OR topping.is_available IS NULL)
        AND (topping.is_active IS TRUE OR topping.is_active IS NULL)
        AND (topping.is_deleted IS FALSE OR topping.is_deleted IS NULL)
      ORDER BY ptl.product_id, ptl.topping_id, COALESCE(ptl.sort_order, 0)
    ) valid_link;
  ELSE
    v_topping_links := '[]'::jsonb;
  END IF;

  v_result := jsonb_build_object(
    'success', true,
    'store_id', v_channel.store_id,
    'store_name', v_channel.store_name,
    'channel_code', v_channel.channel_code,
    'channel_type', v_channel.type,
    'table_id', v_channel.table_id,
    'table_name', COALESCE(v_table_name, v_channel.store_name),
    'products', v_products,
    'toppings', v_toppings,
    'topping_links', v_topping_links
  );

  RETURN v_result;
END;
$$;

-- 2. submit_qr_order_v3(p_channel_code text, p_items jsonb, p_note text, p_idempotency_key text)
CREATE OR REPLACE FUNCTION public.submit_qr_order_v3(
  p_channel_code    text,
  p_items           jsonb,
  p_note            text,
  p_idempotency_key text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_channel        record;
  v_existing_req   record;
  v_item           jsonb;
  v_topping        jsonb;
  v_prod_id        uuid;
  v_topping_id     uuid;
  v_qty            int;
  v_top_qty        int;
  v_prod_rec       record;
  v_top_rec        record;
  v_computed_total numeric := 0;
  v_item_unit_total numeric;
  v_line_total     numeric;
  v_item_toppings  jsonb;
  v_seen_toppings  uuid[];
  v_tracking_token text;
  v_new_request_id uuid;
  v_items_count    int;
  v_toppings_count int;
  v_clean_key      text;
  v_clean_note     text;
  v_item_note      text;
BEGIN
  -- Input Sanitization & Boundary Validation
  IF p_channel_code IS NULL OR TRIM(p_channel_code) = '' THEN
    RAISE EXCEPTION 'QR Error: Channel code cannot be empty.';
  END IF;

  v_clean_key := NULLIF(TRIM(p_idempotency_key), '');
  IF v_clean_key IS NOT NULL AND char_length(v_clean_key) > 128 THEN
    RAISE EXCEPTION 'QR Error: Idempotency key exceeds maximum length of 128 characters.';
  END IF;

  v_clean_note := TRIM(COALESCE(p_note, ''));
  IF char_length(v_clean_note) > 500 THEN
    RAISE EXCEPTION 'QR Error: Note exceeds maximum length of 500 characters.';
  END IF;

  -- Validate jsonb_typeof BEFORE jsonb_array_length
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
    RAISE EXCEPTION 'QR Error: Items payload must be a JSON array.';
  END IF;

  v_items_count := jsonb_array_length(p_items);
  IF v_items_count = 0 OR v_items_count > 50 THEN
    RAISE EXCEPTION 'QR Error: Items payload must contain between 1 and 50 items.';
  END IF;

  -- Step A: Validate channel & store FIRST (Prevents data leakage across stores)
  SELECT id, store_id, type, table_id
  INTO v_channel
  FROM public.qr_channels
  WHERE channel_code = TRIM(p_channel_code) AND is_active = true
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'QR Error: Channel code "%" invalid or inactive.', p_channel_code;
  END IF;

  -- Step B: Atomic Idempotency Locking scoped BY (channel_id, idempotency_key)
  IF v_clean_key IS NOT NULL THEN
    PERFORM pg_advisory_xact_lock(hashtext(v_channel.id::text || ':' || v_clean_key));

    SELECT id, status, tracking_token, total_amount, created_at
    INTO v_existing_req
    FROM public.qr_requests
    WHERE channel_id = v_channel.id AND idempotency_key = v_clean_key
    LIMIT 1;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'success', true,
        'request_id', v_existing_req.id,
        'status', v_existing_req.status,
        'tracking_token', v_existing_req.tracking_token,
        'total_amount', v_existing_req.total_amount,
        'created_at', v_existing_req.created_at,
        'is_duplicate', true
      );
    END IF;
  END IF;

  -- Step C: Pre-validate main items and toppings, compute server-side prices
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    BEGIN
      v_prod_id := (v_item->>'product_id')::uuid;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'QR Error: Invalid product_id UUID format.';
    END;

    v_qty := COALESCE((v_item->>'quantity')::int, 1);
    IF v_qty <= 0 OR v_qty > 99 THEN
      RAISE EXCEPTION 'QR Error: Item quantity must be between 1 and 99.';
    END IF;

    -- Main product check: MUST exist, match store, is_available=true, is_active=true, is_deleted=false, AND is_topping != true
    SELECT id, name, sell_price, is_available, is_active, is_deleted, is_topping
    INTO v_prod_rec
    FROM public.products
    WHERE id = v_prod_id AND store_id = v_channel.store_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'QR Error: Product ID "%" not found in store.', v_prod_id;
    END IF;

    IF v_prod_rec.is_topping IS TRUE THEN
      RAISE EXCEPTION 'QR Error: Product "%" is a topping and cannot be ordered as a main item.', v_prod_rec.name;
    END IF;

    IF v_prod_rec.is_available IS FALSE OR v_prod_rec.is_active IS FALSE OR v_prod_rec.is_deleted IS TRUE THEN
      RAISE EXCEPTION 'QR Error: Product "%" is currently unavailable.', v_prod_rec.name;
    END IF;

    v_item_unit_total := v_prod_rec.sell_price;
    v_seen_toppings   := ARRAY[]::uuid[];

    -- Validate optional toppings array with FAIL-CLOSED logic
    IF v_item ? 'toppings' AND v_item->'toppings' IS NOT NULL AND jsonb_typeof(v_item->'toppings') = 'array' THEN
      v_toppings_count := jsonb_array_length(v_item->'toppings');
      IF v_toppings_count > 10 THEN
        RAISE EXCEPTION 'QR Error: Maximum 10 toppings allowed per item.';
      END IF;

      FOR v_topping IN SELECT * FROM jsonb_array_elements(v_item->'toppings')
      LOOP
        BEGIN
          v_topping_id := (v_topping->>'topping_id')::uuid;
        EXCEPTION WHEN OTHERS THEN
          RAISE EXCEPTION 'QR Error: Invalid topping_id UUID format.';
        END;

        -- Reject duplicate toppings in same item
        IF v_topping_id = ANY(v_seen_toppings) THEN
          RAISE EXCEPTION 'QR Error: Duplicate topping ID "%" in item.', v_topping_id;
        END IF;
        v_seen_toppings := array_append(v_seen_toppings, v_topping_id);

        v_top_qty := COALESCE((v_topping->>'quantity')::int, 1);
        IF v_top_qty <= 0 OR v_top_qty > 10 THEN
          RAISE EXCEPTION 'QR Error: Topping quantity must be between 1 and 10.';
        END IF;

        -- Verify product_topping_links link exists (FAIL-CLOSED if missing)
        IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'product_topping_links') THEN
          RAISE EXCEPTION 'QR System Error: Table product_topping_links is required for topping validation.';
        END IF;

        IF NOT EXISTS (
          SELECT 1 FROM public.product_topping_links 
          WHERE product_id = v_prod_id AND topping_id = v_topping_id
        ) THEN
          RAISE EXCEPTION 'QR Error: Topping ID "%" is not valid for product "%".', v_topping_id, v_prod_rec.name;
        END IF;

        -- Verify topping product (MUST have is_topping = true)
        SELECT id, name, sell_price, is_available, is_active, is_deleted, is_topping
        INTO v_top_rec
        FROM public.products
        WHERE id = v_topping_id AND store_id = v_channel.store_id;

        IF NOT FOUND OR v_top_rec.is_topping IS NOT TRUE OR v_top_rec.is_available IS FALSE OR v_top_rec.is_active IS FALSE OR v_top_rec.is_deleted IS TRUE THEN
          RAISE EXCEPTION 'QR Error: Topping "%" is currently unavailable or invalid.', COALESCE(v_top_rec.name, v_topping_id::text);
        END IF;

        v_item_unit_total := v_item_unit_total + (v_top_rec.sell_price * v_top_qty);
      END LOOP;
    END IF;

    v_line_total     := v_item_unit_total * v_qty;
    v_computed_total := v_computed_total + v_line_total;
  END LOOP;

  -- Step D: Generate secure random tracking token
  v_tracking_token := encode(digest(gen_random_bytes(32), 'sha256'), 'hex');

  -- Step E: Atomic Insert into qr_requests header
  INSERT INTO public.qr_requests (
    store_id,
    channel_id,
    table_id,
    type,
    status,
    total_amount,
    note,
    tracking_token,
    idempotency_key,
    created_at
  ) VALUES (
    v_channel.store_id,
    v_channel.id,
    v_channel.table_id,
    v_channel.type,
    'pending_staff',
    v_computed_total,
    v_clean_note,
    v_tracking_token,
    v_clean_key,
    now()
  )
  RETURNING id INTO v_new_request_id;

  -- Step F: Atomic Insert items into qr_request_items table
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_prod_id := (v_item->>'product_id')::uuid;
    v_qty     := COALESCE((v_item->>'quantity')::int, 1);
    v_item_note := TRIM(COALESCE(v_item->>'note', ''));
    IF char_length(v_item_note) > 250 THEN
      RAISE EXCEPTION 'QR Error: Item note exceeds 250 characters.';
    END IF;

    SELECT name, sell_price INTO v_prod_rec
    FROM public.products
    WHERE id = v_prod_id AND store_id = v_channel.store_id;

    v_item_unit_total := v_prod_rec.sell_price;
    v_item_toppings   := '[]'::jsonb;

    IF v_item ? 'toppings' AND v_item->'toppings' IS NOT NULL AND jsonb_typeof(v_item->'toppings') = 'array' THEN
      FOR v_topping IN SELECT * FROM jsonb_array_elements(v_item->'toppings')
      LOOP
        v_topping_id := (v_topping->>'topping_id')::uuid;
        v_top_qty    := COALESCE((v_topping->>'quantity')::int, 1);
        SELECT name, sell_price INTO v_top_rec
        FROM public.products
        WHERE id = v_topping_id AND store_id = v_channel.store_id;

        v_item_unit_total := v_item_unit_total + (v_top_rec.sell_price * v_top_qty);
        v_item_toppings   := v_item_toppings || jsonb_build_object(
          'topping_id', v_topping_id,
          'name', v_top_rec.name,
          'unit_price', v_top_rec.sell_price,
          'quantity', v_top_qty
        );
      END LOOP;
    END IF;

    INSERT INTO public.qr_request_items (
      request_id,
      product_id,
      product_name,
      unit_price,
      quantity,
      subtotal,
      modifiers_json,
      note
    ) VALUES (
      v_new_request_id,
      v_prod_id,
      v_prod_rec.name,
      v_item_unit_total,
      v_qty,
      (v_item_unit_total * v_qty),
      v_item_toppings,
      v_item_note
    );
  END LOOP;

  -- Step G: Audit Log
  INSERT INTO public.qr_audit_logs (
    store_id, request_id, actor_type, action, from_status, to_status, payload
  ) VALUES (
    v_channel.store_id, v_new_request_id, 'customer', 'submit_qr_order_v3', NULL, 'pending_staff',
    jsonb_build_object('total_amount', v_computed_total, 'items_count', v_items_count)
  );

  RETURN jsonb_build_object(
    'success', true,
    'request_id', v_new_request_id,
    'status', 'pending_staff',
    'tracking_token', v_tracking_token,
    'total_amount', v_computed_total,
    'created_at', now(),
    'is_duplicate', false
  );
END;
$$;

-- 3. get_qr_request_status_v3(p_tracking_token text)
CREATE OR REPLACE FUNCTION public.get_qr_request_status_v3(p_tracking_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_req   record;
  v_items jsonb;
BEGIN
  IF p_tracking_token IS NULL OR TRIM(p_tracking_token) = '' THEN
    RAISE EXCEPTION 'QR Error: Tracking token cannot be empty.';
  END IF;

  SELECT id, store_id, status, total_amount, note, created_at, claimed_at, confirmed_at, reject_reason
  INTO v_req
  FROM public.qr_requests
  WHERE tracking_token = TRIM(p_tracking_token)
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'QR Error: Tracking token invalid.';
  END IF;

  -- Fetch items from qr_request_items table
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', ri.id,
      'product_id', ri.product_id,
      'product_name', ri.product_name,
      'unit_price', ri.unit_price,
      'quantity', ri.quantity,
      'modifiers_json', ri.modifiers_json,
      'note', ri.note
    )
  ), '[]'::jsonb)
  INTO v_items
  FROM public.qr_request_items ri
  WHERE ri.request_id = v_req.id;

  RETURN jsonb_build_object(
    'success', true,
    'request_id', v_req.id,
    'status', v_req.status,
    'items', v_items,
    'total_amount', v_req.total_amount,
    'note', v_req.note,
    'reject_reason', v_req.reject_reason,
    'created_at', v_req.created_at,
    'claimed_at', v_req.claimed_at,
    'confirmed_at', v_req.confirmed_at
  );
END;
$$;

-- Revoke & Grant EXECUTE privileges to anon role
REVOKE ALL ON FUNCTION public.get_qr_menu_v3(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_qr_order_v3(text, jsonb, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_qr_request_status_v3(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_qr_menu_v3(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_qr_order_v3(text, jsonb, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_qr_request_status_v3(text) TO anon, authenticated;
