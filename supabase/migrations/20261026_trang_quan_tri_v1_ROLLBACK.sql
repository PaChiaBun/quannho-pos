-- Hoàn tác TRANG QUẢN TRỊ v1 — XOÁ lịch sử Boom nguyên văn, phiếu chấm, nhật ký dạy, danh sách quán thử, quản trị viên.
BEGIN;
DROP FUNCTION IF EXISTS public.admin_boom_chunk_v1(text);
DROP FUNCTION IF EXISTS public.admin_boom_knowledge_v1();
DROP FUNCTION IF EXISTS public.admin_boom_stats_v1(int);
DROP FUNCTION IF EXISTS public.admin_boom_review_v1(uuid, text, text, boolean);
DROP FUNCTION IF EXISTS public.admin_boom_turn_v1(uuid);
DROP FUNCTION IF EXISTS public.admin_boom_turns_v1(uuid, timestamptz, timestamptz, text, text, int, int);
DROP FUNCTION IF EXISTS public.admin_set_test_store_v1(uuid, boolean);
DROP FUNCTION IF EXISTS public.admin_store_list_v1(text, text, boolean, int, int);
DROP FUNCTION IF EXISTS public.admin_store_overview_v1(boolean);
DROP FUNCTION IF EXISTS public.qn_vn_day(timestamptz);
DROP FUNCTION IF EXISTS public.admin_whoami_v1();
DROP FUNCTION IF EXISTS public.boom_qa_full_write_v1(uuid, uuid, uuid, text, text, text, text, text[]);
DROP FUNCTION IF EXISTS public.admin_is_platform_admin_v1(uuid);
DROP FUNCTION IF EXISTS public.qn_admin_caller();
DROP TABLE IF EXISTS public.boom_admin_reviews;
DROP TABLE IF EXISTS public.boom_qa_full;
DROP TABLE IF EXISTS public.boom_changelog;
DROP TABLE IF EXISTS public.admin_test_stores;
DROP TABLE IF EXISTS public.platform_admins;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qn_admin') THEN
    REVOKE USAGE ON SCHEMA public FROM qn_admin;
    REVOKE qn_admin FROM authenticator;
    DROP ROLE qn_admin;
  END IF;
END $$;
COMMIT;
NOTIFY pgrst, 'reload schema';
