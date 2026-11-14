-- ============================================================================
-- TRANG QUẢN TRỊ v2 — TÀI KHOẢN QUẢN TRỊ RIÊNG (Chủ Quán 25/10/2026: "tạo riêng ra đi, không dùng tk Giang")
--   • platform_admin_accounts — tài khoản quản trị TÁCH HẲN tài khoản quán: đăng nhập bằng tên (vd 'pachiabun'),
--     mật khẩu băm bcrypt; Chủ Quán tự đặt mật khẩu bằng db-fix/tao_tk_quan_tri.sh (Claude không thấy mật khẩu).
--   • Vé quản trị (vai trò qn_admin) giờ mang id tài khoản quản trị; qn_admin_caller / admin_is_platform_admin_v1 kiểm
--     bảng mới. Bảng platform_admins cũ (GIANG) bị gỡ → tài khoản quán không còn vào được trang quản trị.
-- Cần v1 (20261026_trang_quan_tri_v1.sql) đã áp.
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS public.platform_admin_accounts (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username      text NOT NULL UNIQUE CHECK (username ~ '^[a-z0-9_.-]{3,40}$'),
  password_hash text,                      -- NULL = chưa đặt mật khẩu → chưa đăng nhập được
  display_name  text NOT NULL,
  disabled      boolean NOT NULL DEFAULT false,
  last_login_at timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.platform_admin_accounts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.platform_admin_accounts FROM PUBLIC, anon, authenticated, qn_admin;
GRANT ALL ON public.platform_admin_accounts TO service_role;

-- Người gọi là quản trị: vé qn_admin (token_use admin, ≤ 4 giờ, còn hạn) + id thuộc tài khoản quản trị chưa khoá
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
  -- Vé cấp TRƯỚC lần đổi mật khẩu gần nhất → hết hiệu lực (đổi mật khẩu = đá phiên cũ)
  SELECT a.id INTO u FROM public.platform_admin_accounts a
   WHERE a.id = v::uuid AND NOT a.disabled AND a.password_hash IS NOT NULL
     AND (c->>'iat')::bigint >= floor(extract(epoch FROM a.updated_at))::bigint;
  RETURN u;
END
$fn$;
REVOKE ALL ON FUNCTION public.qn_admin_caller() FROM PUBLIC, anon, authenticated;

-- Hàm boom-chat (service_role) hỏi id trong vé có phải quản trị còn hiệu lực không
CREATE OR REPLACE FUNCTION public.admin_is_platform_admin_v1(p_user uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$ SELECT EXISTS (SELECT 1 FROM public.platform_admin_accounts
                        WHERE id = p_user AND NOT disabled AND password_hash IS NOT NULL) $fn$;
REVOKE ALL ON FUNCTION public.admin_is_platform_admin_v1(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_is_platform_admin_v1(uuid) TO service_role;

-- Đăng nhập (cổng /api/auth/admin-jwt gọi bằng service_role): đúng tên + mật khẩu → id; sai → cùng một kết quả.
-- So mật khẩu cả khi không có tài khoản (băm giả) → thời gian trả lời như nhau, không dò được tên đăng nhập.
CREATE OR REPLACE FUNCTION public.admin_account_login_v1(p_username text, p_password text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $fn$
DECLARE a public.platform_admin_accounts; ok boolean;
BEGIN
  SELECT * INTO a FROM public.platform_admin_accounts WHERE username = lower(btrim(COALESCE(p_username, '')));
  IF a.password_hash IS NULL THEN
    PERFORM crypt(COALESCE(p_password, ''), gen_salt('bf', 12));  -- tốn thời gian như tài khoản thật
    ok := false;
  ELSE
    ok := crypt(COALESCE(p_password, ''), a.password_hash) = a.password_hash;
  END IF;
  IF a.id IS NULL OR a.disabled OR a.password_hash IS NULL OR NOT ok THEN
    RETURN jsonb_build_object('ok', false);
  END IF;
  UPDATE public.platform_admin_accounts SET last_login_at = now() WHERE id = a.id;
  RETURN jsonb_build_object('ok', true, 'id', a.id, 'name', a.display_name);
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_account_login_v1(text, text) FROM PUBLIC, anon, authenticated, qn_admin;
GRANT EXECUTE ON FUNCTION public.admin_account_login_v1(text, text) TO service_role;

-- Đặt / đổi mật khẩu (CHỈ chạy trong database bằng db-fix/tao_tk_quan_tri.sh; không cấp cho API). Mật khẩu ≥ 10 ký tự.
CREATE OR REPLACE FUNCTION public.admin_account_set_password_v1(p_username text, p_password text, p_display_name text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $fn$
DECLARE u text := lower(btrim(COALESCE(p_username, '')));
BEGIN
  IF u !~ '^[a-z0-9_.-]{3,40}$' THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_USERNAME'); END IF;
  IF length(COALESCE(p_password, '')) < 10 THEN RETURN jsonb_build_object('ok', false, 'error', 'PASSWORD_TOO_SHORT'); END IF;
  INSERT INTO public.platform_admin_accounts (username, password_hash, display_name)
  VALUES (u, crypt(p_password, gen_salt('bf', 12)), COALESCE(NULLIF(btrim(p_display_name), ''), u))
  ON CONFLICT (username) DO UPDATE SET password_hash = EXCLUDED.password_hash,
    -- updated_at đổi → vé cũ hết hiệu lực (qn_admin_caller)
    display_name = EXCLUDED.display_name, disabled = false, updated_at = now();
  RETURN jsonb_build_object('ok', true, 'username', u);
END
$fn$;
REVOKE ALL ON FUNCTION public.admin_account_set_password_v1(text, text, text) FROM PUBLIC, anon, authenticated, qn_admin, service_role;

-- Tên hiển thị trên trang
CREATE OR REPLACE FUNCTION public.admin_whoami_v1()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  RETURN jsonb_build_object('ok', true, 'user_id', a,
    'name', (SELECT display_name FROM public.platform_admin_accounts WHERE id = a));
END
$fn$;

-- Gỡ quản trị bằng tài khoản quán (GIANG): bảng cũ đổi tên (giữ để hoàn tác khôi phục được), không hàm nào dùng nữa
DO $$
BEGIN
  IF to_regclass('public.platform_admins') IS NOT NULL AND to_regclass('public.platform_admins_v1_cu') IS NULL THEN
    ALTER TABLE public.platform_admins RENAME TO platform_admins_v1_cu;
  END IF;
END $$;

-- Kiểm tra sau áp
DO $$
BEGIN
  IF has_table_privilege('authenticated', 'public.platform_admin_accounts', 'select')
     OR has_table_privilege('qn_admin', 'public.platform_admin_accounts', 'select')
     OR has_function_privilege('authenticated', 'public.admin_account_login_v1(text,text)', 'execute')
     OR has_function_privilege('anon', 'public.admin_account_login_v1(text,text)', 'execute')
     OR has_function_privilege('service_role', 'public.admin_account_set_password_v1(text,text,text)', 'execute')
     OR has_function_privilege('qn_admin', 'public.admin_account_set_password_v1(text,text,text)', 'execute') THEN
    RAISE EXCEPTION 'TRANG QUAN TRI v2: quyền không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
