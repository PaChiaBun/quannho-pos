-- ============================================================================
-- HOÀN TÁC 20261102_bo_huong_dan_dem_cau.sql — trả admin_boom_knowledge_v1 về nguyên văn bản 20261026_trang_quan_tri_v1
-- (trang /admin mới tự quay về cách cộng theo đoạn khi không có khoá 'modules').
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.admin_boom_knowledge_v1()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_pack record; r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  SELECT version, content, chunk_count, note, created_at INTO v_pack FROM public.boom_help_packs ORDER BY version DESC LIMIT 1;
  WITH usage AS (
    SELECT c AS chunk_id, count(*) AS uses,
           count(*) FILTER (WHERE l.rating = 'up') AS ups, count(*) FILTER (WHERE l.rating = 'down') AS downs
      FROM public.boom_qa_log l, unnest(l.chunk_ids) c
     WHERE l.status IN ('ok', 'cached') GROUP BY c
  )
  SELECT jsonb_build_object('ok', true,
    'packs', (SELECT COALESCE(jsonb_agg(jsonb_build_object('version', version, 'chunk_count', chunk_count,
                'note', note, 'created_at', created_at) ORDER BY version DESC), '[]'::jsonb) FROM public.boom_help_packs),
    'chunks', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                 'id', c->>'id', 'module', c->>'module_name', 'title', c->>'title',
                 'uses', COALESCE(u.uses, 0), 'ups', COALESCE(u.ups, 0), 'downs', COALESCE(u.downs, 0))
                 ORDER BY c->>'module_name', c->>'id'), '[]'::jsonb)
                 FROM jsonb_array_elements(COALESCE(v_pack.content->'chunks', '[]'::jsonb)) c
                 LEFT JOIN usage u ON u.chunk_id = c->>'id'),
    'cache', (SELECT COALESCE(jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'questions', questions,
                'answer', answer, 'status', status, 'hits', hits, 'ups', ups, 'downs', downs, 'note', note,
                'updated_at', updated_at) ORDER BY updated_at DESC), '[]'::jsonb) FROM public.boom_answer_cache),
    'changelog', (SELECT COALESCE(jsonb_agg(to_jsonb(c) ORDER BY c.applied_at DESC), '[]'::jsonb) FROM public.boom_changelog c)
  ) INTO r;
  RETURN r;
END
$fn$;

COMMIT;
NOTIFY pgrst, 'reload schema';
