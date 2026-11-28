-- Hoàn tác KHÓA GHI PHÂN QUYỀN v1: gỡ 2 trigger và 2 hàm. Không đụng dữ liệu.
DROP TRIGGER IF EXISTS qn_guard_store_roles_write ON public.store_roles;
DROP TRIGGER IF EXISTS qn_guard_staff_members_write ON public.staff_members;
DROP FUNCTION IF EXISTS public.qn_guard_store_roles_write();
DROP FUNCTION IF EXISTS public.qn_guard_staff_members_write();
