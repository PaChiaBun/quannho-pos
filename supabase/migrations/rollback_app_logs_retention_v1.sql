-- Rollback của 20261018_app_logs_retention_v1.sql (không khôi phục log đã bị xóa bởi lịch purge).
BEGIN;
DROP FUNCTION IF EXISTS public.qn_app_logs_purge(integer, integer, integer);
DROP INDEX IF EXISTS public.idx_app_logs_store_tag_created;
COMMIT;
