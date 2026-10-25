-- HOÀN TÁC 20261024_boom_ai_v3_bo_nho.sql — gỡ bộ nhớ câu đã duyệt, trả hàm 👍/👎 về bản v1.
-- Đưa hàm boom-chat cũ (chưa tra bộ nhớ) về TRƯỚC — boom_bo_nho_ap_dung.sh ROLLBACK=1 làm sẵn.
BEGIN;
DELETE FROM public.boom_qa_log WHERE status = 'cached';
ALTER TABLE public.boom_qa_log DROP CONSTRAINT IF EXISTS boom_qa_log_status_check;
ALTER TABLE public.boom_qa_log ADD CONSTRAINT boom_qa_log_status_check
  CHECK (status IN ('pending', 'ok', 'error', 'rate_limited', 'budget', 'disabled', 'no_context', 'inactive_store', 'blocked'));
ALTER TABLE public.boom_qa_log DROP COLUMN IF EXISTS cache_id;
DROP FUNCTION IF EXISTS public.boom_cache_hit_v1(uuid, uuid, text, uuid, integer);
DROP TABLE IF EXISTS public.boom_answer_cache;

CREATE OR REPLACE FUNCTION public.boom_rate_answer_v1(p_id uuid, p_rating text, p_reason text DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller uuid := auth.uid();
  n integer;
BEGIN
  IF v_caller IS NULL OR p_rating NOT IN ('up', 'down') THEN RETURN false; END IF;
  UPDATE public.boom_qa_log
     SET rating = p_rating,
         rating_reason = left(NULLIF(btrim(p_reason), ''), 300),
         rated_at = now()
   WHERE id = p_id AND user_id = v_caller AND status = 'ok' AND created_at > now() - interval '7 days';
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n = 1;
END
$$;
REVOKE ALL ON FUNCTION public.boom_rate_answer_v1(uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.boom_rate_answer_v1(uuid, text, text) TO authenticated;

COMMIT;
NOTIFY pgrst, 'reload schema';
