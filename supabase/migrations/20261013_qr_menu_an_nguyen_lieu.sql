-- BẢN VÁ 13/10/2026: menu QR và bước tính giá KHÔNG được bán nguyên liệu (product_type='ingredient' / is_raw_material).
-- Phát hiện: khách thấy 30 món gồm 13 "Nguyên liệu" ở quán Bò Đen. Chỉ thay 2 hàm; quyền EXECUTE giữ nguyên (CREATE OR REPLACE).
BEGIN;
CREATE OR REPLACE FUNCTION public.qr_price_items_v4(p_store_id uuid, p_items jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  c_max_lines constant integer := 50;
  c_max_mods  constant integer := 10;
  c_max_note  constant integer := 300;
  v_item jsonb;
  v_mod jsonb;
  v_prod record;
  v_top record;
  v_clean jsonb := '[]'::jsonb;
  v_mods jsonb;
  v_seen uuid[];
  v_pid uuid;
  v_tid uuid;
  v_qty integer;
  v_tq integer;
  v_tops numeric;
  v_unit numeric;
  v_sub numeric;
  v_total numeric := 0;
  v_note text;
BEGIN
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Danh sách món không hợp lệ');
  END IF;
  IF jsonb_array_length(p_items) = 0 THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Đơn hàng phải có ít nhất một món');
  END IF;
  IF jsonb_array_length(p_items) > c_max_lines THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Đơn có quá nhiều dòng món (tối đa ' || c_max_lines || ')');
  END IF;
  IF pg_column_size(p_items) > 65536 THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Dữ liệu đơn quá lớn');
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items)
  LOOP
    IF jsonb_typeof(v_item) <> 'object' THEN
      RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Dòng món không hợp lệ');
    END IF;
    BEGIN
      v_pid := (v_item->>'product_id')::uuid;
      v_qty := (v_item->>'quantity')::integer;
    EXCEPTION WHEN OTHERS THEN
      RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Mã món hoặc số lượng không hợp lệ');
    END;
    IF v_pid IS NULL OR v_qty IS NULL OR v_qty < 1 OR v_qty > 100 THEN
      RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Số lượng món phải từ 1 đến 100');
    END IF;

    v_note := btrim(COALESCE(v_item->>'note', ''));
    IF char_length(v_note) > c_max_note THEN
      RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Ghi chú tối đa ' || c_max_note || ' ký tự');
    END IF;

    SELECT p.id, p.name, COALESCE(p.sell_price, 0) AS sell_price INTO v_prod
    FROM public.products p
    WHERE p.id = v_pid AND p.store_id = p_store_id
      AND COALESCE(p.is_active, true) AND NOT COALESCE(p.is_deleted, false)
      AND COALESCE(p.is_available, true) AND NOT COALESCE(p.is_topping, false)
      AND COALESCE(p.product_type, 'finished') = 'finished' AND NOT COALESCE(p.is_raw_material, false);
    IF NOT FOUND THEN
      RETURN public.qr_err_v4('PRODUCT_NOT_AVAILABLE', 'Món không tồn tại hoặc đã ngừng phục vụ');
    END IF;

    v_tops := 0;
    v_mods := '[]'::jsonb;
    v_seen := ARRAY[]::uuid[];
    IF v_item ? 'modifiers_json' AND jsonb_typeof(v_item->'modifiers_json') NOT IN ('array', 'null') THEN
      RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Topping không hợp lệ');
    END IF;
    IF jsonb_typeof(v_item->'modifiers_json') = 'array' THEN
      IF jsonb_array_length(v_item->'modifiers_json') > c_max_mods THEN
        RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Quá nhiều topping cho một món');
      END IF;
      FOR v_mod IN SELECT value FROM jsonb_array_elements(v_item->'modifiers_json')
      LOOP
        IF jsonb_typeof(v_mod) <> 'object' THEN
          RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Topping không hợp lệ');
        END IF;
        BEGIN
          v_tid := (v_mod->>'id')::uuid;
          v_tq := COALESCE((v_mod->>'quantity')::integer, 1);
        EXCEPTION WHEN OTHERS THEN
          RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Mã topping hoặc số lượng topping không hợp lệ');
        END;
        IF v_tid IS NULL OR v_tq < 1 OR v_tq > 20 THEN
          RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Số lượng topping phải từ 1 đến 20');
        END IF;
        IF v_tid = ANY (v_seen) THEN
          RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Topping bị lặp trong cùng một món');
        END IF;
        v_seen := array_append(v_seen, v_tid);

        SELECT p.id, p.name, COALESCE(p.sell_price, 0) AS sell_price INTO v_top
        FROM public.products p
        WHERE p.id = v_tid AND p.store_id = p_store_id
          AND COALESCE(p.is_active, true) AND NOT COALESCE(p.is_deleted, false)
          AND COALESCE(p.is_available, true) AND COALESCE(p.is_topping, false)
          AND COALESCE(p.product_type, 'finished') = 'finished' AND NOT COALESCE(p.is_raw_material, false);
        IF NOT FOUND OR NOT EXISTS (
          SELECT 1 FROM public.product_topping_links l
          WHERE l.product_id = v_prod.id AND l.topping_id = v_top.id
        ) THEN
          RETURN public.qr_err_v4('PRODUCT_NOT_AVAILABLE', 'Topping không áp dụng cho món này hoặc đã ngừng phục vụ');
        END IF;

        v_tops := v_tops + v_top.sell_price * v_tq;
        v_mods := v_mods || jsonb_build_array(jsonb_build_object(
          'id', v_top.id, 'name', v_top.name, 'price', v_top.sell_price, 'quantity', v_tq));
      END LOOP;
    END IF;

    v_unit := v_prod.sell_price + v_tops;
    v_sub := v_unit * v_qty;
    v_total := v_total + v_sub;
    v_clean := v_clean || jsonb_build_array(jsonb_build_object(
      'product_id', v_prod.id, 'product_name', v_prod.name, 'unit_price', v_unit,
      'quantity', v_qty, 'subtotal', v_sub, 'modifiers_json', v_mods, 'note', v_note));
  END LOOP;

  RETURN jsonb_build_object('success', true, 'items', v_clean, 'total', v_total);
