-- ============================================================================
-- HOÀN TÁC 20261026_va_ton_kho_anh_mon_v1.sql — trả adjust_product_stock + chính sách xoá ảnh về như cũ
-- (bản cũ: adjust_product_stock hỏng uuid = text, không kiểm người gọi; mọi authenticated xoá được mọi ảnh món)
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.adjust_product_stock(p_product_id text, p_delta real, p_store_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  UPDATE products
  SET stock_qty  = GREATEST(0, stock_qty + p_delta),
      updated_at = EXTRACT(EPOCH FROM NOW())::BIGINT * 1000
  WHERE id = p_product_id AND store_id = p_store_id AND is_deleted = FALSE;
END;
$function$;
ALTER FUNCTION public.adjust_product_stock(text, real, text) RESET search_path;
REVOKE ALL ON FUNCTION public.adjust_product_stock(text, real, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.adjust_product_stock(text, real, text) TO authenticated, service_role;

DROP POLICY IF EXISTS "product-images delete" ON storage.objects;
CREATE POLICY "product-images delete" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'product-images');
DROP FUNCTION IF EXISTS public.qn_product_image_deletable(text);

COMMIT;
