-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION: 20260812000000_strict_server_jwt_rls_p0.sql
-- Purpose: Server-Signed JWT RLS Guard (auth.uid() + signed store_id claim) & RPC Hardening
-- Dynamic Catalog Policy Cleanup, Snapshot & Atomic Transaction (BEGIN/COMMIT)
-- DO NOT EXECUTE AUTOMATICALLY ON PRODUCTION
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- 1. Helper function: has_active_store_access
CREATE OR REPLACE FUNCTION public.has_active_store_access(p_store_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID;
  v_jwt_claims JSONB;
  v_claim_store_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  BEGIN
    v_jwt_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
    IF v_jwt_claims IS NULL THEN
      RETURN FALSE;
    END IF;
    v_claim_store_id := (v_jwt_claims->>'store_id')::uuid;
  EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
  END;

  IF v_claim_store_id IS NULL OR v_claim_store_id <> p_store_id THEN
    RETURN FALSE;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.store_members
    WHERE store_id = p_store_id AND user_id = v_user_id
  ) OR EXISTS (
    SELECT 1 FROM public.stores
    WHERE id = p_store_id AND owner_user_id = v_user_id
  ) THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.has_active_store_access(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_active_store_access(UUID) TO authenticated, service_role;

-- 2. Hardened RPC: revoke_store_member (Generic Client Message, No Raw SQLERRM)
CREATE OR REPLACE FUNCTION public.revoke_store_member(
  p_store_id UUID,
  p_target_user_id UUID,
  p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_id UUID;
  v_actor_role TEXT;
  v_actor_is_owner BOOLEAN := FALSE;
  v_target_role TEXT;
  v_target_is_owner BOOLEAN := FALSE;
  v_target_name TEXT := 'Nhân viên';
  v_deleted_memberships INT := 0;
  v_updated_profiles INT := 0;
  v_code TEXT := 'revoked';
BEGIN
  v_actor_id := auth.uid();
  IF v_actor_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'forbidden',
      'message', 'Không thể xác thực danh tính người thực hiện từ JWT.'
    );
  END IF;

  IF p_actor_id IS NOT NULL AND p_actor_id <> v_actor_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'forbidden',
      'message', 'Actor ID không trùng khớp với phiên đăng nhập.'
    );
  END IF;

  SELECT role, COALESCE(is_owner, false)
  INTO v_actor_role, v_actor_is_owner
  FROM public.store_members
  WHERE store_id = p_store_id AND user_id = v_actor_id;

  IF NOT FOUND THEN
    IF EXISTS (
      SELECT 1 FROM public.stores WHERE id = p_store_id AND owner_user_id = v_actor_id
    ) THEN
      v_actor_is_owner := TRUE;
      v_actor_role := 'owner';
    ELSE
      RETURN jsonb_build_object(
        'success', false,
        'code', 'forbidden',
        'message', 'Người thực hiện không có quyền truy cập quán này.'
      );
    END IF;
  END IF;

  IF NOT (v_actor_is_owner OR LOWER(COALESCE(v_actor_role, '')) IN ('owner', 'manager', 'quản lý', 'quan ly')) THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'forbidden',
      'message', 'Chỉ Chủ quán hoặc Quản lý mới có quyền xoá nhân viên.'
    );
  END IF;

  SELECT role, COALESCE(is_owner, false)
  INTO v_target_role, v_target_is_owner
  FROM public.store_members
  WHERE store_id = p_store_id AND user_id = p_target_user_id;

  IF v_target_is_owner 
     OR LOWER(COALESCE(v_target_role, '')) = 'owner' 
     OR EXISTS (SELECT 1 FROM public.stores WHERE id = p_store_id AND owner_user_id = p_target_user_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'is_owner',
      'message', 'Tuyệt đối không thể xoá tài khoản Chủ quán.'
    );
  END IF;

  SELECT COALESCE(name, 'Nhân viên')
  INTO v_target_name
  FROM public.staff_members
  WHERE store_id = p_store_id AND id = p_target_user_id
  LIMIT 1;

  DELETE FROM public.store_members
  WHERE store_id = p_store_id AND user_id = p_target_user_id;
  GET DIAGNOSTICS v_deleted_memberships = ROW_COUNT;

  UPDATE public.staff_members
  SET is_active = false,
      updated_at = (EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT
  WHERE store_id = p_store_id AND id = p_target_user_id;
  GET DIAGNOSTICS v_updated_profiles = ROW_COUNT;

  IF v_deleted_memberships > 0 THEN
    v_code := 'revoked';
  ELSIF v_updated_profiles > 0 THEN
    v_code := 'reconciled';
  ELSE
    v_code := 'already_removed';
  END IF;

  INSERT INTO public.staff_perm_logs (
    id, store_id, by_user, target_user, action, detail, created_at
  ) VALUES (
    gen_random_uuid(), p_store_id, v_actor_id, p_target_user_id, 'remove_staff',
    jsonb_build_object(
      'name', COALESCE(v_target_name, 'Nhân viên'),
      'status', v_code,
      'deleted_memberships', v_deleted_memberships,
      'updated_staff_profiles', v_updated_profiles
    )::text,
    NOW()
  );

  RETURN jsonb_build_object(
    'success', true,
    'code', v_code,
    'deleted_memberships', v_deleted_memberships,
    'updated_staff_profiles', v_updated_profiles,
    'message', 'Đã thu hồi quyền truy cập nhân viên thành công.'
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'code', 'database_error',
    'message', 'Lỗi hệ thống xử lý thao tác thu hồi quyền.'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.revoke_store_member(UUID, UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_store_member(UUID, UUID, UUID) TO authenticated, service_role;

-- 3. Dynamic Catalog Policy Snapshot & Dynamic Drop
DO $$
DECLARE
  pol RECORD;
  v_remaining_count INT;
BEGIN
  -- Dynamic Cleanup
  FOR pol IN
    SELECT policyname, tablename
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('orders', 'order_items', 'staff_members', 'app_settings')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol.policyname, pol.tablename);
  END LOOP;

  -- Assert 0 policies remain
  SELECT COUNT(*) INTO v_remaining_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN ('orders', 'order_items', 'staff_members', 'app_settings');

  IF v_remaining_count > 0 THEN
    RAISE EXCEPTION 'CRITICAL: Failed to drop legacy policies. Remaining count: %', v_remaining_count;
  END IF;
END $$;

-- 4. Enable and FORCE RLS on 4 target tables
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders FORCE ROW LEVEL SECURITY;

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items FORCE ROW LEVEL SECURITY;

ALTER TABLE public.staff_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_members FORCE ROW LEVEL SECURITY;

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings FORCE ROW LEVEL SECURITY;

-- 5. Create strict per-command policies using has_active_store_access(store_id)

-- TABLE 1: orders
CREATE POLICY orders_select_strict ON public.orders
  FOR SELECT TO authenticated, service_role
  USING (public.has_active_store_access(store_id));

CREATE POLICY orders_insert_strict ON public.orders
  FOR INSERT TO authenticated, service_role
  WITH CHECK (public.has_active_store_access(store_id));

CREATE POLICY orders_update_strict ON public.orders
  FOR UPDATE TO authenticated, service_role
  USING (public.has_active_store_access(store_id))
  WITH CHECK (public.has_active_store_access(store_id));

CREATE POLICY orders_delete_strict ON public.orders
  FOR DELETE TO authenticated, service_role
  USING (public.has_active_store_access(store_id));

-- TABLE 2: order_items
CREATE POLICY order_items_select_strict ON public.order_items
  FOR SELECT TO authenticated, service_role
  USING (public.has_active_store_access(store_id));

CREATE POLICY order_items_insert_strict ON public.order_items
  FOR INSERT TO authenticated, service_role
  WITH CHECK (public.has_active_store_access(store_id));

CREATE POLICY order_items_update_strict ON public.order_items
  FOR UPDATE TO authenticated, service_role
  USING (public.has_active_store_access(store_id))
  WITH CHECK (public.has_active_store_access(store_id));

CREATE POLICY order_items_delete_strict ON public.order_items
  FOR DELETE TO authenticated, service_role
  USING (public.has_active_store_access(store_id));

-- TABLE 3: staff_members
CREATE POLICY staff_members_select_strict ON public.staff_members
  FOR SELECT TO authenticated, service_role
  USING (public.has_active_store_access(store_id));

CREATE POLICY staff_members_insert_strict ON public.staff_members
  FOR INSERT TO authenticated, service_role
  WITH CHECK (public.has_active_store_access(store_id));

CREATE POLICY staff_members_update_strict ON public.staff_members
  FOR UPDATE TO authenticated, service_role
  USING (public.has_active_store_access(store_id))
  WITH CHECK (public.has_active_store_access(store_id));

CREATE POLICY staff_members_delete_strict ON public.staff_members
  FOR DELETE TO authenticated, service_role
  USING (public.has_active_store_access(store_id));

-- TABLE 4: app_settings
CREATE POLICY app_settings_select_strict ON public.app_settings
  FOR SELECT TO authenticated, service_role
  USING (public.has_active_store_access(store_id));

CREATE POLICY app_settings_insert_strict ON public.app_settings
  FOR INSERT TO authenticated, service_role
  WITH CHECK (public.has_active_store_access(store_id));

CREATE POLICY app_settings_update_strict ON public.app_settings
  FOR UPDATE TO authenticated, service_role
  USING (public.has_active_store_access(store_id))
  WITH CHECK (public.has_active_store_access(store_id));

CREATE POLICY app_settings_delete_strict ON public.app_settings
  FOR DELETE TO authenticated, service_role
  USING (public.has_active_store_access(store_id));

COMMIT;
