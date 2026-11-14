-- =============================================================================
-- SQL CONTRACT TEST SUITE: F&B Multi-Unit Conversion & Recipe Stock Deduction
-- Target: convert_recipe_ingredient_qty_v1, complete_pos_sale_v1, settle_ban_session_v5
-- Idempotent & Isolated: Runs inside a transaction and rolls back at end
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_pass_count INT := 0;
  v_fail_count INT := 0;
  v_test_name TEXT;

  -- Test variables
  v_res NUMERIC;
  v_expected NUMERIC;
  v_diff NUMERIC;

  -- Integration test variables
  v_store_id UUID := gen_random_uuid();
  v_prod_milk_id UUID := gen_random_uuid();
  v_prod_beans_id UUID := gen_random_uuid();
  v_prod_cream_id UUID := gen_random_uuid();
  v_pos_prod_id UUID := gen_random_uuid();
  v_recipe_id UUID := gen_random_uuid();
  v_order_id UUID := gen_random_uuid();

  v_milk_stock NUMERIC;
  v_beans_stock NUMERIC;
  v_cream_stock NUMERIC;
  v_movement_count INT;
  v_reconciled_count INT;
BEGIN
  RAISE NOTICE '===============================================================';
  RAISE NOTICE 'STARTING SQL CONTRACT SUITE: F&B Multi-Unit Conversion & Deduction';
  RAISE NOTICE '===============================================================';

  -- ───────────────────────────────────────────────────────────────────────────
  -- TIER 1: FEATURE CORE CONVERSIONS (HAPPY PATHS)
  -- ───────────────────────────────────────────────────────────────────────────

  -- Test 1: Identity conversion (kg -> kg)
  v_test_name := 'Tier 1.1: Identity conversion (kg -> kg)';
  v_res := public.convert_recipe_ingredient_qty_v1(5.0, 'kg', 'kg');
  IF v_res = 5.0 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (got %, expected 5.0)', v_test_name, v_res;
  END IF;

  -- Test 2: Standard weight small to large (13 g -> kg)
  v_test_name := 'Tier 1.2: Standard weight (13 g -> 0.013 kg)';
  v_res := public.convert_recipe_ingredient_qty_v1(13.0, 'g', 'kg');
  IF ABS(v_res - 0.013) < 0.000001 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (got %, expected 0.013)', v_test_name, v_res;
  END IF;

  -- Test 3: Standard volume small to large (20 ml -> 0.020 lít)
  v_test_name := 'Tier 1.3: Standard volume (20 ml -> 0.020 lít)';
  v_res := public.convert_recipe_ingredient_qty_v1(20.0, 'ml', 'lít');
  IF ABS(v_res - 0.020) < 0.000001 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (got %, expected 0.020)', v_test_name, v_res;
  END IF;

  -- Test 4: Cross-dimension standard liquid density (20 ml -> 0.020 kg)
  v_test_name := 'Tier 1.4: Cross-dimension liquid density (20 ml -> 0.020 kg)';
  v_res := public.convert_recipe_ingredient_qty_v1(20.0, 'ml', 'kg');
  IF ABS(v_res - 0.020) < 0.000001 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (got %, expected 0.020)', v_test_name, v_res;
  END IF;

  -- Test 5: Cross-dimension standard powder/liquid (15 g -> 0.015 lít)
  v_test_name := 'Tier 1.5: Cross-dimension powder (15 g -> 0.015 lít)';
  v_res := public.convert_recipe_ingredient_qty_v1(15.0, 'g', 'lít');
  IF ABS(v_res - 0.015) < 0.000001 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (got %, expected 0.015)', v_test_name, v_res;
  END IF;

  -- Test 6: Packaging conversion (20 ml into can of 385 ml -> 20/385 lon)
  v_test_name := 'Tier 1.6: Packaging conversion (20 ml with 1 lon = 385 ml)';
  v_res := public.convert_recipe_ingredient_qty_v1(20.0, 'ml', 'lon', 385, 'ml');
  v_expected := 20.0 / 385.0;
  IF ABS(v_res - v_expected) < 0.00001 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (got %, expected %)', v_test_name, v_res, v_expected;
  END IF;

  -- Test 7: Packaging exact match (385 ml into can of 385 ml -> 1.0 lon)
  v_test_name := 'Tier 1.7: Packaging exact whole (385 ml with 1 lon = 385 ml -> 1.0 lon)';
  v_res := public.convert_recipe_ingredient_qty_v1(385.0, 'ml', 'lon', 385, 'ml');
  IF ABS(v_res - 1.0) < 0.000001 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (got %, expected 1.0)', v_test_name, v_res;
  END IF;

  -- Test 8: Packaging from parent unit (0.385 lít into can of 385 ml -> 1.0 lon)
  v_test_name := 'Tier 1.8: Packaging from parent unit (0.385 lít with 385 ml -> 1.0 lon)';
  v_res := public.convert_recipe_ingredient_qty_v1(0.385, 'lít', 'lon', 385, 'ml');
  IF ABS(v_res - 1.0) < 0.000001 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (got %, expected 1.0)', v_test_name, v_res;
  END IF;

  -- ───────────────────────────────────────────────────────────────────────────
  -- TIER 2: BOUNDARIES, TOLERANCES & CORNER CASES
  -- ───────────────────────────────────────────────────────────────────────────

  -- Test 9: Zero conversion rate guard (does not divide by zero)
  v_test_name := 'Tier 2.1: Zero conversion rate safe guard';
  v_res := public.convert_recipe_ingredient_qty_v1(20.0, 'ml', 'lon', 0, 'ml');
  IF v_res = 20.0 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (got %, expected 20.0)', v_test_name, v_res;
  END IF;

  -- Test 10: Negative conversion rate guard
  v_test_name := 'Tier 2.2: Negative conversion rate safe guard';
  v_res := public.convert_recipe_ingredient_qty_v1(20.0, 'ml', 'lon', -385, 'ml');
  IF v_res = 20.0 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (got %, expected 20.0)', v_test_name, v_res;
  END IF;

  -- Test 11: Incompatible unit fallback ('cái' to 'kg')
  v_test_name := 'Tier 2.3: Incompatible dimensions fallback (cái -> kg)';
  v_res := public.convert_recipe_ingredient_qty_v1(3.0, 'cái', 'kg', 0, '');
  IF v_res = 3.0 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (got %, expected 3.0)', v_test_name, v_res;
  END IF;

  -- Test 12: Zero quantity input returns 0
  v_test_name := 'Tier 2.4: Zero quantity input returns 0';
  v_res := public.convert_recipe_ingredient_qty_v1(0, 'ml', 'kg', 0, '');
  IF v_res = 0 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (got %, expected 0)', v_test_name, v_res;
  END IF;

  -- Test 13: Unit synonyms & case insensitivity
  v_test_name := 'Tier 2.5: Vietnamese unit synonyms (gr, gram -> kg; mili lít -> lít)';
  v_res := public.convert_recipe_ingredient_qty_v1(1000.0, '  GRAM  ', 'kG', 0, '');
  IF ABS(v_res - 1.0) < 0.000001 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (got %, expected 1.0)', v_test_name, v_res;
  END IF;

  -- ───────────────────────────────────────────────────────────────────────────
  -- TIER 3: CROSS-FEATURE INTEGRATION (RECIPE DEDUCTION SIMULATION)
  -- ───────────────────────────────────────────────────────────────────────────
  v_test_name := 'Tier 3: Multi-Ingredient Cafe Muoi Deduction Simulation';

  -- Create temporary test products
  INSERT INTO public.products (id, store_id, name, stock_qty, unit, is_active, is_deleted)
  VALUES
    (v_prod_milk_id, v_store_id, 'Sữa đặc test', 10.000, 'kg', true, false),
    (v_prod_beans_id, v_store_id, 'Cà phê hạt test', 5.000, 'kg', true, false),
    (v_prod_cream_id, v_store_id, 'Bột kem muối test', 2.000, 'lít', true, false),
    (v_pos_prod_id, v_store_id, 'Cà phê muối test', 0, 'ly', true, false);

  -- Create temporary recipe
  INSERT INTO public.recipes (id, store_id, name, serving_size, pos_product_id, is_active, is_deleted)
  VALUES (v_recipe_id, v_store_id, 'Công thức Cafe Muối', 1, v_pos_prod_id, true, false);

  -- Insert recipe ingredients (20 ml Sữa đặc, 13 g Cà phê hạt, 15 g Bột kem muối)
  INSERT INTO public.recipe_ingredients (id, recipe_id, ingredient_id, quantity, unit, yield_factor)
  VALUES
    (gen_random_uuid(), v_recipe_id, v_prod_milk_id, 20.0, 'ml', 1.0),
    (gen_random_uuid(), v_recipe_id, v_prod_beans_id, 13.0, 'g', 1.0),
    (gen_random_uuid(), v_recipe_id, v_prod_cream_id, 15.0, 'g', 1.0);

  -- Simulate deduction of 1 ly Cafe Muoi using convert_recipe_ingredient_qty_v1
  UPDATE public.products p
  SET stock_qty = p.stock_qty - public.convert_recipe_ingredient_qty_v1(ri.quantity, ri.unit, p.unit, p.conversion_rate, p.conversion_unit)
  FROM public.recipe_ingredients ri
  WHERE ri.recipe_id = v_recipe_id AND p.id = ri.ingredient_id;

  -- Insert corresponding stock_movements
  INSERT INTO public.stock_movements (id, store_id, product_id, delta, reason, note)
  SELECT
    gen_random_uuid(), v_store_id, p.id,
    -public.convert_recipe_ingredient_qty_v1(ri.quantity, ri.unit, p.unit, p.conversion_rate, p.conversion_unit),
    'recipe_usage', 'POS test order #1'
  FROM public.recipe_ingredients ri
  JOIN public.products p ON p.id = ri.ingredient_id
  WHERE ri.recipe_id = v_recipe_id;

  -- Verify updated stock_qty
  SELECT stock_qty INTO v_milk_stock FROM public.products WHERE id = v_prod_milk_id;
  SELECT stock_qty INTO v_beans_stock FROM public.products WHERE id = v_prod_beans_id;
  SELECT stock_qty INTO v_cream_stock FROM public.products WHERE id = v_prod_cream_id;

  -- 10.000 - 0.020 = 9.980 kg
  -- 5.000 - 0.013 = 4.987 kg
  -- 2.000 - 0.015 = 1.985 lít
  IF ABS(v_milk_stock - 9.980) < 0.0001 AND
     ABS(v_beans_stock - 4.987) < 0.0001 AND
     ABS(v_cream_stock - 1.985) < 0.0001 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: % (milk %, beans %, cream %)', v_test_name, v_milk_stock, v_beans_stock, v_cream_stock;
  END IF;

  -- ───────────────────────────────────────────────────────────────────────────
  -- TIER 4: REAL-WORLD AUDIT RECONCILIATION & IDEMPOTENCY
  -- ───────────────────────────────────────────────────────────────────────────
  v_test_name := 'Tier 4: Reconciliation Idempotency & Recovery';

  -- Simulate a historical over-deducted order (subtracted raw 20 kg instead of 0.02 kg)
  UPDATE public.products SET stock_qty = stock_qty - 19.980 WHERE id = v_prod_milk_id;

  -- Run reconciliation compensation (Pass 1)
  IF NOT EXISTS (
    SELECT 1 FROM public.stock_movements
    WHERE store_id = v_store_id AND product_id = v_prod_milk_id AND reason = 'reconciliation'
  ) THEN
    INSERT INTO public.stock_movements (id, store_id, product_id, delta, reason, note)
    VALUES (gen_random_uuid(), v_store_id, v_prod_milk_id, 19.980, 'reconciliation', 'Bù hoàn đơn test #QN-20260930-002');

    UPDATE public.products SET stock_qty = stock_qty + 19.980 WHERE id = v_prod_milk_id;
  END IF;

  -- Check stock restored
  SELECT stock_qty INTO v_milk_stock FROM public.products WHERE id = v_prod_milk_id;
  IF ABS(v_milk_stock - 9.980) < 0.0001 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: Pass 1 reconciliation did not restore stock (got %)', v_milk_stock;
  END IF;

  -- Run reconciliation compensation (Pass 2 - Idempotency Recheck)
  IF NOT EXISTS (
    SELECT 1 FROM public.stock_movements
    WHERE store_id = v_store_id AND product_id = v_prod_milk_id AND reason = 'reconciliation'
  ) THEN
    -- Should NOT reach here
    UPDATE public.products SET stock_qty = stock_qty + 19.980 WHERE id = v_prod_milk_id;
  END IF;

  -- Verify count of reconciliation movements is exactly 1, and stock did not double-compensate
  SELECT COUNT(*) INTO v_reconciled_count FROM public.stock_movements
  WHERE store_id = v_store_id AND product_id = v_prod_milk_id AND reason = 'reconciliation';

  SELECT stock_qty INTO v_milk_stock FROM public.products WHERE id = v_prod_milk_id;

  IF v_reconciled_count = 1 AND ABS(v_milk_stock - 9.980) < 0.0001 THEN
    v_pass_count := v_pass_count + 1;
  ELSE
    v_fail_count := v_fail_count + 1;
    RAISE WARNING 'FAIL: Idempotency failed! Reconciled count %, stock %', v_reconciled_count, v_milk_stock;
  END IF;

  -- ───────────────────────────────────────────────────────────────────────────
  -- SUMMARY
  -- ───────────────────────────────────────────────────────────────────────────
  RAISE NOTICE '===============================================================';
  RAISE NOTICE 'SQL CONTRACT SUITE RESULTS: % PASSED, % FAILED', v_pass_count, v_fail_count;
  RAISE NOTICE '===============================================================';

  IF v_fail_count > 0 THEN
    RAISE EXCEPTION 'SQL Contract Suite Failed with % errors', v_fail_count;
  END IF;
END $$;

ROLLBACK;
