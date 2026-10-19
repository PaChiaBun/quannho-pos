-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION: 20260808_revoke_staff_and_rls_p0.sql
-- Purpose: RPC Security Definer Header Verification (x-user-id), Realtime, & RLS Guard
-- DO NOT EXECUTE AUTOMATICALLY ON PRODUCTION
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Enable REPLICA IDENTITY FULL on store_members for Postgres Realtime DELETE events
ALTER TABLE IF EXISTS public.store_members REPLICA IDENTITY FULL;

-- 2. Add store_members to supabase_realtime publication if not already added
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables 
      WHERE pubname = 'supabase_realtime' AND tablename = 'store_members'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.store_members;
    END IF;
  END IF;
END $$;

-- 3. Atomic Staff Revocation RPC (Strict Header Verification: x-user-id)
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
  v_request_user_id_text TEXT;
  v_verified_actor_id UUID;
  v_actor_role TEXT;
  v_actor_is_owner BOOLEAN := FALSE;
  v_target_role TEXT;
  v_target_is_owner BOOLEAN := FALSE;
  v_target_name TEXT := 'Nhân viên';
  v_deleted_memberships INT := 0;
  v_updated_profiles INT := 0;
  v_code TEXT := 'revoked';
BEGIN
  -- 3.0 Extract & Verify request x-user-id header strictly
  BEGIN
    v_request_user_id_text := NULLIF(current_setting('request.headers', true)::json->>'x-user-id', '');
    IF v_request_user_id_text IS NOT NULL THEN
      v_verified_actor_id := v_request_user_id_text::UUID;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_verified_actor_id := NULL;
  END;

  -- 100% Strict Header Requirement: NO fallback to p_actor_id
  IF v_verified_actor_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'forbidden',
      'message', 'Không thể xác thực danh tính người thực hiện.'
    );
  END IF;

  -- Guard: IF p_actor_id is explicitly passed, it MUST match the request header user ID
  IF p_actor_id IS NOT NULL AND p_actor_id <> v_verified_actor_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'forbidden',
      'message', 'Actor ID không trùng khớp với phiên đăng nhập.'
    );
  END IF;

  -- 3.1 Check actor permissions using verified actor ID
  SELECT role, COALESCE(is_owner, false)
  INTO v_actor_role, v_actor_is_owner
  FROM public.store_members
  WHERE store_id = p_store_id AND user_id = v_verified_actor_id;

  IF NOT FOUND THEN
    -- Check if actor is store owner in stores (using correct column owner_user_id)
    IF EXISTS (
      SELECT 1 FROM public.stores WHERE id = p_store_id AND owner_user_id = v_verified_actor_id
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

  IF NOT (v_actor_is_owner OR LOWER(COALESCE(v_actor_role, '')) IN ('owner', 'manager', 'quản lý')) THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'forbidden',
      'message', 'Chỉ Chủ quán hoặc Quản lý mới có quyền xoá nhân viên.'
    );
  END IF;

  -- 3.2 Check target permissions (Cannot revoke store owner)
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

  -- Get target display name for audit log
  SELECT COALESCE(name, 'Nhân viên')
  INTO v_target_name
  FROM public.staff_members
  WHERE store_id = p_store_id AND id = p_target_user_id
  LIMIT 1;

  IF v_target_name IS NULL OR v_target_name = 'Nhân viên' THEN
    SELECT COALESCE(display_name, 'Nhân viên')
    INTO v_target_name
    FROM public.user_accounts
    WHERE id = p_target_user_id;
  END IF;

  -- 3.3 Atomic Delete from store_members
  DELETE FROM public.store_members
  WHERE store_id = p_store_id AND user_id = p_target_user_id;
  GET DIAGNOSTICS v_deleted_memberships = ROW_COUNT;

  -- 3.4 Atomic Update staff_members (using correct primary column: staff_members.id)
  UPDATE public.staff_members
  SET is_active = false,
      updated_at = (EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT
  WHERE store_id = p_store_id AND id = p_target_user_id;
  GET DIAGNOSTICS v_updated_profiles = ROW_COUNT;

  -- Determine status code & handle orphan reconciliation
  IF v_deleted_memberships > 0 THEN
    v_code := 'revoked';
  ELSIF v_updated_profiles > 0 THEN
    v_code := 'reconciled';
  ELSE
    v_code := 'already_removed';
  END IF;

  -- 3.5 Single Audit Log Entry (staff_perm_logs.detail is TEXT, by_user uses verified actor)
  INSERT INTO public.staff_perm_logs (
    id,
    store_id,
    by_user,
    target_user,
    action,
    detail,
    created_at
  ) VALUES (
    gen_random_uuid(),
    p_store_id,
    v_verified_actor_id,
    p_target_user_id,
    'remove_staff',
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
    'message', SQLERRM
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.revoke_store_member(UUID, UUID, UUID) TO anon, authenticated, service_role;

-- 4. Store Membership Active Check Helper for RLS
CREATE OR REPLACE FUNCTION public.current_store_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_store_id_text TEXT;
  v_user_id_text TEXT;
  v_store_id UUID;
  v_user_id UUID;
BEGIN
  v_store_id_text := NULLIF(current_setting('request.headers', true)::json->>'x-store-id', '');
  v_user_id_text  := NULLIF(current_setting('request.headers', true)::json->>'x-user-id', '');

  IF v_store_id_text IS NULL OR v_user_id_text IS NULL THEN
    RETURN NULL;
  END IF;

  BEGIN
    v_store_id := v_store_id_text::UUID;
    v_user_id  := v_user_id_text::UUID;
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;

  -- Active Membership Guard: User MUST exist in store_members OR be owner_user_id in stores
  IF EXISTS (
    SELECT 1 FROM public.store_members
    WHERE store_id = v_store_id AND user_id = v_user_id
  ) OR EXISTS (
    SELECT 1 FROM public.stores
    WHERE id = v_store_id AND owner_user_id = v_user_id
  ) THEN
    RETURN v_store_id;
  ELSE
    RETURN NULL;
  END IF;
END;
$$;
