-- ROLLBACK FIX 04 — trả về đúng trạng thái production lúc 07/10/2026 (từ pg_dump đã lưu)
-- 1. current_store_id() bản cũ
CREATE OR REPLACE FUNCTION public.current_store_id()
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
  -- Tầng 1: Header REST x-store-id
  BEGIN
    _raw_store_id := NULLIF(current_setting('request.headers', true)::json->>'x-store-id', '');
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

  -- Kiểm tra định dạng UUID store_id hợp lệ
  IF _raw_store_id IS NULL OR NOT (_raw_store_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') THEN
    RETURN NULL;
  END IF;
  _store_id := _raw_store_id::uuid;

  -- 2. Trích xuất raw user_id
  -- Tầng 1: Header REST x-user-id
  BEGIN
    _raw_user_id := NULLIF(current_setting('request.headers', true)::json->>'x-user-id', '');
  EXCEPTION WHEN OTHERS THEN
    _raw_user_id := NULL;
  END;

  -- Tầng 2: auth.uid()
  IF _raw_user_id IS NULL OR _raw_user_id = '' THEN
    BEGIN
      _raw_user_id := NULLIF(auth.uid()::text, '');
    EXCEPTION WHEN OTHERS THEN
      _raw_user_id := NULL;
    END;
  END IF;

  -- Tầng 3: JWT claims sub
  IF (_raw_user_id IS NULL OR _raw_user_id = '') AND _claims IS NOT NULL THEN
    _raw_user_id := NULLIF(_claims->>'sub', '');
  END IF;

  -- Tầng 4: PostgREST single-claim sub
  IF _raw_user_id IS NULL OR _raw_user_id = '' THEN
    BEGIN
      _raw_user_id := NULLIF(current_setting('request.jwt.claim.sub', true), '');
    EXCEPTION WHEN OTHERS THEN
      _raw_user_id := NULL;
    END;
  END IF;

  -- 3. Active Membership Guard
  IF _raw_user_id IS NOT NULL AND (_raw_user_id ~* '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') THEN
    _user_id := _raw_user_id::uuid;
    IF EXISTS (
      SELECT 1 FROM public.store_members
      WHERE store_id = _store_id AND user_id = _user_id
    ) OR EXISTS (
      SELECT 1 FROM public.stores
      WHERE id = _store_id AND owner_user_id = _user_id
    ) THEN
      RETURN _store_id;
    ELSE
      RETURN NULL;
    END IF;
  END IF;

  -- Fallback: Nếu không tìm thấy user_id nhưng store_id nằm trong server-signed JWT claims
  IF _claims IS NOT NULL AND (_claims->>'store_id') = _raw_store_id THEN
    RETURN _store_id;
  END IF;

  RETURN NULL;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$function$
;


-- 2. user_accounts
DROP POLICY IF EXISTS ua_select_v5 ON public.user_accounts;
DROP POLICY IF EXISTS ua_update_self_v5 ON public.user_accounts;
DROP POLICY IF EXISTS ua_delete_self_v5 ON public.user_accounts;
ALTER TABLE public.user_accounts DISABLE ROW LEVEL SECURITY;
GRANT ALL ON TABLE public.user_accounts TO anon, authenticated;

-- 3. stores
DROP POLICY IF EXISTS stores_select_v5 ON public.stores;
DROP POLICY IF EXISTS stores_insert_v5 ON public.stores;
DROP POLICY IF EXISTS stores_update_v5 ON public.stores;
DROP POLICY IF EXISTS stores_delete_v5 ON public.stores;
CREATE POLICY stores_all ON public.stores TO authenticated, anon USING (true) WITH CHECK (true);
CREATE POLICY stores_isolation ON public.stores USING (((id)::text = (public.current_store_id())::text)) WITH CHECK (((id)::text = (public.current_store_id())::text));
GRANT ALL ON TABLE public.stores TO anon, authenticated;

-- 4. store_members
DROP POLICY IF EXISTS sm_select_v5 ON public.store_members;
DROP POLICY IF EXISTS sm_insert_v5 ON public.store_members;
DROP POLICY IF EXISTS sm_update_v5 ON public.store_members;
DROP POLICY IF EXISTS sm_delete_v5 ON public.store_members;
ALTER TABLE public.store_members DISABLE ROW LEVEL SECURITY;

-- 5. products
CREATE POLICY anon_all ON public.products USING (true) WITH CHECK (true);

-- 6. staff_members
CREATE POLICY staff_select ON public.staff_members FOR SELECT USING (true);
CREATE POLICY staff_insert ON public.staff_members FOR INSERT WITH CHECK (true);
CREATE POLICY staff_update ON public.staff_members FOR UPDATE USING (true);
CREATE POLICY staff_delete ON public.staff_members FOR DELETE USING (true);

-- 7. Quyền bảng & hàm như cũ
DO $$ DECLARE t text; BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' LOOP
    EXECUTE format('GRANT TRUNCATE, TRIGGER, REFERENCES ON public.%I TO anon, authenticated', t);
  END LOOP;
END $$;
DO $$ DECLARE f text; BEGIN
  FOR f IN SELECT p.oid::regprocedure::text FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
           WHERE n.nspname='public' AND p.proname IN ('admin_create_staff_member_v4','admin_revoke_staff_membership_v4','admin_set_staff_status_v4',
             'admin_update_staff_role_v4','batch_soft_delete_products_v1','adjust_product_stock','repair_missing_staff_accounts',
             'change_user_password_v4','create_store_with_owner_v4','set_user_quick_pin_v4','revoke_store_member','join_store_by_code_v4')
  LOOP EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO anon', f); END LOOP;
END $$;

-- 8. Hàm phụ
DROP FUNCTION IF EXISTS public.qn_shares_store_with(uuid);
DROP FUNCTION IF EXISTS public.qn_is_manager(uuid);
DROP FUNCTION IF EXISTS public.qn_is_member(uuid);
DROP FUNCTION IF EXISTS public.qn_caller_id();
NOTIFY pgrst, 'reload schema';
