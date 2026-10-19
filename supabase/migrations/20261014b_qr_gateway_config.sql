-- QR chống phá — cấu hình cho cổng cấp vé (services/pos_jwt_auth_service.py: /api/auth/qr-ticket).
-- Hàm chỉ service_role gọi được; trả khoá ký vé + khoá bí mật Turnstile (không bao giờ ra anon/authenticated).
-- Hoàn tác: DROP FUNCTION public.qr_gateway_config_v1(); DELETE FROM public.qr_security_config WHERE key='turnstile_secret';
BEGIN;
INSERT INTO public.qr_security_config (key, value) VALUES ('turnstile_secret', '') ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.qr_gateway_config_v1()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
  SELECT jsonb_build_object(
    'ticket_secret',    COALESCE((SELECT value FROM public.qr_security_config WHERE key = 'ticket_secret'), ''),
    'turnstile_secret', COALESCE((SELECT value FROM public.qr_security_config WHERE key = 'turnstile_secret'), ''),
    'require_ticket',   COALESCE((SELECT value FROM public.qr_security_config WHERE key = 'require_ticket'), 'false'))
$fn$;
REVOKE ALL ON FUNCTION public.qr_gateway_config_v1() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qr_gateway_config_v1() TO service_role;
COMMIT;
NOTIFY pgrst, 'reload schema';
