-- ============================================================================
-- QR Gọi Món đơn giản hóa (V4-simple) — đích triển khai 13/10/2026
-- Hợp đồng : .docs/qr-rpc-contract-don-gian.md
-- Kế hoạch : ke-hoach-don-gian-hoa-qr.md (mục 2: các lỗi của bản proposed cũ)
--
-- TRẠNG THÁI: CHƯA APPLY. Chạy staging trước (supabase/tests/qr_simple_v4_test.sql).
--
-- PHỤ THUỘC (phải đã áp trước):
--   20260901_settlement_v5_prerequisites.sql  (qr_audit_logs, ban_session_orders,
--       ban_session_order_items, payment_settlements, verify_staff_qr_membership_v4)
--   20260902_atomic_settlement_v5.sql (+ các bản fix tới 20261008_fix09): settle_ban_session_v5,
--       generate_daily_order_number_v1, convert_recipe_ingredient_qty_v1
--   20260912_atomic_send_kitchen_ticket_v2.sql: send_kitchen_ticket_v2
--
-- MIGRATION NÀY KHÔNG: tạo lại bảng/hàm của V5 prerequisites; ghi đè
--   verify_staff_qr_membership_v4; UPDATE ban_dining_tables; có FK cứng sang
--   ban_dining_tables; có handoff token / settle_v4.
--
-- QUYẾT ĐỊNH THIẾT KẾ
--   * id bàn là TEXT: qr_requests.table_id text + snapshot table_name.
--   * Cột tên bàn (name hay label) được dò lúc migrate; chỉ 2 hàm nhỏ
--     (qr_table_info_v4, qr_list_tables_v4) được sinh động theo cột có thật.
--   * Không có bảng idempotency riêng: qr_requests (UNIQUE store_id+idempotency_key
--     cho khách; status + FOR UPDATE + ticket_id/order_id cho nhân viên) là nguồn
--     sự thật. Gọi lại approve/pay trả đúng kết quả cũ.
--   * Trừ kho: COUNTER trong pay_and_send_counter_v4; TABLE chỉ ở settle_ban_session_v5.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 00. BẢNG LIÊN KẾT TOPPING (production audit 07/10: chưa có, nhưng app Kho/Bàn đang dùng).
--     Khớp đúng cột app ghi: product_id, topping_id (không có store_id; quán suy ra qua products).
--     Không cấp quyền cho anon. Authenticated chỉ thao tác trên món thuộc quán mình là thành viên.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.product_topping_links (
  product_id uuid NOT NULL,
  topping_id uuid NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (product_id, topping_id)
);
CREATE INDEX IF NOT EXISTS idx_ptl_product ON public.product_topping_links(product_id);
CREATE INDEX IF NOT EXISTS idx_ptl_topping ON public.product_topping_links(topping_id);
ALTER TABLE public.product_topping_links ENABLE ROW LEVEL SECURITY;
DO $ptl$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='product_topping_links'
                 AND policyname='ptl_member_all') THEN
    CREATE POLICY ptl_member_all ON public.product_topping_links
      FOR ALL TO authenticated
      USING (EXISTS (SELECT 1 FROM public.products p
                     JOIN public.store_members m ON m.store_id = p.store_id AND m.user_id = auth.uid()
                     WHERE p.id = product_topping_links.product_id))
      WITH CHECK (EXISTS (SELECT 1 FROM public.products p
                          JOIN public.store_members m ON m.store_id = p.store_id AND m.user_id = auth.uid()
                          WHERE p.id = product_topping_links.product_id));
  END IF;
END
$ptl$;
REVOKE ALL ON public.product_topping_links FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.product_topping_links TO authenticated;
GRANT ALL ON public.product_topping_links TO service_role;

