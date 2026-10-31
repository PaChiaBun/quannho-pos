-- ============================================================================
-- BỘ HƯỚNG DẪN /admin: ĐẾM ĐÚNG SỐ CÂU HỎI THEO MODULE (Chủ Quán 26/10 "đếm đúng số câu hỏi ở Bộ hướng dẫn")
-- Trước: /admin cộng lượt dùng từng ĐOẠN → một câu gửi kèm 3 đoạn cùng module bị tính 3 lần (Báo cáo hiện 8, thật 4).
-- Sau: admin_boom_knowledge_v1 trả thêm 'modules' [{module, questions, ups, downs}] đếm câu không trùng.
-- Chỉ thêm một khoá JSON (trang /admin cũ bỏ qua khoá lạ); giữ nguyên quyền (CREATE OR REPLACE giữ GRANT).
-- Hoàn tác: …_ROLLBACK.sql (trả nguyên văn bản 20261026_trang_quan_tri_v1).
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
    -- 26/10: số CÂU HỎI theo module (một câu gửi kèm ≤ 3 đoạn cùng module chỉ tính 1 — trước /admin cộng số đoạn)
    'modules', (SELECT COALESCE(jsonb_agg(jsonb_build_object('module', m.module, 'questions', m.questions,
                  'ups', m.ups, 'downs', m.downs) ORDER BY m.module), '[]'::jsonb) FROM (
                  SELECT cm.module, count(DISTINCT l.id) AS questions,
                         count(DISTINCT l.id) FILTER (WHERE l.rating = 'up') AS ups,
                         count(DISTINCT l.id) FILTER (WHERE l.rating = 'down') AS downs
                    FROM (SELECT c->>'id' AS id, c->>'module_name' AS module
                            FROM jsonb_array_elements(COALESCE(v_pack.content->'chunks', '[]'::jsonb)) c) cm
                    -- tách mảng mã đoạn rồi nối theo mã (băm nối, ~3 × số câu) — không so "= ANY" từng đoạn × từng câu
                    JOIN (SELECT l.id, l.rating, u.chunk_id FROM public.boom_qa_log l, unnest(l.chunk_ids) u(chunk_id)
                           WHERE l.status IN ('ok', 'cached')) l ON l.chunk_id = cm.id
                   GROUP BY cm.module) m),
    'cache', (SELECT COALESCE(jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'questions', questions,
                'answer', answer, 'status', status, 'hits', hits, 'ups', ups, 'downs', downs, 'note', note,
                'updated_at', updated_at) ORDER BY updated_at DESC), '[]'::jsonb) FROM public.boom_answer_cache),
    'changelog', (SELECT COALESCE(jsonb_agg(to_jsonb(c) ORDER BY c.applied_at DESC), '[]'::jsonb) FROM public.boom_changelog c)
  ) INTO r;
  RETURN r;
END
$fn$;

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.admin_boom_knowledge_v1()', 'execute')
     OR has_function_privilege('authenticated', 'public.admin_boom_knowledge_v1()', 'execute')
     OR NOT has_function_privilege('qn_admin', 'public.admin_boom_knowledge_v1()', 'execute') THEN
    RAISE EXCEPTION 'BO HUONG DAN DEM CAU: quyền không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
