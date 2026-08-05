-- ═══════════════════════════════════════════════════════════════════════════
-- QUÁN NHỎ POS & KAY RESTAURANT — SQL Migration v2: Module QR & Web Public Ordering
-- File: supabase/migration_kay_public_ordering_v2.sql
-- Note: Re-runnable / Idempotent SQL script. DO NOT auto-apply to production.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. BẢNG STORES: Thêm cột slug cho Web Public (VD: 'kay')
ALTER TABLE stores ADD COLUMN IF NOT EXISTS slug text UNIQUE;

-- Gán slug duy nhất 'kay' cho cửa hàng KAY Rạch Giá (ID: 79fd45e9-14c3-4dd2-81ba-aa288a45b472)
UPDATE stores
SET slug = 'kay'
WHERE id = '79fd45e9-14c3-4dd2-81ba-aa288a45b472'
  AND (slug IS NULL OR slug != 'kay');

-- 2. BẢNG PRODUCTS: Bổ sung các cột hiển thị trên Web Frontend
ALTER TABLE products ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE products ADD COLUMN IF NOT EXISTS image_url text;
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_featured boolean DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS public_badge text;
ALTER TABLE products ADD COLUMN IF NOT EXISTS public_sort_order integer DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_topping boolean DEFAULT false;

-- 3. BẢNG QR_CHANNELS (Quản lý Kênh QR: Bàn / Quầy)
CREATE TABLE IF NOT EXISTS qr_channels (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id     uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  type         text NOT NULL DEFAULT 'table' CHECK (type IN ('table', 'counter')),
  table_id     text REFERENCES ban_dining_tables(id) ON DELETE SET NULL,
  channel_code text UNIQUE NOT NULL,
  name         text NOT NULL,
  is_active    boolean DEFAULT true,
  created_at   timestamptz DEFAULT now()
);

-- 4. BẢNG QR_REQUESTS (Đơn gọi món chờ nhân viên xác nhận)
CREATE TABLE IF NOT EXISTS qr_requests (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id         uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  channel_id       uuid REFERENCES qr_channels(id) ON DELETE SET NULL,
  type             text NOT NULL DEFAULT 'table' CHECK (type IN ('table', 'counter')),
  table_id         text,
  table_name       text,
  pickup_code      text,
  tracking_token   text UNIQUE NOT NULL,
  idempotency_key  text,
  status           text DEFAULT 'pending_staff' CHECK (status IN ('pending_staff', 'processing', 'sent_kitchen', 'rejected', 'expired')),
  note             text,
  total_amount     numeric(12,0) DEFAULT 0,
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now()
);

-- Thêm cột idempotency_key an toàn nếu chưa có
ALTER TABLE qr_requests ADD COLUMN IF NOT EXISTS idempotency_key text;

-- 5. BẢNG QR_REQUEST_ITEMS (Chi tiết các món trong đơn QR)
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

-- 6. INDEXES & UNIQUE CONSTRAINTS
CREATE INDEX IF NOT EXISTS idx_qr_requests_store_status ON qr_requests(store_id, status);
CREATE INDEX IF NOT EXISTS idx_qr_requests_table_id ON qr_requests(table_id);
CREATE INDEX IF NOT EXISTS idx_qr_requests_tracking_token ON qr_requests(tracking_token);
CREATE INDEX IF NOT EXISTS idx_qr_channels_store_code ON qr_channels(store_id, channel_code);

-- UNIQUE Partial Index cho Idempotency Key theo Cửa Hàng (Chống Race Condition tuyệt đối)
CREATE UNIQUE INDEX IF NOT EXISTS idx_qr_requests_idempotency_unique
  ON qr_requests (store_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- 7. ROW LEVEL SECURITY (RLS)
ALTER TABLE qr_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE qr_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE qr_request_items ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'qr_channels' AND policyname = 'Staff access qr_channels'
  ) THEN
    CREATE POLICY "Staff access qr_channels" ON qr_channels
      FOR ALL TO authenticated
      USING (store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid()))
      WITH CHECK (store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid()));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'qr_requests' AND policyname = 'Staff access qr_requests'
  ) THEN
    CREATE POLICY "Staff access qr_requests" ON qr_requests
      FOR ALL TO authenticated
      USING (store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid()))
      WITH CHECK (store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid()));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'qr_request_items' AND policyname = 'Staff access qr_request_items'
  ) THEN
    CREATE POLICY "Staff access qr_request_items" ON qr_request_items
      FOR ALL TO authenticated
      USING (request_id IN (
        SELECT id FROM qr_requests WHERE store_id IN (
          SELECT store_id FROM store_members WHERE user_id = auth.uid()
        )
      ));
  END IF;
END $$;

