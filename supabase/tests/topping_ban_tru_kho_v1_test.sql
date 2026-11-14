-- Test 20261103_topping_ban_tru_kho_v1.sql: thanh toán bàn trừ kho topping đúng số đã bán.
-- Chạy thật settle_ban_session_v5; mọi dữ liệu dựng và mọi tác động đều ROLLBACK.
--   Dòng 1 (bàn):  2 ly + 1 trân châu cả dòng  ({"qty":1})       → trừ 1 (bản cũ trừ 2)
--   Dòng 2 (bàn):  1 ly + 3 trân châu           ({"qty":3})       → trừ 3 (bản cũ trừ 1)
--   Dòng 3 (QR):   2 ly, mỗi ly 1 trân châu     ({"quantity":1})  → trừ 2 (giữ nguyên)
--   Dòng 4 (bàn):  1 ly + tuỳ chọn "Ít đá" (cả dòng product_modifiers như app ghi) + 1 trân châu
--                  → thu tiền được, không trừ kho tuỳ chọn (bản cũ: lỗi khoá ngoại, huỷ cả lần thu)
--   Dòng 5 (QC 04/11): 1 ly + topping "qty":"abc" (chữ) + phần tử id "khong-phai-uuid"
--                  → thu tiền được: qty lạ coi như thiếu (1 × 1 ly), id lạ bỏ qua (bản cũ: lỗi ép kiểu)
--   Dòng 6: 1 ly + 2 phần "Trân châu CT" (topping có công thức 10 g bột/phần) → trừ 20 g bột
-- Tổng trân châu trừ 8 (bản cũ 5 rồi lỗi); món trừ 8 ly; bột trừ 20 g.

BEGIN;

DO $$
DECLARE
  v_store_id   uuid := gen_random_uuid();
  v_user_id    uuid := gen_random_uuid();
  v_table_uuid uuid := gen_random_uuid();
  v_dish_id    uuid := gen_random_uuid();
  v_top_id     uuid := gen_random_uuid();
  v_opt_id     uuid := gen_random_uuid();
  v_top2_id    uuid := gen_random_uuid();
  v_ing_id     uuid := gen_random_uuid();
  v_rec_id     uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_zone_id    text := 'tt-' || substr(gen_random_uuid()::text, 1, 8);
  v_result     jsonb;
  v_settle_id  uuid;
  v_top_stock  numeric;
  v_dish_stock numeric;
  v_top_moves  int;
  v_top_sum    numeric;
  v_ing_stock  numeric;
  v_ing_sum    numeric;
