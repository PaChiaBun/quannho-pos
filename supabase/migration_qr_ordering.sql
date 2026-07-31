-- ═══════════════════════════════════════════════════════════════════════════
-- QUÁN NHỎ POS — SQL Migration: Module QR Gọi Món (Strict Security & RLS)
-- Note: KHÔNG tự động apply migration này lên Supabase production.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. BẢNG QR_CHANNELS (Quản lý Kênh QR: Bàn / Quầy)
CREATE TABLE IF NOT EXISTS qr_channels (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id     uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  type         text NOT NULL DEFAULT 'table' CHECK (type IN ('table', 'counter')),
  table_id     uuid REFERENCES ban_dining_tables(id) ON DELETE SET NULL,
  channel_code text UNIQUE NOT NULL,          -- Random entropy token (VD: "TBL_8F3A912C")
  name         text NOT NULL,                -- VD: "Bàn A01", "Quầy Thu Ngân"
  is_active    boolean DEFAULT true,
  created_at   timestamptz DEFAULT now()
);

-- 2. BẢNG QR_REQUESTS (Đơn gọi món chờ nhân viên xác nhận)
CREATE TABLE IF NOT EXISTS qr_requests (
  id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id       uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  channel_id     uuid REFERENCES qr_channels(id) ON DELETE SET NULL,
  type           text NOT NULL DEFAULT 'table' CHECK (type IN ('table', 'counter')),
  table_id       uuid,
  table_name     text,
  pickup_code    text,                          -- VD: "#Q01", "#Q02" (Cho Counter mode)
  tracking_token text UNIQUE NOT NULL,          -- Security token cho khách theo dõi trạng thái
  status         text DEFAULT 'pending_staff' CHECK (status IN ('pending_staff', 'processing', 'sent_kitchen', 'rejected', 'expired')),
  note           text,
  total_amount   numeric(12,0) DEFAULT 0,
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now()
);

-- 3. BẢNG QR_REQUEST_ITEMS (Chi tiết các món trong đơn QR)
CREATE TABLE IF NOT EXISTS qr_request_items (
  id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  request_id     uuid NOT NULL REFERENCES qr_requests(id) ON DELETE CASCADE,
  product_id     uuid NOT NULL REFERENCES products(id),
  product_name   text NOT NULL,
  unit_price     numeric(12,0) DEFAULT 0,
  quantity       integer DEFAULT 1 CHECK (quantity > 0 AND quantity <= 99),
  modifiers_json text,
  note           text
);

-- 4. INDEXES
CREATE INDEX IF NOT EXISTS idx_qr_requests_store_status ON qr_requests(store_id, status);
CREATE INDEX IF NOT EXISTS idx_qr_requests_table_id ON qr_requests(table_id);
CREATE INDEX IF NOT EXISTS idx_qr_requests_tracking_token ON qr_requests(tracking_token);
CREATE INDEX IF NOT EXISTS idx_qr_channels_store_code ON qr_channels(store_id, channel_code);

-- 5. ROW LEVEL SECURITY (RLS)
ALTER TABLE qr_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE qr_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE qr_request_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff access qr_channels" ON qr_channels
  FOR ALL TO authenticated
  USING (store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid()));

CREATE POLICY "Staff access qr_requests" ON qr_requests
  FOR ALL TO authenticated
  USING (store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid()))
  WITH CHECK (store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid()));

CREATE POLICY "Staff access qr_request_items" ON qr_request_items
  FOR ALL TO authenticated
  USING (request_id IN (
    SELECT id FROM qr_requests WHERE store_id IN (
      SELECT store_id FROM store_members WHERE user_id = auth.uid()
    )
  ));

-- 6. PUBLIC RPC FUNCTION: TẢI MENU & THÔNG TIN KÊNH QR CHO KHÁCH
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

-- 7. PUBLIC RPC FUNCTION: TẠO ĐƠN QR AN TOÀN CHO ANON CUSTOMER
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

    IF length(v_item.note) > 200 THEN
      RAISE EXCEPTION 'Ghi chú từng món không được quá 200 ký tự';
    END IF;

    SELECT id, name, sell_price, is_available, stock_qty
    INTO v_product
    FROM products
    WHERE id = v_item.product_id
      AND store_id = v_channel.store_id
      AND is_active = true
      AND is_deleted = false
      AND (is_topping IS NULL OR is_topping = false);

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Sản phẩm ID % không tồn tại hoặc là topping', v_item.product_id;
    END IF;

    IF v_product.is_available = false OR v_product.stock_qty <= 0 THEN
      RAISE EXCEPTION 'Sản phẩm % hiện đã hết hàng', v_product.name;
    END IF;

    v_unit_price := v_product.sell_price;
    v_topping_price := 0;

    -- Authoritative Topping Validation (is_topping = true AND product_topping_links check)
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
          RAISE EXCEPTION 'Topping ID % không tồn tại hoặc không phải là topping', v_topping_item.topping_id;
        END IF;

        SELECT EXISTS (
          SELECT 1 FROM product_topping_links
          WHERE product_id = v_product.id AND topping_id = v_topping_item.topping_id
        ) INTO v_link_exists;

        IF NOT v_link_exists THEN
          RAISE EXCEPTION 'Topping % không áp dụng được cho sản phẩm %', v_topping.name, v_product.name;
        END IF;

        v_topping_price := v_topping_price + COALESCE(v_topping.sell_price, 0);
      END LOOP;
    END IF;

    v_unit_price := v_unit_price + v_topping_price;

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

-- 8. PUBLIC RPC FUNCTION: CLAIM QR REQUEST WITH STORE MEMBERSHIP CHECK
CREATE OR REPLACE FUNCTION claim_qr_request(
  p_request_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_affected int;
BEGIN
  UPDATE qr_requests
  SET status = 'processing', updated_at = now()
  WHERE id = p_request_id
    AND status = 'pending_staff'
    AND store_id IN (
      SELECT store_id FROM store_members WHERE user_id = auth.uid()
    );

  GET DIAGNOSTICS v_affected = ROW_COUNT;

  IF v_affected = 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Đơn hàng này đã được xử lý hoặc bạn không có quyền truy cập cửa hàng này');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- 9. PUBLIC RPC FUNCTION: THEO DÕI TRẠNG THÁI BẰNG TRACKING TOKEN
CREATE OR REPLACE FUNCTION get_qr_request_status(
  p_tracking_token text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req record;
BEGIN
  SELECT id, status, table_name, pickup_code, total_amount, updated_at
  INTO v_req
  FROM qr_requests
  WHERE tracking_token = p_tracking_token;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy đơn hàng');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'id', v_req.id,
    'status', v_req.status,
    'table_name', v_req.table_name,
    'pickup_code', v_req.pickup_code,
    'total_amount', v_req.total_amount,
    'updated_at', v_req.updated_at
  );
END;
$$;

-- Grant permissions explicitly
REVOKE ALL ON FUNCTION get_qr_menu(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION submit_qr_order(text, jsonb, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION claim_qr_request(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_qr_request_status(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION get_qr_menu(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION submit_qr_order(text, jsonb, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION claim_qr_request(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_qr_request_status(text) TO anon, authenticated;