-- 8. PUBLIC RPC FUNCTION: TẢI MENU THEO MÃ QR (p_channel_code)
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

  SELECT id, name, slug INTO v_store FROM stores WHERE id = v_channel.store_id;

  SELECT jsonb_agg(jsonb_build_object(
    'id', id,
    'name', name,
    'sell_price', sell_price,
    'category', COALESCE(category, 'Khác'),
    'unit', unit,
    'description', COALESCE(description, ''),
    'image_url', COALESCE(image_url, ''),
    'is_available', (COALESCE(is_available, true) AND COALESCE(is_active, true) AND NOT COALESCE(is_deleted, false)),
    'is_featured', COALESCE(is_featured, false),
    'public_badge', COALESCE(public_badge, ''),
    'public_sort_order', COALESCE(public_sort_order, 0)
  ) ORDER BY COALESCE(public_sort_order, 0) ASC, name ASC)
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
    'unit', unit,
    'is_available', (COALESCE(is_available, true) AND COALESCE(is_active, true) AND NOT COALESCE(is_deleted, false))
  ) ORDER BY name ASC)
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
    'store_slug', v_store.slug,
    'channel_type', v_channel.type,
    'table_id', v_channel.table_id,
    'table_name', v_channel.name,
    'products', COALESCE(v_products, '[]'::jsonb),
    'toppings', COALESCE(v_toppings, '[]'::jsonb),
    'topping_links', COALESCE(v_topping_links, '[]'::jsonb)
  );
END;
$$;

-- 9. PUBLIC RPC FUNCTION: TẢI MENU CÔNG KHAI THEO STORE SLUG (p_store_slug)
CREATE OR REPLACE FUNCTION get_public_store_menu(
  p_store_slug text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store record;
  v_products jsonb;
  v_toppings jsonb;
  v_topping_links jsonb;
BEGIN
  SELECT id, name, slug INTO v_store FROM stores WHERE slug = p_store_slug AND status != 'suspended';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Cửa hàng không tồn tại hoặc đã tạm ngưng');
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', id,
    'name', name,
    'sell_price', sell_price,
    'category', COALESCE(category, 'Khác'),
    'unit', unit,
    'description', COALESCE(description, ''),
    'image_url', COALESCE(image_url, ''),
    'is_available', (COALESCE(is_available, true) AND COALESCE(is_active, true) AND NOT COALESCE(is_deleted, false)),
    'is_featured', COALESCE(is_featured, false),
    'public_badge', COALESCE(public_badge, ''),
    'public_sort_order', COALESCE(public_sort_order, 0)
  ) ORDER BY COALESCE(public_sort_order, 0) ASC, name ASC)
  INTO v_products
  FROM products
  WHERE store_id = v_store.id
    AND is_active = true
    AND is_deleted = false
    AND (is_topping IS NULL OR is_topping = false);

  SELECT jsonb_agg(jsonb_build_object(
    'id', id,
    'name', name,
    'sell_price', sell_price,
    'unit', unit,
    'is_available', (COALESCE(is_available, true) AND COALESCE(is_active, true) AND NOT COALESCE(is_deleted, false))
  ) ORDER BY name ASC)
  INTO v_toppings
  FROM products
  WHERE store_id = v_store.id
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
    SELECT id FROM products WHERE store_id = v_store.id
  );

  RETURN jsonb_build_object(
    'success', true,
    'store_id', v_store.id,
    'store_name', v_store.name,
    'store_slug', v_store.slug,
    'products', COALESCE(v_products, '[]'::jsonb),
    'toppings', COALESCE(v_toppings, '[]'::jsonb),
    'topping_links', COALESCE(v_topping_links, '[]'::jsonb)
  );
END;
$$;

