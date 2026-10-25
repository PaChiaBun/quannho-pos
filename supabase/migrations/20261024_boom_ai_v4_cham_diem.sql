-- ============================================================================
-- Boom AI v4 (24/10/2026) — 👍/👎 cho MỌI câu trả lời của Boom vào sổ hỏi đáp (Chủ Quán test web 24/10: chấm câu
-- trả lời số liệu → hiện "Chưa ghép nối thiết bị" vì đi đường phản hồi cũ của bản thử nghiệm).
-- Câu trả lời không gọi GPT (số liệu, hướng dẫn nguyên văn, từ chối…) chưa có dòng trong sổ → hàm boom-chat (chế độ
-- 'feedback') gọi boom_feedback_v1 ghi MỘT dòng trạng thái 'feedback' kèm câu hỏi, câu trả lời (đã che), 👍/👎, lý do,
-- loại câu trả lời (model = mã công cụ, vd orders_summary_read_only). Hạn mức chung "không tốn tiền" / người / giờ.
-- Áp sau 20261024_boom_ai_v3_bo_nho.sql (đã có trên production 24/10 02:42).
-- ============================================================================
BEGIN;

ALTER TABLE public.boom_qa_log DROP CONSTRAINT IF EXISTS boom_qa_log_status_check;
ALTER TABLE public.boom_qa_log ADD CONSTRAINT boom_qa_log_status_check
  CHECK (status IN ('pending', 'ok', 'error', 'rate_limited', 'budget', 'disabled', 'no_context', 'inactive_store',
                    'blocked', 'cached', 'feedback'));

CREATE OR REPLACE FUNCTION public.boom_feedback_v1(
  p_store uuid, p_user uuid, p_question text, p_answer text, p_rating text, p_reason text, p_tool text,
  p_free_per_hour integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_id uuid;
BEGIN
  IF p_rating IS NULL OR p_rating NOT IN ('up', 'down') OR btrim(COALESCE(p_question, '')) = '' THEN
    RETURN jsonb_build_object('ok', false, 'status', 'bad_request');
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('boom_ai:' || p_store::text, 0));
  IF NOT EXISTS (SELECT 1 FROM public.stores WHERE id = p_store AND COALESCE(status, 'trial') IN ('trial', 'active')) THEN
    RETURN jsonb_build_object('ok', false, 'status', 'inactive_store');
  END IF;
  IF (SELECT count(*) FROM public.boom_qa_log
      WHERE user_id = p_user AND status IN ('no_context', 'blocked', 'cached', 'feedback')
        AND created_at > now() - interval '1 hour') >= p_free_per_hour THEN
    RETURN jsonb_build_object('ok', false, 'status', 'rate_limited');
  END IF;
  INSERT INTO public.boom_qa_log (store_id, user_id, question, answer, model, status, rating, rating_reason, rated_at)
  VALUES (p_store, p_user, left(p_question, 1000), left(p_answer, 4000), left(NULLIF(btrim(p_tool), ''), 60),
          'feedback', p_rating, left(NULLIF(btrim(p_reason), ''), 300), now())
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'status', 'feedback', 'id', v_id);
END
$$;
REVOKE ALL ON FUNCTION public.boom_feedback_v1(uuid, uuid, text, text, text, text, text, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.boom_feedback_v1(uuid, uuid, text, text, text, text, text, integer) TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
