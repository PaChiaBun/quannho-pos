-- Gỡ lịch dọn log v2 (không khôi phục được log đã bị xoá bởi lịch dọn). Nhớ tắt timer trên VPS trước.
BEGIN;
DROP FUNCTION IF EXISTS public.qn_app_logs_purge(integer, integer, integer);
DROP INDEX IF EXISTS public.idx_app_logs_created_at;
COMMIT;
