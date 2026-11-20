-- FIX 11 (10/10/2026) — Thu hồi quyền trực tiếp của vai trò `anon` trên các bảng dữ liệu bill + dọn mẫu lạc
-- Lý do: `anon` đang có SELECT/INSERT/UPDATE/DELETE trên các bảng đơn hàng/cài đặt/bếp/kho, chỉ nhờ RLS chặn.
--   Nếu một bảng lỡ tắt RLS hoặc thêm policy rộng thì lộ dữ liệu mọi quán. Thêm lớp phòng thủ thứ hai ở tầng quyền bảng.
-- Đã kiểm tra trước (DB thật, 10/10): không có hàm SECURITY INVOKER nào anon được EXECUTE nhắc tới các bảng này,
--   không có view nào anon đọc; RLS `*_isolation` đã trả 0 dòng cho anon (current_store_id() = NULL khi không có JWT).
--   => Không đổi hành vi hợp lệ. App dùng vai trò `authenticated` (POS JWT).
-- KHÔNG đụng: app_logs (có policy insert cho anon có chủ đích), stores, user_accounts, store_members.
-- Giữ nguyên quyền của `authenticated` và `service_role`.
-- Rollback: 20261010_fix11_ROLLBACK.sql
SET search_path = public, pg_catalog, pg_temp;

-- 1) Thu hồi quyền bảng của anon (idempotent)
REVOKE ALL ON TABLE
  public.app_settings,
  public.orders,
  public.order_items,
  public.payment_settlements,
  public.finance_records,
  public.kitchen_tickets,
  public.kitchen_ticket_items,
  public.stock_movements
FROM anon;

-- 2) Dọn mẫu bill lạc của "Quán bữa trưa": ký hiệu hóa đơn 1C26TAA là số mặc định cũ của code bị lưu theo,
--    không phải số của quán này. Chỉ sửa đúng khi giá trị còn là 1C26TAA (idempotent, không đụng quán khác).
UPDATE public.app_settings a
SET value = jsonb_set(
      a.value::jsonb,
      '{blocks}',
      (SELECT jsonb_agg(
                CASE WHEN t.b->>'type' = 'taxInfo'
                       AND t.b->'config'->>'invoiceSerial' = '1C26TAA'
                     THEN jsonb_set(jsonb_set(t.b, '{config,invoiceSerial}', '""'::jsonb),
                                    '{config,invoicePattern}', '""'::jsonb)
                     ELSE t.b END
                ORDER BY t.ord)
         FROM jsonb_array_elements((a.value::jsonb)->'blocks') WITH ORDINALITY AS t(b, ord))
    )::text
WHERE a.store_id = '2d17be61-ad08-443c-a922-1b9702231101'
  AND a.key = 'qn_bill_template_cashier'
  AND a.value LIKE '%1C26TAA%';

-- 3) Kiểm tra sau áp (nếu sai thì lỗi và hoàn tác cả giao dịch)
DO $$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM (VALUES ('app_settings'),('orders'),('order_items'),('payment_settlements'),
      ('finance_records'),('kitchen_tickets'),('kitchen_ticket_items'),('stock_movements')) t(x)
   WHERE has_table_privilege('anon', 'public.'||t.x, 'select')
      OR has_table_privilege('anon', 'public.'||t.x, 'insert')
      OR has_table_privilege('anon', 'public.'||t.x, 'update')
      OR has_table_privilege('anon', 'public.'||t.x, 'delete');
  IF n <> 0 THEN RAISE EXCEPTION 'FIX 11: anon van con quyen tren % bang', n; END IF;
  IF NOT has_table_privilege('authenticated', 'public.orders', 'select')
     OR NOT has_table_privilege('authenticated', 'public.app_settings', 'update') THEN
    RAISE EXCEPTION 'FIX 11: authenticated mat quyen can thiet';
  END IF;
  IF EXISTS (SELECT 1 FROM public.app_settings
              WHERE store_id = '2d17be61-ad08-443c-a922-1b9702231101'
                AND key = 'qn_bill_template_cashier' AND value LIKE '%1C26TAA%') THEN
    RAISE EXCEPTION 'FIX 11: mau Quan bua trua van con 1C26TAA';
  END IF;
END $$;
