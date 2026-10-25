-- Hoàn tác 20261022_cung_co_p0_v3.sql: trả lại quyền gọi hàm như trước, gỡ 3 trigger. Không đụng dữ liệu.
DROP TRIGGER IF EXISTS guard_finance_manual_insert_v1 ON public.finance_records;
DROP FUNCTION IF EXISTS public.guard_finance_manual_insert_v1();
DROP FUNCTION IF EXISTS public.qn_caller_has_module(uuid, text);
DROP FUNCTION IF EXISTS public.qn_canonical_role(text);
DROP TRIGGER IF EXISTS guard_ban_session_closed_row_v3 ON public.ban_sessions;
DROP FUNCTION IF EXISTS public.guard_ban_session_closed_row_v3();
DROP TRIGGER IF EXISTS guard_app_settings_perms_v1 ON public.app_settings;
DROP FUNCTION IF EXISTS public.guard_app_settings_perms_v1();
DROP FUNCTION IF EXISTS public.app_setting_is_permission_key(text);
GRANT EXECUTE ON FUNCTION public.publish_app_version_v1(text,text,integer,text,text,boolean) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_staff_by_phone(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_store_member(uuid,uuid,uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';
