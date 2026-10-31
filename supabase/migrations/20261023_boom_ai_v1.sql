-- ============================================================================
-- Boom AI v1 (23–24/10/2026) — sổ hỏi đáp + hạn mức + 👍/👎 cho hàm máy chủ boom-chat (GPT-4o mini).
-- ke-hoach-trien-khai-boom.md Bước 4.2, 4.3. Khoá API OpenAI KHÔNG nằm trong database.
--
-- • boom_qa_log: mỗi lần Boom hỏi GPT / không tìm thấy hướng dẫn — câu hỏi ĐÃ CHE thông tin riêng, mã đoạn
--   hướng dẫn, câu trả lời, mô hình, token, chi phí, trạng thái, 👍/👎. Chỉ hàm máy chủ (service_role) GHI.
--   Chủ quán / Quản lý ĐĂNG NHẬP THẬT (JWT) đọc sổ của quán mình — không nhận header x-user-id (#33).
-- • boom_ai_reserve_v1 (chỉ service_role): GIỮ CHỖ một lượt TRƯỚC khi gọi GPT, có khoá theo quán →
--   gửi dồn dập cùng lúc không lách được hạn mức. Kiểm: quán còn hoạt động (trial/active), lượt / người / giờ,
--   chi phí / quán / ngày, chi phí / quán / tháng, trần cả hệ thống / tháng; câu "không tìm thấy hướng dẫn"
--   có hạn mức riêng. Lượt bị chặn KHÔNG ghi dòng. Dọn sổ của quán cũ hơn 180 ngày.
-- • boom_ai_finish_v1 (chỉ service_role): ghi kết quả vào lượt đã giữ chỗ.
-- • boom_rate_answer_v1: người hỏi (JWT) chấm 👍/👎 câu của chính mình trong 7 ngày.
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS public.boom_qa_log (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  user_id       uuid,
  question      text NOT NULL CHECK (length(question) <= 1000),
  chunk_ids     text[] NOT NULL DEFAULT '{}',
  answer        text CHECK (answer IS NULL OR length(answer) <= 4000),
  model         text,
  input_tokens  integer NOT NULL DEFAULT 0,
  output_tokens integer NOT NULL DEFAULT 0,
  cost_usd      numeric(12, 6) NOT NULL DEFAULT 0,
  latency_ms    integer,
  status        text NOT NULL CHECK (status IN ('pending', 'ok', 'error', 'rate_limited', 'budget', 'disabled', 'no_context', 'inactive_store')),
  rating        text CHECK (rating IN ('up', 'down')),
  rating_reason text CHECK (rating_reason IS NULL OR length(rating_reason) <= 300),
  rated_at      timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_boom_qa_log_store_created ON public.boom_qa_log (store_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_boom_qa_log_user_created  ON public.boom_qa_log (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_boom_qa_log_created       ON public.boom_qa_log (created_at);

ALTER TABLE public.boom_qa_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS boom_qa_log_manager_read ON public.boom_qa_log;
CREATE POLICY boom_qa_log_manager_read ON public.boom_qa_log
  FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL
         AND store_id = (SELECT public.current_store_id())
         AND public.qn_is_manager(store_id));
REVOKE ALL ON public.boom_qa_log FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.boom_qa_log TO authenticated;
GRANT ALL ON public.boom_qa_log TO service_role;

-- Giữ chỗ một lượt (chỉ hàm máy chủ gọi). Trả {ok, id} hoặc {ok:false, status}.
CREATE OR REPLACE FUNCTION public.boom_ai_reserve_v1(
  p_store uuid, p_user uuid, p_question text, p_chunk_ids text[], p_mode text,
  p_user_per_hour integer, p_unanswered_per_hour integer,
  p_store_usd_day numeric, p_store_usd_month numeric, p_global_usd_month numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_day   timestamptz := date_trunc('day',   now() AT TIME ZONE 'Asia/Ho_Chi_Minh') AT TIME ZONE 'Asia/Ho_Chi_Minh';
  v_month timestamptz := date_trunc('month', now() AT TIME ZONE 'Asia/Ho_Chi_Minh') AT TIME ZONE 'Asia/Ho_Chi_Minh';
  v_status text;
  v_id uuid;
BEGIN
  -- Khoá theo quán: lượt gọi cùng lúc của một quán xếp hàng, đếm đúng.
  PERFORM pg_advisory_xact_lock(hashtextextended('boom_ai:' || p_store::text, 0));

  IF NOT EXISTS (SELECT 1 FROM public.stores WHERE id = p_store AND COALESCE(status, 'trial') IN ('trial', 'active')) THEN
    v_status := 'inactive_store';
  ELSIF p_mode = 'log_only' THEN
    IF (SELECT count(*) FROM public.boom_qa_log
        WHERE user_id = p_user AND status = 'no_context' AND created_at > now() - interval '1 hour') >= p_unanswered_per_hour THEN
      RETURN jsonb_build_object('ok', false, 'status', 'rate_limited');   -- không ghi thêm dòng
    END IF;
    v_status := 'no_context';
  ELSIF (SELECT count(*) FROM public.boom_qa_log
         WHERE user_id = p_user AND status IN ('pending', 'ok', 'error')
           AND created_at > now() - interval '1 hour') >= p_user_per_hour THEN
    v_status := 'rate_limited';
  ELSIF (SELECT COALESCE(sum(cost_usd), 0) FROM public.boom_qa_log WHERE store_id = p_store AND created_at >= v_day) >= p_store_usd_day
     OR (SELECT COALESCE(sum(cost_usd), 0) FROM public.boom_qa_log WHERE store_id = p_store AND created_at >= v_month) >= p_store_usd_month
     OR (SELECT COALESCE(sum(cost_usd), 0) FROM public.boom_qa_log WHERE created_at >= v_month) >= p_global_usd_month THEN
    v_status := 'budget';
  ELSE
    v_status := 'pending';
  END IF;

  -- Bị chặn (hết lượt / hết tiền / quán khoá): KHÔNG ghi dòng — gửi lặp không làm phình sổ.
  IF v_status IN ('rate_limited', 'budget', 'inactive_store') THEN
    RETURN jsonb_build_object('ok', false, 'status', v_status);
  END IF;

  -- Lượt đang chờ tính tạm chi phí ước lượng (≈ 1 lượt) để trần tiền chặt khi gọi dồn; finish ghi số thật.
  INSERT INTO public.boom_qa_log (store_id, user_id, question, chunk_ids, status, cost_usd)
  VALUES (p_store, p_user, left(p_question, 1000), COALESCE(p_chunk_ids, '{}'), v_status,
          CASE WHEN v_status = 'pending' THEN 0.001 ELSE 0 END)
  RETURNING id INTO v_id;

  -- Dọn sổ cũ của quán (rẻ: có chỉ mục store_id, created_at)
  DELETE FROM public.boom_qa_log WHERE store_id = p_store AND created_at < now() - interval '180 days';

  RETURN jsonb_build_object('ok', v_status = 'pending', 'status', v_status, 'id', v_id);
END
$$;
REVOKE ALL ON FUNCTION public.boom_ai_reserve_v1(uuid, uuid, text, text[], text, integer, integer, numeric, numeric, numeric)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.boom_ai_reserve_v1(uuid, uuid, text, text[], text, integer, integer, numeric, numeric, numeric)
  TO service_role;

-- Ghi kết quả vào lượt đã giữ chỗ (chỉ hàm máy chủ gọi)
CREATE OR REPLACE FUNCTION public.boom_ai_finish_v1(
  p_id uuid, p_status text, p_answer text, p_model text,
  p_input_tokens integer, p_output_tokens integer, p_cost_usd numeric, p_latency_ms integer
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE n integer;
BEGIN
  IF p_status NOT IN ('ok', 'error') THEN RETURN false; END IF;
  UPDATE public.boom_qa_log
     SET status = p_status, answer = left(p_answer, 4000), model = p_model,
         input_tokens = GREATEST(COALESCE(p_input_tokens, 0), 0),
         output_tokens = GREATEST(COALESCE(p_output_tokens, 0), 0),
         cost_usd = GREATEST(COALESCE(p_cost_usd, 0), 0), latency_ms = p_latency_ms
   WHERE id = p_id AND status = 'pending';
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n = 1;
END
$$;
REVOKE ALL ON FUNCTION public.boom_ai_finish_v1(uuid, text, text, text, integer, integer, numeric, integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.boom_ai_finish_v1(uuid, text, text, text, integer, integer, numeric, integer)
  TO service_role;

-- 👍/👎 của người hỏi (chỉ vé đăng nhập thật)
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
