-- Gỡ bàn giao ca v1. CẢNH BÁO: xoá luôn các biên bản bàn giao đã lưu.
BEGIN;
DROP TABLE IF EXISTS public.ops_shift_handovers;
DROP FUNCTION IF EXISTS public.guard_ops_shift_handover_v1();
COMMIT;
NOTIFY pgrst, 'reload schema';
