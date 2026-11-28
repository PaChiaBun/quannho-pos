-- Hoàn tác 20261022_cung_co_p0_v2.sql về trạng thái sau P0-1…P0-5. Không đụng dữ liệu.
DROP TRIGGER IF EXISTS guard_ban_session_delete_v2 ON public.ban_sessions;
DROP FUNCTION IF EXISTS public.guard_ban_session_delete_v2();

CREATE OR REPLACE FUNCTION public.payroll_actor_v1(p_store_id uuid,
  OUT uid uuid, OUT is_owner boolean, OUT is_manager boolean)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE v_m record;
BEGIN
  is_owner := false; is_manager := false;
  BEGIN
    SELECT * INTO v_m FROM public.verify_staff_qr_membership_v4(p_store_id, false, false);
  EXCEPTION WHEN OTHERS THEN
    RETURN;
  END;
  uid := v_m.member_user_id;
  is_owner := COALESCE(v_m.is_owner_member, false) OR lower(COALESCE(v_m.member_role, '')) = 'owner';
  is_manager := is_owner OR lower(COALESCE(v_m.member_role, '')) IN ('manager', 'admin');
END
$fn$;

DROP POLICY IF EXISTS finance_record_deletions_read ON public.finance_record_deletions;
REVOKE SELECT ON public.finance_record_deletions FROM anon;
CREATE POLICY finance_record_deletions_read ON public.finance_record_deletions
  FOR SELECT TO authenticated
  USING (store_id = (SELECT public.current_store_id()));

CREATE OR REPLACE FUNCTION public.app_log_is_protected_tag(p_tag text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_catalog, pg_temp
AS $fn$
  SELECT lower(COALESCE(p_tag, '')) IN ('action','checkout','order','auth','ban_items','finance','payroll','staff','staff_shift_audit','payroll_staff_confirm');
$fn$;