-- ============================================================================
-- 00b. SỬA LỖI HÀM CÓ SẴN verify_staff_qr_membership_v4 (production 07/10):
--      nhánh dự phòng "chủ quán không có dòng store_members" tham chiếu cột stores.owner_id
--      KHÔNG tồn tại → người không thuộc quán gọi RPC bị lỗi 42703 thay vì PERMISSION_DENIED.
--      Chỉ bỏ "OR owner_id = v_uid"; mọi logic và quyền EXECUTE hiện có giữ nguyên bản production
--      (CREATE OR REPLACE không đổi GRANT).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.verify_staff_qr_membership_v4(p_store_id uuid, p_require_checkout boolean DEFAULT false, p_require_manage boolean DEFAULT false)
 RETURNS TABLE(member_user_id uuid, member_role text, store_member_id uuid, is_owner_member boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp'
AS $vsq$
DECLARE
  v_uid uuid;
  v_sm_id uuid;
  v_role text;
  v_is_owner boolean;
  v_perms_json jsonb;
  v_has_checkout boolean := false;
BEGIN
  -- Trích xuất User ID qua auth.uid() hoặc JWT context đa tầng
  BEGIN
    v_uid := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_uid := NULL;
  END;

  IF v_uid IS NULL THEN
    BEGIN
      v_uid := NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_uid := NULL;
    END;
  END IF;

  IF v_uid IS NULL THEN
    BEGIN
      v_uid := NULLIF(((current_setting('request.jwt.claims', true)::jsonb)->>'sub'), '')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_uid := NULL;
    END;
  END IF;

  IF v_uid IS NULL THEN
    BEGIN
      v_uid := NULLIF((current_setting('request.headers', true)::jsonb)->>'x-user-id', '')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_uid := NULL;
    END;
  END IF;

  IF v_uid IS NULL THEN
    BEGIN
      v_uid := NULLIF(current_setting('request.header.x-user-id', true), '')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_uid := NULL;
    END;
  END IF;

  IF v_uid IS NULL OR p_store_id IS NULL THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: authenticated store context is required'
      USING ERRCODE = '42501';
  END IF;

  -- 1. Tìm thông tin trong store_members
  SELECT sm.id, sm.role, COALESCE(sm.is_owner, false)
  INTO v_sm_id, v_role, v_is_owner
  FROM public.store_members sm
  WHERE sm.store_id = p_store_id AND sm.user_id = v_uid
  LIMIT 1;

  -- 2. Fallback: Nếu không có trong store_members, kiểm tra stores (Owner)
  IF v_role IS NULL THEN
    SELECT 'owner', true
    INTO v_role, v_is_owner
    FROM public.stores
    WHERE id = p_store_id AND owner_user_id = v_uid
    LIMIT 1;
  END IF;

  -- 3. Fallback: Kiểm tra trực tiếp trong staff_members
  IF v_role IS NULL THEN
    SELECT sm.role, false
    INTO v_role, v_is_owner
    FROM public.staff_members sm
    WHERE sm.store_id = p_store_id AND sm.id = v_uid
    LIMIT 1;
  END IF;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: not a member of this store'
      USING ERRCODE = '42501';
  END IF;

  IF p_require_manage AND NOT (v_is_owner OR v_role IN ('owner', 'manager', 'admin')) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: manage permission required'
      USING ERRCODE = '42501';
  END IF;

  IF p_require_checkout AND NOT (v_is_owner OR v_role = 'owner') THEN
    -- 1. Ưu tiên vai trò chuẩn (owner, manager, cashier, admin, waiter) hoặc tiếng Việt
    IF v_role IN ('owner', 'manager', 'cashier', 'admin', 'waiter')
       OR lower(trim(v_role)) LIKE '%thu ngân%'
       OR lower(trim(v_role)) LIKE '%quản lý%'
       OR lower(trim(v_role)) LIKE '%quầy%'
       OR lower(trim(v_role)) LIKE '%phục vụ%'
       OR lower(trim(v_role)) LIKE '%chạy bàn%'
       OR lower(trim(v_role)) LIKE '%bán hàng%' THEN
      v_has_checkout := true;
    END IF;

    -- 2. Kiểm tra modules từ store_roles (Lego Modules)
    IF NOT v_has_checkout THEN
      BEGIN
        SELECT EXISTS (
          SELECT 1
          FROM public.store_roles sr,
               LATERAL jsonb_array_elements_text(
                 CASE
                   WHEN sr.modules IS NULL OR btrim(sr.modules::text) = '' THEN '[]'::jsonb
                   WHEN jsonb_typeof(sr.modules::jsonb) = 'array' THEN sr.modules::jsonb
                   ELSE '[]'::jsonb
                 END
               ) AS m(module_name)
          WHERE sr.store_id = p_store_id
            AND (sr.name = v_role OR lower(trim(sr.name)) = lower(trim(v_role)))
            AND m.module_name IN ('pos', 'ban')
        ) INTO v_has_checkout;
      EXCEPTION WHEN OTHERS THEN
        v_has_checkout := false;
      END;
    END IF;

    -- 3. Kiểm tra modules từ staff_members
    IF NOT v_has_checkout THEN
      BEGIN
        SELECT EXISTS (
          SELECT 1
          FROM public.staff_members sm,
               LATERAL jsonb_array_elements_text(
                 CASE
                   WHEN sm.modules IS NULL OR btrim(sm.modules::text) = '' THEN '[]'::jsonb
                   WHEN jsonb_typeof(sm.modules::jsonb) = 'array' THEN sm.modules::jsonb
                   ELSE '[]'::jsonb
                 END
               ) AS m(module_name)
          WHERE sm.store_id = p_store_id
            AND sm.id = v_uid
            AND m.module_name IN ('pos', 'ban')
        ) INTO v_has_checkout;
      EXCEPTION WHEN OTHERS THEN
        v_has_checkout := false;
      END;
    END IF;

    -- 4. Fallback kiểm tra app_settings (action_perms_*)
    IF NOT v_has_checkout THEN
      SELECT CASE
        WHEN s.value IS NULL OR btrim(s.value) = '' THEN '[]'::jsonb
        ELSE s.value::jsonb
      END
      INTO v_perms_json
      FROM public.app_settings s
      WHERE s.store_id = p_store_id
        AND (s.key = 'action_perms_' || v_role OR s.key = 'action_perms_cashier')
      LIMIT 1;
      IF jsonb_typeof(COALESCE(v_perms_json, '[]'::jsonb)) = 'array' THEN
        SELECT EXISTS (
          SELECT 1 FROM jsonb_array_elements_text(v_perms_json) permission
          WHERE permission = 'pos.checkout'
        ) INTO v_has_checkout;
      END IF;
    END IF;

    IF NOT v_has_checkout THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: pos.checkout permission required'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  member_user_id := v_uid;
  member_role := v_role;
  store_member_id := v_uid;
  is_owner_member := v_is_owner OR v_role = 'owner';
  RETURN NEXT;
END;
$vsq$;

-- ============================================================================
-- 0. PREFLIGHT — fail-closed. Bất kỳ giả định sai nào => RAISE EXCEPTION, không đổi gì.
-- ============================================================================
DO $preflight$
DECLARE
  v_missing text;
  v_ext_schema text;
  v_type text;
  v_has_name boolean;
  v_has_label boolean;
  v_con text;
BEGIN
  -- 0.1 Bảng bắt buộc
  SELECT string_agg(t, ', ') INTO v_missing
  FROM unnest(ARRAY[
    'stores','store_members','user_accounts','staff_members','products',
    'ban_dining_tables','ban_zones','ban_sessions','ban_session_items',
    'orders','order_items','kitchen_tickets','kitchen_ticket_items',
    'finance_records','stock_movements','recipes','recipe_ingredients',
    'product_topping_links','qr_audit_logs','ban_session_orders',
    'ban_session_order_items','payment_settlements','daily_order_counters'
  ]) AS t
  WHERE to_regclass('public.' || t) IS NULL;
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: thiếu bảng: %. Áp các migration nền (V5 prerequisites/settlement) trước.', v_missing;
  END IF;

  -- 0.2 Hàm bắt buộc (V5 prerequisites phải áp trước)
  IF to_regprocedure('public.verify_staff_qr_membership_v4(uuid,boolean,boolean)') IS NULL THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: thiếu verify_staff_qr_membership_v4(uuid,boolean,boolean) — áp 20260901_settlement_v5_prerequisites.sql trước';
  END IF;
  IF to_regprocedure('public.settle_ban_session_v5(uuid,uuid,text,text,uuid,integer,numeric,text,numeric)') IS NULL THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: thiếu settle_ban_session_v5 — áp 20260902_atomic_settlement_v5.sql (và fix mới nhất) trước';
  END IF;
  IF to_regprocedure('public.send_kitchen_ticket_v2(uuid,uuid,text,text,text,uuid[])') IS NULL THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: thiếu send_kitchen_ticket_v2 — áp 20260912_atomic_send_kitchen_ticket_v2.sql trước';
  END IF;
  IF to_regprocedure('public.generate_daily_order_number_v1(uuid,text,text)') IS NULL THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: thiếu generate_daily_order_number_v1(uuid,text,text)';
  END IF;
  IF to_regprocedure('public.convert_recipe_ingredient_qty_v1(numeric,text,text,numeric,text)') IS NULL THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: thiếu convert_recipe_ingredient_qty_v1 — áp 20261008_fix09_quy_doi_don_vi_cong_thuc.sql trước (trừ kho COUNTER dùng cùng quy đổi đơn vị với settle V5)';
  END IF;

  -- 0.3 pgcrypto: phải nằm trong schema mà search_path của hàm (public, extensions) nhìn thấy
  SELECT n.nspname INTO v_ext_schema
  FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace
  WHERE e.extname = 'pgcrypto';
  IF v_ext_schema IS NULL THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: chưa cài extension pgcrypto (CREATE EXTENSION pgcrypto SCHEMA extensions)';
  END IF;
  IF v_ext_schema NOT IN ('public', 'extensions') THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: pgcrypto nằm ở schema "%" — ngoài search_path (public, extensions, pg_catalog, pg_temp)', v_ext_schema;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = v_ext_schema AND p.proname = 'gen_random_bytes'
  ) THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: không thấy gen_random_bytes trong schema %', v_ext_schema;
  END IF;

  -- 0.4 Cột bắt buộc (gộp báo lỗi một lần)
  SELECT string_agg(v.t || '.' || v.c, ', ') INTO v_missing
  FROM (VALUES
    ('stores','id'),
    ('store_members','store_id'),('store_members','user_id'),('store_members','role'),
    ('user_accounts','id'),('user_accounts','display_name'),('user_accounts','phone'),
    ('staff_members','id'),('staff_members','store_id'),('staff_members','name'),
    ('staff_members','role'),('staff_members','phone'),('staff_members','is_active'),('staff_members','updated_at'),
    ('products','id'),('products','store_id'),('products','name'),('products','category'),
    ('products','sell_price'),('products','cost_price_latest'),('products','stock_qty'),
    ('products','is_active'),('products','is_deleted'),('products','is_topping'),
    ('products','is_available'),('products','station_code'),('products','unit'),
    ('products','conversion_rate'),('products','conversion_unit'),('products','image_url'),
    ('products','updated_at'),
    ('ban_dining_tables','id'),('ban_dining_tables','store_id'),('ban_dining_tables','zone_id'),
    ('ban_dining_tables','is_active'),
    ('ban_zones','id'),('ban_zones','name'),
    ('ban_sessions','id'),('ban_sessions','store_id'),('ban_sessions','table_id'),
    ('ban_sessions','status'),('ban_sessions','opened_at'),('ban_sessions','total_amount'),
    ('ban_sessions','guest_count'),
    ('ban_session_items','id'),('ban_session_items','store_id'),('ban_session_items','session_id'),
    ('ban_session_items','product_id'),('ban_session_items','product_name'),
    ('ban_session_items','unit_price'),('ban_session_items','price'),('ban_session_items','quantity'),
    ('ban_session_items','subtotal'),('ban_session_items','kitchen_status'),
    ('ban_session_items','added_at'),('ban_session_items','note'),('ban_session_items','modifiers_json'),
    ('orders','id'),('orders','store_id'),('orders','order_number'),('orders','subtotal'),
    ('orders','discount'),('orders','tax'),('orders','total'),('orders','total_amount'),
    ('orders','payment_method'),('orders','status'),('orders','source_type'),('orders','source_id'),
    ('orders','staff_id'),('orders','receipt_printed'),('orders','created_at'),('orders','note'),
    ('order_items','id'),('order_items','store_id'),('order_items','order_id'),
    ('order_items','product_id'),('order_items','name'),('order_items','product_name'),
    ('order_items','qty'),('order_items','quantity'),('order_items','unit_price'),
    ('order_items','cost_price'),('order_items','subtotal'),('order_items','modifiers_json'),
    ('kitchen_tickets','id'),('kitchen_tickets','store_id'),('kitchen_tickets','session_id'),
    ('kitchen_tickets','table_label'),('kitchen_tickets','zone_label'),('kitchen_tickets','round'),
    ('kitchen_tickets','status'),('kitchen_tickets','sent_at'),('kitchen_tickets','note'),
    ('kitchen_ticket_items','id'),('kitchen_ticket_items','store_id'),('kitchen_ticket_items','ticket_id'),
    ('kitchen_ticket_items','session_item_id'),('kitchen_ticket_items','product_id'),
    ('kitchen_ticket_items','name'),('kitchen_ticket_items','product_name'),
    ('kitchen_ticket_items','qty'),('kitchen_ticket_items','quantity'),
    ('kitchen_ticket_items','free_note'),('kitchen_ticket_items','kitchen_note'),
    ('kitchen_ticket_items','modifiers_json'),('kitchen_ticket_items','station_code'),
    ('kitchen_ticket_items','done'),
    ('finance_records','id'),('finance_records','store_id'),('finance_records','type'),
    ('finance_records','amount'),('finance_records','description'),('finance_records','reference_id'),
    ('finance_records','is_auto'),('finance_records','recorded_at'),('finance_records','fund_type'),
    ('stock_movements','id'),('stock_movements','store_id'),('stock_movements','product_id'),
    ('stock_movements','delta'),('stock_movements','reason'),('stock_movements','reference_id'),
    ('stock_movements','note'),('stock_movements','created_at'),
    ('recipes','id'),('recipes','pos_product_id'),('recipes','is_deleted'),
    ('recipe_ingredients','recipe_id'),('recipe_ingredients','ingredient_id'),
    ('recipe_ingredients','quantity'),('recipe_ingredients','unit'),('recipe_ingredients','yield_factor'),
    ('product_topping_links','product_id'),
    ('product_topping_links','topping_id'),
    ('qr_audit_logs','store_id'),('qr_audit_logs','request_id'),('qr_audit_logs','action'),
    ('qr_audit_logs','actor_user_id'),('qr_audit_logs','details'),
    ('ban_session_orders','store_id'),('ban_session_orders','session_id'),
    ('ban_session_orders','order_id'),('ban_session_orders','qr_request_id'),
    ('ban_session_order_items','session_item_id'),('ban_session_order_items','order_item_id'),
    ('ban_session_order_items','source_type')
  ) AS v(t, c)
  WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.columns ic
    WHERE ic.table_schema = 'public' AND ic.table_name = v.t AND ic.column_name = v.c
  );
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: thiếu cột: %', v_missing;
  END IF;

  -- 0.5 ban_dining_tables.id PHẢI là text (không FK uuid -> bảng này)
  SELECT data_type INTO v_type FROM information_schema.columns
  WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='id';
  IF v_type <> 'text' THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: ban_dining_tables.id kiểu "%" (giả định: text). Hợp đồng và mọi RPC dùng table_id text — dừng để rà soát.', v_type;
  END IF;

  -- 0.6 Cột tên bàn: name hay label (ít nhất một)
  SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='name'),
         EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='label')
  INTO v_has_name, v_has_label;
  IF NOT v_has_name AND NOT v_has_label THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: ban_dining_tables không có cả cột "name" lẫn "label" — không biết lấy tên bàn từ đâu';
  END IF;
  RAISE NOTICE 'QR preflight: ban_dining_tables name=% label=% (tên bàn = COALESCE theo cột có thật)', v_has_name, v_has_label;

  -- 0.7 ban_sessions.table_id: uuid (lịch sử) hoặc text
  SELECT data_type INTO v_type FROM information_schema.columns
  WHERE table_schema='public' AND table_name='ban_sessions' AND column_name='table_id';
  IF v_type NOT IN ('uuid', 'text') THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: ban_sessions.table_id kiểu "%" (chấp nhận uuid hoặc text)', v_type;
  END IF;
  IF v_type = 'uuid' AND EXISTS (
    SELECT 1 FROM public.ban_dining_tables
    WHERE id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ) THEN
    RAISE WARNING 'QR preflight: ban_sessions.table_id là uuid nhưng có ban_dining_tables.id không đúng định dạng uuid — các bàn đó sẽ KHÔNG duyệt/gửi bếp được qua QR (trả TABLE_NOT_FOUND)';
  END IF;

  -- 0.8 Kitchen: COUNTER không có phiên bàn => session_id / session_item_id phải cho phép NULL
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='kitchen_tickets' AND column_name='session_id' AND is_nullable='NO') THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: kitchen_tickets.session_id đang NOT NULL; vé bếp COUNTER không có phiên bàn. Chạy trước: ALTER TABLE public.kitchen_tickets ALTER COLUMN session_id DROP NOT NULL; (và kiểm màn bếp xử lý vé không có phiên)';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='kitchen_ticket_items' AND column_name='session_item_id' AND is_nullable='NO') THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: kitchen_ticket_items.session_item_id đang NOT NULL; chạy trước: ALTER TABLE public.kitchen_ticket_items ALTER COLUMN session_item_id DROP NOT NULL;';
  END IF;

  -- 0.9 Kiểu id nền tảng là uuid
  SELECT string_agg(v.t || '.' || v.c || '=' || ic.data_type, ', ') INTO v_missing
  FROM (VALUES ('stores','id'),('products','id'),('orders','id'),('ban_sessions','id'),
               ('kitchen_tickets','id'),('store_members','store_id'),('store_members','user_id')) AS v(t,c)
  JOIN information_schema.columns ic
    ON ic.table_schema='public' AND ic.table_name=v.t AND ic.column_name=v.c
  WHERE ic.data_type <> 'uuid';
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: các cột phải là uuid nhưng không phải: %', v_missing;
  END IF;

  -- 0.10 Dữ liệu QR cũ lệch schema (bản proposed cũ dùng assigned_table_id uuid / handoff token)
  IF to_regclass('public.qr_requests') IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='qr_requests' AND column_name='table_id' AND data_type='text')
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='qr_requests' AND column_name='claimed_by') THEN
      RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: public.qr_requests đã tồn tại với schema cũ (không có table_id text / claimed_by). Dọn đối tượng QR cũ thủ công (KHÔNG xóa bảng V5 dùng chung) rồi chạy lại.';
    END IF;
  END IF;
  IF to_regclass('public.qr_channels') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='qr_channels' AND column_name='channel_code'
  ) THEN
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: public.qr_channels đã tồn tại với schema lạ (thiếu channel_code)';
  END IF;

  -- 0.11 orders.status có CHECK mà không cho 'open'/'completed'? (cảnh báo, không chặn)
  FOR v_con IN
    SELECT pg_get_constraintdef(c.oid)
    FROM pg_constraint c
    WHERE c.conrelid = 'public.orders'::regclass AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) ILIKE '%status%'
  LOOP
    IF v_con NOT ILIKE '%open%' OR v_con NOT ILIKE '%completed%' THEN
      RAISE WARNING 'QR preflight: orders có CHECK liên quan status: % — cần chứa cả ''open'' (đơn TABLE) và ''completed'' (đơn COUNTER)', v_con;
    END IF;
  END LOOP;
END
$preflight$;

-- ============================================================================
-- 1. DỌN HÀM BỊ BỎ / ĐỔI CHỮ KÝ (chỉ đối tượng QR; production chưa có theo khảo sát 27/08)
-- ============================================================================
DROP FUNCTION IF EXISTS public.claim_qr_handoff_v4(text, uuid);
DROP FUNCTION IF EXISTS public.regenerate_handoff_token_v4(text);
DROP FUNCTION IF EXISTS public.assign_qr_order_table_v4(uuid, uuid, uuid);
DROP FUNCTION IF EXISTS public.assign_qr_order_table_v4(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.mark_qr_order_paid_v4(uuid, uuid, text, text);
DROP FUNCTION IF EXISTS public.send_qr_order_to_kitchen_v4(uuid, uuid, text, text);
DROP FUNCTION IF EXISTS public.settle_ban_session_v4(uuid, uuid, text, text, uuid, integer, numeric, text, numeric);
DROP FUNCTION IF EXISTS public.get_qr_menu_v4(text, text);
DROP FUNCTION IF EXISTS public.submit_qr_order_v4(text, jsonb, text, text, text);

-- ============================================================================
-- 2. BẢNG (chỉ 4 bảng QR; audit dùng qr_audit_logs có sẵn)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.qr_channels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('TABLE_SHARED', 'COUNTER_TAKEAWAY')),
  channel_code text NOT NULL,
  name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  -- giữ cột tương thích hợp đồng manage_qr_channel_v4; không điều khiển luồng thu tiền
  payment_mode text NOT NULL DEFAULT 'CASHIER_CONFIRM'
    CHECK (payment_mode IN ('PAY_BEFORE_KITCHEN', 'CASHIER_CONFIRM')),
  created_at timestamptz NOT NULL DEFAULT now(),
  -- mỗi quán đúng một kênh cho mỗi loại => tối đa một kênh active mỗi loại
  CONSTRAINT uq_qr_channels_store_type UNIQUE (store_id, type),
  CONSTRAINT uq_qr_channels_code UNIQUE (channel_code)
);

