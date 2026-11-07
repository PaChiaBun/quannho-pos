-- ============================================================================
-- Boom AI v3 (24/10/2026) — BỘ NHỚ CÂU TRẢ LỜI ĐÃ DUYỆT (ke-hoach-trien-khai-boom.md Bước 4.3).
-- Câu hỏi giống câu đã duyệt → hàm boom-chat trả câu đã duyệt, KHÔNG gọi GPT (0 đồng, đã qua luật).
--
-- • boom_answer_cache: câu trả lời đã duyệt + các cách hỏi (đã chuẩn hoá) + loại ('guide' theo bài hướng dẫn /
--   'advice' tư vấn kinh doanh) + mã đoạn hướng dẫn + mã băm nội dung đoạn lúc duyệt (bài đổi → câu tự hết hiệu lực).
--   Dùng CHUNG cho mọi quán → chỉ duyệt câu trả lời KHÔNG chứa thông tin riêng của quán nào (quy trình duyệt).
--   Chỉ service_role (hàm máy chủ) đọc; chỉ supabase_admin (script duyệt) ghi. App không đọc / ghi được.
-- • boom_cache_hit_v1 (chỉ service_role): ghi sổ một lượt trả từ bộ nhớ (trạng thái 'cached', chi phí 0), đếm lượt
--   dùng; hạn mức riêng / người / giờ (BOOM_UNANSWERED_PER_HOUR, đếm cả câu bị chặn + câu không có hướng dẫn). Hết lượt
--   → hàm boom-chat bỏ qua bộ nhớ, đi đường GPT thường (hạn mức GPT riêng).
-- • boom_rate_answer_v1 (thay thân hàm, giữ chữ ký): chấm được cả câu 'cached'. 👍 / 👎 của câu từ bộ nhớ đếm theo
--   SỐ CHỦ QUÁN (lần chấm mới nhất của mỗi chủ quán; chỉ quán đã mở ≥ 7 ngày — tài khoản ảo mới tạo không tính) — một
--   người tự chấm nhiều lần / mở nhiều quán chỉ tính 1. 👎 từ ≥ 2 chủ quán và nhiều hơn 👍
--   → tự gỡ (status 'retired'), lần sau GPT trả lời lại và câu mới vào hàng chờ duyệt.
-- Áp sau 20261024_boom_ai_v2_luat.sql (đã có trên production 24/10 01:40).
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS public.boom_answer_cache (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind        text NOT NULL CHECK (kind IN ('guide', 'advice')),
  questions   text[] NOT NULL CHECK (cardinality(questions) BETWEEN 1 AND 30),
  chunk_ids   text[] NOT NULL DEFAULT '{}',
  chunk_hash  text,
  answer      text NOT NULL CHECK (length(answer) BETWEEN 1 AND 2000),
  status      text NOT NULL DEFAULT 'approved' CHECK (status IN ('approved', 'retired')),
  approved_by text NOT NULL CHECK (length(approved_by) BETWEEN 1 AND 60),
  note        text CHECK (note IS NULL OR length(note) <= 500),
  from_log_id uuid,
  hits        integer NOT NULL DEFAULT 0,
  ups         integer NOT NULL DEFAULT 0,
  downs       integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CHECK ((kind = 'guide') = (cardinality(chunk_ids) > 0 AND chunk_hash IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS idx_boom_answer_cache_status ON public.boom_answer_cache (status);

ALTER TABLE public.boom_answer_cache ENABLE ROW LEVEL SECURITY;   -- không có policy: app không đọc được
REVOKE ALL ON public.boom_answer_cache FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.boom_answer_cache TO service_role;   -- hàm máy chủ chỉ đọc; ghi qua script duyệt / hàm dưới

ALTER TABLE public.boom_qa_log ADD COLUMN IF NOT EXISTS cache_id uuid
  REFERENCES public.boom_answer_cache(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_boom_qa_log_cache ON public.boom_qa_log (cache_id) WHERE cache_id IS NOT NULL;

ALTER TABLE public.boom_qa_log DROP CONSTRAINT IF EXISTS boom_qa_log_status_check;
ALTER TABLE public.boom_qa_log ADD CONSTRAINT boom_qa_log_status_check
  CHECK (status IN ('pending', 'ok', 'error', 'rate_limited', 'budget', 'disabled', 'no_context', 'inactive_store',
                    'blocked', 'cached'));

-- Trả lời từ bộ nhớ: ghi sổ + đếm lượt dùng. Trả {ok, id, answer} hoặc {ok:false, status}.
CREATE OR REPLACE FUNCTION public.boom_cache_hit_v1(
  p_store uuid, p_user uuid, p_question text, p_cache_id uuid, p_free_per_hour integer
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_answer text;
  v_chunks text[];
  v_id uuid;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('boom_ai:' || p_store::text, 0));
  IF NOT EXISTS (SELECT 1 FROM public.stores WHERE id = p_store AND COALESCE(status, 'trial') IN ('trial', 'active')) THEN
    RETURN jsonb_build_object('ok', false, 'status', 'inactive_store');
  END IF;
  IF (SELECT count(*) FROM public.boom_qa_log
      WHERE user_id = p_user AND status IN ('no_context', 'blocked', 'cached')
        AND created_at > now() - interval '1 hour') >= p_free_per_hour THEN
    RETURN jsonb_build_object('ok', false, 'status', 'rate_limited');
  END IF;
  UPDATE public.boom_answer_cache SET hits = hits + 1
   WHERE id = p_cache_id AND status = 'approved'
   RETURNING answer, chunk_ids INTO v_answer, v_chunks;
  IF v_answer IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'status', 'retired');
  END IF;
  INSERT INTO public.boom_qa_log (store_id, user_id, question, chunk_ids, answer, model, status, cache_id)
  VALUES (p_store, p_user, left(p_question, 1000), COALESCE(v_chunks, '{}'), v_answer, 'cache', 'cached', p_cache_id)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'status', 'cached', 'id', v_id, 'answer', v_answer);
END
$$;
REVOKE ALL ON FUNCTION public.boom_cache_hit_v1(uuid, uuid, text, uuid, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.boom_cache_hit_v1(uuid, uuid, text, uuid, integer) TO service_role;

-- 👍/👎 của người hỏi (chỉ vé đăng nhập thật). Câu từ bộ nhớ: cộng / trừ đếm theo thay đổi (chấm lại không đếm hai lần).
CREATE OR REPLACE FUNCTION public.boom_rate_answer_v1(p_id uuid, p_rating text, p_reason text DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_old text;
  v_cache uuid;
BEGIN
  IF v_caller IS NULL OR p_rating NOT IN ('up', 'down') THEN RETURN false; END IF;
  SELECT rating, cache_id INTO v_old, v_cache FROM public.boom_qa_log
   WHERE id = p_id AND user_id = v_caller AND status IN ('ok', 'cached') AND created_at > now() - interval '7 days'
   FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;
  UPDATE public.boom_qa_log
     SET rating = p_rating,
         rating_reason = left(NULLIF(btrim(p_reason), ''), 300),
         rated_at = now()
   WHERE id = p_id;
  IF v_cache IS NOT NULL AND v_old IS DISTINCT FROM p_rating THEN
    PERFORM 1 FROM public.boom_answer_cache WHERE id = v_cache FOR UPDATE;   -- chấm cùng lúc: đếm tuần tự
    WITH moi_quan AS (   -- mỗi CHỦ QUÁN một phiếu (lần chấm mới nhất), chống một người mở nhiều quán để gỡ câu
      SELECT DISTINCT ON (s.owner_user_id) l.rating FROM public.boom_qa_log l JOIN public.stores s ON s.id = l.store_id
       WHERE l.cache_id = v_cache AND l.rating IS NOT NULL AND s.created_at < now() - interval '7 days'
       ORDER BY s.owner_user_id, l.rated_at DESC NULLS LAST, l.id DESC)
    UPDATE public.boom_answer_cache
       SET ups   = (SELECT count(*) FROM moi_quan WHERE rating = 'up'),
           downs = (SELECT count(*) FROM moi_quan WHERE rating = 'down'),
           updated_at = now()
     WHERE id = v_cache;
    -- 👎 từ ≥ 2 chủ quán và nhiều hơn 👍 → tự gỡ khỏi bộ nhớ
    UPDATE public.boom_answer_cache SET status = 'retired', updated_at = now()
     WHERE id = v_cache AND status = 'approved' AND downs >= 2 AND downs > ups;
  END IF;
  RETURN true;
END
$$;
REVOKE ALL ON FUNCTION public.boom_rate_answer_v1(uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.boom_rate_answer_v1(uuid, text, text) TO authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
