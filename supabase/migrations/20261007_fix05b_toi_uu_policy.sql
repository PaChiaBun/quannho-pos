-- ═════════════════════════════════════════════════════════════════════════════
-- FIX 05b (a) — Tối ưu policy cô lập quán (07/10/2026, sau 23h)
-- Đổi  (store_id)::text = (current_store_id())::text   (hàm chạy lại cho TỪNG dòng)
-- sang store_id = (SELECT public.current_store_id())    (hàm chạy 1 lần / câu lệnh)
-- Ý nghĩa quyền KHÔNG đổi: cùng điều kiện "store_id của dòng = quán của người gọi".
-- Không đụng tới các policy USING(true) (phần b) — để sau khi máy bản cũ cập nhật.
-- ALTER POLICY giữ nguyên tên, lệnh (cmd) và roles của policy.
-- ═════════════════════════════════════════════════════════════════════════════
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '60s';

DO $$
DECLARE
  p record;
  coltype text;
  expr text;
  n int := 0;
BEGIN
  FOR p IN
    SELECT tablename, policyname, cmd, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND (
        coalesce(qual, '') IN ('((store_id)::text = (current_store_id())::text)',
                               '(store_id = (current_store_id())::text)',
                               '(store_id = current_store_id())')
        OR coalesce(with_check, '') IN ('((store_id)::text = (current_store_id())::text)',
                                        '(store_id = (current_store_id())::text)',
                                        '(store_id = current_store_id())')
      )
    ORDER BY tablename, policyname
  LOOP
    SELECT format_type(a.atttypid, a.atttypmod) INTO coltype
    FROM pg_attribute a
    WHERE a.attrelid = format('public.%I', p.tablename)::regclass
      AND a.attname = 'store_id' AND NOT a.attisdropped;

    IF coltype = 'uuid' THEN
      expr := 'store_id = (SELECT public.current_store_id())';
    ELSE
      expr := 'store_id = (SELECT public.current_store_id())::text';
    END IF;

    IF p.cmd IN ('INSERT') THEN
      EXECUTE format('ALTER POLICY %I ON public.%I WITH CHECK (%s)', p.policyname, p.tablename, expr);
    ELSIF p.cmd IN ('SELECT', 'DELETE') THEN
      EXECUTE format('ALTER POLICY %I ON public.%I USING (%s)', p.policyname, p.tablename, expr);
    ELSIF p.with_check IS NULL THEN
      EXECUTE format('ALTER POLICY %I ON public.%I USING (%s)', p.policyname, p.tablename, expr);
    ELSE
      EXECUTE format('ALTER POLICY %I ON public.%I USING (%s) WITH CHECK (%s)', p.policyname, p.tablename, expr, expr);
    END IF;
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'FIX05b: đã tối ưu % policy', n;
END $$;