CREATE TABLE IF NOT EXISTS public.qr_pickup_counters (
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  pickup_date date NOT NULL,
  last_seq integer NOT NULL DEFAULT 0,
  PRIMARY KEY (store_id, pickup_date)
);

CREATE TABLE IF NOT EXISTS public.qr_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  channel_id uuid NOT NULL REFERENCES public.qr_channels(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('TABLE_SHARED', 'COUNTER_TAKEAWAY')),
  -- id bàn là text; KHÔNG FK (ban_dining_tables.id text, ban_sessions.table_id uuid lịch sử)
  table_id text,
  table_name text,
  pickup_date date,
  pickup_seq integer,
  pickup_code text,
  tracking_token text NOT NULL,
  idempotency_key text NOT NULL,
  payload_hash text,
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'claimed', 'sent_kitchen', 'rejected', 'expired', 'cancelled')),
  payment_status text NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid')),
  payment_method text,
  customer_note text NOT NULL DEFAULT '' CHECK (char_length(customer_note) <= 300),
  reject_reason text,
  total_amount numeric NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  version integer NOT NULL DEFAULT 1,
  original_items jsonb NOT NULL DEFAULT '[]'::jsonb,   -- snapshot món khách gửi, không bao giờ sửa
  claimed_by uuid,
  claimed_at timestamptz,
  session_id uuid,        -- ban_sessions.id (TABLE)
  order_id uuid,          -- orders.id
  ticket_id uuid,         -- kitchen_tickets.id
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '60 minutes'),
  CONSTRAINT uq_qr_requests_tracking UNIQUE (tracking_token),
  CONSTRAINT uq_qr_requests_idempotency UNIQUE (store_id, idempotency_key),
  CONSTRAINT uq_qr_requests_pickup UNIQUE (store_id, pickup_date, pickup_seq)
);
CREATE INDEX IF NOT EXISTS idx_qr_requests_store_status
  ON public.qr_requests (store_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_qr_requests_channel_pending
  ON public.qr_requests (channel_id, created_at) WHERE status = 'submitted';
CREATE INDEX IF NOT EXISTS idx_qr_requests_table
  ON public.qr_requests (store_id, table_id) WHERE table_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.qr_request_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES public.qr_requests(id) ON DELETE CASCADE,
  product_id uuid NOT NULL,   -- không FK: giữ snapshot kể cả khi món bị xóa cứng
  product_name text NOT NULL,
  unit_price numeric NOT NULL CHECK (unit_price >= 0),
  quantity integer NOT NULL CHECK (quantity > 0),
  subtotal numeric NOT NULL CHECK (subtotal >= 0),
  modifiers_json jsonb NOT NULL DEFAULT '[]'::jsonb,
  note text NOT NULL DEFAULT '' CHECK (char_length(note) <= 300),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_qr_request_items_req ON public.qr_request_items (request_id);

-- ============================================================================
-- 3. HÀM SINH ĐỘNG THEO CỘT TÊN BÀN CÓ THẬT (name / label)
--    Chỉ 2 hàm này đụng tới cột tên bàn. Mọi nơi khác gọi qua chúng.
-- ============================================================================
DO $gen$
DECLARE
  v_has_name boolean;
  v_has_label boolean;
  v_expr text;
  v_tpl_info text;
  v_tpl_list text;
BEGIN
  SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='name'),
         EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='label')
  INTO v_has_name, v_has_label;

  IF v_has_name AND v_has_label THEN
    v_expr := 'COALESCE(NULLIF(btrim(t.name::text), ''''), NULLIF(btrim(t.label::text), ''''), t.id::text)';
  ELSIF v_has_name THEN
    v_expr := 'COALESCE(NULLIF(btrim(t.name::text), ''''), t.id::text)';
  ELSIF v_has_label THEN
    v_expr := 'COALESCE(NULLIF(btrim(t.label::text), ''''), t.id::text)';
  ELSE
    RAISE EXCEPTION 'QR_PREFLIGHT_FAIL: không có cột tên bàn';
  END IF;

  v_tpl_info := $t$
CREATE OR REPLACE FUNCTION public.qr_table_info_v4(p_store_id uuid, p_table_id text)
RETURNS TABLE (t_id text, t_name text, t_zone text, t_active boolean)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $q$
  SELECT t.id::text, @NAME@, z.name::text, COALESCE(t.is_active, true)
  FROM public.ban_dining_tables t
  LEFT JOIN public.ban_zones z ON z.id::text = t.zone_id::text
  -- Chỉ bàn ăn thật (id dạng uuid): loại bàn hệ thống như 'sys-table-takeaway' (không mở được phiên bàn).
  WHERE t.store_id = p_store_id AND t.id::text = p_table_id
    AND t.id::text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  LIMIT 1
$q$
$t$;

  v_tpl_list := $t$
CREATE OR REPLACE FUNCTION public.qr_list_tables_v4(p_store_id uuid)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $q$
  SELECT COALESCE(jsonb_agg(
           jsonb_build_object('id', x.t_id, 'name', x.t_name, 'zone_name', x.t_zone)
           ORDER BY x.t_zone NULLS LAST, length(x.t_name), x.t_name
         ), '[]'::jsonb)
  FROM (
    SELECT t.id::text AS t_id, @NAME@ AS t_name, z.name::text AS t_zone
    FROM public.ban_dining_tables t
    LEFT JOIN public.ban_zones z ON z.id::text = t.zone_id::text
    WHERE t.store_id = p_store_id AND COALESCE(t.is_active, true)
      AND t.id::text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ) x
$q$
$t$;

  EXECUTE replace(v_tpl_info, '@NAME@', v_expr);
  EXECUTE replace(v_tpl_list, '@NAME@', v_expr);
END
$gen$;

-- ============================================================================
-- 4. HÀM NỘI BỘ (không cấp cho anon/authenticated, trừ qr_is_active_member_v4)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.qr_err_v4(p_code text, p_message text)
RETURNS jsonb
LANGUAGE sql IMMUTABLE
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
  SELECT jsonb_build_object('success', false, 'error_code', p_code, 'message', p_message)
$fn$;

