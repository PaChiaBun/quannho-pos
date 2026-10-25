-- Hoàn tác TRANG QUẢN TRỊ v2: trở về quản trị bằng tài khoản quán (khôi phục bảng platform_admins cũ kèm GIANG).
BEGIN;
-- Khôi phục bảng cũ (kèm GIANG) nếu còn bản đổi tên; không có thì tạo bảng trống
DO $$
BEGIN
  IF to_regclass('public.platform_admins_v1_cu') IS NOT NULL AND to_regclass('public.platform_admins') IS NULL THEN
    ALTER TABLE public.platform_admins_v1_cu RENAME TO platform_admins;
  END IF;
END $$;
CREATE TABLE IF NOT EXISTS public.platform_admins (
  user_id    uuid PRIMARY KEY REFERENCES public.user_accounts(id) ON DELETE CASCADE,
  note       text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.platform_admins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.platform_admins FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.platform_admins TO service_role;
CREATE OR REPLACE FUNCTION public.qn_admin_caller()
RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE c jsonb; v text; u uuid;
BEGIN
  BEGIN c := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb; EXCEPTION WHEN OTHERS THEN RETURN NULL; END;
  IF c IS NULL OR c->>'role' IS DISTINCT FROM 'qn_admin' OR c->>'token_use' IS DISTINCT FROM 'admin' THEN RETURN NULL; END IF;
  IF (c->>'exp') IS NULL OR (c->>'exp') !~ '^[0-9]+$' OR (c->>'exp')::bigint <= extract(epoch FROM now())::bigint
     OR (c->>'iat') IS NULL OR (c->>'iat') !~ '^[0-9]+$' OR (c->>'exp')::bigint - (c->>'iat')::bigint > 14400 THEN
    RETURN NULL;
  END IF;
  v := c->>'sub';
  IF v IS NULL OR v !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN RETURN NULL; END IF;
  SELECT p.user_id INTO u FROM public.platform_admins p WHERE p.user_id = v::uuid;
  RETURN u;
END
$fn$;
REVOKE ALL ON FUNCTION public.qn_admin_caller() FROM PUBLIC, anon, authenticated;
CREATE OR REPLACE FUNCTION public.admin_is_platform_admin_v1(p_user uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$ SELECT EXISTS (SELECT 1 FROM public.platform_admins WHERE user_id = p_user) $fn$;
REVOKE ALL ON FUNCTION public.admin_is_platform_admin_v1(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_is_platform_admin_v1(uuid) TO service_role;
CREATE OR REPLACE FUNCTION public.admin_whoami_v1()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  RETURN jsonb_build_object('ok', true, 'user_id', a,
    'name', (SELECT display_name FROM public.user_accounts WHERE id = a));
END
$fn$;
DROP FUNCTION IF EXISTS public.admin_account_set_password_v1(text, text, text);
DROP FUNCTION IF EXISTS public.admin_account_login_v1(text, text);
DROP TABLE IF EXISTS public.platform_admin_accounts;
COMMIT;
NOTIFY pgrst, 'reload schema';
