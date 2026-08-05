-- QR menu V3 hotfix: return structured invalid-channel errors and expose only
-- valid, same-store, active product/topping links.

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
BEGIN
  IF p_channel_code IS NULL OR TRIM(p_channel_code) = '' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_CHANNEL', 'message', 'Mã QR không hợp lệ.');
  END IF;

  SELECT c.id, c.store_id, c.type, c.table_id, c.channel_code, s.name AS store_name
  INTO v_channel
  FROM public.qr_channels c
  JOIN public.stores s ON s.id = c.store_id
  WHERE c.channel_code = TRIM(p_channel_code) AND c.is_active = true
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_CHANNEL', 'message', 'Mã QR không tồn tại hoặc đã tạm dừng.');
  END IF;

  IF v_channel.table_id IS NOT NULL THEN
    SELECT COALESCE(name, label, id) INTO v_table_name
    FROM public.ban_dining_tables
    WHERE id = v_channel.table_id;
  ELSE
    v_table_name := 'Quầy Thu Ngân';
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', p.id, 'name', p.name, 'sell_price', p.sell_price,
    'category', p.category, 'unit', p.unit, 'is_available', p.is_available,
    'is_topping', false, 'image_url', p.image_url
  )), '[]'::jsonb)
  INTO v_products
  FROM public.products p
  WHERE p.store_id = v_channel.store_id
    AND p.is_topping IS NOT TRUE
    AND (p.is_available IS TRUE OR p.is_available IS NULL)
    AND (p.is_active IS TRUE OR p.is_active IS NULL)
    AND (p.is_deleted IS FALSE OR p.is_deleted IS NULL);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', p.id, 'name', p.name, 'sell_price', p.sell_price,
    'category', p.category, 'unit', p.unit, 'is_available', p.is_available,
    'is_topping', true, 'image_url', p.image_url
  )), '[]'::jsonb)
  INTO v_toppings
  FROM public.products p
  WHERE p.store_id = v_channel.store_id
    AND p.is_topping IS TRUE
    AND (p.is_available IS TRUE OR p.is_available IS NULL)
    AND (p.is_active IS TRUE OR p.is_active IS NULL)
    AND (p.is_deleted IS FALSE OR p.is_deleted IS NULL);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'product_id', valid_link.product_id,
    'topping_id', valid_link.topping_id,
    'sort_order', valid_link.sort_order
  ) ORDER BY valid_link.sort_order, valid_link.topping_id), '[]'::jsonb)
  INTO v_topping_links
  FROM (
    SELECT DISTINCT ON (ptl.product_id, ptl.topping_id)
      ptl.product_id, ptl.topping_id, COALESCE(ptl.sort_order, 0) AS sort_order
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

  RETURN jsonb_build_object(
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
END;
$$;

REVOKE ALL ON FUNCTION public.get_qr_menu_v3(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_qr_menu_v3(text) TO anon, authenticated;
