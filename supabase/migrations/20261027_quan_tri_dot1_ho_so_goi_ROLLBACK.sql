-- ============================================================================
-- HOÀN TÁC 20261027_quan_tri_dot1_ho_so_goi.sql
--   • Mở mọi quán đang khoá (status 'locked' → 'active' nếu pro, 'trial' nếu free) — hết cơ chế khoá thì không để kẹt.
--   • Trả current_store_id() và admin_store_list_v1 về bản trước; gỡ trigger chốt cột gói + các hàm mới.
--   • GIỮ dữ liệu: bảng admin_store_actions / admin_store_notes / platform_settings và cột stores.plan_ends_at
--     (xoá tay nếu chắc chắn không cần: DROP TABLE ...; ALTER TABLE public.stores DROP COLUMN plan_ends_at).
-- ============================================================================
BEGIN;

DROP TRIGGER IF EXISTS qn_stores_guard_plan_cols ON public.stores;
DROP FUNCTION IF EXISTS public.qn_stores_guard_plan_cols();

UPDATE public.stores SET status = CASE WHEN plan = 'pro' THEN 'active' ELSE 'trial' END WHERE status = 'locked';

CREATE OR REPLACE FUNCTION public.current_store_id()
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE _raw text; _claims jsonb; _store uuid; _user uuid;
BEGIN
  BEGIN _claims := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb; EXCEPTION WHEN OTHERS THEN _claims := NULL; END;
  BEGIN _raw := NULLIF(current_setting('request.headers', true)::json->>'x-store-id', ''); EXCEPTION WHEN OTHERS THEN _raw := NULL; END;
  IF (_raw IS NULL OR _raw = '') AND _claims IS NOT NULL THEN _raw := NULLIF(_claims->>'store_id', ''); END IF;
  IF _raw IS NULL OR NOT (_raw ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') THEN RETURN NULL; END IF;
  _store := _raw::uuid;
  _user := public.qn_caller_id();
  IF _user IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.store_members WHERE store_id = _store AND user_id = _user)
       OR EXISTS (SELECT 1 FROM public.stores WHERE id = _store AND owner_user_id = _user) THEN
      RETURN _store;
    END IF;
    RETURN NULL;
  END IF;
  -- Không có người gọi: chỉ chấp nhận store_id nằm trong JWT đã ký
  IF _claims IS NOT NULL AND _claims->>'role' = 'authenticated' AND (_claims->>'store_id') = _raw THEN RETURN _store; END IF;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END $function$;

-- Danh sách quán (số tổng hợp, KHÔNG doanh thu). p_filter: all | active | sleeping | never | new7 | test
CREATE OR REPLACE FUNCTION public.admin_store_list_v1(
  p_filter text DEFAULT 'all', p_search text DEFAULT NULL, p_include_test boolean DEFAULT false,
  p_limit int DEFAULT 50, p_offset int DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_lim int := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
  v_off int := GREATEST(COALESCE(p_offset, 0), 0);
  v_q text := NULLIF(btrim(COALESCE(p_search, '')), '');
  r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF COALESCE(p_filter, 'all') NOT IN ('all', 'active', 'sleeping', 'never', 'new7', 'test') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_FILTER');
  END IF;
  WITH rows AS (
    SELECT st.id, st.name, st.store_code, st.plan, st.status, st.trial_ends_at, st.last_active_at, st.created_at,
           (SELECT display_name FROM public.user_accounts u WHERE u.id = st.owner_user_id) AS owner_name,
           EXISTS (SELECT 1 FROM public.admin_test_stores t WHERE t.store_id = st.id) AS is_test,
           (SELECT count(*) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed'
               AND o.created_at > now() - interval '7 days') AS orders_7d,
           (SELECT count(*) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed'
               AND o.created_at > now() - interval '30 days') AS orders_30d,
           (SELECT max(o.created_at) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed') AS last_order_at,
           (SELECT count(*) FROM public.devices d WHERE d.store_id = st.id) AS devices,
           (SELECT max(d.last_seen) FROM public.devices d WHERE d.store_id = st.id) AS device_last_seen,
           -- chủ: thành viên đánh dấu chủ HOẶC chủ ghi trên quán (5 quán thiếu dòng is_owner — QC 26/10)
           (SELECT count(DISTINCT x.u) FROM (
               SELECT m.user_id AS u FROM public.store_members m WHERE m.store_id = st.id AND m.is_owner
               UNION SELECT st.owner_user_id WHERE st.owner_user_id IS NOT NULL) x) AS staff_owner,
           (SELECT count(*) FROM public.store_members m WHERE m.store_id = st.id AND NOT COALESCE(m.is_owner, false)
               AND m.user_id IS DISTINCT FROM st.owner_user_id
               AND lower(COALESCE(m.role, '')) IN ('manager', 'quản lý', 'quan ly')) AS staff_manager,
           (SELECT count(*) FROM public.store_members m WHERE m.store_id = st.id AND NOT COALESCE(m.is_owner, false)
               AND m.user_id IS DISTINCT FROM st.owner_user_id
               AND lower(COALESCE(m.role, '')) NOT IN ('manager', 'quản lý', 'quan ly', 'owner', 'unassigned')) AS staff_other,
           (SELECT count(*) FROM public.products p WHERE p.store_id = st.id AND p.product_type = 'finished'
               AND NOT COALESCE(p.is_deleted, false) AND COALESCE(p.is_active, true)
               AND NOT COALESCE(p.is_raw_material, false)) AS menu_items
      FROM public.stores st
     WHERE (v_q IS NULL OR st.name ILIKE '%' || v_q || '%' OR st.store_code ILIKE '%' || v_q || '%')
  ), f AS (
    SELECT * FROM rows
     WHERE CASE COALESCE(p_filter, 'all')
             WHEN 'test' THEN is_test
             ELSE (p_include_test OR NOT is_test) AND CASE COALESCE(p_filter, 'all')
               WHEN 'active' THEN orders_7d > 0
               WHEN 'sleeping' THEN last_order_at IS NOT NULL AND orders_30d = 0
               WHEN 'never' THEN last_order_at IS NULL
               WHEN 'new7' THEN created_at > now() - interval '7 days'
               ELSE true END
           END
  )
  SELECT jsonb_build_object('ok', true, 'total', (SELECT count(*) FROM f),
    'rows', COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.orders_7d DESC, x.created_at DESC)
                        FROM (SELECT * FROM f ORDER BY orders_7d DESC, created_at DESC LIMIT v_lim OFFSET v_off) x), '[]'::jsonb))
    INTO r;
  RETURN r;
