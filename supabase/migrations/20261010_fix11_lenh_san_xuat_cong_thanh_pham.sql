-- FIX 11 (10/10/2026) — Lệnh sản xuất: trừ nguyên liệu VÀ CỘNG thành phẩm/bán thành phẩm vào kho, nguyên tử ở server.
-- Trước đây app chỉ trừ nguyên liệu (client đọc-rồi-ghi, lỗi trừ kho bị nuốt nhưng vẫn đánh dấu "done"), KHÔNG cộng thành phẩm
--   → vd pha 16 lít cốt trà từ 1 kg trà thì tồn "Cốt trà đen" không bao giờ tăng.
-- complete_production_order_v1(order_id):
--   * khóa lệnh (idempotent: gọi lại trả already_completed, không trừ/cộng thêm), chỉ lệnh pending/in_progress
--   * trừ từng nguyên liệu theo quy đổi đơn vị (convert_recipe_ingredient_qty_v1) + hao phí, ghi stock_movements 'production'
--   * ghi production_logs (qty theo đơn vị công thức, giá vốn đã quy đổi)
--   * CỘNG thành phẩm = serving_size × số mẻ (đổi sang đơn vị kho) vào sản phẩm gắn với công thức (pos_product_id)
--     khi sản phẩm đó là 'semi_finished' hoặc 'ingredient'; ghi stock_movements 'production_output'
--     và cập nhật cost_price_latest = giá vốn bình quân gia quyền theo đơn vị kho
--   * tất cả trong 1 transaction: lỗi giữa chừng thì hoàn tác toàn bộ
-- Rollback: 20261010_fix11_ROLLBACK.sql (xóa hàm; bút toán đã ghi không xóa)
SET search_path = public, extensions, pg_catalog, pg_temp;

