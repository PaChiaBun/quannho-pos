-- STAGING ONLY — rebuild KAY topping links after the rehearsal seed created
-- a Cartesian product between every main product and every topping.
-- Hard-gated by the known staging channel and KAY store identity.

BEGIN;

DO $$
DECLARE
  v_store_id uuid;
BEGIN
  SELECT store_id INTO v_store_id
  FROM public.qr_channels
  WHERE channel_code = 'kay_counter_v3' AND is_active = true
  LIMIT 1;

  IF v_store_id IS DISTINCT FROM '79fd45e9-14c3-4dd2-81ba-aa288a45b472'::uuid THEN
    RAISE EXCEPTION 'Safety gate failed: this is not the expected KAY staging dataset.';
  END IF;

  UPDATE public.products
  SET name = 'Aquafina'
  WHERE store_id = v_store_id AND lower(name) = 'aquaifina';

  DELETE FROM public.product_topping_links ptl
  USING public.products main_product
  WHERE main_product.id = ptl.product_id
    AND main_product.store_id = v_store_id;

  -- Drink toppings: milk tea, fruit tea, matcha, latte and yogurt drinks.
  INSERT INTO public.product_topping_links (product_id, topping_id, sort_order)
  SELECT main_product.id, topping.id,
         row_number() OVER (PARTITION BY main_product.id ORDER BY topping.name)::int
  FROM public.products main_product
  JOIN public.products topping ON topping.store_id = main_product.store_id
  WHERE main_product.store_id = v_store_id
    AND main_product.is_topping IS NOT TRUE
    AND topping.is_topping IS TRUE
    AND lower(main_product.name) ~ '(trà|matcha|latte|sữa chua)'
    AND lower(main_product.name) !~ '(trà đường|trà tắc|lipton)'
    AND lower(topping.name) ~ '(flan|pudding|củ năng|dừa sợi|kem thêm|khoai môn|khúc bạch|phô mai|rau câu|trái vải|trân châu)'
  ON CONFLICT (product_id, topping_id) DO NOTHING;

  -- Mì cay / mì kim chi toppings.
  INSERT INTO public.product_topping_links (product_id, topping_id, sort_order)
  SELECT main_product.id, topping.id,
         row_number() OVER (PARTITION BY main_product.id ORDER BY topping.name)::int
  FROM public.products main_product
  JOIN public.products topping ON topping.store_id = main_product.store_id
  WHERE main_product.store_id = v_store_id
    AND main_product.is_topping IS NOT TRUE
    AND topping.is_topping IS TRUE
    AND lower(main_product.name) ~ '(mì kim chi|mì cay)'
    AND lower(topping.name) ~ '(kim chi|bắp cải|bông cải|nấm kim châm|cá viên|xúc xích|tôm \(mì cay\)|bạch tuộc|bò mỹ|bò vn|mực thêm|mì cay thêm|viên thả lẩu)'
  ON CONFLICT (product_id, topping_id) DO NOTHING;

  -- Breakfast noodle toppings, scoped by the base dish name.
  INSERT INTO public.product_topping_links (product_id, topping_id, sort_order)
  SELECT main_product.id, topping.id,
         row_number() OVER (PARTITION BY main_product.id ORDER BY topping.name)::int
  FROM public.products main_product
  JOIN public.products topping ON topping.store_id = main_product.store_id
  WHERE main_product.store_id = v_store_id
    AND main_product.is_topping IS NOT TRUE
    AND topping.is_topping IS TRUE
    AND (
      (lower(main_product.name) LIKE '%hủ tiếu%' AND lower(topping.name) ~ '(hủ tiếu thêm|chả thêm|sườn|tôm \(sáng\)|mực \(sáng\)|rau thêm)') OR
      (lower(main_product.name) LIKE '%mì tươi%' AND lower(topping.name) ~ '(mì tươi thêm|chả thêm|sườn|tôm \(sáng\)|mực \(sáng\)|rau thêm)') OR
      (lower(main_product.name) LIKE '%nui%' AND lower(topping.name) ~ '(nui thêm|sườn|tôm \(sáng\)|mực \(sáng\)|rau thêm)') OR
      (lower(main_product.name) LIKE '%cơm%' AND lower(topping.name) ~ '(trứng thêm|chả thêm|sườn)')
    )
  ON CONFLICT (product_id, topping_id) DO NOTHING;
END;
$$;

COMMIT;
