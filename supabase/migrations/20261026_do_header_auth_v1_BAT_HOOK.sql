-- ============================================================================
-- BẬT hook đo đạc Pha 1 (CHỈ chạy trên production qua db-fix/do_header_auth_ap_dung.sh, KHÔNG chạy trên bản sao:
-- ALTER ROLE là lệnh cấp cụm Postgres). PostgREST đọc cấu hình trong DB và nạp lại khi nhận NOTIFY.
-- Tắt: 20261026_do_header_auth_v1_TAT_HOOK.sql
-- ============================================================================
DO $pf$
BEGIN
  IF current_database() <> 'postgres' THEN RAISE EXCEPTION 'BAT_HOOK: chỉ chạy trên database postgres (production)'; END IF;
  IF to_regprocedure('public.qn_pre_request()') IS NULL THEN RAISE EXCEPTION 'BAT_HOOK: chưa áp 20261026_do_header_auth_v1.sql'; END IF;
END $pf$;
ALTER ROLE authenticator IN DATABASE postgres SET pgrst.db_pre_request = 'public.qn_pre_request';
NOTIFY pgrst, 'reload config';
