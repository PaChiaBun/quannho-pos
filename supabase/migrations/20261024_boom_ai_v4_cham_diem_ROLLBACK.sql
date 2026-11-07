-- HOÀN TÁC 20261024_boom_ai_v4_cham_diem.sql — đưa hàm boom-chat bản v3 về TRƯỚC (boom_cham_diem_ap_dung.sh làm sẵn).
BEGIN;
DELETE FROM public.boom_qa_log WHERE status = 'feedback';
DROP FUNCTION IF EXISTS public.boom_feedback_v1(uuid, uuid, text, text, text, text, text, integer);
ALTER TABLE public.boom_qa_log DROP CONSTRAINT IF EXISTS boom_qa_log_status_check;
ALTER TABLE public.boom_qa_log ADD CONSTRAINT boom_qa_log_status_check
  CHECK (status IN ('pending', 'ok', 'error', 'rate_limited', 'budget', 'disabled', 'no_context', 'inactive_store',
                    'blocked', 'cached'));
COMMIT;
NOTIFY pgrst, 'reload schema';
