-- 20261018_app_logs_retention_v1.sql
-- CHƯA ÁP DỤNG lên production (chờ Chủ Quán duyệt). Chưa chạy thử trên bản sao.
-- Mục đích: log ghi nhiều hơn (hành động nghiệp vụ, tag = 'action') nên cần
--   1) chỉ mục để tra theo quán/loại/thời gian,
--   2) lịch xóa: log kỹ thuật giữ ngắn, log nghiệp vụ/kiểm toán giữ dài.
-- Không đổi cấu trúc bảng app_logs; không đụng dữ liệu hiện có khi chạy file này.
-- Rollback: rollback_app_logs_retention_v1.sql

BEGIN;

CREATE INDEX IF NOT EXISTS idx_app_logs_store_tag_created
  ON public.app_logs (store_id, tag, created_at DESC);

-- Tag được coi là nghiệp vụ/kiểm toán (giữ lâu): action, checkout, order, auth, ban_items.
-- Mọi tag khác (printer, system, settings, finance, ...) là log kỹ thuật (giữ ngắn).
CREATE OR REPLACE FUNCTION public.qn_app_logs_purge(
  p_tech_days integer DEFAULT 30,
  p_audit_days integer DEFAULT 365,
  p_batch integer DEFAULT 5000
) RETURNS TABLE (tech_deleted bigint, audit_deleted bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tech bigint := 0;
  v_audit bigint := 0;
  v_n bigint;
BEGIN
  -- Chặn gọi nhầm làm mất log: tối thiểu 7 ngày (kỹ thuật) và 90 ngày (nghiệp vụ).
  IF p_tech_days < 7 OR p_audit_days < 90 THEN
    RAISE EXCEPTION 'RETENTION_TOO_SHORT: tech>=7, audit>=90';
  END IF;
  IF p_batch < 100 OR p_batch > 20000 THEN
    RAISE EXCEPTION 'BATCH_OUT_OF_RANGE';
  END IF;

  -- Xóa theo lô nhỏ để không khóa bảng lâu (VPS 2 vCPU).
  LOOP
    DELETE FROM public.app_logs
    WHERE id IN (
      SELECT id FROM public.app_logs
      WHERE created_at < now() - make_interval(days => p_tech_days)
        AND tag NOT IN ('action','checkout','order','auth','ban_items')
      LIMIT p_batch);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_tech := v_tech + v_n;
    EXIT WHEN v_n < p_batch;
  END LOOP;

  LOOP
    DELETE FROM public.app_logs
    WHERE id IN (
      SELECT id FROM public.app_logs
      WHERE created_at < now() - make_interval(days => p_audit_days)
        AND tag IN ('action','checkout','order','auth','ban_items')
      LIMIT p_batch);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_audit := v_audit + v_n;
    EXIT WHEN v_n < p_batch;
  END LOOP;

  RETURN QUERY SELECT v_tech, v_audit;
END;
$$;

REVOKE ALL ON FUNCTION public.qn_app_logs_purge(integer, integer, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qn_app_logs_purge(integer, integer, integer) TO service_role;

COMMIT;

-- Gắn lịch (làm trên VPS, tương tự quannho-audit-purge.timer; KHÔNG nằm trong migration):
--   docker exec supabase-db psql -U supabase_admin -d postgres -c "SELECT * FROM qn_app_logs_purge(30,365,5000)"
-- Chạy 00:40 giờ Việt Nam mỗi đêm, sau lịch sao lưu 00:30.
