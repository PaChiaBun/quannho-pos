-- Hoàn tác 20261022_khoa_duyet_tra_luong_v1.sql. Không đụng dữ liệu lương.
DROP TRIGGER IF EXISTS guard_payroll_records_v1 ON public.payroll_records;
DROP TRIGGER IF EXISTS guard_payroll_periods_v1 ON public.payroll_periods;
DROP FUNCTION IF EXISTS public.guard_payroll_records_v1();
DROP FUNCTION IF EXISTS public.guard_payroll_periods_v1();
DROP FUNCTION IF EXISTS public.payroll_actor_v1(uuid);
