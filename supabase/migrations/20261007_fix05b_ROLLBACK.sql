-- ROLLBACK FIX 05b (a): trả về dạng so sánh text như cũ (ý nghĩa quyền giống hệt, chỉ chậm hơn)
SET LOCAL lock_timeout = '3s';
DO $$
DECLARE p record; expr text;
BEGIN
  FOR p IN SELECT tablename, policyname, cmd, with_check FROM pg_policies
           WHERE schemaname='public' AND (coalesce(qual,'') LIKE '%SELECT current_store_id()%' OR coalesce(with_check,'') LIKE '%SELECT current_store_id()%')
             AND policyname NOT LIKE '%\_v5'
  LOOP
    expr := '(store_id)::text = (public.current_store_id())::text';
    IF p.cmd = 'INSERT' THEN EXECUTE format('ALTER POLICY %I ON public.%I WITH CHECK (%s)', p.policyname, p.tablename, expr);
    ELSIF p.cmd IN ('SELECT','DELETE') OR p.with_check IS NULL THEN EXECUTE format('ALTER POLICY %I ON public.%I USING (%s)', p.policyname, p.tablename, expr);
    ELSE EXECUTE format('ALTER POLICY %I ON public.%I USING (%s) WITH CHECK (%s)', p.policyname, p.tablename, expr, expr);
    END IF;
  END LOOP;
END $$;
