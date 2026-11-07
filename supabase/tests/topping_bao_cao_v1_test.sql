-- Test 20261104_topping_bao_cao_v1.sql: báo cáo đếm topping chọn kèm món thành dòng riêng.
-- Mọi dữ liệu dựng đều ROLLBACK. Ngày 1 (bán kèm món):
--   A bàn: Trà x2 + 1 trân châu cả dòng ({"qty":1})  75.000 → Trà 70.000, trân châu 1 = 5.000
--   B QR:  Trà x2, mỗi ly 1 trân châu ({"quantity":1}, KHÔNG có "type" như dữ liệu QR thật) 80.000 → Trà 70.000, trân châu 2 = 10.000
--   D bàn: Trà x1 + tuỳ chọn "Ít đá" + 2 trân châu      45.000 → Trà 35.000, trân châu 2 = 10.000
--   E:     Trà x1, modifiers_json hỏng (có chữ topping)  35.000 → Trà 35.000 (bỏ qua JSON hỏng)
-- Ngày 2: C quầy: trân châu bán lẻ x3 15.000.
-- Cần: ngày 1 Trà 6 phần / 210.000 (đúng 35.000/phần), trân châu 5 / 25.000; cả hai ngày trân châu 8 / 40.000;
-- lọc "Topping" chỉ ra trân châu; danh mục ngày 1 có "Topping"; Boom: trân châu 8 / 40.000 giá vốn 0.

BEGIN;

DO $$
DECLARE
  v_store uuid := gen_random_uuid();
  v_user  uuid := gen_random_uuid();
  v_dish  uuid := gen_random_uuid();
  v_top   uuid := gen_random_uuid();
  v_opt   uuid := gen_random_uuid();
  o_a uuid := gen_random_uuid(); o_b uuid := gen_random_uuid(); o_c uuid := gen_random_uuid();
  o_d uuid := gen_random_uuid(); o_e uuid := gen_random_uuid();
  d1 timestamptz := '2026-01-01 10:00+07';
  d2 timestamptz := '2026-01-02 10:00+07';
  f1 timestamptz := '2026-01-01 00:00+07';
  f2 timestamptz := '2026-01-02 00:00+07';
  f3 timestamptz := '2026-01-03 00:00+07';
  r record;
  v_cnt int;
  v_sum numeric;
  v_raw jsonb;