END
$fn$;

-- 2 chính sách đọc trả về qn_is_member, gỡ qn_is_member_any
ALTER POLICY stores_select_v5 ON public.stores USING (public.qn_is_member(id));
ALTER POLICY sm_select_v5 ON public.store_members USING ((user_id = public.qn_caller_id()) OR public.qn_is_member(store_id));
DROP FUNCTION IF EXISTS public.qn_is_member_any(uuid);

-- 2 cổng kiểm thành viên: trả nguyên bản trước đợt 1
CREATE OR REPLACE FUNCTION public.qn_is_member(p_store uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_store IS NOT NULL AND public.qn_caller_id() IS NOT NULL AND (
    EXISTS (SELECT 1 FROM public.store_members m WHERE m.store_id = p_store AND m.user_id = public.qn_caller_id())
    OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = p_store AND s.owner_user_id = public.qn_caller_id()));
$function$;

CREATE OR REPLACE FUNCTION public.verify_staff_qr_membership_v4(p_store_id uuid, p_require_checkout boolean DEFAULT false, p_require_manage boolean DEFAULT false)
 RETURNS TABLE(member_user_id uuid, member_role text, store_member_id uuid, is_owner_member boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp'
AS $function$
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
$function$;

DROP FUNCTION IF EXISTS public.admin_store_detail_v1(uuid);
DROP FUNCTION IF EXISTS public.admin_plan_overview_v1(boolean);
DROP FUNCTION IF EXISTS public.admin_plan_list_v1(text, text, boolean, int, int);
DROP FUNCTION IF EXISTS public.admin_store_extend_trial_v1(uuid, int, text);
DROP FUNCTION IF EXISTS public.admin_store_set_plan_v1(uuid, text, timestamptz, bigint, text);
DROP FUNCTION IF EXISTS public.admin_store_set_locked_v1(uuid, boolean, text);
DROP FUNCTION IF EXISTS public.admin_store_note_add_v1(uuid, text, date);
DROP FUNCTION IF EXISTS public.admin_store_note_done_v1(bigint, boolean);
DROP FUNCTION IF EXISTS public.admin_platform_setting_set_v1(text, text);
DROP FUNCTION IF EXISTS public.store_plan_status_v1(uuid);
DROP FUNCTION IF EXISTS public.store_self_extend_trial_v1(uuid);
DROP FUNCTION IF EXISTS public.qn_store_can_self_extend(public.stores);
DROP FUNCTION IF EXISTS public.qn_store_plan_notice(text, text, timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.qn_store_plan_snapshot(public.stores);

COMMIT;
NOTIFY pgrst, 'reload schema';
