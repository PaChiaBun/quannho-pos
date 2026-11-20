-- ============================================================================
-- HOÀN TÁC 20261026_va_ton_kho_anh_mon_v2.sql — trả adjust_product_stock về bản v1 (vẫn kiểm thành viên quán)
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.adjust_product_stock(p_product_id text, p_delta real, p_store_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE v_store uuid := p_store_id::uuid; v_role text;
BEGIN
  BEGIN v_role := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role';
  EXCEPTION WHEN OTHERS THEN v_role := NULL; END;
  IF v_role IS DISTINCT FROM 'service_role' AND NOT public.qn_is_member(v_store) THEN
    RAISE EXCEPTION 'STOCK_FORBIDDEN: không phải thành viên quán' USING ERRCODE = '42501';
  END IF;
  UPDATE public.products
  SET stock_qty  = GREATEST(0, stock_qty + p_delta),
      updated_at = EXTRACT(EPOCH FROM NOW())::BIGINT * 1000
  WHERE id = p_product_id::uuid AND store_id = v_store AND is_deleted = FALSE;
END;
$function$;
REVOKE ALL ON FUNCTION public.adjust_product_stock(text, real, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.adjust_product_stock(text, real, text) TO authenticated, service_role;

COMMIT;
