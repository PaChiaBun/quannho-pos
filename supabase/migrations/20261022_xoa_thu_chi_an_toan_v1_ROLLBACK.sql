-- Hoàn tác 20261022_xoa_thu_chi_an_toan_v1.sql. GIỮ bảng finance_record_deletions (vết đã xoá).
DROP TRIGGER IF EXISTS guard_finance_records_v1 ON public.finance_records;
DROP FUNCTION IF EXISTS public.guard_finance_records_v1();
DROP FUNCTION IF EXISTS public.delete_manual_finance_record_v1(uuid, uuid, text);
