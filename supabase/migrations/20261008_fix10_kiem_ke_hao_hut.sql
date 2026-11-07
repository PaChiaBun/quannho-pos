-- FIX 10 (08/10/2026) — Kiểm kê kho + ghi hao hụt, xử lý ở server (nguyên tử, không ghi đè tồn khi đang bán)
-- Trước đây bảng stock_counts / stock_count_items KHÔNG tồn tại trên DB thật (code nằm sẵn trong app nhưng chưa có màn hình).
-- 1) Bảng stock_counts, stock_count_items + RLS cô lập theo quán.
-- 2) confirm_stock_count_v1(count_id): áp CHÊNH LỆCH (thực tế - hệ thống lúc đếm) lên tồn hiện tại, khóa dòng sản phẩm.
-- 3) record_stock_waste_v1(product_id, qty, reason, note): trừ hao hụt nguyên tử + ghi stock_movements.
-- Rollback: 20261008_fix10_ROLLBACK.sql
SET search_path = public, extensions, pg_catalog, pg_temp;

CREATE TABLE IF NOT EXISTS public.stock_counts (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  status       text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','confirmed','cancelled')),
  note         text,
  counted_by   text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  confirmed_at timestamptz
);
CREATE TABLE IF NOT EXISTS public.stock_count_items (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  count_id   uuid NOT NULL REFERENCES public.stock_counts(id) ON DELETE CASCADE,
  store_id   uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id),
  system_qty numeric NOT NULL DEFAULT 0,
  actual_qty numeric NOT NULL DEFAULT 0,
  note       text,
  UNIQUE (count_id, product_id)
);
CREATE INDEX IF NOT EXISTS idx_stock_counts_store ON public.stock_counts(store_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_count_items_count ON public.stock_count_items(count_id);

ALTER TABLE public.stock_counts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_count_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS stock_counts_isolation_v5 ON public.stock_counts;
CREATE POLICY stock_counts_isolation_v5 ON public.stock_counts TO anon, authenticated
  USING (store_id = (SELECT public.current_store_id())) WITH CHECK (store_id = (SELECT public.current_store_id()));
DROP POLICY IF EXISTS stock_count_items_isolation_v5 ON public.stock_count_items;
CREATE POLICY stock_count_items_isolation_v5 ON public.stock_count_items TO anon, authenticated
  USING (store_id = (SELECT public.current_store_id())) WITH CHECK (store_id = (SELECT public.current_store_id()));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.stock_counts, public.stock_count_items TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.confirm_stock_count_v1(p_count_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_catalog, pg_temp AS $$
DECLARE v_store uuid := public.current_store_id(); v_count record; v_it record; v_prod record; v_diff numeric; v_changed int := 0;
BEGIN
  IF v_store IS NULL THEN RETURN jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực quán'); END IF;
  SELECT * INTO v_count FROM public.stock_counts WHERE id = p_count_id AND store_id = v_store FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error_code', 'NOT_FOUND', 'message', 'Phiên kiểm kê không tồn tại'); END IF;
  IF v_count.status = 'confirmed' THEN RETURN jsonb_build_object('success', true, 'already_confirmed', true, 'changed', 0); END IF;
  IF v_count.status <> 'draft' THEN RETURN jsonb_build_object('success', false, 'error_code', 'BAD_STATUS', 'message', 'Phiên không còn ở trạng thái nháp'); END IF;
  FOR v_it IN SELECT * FROM public.stock_count_items WHERE count_id = p_count_id AND store_id = v_store ORDER BY product_id LOOP
    v_diff := round(v_it.actual_qty - v_it.system_qty, 3);
    IF v_diff = 0 THEN CONTINUE; END IF;
    SELECT id, stock_qty INTO v_prod FROM public.products WHERE id = v_it.product_id AND store_id = v_store FOR UPDATE;
    IF NOT FOUND THEN CONTINUE; END IF;
    UPDATE public.products SET stock_qty = COALESCE(stock_qty, 0) + v_diff WHERE id = v_it.product_id;
    INSERT INTO public.stock_movements (id, store_id, product_id, delta, reason, reference_id, note, created_at)
    VALUES (gen_random_uuid(), v_store, v_it.product_id, v_diff, 'stock_count', p_count_id,
            CASE WHEN v_diff > 0 THEN 'Kiểm kê: thừa ' ELSE 'Kiểm kê: thiếu ' END || abs(v_diff)::text
              || ' (đếm ' || v_it.actual_qty::text || ', sổ sách ' || v_it.system_qty::text || ')', now());
    v_changed := v_changed + 1;
  END LOOP;
  UPDATE public.stock_counts SET status = 'confirmed', confirmed_at = now() WHERE id = p_count_id;
  RETURN jsonb_build_object('success', true, 'already_confirmed', false, 'changed', v_changed);
END $$;
REVOKE ALL ON FUNCTION public.confirm_stock_count_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_stock_count_v1(uuid) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.record_stock_waste_v1(p_product_id uuid, p_qty numeric, p_reason text DEFAULT 'waste', p_note text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions, pg_catalog, pg_temp AS $$
DECLARE v_store uuid := public.current_store_id(); v_prod record; v_new numeric;
BEGIN
  IF v_store IS NULL THEN RETURN jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực quán'); END IF;
  IF p_qty IS NULL OR p_qty <= 0 THEN RETURN jsonb_build_object('success', false, 'error_code', 'BAD_QTY', 'message', 'Số lượng hao hụt phải lớn hơn 0'); END IF;
  IF p_reason NOT IN ('waste','expired','damaged','spill','loss') THEN RETURN jsonb_build_object('success', false, 'error_code', 'BAD_REASON', 'message', 'Lý do không hợp lệ'); END IF;
  SELECT id, name, unit, stock_qty INTO v_prod FROM public.products WHERE id = p_product_id AND store_id = v_store FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error_code', 'NOT_FOUND', 'message', 'Không tìm thấy sản phẩm'); END IF;
  v_new := COALESCE(v_prod.stock_qty, 0) - p_qty;
  UPDATE public.products SET stock_qty = v_new WHERE id = p_product_id;
  INSERT INTO public.stock_movements (id, store_id, product_id, delta, reason, reference_id, note, created_at)
  VALUES (gen_random_uuid(), v_store, p_product_id, -p_qty, p_reason, NULL, NULLIF(trim(COALESCE(p_note, '')), ''), now());
  RETURN jsonb_build_object('success', true, 'new_stock', v_new, 'unit', v_prod.unit, 'name', v_prod.name);
END $$;
REVOKE ALL ON FUNCTION public.record_stock_waste_v1(uuid, numeric, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_stock_waste_v1(uuid, numeric, text, text) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
