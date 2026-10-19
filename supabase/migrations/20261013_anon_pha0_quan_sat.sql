-- ============================================================================
-- THU HỒI QUYỀN anon DẦN DẦN — PHA 0 (quan sát) + PHA 1a (khóa bảng chết)
--
-- Bối cảnh (audit 13/10): anon được GRANT INSERT/UPDATE/DELETE trên ~52 bảng. RLS bật ở cả 68 bảng và
-- chính sách cô lập theo current_store_id(), NHƯNG danh tính lấy từ header x-store-id / x-user-id do máy
-- khách tự gửi (có thể giả). Thu hồi ngay sẽ làm hỏng các bản app cũ còn đăng nhập kiểu header (sự cố
-- FIX 11, 10/10). Vì vậy: quan sát trước, thu hồi từng bảng khi đã có bằng chứng.
--
-- PHA 0 — KHÔNG đổi hành vi nghiệp vụ:
--   * Bảng public.anon_write_audit: mỗi câu lệnh GHI do vai anon thực hiện lên bảng được theo dõi sẽ để lại
--     1 dòng (bảng, thao tác, jwt_role, có header x-user-id?, có header x-store-id?, x-client-info).
--     KHÔNG lưu dữ liệu nghiệp vụ, không lưu giá trị header, không lưu nội dung dòng.
--   * Trigger mức câu lệnh, SECURITY DEFINER, mọi lỗi trong trigger bị nuốt (không bao giờ làm hỏng ghi thật).
-- PHA 1a — stock_movements_sync (0 dòng, không có trong code app/dịch vụ) đang mở ALL cho public với
--   USING(true): bỏ 2 chính sách mở + thu hồi quyền anon/authenticated.
--
-- Hoàn tác: rollback_anon_pha0_quan_sat.sql
-- ============================================================================

BEGIN;
SET LOCAL client_min_messages = warning;  -- bớt thông báo "trigger does not exist, skipping"

-- 1. Bảng ghi nhận ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.anon_write_audit (
  id               bigserial PRIMARY KEY,
  at               timestamptz NOT NULL DEFAULT now(),
  table_name       text NOT NULL,
  op               text NOT NULL,
  jwt_role         text,
  has_user_header  boolean NOT NULL DEFAULT false,
  has_store_header boolean NOT NULL DEFAULT false,
  client           text
);
CREATE INDEX IF NOT EXISTS idx_anon_write_audit_at ON public.anon_write_audit (at);
ALTER TABLE public.anon_write_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.anon_write_audit FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.anon_write_audit_id_seq FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.anon_write_audit TO service_role;
GRANT ALL ON SEQUENCE public.anon_write_audit_id_seq TO service_role;

-- 2. Hàm trigger -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qn_anon_write_audit()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_hdr jsonb;
  v_claims jsonb;
BEGIN
  -- Chỉ ghi nhận vai anon (PostgREST đặt GUC "role"; trong hàm SECURITY DEFINER current_user là chủ hàm)
  IF COALESCE(current_setting('role', true), '') <> 'anon' THEN
    RETURN NULL;
  END IF;
  BEGIN v_hdr := NULLIF(current_setting('request.headers', true), '')::jsonb; EXCEPTION WHEN OTHERS THEN v_hdr := NULL; END;
  BEGIN v_claims := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb; EXCEPTION WHEN OTHERS THEN v_claims := NULL; END;
  INSERT INTO public.anon_write_audit (table_name, op, jwt_role, has_user_header, has_store_header, client)
  VALUES (TG_TABLE_NAME, TG_OP,
          v_claims->>'role',
          COALESCE(NULLIF(v_hdr->>'x-user-id', ''), '') <> '',
          COALESCE(NULLIF(v_hdr->>'x-store-id', ''), '') <> '',
          left(COALESCE(v_hdr->>'x-client-info', ''), 60));
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;   -- ghi nhận không bao giờ được làm hỏng nghiệp vụ
END
$fn$;
REVOKE ALL ON FUNCTION public.qn_anon_write_audit() FROM PUBLIC, anon, authenticated;

-- 3. Gắn trigger vào mọi bảng mà anon đang được GHI (trừ app_logs: nhật ký, ghi dày) --------------
DO $trg$
DECLARE
  r record;
  v_n int := 0;
BEGIN
  FOR r IN
    SELECT DISTINCT g.table_name
    FROM information_schema.role_table_grants g
    JOIN pg_class c ON c.relname = g.table_name AND c.relnamespace = 'public'::regnamespace AND c.relkind = 'r'
    WHERE g.grantee = 'anon' AND g.table_schema = 'public'
      AND g.privilege_type IN ('INSERT', 'UPDATE', 'DELETE')
      AND g.table_name NOT IN ('app_logs', 'anon_write_audit')
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS qn_anon_write_audit ON public.%I', r.table_name);
    EXECUTE format(
      'CREATE TRIGGER qn_anon_write_audit AFTER INSERT OR UPDATE OR DELETE ON public.%I '
      'FOR EACH STATEMENT EXECUTE FUNCTION public.qn_anon_write_audit()', r.table_name);
    v_n := v_n + 1;
  END LOOP;
  RAISE WARNING 'PHA 0: đã gắn trigger quan sát vào % bảng', v_n;
END
$trg$;

-- 4. PHA 1a: stock_movements_sync (bảng chết, đang mở toàn quyền) ---------------------------------
DO $p1a$
BEGIN
  IF to_regclass('public.stock_movements_sync') IS NOT NULL THEN
    -- An toàn: chỉ khóa khi bảng thật sự rỗng (nếu có dữ liệu thì dừng, để người xem xét)
    IF (SELECT count(*) FROM public.stock_movements_sync) > 0 THEN
      RAISE EXCEPTION 'PHA 1a DỪNG: stock_movements_sync có dữ liệu, cần xem xét thủ công';
    END IF;
    DROP POLICY IF EXISTS all_members_write_stock_movements ON public.stock_movements_sync;
    DROP POLICY IF EXISTS anon_all_stock ON public.stock_movements_sync;
    REVOKE ALL ON public.stock_movements_sync FROM anon, authenticated;
    RAISE WARNING 'PHA 1a: đã khóa stock_movements_sync';
  END IF;
END
$p1a$;

COMMIT;