CREATE OR REPLACE FUNCTION public.complete_production_order_v1(p_order_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_catalog, pg_temp AS $$
DECLARE
  v_store uuid := public.current_store_id();
  v_order record; v_recipe record; v_ing record; v_prod record; v_out record;
  v_actual numeric; v_need numeric; v_unit_cost numeric; v_total_cost numeric := 0;
  v_out_qty numeric := 0; v_out_unit text := NULL; v_out_name text := NULL; v_old_stock numeric; v_old_cost numeric; v_new_cost numeric;
  v_batches numeric; v_deducted int := 0;
BEGIN
  IF v_store IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực quán');
  END IF;

  SELECT * INTO v_order FROM public.production_orders WHERE id = p_order_id AND store_id = v_store FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'NOT_FOUND', 'message', 'Không tìm thấy lệnh sản xuất');
  END IF;
  IF v_order.status = 'done' THEN
    RETURN jsonb_build_object('success', true, 'already_completed', true);
  END IF;
  IF v_order.status NOT IN ('pending', 'in_progress') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'BAD_STATUS', 'message', 'Lệnh đã hủy hoặc không còn hợp lệ');
  END IF;
  IF COALESCE(v_order.quantity, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'BAD_QTY', 'message', 'Số lượng sản xuất phải lớn hơn 0');
  END IF;

  SELECT * INTO v_recipe FROM public.recipes WHERE id::text = v_order.recipe_id::text AND store_id = v_store;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'RECIPE_NOT_FOUND', 'message', 'Công thức của lệnh này không còn tồn tại');
  END IF;
  v_batches := v_order.quantity;

  -- 1. Trừ nguyên liệu
  FOR v_ing IN
    SELECT ri.* FROM public.recipe_ingredients ri
    WHERE ri.recipe_id::text = v_recipe.id::text AND ri.ingredient_id IS NOT NULL
    ORDER BY ri.ingredient_id::text, ri.id::text
  LOOP
    SELECT * INTO v_prod FROM public.products WHERE id::text = v_ing.ingredient_id::text AND store_id = v_store FOR UPDATE;
    IF NOT FOUND THEN CONTINUE; END IF;

    -- lượng thực tế theo đơn vị công thức (đã tính hao phí) rồi quy đổi sang đơn vị kho
    v_actual := (v_ing.quantity / CASE WHEN v_ing.yield_factor IS NULL OR v_ing.yield_factor <= 0 THEN 1.0 ELSE v_ing.yield_factor END) * v_batches;
    v_need := public.convert_recipe_ingredient_qty_v1(v_actual, v_ing.unit, v_prod.unit,
                COALESCE(v_prod.conversion_rate, 0), COALESCE(v_prod.conversion_unit, ''));

    UPDATE public.products SET stock_qty = COALESCE(stock_qty, 0) - v_need,
           updated_at = extract(epoch from now()) * 1000 WHERE id = v_prod.id;
    INSERT INTO public.stock_movements (id, store_id, product_id, delta, reason, reference_id, note, created_at)
    VALUES (gen_random_uuid(), v_store, v_prod.id, -round(v_need, 3), 'production', p_order_id,
            'Lệnh SX: ' || v_order.recipe_name || ' × ' || v_batches::text, now());

    -- giá vốn 1 đơn vị công thức = giá/đơn vị kho × (đơn vị kho cho 1 đơn vị công thức)
    v_unit_cost := CASE WHEN COALESCE(v_prod.cost_price_latest, 0) > 0 THEN v_prod.cost_price_latest ELSE COALESCE(v_prod.cost_price, 0) END
                   * public.convert_recipe_ingredient_qty_v1(1, v_ing.unit, v_prod.unit,
                       COALESCE(v_prod.conversion_rate, 0), COALESCE(v_prod.conversion_unit, ''));
    v_total_cost := v_total_cost + v_unit_cost * v_actual;

    INSERT INTO public.production_logs (id, production_order_id, store_id, ingredient_id, ingredient_name,
                                        qty_used, unit, cost_at_time, total_cost, created_at)
    VALUES (gen_random_uuid(), p_order_id::text, v_store, v_prod.id::text, v_prod.name,
            v_actual, v_ing.unit, v_unit_cost, v_unit_cost * v_actual, now());
    v_deducted := v_deducted + 1;
  END LOOP;

  -- 2. Cộng thành phẩm / bán thành phẩm vào kho
  IF v_recipe.pos_product_id IS NOT NULL THEN
    SELECT * INTO v_out FROM public.products
     WHERE id::text = v_recipe.pos_product_id::text AND store_id = v_store FOR UPDATE;
    IF FOUND AND COALESCE(v_out.product_type, '') IN ('semi_finished', 'ingredient') THEN
      v_out_qty := public.convert_recipe_ingredient_qty_v1(
                     COALESCE(v_recipe.serving_size, 1) * v_batches, COALESCE(v_recipe.serving_unit, ''), v_out.unit,
                     COALESCE(v_out.conversion_rate, 0), COALESCE(v_out.conversion_unit, ''));
      IF v_out_qty > 0 THEN
        v_old_stock := COALESCE(v_out.stock_qty, 0);
        v_old_cost  := CASE WHEN COALESCE(v_out.cost_price_latest, 0) > 0 THEN v_out.cost_price_latest ELSE COALESCE(v_out.cost_price, 0) END;
        IF v_total_cost > 0 THEN
          v_new_cost := CASE WHEN v_old_stock > 0 AND v_old_cost > 0
                             THEN (v_old_stock * v_old_cost + v_total_cost) / (v_old_stock + v_out_qty)
                             ELSE v_total_cost / v_out_qty END;
          UPDATE public.products SET cost_price_latest = round(v_new_cost, 6) WHERE id = v_out.id;
        END IF;
        UPDATE public.products SET stock_qty = COALESCE(stock_qty, 0) + v_out_qty,
               updated_at = extract(epoch from now()) * 1000 WHERE id = v_out.id;
        INSERT INTO public.stock_movements (id, store_id, product_id, delta, reason, reference_id, note, created_at)
        VALUES (gen_random_uuid(), v_store, v_out.id, round(v_out_qty, 3), 'production_output', p_order_id,
                'Lệnh SX: ' || v_order.recipe_name || ' × ' || v_batches::text || ' → nhập thành phẩm', now());
        v_out_unit := v_out.unit; v_out_name := v_out.name;
      END IF;
    END IF;
  END IF;

  UPDATE public.production_orders SET status = 'done', completed_at = now() WHERE id = p_order_id;

  RETURN jsonb_build_object('success', true, 'already_completed', false,
    'ingredients_deducted', v_deducted, 'total_cost', round(v_total_cost, 2),
    'output_qty', round(v_out_qty, 3), 'output_unit', v_out_unit, 'output_name', v_out_name);
END $$;

REVOKE ALL ON FUNCTION public.complete_production_order_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_production_order_v1(uuid) TO anon, authenticated, service_role;
NOTIFY pgrst, 'reload schema';
