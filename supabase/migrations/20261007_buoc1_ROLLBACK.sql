-- ROLLBACK Bước 1 — refresh token
SET lock_timeout = '5s';
DROP TRIGGER IF EXISTS qn_revoke_refresh_on_member_delete ON public.store_members;
DROP TRIGGER IF EXISTS qn_revoke_refresh_on_password_change ON public.user_accounts;
DROP FUNCTION IF EXISTS public.qn_trg_revoke_refresh_on_member_delete();
DROP FUNCTION IF EXISTS public.qn_trg_revoke_refresh_on_password_change();
DROP FUNCTION IF EXISTS public.qn_refresh_revoke_v1(text, text);
DROP FUNCTION IF EXISTS public.qn_refresh_rotate_v1(text, text, integer, text);
DROP FUNCTION IF EXISTS public.qn_refresh_issue_v1(uuid, uuid, text, integer, uuid, text, text);
DROP FUNCTION IF EXISTS public.qn_member_role_v1(uuid, uuid);
DROP TABLE IF EXISTS public.pos_refresh_tokens;
