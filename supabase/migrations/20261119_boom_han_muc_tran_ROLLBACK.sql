-- HOÀN TÁC 20261119_boom_han_muc_tran.sql — trả hàm giữ chỗ về đúng bản đang chạy trên production ngày 19/11/2026
-- (chép nguyên từ pg_get_functiondef trước khi áp). Hàm boom-chat và app bản mới vẫn chạy được với bản này:
-- không có khoá "scope" thì app báo như trần ngày.
CREATE OR REPLACE FUNCTION public.boom_ai_reserve_v1(p_store uuid, p_user uuid, p_question text, p_chunk_ids text[], p_mode text, p_user_per_hour integer, p_unanswered_per_hour integer, p_store_usd_day numeric, p_store_usd_month numeric, p_global_usd_month numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
  ELSIF p_mode IN ('log_only', 'blocked') THEN
    -- Câu không có hướng dẫn / câu ngoài phạm vi bị chặn: chỉ ghi sổ, chung một hạn mức / người / giờ
    IF (SELECT count(*) FROM public.boom_qa_log
        WHERE user_id = p_user AND status IN ('no_context', 'blocked') AND created_at > now() - interval '1 hour') >= p_unanswered_per_hour THEN
      RETURN jsonb_build_object('ok', false, 'status', 'rate_limited');   -- không ghi thêm dòng
    END IF;
    v_status := CASE WHEN p_mode = 'blocked' THEN 'blocked' ELSE 'no_context' END;
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
$function$;
