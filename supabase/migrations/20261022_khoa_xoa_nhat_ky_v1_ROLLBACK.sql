-- Hoàn tác 20261022_khoa_xoa_nhat_ky_v1.sql. Không đụng dữ liệu log.
DROP TRIGGER IF EXISTS guard_app_logs_v1 ON public.app_logs;
DROP FUNCTION IF EXISTS public.guard_app_logs_v1();
DROP FUNCTION IF EXISTS public.app_log_is_protected_tag(text);
