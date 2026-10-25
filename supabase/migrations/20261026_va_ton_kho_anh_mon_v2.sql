-- ============================================================================
-- VÁ TIẾP adjust_product_stock (rà lại sau khi áp v1, 26/10/2026) — CHƯA áp production, chờ Chủ Quán duyệt
--  numeric + real được PostgreSQL tính bằng double → tồn kho lẻ bị dính rác: 10.25 + 0.1 = 10.3500000014901.
--  → ép p_delta sang numeric trước khi cộng (0.1::real::numeric = 0.1). Phần còn lại giữ nguyên v1.
--  Hoàn tác (về v1): 20261026_va_ton_kho_anh_mon_v2_ROLLBACK.sql
-- ============================================================================
BEGIN;

DO $pf$
DECLARE v_md5 text;
BEGIN
  SELECT md5(prosrc) INTO v_md5 FROM pg_proc WHERE oid = to_regprocedure('public.adjust_product_stock(text, real, text)');
  RAISE NOTICE 'VA_TON_KHO_V2 PREFLIGHT: adjust_product_stock md5=%', v_md5;
  IF v_md5 IS DISTINCT FROM '0e543805c376bc05a8f37c0fc441f803' THEN
    RAISE EXCEPTION 'VA_TON_KHO_V2 PREFLIGHT_FAIL: adjust_product_stock không phải bản v1 (md5 %)', v_md5;
  END IF;
END $pf$;

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
  SET stock_qty  = GREATEST(0, stock_qty + p_delta::numeric),
      updated_at = EXTRACT(EPOCH FROM NOW())::BIGINT * 1000
  WHERE id = p_product_id::uuid AND store_id = v_store AND is_deleted = FALSE;
END;
$function$;
REVOKE ALL ON FUNCTION public.adjust_product_stock(text, real, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.adjust_product_stock(text, real, text) TO authenticated, service_role;

COMMIT;
