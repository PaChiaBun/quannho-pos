-- Hoàn tác 20261121_gieo_module_khi_tao_quan.sql: gỡ trigger gieo, trả việc gieo về app như trước.
-- Các dòng cấu hình đã gieo được giữ lại (quán đang dùng).

DROP TRIGGER IF EXISTS qn_stores_seed_module_config ON public.stores;
DROP FUNCTION IF EXISTS public.qn_seed_module_config();
