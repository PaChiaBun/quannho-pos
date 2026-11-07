-- Tự xóa bản ghi quan sát anon cũ (retention). Bảng anon_write_audit tăng ~3,6 MB/ngày.
-- Hàm chỉ xóa dòng cũ hơn p_days (mặc định 30, tối thiểu 7 để không lỡ xóa bằng chứng đang quan sát).
-- Chạy hằng ngày bởi systemd timer quannho-audit-purge.timer. Hoàn tác: rollback_anon_pha0_quan_sat.sql.
BEGIN;
CREATE OR REPLACE FUNCTION public.qn_anon_write_audit_purge(p_days integer DEFAULT 30)
RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE n bigint;
BEGIN
  IF p_days IS NULL OR p_days < 7 THEN
    RAISE EXCEPTION 'p_days phải >= 7 (đang quan sát, không xóa sớm hơn 7 ngày)';
  END IF;
  DELETE FROM public.anon_write_audit WHERE at < now() - make_interval(days => p_days);
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END
$fn$;
REVOKE ALL ON FUNCTION public.qn_anon_write_audit_purge(integer) FROM PUBLIC, anon, authenticated;
COMMIT;