-- Thành viên ĐANG HOẠT ĐỘNG của quán? Đọc store_members qua to_jsonb để chịu được
-- việc cột is_active/status/is_deleted có hay không (chưa xác minh trên DB thật).
CREATE OR REPLACE FUNCTION public.qr_is_active_member_v4(p_store_id uuid, p_uid uuid DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_uid uuid := COALESCE(p_uid, auth.uid());
  v_row jsonb;
BEGIN
  IF v_uid IS NULL OR p_store_id IS NULL THEN RETURN false; END IF;
  SELECT to_jsonb(sm) INTO v_row
  FROM public.store_members sm
  WHERE sm.store_id = p_store_id AND sm.user_id = v_uid
  LIMIT 1;
  IF v_row IS NULL THEN RETURN false; END IF;
  IF v_row ? 'is_active' AND lower(COALESCE(v_row->>'is_active', 'true')) IN ('false', 'f', '0') THEN RETURN false; END IF;
  IF v_row ? 'is_deleted' AND lower(COALESCE(v_row->>'is_deleted', 'false')) IN ('true', 't', '1') THEN RETURN false; END IF;
  IF v_row ? 'status' AND lower(COALESCE(v_row->>'status', '')) IN
     ('inactive', 'disabled', 'removed', 'suspended', 'blocked', 'banned', 'deleted', 'left', 'revoked') THEN
    RETURN false;
  END IF;
  RETURN true;
END
$fn$;

-- Ngữ cảnh nhân viên: kiểm active membership đúng store_id (+ quyền thu tiền / quản lý).
-- Trả jsonb {success, uid, role, is_manager} hoặc lỗi chuẩn hợp đồng. Không ném lỗi ra ngoài.
CREATE OR REPLACE FUNCTION public.qr_staff_ctx_v4(
  p_store_id uuid,
  p_need_checkout boolean DEFAULT false,
  p_need_manage boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_m record;
  v_msg text;
  v_is_mgr boolean;
  v_role text;
  v_ok boolean := false;
  v_perms jsonb;
BEGIN
  IF p_store_id IS NULL THEN
    RETURN public.qr_err_v4('PERMISSION_DENIED', 'Thiếu mã quán');
  END IF;
  BEGIN
    SELECT * INTO v_m FROM public.verify_staff_qr_membership_v4(p_store_id, p_need_checkout, p_need_manage);
  EXCEPTION WHEN insufficient_privilege THEN
    GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT;
    IF p_need_checkout AND v_msg ILIKE '%pos.checkout%' THEN
      RETURN public.qr_err_v4('PAYMENT_PERMISSION_DENIED', 'Bạn không có quyền thu tiền (pos.checkout)');
    END IF;
    RETURN public.qr_err_v4('PERMISSION_DENIED', 'Bạn không có quyền thao tác ở quán này');
  END;
  IF v_m.member_user_id IS NULL OR NOT public.qr_is_active_member_v4(p_store_id, v_m.member_user_id) THEN
    RETURN public.qr_err_v4('PERMISSION_DENIED', 'Tài khoản không còn hoạt động ở quán này');
  END IF;
  v_is_mgr := (COALESCE(v_m.is_owner_member, false)
               OR lower(COALESCE(v_m.member_role, '')) IN ('owner', 'manager', 'admin'));

  -- Thu tiền: kiểm LẠI chặt hơn verify_staff_qr_membership_v4. Nhánh fallback của verify
  -- (app_settings 'action_perms_cashier' áp cho MỌI vai trò) sẽ cho phục vụ thu tiền khi quán
  -- có cấu hình thu ngân => ở đây chỉ chấp nhận: owner/manager, vai trò thu ngân, module 'pos'
  -- của đúng vai trò / đúng nhân viên, hoặc action_perms của ĐÚNG vai trò chứa 'pos.checkout'.
  IF p_need_checkout AND NOT v_is_mgr THEN
    v_role := lower(btrim(COALESCE(v_m.member_role, '')));
    v_ok := v_role IN ('cashier', 'admin') OR v_role LIKE '%thu ngân%' OR v_role LIKE '%quầy%' OR v_role LIKE '%quản lý%';
    IF NOT v_ok THEN
      BEGIN
        SELECT EXISTS (
          SELECT 1 FROM public.store_roles sr,
            LATERAL jsonb_array_elements_text(
              CASE WHEN sr.modules IS NULL OR btrim(sr.modules::text) = '' THEN '[]'::jsonb
                   WHEN jsonb_typeof(sr.modules::jsonb) = 'array' THEN sr.modules::jsonb
                   ELSE '[]'::jsonb END) AS m(module_name)
          WHERE sr.store_id = p_store_id AND lower(btrim(sr.name)) = v_role AND m.module_name = 'pos'
        ) INTO v_ok;
      EXCEPTION WHEN OTHERS THEN v_ok := false;
      END;
    END IF;
    IF NOT v_ok THEN
      BEGIN
        SELECT EXISTS (
          SELECT 1 FROM public.staff_members stf,
            LATERAL jsonb_array_elements_text(
              CASE WHEN stf.modules IS NULL OR btrim(stf.modules::text) = '' THEN '[]'::jsonb
                   WHEN jsonb_typeof(stf.modules::jsonb) = 'array' THEN stf.modules::jsonb
                   ELSE '[]'::jsonb END) AS m(module_name)
          WHERE stf.store_id = p_store_id AND stf.id = v_m.member_user_id AND m.module_name = 'pos'
        ) INTO v_ok;
      EXCEPTION WHEN OTHERS THEN v_ok := false;
      END;
    END IF;
    IF NOT v_ok THEN
      BEGIN
        SELECT CASE WHEN s.value IS NULL OR btrim(s.value) = '' THEN '[]'::jsonb ELSE s.value::jsonb END
        INTO v_perms
        FROM public.app_settings s
        WHERE s.store_id = p_store_id AND s.key = 'action_perms_' || COALESCE(v_m.member_role, '')
        LIMIT 1;
        IF jsonb_typeof(COALESCE(v_perms, '[]'::jsonb)) = 'array' THEN
          SELECT EXISTS (SELECT 1 FROM jsonb_array_elements_text(v_perms) pm WHERE pm = 'pos.checkout') INTO v_ok;
        END IF;
      EXCEPTION WHEN OTHERS THEN v_ok := false;
      END;
    END IF;
    IF NOT COALESCE(v_ok, false) THEN
      RETURN public.qr_err_v4('PAYMENT_PERMISSION_DENIED', 'Bạn không có quyền thu tiền (pos.checkout)');
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'uid', v_m.member_user_id,
    'role', v_m.member_role,
    'is_manager', v_is_mgr
  );
END
$fn$;

-- staff_members.id = user uuid (cùng quy ước settle V5)
CREATE OR REPLACE FUNCTION public.qr_ensure_staff_v4(p_store_id uuid, p_uid uuid, p_role text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_name text;
  v_phone text;
BEGIN
  SELECT display_name, phone INTO v_name, v_phone FROM public.user_accounts WHERE id = p_uid;
  INSERT INTO public.staff_members (id, store_id, name, role, phone, is_active, updated_at)
  VALUES (p_uid, p_store_id, COALESCE(v_name, 'Staff'), COALESCE(p_role, 'waiter'), v_phone, true,
          extract(epoch from now()) * 1000)
  ON CONFLICT (id) DO UPDATE
    SET name = EXCLUDED.name, role = EXCLUDED.role, is_active = true, updated_at = EXCLUDED.updated_at;
  RETURN p_uid;
END
$fn$;

-- Giá do server tính. Dùng chung cho submit (khách) và update_items (nhân viên).
-- Trả {success:true, items:[...], total} hoặc lỗi. Mọi cast uuid/int nằm trong khối bắt lỗi.
CREATE OR REPLACE FUNCTION public.qr_price_items_v4(p_store_id uuid, p_items jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  c_max_lines constant integer := 50;
  c_max_mods  constant integer := 10;
  c_max_note  constant integer := 300;
  v_item jsonb;
  v_mod jsonb;
  v_prod record;
  v_top record;
  v_clean jsonb := '[]'::jsonb;
  v_mods jsonb;
  v_seen uuid[];
  v_pid uuid;
  v_tid uuid;
  v_qty integer;
  v_tq integer;
  v_tops numeric;
  v_unit numeric;
  v_sub numeric;
  v_total numeric := 0;
  v_note text;
BEGIN
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Danh sách món không hợp lệ');
  END IF;
  IF jsonb_array_length(p_items) = 0 THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Đơn hàng phải có ít nhất một món');
  END IF;
  IF jsonb_array_length(p_items) > c_max_lines THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Đơn có quá nhiều dòng món (tối đa ' || c_max_lines || ')');
  END IF;
  IF pg_column_size(p_items) > 65536 THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Dữ liệu đơn quá lớn');
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items)
  LOOP
    IF jsonb_typeof(v_item) <> 'object' THEN
      RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Dòng món không hợp lệ');
    END IF;
    BEGIN
      v_pid := (v_item->>'product_id')::uuid;
      v_qty := (v_item->>'quantity')::integer;
    EXCEPTION WHEN OTHERS THEN
      RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Mã món hoặc số lượng không hợp lệ');
    END;
    IF v_pid IS NULL OR v_qty IS NULL OR v_qty < 1 OR v_qty > 100 THEN
      RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Số lượng món phải từ 1 đến 100');
    END IF;

    v_note := btrim(COALESCE(v_item->>'note', ''));
    IF char_length(v_note) > c_max_note THEN
      RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Ghi chú tối đa ' || c_max_note || ' ký tự');
    END IF;

    SELECT p.id, p.name, COALESCE(p.sell_price, 0) AS sell_price INTO v_prod
    FROM public.products p
    WHERE p.id = v_pid AND p.store_id = p_store_id
      AND COALESCE(p.is_active, true) AND NOT COALESCE(p.is_deleted, false)
      AND COALESCE(p.is_available, true) AND NOT COALESCE(p.is_topping, false)
      AND COALESCE(p.product_type, 'finished') = 'finished' AND NOT COALESCE(p.is_raw_material, false);
    IF NOT FOUND THEN
      RETURN public.qr_err_v4('PRODUCT_NOT_AVAILABLE', 'Món không tồn tại hoặc đã ngừng phục vụ');
    END IF;

    v_tops := 0;
    v_mods := '[]'::jsonb;
    v_seen := ARRAY[]::uuid[];
    IF v_item ? 'modifiers_json' AND jsonb_typeof(v_item->'modifiers_json') NOT IN ('array', 'null') THEN
      RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Topping không hợp lệ');
    END IF;
    IF jsonb_typeof(v_item->'modifiers_json') = 'array' THEN
      IF jsonb_array_length(v_item->'modifiers_json') > c_max_mods THEN
        RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Quá nhiều topping cho một món');
      END IF;
      FOR v_mod IN SELECT value FROM jsonb_array_elements(v_item->'modifiers_json')
      LOOP
        IF jsonb_typeof(v_mod) <> 'object' THEN
          RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Topping không hợp lệ');
        END IF;
        BEGIN
          v_tid := (v_mod->>'id')::uuid;
          v_tq := COALESCE((v_mod->>'quantity')::integer, 1);
        EXCEPTION WHEN OTHERS THEN
          RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Mã topping hoặc số lượng topping không hợp lệ');
        END;
        IF v_tid IS NULL OR v_tq < 1 OR v_tq > 20 THEN
          RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Số lượng topping phải từ 1 đến 20');
        END IF;
        IF v_tid = ANY (v_seen) THEN
          RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Topping bị lặp trong cùng một món');
        END IF;
        v_seen := array_append(v_seen, v_tid);

        SELECT p.id, p.name, COALESCE(p.sell_price, 0) AS sell_price INTO v_top
        FROM public.products p
        WHERE p.id = v_tid AND p.store_id = p_store_id
          AND COALESCE(p.is_active, true) AND NOT COALESCE(p.is_deleted, false)
          AND COALESCE(p.is_available, true) AND COALESCE(p.is_topping, false)
          AND COALESCE(p.product_type, 'finished') = 'finished' AND NOT COALESCE(p.is_raw_material, false);
        IF NOT FOUND OR NOT EXISTS (
          SELECT 1 FROM public.product_topping_links l
          WHERE l.product_id = v_prod.id AND l.topping_id = v_top.id
        ) THEN
          RETURN public.qr_err_v4('PRODUCT_NOT_AVAILABLE', 'Topping không áp dụng cho món này hoặc đã ngừng phục vụ');
        END IF;

        v_tops := v_tops + v_top.sell_price * v_tq;
        v_mods := v_mods || jsonb_build_array(jsonb_build_object(
          'id', v_top.id, 'name', v_top.name, 'price', v_top.sell_price, 'quantity', v_tq));
      END LOOP;
    END IF;

    v_unit := v_prod.sell_price + v_tops;
    v_sub := v_unit * v_qty;
    v_total := v_total + v_sub;
    v_clean := v_clean || jsonb_build_array(jsonb_build_object(
      'product_id', v_prod.id, 'product_name', v_prod.name, 'unit_price', v_unit,
      'quantity', v_qty, 'subtotal', v_sub, 'modifiers_json', v_mods, 'note', v_note));
  END LOOP;

  RETURN jsonb_build_object('success', true, 'items', v_clean, 'total', v_total);
END
$fn$;

-- Trừ kho một dòng (sản phẩm hoặc topping) — cùng quy đổi đơn vị/hao hụt với settle V5 (fix09).
CREATE OR REPLACE FUNCTION public.qr_deduct_stock_v4(
  p_store_id uuid, p_order_id uuid, p_order_number text,
  p_product_id uuid, p_qty numeric, p_label text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_has_recipe boolean;
  v_ing record;
  v_amt numeric;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.recipes r
    JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
    WHERE r.pos_product_id::text = p_product_id::text AND COALESCE(r.is_deleted, false) = false
  ) INTO v_has_recipe;

  IF v_has_recipe THEN
    FOR v_ing IN
      SELECT ri.ingredient_id, ri.quantity, ri.yield_factor, ri.unit AS recipe_unit,
             p.unit AS prod_unit, COALESCE(p.conversion_rate, 0) AS conversion_rate,
             COALESCE(p.conversion_unit, '') AS conversion_unit
      FROM public.recipes r
      JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
      LEFT JOIN public.products p ON p.id::text = ri.ingredient_id::text AND p.store_id = p_store_id
      WHERE r.pos_product_id::text = p_product_id::text
        AND COALESCE(r.is_deleted, false) = false
        AND ri.ingredient_id IS NOT NULL
    LOOP
      v_amt := public.convert_recipe_ingredient_qty_v1(
        (v_ing.quantity / CASE WHEN v_ing.yield_factor IS NULL OR v_ing.yield_factor <= 0 THEN 1.0 ELSE v_ing.yield_factor END) * p_qty,
        v_ing.recipe_unit, v_ing.prod_unit, v_ing.conversion_rate, v_ing.conversion_unit);
      INSERT INTO public.stock_movements (id, store_id, product_id, delta, reason, reference_id, note, created_at)
      VALUES (gen_random_uuid(), p_store_id, v_ing.ingredient_id::uuid, -v_amt, 'recipe_usage', p_order_id,
              'QR mang đi công thức #' || p_order_number || ': ' || p_label, now());
      UPDATE public.products
      SET stock_qty = COALESCE(stock_qty, 0) - v_amt, updated_at = extract(epoch from now()) * 1000
      WHERE id = v_ing.ingredient_id::uuid AND store_id = p_store_id;
    END LOOP;
  ELSE
    INSERT INTO public.stock_movements (id, store_id, product_id, delta, reason, reference_id, note, created_at)
    VALUES (gen_random_uuid(), p_store_id, p_product_id, -p_qty, 'sale', p_order_id,
            'QR mang đi #' || p_order_number || ': ' || p_label, now());
    UPDATE public.products
    SET stock_qty = COALESCE(stock_qty, 0) - p_qty, updated_at = extract(epoch from now()) * 1000
    WHERE id = p_product_id AND store_id = p_store_id;
  END IF;
END
$fn$;

-- Tìm-hoặc-tạo phiên mở của bàn dưới advisory lock theo (quán, bàn).
CREATE OR REPLACE FUNCTION public.qr_open_session_v4(p_store_id uuid, p_table_id text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_id uuid;
  v_type text;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('qr_table:' || p_store_id::text), hashtext(lower(p_table_id)));

  SELECT bs.id INTO v_id
  FROM public.ban_sessions bs
  WHERE bs.store_id = p_store_id AND bs.status = 'open' AND lower(bs.table_id::text) = lower(p_table_id)
  ORDER BY bs.opened_at DESC LIMIT 1;
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;

  SELECT data_type INTO v_type FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'ban_sessions' AND column_name = 'table_id';

  v_id := gen_random_uuid();
  BEGIN
    IF v_type = 'uuid' THEN
      -- ban_dining_tables.id là text nhưng ban_sessions.table_id là uuid: id bàn lạ (không phải uuid) thì dừng rõ ràng.
      IF p_table_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        RAISE EXCEPTION 'TABLE_ID_NOT_UUID: id bàn không đúng dạng uuid, không thể mở phiên bàn';
      END IF;
      INSERT INTO public.ban_sessions (id, store_id, table_id, status, opened_at, total_amount, guest_count)
      VALUES (v_id, p_store_id, p_table_id::uuid, 'open', now(), 0, 1);
    ELSE
      INSERT INTO public.ban_sessions (id, store_id, table_id, status, opened_at, total_amount, guest_count)
      VALUES (v_id, p_store_id, p_table_id, 'open', now(), 0, 1);
    END IF;
  EXCEPTION WHEN unique_violation THEN
    -- app Flutter (openSession) mở bàn không qua advisory lock: lấy phiên vừa được tạo
    SELECT bs.id INTO v_id
    FROM public.ban_sessions bs
    WHERE bs.store_id = p_store_id AND bs.status = 'open' AND lower(bs.table_id::text) = lower(p_table_id)
    ORDER BY bs.opened_at DESC LIMIT 1;
    IF v_id IS NULL THEN RAISE; END IF;
  END;
  RETURN v_id;
END
$fn$;

-- JSON chi tiết đơn (dùng chung claim / detail / update).
CREATE OR REPLACE FUNCTION public.qr_request_json_v4(p_req public.qr_requests)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
  SELECT jsonb_build_object(
    'id', p_req.id,
    'store_id', p_req.store_id,
    'channel_id', p_req.channel_id,
    'type', p_req.type,
    'table_id', p_req.table_id,
    'table_name', p_req.table_name,
    'pickup_code', p_req.pickup_code,
    'tracking_token', p_req.tracking_token,
    'status', p_req.status,
    'payment_status', p_req.payment_status,
    'payment_method', p_req.payment_method,
    'customer_note', p_req.customer_note,
    'reject_reason', p_req.reject_reason,
    'total_amount', p_req.total_amount,
    'version', p_req.version,
    'claimed_by', p_req.claimed_by,
    'claimed_at', p_req.claimed_at,
    'session_id', p_req.session_id,
    'order_id', p_req.order_id,
    'ticket_id', p_req.ticket_id,
    'created_at', p_req.created_at,
    'updated_at', p_req.updated_at,
    'expires_at', p_req.expires_at,
    'original_items', p_req.original_items,
    'items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'id', i.id, 'product_id', i.product_id, 'product_name', i.product_name,
               'unit_price', i.unit_price, 'quantity', i.quantity, 'subtotal', i.subtotal,
               'modifiers_json', i.modifiers_json, 'note', i.note
             ) ORDER BY i.created_at, i.id)
      FROM public.qr_request_items i WHERE i.request_id = p_req.id
    ), '[]'::jsonb)
  )
