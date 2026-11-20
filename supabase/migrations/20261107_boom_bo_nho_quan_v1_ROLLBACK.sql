-- HOÀN TÁC 20261107_boom_bo_nho_quan_v1.sql — xoá hẳn bộ nhớ từng quán (mọi ghi nhớ, hồ sơ, lời khuyên đã lưu sẽ mất).
BEGIN;
DROP TRIGGER IF EXISTS trg_boom_bo_nho_doi_chu ON public.stores;
DROP FUNCTION IF EXISTS public._boom_bo_nho_doi_chu();
DROP FUNCTION IF EXISTS public.boom_bo_nho_xem_v1(uuid);
DROP FUNCTION IF EXISTS public.boom_bo_nho_sua_v1(uuid, text);
DROP FUNCTION IF EXISTS public.boom_bo_nho_xoa_v1(uuid);
DROP FUNCTION IF EXISTS public.boom_bo_nho_tat_v1(uuid, boolean);
DROP FUNCTION IF EXISTS public._boom_la_chu(uuid);
DROP TABLE IF EXISTS public.boom_quan_loi_khuyen;
DROP TABLE IF EXISTS public.boom_quan_ghi_nho;
DROP FUNCTION IF EXISTS public._boom_ghi_nho_gioi_han();
DROP TABLE IF EXISTS public.boom_quan_ho_so;
COMMIT;
