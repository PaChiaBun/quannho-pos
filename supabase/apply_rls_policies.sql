-- 1. Tạo hàm đọc store_id an toàn từ Header của thiết bị gửi lên (chống SQL Injection / Lỗi ép kiểu)
CREATE OR REPLACE FUNCTION public.current_store_id()
RETURNS uuid AS $$
DECLARE
  _store_id text;
BEGIN
  _store_id := current_setting('request.headers', true)::json->>'x-store-id';
  -- Kiểm tra định dạng UUID hợp lệ trước khi ép kiểu để tránh crash database
  IF _store_id IS NULL OR _store_id = '' OR NOT (_store_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') THEN
    RETURN '00000000-0000-0000-0000-000000000000'::uuid;
  END IF;
  RETURN _store_id::uuid;
END;
$$ LANGUAGE plpgsql STABLE;

-- 2. Kích hoạt RLS cho toàn bộ các bảng dữ liệu chính
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ban_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kitchen_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kitchen_ticket_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- 3. Xoá các Policy "ALL USING (true)" cũ để tránh xung đột
DROP POLICY IF EXISTS "devices_all" ON public.devices;
DROP POLICY IF EXISTS "products_select" ON public.products;
DROP POLICY IF EXISTS "products_insert" ON public.products;
DROP POLICY IF EXISTS "products_update" ON public.products;
DROP POLICY IF EXISTS "products_delete" ON public.products;
DROP POLICY IF EXISTS "staff_select" ON public.staff_members;
DROP POLICY IF EXISTS "staff_insert" ON public.staff_members;
DROP POLICY IF EXISTS "staff_update" ON public.staff_members;
DROP POLICY IF EXISTS "staff_delete" ON public.staff_members;
DROP POLICY IF EXISTS "orders_all" ON public.orders;
DROP POLICY IF EXISTS "order_items_all" ON public.order_items;
DROP POLICY IF EXISTS "kitchen_all" ON public.kitchen_tickets;
DROP POLICY IF EXISTS "kitchen_items_all" ON public.kitchen_ticket_items;
DROP POLICY IF EXISTS "ban_all" ON public.ban_sessions;
DROP POLICY IF EXISTS "settings_all" ON public.app_settings;

-- 4. Tạo các Policy bảo mật cách ly theo store_id tuyệt đối
CREATE POLICY "devices_isolation" ON public.devices FOR ALL USING (store_id = public.current_store_id()) WITH CHECK (store_id = public.current_store_id());
CREATE POLICY "products_isolation" ON public.products FOR ALL USING (store_id = public.current_store_id()) WITH CHECK (store_id = public.current_store_id());
CREATE POLICY "staff_isolation" ON public.staff_members FOR ALL USING (store_id = public.current_store_id()) WITH CHECK (store_id = public.current_store_id());
CREATE POLICY "orders_isolation" ON public.orders FOR ALL USING (store_id = public.current_store_id()) WITH CHECK (store_id = public.current_store_id());
CREATE POLICY "order_items_isolation" ON public.order_items FOR ALL USING (store_id = public.current_store_id()) WITH CHECK (store_id = public.current_store_id());
CREATE POLICY "ban_isolation" ON public.ban_sessions FOR ALL USING (store_id = public.current_store_id()) WITH CHECK (store_id = public.current_store_id());
CREATE POLICY "kitchen_isolation" ON public.kitchen_tickets FOR ALL USING (store_id = public.current_store_id()) WITH CHECK (store_id = public.current_store_id());
CREATE POLICY "kitchen_items_isolation" ON public.kitchen_ticket_items FOR ALL USING (store_id = public.current_store_id()) WITH CHECK (store_id = public.current_store_id());
CREATE POLICY "settings_isolation" ON public.app_settings FOR ALL USING (store_id = public.current_store_id()) WITH CHECK (store_id = public.current_store_id());