$fn$;

-- ============================================================================
-- 5. RPC CÔNG KHAI (anon) — đúng 4 hàm
-- ============================================================================

-- 5.1 get_qr_channel_info_v4
CREATE OR REPLACE FUNCTION public.get_qr_channel_info_v4(p_channel_code text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ch public.qr_channels%ROWTYPE;
  v_store_name text;
BEGIN
  IF p_channel_code IS NULL OR char_length(p_channel_code) > 64 THEN
    RETURN public.qr_err_v4('INVALID_QR', 'Mã QR không hợp lệ');
  END IF;
  SELECT * INTO v_ch FROM public.qr_channels WHERE channel_code = btrim(p_channel_code) AND is_active;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('CHANNEL_DISABLED', 'Kênh gọi món này hiện đang tạm đóng hoặc không tồn tại');
  END IF;
  SELECT s.name INTO v_store_name FROM public.stores s WHERE s.id = v_ch.store_id;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'id', v_ch.id, 'channel_id', v_ch.id, 'store_id', v_ch.store_id,
    'store_name', COALESCE(v_store_name, 'Quán Nhỏ'),
    'type', v_ch.type, 'channel_code', v_ch.channel_code, 'name', v_ch.name,
    'payment_mode', v_ch.payment_mode, 'is_active', v_ch.is_active, 'created_at', v_ch.created_at));
END
$fn$;

-- 5.2 get_qr_menu_v4 (+ data.tables, data.channel_type)
CREATE OR REPLACE FUNCTION public.get_qr_menu_v4(p_channel_code text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ch public.qr_channels%ROWTYPE;
  v_store_name text;
  v_products jsonb;
  v_toppings jsonb;
  v_links jsonb;
  v_tables jsonb := '[]'::jsonb;
BEGIN
  IF p_channel_code IS NULL OR char_length(p_channel_code) > 64 THEN
    RETURN public.qr_err_v4('INVALID_QR', 'Mã QR không hợp lệ');
  END IF;
  SELECT * INTO v_ch FROM public.qr_channels WHERE channel_code = btrim(p_channel_code) AND is_active;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('CHANNEL_DISABLED', 'Kênh gọi món này hiện đang tạm đóng');
  END IF;
  SELECT s.name INTO v_store_name FROM public.stores s WHERE s.id = v_ch.store_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', p.id, 'name', p.name, 'category', p.category, 'sell_price', p.sell_price,
           'image_url', p.image_url, 'is_active', true
         ) ORDER BY p.category, p.name), '[]'::jsonb)
  INTO v_products
  FROM public.products p
  WHERE p.store_id = v_ch.store_id AND COALESCE(p.is_active, true) AND NOT COALESCE(p.is_deleted, false)
    AND COALESCE(p.is_available, true) AND NOT COALESCE(p.is_topping, false)
    AND COALESCE(p.product_type, 'finished') = 'finished' AND NOT COALESCE(p.is_raw_material, false);  -- không bán nguyên liệu

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'id', p.id, 'name', p.name, 'sell_price', p.sell_price, 'unit', p.unit, 'is_active', true
         ) ORDER BY p.name), '[]'::jsonb)
  INTO v_toppings
  FROM public.products p
  WHERE p.store_id = v_ch.store_id AND COALESCE(p.is_active, true) AND NOT COALESCE(p.is_deleted, false)
    AND COALESCE(p.is_available, true) AND COALESCE(p.is_topping, false)
    AND COALESCE(p.product_type, 'finished') = 'finished' AND NOT COALESCE(p.is_raw_material, false);

  SELECT COALESCE(jsonb_agg(jsonb_build_object('product_id', l.product_id, 'topping_id', l.topping_id)), '[]'::jsonb)
  INTO v_links
  FROM public.product_topping_links l
  JOIN public.products lp ON lp.id = l.product_id AND lp.store_id = v_ch.store_id;

  IF v_ch.type = 'TABLE_SHARED' THEN
    v_tables := public.qr_list_tables_v4(v_ch.store_id);
  END IF;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'store_id', v_ch.store_id, 'store_name', COALESCE(v_store_name, 'Quán Nhỏ'),
    'channel_type', v_ch.type, 'channel_code', v_ch.channel_code, 'payment_mode', v_ch.payment_mode,
    'products', v_products, 'toppings', v_toppings, 'topping_links', v_links, 'tables', v_tables));
END
$fn$;

-- 5.3 submit_qr_order_v4
CREATE OR REPLACE FUNCTION public.submit_qr_order_v4(
  p_channel_code text,
  p_items jsonb,
  p_table_id text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL,
  p_payload_hash text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  -- Giới hạn tần suất theo KÊNH (anon không có IP): chỉnh tại đây nếu cần
  c_max_unclaimed   constant integer := 40;  -- đơn submitted chưa nhận, chưa hết hạn / kênh
  c_max_per_minute  constant integer := 15;  -- đơn tạo trong 60 giây / kênh
  c_max_per_table   constant integer := 5;   -- đơn submitted chưa nhận / một bàn
  v_ch public.qr_channels%ROWTYPE;
  v_ex public.qr_requests%ROWTYPE;
  v_tbl record;
  v_price jsonb;
  v_key text;
  v_hash text;
  v_table_id text := NULL;
  v_table_name text := NULL;
  v_req_id uuid := gen_random_uuid();
  v_token text;
  v_date date := NULL;
  v_seq integer := NULL;
  v_code text := NULL;
  v_expires timestamptz := now() + interval '60 minutes';
  v_item jsonb;
BEGIN
  v_key := btrim(COALESCE(p_idempotency_key, ''));
  IF char_length(v_key) < 8 OR char_length(v_key) > 128 THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Khóa chống trùng (idempotency key) phải dài 8-128 ký tự');
  END IF;
  v_hash := NULLIF(lower(btrim(COALESCE(p_payload_hash, ''))), '');
  IF v_hash IS NOT NULL AND v_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Payload hash phải là SHA-256 hex (64 ký tự)');
  END IF;
  IF p_channel_code IS NULL OR char_length(p_channel_code) > 64 THEN
    RETURN public.qr_err_v4('INVALID_QR', 'Mã QR không hợp lệ');
  END IF;

  SELECT * INTO v_ch FROM public.qr_channels WHERE channel_code = btrim(p_channel_code) AND is_active;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('CHANNEL_DISABLED', 'Kênh gọi món này hiện đang tạm đóng');
  END IF;

  -- Thứ tự khóa cố định (khóa key -> khóa kênh) để không deadlock
  PERFORM pg_advisory_xact_lock(hashtext('qr_submit:' || v_ch.store_id::text), hashtext(v_key));

  -- Idempotency: cùng key trả lại đúng đơn cũ
  SELECT * INTO v_ex FROM public.qr_requests WHERE store_id = v_ch.store_id AND idempotency_key = v_key;
  IF FOUND THEN
    IF v_ex.channel_id <> v_ch.id
       OR (v_hash IS NOT NULL AND v_ex.payload_hash IS NOT NULL AND v_ex.payload_hash <> v_hash) THEN
      RETURN public.qr_err_v4('IDEMPOTENCY_CONFLICT', 'Khóa chống trùng đã dùng cho nội dung khác');
    END IF;
    RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
      'request_id', v_ex.id, 'tracking_token', v_ex.tracking_token, 'status', v_ex.status,
      'pickup_code', v_ex.pickup_code, 'table_id', v_ex.table_id, 'table_name', v_ex.table_name,
      'total_amount', v_ex.total_amount, 'expires_at', v_ex.expires_at, 'is_replay', true));
  END IF;

  -- Bàn (chỉ TABLE_SHARED): phải thuộc ĐÚNG quán của kênh
  IF v_ch.type = 'TABLE_SHARED' THEN
    v_table_id := btrim(COALESCE(p_table_id, ''));
    IF v_table_id = '' THEN
      RETURN public.qr_err_v4('TABLE_REQUIRED', 'Vui lòng chọn bàn');
    END IF;
    IF char_length(v_table_id) > 64 THEN
      RETURN public.qr_err_v4('TABLE_NOT_FOUND', 'Bàn không tồn tại');
    END IF;
    SELECT * INTO v_tbl FROM public.qr_table_info_v4(v_ch.store_id, v_table_id);
    IF NOT FOUND OR NOT v_tbl.t_active THEN
      RETURN public.qr_err_v4('TABLE_NOT_FOUND', 'Bàn không tồn tại hoặc đã ngừng sử dụng');
    END IF;
    v_table_id := v_tbl.t_id;
    v_table_name := v_tbl.t_name;
  END IF;

  -- Giới hạn tần suất theo kênh (khóa kênh để đếm nhất quán giữa các key khác nhau)
  PERFORM pg_advisory_xact_lock(hashtext('qr_channel'), hashtext(v_ch.id::text));
  IF (SELECT count(*) FROM public.qr_requests r
      WHERE r.channel_id = v_ch.id AND r.status = 'submitted' AND r.expires_at > now()) >= c_max_unclaimed
     OR (SELECT count(*) FROM public.qr_requests r
         WHERE r.channel_id = v_ch.id AND r.created_at > now() - interval '60 seconds') >= c_max_per_minute
     OR (v_table_id IS NOT NULL AND (SELECT count(*) FROM public.qr_requests r
         WHERE r.channel_id = v_ch.id AND r.table_id = v_table_id AND r.status = 'submitted'
           AND r.expires_at > now()) >= c_max_per_table) THEN
    RETURN public.qr_err_v4('RATE_LIMITED', 'Quán đang nhận quá nhiều đơn, vui lòng thử lại sau ít phút');
  END IF;

  v_price := public.qr_price_items_v4(v_ch.store_id, p_items);
  IF NOT (v_price->>'success')::boolean THEN RETURN v_price; END IF;

  -- Mã nhận món theo ngày của quán (không giới hạn 99)
  IF v_ch.type = 'COUNTER_TAKEAWAY' THEN
    v_date := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
    INSERT INTO public.qr_pickup_counters AS c (store_id, pickup_date, last_seq)
    VALUES (v_ch.store_id, v_date, 1)
    ON CONFLICT (store_id, pickup_date) DO UPDATE SET last_seq = c.last_seq + 1
    RETURNING c.last_seq INTO v_seq;
    -- lpad() CẮT chuỗi dài hơn độ rộng (lpad('100',2,'0') = '10'), nên chỉ đệm số 0 khi < 10.
    v_code := '#Q' || CASE WHEN v_seq < 10 THEN '0' || v_seq::text ELSE v_seq::text END;
  END IF;

  v_token := 'TRK_' || upper(encode(gen_random_bytes(16), 'hex'));

  INSERT INTO public.qr_requests (
    id, store_id, channel_id, type, table_id, table_name, pickup_date, pickup_seq, pickup_code,
    tracking_token, idempotency_key, payload_hash, status, payment_status,
    total_amount, original_items, expires_at
  ) VALUES (
    v_req_id, v_ch.store_id, v_ch.id, v_ch.type, v_table_id, v_table_name, v_date, v_seq, v_code,
    v_token, v_key, v_hash, 'submitted', 'unpaid',
    (v_price->>'total')::numeric, v_price->'items', v_expires
  );

  FOR v_item IN SELECT value FROM jsonb_array_elements(v_price->'items')
  LOOP
    INSERT INTO public.qr_request_items (
      request_id, product_id, product_name, unit_price, quantity, subtotal, modifiers_json, note
    ) VALUES (
      v_req_id, (v_item->>'product_id')::uuid, v_item->>'product_name',
      (v_item->>'unit_price')::numeric, (v_item->>'quantity')::integer,
      (v_item->>'subtotal')::numeric, v_item->'modifiers_json', COALESCE(v_item->>'note', '')
    );
  END LOOP;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'request_id', v_req_id, 'tracking_token', v_token, 'status', 'submitted',
    'pickup_code', v_code, 'table_id', v_table_id, 'table_name', v_table_name,
    'total_amount', (v_price->>'total')::numeric, 'expires_at', v_expires, 'is_replay', false));
