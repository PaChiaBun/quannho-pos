-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION: 20260808043000_fix_rls_permissive_policies_p0.sql
-- Purpose: Remove permissive policies (USING true) and enforce fail-closed store_id isolation
-- Target Scope: STRICTLY 4 TABLES (orders, order_items, staff_members, app_settings)
-- DO NOT MODIFY: stores, products, devices, ban_sessions, kitchen_tickets, kitchen_ticket_items
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Explicitly drop all previous policies on the 4 target tables
DROP POLICY IF EXISTS "orders_all" ON public.orders;
DROP POLICY IF EXISTS "orders_read_all" ON public.orders;
DROP POLICY IF EXISTS "orders_isolation" ON public.orders;
DROP POLICY IF EXISTS "orders_select_policy" ON public.orders;
DROP POLICY IF EXISTS "orders_insert_policy" ON public.orders;
DROP POLICY IF EXISTS "orders_update_policy" ON public.orders;
DROP POLICY IF EXISTS "orders_delete_policy" ON public.orders;
DROP POLICY IF EXISTS "orders_select_isolation" ON public.orders;
DROP POLICY IF EXISTS "orders_insert_isolation" ON public.orders;
DROP POLICY IF EXISTS "orders_update_isolation" ON public.orders;
DROP POLICY IF EXISTS "orders_delete_isolation" ON public.orders;

DROP POLICY IF EXISTS "order_items_all" ON public.order_items;
DROP POLICY IF EXISTS "order_items_read_all" ON public.order_items;
DROP POLICY IF EXISTS "order_items_isolation" ON public.order_items;
DROP POLICY IF EXISTS "order_items_select_policy" ON public.order_items;
DROP POLICY IF EXISTS "order_items_insert_policy" ON public.order_items;
DROP POLICY IF EXISTS "order_items_update_policy" ON public.order_items;
DROP POLICY IF EXISTS "order_items_delete_policy" ON public.order_items;
DROP POLICY IF EXISTS "order_items_select_isolation" ON public.order_items;
DROP POLICY IF EXISTS "order_items_insert_isolation" ON public.order_items;
DROP POLICY IF EXISTS "order_items_update_isolation" ON public.order_items;
DROP POLICY IF EXISTS "order_items_delete_isolation" ON public.order_items;

DROP POLICY IF EXISTS "staff_select" ON public.staff_members;
DROP POLICY IF EXISTS "staff_insert" ON public.staff_members;
DROP POLICY IF EXISTS "staff_update" ON public.staff_members;
DROP POLICY IF EXISTS "staff_delete" ON public.staff_members;
DROP POLICY IF EXISTS "staff_isolation" ON public.staff_members;
DROP POLICY IF EXISTS "staff_members_isolation" ON public.staff_members;
DROP POLICY IF EXISTS "staff_members_read_all" ON public.staff_members;
DROP POLICY IF EXISTS "staff_members_select_policy" ON public.staff_members;
DROP POLICY IF EXISTS "staff_members_insert_policy" ON public.staff_members;
DROP POLICY IF EXISTS "staff_members_update_policy" ON public.staff_members;
DROP POLICY IF EXISTS "staff_members_delete_policy" ON public.staff_members;
DROP POLICY IF EXISTS "staff_members_select_isolation" ON public.staff_members;
DROP POLICY IF EXISTS "staff_members_insert_isolation" ON public.staff_members;
DROP POLICY IF EXISTS "staff_members_update_isolation" ON public.staff_members;
DROP POLICY IF EXISTS "staff_members_delete_isolation" ON public.staff_members;

DROP POLICY IF EXISTS "settings_all" ON public.app_settings;
DROP POLICY IF EXISTS "settings_isolation" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_read_all" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_isolation" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_select_policy" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_insert_policy" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_update_policy" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_delete_policy" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_select_isolation" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_insert_isolation" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_update_isolation" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_delete_isolation" ON public.app_settings;

-- 2. Ensure RLS is enabled on the 4 target tables
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- 3. Create command-specific fail-closed policies for each table
-- BẢNG 1: orders
CREATE POLICY orders_select_isolation ON public.orders
  FOR SELECT
  USING (store_id = public.current_store_id());

CREATE POLICY orders_insert_isolation ON public.orders
  FOR INSERT
  WITH CHECK (store_id = public.current_store_id());

CREATE POLICY orders_update_isolation ON public.orders
  FOR UPDATE
  USING (store_id = public.current_store_id())
  WITH CHECK (store_id = public.current_store_id());

CREATE POLICY orders_delete_isolation ON public.orders
  FOR DELETE
  USING (store_id = public.current_store_id());

-- BẢNG 2: order_items
CREATE POLICY order_items_select_isolation ON public.order_items
  FOR SELECT
  USING (store_id = public.current_store_id());

CREATE POLICY order_items_insert_isolation ON public.order_items
  FOR INSERT
  WITH CHECK (store_id = public.current_store_id());

CREATE POLICY order_items_update_isolation ON public.order_items
  FOR UPDATE
  USING (store_id = public.current_store_id())
  WITH CHECK (store_id = public.current_store_id());

CREATE POLICY order_items_delete_isolation ON public.order_items
  FOR DELETE
  USING (store_id = public.current_store_id());

-- BẢNG 3: staff_members
CREATE POLICY staff_members_select_isolation ON public.staff_members
  FOR SELECT
  USING (store_id = public.current_store_id());

CREATE POLICY staff_members_insert_isolation ON public.staff_members
  FOR INSERT
  WITH CHECK (store_id = public.current_store_id());

CREATE POLICY staff_members_update_isolation ON public.staff_members
  FOR UPDATE
  USING (store_id = public.current_store_id())
  WITH CHECK (store_id = public.current_store_id());

CREATE POLICY staff_members_delete_isolation ON public.staff_members
  FOR DELETE
  USING (store_id = public.current_store_id());

-- BẢNG 4: app_settings
CREATE POLICY app_settings_select_isolation ON public.app_settings
  FOR SELECT
  USING (store_id = public.current_store_id());

CREATE POLICY app_settings_insert_isolation ON public.app_settings
  FOR INSERT
  WITH CHECK (store_id = public.current_store_id());

CREATE POLICY app_settings_update_isolation ON public.app_settings
  FOR UPDATE
  USING (store_id = public.current_store_id())
  WITH CHECK (store_id = public.current_store_id());

CREATE POLICY app_settings_delete_isolation ON public.app_settings
  FOR DELETE
  USING (store_id = public.current_store_id());
