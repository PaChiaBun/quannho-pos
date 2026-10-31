-- ============================================================================
-- HOÀN TÁC 20261026_do_header_auth_v1.sql — CHẠY _TAT_HOOK.sql TRƯỚC (nếu hook đang bật mà xóa hàm thì MỌI yêu cầu API lỗi).
-- Xóa hàm hook, thủ tục ghi, bảng số đo (mất số đo đã gom) và extension dblink.
-- ============================================================================
BEGIN;
DO $g$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole
             WHERE r.rolname = 'authenticator' AND array_to_string(s.setconfig, ',') LIKE '%pgrst.db_pre_request%') THEN
    RAISE EXCEPTION 'DO_HEADER ROLLBACK: hook còn bật trên authenticator — chạy 20261026_do_header_auth_v1_TAT_HOOK.sql trước';
  END IF;
END $g$;
DROP FUNCTION IF EXISTS public.qn_pre_request();
DROP PROCEDURE IF EXISTS public.qn_header_auth_ghi(timestamptz, uuid, boolean, text, text, text, text, boolean);
DROP TABLE IF EXISTS public.qn_header_auth_seen;
DROP EXTENSION IF EXISTS dblink;
DO $chk$ BEGIN RAISE NOTICE 'DO_HEADER v1 ROLLBACK: xong'; END $chk$;
COMMIT;