END
$fn$;

-- 5.4 get_qr_request_status_v4 (đánh expired khi đọc, theo giờ server)
CREATE OR REPLACE FUNCTION public.get_qr_request_status_v4(p_tracking_token text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_req public.qr_requests%ROWTYPE;
BEGIN
  IF p_tracking_token IS NULL OR char_length(p_tracking_token) > 100 THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Không tìm thấy đơn hàng');
  END IF;
  SELECT * INTO v_req FROM public.qr_requests WHERE tracking_token = btrim(p_tracking_token);
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Không tìm thấy đơn hàng');
  END IF;

  IF v_req.status = 'submitted' AND v_req.expires_at < now() THEN
    UPDATE public.qr_requests
    SET status = 'expired', version = version + 1, updated_at = now()
    WHERE id = v_req.id AND status = 'submitted' AND expires_at < now();
    SELECT * INTO v_req FROM public.qr_requests WHERE id = v_req.id;
  END IF;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'id', v_req.id, 'type', v_req.type, 'status', v_req.status, 'payment_status', v_req.payment_status,
    'table_id', v_req.table_id, 'table_name', v_req.table_name, 'pickup_code', v_req.pickup_code,
    'total_amount', v_req.total_amount, 'reject_reason', v_req.reject_reason,
    'expires_at', v_req.expires_at, 'updated_at', v_req.updated_at,
    'items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'product_name', i.product_name, 'unit_price', i.unit_price, 'quantity', i.quantity,
               'subtotal', i.subtotal, 'modifiers_json', i.modifiers_json, 'note', i.note
             ) ORDER BY i.created_at, i.id)
      FROM public.qr_request_items i WHERE i.request_id = v_req.id), '[]'::jsonb)));
END
$fn$;

-- ============================================================================
-- 6. RPC NHÂN VIÊN (authenticated)
--    Mọi hàm: qr_staff_ctx_v4 (active membership đúng store_id) -> FOR UPDATE ->
--    kiểm trạng thái -> kiểm người nhận (claimed_by) hoặc owner/manager.
-- ============================================================================

-- 6.1 get_qr_request_detail_v4
CREATE OR REPLACE FUNCTION public.get_qr_request_detail_v4(p_request_id uuid, p_store_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ctx jsonb;
  v_req public.qr_requests%ROWTYPE;
BEGIN
  v_ctx := public.qr_staff_ctx_v4(p_store_id);
  IF NOT (v_ctx->>'success')::boolean THEN RETURN v_ctx; END IF;
  SELECT * INTO v_req FROM public.qr_requests WHERE id = p_request_id AND store_id = p_store_id;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Không tìm thấy đơn hàng');
  END IF;
  RETURN jsonb_build_object('success', true, 'data', public.qr_request_json_v4(v_req));
END
$fn$;

-- 6.2 claim_qr_request_v4 — atomic submitted -> claimed
CREATE OR REPLACE FUNCTION public.claim_qr_request_v4(p_request_id uuid, p_store_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ctx jsonb;
  v_uid uuid;
  v_req public.qr_requests%ROWTYPE;
BEGIN
  v_ctx := public.qr_staff_ctx_v4(p_store_id);
  IF NOT (v_ctx->>'success')::boolean THEN RETURN v_ctx; END IF;
  v_uid := (v_ctx->>'uid')::uuid;

  SELECT * INTO v_req FROM public.qr_requests WHERE id = p_request_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Không tìm thấy đơn hàng');
  END IF;

  IF v_req.status = 'submitted' THEN
    IF v_req.expires_at < now() THEN
      UPDATE public.qr_requests SET status = 'expired', version = version + 1, updated_at = now() WHERE id = v_req.id;
      RETURN public.qr_err_v4('REQUEST_EXPIRED', 'Đơn đã hết hạn');
    END IF;
    UPDATE public.qr_requests
    SET status = 'claimed', claimed_by = v_uid, claimed_at = now(), version = version + 1, updated_at = now()
    WHERE id = v_req.id;
    INSERT INTO public.qr_audit_logs (store_id, request_id, action, actor_user_id, details)
    VALUES (p_store_id, v_req.id, 'claim', v_uid, '{}'::jsonb);
  ELSIF v_req.status = 'claimed' THEN
    IF v_req.claimed_by IS DISTINCT FROM v_uid THEN
      RETURN public.qr_err_v4('ALREADY_CLAIMED', 'Đơn đã có người khác nhận');
    END IF;
    -- gọi lại bởi chính người đã nhận: idempotent
  ELSIF v_req.status = 'expired' THEN
    RETURN public.qr_err_v4('REQUEST_EXPIRED', 'Đơn đã hết hạn');
  ELSE
    RETURN public.qr_err_v4('INVALID_STATE', 'Đơn không còn ở trạng thái chờ nhận');
  END IF;

  SELECT * INTO v_req FROM public.qr_requests WHERE id = p_request_id;
  RETURN jsonb_build_object('success', true, 'data', public.qr_request_json_v4(v_req));
END
$fn$;

-- 6.3 update_qr_order_items_v4 — chỉ status='claimed', chỉ người nhận / owner / manager
CREATE OR REPLACE FUNCTION public.update_qr_order_items_v4(
  p_request_id uuid, p_store_id uuid, p_expected_version integer, p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ctx jsonb;
  v_uid uuid;
  v_req public.qr_requests%ROWTYPE;
  v_price jsonb;
  v_item jsonb;
BEGIN
  v_ctx := public.qr_staff_ctx_v4(p_store_id);
  IF NOT (v_ctx->>'success')::boolean THEN RETURN v_ctx; END IF;
  v_uid := (v_ctx->>'uid')::uuid;

  SELECT * INTO v_req FROM public.qr_requests WHERE id = p_request_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Không tìm thấy đơn hàng');
  END IF;
  IF v_req.status <> 'claimed' THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Chỉ sửa được đơn đang ở trạng thái đã nhận');
  END IF;
  IF v_req.claimed_by IS DISTINCT FROM v_uid AND NOT (v_ctx->>'is_manager')::boolean THEN
    RETURN public.qr_err_v4('NOT_CLAIMER', 'Đơn đang do nhân viên khác xử lý');
  END IF;
  IF v_req.version <> p_expected_version THEN
    RETURN public.qr_err_v4('VERSION_CONFLICT', 'Đơn đã được cập nhật từ thiết bị khác, vui lòng tải lại');
  END IF;

  v_price := public.qr_price_items_v4(p_store_id, p_items);
  IF NOT (v_price->>'success')::boolean THEN RETURN v_price; END IF;

  DELETE FROM public.qr_request_items WHERE request_id = v_req.id;
  FOR v_item IN SELECT value FROM jsonb_array_elements(v_price->'items')
  LOOP
    INSERT INTO public.qr_request_items (
      request_id, product_id, product_name, unit_price, quantity, subtotal, modifiers_json, note
    ) VALUES (
      v_req.id, (v_item->>'product_id')::uuid, v_item->>'product_name',
      (v_item->>'unit_price')::numeric, (v_item->>'quantity')::integer,
      (v_item->>'subtotal')::numeric, v_item->'modifiers_json', COALESCE(v_item->>'note', '')
    );
  END LOOP;

  -- original_items (snapshot khách gửi) KHÔNG bị đụng tới
  UPDATE public.qr_requests
  SET total_amount = (v_price->>'total')::numeric, version = version + 1, updated_at = now()
  WHERE id = v_req.id;

  INSERT INTO public.qr_audit_logs (store_id, request_id, action, actor_user_id, details)
  VALUES (p_store_id, v_req.id, 'update_items', v_uid,
          jsonb_build_object('total_amount', (v_price->>'total')::numeric,
                             'lines', jsonb_array_length(v_price->'items')));

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'request_id', v_req.id, 'total_amount', (v_price->>'total')::numeric,
    'version', v_req.version + 1, 'items', v_price->'items'));
END
$fn$;

-- 6.4 set_qr_order_table_v4 — đổi bàn khi status='claimed' (thay assign_qr_order_table_v4)
CREATE OR REPLACE FUNCTION public.set_qr_order_table_v4(p_request_id uuid, p_store_id uuid, p_table_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ctx jsonb;
  v_uid uuid;
  v_req public.qr_requests%ROWTYPE;
  v_tbl record;
  v_tid text;
BEGIN
  v_ctx := public.qr_staff_ctx_v4(p_store_id);
  IF NOT (v_ctx->>'success')::boolean THEN RETURN v_ctx; END IF;
  v_uid := (v_ctx->>'uid')::uuid;

  SELECT * INTO v_req FROM public.qr_requests WHERE id = p_request_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Không tìm thấy đơn hàng');
  END IF;
  IF v_req.type <> 'TABLE_SHARED' OR v_req.status <> 'claimed' THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Chỉ đổi bàn được cho đơn tại bàn đang ở trạng thái đã nhận');
  END IF;
  IF v_req.claimed_by IS DISTINCT FROM v_uid AND NOT (v_ctx->>'is_manager')::boolean THEN
    RETURN public.qr_err_v4('NOT_CLAIMER', 'Đơn đang do nhân viên khác xử lý');
  END IF;

  v_tid := btrim(COALESCE(p_table_id, ''));
  IF v_tid = '' THEN
    RETURN public.qr_err_v4('TABLE_REQUIRED', 'Vui lòng chọn bàn');
  END IF;
  IF char_length(v_tid) > 64 THEN
    RETURN public.qr_err_v4('TABLE_NOT_FOUND', 'Bàn không tồn tại');
  END IF;
  SELECT * INTO v_tbl FROM public.qr_table_info_v4(p_store_id, v_tid);
  IF NOT FOUND OR NOT v_tbl.t_active THEN
    RETURN public.qr_err_v4('TABLE_NOT_FOUND', 'Bàn không thuộc quán này hoặc đã ngừng sử dụng');
  END IF;

  UPDATE public.qr_requests
  SET table_id = v_tbl.t_id, table_name = v_tbl.t_name, version = version + 1, updated_at = now()
  WHERE id = v_req.id;
  INSERT INTO public.qr_audit_logs (store_id, request_id, action, actor_user_id, details)
  VALUES (p_store_id, v_req.id, 'set_table', v_uid,
          jsonb_build_object('from', v_req.table_id, 'to', v_tbl.t_id));

  SELECT * INTO v_req FROM public.qr_requests WHERE id = p_request_id;
  RETURN jsonb_build_object('success', true, 'data', public.qr_request_json_v4(v_req));
END
$fn$;

-- 6.5 approve_and_send_table_v4 — TABLE: gắn vào phiên bàn + vé bếp, KHÔNG thu tiền, KHÔNG trừ kho
CREATE OR REPLACE FUNCTION public.approve_and_send_table_v4(p_request_id uuid, p_store_id uuid, p_version integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ctx jsonb;
  v_uid uuid;
  v_req public.qr_requests%ROWTYPE;
  v_tbl record;
  v_sess uuid;
  v_staff uuid;
  v_order_id uuid := gen_random_uuid();
  v_order_no text;
  v_item record;
  v_cost numeric;
  v_si uuid;
  v_oi uuid;
  v_ids uuid[] := ARRAY[]::uuid[];
  v_n integer := 0;
  v_k jsonb;
  v_ticket uuid;
BEGIN
  v_ctx := public.qr_staff_ctx_v4(p_store_id);
  IF NOT (v_ctx->>'success')::boolean THEN RETURN v_ctx; END IF;
  v_uid := (v_ctx->>'uid')::uuid;

  SELECT * INTO v_req FROM public.qr_requests WHERE id = p_request_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Không tìm thấy đơn hàng');
  END IF;
  IF v_req.type <> 'TABLE_SHARED' THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Đơn mang đi phải dùng "Đã thu tiền & gửi bếp"');
  END IF;
  IF v_req.claimed_by IS NOT NULL AND v_req.claimed_by IS DISTINCT FROM v_uid AND NOT (v_ctx->>'is_manager')::boolean THEN
    RETURN public.qr_err_v4('NOT_CLAIMER', 'Đơn đang do nhân viên khác xử lý');
  END IF;

  -- Gọi lại: trả kết quả cũ, không sinh order/vé bếp mới
  IF v_req.status = 'sent_kitchen' THEN
    RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
      'request_id', v_req.id, 'status', v_req.status, 'session_id', v_req.session_id,
      'order_id', v_req.order_id, 'ticket_id', v_req.ticket_id, 'table_id', v_req.table_id,
      'table_name', v_req.table_name, 'version', v_req.version, 'is_replay', true));
  END IF;
  IF v_req.status = 'expired' THEN
    RETURN public.qr_err_v4('REQUEST_EXPIRED', 'Đơn đã hết hạn');
  END IF;
  IF v_req.status <> 'claimed' THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Đơn phải được nhận trước khi duyệt');
  END IF;
  IF p_version IS NULL OR v_req.version <> p_version THEN
    RETURN public.qr_err_v4('VERSION_CONFLICT', 'Đơn đã được cập nhật từ thiết bị khác, vui lòng tải lại');
  END IF;

  IF v_req.table_id IS NULL THEN
    RETURN public.qr_err_v4('TABLE_REQUIRED', 'Vui lòng chọn bàn trước khi duyệt');
  END IF;
  SELECT * INTO v_tbl FROM public.qr_table_info_v4(p_store_id, v_req.table_id);
  IF NOT FOUND OR NOT v_tbl.t_active THEN
    RETURN public.qr_err_v4('TABLE_NOT_FOUND', 'Bàn không thuộc quán này hoặc đã ngừng sử dụng');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.qr_request_items WHERE request_id = v_req.id) THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Đơn không có món');
  END IF;

  -- Phiên bàn: khóa theo bàn, không bao giờ tạo hai phiên mở
  BEGIN
    v_sess := public.qr_open_session_v4(p_store_id, v_tbl.t_id);
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN public.qr_err_v4('TABLE_NOT_FOUND', 'Mã bàn không dùng được để mở phiên bàn');
  END;

  v_staff := public.qr_ensure_staff_v4(p_store_id, v_uid, v_ctx->>'role');
  v_order_no := public.generate_daily_order_number_v1(p_store_id, 'QR');

  -- Order canonical mở; settle V5 sẽ chốt tiền + trừ kho khi thanh toán cả bàn
  INSERT INTO public.orders (
    id, store_id, order_number, subtotal, discount, tax, total, total_amount,
    payment_method, status, source_type, source_id, staff_id, receipt_printed, created_at, note
  ) VALUES (
    v_order_id, p_store_id, v_order_no, v_req.total_amount, 0, 0, v_req.total_amount, v_req.total_amount,
    'unpaid', 'open', 'qr_table', v_req.id::text, v_staff, false, now(),
    'Đơn QR ' || v_tbl.t_name
  );
  INSERT INTO public.ban_session_orders (id, store_id, session_id, order_id, qr_request_id, created_at)
  VALUES (gen_random_uuid(), p_store_id, v_sess, v_order_id, v_req.id, now());

  FOR v_item IN
    SELECT * FROM public.qr_request_items WHERE request_id = v_req.id ORDER BY created_at, id
  LOOP
    SELECT COALESCE(p.cost_price_latest, 0) INTO v_cost FROM public.products p WHERE p.id = v_item.product_id;
    v_si := gen_random_uuid();
    v_oi := gen_random_uuid();

    INSERT INTO public.ban_session_items (
      id, store_id, session_id, product_id, product_name, unit_price, price,
      quantity, subtotal, kitchen_status, added_at, note, modifiers_json
    ) VALUES (
      v_si, p_store_id, v_sess, v_item.product_id, v_item.product_name, v_item.unit_price, v_item.unit_price,
      v_item.quantity, v_item.subtotal, 'chua_gui', now(), v_item.note, v_item.modifiers_json::text
    );
    INSERT INTO public.order_items (
      id, store_id, order_id, product_id, name, product_name, qty, quantity,
      unit_price, cost_price, subtotal, modifiers_json
    ) VALUES (
      v_oi, p_store_id, v_order_id, v_item.product_id, v_item.product_name, v_item.product_name,
      v_item.quantity, v_item.quantity, v_item.unit_price, COALESCE(v_cost, 0),
      v_item.subtotal, v_item.modifiers_json::text
    );
    INSERT INTO public.ban_session_order_items (
      id, store_id, session_id, session_item_id, order_id, order_item_id, source_type, created_at
    ) VALUES (
      gen_random_uuid(), p_store_id, v_sess, v_si, v_order_id, v_oi, 'qr_table', now()
    );
    v_ids := array_append(v_ids, v_si);
    v_n := v_n + 1;
  END LOOP;

  -- Vé bếp qua đúng đường của app (round, station_code, 'da_gui') — chỉ các món vừa tạo
  v_k := public.send_kitchen_ticket_v2(
    v_sess, p_store_id, v_tbl.t_name, COALESCE(v_tbl.t_zone, 'Khu vực'),
    'Đơn QR ' || v_tbl.t_name, v_ids);
  IF COALESCE((v_k->>'success')::boolean, false) IS NOT TRUE
     OR COALESCE((v_k->>'items_count')::integer, 0) <> v_n THEN
    RAISE EXCEPTION 'QR_KITCHEN_FAIL: send_kitchen_ticket_v2 trả % (kỳ vọng % món)', v_k::text, v_n;
  END IF;
  v_ticket := (v_k->>'ticket_id')::uuid;

  UPDATE public.qr_requests
  SET status = 'sent_kitchen', session_id = v_sess, order_id = v_order_id, ticket_id = v_ticket,
      sent_at = now(), version = version + 1, updated_at = now()
  WHERE id = v_req.id;
  INSERT INTO public.qr_audit_logs (store_id, request_id, action, actor_user_id, details)
  VALUES (p_store_id, v_req.id, 'approve_send_table', v_uid,
          jsonb_build_object('session_id', v_sess, 'order_id', v_order_id, 'ticket_id', v_ticket,
                             'table_id', v_tbl.t_id));

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'request_id', v_req.id, 'status', 'sent_kitchen', 'session_id', v_sess, 'order_id', v_order_id,
    'ticket_id', v_ticket, 'table_id', v_tbl.t_id, 'table_name', v_tbl.t_name,
    'version', v_req.version + 1, 'is_replay', false));