-- 10. PUBLIC RPC FUNCTION: TẠO ĐƠN QR AN TOÀN KÈM IDEMPOTENCY LOCK & AUTHORITATIVE PRICES
CREATE OR REPLACE FUNCTION submit_qr_order(
  p_channel_code    text,
  p_items           jsonb,
  p_note            text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
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
  v_existing       record;
  v_clean_key      text;
BEGIN
  -- Validate channel
  SELECT id, store_id, type, table_id, name, is_active
  INTO v_channel
  FROM qr_channels
  WHERE channel_code = p_channel_code AND is_active = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Kênh QR không tồn tại hoặc đã tạm dừng');
  END IF;

  -- ATOMIC CONCURRENCY LOCK & IDEMPOTENCY KEY CHECK
  v_clean_key := trim(COALESCE(p_idempotency_key, ''));
  IF length(v_clean_key) > 0 THEN
    -- Acquires a transaction-level lock for this store + key combination to handle race conditions serially
    PERFORM pg_advisory_xact_lock(hashtext(v_channel.store_id::text || '_' || v_clean_key));

    SELECT id, tracking_token, pickup_code, status, total_amount
    INTO v_existing
    FROM qr_requests
    WHERE store_id = v_channel.store_id
      AND idempotency_key = v_clean_key;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'success', true,
        'request_id', v_existing.id,
        'tracking_token', v_existing.tracking_token,
        'pickup_code', v_existing.pickup_code,
        'status', v_existing.status,
        'total_amount', v_existing.total_amount,
        'is_duplicate', true
      );
    END IF;
  ELSE
    v_clean_key := NULL;
  END IF;

  -- Validate Input Limits
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Vui lòng chọn ít nhất 1 món');
  END IF;

  IF jsonb_array_length(p_items) > 50 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Mỗi đơn không được vượt quá 50 món');
  END IF;

  IF length(p_note) > 500 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Ghi chú đơn hàng không được dài quá 500 ký tự');
  END IF;

  -- Sanitize Note to prevent XSS
  p_note := regexp_replace(p_note, '<[^>]*>', '', 'g');

  v_tracking_token := encode(gen_random_bytes(16), 'hex');

  IF v_channel.type = 'counter' THEN
    -- Transaction-level advisory lock to guarantee serial pickup code allocation per store & day
    PERFORM pg_advisory_xact_lock(hashtext(v_channel.store_id::text || '_counter_seq_' || CURRENT_DATE::text));

    SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
    FROM qr_requests
    WHERE store_id = v_channel.store_id
      AND type = 'counter'
      AND created_at >= CURRENT_DATE;
    v_pickup_code := '#Q' || LPAD(v_seq::text, 2, '0');
  END IF;

  INSERT INTO qr_requests (
    store_id, channel_id, type, table_id, table_name, pickup_code, tracking_token, idempotency_key, status, note, total_amount
  ) VALUES (
    v_channel.store_id, v_channel.id, v_channel.type, v_channel.table_id, v_channel.name, v_pickup_code, v_tracking_token, v_clean_key, 'pending_staff', p_note, 0
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

    -- Validate Server-Side Item Note Length Limit (Max 200 chars)
    IF length(COALESCE(v_item.note, '')) > 200 THEN
      RAISE EXCEPTION 'Ghi chú riêng cho món không được dài quá 200 ký tự';
    END IF;

    -- Fetch Product Authoritative Price & Availability
    SELECT id, name, sell_price, is_available, is_active, is_deleted
    INTO v_product
    FROM products
    WHERE id = v_item.product_id
      AND store_id = v_channel.store_id
      AND is_active = true
      AND is_deleted = false
      AND (is_topping IS NULL OR is_topping = false);

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Sản phẩm ID % không tồn tại hoặc không khả dụng', v_item.product_id;
    END IF;

    IF v_product.is_available = false THEN
      RAISE EXCEPTION 'Sản phẩm "%" hiện đã tạm hết hàng', v_product.name;
    END IF;

    v_unit_price := v_product.sell_price;
    v_topping_price := 0;

    -- Validate Toppings (Check Availability strictly)
    IF v_item.toppings IS NOT NULL AND jsonb_array_length(v_item.toppings) > 0 THEN
      FOR v_topping_item IN SELECT * FROM jsonb_to_recordset(v_item.toppings) AS t(topping_id uuid) LOOP
        SELECT id, name, sell_price, is_available
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

        IF COALESCE(v_topping.is_available, true) = false THEN
          RAISE EXCEPTION 'Topping "%" hiện đã tạm hết hàng', v_topping.name;
        END IF;

        SELECT EXISTS (
          SELECT 1 FROM product_topping_links
          WHERE product_id = v_product.id AND topping_id = v_topping_item.topping_id
        ) INTO v_link_exists;

        IF NOT v_link_exists THEN
          RAISE EXCEPTION 'Topping "%" không áp dụng được cho món "%"', v_topping.name, v_product.name;
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
    'total_amount', v_total,
    'is_duplicate', false
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- 11. PUBLIC RPC FUNCTION: CLAIM QR REQUEST WITH STORE MEMBERSHIP CHECK
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
    RETURN jsonb_build_object('success', false, 'message', 'Đơn hàng này đã được xử lý bởi nhân viên khác hoặc bạn không có quyền truy cập cửa hàng này');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- 12. PUBLIC RPC FUNCTION: THEO DÕI TRẠNG THÁI BẰNG TRACKING TOKEN
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

-- 13. GRANT SECURITY & PERMISSIONS
REVOKE ALL ON FUNCTION get_qr_menu(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_public_store_menu(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION submit_qr_order(text, jsonb, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION claim_qr_request(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_qr_request_status(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION get_qr_menu(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_public_store_menu(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION submit_qr_order(text, jsonb, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION claim_qr_request(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_qr_request_status(text) TO anon, authenticated;

-- 14. REALTIME PUBLICATION SETUP (SAFE & IDEMPOTENT)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'qr_requests') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.qr_requests;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'qr_channels') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.qr_channels;
    END IF;
  END IF;
END $$;
