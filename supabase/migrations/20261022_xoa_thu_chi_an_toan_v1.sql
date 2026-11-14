-- ============================================================================
-- XOÁ THU/CHI AN TOÀN (22/10/2026) — P0-3 trong .docs/Huong_dan/viec-can-sua.md
-- Lỗi cũ (FinanceRepository.deleteRecord, client): xoá thẳng finance_records (is_auto=false)
--   — ai có module Thu Chi cũng xoá được, không lý do, không dấu vết; client còn có quyền
--   UPDATE/DELETE mọi dòng thu chi (kể cả dòng tự động từ thanh toán) qua API.
-- Sửa:
--   * bảng finance_record_deletions: lưu nguyên dòng bị xoá + người xoá + lý do (client chỉ đọc);
--   * RPC delete_manual_finance_record_v1: chỉ Chủ quán/Quản lý, chỉ dòng nhập tay, bắt buộc
--     lý do; lưu vết rồi xoá trong một transaction; gọi lại khi đã xoá → already_deleted;
--   * trigger guard_finance_records_v1: vai trò anon/authenticated không UPDATE/DELETE trực tiếp
--     finance_records (app không có chỗ nào sửa; INSERT giữ nguyên).
-- Ảnh hưởng app cũ (≤ 1.0.5+20): bấm Xoá giao dịch không còn tác dụng (máy chủ từ chối).
-- Rollback: 20261022_xoa_thu_chi_an_toan_v1_ROLLBACK.sql
-- ============================================================================

DO $pf$
BEGIN
  IF to_regprocedure('public.qr_staff_ctx_v4(uuid,boolean,boolean)') IS NULL
     OR to_regprocedure('public.qr_err_v4(text,text)') IS NULL THEN
    RAISE EXCEPTION 'PREFLIGHT: thiếu qr_staff_ctx_v4 / qr_err_v4 (cần 20261013_qr_order_simple_v4.sql)';
  END IF;
  IF to_regprocedure('public.current_store_id()') IS NULL THEN
    RAISE EXCEPTION 'PREFLIGHT: thiếu current_store_id()';
  END IF;
  RAISE NOTICE 'PREFLIGHT xoa_thu_chi_an_toan_v1: OK';
END
$pf$;

CREATE TABLE IF NOT EXISTS public.finance_record_deletions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      uuid NOT NULL,
  record_id     uuid NOT NULL,
  record        jsonb NOT NULL,
  reason        text NOT NULL,
  actor_user_id uuid,
  actor_role    text,
  deleted_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (store_id, record_id)
);
ALTER TABLE public.finance_record_deletions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.finance_record_deletions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.finance_record_deletions TO authenticated;
GRANT ALL ON public.finance_record_deletions TO service_role;
DROP POLICY IF EXISTS finance_record_deletions_read ON public.finance_record_deletions;
CREATE POLICY finance_record_deletions_read ON public.finance_record_deletions
  FOR SELECT TO authenticated
  USING (store_id = (SELECT public.current_store_id()));

CREATE OR REPLACE FUNCTION public.guard_finance_records_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog, pg_temp
AS $fn$
BEGIN
  -- Chỉ chặn app (PostgREST). RPC SECURITY DEFINER, quản trị, xoá dây chuyền khi xoá quán: không chặn.
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  RAISE EXCEPTION 'FINANCE_RECORD_LOCKED: Không sửa/xoá trực tiếp thu chi — dùng nút Xoá giao dịch (cần Chủ quán/Quản lý)'
    USING ERRCODE = '42501';
END
$fn$;

DROP TRIGGER IF EXISTS guard_finance_records_v1 ON public.finance_records;
CREATE TRIGGER guard_finance_records_v1
  BEFORE UPDATE OR DELETE ON public.finance_records
  FOR EACH ROW EXECUTE FUNCTION public.guard_finance_records_v1();

CREATE OR REPLACE FUNCTION public.delete_manual_finance_record_v1(
  p_store_id  uuid,
  p_record_id uuid,
  p_reason    text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ctx    jsonb;
  v_uid    uuid;
  v_rec    public.finance_records%ROWTYPE;
  v_reason text := btrim(COALESCE(p_reason, ''));
BEGIN
  v_ctx := public.qr_staff_ctx_v4(p_store_id, false, false);
  IF NOT COALESCE((v_ctx->>'success')::boolean, false) THEN
    RETURN v_ctx;
  END IF;
  IF NOT COALESCE((v_ctx->>'is_manager')::boolean, false) THEN
    RETURN public.qr_err_v4('PERMISSION_DENIED', 'Chỉ Chủ quán hoặc Quản lý được xoá giao dịch thu chi');
  END IF;
  v_uid := NULLIF(v_ctx->>'uid', '')::uuid;

  IF p_record_id IS NULL THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Thiếu mã giao dịch');
  END IF;
  IF length(v_reason) < 3 OR length(v_reason) > 300 THEN
    RETURN public.qr_err_v4('REASON_REQUIRED', 'Nhập lý do xoá (ít nhất 3 ký tự)');
  END IF;

  SELECT * INTO v_rec FROM public.finance_records
  WHERE id = p_record_id AND store_id = p_store_id
  FOR UPDATE;

  IF NOT FOUND THEN
    -- Bấm lại sau khi mạng chập chờn: đã xoá rồi thì coi như xong.
    IF EXISTS (SELECT 1 FROM public.finance_record_deletions
               WHERE store_id = p_store_id AND record_id = p_record_id) THEN
      RETURN jsonb_build_object('success', true, 'data',
        jsonb_build_object('record_id', p_record_id, 'already_deleted', true));
    END IF;
    RETURN public.qr_err_v4('NOT_FOUND', 'Không tìm thấy giao dịch này');
  END IF;

  IF COALESCE(v_rec.is_auto, false) THEN
    RETURN public.qr_err_v4('AUTO_RECORD',
      'Giao dịch tự động (bán hàng, nhập kho, lương…) không xoá ở đây — huỷ từ nghiệp vụ gốc');
  END IF;

  INSERT INTO public.finance_record_deletions (store_id, record_id, record, reason, actor_user_id, actor_role)
  VALUES (p_store_id, p_record_id, to_jsonb(v_rec), v_reason, v_uid, v_ctx->>'role');

  DELETE FROM public.finance_records WHERE id = p_record_id;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'record_id', p_record_id,
    'type', v_rec.type,
    'amount', v_rec.amount,
    'already_deleted', false
  ));
END
$fn$;

REVOKE ALL ON FUNCTION public.delete_manual_finance_record_v1(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_manual_finance_record_v1(uuid, uuid, text)
  TO anon, authenticated, service_role;

DO $chk$
BEGIN
  IF to_regprocedure('public.delete_manual_finance_record_v1(uuid,uuid,text)') IS NULL
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'guard_finance_records_v1'
                    AND tgrelid = 'public.finance_records'::regclass) THEN
    RAISE EXCEPTION 'POSTCHECK: thiếu delete_manual_finance_record_v1 / guard_finance_records_v1';
  END IF;
  RAISE NOTICE 'POSTCHECK xoa_thu_chi_an_toan_v1: OK';
END
$chk$;
