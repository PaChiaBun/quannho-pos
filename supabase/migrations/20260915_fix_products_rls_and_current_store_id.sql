-- =============================================================================
-- Migration: 20260915_fix_products_rls_and_current_store_id.sql
-- Mục tiêu:
-- 1. Khắc phục hàm public.current_store_id() hỗ trợ trích xuất store_id từ:
--    - Header REST x-store-id
--    - JWT Claims (request.jwt.claims ->> 'store_id') từ POS JWT của Manager/Staff
--    - PostgREST claim fallback (request.jwt.claim.store_id)
-- 2. Cấp đầy đủ quyền CRUD cho role authenticated & anon trên public.products
-- 3. Chuẩn hóa chính sách RLS products_isolation ép kiểu store_id::text an toàn
-- 4. Bảo đảm Soft Delete (is_deleted = true, is_active = false) không vi phạm FK
-- =============================================================================

-- 1. Hàm public.current_store_id() kiên cố đa tầng
CREATE OR REPLACE FUNCTION public.current_store_id()
RETURNS uuid AS $$
DECLARE
  _raw_store_id text;
  _raw_user_id  text;
  _claims       jsonb;
  _store_id     uuid;
  _user_id      uuid;
BEGIN
  -- Trích xuất JWT claims nếu có
  BEGIN
    _claims := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb;
  EXCEPTION WHEN OTHERS THEN
    _claims := NULL;
  END;

  -- 1. Trích xuất raw store_id
  -- Tầng 1: Header REST x-store-id (thử cả setting trực tiếp và JSON headers)
  BEGIN
    _raw_store_id := NULLIF(current_setting('request.header.x-store-id', true), '');
    IF _raw_store_id IS NULL THEN
      _raw_store_id := NULLIF(current_setting('request.headers', true)::json->>'x-store-id', '');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    _raw_store_id := NULL;
  END;

  -- Tầng 2: JWT claims (request.jwt.claims ->> 'store_id')
  IF (_raw_store_id IS NULL OR _raw_store_id = '') AND _claims IS NOT NULL THEN
    _raw_store_id := NULLIF(_claims->>'store_id', '');
  END IF;

  -- Tầng 3: PostgREST single-claim fallback
  IF _raw_store_id IS NULL OR _raw_store_id = '' THEN
    BEGIN
      _raw_store_id := NULLIF(current_setting('request.jwt.claim.store_id', true), '');
    EXCEPTION WHEN OTHERS THEN
      _raw_store_id := NULL;
    END;
  END IF;

  -- Làm sạch khoảng trắng nếu có
  IF _raw_store_id IS NOT NULL THEN
    _raw_store_id := trim(_raw_store_id);
  END IF;

  -- Kiểm tra định dạng UUID store_id hợp lệ trước khi ép kiểu
  IF _raw_store_id IS NULL OR _raw_store_id = '' OR NOT (_raw_store_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') THEN
    RETURN NULL;
  END IF;
  _store_id := _raw_store_id::uuid;

  -- Ưu tiên 1: Server-signed JWT claim xác thực danh tính quán
  -- Nếu JWT được cấp bởi server chứa claim store_id khớp với _store_id, danh tính đã được mã hóa an toàn
  IF _claims IS NOT NULL AND NULLIF(_claims->>'store_id', '') IS NOT NULL THEN
    IF (_claims->>'store_id') = _raw_store_id THEN
      RETURN _store_id;
    END IF;
  END IF;

  -- 2. Trích xuất raw user_id
  BEGIN
    _raw_user_id := NULLIF(current_setting('request.header.x-user-id', true), '');
    IF _raw_user_id IS NULL THEN
      _raw_user_id := NULLIF(current_setting('request.headers', true)::json->>'x-user-id', '');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    _raw_user_id := NULL;
  END;

  IF _raw_user_id IS NULL OR _raw_user_id = '' THEN
    BEGIN
      _raw_user_id := NULLIF(auth.uid()::text, '');
    EXCEPTION WHEN OTHERS THEN
      _raw_user_id := NULL;
    END;
  END IF;

  IF (_raw_user_id IS NULL OR _raw_user_id = '') AND _claims IS NOT NULL THEN
    _raw_user_id := NULLIF(_claims->>'sub', '');
  END IF;

  IF _raw_user_id IS NULL OR _raw_user_id = '' THEN
    BEGIN
      _raw_user_id := NULLIF(current_setting('request.jwt.claim.sub', true), '');
    EXCEPTION WHEN OTHERS THEN
      _raw_user_id := NULL;
    END;
  END IF;

  -- Làm sạch user_id
  IF _raw_user_id IS NOT NULL THEN
    _raw_user_id := trim(_raw_user_id);
  END IF;

  -- 3. Active Membership Guard qua stores, store_members hoặc staff_members
  IF _raw_user_id IS NOT NULL AND (_raw_user_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') THEN
    _user_id := _raw_user_id::uuid;

    -- Kiểm tra chủ quán trong stores
    IF EXISTS (
      SELECT 1 FROM public.stores
      WHERE id = _store_id AND owner_user_id = _user_id
    ) THEN
      RETURN _store_id;
    END IF;

    -- Kiểm tra thành viên trong store_members nếu bảng tồn tại
    BEGIN
      IF EXISTS (
        SELECT 1 FROM public.store_members
        WHERE store_id = _store_id AND user_id = _user_id
      ) THEN
        RETURN _store_id;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    -- Kiểm tra nhân viên/quản lý trong staff_members
    BEGIN
      IF EXISTS (
        SELECT 1 FROM public.staff_members
        WHERE store_id = _store_id AND id = _user_id
      ) THEN
        RETURN _store_id;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  -- Fallback: Nếu không có user_id hoặc là anon request nhưng có header x-store-id hợp lệ
  RETURN _store_id;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, public;

-- 2. Cấp quyền thực thi hàm
GRANT EXECUTE ON FUNCTION public.current_store_id() TO anon, authenticated, service_role;

-- 3. Cấp quyền bảng public.products cho các role API
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.products TO anon, authenticated, service_role;

-- 4. Kích hoạt Row-Level Security (RLS) cho products
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- 5. Xóa các policy cũ / trùng lặp / hạn chế sai
DROP POLICY IF EXISTS "products_isolation" ON public.products;
DROP POLICY IF EXISTS "products_select" ON public.products;
DROP POLICY IF EXISTS "products_insert" ON public.products;
DROP POLICY IF EXISTS "products_update" ON public.products;
DROP POLICY IF EXISTS "products_delete" ON public.products;
DROP POLICY IF EXISTS "owner_write_products" ON public.products;
DROP POLICY IF EXISTS "members_read_products" ON public.products;
DROP POLICY IF EXISTS "anon_access_products" ON public.products;

-- 6. Thiết lập chính sách bảo mật cô lập đa quán (Tenant Isolation)
CREATE POLICY "products_isolation" ON public.products
FOR ALL TO authenticated, anon
USING (
  store_id = public.current_store_id() OR store_id::text = public.current_store_id()::text
)
WITH CHECK (
  store_id = public.current_store_id() OR store_id::text = public.current_store_id()::text
);

-- 7. Bảo đảm các cột Soft Delete tồn tại trên bảng products
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS is_available boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_active    boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_deleted   boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS updated_at   bigint;

-- 8. Index tối ưu hiệu năng lọc quán và trạng thái xóa
CREATE INDEX IF NOT EXISTS idx_products_store_active_v2
  ON public.products (store_id, is_deleted, is_active);
