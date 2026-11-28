-- ═════════════════════════════════════════════════════════════════════════════
-- FIX 04 (07/10/2026) — Khoá quyền: tài khoản, quán, thành viên, menu, nhân viên
-- Mục tiêu: chặn đọc/sửa mật khẩu, chặn chiếm quán, chặn quán khác sửa menu.
-- Giữ nguyên các luồng app đang chạy (client gửi x-store-id + x-user-id hoặc POS JWT).
-- Rollback: 20261007_fix04_ROLLBACK.sql
-- ═════════════════════════════════════════════════════════════════════════════

-- ── 0. Hàm định danh người gọi ──────────────────────────────────────────────
-- Ưu tiên JWT đã ký (role=authenticated → sub). Chỉ khi không có JWT người dùng
-- mới dùng header x-user-id (client cũ). Header KHÔNG ghi đè được JWT.
CREATE OR REPLACE FUNCTION public.qn_caller_id()
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE c jsonb; v text;
BEGIN
  BEGIN c := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb; EXCEPTION WHEN OTHERS THEN c := NULL; END;
  IF c IS NOT NULL AND c->>'role' = 'authenticated' THEN
    v := c->>'sub';
  ELSE
    BEGIN v := NULLIF(current_setting('request.headers', true), '')::json->>'x-user-id'; EXCEPTION WHEN OTHERS THEN v := NULL; END;
  END IF;
  IF v ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN RETURN v::uuid; END IF;
  RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.qn_is_member(p_store uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT p_store IS NOT NULL AND public.qn_caller_id() IS NOT NULL AND (
    EXISTS (SELECT 1 FROM public.store_members m WHERE m.store_id = p_store AND m.user_id = public.qn_caller_id())
    OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = p_store AND s.owner_user_id = public.qn_caller_id()));
$$;

CREATE OR REPLACE FUNCTION public.qn_is_manager(p_store uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT p_store IS NOT NULL AND public.qn_caller_id() IS NOT NULL AND (
    EXISTS (SELECT 1 FROM public.store_members m WHERE m.store_id = p_store AND m.user_id = public.qn_caller_id()
            AND (m.is_owner OR lower(m.role) IN ('owner','manager')))
    OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = p_store AND s.owner_user_id = public.qn_caller_id()));
$$;

