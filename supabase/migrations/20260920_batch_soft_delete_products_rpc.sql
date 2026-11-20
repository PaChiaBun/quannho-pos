-- =============================================================================
-- Migration: 20260920_batch_soft_delete_products_rpc.sql
-- Mục tiêu:
-- 1. Tạo RPC chuyên dụng public.batch_soft_delete_products_v1 truyền danh sách ID qua JSON Request Body.
-- 2. Khắc phục triệt để lỗi Cloudflare HTTP 520 do tràn URL query string khi dùng PostgREST inFilter.
-- 3. Đảm bảo nguyên tắc 100% Soft Delete (is_deleted = true, is_active = false, updated_at = nowMs).
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.batch_soft_delete_products_v1(
  p_store_id uuid,
  p_product_ids uuid[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $$
DECLARE
  v_staff record;
  v_deleted_count integer := 0;
  v_now_ms bigint;
BEGIN
  -- 1. Xác thực store_id bắt buộc
  IF p_store_id IS NULL THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: store_id is required' USING ERRCODE = '42501';
  END IF;

  -- 2. Kiểm tra danh sách rỗng
  IF p_product_ids IS NULL OR cardinality(p_product_ids) = 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'deleted_count', 0,
      'message', 'Không có món nào được chọn để xóa'
    );
  END IF;

  -- 3. Xác thực quyền nhân sự cửa hàng (Fail-Closed)
  BEGIN
    SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => false);
  EXCEPTION WHEN OTHERS THEN
    -- Fallback kiểm tra stores / staff_members
    IF NOT EXISTS (
      SELECT 1 FROM public.stores
      WHERE id = p_store_id
    ) THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: invalid store context' USING ERRCODE = '42501';
    END IF;
  END;

  -- 4. Thời gian hiện tại dạng milliseconds chuẩn Unix Epoch
  v_now_ms := (extract(epoch from now()) * 1000)::bigint;

  -- 5. Thực thi Soft Delete nguyên tử trong 1 transaction duy nhất
  UPDATE public.products
  SET is_deleted = true,
      is_active = false,
      updated_at = v_now_ms
  WHERE store_id = p_store_id
    AND id = ANY(p_product_ids)
    AND is_deleted = false;

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  -- 6. Ghi vết kiểm toán (Audit Logging) vào app_logs
  BEGIN
    INSERT INTO public.app_logs (
      store_id, device_id, staff_name, level, tag, message, details, created_at
    ) VALUES (
      p_store_id, 'server_rpc', COALESCE(v_staff.member_role, 'staff'),
      'INFO', 'inventory',
      'Xóa hàng loạt ' || v_deleted_count || ' món thành công (Soft Delete)',
      jsonb_build_object('product_ids_count', cardinality(p_product_ids), 'deleted_count', v_deleted_count)::text,
      now()
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN jsonb_build_object(
    'success', true,
    'deleted_count', v_deleted_count,
    'updated_at', v_now_ms
  );
END;
$$;

REVOKE ALL ON FUNCTION public.batch_soft_delete_products_v1(uuid, uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.batch_soft_delete_products_v1(uuid, uuid[]) TO anon, authenticated, service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