BEGIN
  INSERT INTO public.user_accounts(id, phone, password_hash, display_name)
  VALUES (v_user_id, '+8490' || substr(regexp_replace(v_user_id::text, '\D', '', 'g'), 1, 7),
          'test-only', 'Topping Test Cashier');

  INSERT INTO public.stores(id, store_code, name, owner_user_id)
  VALUES (v_store_id, 'TT' || substr(replace(v_store_id::text, '-', ''), 1, 8),
          'Topping Ban Tru Kho Test', v_user_id);

  INSERT INTO public.store_members(id, user_id, store_id, role, is_owner)
  VALUES (gen_random_uuid(), v_user_id, v_store_id, 'owner', true);

  INSERT INTO public.ban_zones(id, store_id, name, created_at)
  VALUES (v_zone_id, v_store_id, 'Topping Zone',
          extract(epoch FROM clock_timestamp())::bigint * 1000);

  INSERT INTO public.ban_dining_tables(
    id, store_id, zone_id, name, capacity, pos_x, pos_y, shape,
    table_width, table_height, sort_order, is_active, created_at, label
  ) VALUES (
    v_table_uuid::text, v_store_id, v_zone_id, 'T1 Topping', 4, 100, 100,
    'rect', 90, 65, 0, true,
    extract(epoch FROM clock_timestamp())::bigint * 1000, 'T1 Topping'
  );

  INSERT INTO public.products(id, store_id, name, sell_price, stock_qty)
  VALUES (v_dish_id, v_store_id, 'Trà test', 35000, 10),
         (v_top_id,  v_store_id, 'Trân châu test', 5000, 100);

  -- Topping có công thức: trừ nguyên liệu theo số phần topping
  INSERT INTO public.products(id, store_id, name, sell_price, stock_qty, unit)
  VALUES (v_top2_id, v_store_id, 'Trân châu CT test', 6000, 0, 'phần'),
         (v_ing_id,  v_store_id, 'Bột năng test', 0, 1000, 'g');
  INSERT INTO public.recipes(id, store_id, name, serving_size, pos_product_id, is_active, is_deleted)
  VALUES (v_rec_id, v_store_id, 'CT trân châu test', 1, v_top2_id, true, false);
  INSERT INTO public.recipe_ingredients(id, recipe_id, ingredient_id, quantity, unit, yield_factor)
  VALUES (gen_random_uuid(), v_rec_id, v_ing_id, 10, 'g', 1);

  INSERT INTO public.product_modifiers(id, store_id, product_id, group_name, name, price_adjust, sort_order, is_active)
  VALUES (v_opt_id, v_store_id, v_dish_id, 'Đá', 'Ít đá', 0, 0, true);

  INSERT INTO public.ban_sessions(id, store_id, table_id, status, waiter_id, total_amount)
  VALUES (v_session_id, v_store_id, v_table_uuid, 'open', v_user_id::text, 332000);

  INSERT INTO public.ban_session_items(
    store_id, session_id, product_id, product_name, unit_price, quantity,
    subtotal, kitchen_status, modifiers_json
  ) VALUES
    (v_store_id, v_session_id, v_dish_id, 'Trà test', 37500, 2, 75000, 'da_gui',
     jsonb_build_array(jsonb_build_object('type', 'topping', 'id', v_top_id, 'name', 'Trân châu test',
                                          'price', 5000, 'qty', 1, 'unit', 'phần'))::text),
    (v_store_id, v_session_id, v_dish_id, 'Trà test', 50000, 1, 50000, 'da_gui',
     jsonb_build_array(jsonb_build_object('type', 'topping', 'id', v_top_id, 'name', 'Trân châu test',
                                          'price', 5000, 'qty', 3, 'unit', 'phần'))::text),
    (v_store_id, v_session_id, v_dish_id, 'Trà test', 40000, 2, 80000, 'da_gui',
     jsonb_build_array(jsonb_build_object('id', v_top_id, 'type', 'topping', 'name', 'Trân châu test',
                                          'price', 5000, 'quantity', 1))::text);

  -- Món bàn có tuỳ chọn: app ghi nguyên dòng product_modifiers (có id tuỳ chọn) + topping.
  INSERT INTO public.ban_session_items(
    store_id, session_id, product_id, product_name, unit_price, quantity,
    subtotal, kitchen_status, modifiers_json
  )
  SELECT v_store_id, v_session_id, v_dish_id, 'Trà test', 40000, 1, 40000, 'da_gui',
         jsonb_build_array(to_jsonb(m), jsonb_build_object('type', 'topping', 'id', v_top_id,
           'name', 'Trân châu test', 'price', 5000, 'qty', 1, 'unit', 'phần'))::text
  FROM public.product_modifiers m WHERE m.id = v_opt_id;

  -- Dữ liệu lạ: số topping ghi bằng chữ, phần tử có id không phải uuid.
  INSERT INTO public.ban_session_items(
    store_id, session_id, product_id, product_name, unit_price, quantity,
    subtotal, kitchen_status, modifiers_json
  ) VALUES (v_store_id, v_session_id, v_dish_id, 'Trà test', 40000, 1, 40000, 'da_gui',
     jsonb_build_array(
       jsonb_build_object('type', 'topping', 'id', v_top_id, 'name', 'Trân châu test', 'price', 5000, 'qty', 'abc'),
       jsonb_build_object('type', 'topping', 'id', 'khong-phai-uuid', 'name', 'Lạ', 'price', 0, 'qty', 1))::text);

  INSERT INTO public.ban_session_items(
    store_id, session_id, product_id, product_name, unit_price, quantity,
    subtotal, kitchen_status, modifiers_json
  ) VALUES (v_store_id, v_session_id, v_dish_id, 'Trà test', 47000, 1, 47000, 'da_gui',
     jsonb_build_array(jsonb_build_object('type', 'topping', 'id', v_top2_id, 'name', 'Trân châu CT test',
                                          'price', 6000, 'qty', 2, 'unit', 'phần'))::text);

  PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

  v_result := public.settle_ban_session_v5(
    v_session_id, v_store_id, 'cash', 'topping-ban-tru-kho-test', NULL, 0, 0, NULL, 0
  );
  IF v_result->>'success' <> 'true'
     OR (v_result->'data'->>'total_amount')::numeric <> 332000 THEN
    RAISE EXCEPTION 'TOPPING_BAN_TRU_KHO_V1_TEST_FAIL: thanh toán: %', v_result;
  END IF;
  v_settle_id := (v_result->'data'->>'settlement_id')::uuid;

  SELECT stock_qty INTO v_top_stock FROM public.products WHERE id = v_top_id;
  SELECT stock_qty INTO v_dish_stock FROM public.products WHERE id = v_dish_id;
  SELECT count(*), COALESCE(sum(delta), 0) INTO v_top_moves, v_top_sum
  FROM public.stock_movements WHERE reference_id = v_settle_id AND product_id = v_top_id;

  IF v_top_stock <> 92 OR v_top_moves <> 5 OR v_top_sum <> -8 THEN
    RAISE EXCEPTION 'TOPPING_BAN_TRU_KHO_V1_TEST_FAIL: trân châu còn % (cần 92), % phiếu, tổng % (cần -8)',
      v_top_stock, v_top_moves, v_top_sum;
  END IF;
  IF v_dish_stock <> 2 THEN
    RAISE EXCEPTION 'TOPPING_BAN_TRU_KHO_V1_TEST_FAIL: món còn % (cần 2)', v_dish_stock;
  END IF;
  SELECT stock_qty INTO v_ing_stock FROM public.products WHERE id = v_ing_id;
  SELECT COALESCE(sum(delta), 0) INTO v_ing_sum FROM public.stock_movements
  WHERE reference_id = v_settle_id AND product_id = v_ing_id;
  IF v_ing_stock <> 980 OR v_ing_sum <> -20 THEN
    RAISE EXCEPTION 'TOPPING_BAN_TRU_KHO_V1_TEST_FAIL: bột còn % (cần 980), trừ % (cần -20)', v_ing_stock, v_ing_sum;
  END IF;

  RAISE NOTICE 'TOPPING_BAN_TRU_KHO_V1_TEST_PASS: bàn trừ đúng tổng dòng (1 + 3 + 1), QR giữ quantity × số món (2), món có tuỳ chọn thu tiền được, dữ liệu lạ không làm hỏng lần thu, topping có công thức trừ nguyên liệu đúng';
END;
$$;

ROLLBACK;