END
$fn$;

-- 6.6 pay_and_send_counter_v4 — COUNTER: order + finance + trừ kho + vé bếp, một giao dịch
CREATE OR REPLACE FUNCTION public.pay_and_send_counter_v4(
  p_request_id uuid, p_store_id uuid, p_version integer, p_payment_method text DEFAULT 'cash'
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ctx jsonb;
  v_uid uuid;
  v_req public.qr_requests%ROWTYPE;
  v_method text;
  v_staff uuid;
  v_order_id uuid := gen_random_uuid();
  v_order_no text;
  v_ticket uuid := gen_random_uuid();
  v_item record;
  v_mod jsonb;
  v_cost numeric;
  v_station text;
  v_label text;
  v_fund text;
  v_n integer := 0;
BEGIN
  -- Quyền thu tiền kiểm Ở SERVER (owner/manager/cashier hoặc modules pos / pos.checkout)
  v_ctx := public.qr_staff_ctx_v4(p_store_id, true, false);
  IF NOT (v_ctx->>'success')::boolean THEN RETURN v_ctx; END IF;
  v_uid := (v_ctx->>'uid')::uuid;

  v_method := lower(btrim(COALESCE(p_payment_method, 'cash')));
  IF v_method NOT IN ('cash', 'transfer', 'card', 'bank') THEN
    RETURN public.qr_err_v4('INVALID_PAYMENT_METHOD', 'Phương thức thanh toán không hợp lệ');
  END IF;

  SELECT * INTO v_req FROM public.qr_requests WHERE id = p_request_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Không tìm thấy đơn hàng');
  END IF;
  IF v_req.type <> 'COUNTER_TAKEAWAY' THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Đơn tại bàn thanh toán khi trả bàn, không thu tiền ở đây');
  END IF;
  IF v_req.claimed_by IS NOT NULL AND v_req.claimed_by IS DISTINCT FROM v_uid AND NOT (v_ctx->>'is_manager')::boolean THEN
    RETURN public.qr_err_v4('NOT_CLAIMER', 'Đơn đang do nhân viên khác xử lý');
  END IF;

  IF v_req.status = 'sent_kitchen' THEN
    RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
      'request_id', v_req.id, 'status', v_req.status, 'payment_status', v_req.payment_status,
      'order_id', v_req.order_id, 'ticket_id', v_req.ticket_id, 'pickup_code', v_req.pickup_code,
      'version', v_req.version, 'is_replay', true));
  END IF;
  IF v_req.status = 'expired' THEN
    RETURN public.qr_err_v4('REQUEST_EXPIRED', 'Đơn đã hết hạn');
  END IF;
  IF v_req.status <> 'claimed' OR v_req.claimed_by IS NULL THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Đơn phải được nhận trước khi thu tiền');
  END IF;
  IF p_version IS NULL OR v_req.version <> p_version THEN
    RETURN public.qr_err_v4('VERSION_CONFLICT', 'Đơn đã được cập nhật từ thiết bị khác, vui lòng tải lại');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.qr_request_items WHERE request_id = v_req.id) THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Đơn không có món');
  END IF;

  v_staff := public.qr_ensure_staff_v4(p_store_id, v_uid, v_ctx->>'role');
  v_order_no := public.generate_daily_order_number_v1(p_store_id, 'QR');
  v_label := 'Mang đi ' || COALESCE(v_req.pickup_code, '');
  v_fund := CASE WHEN v_method IN ('transfer', 'card', 'bank') THEN 'bank' ELSE 'cash' END;

  INSERT INTO public.orders (
    id, store_id, order_number, subtotal, discount, tax, total, total_amount,
    payment_method, status, source_type, source_id, staff_id, receipt_printed, created_at, note
  ) VALUES (
    v_order_id, p_store_id, v_order_no, v_req.total_amount, 0, 0, v_req.total_amount, v_req.total_amount,
    v_method, 'completed', 'qr_counter', v_req.id::text, v_staff, false, now(),
    'Đơn QR ' || v_label
  );

  INSERT INTO public.kitchen_tickets (
    id, store_id, session_id, table_label, zone_label, round, status, sent_at, note
  ) VALUES (
    v_ticket, p_store_id, NULL, v_label, 'Mang đi', 1, 'cho', clock_timestamp(), 'Đơn QR ' || v_label
  );

  FOR v_item IN
    SELECT * FROM public.qr_request_items WHERE request_id = v_req.id ORDER BY created_at, id
  LOOP
    SELECT COALESCE(p.cost_price_latest, 0), COALESCE(p.station_code, 'nong')
    INTO v_cost, v_station FROM public.products p WHERE p.id = v_item.product_id;

    INSERT INTO public.order_items (
      id, store_id, order_id, product_id, name, product_name, qty, quantity,
      unit_price, cost_price, subtotal, modifiers_json
    ) VALUES (
      gen_random_uuid(), p_store_id, v_order_id, v_item.product_id, v_item.product_name, v_item.product_name,
      v_item.quantity, v_item.quantity, v_item.unit_price, COALESCE(v_cost, 0),
      v_item.subtotal, v_item.modifiers_json::text
    );

    -- Trừ kho (COUNTER chỉ trừ ở đây): món + từng topping
    PERFORM public.qr_deduct_stock_v4(p_store_id, v_order_id, v_order_no, v_item.product_id,
                                      v_item.quantity::numeric, v_item.product_name);
    FOR v_mod IN SELECT value FROM jsonb_array_elements(v_item.modifiers_json)
    LOOP
      PERFORM public.qr_deduct_stock_v4(
        p_store_id, v_order_id, v_order_no, (v_mod->>'id')::uuid,
        COALESCE((v_mod->>'quantity')::numeric, 1) * v_item.quantity,
        COALESCE(v_mod->>'name', 'Topping'));
    END LOOP;

    INSERT INTO public.kitchen_ticket_items (
      id, store_id, ticket_id, session_item_id, product_id, name, product_name, qty, quantity,
      free_note, kitchen_note, modifiers_json, station_code, done
    ) VALUES (
      gen_random_uuid(), p_store_id, v_ticket, NULL, v_item.product_id, v_item.product_name,
      v_item.product_name, v_item.quantity::integer, v_item.quantity,
      v_item.note, v_item.modifiers_json::text, v_item.modifiers_json::text, v_station, false
    );
    v_n := v_n + 1;
  END LOOP;

  INSERT INTO public.finance_records (
    id, store_id, type, amount, description, reference_id, is_auto, recorded_at, fund_type
  ) VALUES (
    gen_random_uuid(), p_store_id, 'income', v_req.total_amount,
    'Bán hàng mang đi #' || v_order_no || ' (' || COALESCE(v_req.pickup_code, 'QR') || ')',
    v_order_id, true, now(), v_fund
  );

  UPDATE public.qr_requests
  SET status = 'sent_kitchen', payment_status = 'paid', payment_method = v_method,
      order_id = v_order_id, ticket_id = v_ticket, sent_at = now(),
      version = version + 1, updated_at = now()
  WHERE id = v_req.id;
  INSERT INTO public.qr_audit_logs (store_id, request_id, action, actor_user_id, details)
  VALUES (p_store_id, v_req.id, 'pay_send_counter', v_uid,
          jsonb_build_object('order_id', v_order_id, 'ticket_id', v_ticket,
                             'amount', v_req.total_amount, 'payment_method', v_method, 'lines', v_n));

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'request_id', v_req.id, 'status', 'sent_kitchen', 'payment_status', 'paid',
    'order_id', v_order_id, 'order_number', v_order_no, 'ticket_id', v_ticket,
    'pickup_code', v_req.pickup_code, 'version', v_req.version + 1, 'is_replay', false));
