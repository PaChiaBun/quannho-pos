-- ============================================================================
-- Nhật ký (app_logs) — lịch dọn v2 (23/10/2026). Thay 20261018_app_logs_retention_v1.sql (đã bỏ).
-- CHƯA ÁP DỤNG lên production — chờ Chủ Quán duyệt.
--
-- Khác v1: "log nghiệp vụ giữ lâu" dùng CHUNG hàm public.app_log_is_protected_tag() với khoá
-- nhật ký (20261022_khoa_xoa_nhat_ky_v1 + v2): action, checkout, order, auth, ban_items, finance,
-- payroll, staff, staff_shift_audit, payroll_staff_confirm, kho, settings, inventory.
-- v1 viết cứng 5 tag → Thu Chi / Lương / Kho / Cài đặt sẽ bị xoá sau 30 ngày. Thêm tag vào hàm
-- là lịch dọn tự theo, không phải sửa 2 nơi.
--
-- Log kỹ thuật (printer, system, kitchen, …) giữ p_tech_days (mặc định 30); log nghiệp vụ giữ
-- p_audit_days (mặc định 365). Chỉ service_role / quản trị VPS gọi được — app (anon) không gọi.
-- File này KHÔNG xoá log nào; chỉ tạo hàm + chỉ mục. Lịch chạy gắn riêng trên VPS (xem cuối file).
-- ============================================================================
BEGIN;

CREATE INDEX IF NOT EXISTS idx_app_logs_created_at
  ON public.app_logs (created_at);

CREATE OR REPLACE FUNCTION public.qn_app_logs_purge(
  p_tech_days  integer DEFAULT 30,
  p_audit_days integer DEFAULT 365,
  p_batch      integer DEFAULT 5000
) RETURNS TABLE (tech_deleted bigint, audit_deleted bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tech  bigint := 0;
  v_audit bigint := 0;
  v_n     bigint;
BEGIN
  -- Chặn gọi nhầm làm mất log: tối thiểu 7 ngày (kỹ thuật) và 90 ngày (nghiệp vụ).
  IF p_tech_days IS NULL OR p_audit_days IS NULL OR p_tech_days < 7 OR p_audit_days < 90 THEN
    RAISE EXCEPTION 'RETENTION_TOO_SHORT: tech>=7, audit>=90';
  END IF;
  IF p_batch IS NULL OR p_batch < 100 OR p_batch > 20000 THEN
    RAISE EXCEPTION 'BATCH_OUT_OF_RANGE';
  END IF;

  -- Chia lô chỉ để mỗi câu DELETE nhỏ; cả hàm vẫn là MỘT transaction (giữ khoá tới khi xong).
  -- Lần đầu ~132.000 dòng: chạy thử trên bản sao ~1 phút với lô 100, lô 5000 nhanh hơn — chạy giờ vắng.
  -- created_at NULL: không đụng.
  LOOP
    DELETE FROM public.app_logs
    WHERE id IN (
      SELECT id FROM public.app_logs
      WHERE created_at < now() - make_interval(days => p_tech_days)
        AND NOT public.app_log_is_protected_tag(tag)
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
        AND public.app_log_is_protected_tag(tag)
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

-- Gắn lịch (làm trên VPS bằng systemd timer, giống quannho-audit-purge.timer; KHÔNG nằm trong migration):
--   docker exec supabase-db psql -U supabase_admin -d postgres -c "SELECT * FROM qn_app_logs_purge(30,365,5000)"
-- Chạy 00:40 giờ Việt Nam mỗi đêm, sau lịch sao lưu 00:30.