CREATE OR REPLACE FUNCTION public.qn_shares_store_with(p_user uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT public.qn_caller_id() IS NOT NULL AND (p_user = public.qn_caller_id() OR EXISTS (
    SELECT 1 FROM public.store_members a JOIN public.store_members b ON a.store_id = b.store_id
    WHERE a.user_id = public.qn_caller_id() AND b.user_id = p_user));
$$;

REVOKE ALL ON FUNCTION public.qn_caller_id(), public.qn_is_member(uuid), public.qn_is_manager(uuid), public.qn_shares_store_with(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qn_caller_id(), public.qn_is_member(uuid), public.qn_is_manager(uuid), public.qn_shares_store_with(uuid) TO anon, authenticated, service_role;

-- ── 1. current_store_id(): người gọi lấy từ qn_caller_id() (JWT ưu tiên) ────
CREATE OR REPLACE FUNCTION public.current_store_id()
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $function$
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

-- ── 2. Bỏ các quyền PostgREST không bao giờ cần ─────────────────────────────
DO $$ DECLARE t text; BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.%I FROM anon, authenticated', t);
  END LOOP;
END $$;

-- ── 3. user_accounts: bật RLS, ẩn mật khẩu/PIN, cấm tạo/sửa mật khẩu trực tiếp ─
ALTER TABLE public.user_accounts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_accounts FROM anon, authenticated;
GRANT SELECT (id, phone, display_name, created_at) ON public.user_accounts TO anon, authenticated;
GRANT UPDATE (display_name) ON public.user_accounts TO anon, authenticated;
GRANT DELETE ON public.user_accounts TO authenticated;
DROP POLICY IF EXISTS ua_select_v5 ON public.user_accounts;
DROP POLICY IF EXISTS ua_update_self_v5 ON public.user_accounts;
DROP POLICY IF EXISTS ua_delete_self_v5 ON public.user_accounts;
CREATE POLICY ua_select_v5 ON public.user_accounts FOR SELECT TO anon, authenticated USING (public.qn_shares_store_with(id));
CREATE POLICY ua_update_self_v5 ON public.user_accounts FOR UPDATE TO anon, authenticated USING (id = public.qn_caller_id()) WITH CHECK (id = public.qn_caller_id());
CREATE POLICY ua_delete_self_v5 ON public.user_accounts FOR DELETE TO authenticated USING (id = auth.uid());
-- (policy cũ user_accounts_store_member_select_v4 nếu có vẫn giữ, chỉ đọc cột được cấp)

-- ── 4. stores ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS stores_all ON public.stores;
DROP POLICY IF EXISTS stores_isolation ON public.stores;
DROP POLICY IF EXISTS stores_select_v5 ON public.stores;
DROP POLICY IF EXISTS stores_insert_v5 ON public.stores;
DROP POLICY IF EXISTS stores_update_v5 ON public.stores;
DROP POLICY IF EXISTS stores_delete_v5 ON public.stores;
REVOKE INSERT, DELETE ON public.stores FROM anon;
CREATE POLICY stores_select_v5 ON public.stores FOR SELECT TO anon, authenticated USING (public.qn_is_member(id));
CREATE POLICY stores_insert_v5 ON public.stores FOR INSERT TO authenticated WITH CHECK (owner_user_id = auth.uid());
CREATE POLICY stores_update_v5 ON public.stores FOR UPDATE TO anon, authenticated USING (public.qn_is_member(id)) WITH CHECK (public.qn_is_member(id));
CREATE POLICY stores_delete_v5 ON public.stores FOR DELETE TO authenticated USING (owner_user_id = auth.uid());

-- ── 5. store_members ────────────────────────────────────────────────────────
ALTER TABLE public.store_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sm_select_v5 ON public.store_members;
DROP POLICY IF EXISTS sm_insert_v5 ON public.store_members;
DROP POLICY IF EXISTS sm_update_v5 ON public.store_members;
DROP POLICY IF EXISTS sm_delete_v5 ON public.store_members;
CREATE POLICY sm_select_v5 ON public.store_members FOR SELECT TO anon, authenticated USING (user_id = public.qn_caller_id() OR public.qn_is_member(store_id));
CREATE POLICY sm_insert_v5 ON public.store_members FOR INSERT TO anon, authenticated WITH CHECK (public.qn_is_manager(store_id));
CREATE POLICY sm_update_v5 ON public.store_members FOR UPDATE TO anon, authenticated USING (public.qn_is_manager(store_id)) WITH CHECK (public.qn_is_manager(store_id));
CREATE POLICY sm_delete_v5 ON public.store_members FOR DELETE TO anon, authenticated USING (public.qn_is_manager(store_id) OR user_id = public.qn_caller_id());

-- ── 6. products: bỏ policy mở toàn bộ (giữ products_isolation theo quán) ─────
DROP POLICY IF EXISTS anon_all ON public.products;

-- ── 7. staff_members: bỏ 4 policy mở toàn bộ (giữ staff_members_isolation) ──
DROP POLICY IF EXISTS staff_select ON public.staff_members;
DROP POLICY IF EXISTS staff_insert ON public.staff_members;
DROP POLICY IF EXISTS staff_update ON public.staff_members;
DROP POLICY IF EXISTS staff_delete ON public.staff_members;

-- ── 8. Hàm quản trị: không cho người chưa đăng nhập gọi (thống kê 11 ngày: anon = 0 lượt) ─
DO $$ DECLARE f text; BEGIN
  FOR f IN SELECT p.oid::regprocedure::text FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.proname IN (
             'admin_create_staff_member_v4','admin_revoke_staff_membership_v4','admin_set_staff_status_v4',
             'admin_update_staff_role_v4','batch_soft_delete_products_v1','adjust_product_stock',
             'repair_missing_staff_accounts','change_user_password_v4','create_store_with_owner_v4',
             'set_user_quick_pin_v4','revoke_store_member','join_store_by_code_v4')
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role', f);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
