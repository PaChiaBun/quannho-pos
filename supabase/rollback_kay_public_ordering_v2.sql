-- ═══════════════════════════════════════════════════════════════════════════
-- QUÁN NHỎ POS & KAY RESTAURANT — SQL Rollback Script v2 (Safe & Complete)
-- File: supabase/rollback_kay_public_ordering_v2.sql
-- Note: Restores the exact database RPC state prior to v2.
--       NEVER drops core tables (qr_requests, qr_channels, qr_request_items).
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. DROP V2 OVERLOADED RPC FUNCTIONS
DROP FUNCTION IF EXISTS submit_qr_order(text, jsonb, text, text);
DROP FUNCTION IF EXISTS get_public_store_menu(text);

-- 2. DROP V2 UNIQUE INDEX FOR IDEMPOTENCY KEY
DROP INDEX IF EXISTS idx_qr_requests_idempotency_unique;

-- 3. RESTORE PRE-V2 VERSION OF get_qr_menu(text)
CREATE OR REPLACE FUNCTION get_qr_menu(
  p_channel_code text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_channel record;
  v_store   record;
  v_products jsonb;
  v_toppings jsonb;
  v_topping_links jsonb;
BEGIN
  SELECT id, store_id, type, table_id, name, is_active
  INTO v_channel
  FROM qr_channels
  WHERE channel_code = p_channel_code AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Mã QR không hợp lệ hoặc đã bị khóa');
  END IF;

  SELECT id, name INTO v_store FROM stores WHERE id = v_channel.store_id;

  SELECT jsonb_agg(jsonb_build_object(
    'id', id,
    'name', name,
    'sell_price', sell_price,
    'category', COALESCE(category, 'Khác'),
    'unit', unit,
    'is_available', COALESCE(is_available, true),
    'stock_qty', COALESCE(stock_qty, 999)
  ))
  INTO v_products
  FROM products
  WHERE store_id = v_channel.store_id
    AND is_active = true
    AND is_deleted = false
    AND (is_topping IS NULL OR is_topping = false);

  SELECT jsonb_agg(jsonb_build_object(
    'id', id,
    'name', name,
    'sell_price', sell_price,
    'unit', unit
  ))
  INTO v_toppings
  FROM products
  WHERE store_id = v_channel.store_id
    AND is_active = true
    AND is_deleted = false
    AND is_topping = true;

  SELECT jsonb_agg(jsonb_build_object(
    'product_id', product_id,
    'topping_id', topping_id
  ))
  INTO v_topping_links
  FROM product_topping_links
  WHERE product_id IN (
    SELECT id FROM products WHERE store_id = v_channel.store_id
  );

  RETURN jsonb_build_object(
    'success', true,
    'store_id', v_store.id,
    'store_name', v_store.name,
    'channel_type', v_channel.type,
    'table_id', v_channel.table_id,
    'table_name', v_channel.name,
    'products', COALESCE(v_products, '[]'::jsonb),
    'toppings', COALESCE(v_toppings, '[]'::jsonb),
    'topping_links', COALESCE(v_topping_links, '[]'::jsonb)
  );
END;
$$;

-- 4. RESTORE PRE-V2 VERSION OF submit_qr_order(text, jsonb, text)
CREATE OR REPLACE FUNCTION submit_qr_order(
  p_channel_code text,
  p_items        jsonb,
  p_note         text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_channel        record;
  v_product        record;
  v_topping        record;
  v_link_exists    boolean;
  v_request_id     uuid;
  v_tracking_token text;
  v_pickup_code    text;
  v_item           record;
  v_topping_item   record;
  v_unit_price     numeric(12,0);
  v_topping_price  numeric(12,0);
  v_total          numeric(12,0) := 0;
  v_seq            int;
BEGIN
  SELECT id, store_id, type, table_id, name, is_active
  INTO v_channel
  FROM qr_channels
  WHERE channel_code = p_channel_code AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Kênh QR không tồn tại hoặc đã tạm dừng');
  END IF;

  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Vui lòng chọn ít nhất 1 món');
  END IF;

  IF jsonb_array_length(p_items) > 50 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Mỗi đơn không được vượt quá 50 món');
  END IF;

  IF length(p_note) > 500 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Ghi chú không được dài quá 500 ký tự');
  END IF;

  p_note := regexp_replace(p_note, '<[^>]*>', '', 'g');

  v_tracking_token := encode(gen_random_bytes(16), 'hex');

  IF v_channel.type = 'counter' THEN
    SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
    FROM qr_requests
    WHERE store_id = v_channel.store_id
      AND type = 'counter'
      AND created_at >= CURRENT_DATE;
    v_pickup_code := '#Q' || LPAD(v_seq::text, 2, '0');
  END IF;

  INSERT INTO qr_requests (
    store_id, channel_id, type, table_id, table_name, pickup_code, tracking_token, status, note, total_amount
  ) VALUES (
    v_channel.store_id, v_channel.id, v_channel.type, v_channel.table_id, v_channel.name, v_pickup_code, v_tracking_token, 'pending_staff', p_note, 0
  ) RETURNING id INTO v_request_id;

  FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
    product_id uuid,
    quantity int,
    toppings jsonb,
    note text
  ) LOOP
    IF v_item.quantity <= 0 OR v_item.quantity > 99 THEN
      RAISE EXCEPTION 'Số lượng món phải từ 1 đến 99';
    END IF;

    SELECT id, name, sell_price, is_available
    INTO v_product
    FROM products
    WHERE id = v_item.product_id
      AND store_id = v_channel.store_id
      AND is_active = true
      AND is_deleted = false
      AND (is_topping IS NULL OR is_topping = false);

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Sản phẩm ID % không tồn tại hoặc đã ngưng bán', v_item.product_id;
    END IF;

    IF v_product.is_available = false THEN
      RAISE EXCEPTION 'Sản phẩm "%" hiện đang tạm hết hàng', v_product.name;
    END IF;

    v_unit_price := v_product.sell_price;
    v_topping_price := 0;

    IF v_item.toppings IS NOT NULL AND jsonb_array_length(v_item.toppings) > 0 THEN
      FOR v_topping_item IN SELECT * FROM jsonb_to_recordset(v_item.toppings) AS t(topping_id uuid) LOOP
        SELECT id, name, sell_price
        INTO v_topping
        FROM products
        WHERE id = v_topping_item.topping_id
          AND store_id = v_channel.store_id
          AND is_active = true
          AND is_deleted = false
          AND is_topping = true;

        IF NOT FOUND THEN
          RAISE EXCEPTION 'Topping ID % không hợp lệ', v_topping_item.topping_id;
        END IF;

        SELECT EXISTS (
          SELECT 1 FROM product_topping_links
          WHERE product_id = v_product.id AND topping_id = v_topping_item.topping_id
        ) INTO v_link_exists;

        IF NOT v_link_exists THEN
          RAISE EXCEPTION 'Topping "%" không hợp lệ cho món "%"', v_topping.name, v_product.name;
        END IF;

        v_topping_price := v_topping_price + COALESCE(v_topping.sell_price, 0);
      END LOOP;
    END IF;

    v_unit_price := v_unit_price + v_topping_price;
    v_item.note := regexp_replace(COALESCE(v_item.note, ''), '<[^>]*>', '', 'g');

    INSERT INTO qr_request_items (
      request_id, product_id, product_name, unit_price, quantity, modifiers_json, note
    ) VALUES (
      v_request_id, v_product.id, v_product.name, v_unit_price, v_item.quantity, v_item.toppings::text, v_item.note
    );

    v_total := v_total + (v_unit_price * v_item.quantity);
  END LOOP;

  UPDATE qr_requests SET total_amount = v_total WHERE id = v_request_id;

  RETURN jsonb_build_object(
    'success', true,
    'request_id', v_request_id,
    'tracking_token', v_tracking_token,
    'pickup_code', v_pickup_code,
    'status', 'pending_staff',
    'total_amount', v_total
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- 5. RESTORE PERMISSIONS & GRANTS
REVOKE ALL ON FUNCTION submit_qr_order(text, jsonb, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_qr_menu(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION submit_qr_order(text, jsonb, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_qr_menu(text) TO anon, authenticated;
