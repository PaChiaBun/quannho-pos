-- ============================================================================
-- VÁ QUYỀN: sửa tồn kho + xoá ảnh món giữa các quán (QC 26/10/2026) — CHƯA áp production, chờ Chủ Quán duyệt
--  1. adjust_product_stock(text, real, text): SECURITY DEFINER, không kiểm người gọi ⇒ thành viên quán A sửa
--     được tồn kho quán B. Bản hiện tại còn HỎNG (so uuid = text → lỗi mỗi lần gọi), app/dịch vụ không gọi.
--     → giữ chữ ký; người gọi phải là service_role hoặc thành viên quán (qn_is_member — quán bị khoá cũng chặn);
--       ép kiểu uuid cho đúng; search_path cố định. Quyền: authenticated + service_role (như cũ).
--  2. Chính sách "product-images delete": mọi authenticated xoá được mọi ảnh món
--     → chỉ xoá được ảnh mà MỌI món đang dùng nó (products.image_url kết thúc bằng /product-images/<tên>)
--       đều thuộc quán mình là thành viên. Ảnh không món nào dùng (rác) → chỉ service_role (bộ dọn image_optimizer.py).
--     App (inventory_screen.dart) chỉ xoá ảnh lúc gỡ ảnh khỏi món — món đó vẫn trỏ tới ảnh ⇒ không bị chặn.
--     Hàm kiểm chạy SECURITY DEFINER để thấy cả món quán khác (RLS che mất nếu chạy bằng quyền người gọi).
--  Không có lệnh ROLE (chỉ hàm/chính sách) → chạy bản sao cùng cụm an toàn.
--  Hoàn tác: 20261026_va_ton_kho_anh_mon_v1_ROLLBACK.sql
-- ============================================================================
BEGIN;

DO $pf$
DECLARE v_md5 text;
BEGIN
  SELECT md5(prosrc) INTO v_md5 FROM pg_proc WHERE oid = to_regprocedure('public.adjust_product_stock(text, real, text)');
  RAISE NOTICE 'VA_TON_KHO PREFLIGHT: adjust_product_stock md5=%', v_md5;
  IF v_md5 IS DISTINCT FROM '0f70554f829d044f6395c47101725209' THEN
    RAISE EXCEPTION 'VA_TON_KHO PREFLIGHT_FAIL: adjust_product_stock khác bản đã kiểm (md5 %)', v_md5;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
                 AND policyname = 'product-images delete' AND qual = '(bucket_id = ''product-images''::text)') THEN
    RAISE EXCEPTION 'VA_TON_KHO PREFLIGHT_FAIL: chính sách "product-images delete" khác bản đã kiểm';
  END IF;
  IF to_regprocedure('public.qn_is_member(uuid)') IS NULL THEN RAISE EXCEPTION 'VA_TON_KHO PREFLIGHT_FAIL: thiếu qn_is_member'; END IF;
END $pf$;

-- ── 1. adjust_product_stock ───────────────────────────────────────────────────
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

-- ── 2. Xoá ảnh món ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.qn_product_image_deletable(p_name text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  -- tên đúng mẫu <uuid>.<đuôi ảnh> (không có ký tự đại diện của LIKE)
  SELECT p_name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp)$'
     AND EXISTS (SELECT 1 FROM public.products p
                 WHERE p.image_url LIKE '%/product-images/' || p_name AND public.qn_is_member(p.store_id))
     AND NOT EXISTS (SELECT 1 FROM public.products p
                     WHERE p.image_url LIKE '%/product-images/' || p_name AND NOT public.qn_is_member(p.store_id));
$function$;
REVOKE ALL ON FUNCTION public.qn_product_image_deletable(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.qn_product_image_deletable(text) TO authenticated, service_role;

DROP POLICY "product-images delete" ON storage.objects;
CREATE POLICY "product-images delete" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'product-images' AND public.qn_product_image_deletable(name));

COMMIT;