BEGIN
  INSERT INTO public.user_accounts(id, phone, password_hash, display_name)
  VALUES (v_user, '+8490' || substr(regexp_replace(v_user::text, '\D', '', 'g'), 1, 7), 'test-only', 'Topping Report Test');
  INSERT INTO public.stores(id, store_code, name, owner_user_id)
  VALUES (v_store, 'TB' || substr(replace(v_store::text, '-', ''), 1, 8), 'Topping Bao Cao Test', v_user);

  INSERT INTO public.products(id, store_id, name, category, sell_price)
  VALUES (v_dish, v_store, 'Trà test', 'Đồ uống', 35000),
         (v_top,  v_store, 'Trân châu test', 'Topping', 5000);

  INSERT INTO public.orders(id, store_id, status, created_at, total_amount, total, order_number, payment_method)
  VALUES (o_a, v_store, 'completed', d1, 75000, 75000, 'TB-A', 'cash'),
         (o_b, v_store, 'completed', d1, 80000, 80000, 'TB-B', 'cash'),
         (o_d, v_store, 'completed', d1, 45000, 45000, 'TB-D', 'cash'),
         (o_e, v_store, 'completed', d1, 35000, 35000, 'TB-E', 'cash'),
         (o_c, v_store, 'completed', d2, 15000, 15000, 'TB-C', 'cash');

  INSERT INTO public.order_items(id, store_id, order_id, name, product_id, product_name, quantity, unit_price, subtotal, modifiers_json)
  VALUES
    (gen_random_uuid(), v_store, o_a, 'Trà test', v_dish, 'Trà test', 2, 37500, 75000,
     jsonb_build_array(jsonb_build_object('type', 'topping', 'id', v_top, 'name', 'Trân châu test', 'price', 5000, 'qty', 1, 'unit', 'phần'))::text),
    (gen_random_uuid(), v_store, o_b, 'Trà test', v_dish, 'Trà test', 2, 40000, 80000,
     -- dạng QR thật (qr_price_items_v4): không có "type"; kèm 1 phần tử lạ dạng chữ
     jsonb_build_array('lạ'::text, jsonb_build_object('id', v_top, 'name', 'Trân châu test', 'price', 5000, 'quantity', 1))::text),
    (gen_random_uuid(), v_store, o_d, 'Trà test', v_dish, 'Trà test', 1, 45000, 45000,
     jsonb_build_array(
       jsonb_build_object('id', v_opt, 'name', 'Ít đá', 'price_adjust', 0),
       jsonb_build_object('type', 'topping', 'id', v_top, 'name', 'Trân châu test', 'price', 5000, 'qty', 2, 'unit', 'phần'))::text),
    (gen_random_uuid(), v_store, o_e, 'Trà test', v_dish, 'Trà test', 1, 35000, 35000, '[{"type":"topping", hỏng'),
    (gen_random_uuid(), v_store, o_c, 'Trân châu test', v_top, 'Trân châu test', 3, 5000, 15000, NULL);

  -- Ngày 1: món chính về đúng giá, trân châu bán kèm được đếm
  SELECT * INTO r FROM public.get_top_products_for_range_v1(v_store, f1, f2, NULL, 20) t WHERE t.product_id = v_dish::text;
  IF NOT FOUND OR r.total_qty <> 6 OR r.total_revenue <> 210000 THEN
    RAISE EXCEPTION 'TOPPING_BAO_CAO_V1_TEST_FAIL: Trà ngày 1 % phần / % (cần 6 / 210000)', r.total_qty, r.total_revenue;
  END IF;
  SELECT * INTO r FROM public.get_top_products_for_range_v1(v_store, f1, f2, NULL, 20) t WHERE t.product_id = v_top::text;
  IF NOT FOUND OR r.total_qty <> 5 OR r.total_revenue <> 25000 OR r.product_name <> 'Trân châu test' THEN
    RAISE EXCEPTION 'TOPPING_BAO_CAO_V1_TEST_FAIL: trân châu ngày 1 % phần / % (cần 5 / 25000)', r.total_qty, r.total_revenue;
  END IF;
  SELECT sum(t.total_revenue) INTO v_sum FROM public.get_top_products_for_range_v1(v_store, f1, f2, NULL, 20) t;
  IF v_sum <> 235000 THEN
    RAISE EXCEPTION 'TOPPING_BAO_CAO_V1_TEST_FAIL: tổng ngày 1 % (cần 235000 = tổng đơn)', v_sum;
  END IF;

  -- Hai ngày + lọc danh mục "Topping": cộng cả trân châu bán lẻ
  SELECT count(*) INTO v_cnt FROM public.get_top_products_for_range_v1(v_store, f1, f3, 'Topping', 20);
  SELECT * INTO r FROM public.get_top_products_for_range_v1(v_store, f1, f3, 'Topping', 20);
  IF v_cnt <> 1 OR r.product_id <> v_top::text OR r.total_qty <> 8 OR r.total_revenue <> 40000 THEN
    RAISE EXCEPTION 'TOPPING_BAO_CAO_V1_TEST_FAIL: lọc Topping % dòng, % phần / % (cần 1 dòng 8 / 40000)', v_cnt, r.total_qty, r.total_revenue;
  END IF;

  -- Danh mục ngày 1: "Topping" chỉ có trong modifiers_json vẫn phải hiện
  IF NOT EXISTS (SELECT 1 FROM public.get_sold_categories_for_range_v1(v_store, f1, f2) c WHERE c.category = 'Topping')
     OR NOT EXISTS (SELECT 1 FROM public.get_sold_categories_for_range_v1(v_store, f1, f2) c WHERE c.category = 'Đồ uống') THEN
    RAISE EXCEPTION 'TOPPING_BAO_CAO_V1_TEST_FAIL: danh mục ngày 1 thiếu Topping hoặc Đồ uống';
  END IF;

  -- Boom: cùng cách đếm, topping giá vốn 0
  v_raw := public.boom_sales_raw_v1(v_store, f1, f3);
  SELECT (e->>'qty')::numeric AS q, (e->>'revenue')::numeric AS rev, (e->>'cost')::numeric AS cost INTO r
  FROM jsonb_array_elements(v_raw->'items') e WHERE e->>'id' = v_top::text;
  IF NOT FOUND OR r.q <> 8 OR r.rev <> 40000 OR r.cost <> 0 THEN
    RAISE EXCEPTION 'TOPPING_BAO_CAO_V1_TEST_FAIL: Boom trân châu % / % / giá vốn % (cần 8 / 40000 / 0)', r.q, r.rev, r.cost;
  END IF;
  SELECT (e->>'qty')::numeric AS q, (e->>'revenue')::numeric AS rev, 0::numeric AS cost INTO r
  FROM jsonb_array_elements(v_raw->'items') e WHERE e->>'id' = v_dish::text;
  IF NOT FOUND OR r.q <> 6 OR r.rev <> 210000 THEN
    RAISE EXCEPTION 'TOPPING_BAO_CAO_V1_TEST_FAIL: Boom Trà % / % (cần 6 / 210000)', r.q, r.rev;
  END IF;

  RAISE NOTICE 'TOPPING_BAO_CAO_V1_TEST_PASS: topping bán kèm được đếm riêng (bàn qty tổng dòng, QR quantity × số món), món chính đúng giá, tổng không đổi, danh mục + Boom khớp';
END;
$$;

ROLLBACK;
