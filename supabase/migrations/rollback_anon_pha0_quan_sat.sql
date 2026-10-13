-- ROLLBACK cho 20261013_anon_pha0_quan_sat.sql
-- Gỡ trigger quan sát + hàm + bảng ghi nhận; khôi phục quyền/chính sách cũ của stock_movements_sync.
-- (Bảng anon_write_audit bị xóa cùng dữ liệu quan sát — nếu cần giữ bằng chứng, xuất ra trước.)
BEGIN;

DO $rb$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.relname FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
    WHERE t.tgname = 'qn_anon_write_audit' AND NOT t.tgisinternal
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS qn_anon_write_audit ON public.%I', r.relname);
  END LOOP;
END
$rb$;

DROP FUNCTION IF EXISTS public.qn_anon_write_audit();
DROP TABLE IF EXISTS public.anon_write_audit;

DO $p1a$
BEGIN
  IF to_regclass('public.stock_movements_sync') IS NOT NULL THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON public.stock_movements_sync TO anon, authenticated;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='stock_movements_sync' AND policyname='anon_all_stock') THEN
      CREATE POLICY anon_all_stock ON public.stock_movements_sync FOR ALL TO public USING (true) WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='stock_movements_sync' AND policyname='all_members_write_stock_movements') THEN
      CREATE POLICY all_members_write_stock_movements ON public.stock_movements_sync FOR ALL TO public USING (true) WITH CHECK (true);
    END IF;
  END IF;
END
$p1a$;

COMMIT;