END
$fn$;

CREATE OR REPLACE FUNCTION public.get_qr_menu_v4(p_channel_code text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ch public.qr_channels%ROWTYPE;
  v_store_name text;
  v_products jsonb;
  v_toppings jsonb;
  v_links jsonb;
  v_tables jsonb := '[]'::jsonb;
BEGIN
  IF p_channel_code IS NULL OR char_length(p_channel_code) > 64 THEN
    RETURN public.qr_err_v4('INVALID_QR', 'Mã QR không hợp lệ');
  END IF;
  SELECT * INTO v_ch FROM public.qr_channels WHERE channel_code = btrim(p_channel_code) AND is_active;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('CHANNEL_DISABLED', 'Kênh gọi món này hiện đang tạm đóng');
  END IF;
  SELECT s.name INTO v_store_name FROM public.stores s WHERE s.id = v_ch.store_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', p.id, 'name', p.name, 'category', p.category, 'sell_price', p.sell_price,
           'image_url', p.image_url, 'is_active', true
         ) ORDER BY p.category, p.name), '[]'::jsonb)
  INTO v_products
  FROM public.products p
  WHERE p.store_id = v_ch.store_id AND COALESCE(p.is_active, true) AND NOT COALESCE(p.is_deleted, false)
    AND COALESCE(p.is_available, true) AND NOT COALESCE(p.is_topping, false)
    AND COALESCE(p.product_type, 'finished') = 'finished' AND NOT COALESCE(p.is_raw_material, false);  -- không bán nguyên liệu

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', p.id, 'name', p.name, 'sell_price', p.sell_price, 'unit', p.unit, 'is_active', true
         ) ORDER BY p.name), '[]'::jsonb)
  INTO v_toppings
  FROM public.products p
  WHERE p.store_id = v_ch.store_id AND COALESCE(p.is_active, true) AND NOT COALESCE(p.is_deleted, false)
    AND COALESCE(p.is_available, true) AND COALESCE(p.is_topping, false)
    AND COALESCE(p.product_type, 'finished') = 'finished' AND NOT COALESCE(p.is_raw_material, false);

  SELECT COALESCE(jsonb_agg(jsonb_build_object('product_id', l.product_id, 'topping_id', l.topping_id)), '[]'::jsonb)
  INTO v_links
  FROM public.product_topping_links l
  JOIN public.products lp ON lp.id = l.product_id AND lp.store_id = v_ch.store_id;

  IF v_ch.type = 'TABLE_SHARED' THEN
    v_tables := public.qr_list_tables_v4(v_ch.store_id);
  END IF;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'store_id', v_ch.store_id, 'store_name', COALESCE(v_store_name, 'Quán Nhỏ'),
    'channel_type', v_ch.type, 'channel_code', v_ch.channel_code, 'payment_mode', v_ch.payment_mode,
    'products', v_products, 'toppings', v_toppings, 'topping_links', v_links, 'tables', v_tables));
END
$fn$;

COMMIT;
