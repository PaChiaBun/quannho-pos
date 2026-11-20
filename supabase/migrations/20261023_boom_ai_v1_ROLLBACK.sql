-- HOÀN TÁC 20261023_boom_ai_v1.sql — XOÁ sổ hỏi đáp Boom (mất lịch sử hỏi đáp / 👍👎 đã lưu).
BEGIN;
DROP FUNCTION IF EXISTS public.boom_rate_answer_v1(uuid, text, text);
DROP FUNCTION IF EXISTS public.boom_ai_finish_v1(uuid, text, text, text, integer, integer, numeric, integer);
DROP FUNCTION IF EXISTS public.boom_ai_reserve_v1(uuid, uuid, text, text[], text, integer, integer, numeric, numeric, numeric);
DROP FUNCTION IF EXISTS public.boom_ai_quota_v1(uuid, uuid);
DROP TABLE IF EXISTS public.boom_qa_log;
COMMIT;
NOTIFY pgrst, 'reload schema';
