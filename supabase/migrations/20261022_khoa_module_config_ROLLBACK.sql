-- Hoàn tác: gỡ khoá module_config_v2 (giữ lại bảng lịch sử để đối chiếu).
DROP TRIGGER IF EXISTS qn_module_config_guard_iu ON public.app_settings;
DROP TRIGGER IF EXISTS qn_module_config_guard_d  ON public.app_settings;
DROP TRIGGER IF EXISTS qn_module_config_log_iu   ON public.app_settings;
DROP TRIGGER IF EXISTS qn_module_config_log_d    ON public.app_settings;
DROP FUNCTION IF EXISTS public.qn_guard_module_config();
DROP FUNCTION IF EXISTS public.qn_log_module_config();