END
$fn$;

-- 6.7 cancel_qr_order_v4 — chỉ trước sent_kitchen
--     submitted -> rejected (mọi thành viên active); claimed -> cancelled (người nhận / owner / manager)
CREATE OR REPLACE FUNCTION public.cancel_qr_order_v4(p_request_id uuid, p_store_id uuid, p_reason text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ctx jsonb;
  v_uid uuid;
  v_req public.qr_requests%ROWTYPE;
  v_new text;
  v_reason text := left(btrim(COALESCE(p_reason, '')), 300);
BEGIN
  v_ctx := public.qr_staff_ctx_v4(p_store_id);
  IF NOT (v_ctx->>'success')::boolean THEN RETURN v_ctx; END IF;
  v_uid := (v_ctx->>'uid')::uuid;

  SELECT * INTO v_req FROM public.qr_requests WHERE id = p_request_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Không tìm thấy đơn hàng');
  END IF;

  IF v_req.status IN ('rejected', 'cancelled') THEN
    RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
      'request_id', v_req.id, 'status', v_req.status, 'is_replay', true));
  END IF;
  IF v_req.status = 'sent_kitchen' THEN
    RETURN public.qr_err_v4('ALREADY_SENT', 'Đơn đã vào bếp, không hủy ở đây (hủy món ở màn Bàn)');
  END IF;
  IF v_req.status NOT IN ('submitted', 'claimed') THEN
    RETURN public.qr_err_v4('INVALID_STATE', 'Đơn không còn hủy được');
  END IF;
  IF v_req.status = 'claimed'
     AND v_req.claimed_by IS DISTINCT FROM v_uid AND NOT (v_ctx->>'is_manager')::boolean THEN
    RETURN public.qr_err_v4('NOT_CLAIMER', 'Đơn đang do nhân viên khác xử lý');
  END IF;

  v_new := CASE WHEN v_req.status = 'submitted' THEN 'rejected' ELSE 'cancelled' END;
  UPDATE public.qr_requests
  SET status = v_new, reject_reason = NULLIF(v_reason, ''), version = version + 1, updated_at = now()
  WHERE id = v_req.id;
  INSERT INTO public.qr_audit_logs (store_id, request_id, action, actor_user_id, details)
  VALUES (p_store_id, v_req.id, 'cancel_order', v_uid,
          jsonb_build_object('from', v_req.status, 'to', v_new, 'reason', NULLIF(v_reason, '')));

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'request_id', v_req.id, 'status', v_new, 'version', v_req.version + 1, 'is_replay', false));
END
$fn$;

-- 6.8 manage_qr_channel_v4 — khóa advisory để gọi đồng thời không vỡ unique
CREATE OR REPLACE FUNCTION public.manage_qr_channel_v4(
  p_store_id uuid, p_type text, p_is_active boolean DEFAULT true, p_payment_mode text DEFAULT 'CASHIER_CONFIRM'
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ctx jsonb;
  v_type text;
  v_mode text;
  v_ch public.qr_channels%ROWTYPE;
  v_code text;
  v_tries integer := 0;
BEGIN
  v_ctx := public.qr_staff_ctx_v4(p_store_id, false, true);
  IF NOT (v_ctx->>'success')::boolean THEN RETURN v_ctx; END IF;

  v_type := CASE upper(btrim(COALESCE(p_type, '')))
              WHEN 'TABLE_SHARED' THEN 'TABLE_SHARED' WHEN 'TABLE' THEN 'TABLE_SHARED'
              WHEN 'COUNTER_TAKEAWAY' THEN 'COUNTER_TAKEAWAY' WHEN 'COUNTER' THEN 'COUNTER_TAKEAWAY'
              ELSE NULL END;
  IF v_type IS NULL THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Loại kênh không hợp lệ');
  END IF;
  v_mode := COALESCE(NULLIF(btrim(p_payment_mode), ''), 'CASHIER_CONFIRM');
  IF v_mode NOT IN ('PAY_BEFORE_KITCHEN', 'CASHIER_CONFIRM') THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Chế độ thanh toán không hợp lệ');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('qr_manage_channel:' || p_store_id::text), hashtext(v_type));

  SELECT * INTO v_ch FROM public.qr_channels WHERE store_id = p_store_id AND type = v_type;
  IF FOUND THEN
    UPDATE public.qr_channels
    SET is_active = COALESCE(p_is_active, true), payment_mode = v_mode
    WHERE id = v_ch.id
    RETURNING * INTO v_ch;
  ELSE
    LOOP
      v_code := CASE WHEN v_type = 'TABLE_SHARED' THEN 'TBL' ELSE 'CTR' END
                || '_' || upper(encode(gen_random_bytes(6), 'hex'));
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.qr_channels WHERE channel_code = v_code);
      v_tries := v_tries + 1;
      IF v_tries > 10 THEN
        RAISE EXCEPTION 'QR_CHANNEL_CODE_FAIL: không sinh được mã kênh duy nhất';
      END IF;
    END LOOP;
    INSERT INTO public.qr_channels (store_id, type, channel_code, name, is_active, payment_mode)
    VALUES (p_store_id, v_type, v_code,
            CASE WHEN v_type = 'TABLE_SHARED' THEN 'QR Dùng Chung Tại Bàn' ELSE 'Quầy Mang Đi' END,
            COALESCE(p_is_active, true), v_mode)
    RETURNING * INTO v_ch;
  END IF;

  INSERT INTO public.qr_audit_logs (store_id, request_id, action, actor_user_id, details)
  VALUES (p_store_id, NULL, 'manage_channel', (v_ctx->>'uid')::uuid,
          jsonb_build_object('type', v_type, 'is_active', v_ch.is_active, 'channel_id', v_ch.id));

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'id', v_ch.id, 'store_id', v_ch.store_id, 'type', v_ch.type, 'channel_code', v_ch.channel_code,
    'name', v_ch.name, 'is_active', v_ch.is_active, 'payment_mode', v_ch.payment_mode,
    'created_at', v_ch.created_at));
END
$fn$;

-- ============================================================================
-- 7. RLS + QUYỀN
-- ============================================================================
ALTER TABLE public.qr_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_pickup_counters ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.qr_channels, public.qr_requests, public.qr_request_items,
  public.qr_pickup_counters FROM PUBLIC, anon, authenticated;
-- Staff đọc hàng chờ trực tiếp (realtime/polling); mọi ghi đi qua RPC. anon: KHÔNG có gì.
GRANT SELECT ON TABLE public.qr_channels, public.qr_requests, public.qr_request_items TO authenticated;

DROP POLICY IF EXISTS qr_channels_staff_select ON public.qr_channels;
CREATE POLICY qr_channels_staff_select ON public.qr_channels
  FOR SELECT TO authenticated
  USING (public.qr_is_active_member_v4(store_id));

DROP POLICY IF EXISTS qr_requests_staff_select ON public.qr_requests;
CREATE POLICY qr_requests_staff_select ON public.qr_requests
  FOR SELECT TO authenticated
  USING (public.qr_is_active_member_v4(store_id));

DROP POLICY IF EXISTS qr_request_items_staff_select ON public.qr_request_items;
CREATE POLICY qr_request_items_staff_select ON public.qr_request_items
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.qr_requests r
    WHERE r.id = qr_request_items.request_id AND public.qr_is_active_member_v4(r.store_id)
  ));

-- Hàm: thu hồi mặc định (Supabase mặc định cấp EXECUTE cho anon/authenticated) rồi cấp lại tối thiểu.
REVOKE ALL ON FUNCTION public.qr_err_v4(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.qr_is_active_member_v4(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.qr_staff_ctx_v4(uuid, boolean, boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.qr_ensure_staff_v4(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.qr_price_items_v4(uuid, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.qr_deduct_stock_v4(uuid, uuid, text, uuid, numeric, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.qr_open_session_v4(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.qr_request_json_v4(public.qr_requests) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.qr_table_info_v4(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.qr_list_tables_v4(uuid) FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.get_qr_channel_info_v4(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_qr_menu_v4(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.submit_qr_order_v4(text, jsonb, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_qr_request_status_v4(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_qr_request_detail_v4(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.claim_qr_request_v4(uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_qr_order_items_v4(uuid, uuid, integer, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_qr_order_table_v4(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.approve_and_send_table_v4(uuid, uuid, integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pay_and_send_counter_v4(uuid, uuid, integer, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cancel_qr_order_v4(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.manage_qr_channel_v4(uuid, text, boolean, text) FROM PUBLIC, anon, authenticated;

-- anon: ĐÚNG 4 RPC công khai
GRANT EXECUTE ON FUNCTION public.get_qr_channel_info_v4(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_qr_menu_v4(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_qr_order_v4(text, jsonb, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_qr_request_status_v4(text) TO anon, authenticated;

-- Nhân viên: chỉ authenticated (bên trong đã kiểm active membership đúng store_id)
GRANT EXECUTE ON FUNCTION public.get_qr_request_detail_v4(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_qr_request_v4(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_qr_order_items_v4(uuid, uuid, integer, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_qr_order_table_v4(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_and_send_table_v4(uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pay_and_send_counter_v4(uuid, uuid, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_qr_order_v4(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.manage_qr_channel_v4(uuid, text, boolean, text) TO authenticated;
-- Dùng trong policy RLS (chỉ trả về tư cách thành viên của chính người gọi)
GRANT EXECUTE ON FUNCTION public.qr_is_active_member_v4(uuid, uuid) TO authenticated;

-- ============================================================================
-- 8. MỘT PHIÊN MỞ MỖI BÀN (partial unique) — chỉ tạo nếu dữ liệu hiện tại cho phép
-- ============================================================================
DO $idx$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.ban_sessions
    WHERE status = 'open'
    GROUP BY store_id, lower(table_id::text)
    HAVING count(*) > 1
  ) THEN
    RAISE WARNING 'QR: đã có bàn với >1 phiên mở — BỎ QUA tạo uq_ban_sessions_one_open_per_table. Dọn phiên trùng rồi tạo tay: CREATE UNIQUE INDEX uq_ban_sessions_one_open_per_table ON public.ban_sessions (store_id, table_id) WHERE status = ''open''. Trong lúc đó chỉ advisory lock bảo vệ luồng QR.';
  ELSE
    CREATE UNIQUE INDEX IF NOT EXISTS uq_ban_sessions_one_open_per_table
      ON public.ban_sessions (store_id, table_id) WHERE status = 'open';
  END IF;
END
$idx$;

COMMIT;
