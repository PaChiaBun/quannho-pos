-- ============================================================================
-- TRANG QUẢN TRỊ v1 (ke-hoach-trang-quan-tri.md, Chủ Quán duyệt kế hoạch 25/10/2026)
--   • platform_admins       — ai được vào quannho.lpm.vn/admin (chỉ tài khoản Chủ Quán)
--   • admin_test_stores     — quán thử / demo (loại khỏi số liệu)
--   • boom_qa_full          — lịch sử Boom NGUYÊN VĂN (kể cả số); khoá hẳn, chỉ hàm admin_* đọc; tự xoá sau 90 ngày
--   • boom_admin_reviews    — Chủ Quán chấm từng lượt (Đúng / Chưa đúng / Sai, ghi chú, cần dạy lại)
--   • boom_changelog        — nhật ký dạy Boom (nhập sẵn 23/10 → 25/10)
--   • Hàm admin_*_v1        — gọi bằng vé QUẢN TRỊ: vai trò Postgres riêng `qn_admin` (token_use = 'admin', cổng
--                             /api/auth/admin-jwt cấp, sống 4 giờ) + người gọi có trong platform_admins.
--                             Vai trò qn_admin KHÔNG có quyền bảng nào và không phải `authenticated` → vé quản trị lộ ra
--                             cũng không dùng được như phiên đăng nhập quán (QC 26/10); vé bán hàng / vé tạo quán bị từ chối.
-- Không sửa bảng cũ. Số liệu quán chỉ trả số tổng hợp (không doanh thu, không dữ liệu khách của quán).
-- ============================================================================
BEGIN;

-- ĐÃ CÓ v2 (tài khoản quản trị riêng) → KHÔNG chạy lại v1 (sẽ âm thầm trả quản trị về tài khoản quán — QC 26/10)
DO $$
BEGIN
  IF to_regclass('public.platform_admin_accounts') IS NOT NULL THEN
    RAISE EXCEPTION 'v1 đã được thay bằng 20261026_trang_quan_tri_v2_tai_khoan.sql — không chạy lại v1';
  END IF;
END $$;

-- 1) Bảng ------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.platform_admins (
  user_id    uuid PRIMARY KEY REFERENCES public.user_accounts(id) ON DELETE CASCADE,
  note       text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.admin_test_stores (
  store_id   uuid PRIMARY KEY REFERENCES public.stores(id) ON DELETE CASCADE,
  marked_by  uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.boom_qa_full (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  log_id     uuid,                       -- dòng boom_qa_log tương ứng (lượt qua máy chủ); NULL = câu app tự trả
  store_id   uuid NOT NULL,
  user_id    uuid,
  source     text NOT NULL CHECK (source IN ('gpt', 'app')),
  tool       text,                       -- loại câu trả lời (huong_dan_gpt, boom_tu_van_so_lieu_module, …)
  question   text NOT NULL,
  answer     text,
  chunk_ids  text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_boom_qa_full_created ON public.boom_qa_full (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_boom_qa_full_store   ON public.boom_qa_full (store_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_boom_qa_full_user    ON public.boom_qa_full (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_boom_qa_full_log     ON public.boom_qa_full (log_id);

CREATE TABLE IF NOT EXISTS public.boom_admin_reviews (
  qa_id          uuid PRIMARY KEY REFERENCES public.boom_qa_full(id) ON DELETE CASCADE,
  verdict        text CHECK (verdict IN ('dung', 'chua_dung', 'sai')),
  note           text,
  needs_teaching boolean NOT NULL DEFAULT false,
  reviewer       uuid,
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.boom_changelog (
  id         bigserial PRIMARY KEY,
  applied_at timestamptz NOT NULL,
  version    text,
  title      text NOT NULL,
  detail     text,
  checks     text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Khoá hẳn: bật RLS, KHÔNG có chính sách nào → người đăng nhập thường (kể cả chủ / quản lý quán) không đọc / ghi được.
ALTER TABLE public.platform_admins    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_test_stores  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boom_qa_full       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boom_admin_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boom_changelog     ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.platform_admins, public.admin_test_stores, public.boom_qa_full, public.boom_admin_reviews,
              public.boom_changelog FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.boom_changelog_id_seq FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.platform_admins, public.admin_test_stores, public.boom_qa_full, public.boom_admin_reviews,
             public.boom_changelog TO service_role;
GRANT USAGE ON SEQUENCE public.boom_changelog_id_seq TO service_role;

-- 2) Chốt quyền -----------------------------------------------------------------------------------------------
-- Vai trò riêng cho vé quản trị: PostgREST (authenticator) chuyển sang vai trò này theo claim role của vé.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'qn_admin') THEN
    CREATE ROLE qn_admin NOLOGIN NOINHERIT;
  END IF;
END $$;
GRANT qn_admin TO authenticator;
GRANT USAGE ON SCHEMA public TO qn_admin;
ALTER ROLE qn_admin SET statement_timeout = '8s';

-- Người gọi là quản trị: CHỈ tin vé (request.jwt.claims) — không dùng header x-user-id như qn_caller_id; vé phải là
-- vé quản trị (token_use = 'admin') còn hạn, và người đó có trong platform_admins.
CREATE OR REPLACE FUNCTION public.qn_admin_caller()
RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE c jsonb; v text; u uuid;
BEGIN
  BEGIN c := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb; EXCEPTION WHEN OTHERS THEN RETURN NULL; END;
  IF c IS NULL OR c->>'role' IS DISTINCT FROM 'qn_admin' OR c->>'token_use' IS DISTINCT FROM 'admin' THEN RETURN NULL; END IF;
  IF (c->>'exp') IS NULL OR (c->>'exp') !~ '^[0-9]+$' OR (c->>'exp')::bigint <= extract(epoch FROM now())::bigint
     OR (c->>'iat') IS NULL OR (c->>'iat') !~ '^[0-9]+$' OR (c->>'exp')::bigint - (c->>'iat')::bigint > 14400 THEN
    RETURN NULL;
  END IF;
  v := c->>'sub';
  IF v IS NULL OR v !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN RETURN NULL; END IF;
  SELECT p.user_id INTO u FROM public.platform_admins p WHERE p.user_id = v::uuid;
  RETURN u;
END
$fn$;
REVOKE ALL ON FUNCTION public.qn_admin_caller() FROM PUBLIC, anon, authenticated;

-- Cổng đăng nhập (service_role) hỏi: tài khoản này có phải quản trị không (trước khi cấp vé quản trị).
CREATE OR REPLACE FUNCTION public.admin_is_platform_admin_v1(p_user uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$ SELECT EXISTS (SELECT 1 FROM public.platform_admins WHERE user_id = p_user) $fn$;
REVOKE ALL ON FUNCTION public.admin_is_platform_admin_v1(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_is_platform_admin_v1(uuid) TO service_role;

-- 3) Ghi lịch sử Boom nguyên văn (hàm boom-chat gọi bằng service_role) -------------------------------------------
-- Câu app tự trả ('app'): mỗi người tối đa 300 dòng / giờ (chống ghi rác). Tự xoá dòng quá 90 ngày (từng ít một).
CREATE OR REPLACE FUNCTION public.boom_qa_full_write_v1(
  p_log_id uuid, p_store uuid, p_user uuid, p_source text, p_tool text, p_question text, p_answer text, p_chunk_ids text[])
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_id uuid;
BEGIN
  IF p_store IS NULL OR p_source IS NULL OR p_source NOT IN ('gpt', 'app') OR NULLIF(btrim(COALESCE(p_question, '')), '') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'status', 'bad_request');
  END IF;
  -- Mỗi người tối đa 300 dòng / giờ (mọi nguồn) — chống ghi rác, kể cả câu bị từ chối gửi liên tục (QC 26/10)
  IF (SELECT count(*) FROM public.boom_qa_full
       WHERE user_id IS NOT DISTINCT FROM p_user AND created_at > now() - interval '1 hour') >= 300 THEN
    RETURN jsonb_build_object('ok', false, 'status', 'rate_limited');
  END IF;
  INSERT INTO public.boom_qa_full (log_id, store_id, user_id, source, tool, question, answer, chunk_ids)
  VALUES (p_log_id, p_store, p_user, p_source, left(p_tool, 80), left(p_question, 1000), left(p_answer, 8000),
          COALESCE(p_chunk_ids[1:3], '{}'))
  RETURNING id INTO v_id;
  IF random() < 0.05 THEN
    DELETE FROM public.boom_qa_full WHERE id IN (
      SELECT id FROM public.boom_qa_full WHERE created_at < now() - interval '90 days' LIMIT 500);
  END IF;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END
$fn$;
REVOKE ALL ON FUNCTION public.boom_qa_full_write_v1(uuid, uuid, uuid, text, text, text, text, text[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.boom_qa_full_write_v1(uuid, uuid, uuid, text, text, text, text, text[]) TO service_role;

-- 4) Hàm cho trang quản trị --------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_whoami_v1()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  RETURN jsonb_build_object('ok', true, 'user_id', a,
    'name', (SELECT display_name FROM public.user_accounts WHERE id = a));
END
$fn$;

-- Ngày theo giờ Việt Nam
CREATE OR REPLACE FUNCTION public.qn_vn_day(p timestamptz)
RETURNS date LANGUAGE sql STABLE AS $fn$ SELECT (p AT TIME ZONE 'Asia/Ho_Chi_Minh')::date $fn$;
REVOKE ALL ON FUNCTION public.qn_vn_day(timestamptz) FROM PUBLIC, anon, authenticated;

-- Tổng quan quán. "Tích cực" = có đơn hoàn thành trong 7 ngày (Chủ Quán chốt 25/10).
CREATE OR REPLACE FUNCTION public.admin_store_overview_v1(p_include_test boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_today date := public.qn_vn_day(now());
  r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  WITH s AS (
    SELECT st.id, st.created_at,
           EXISTS (SELECT 1 FROM public.admin_test_stores t WHERE t.store_id = st.id) AS is_test
      FROM public.stores st
  ), base AS (
    SELECT s.* FROM s WHERE p_include_test OR NOT s.is_test
  ), act AS (
    SELECT o.store_id, max(o.created_at) AS last_order,
           count(*) FILTER (WHERE o.created_at > now() - interval '7 days') AS o7,
           count(*) FILTER (WHERE o.created_at > now() - interval '30 days') AS o30
      FROM public.orders o
     WHERE o.status = 'completed' AND o.store_id IN (SELECT id FROM base)
     GROUP BY o.store_id
  )
  SELECT jsonb_build_object(
    'ok', true,
    'total', (SELECT count(*) FROM base),
    'test_stores', (SELECT count(*) FROM s WHERE s.is_test),
    'new_today', (SELECT count(*) FROM base WHERE public.qn_vn_day(created_at) = v_today),
    'new_7d', (SELECT count(*) FROM base WHERE created_at > now() - interval '7 days'),
    'new_30d', (SELECT count(*) FROM base WHERE created_at > now() - interval '30 days'),
    'active_7d', (SELECT count(*) FROM act WHERE o7 > 0),
    'active_30d', (SELECT count(*) FROM act WHERE o30 > 0),
    'sleeping', (SELECT count(*) FROM act WHERE o30 = 0),
    'never_sold', (SELECT count(*) FROM base b WHERE NOT EXISTS (SELECT 1 FROM act a WHERE a.store_id = b.id)),
    'new_by_day', (SELECT COALESCE(jsonb_agg(jsonb_build_object('day', d, 'n', n) ORDER BY d), '[]'::jsonb) FROM (
        SELECT g::date AS d, (SELECT count(*) FROM base WHERE public.qn_vn_day(created_at) = g::date) AS n
          FROM generate_series(v_today - 59, v_today, interval '1 day') g) x),
    'active_by_week', (SELECT COALESCE(jsonb_agg(jsonb_build_object('week_start', w, 'n', n) ORDER BY w), '[]'::jsonb) FROM (
        SELECT w::date AS w, (SELECT count(DISTINCT o.store_id) FROM public.orders o
                               WHERE o.status = 'completed' AND o.store_id IN (SELECT id FROM base)
                                 AND public.qn_vn_day(o.created_at) >= w::date
                                 AND public.qn_vn_day(o.created_at) < w::date + 7) AS n
          FROM generate_series(date_trunc('week', v_today::timestamp) - interval '11 weeks',
                               date_trunc('week', v_today::timestamp), interval '1 week') w) y)
  ) INTO r;
  RETURN r;
END
$fn$;

-- Danh sách quán (số tổng hợp, KHÔNG doanh thu). p_filter: all | active | sleeping | never | new7 | test
CREATE OR REPLACE FUNCTION public.admin_store_list_v1(
  p_filter text DEFAULT 'all', p_search text DEFAULT NULL, p_include_test boolean DEFAULT false,
  p_limit int DEFAULT 50, p_offset int DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_lim int := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
  v_off int := GREATEST(COALESCE(p_offset, 0), 0);
  v_q text := NULLIF(btrim(COALESCE(p_search, '')), '');
  r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF COALESCE(p_filter, 'all') NOT IN ('all', 'active', 'sleeping', 'never', 'new7', 'test') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_FILTER');
  END IF;
  WITH rows AS (
    SELECT st.id, st.name, st.store_code, st.plan, st.status, st.trial_ends_at, st.last_active_at, st.created_at,
           (SELECT display_name FROM public.user_accounts u WHERE u.id = st.owner_user_id) AS owner_name,
           EXISTS (SELECT 1 FROM public.admin_test_stores t WHERE t.store_id = st.id) AS is_test,
           (SELECT count(*) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed'
               AND o.created_at > now() - interval '7 days') AS orders_7d,
           (SELECT count(*) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed'
               AND o.created_at > now() - interval '30 days') AS orders_30d,
           (SELECT max(o.created_at) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed') AS last_order_at,
           (SELECT count(*) FROM public.devices d WHERE d.store_id = st.id) AS devices,
           (SELECT max(d.last_seen) FROM public.devices d WHERE d.store_id = st.id) AS device_last_seen,
           -- chủ: thành viên đánh dấu chủ HOẶC chủ ghi trên quán (5 quán thiếu dòng is_owner — QC 26/10)
           (SELECT count(DISTINCT x.u) FROM (
               SELECT m.user_id AS u FROM public.store_members m WHERE m.store_id = st.id AND m.is_owner
               UNION SELECT st.owner_user_id WHERE st.owner_user_id IS NOT NULL) x) AS staff_owner,
           (SELECT count(*) FROM public.store_members m WHERE m.store_id = st.id AND NOT COALESCE(m.is_owner, false)
               AND m.user_id IS DISTINCT FROM st.owner_user_id
               AND lower(COALESCE(m.role, '')) IN ('manager', 'quản lý', 'quan ly')) AS staff_manager,
           (SELECT count(*) FROM public.store_members m WHERE m.store_id = st.id AND NOT COALESCE(m.is_owner, false)
               AND m.user_id IS DISTINCT FROM st.owner_user_id
               AND lower(COALESCE(m.role, '')) NOT IN ('manager', 'quản lý', 'quan ly', 'owner', 'unassigned')) AS staff_other,
           (SELECT count(*) FROM public.products p WHERE p.store_id = st.id AND p.product_type = 'finished'
               AND NOT COALESCE(p.is_deleted, false) AND COALESCE(p.is_active, true)
               AND NOT COALESCE(p.is_raw_material, false)) AS menu_items
      FROM public.stores st
     WHERE (v_q IS NULL OR st.name ILIKE '%' || v_q || '%' OR st.store_code ILIKE '%' || v_q || '%')
  ), f AS (
    SELECT * FROM rows
     WHERE CASE COALESCE(p_filter, 'all')
             WHEN 'test' THEN is_test
             ELSE (p_include_test OR NOT is_test) AND CASE COALESCE(p_filter, 'all')
               WHEN 'active' THEN orders_7d > 0
               WHEN 'sleeping' THEN last_order_at IS NOT NULL AND orders_30d = 0
               WHEN 'never' THEN last_order_at IS NULL
               WHEN 'new7' THEN created_at > now() - interval '7 days'
               ELSE true END
           END
  )
  SELECT jsonb_build_object('ok', true, 'total', (SELECT count(*) FROM f),
    'rows', COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.orders_7d DESC, x.created_at DESC)
                        FROM (SELECT * FROM f ORDER BY orders_7d DESC, created_at DESC LIMIT v_lim OFFSET v_off) x), '[]'::jsonb))
    INTO r;
  RETURN r;
END
$fn$;

CREATE OR REPLACE FUNCTION public.admin_set_test_store_v1(p_store uuid, p_is_test boolean)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.stores WHERE id = p_store) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND');
  END IF;
  IF p_is_test THEN
    INSERT INTO public.admin_test_stores (store_id, marked_by) VALUES (p_store, a) ON CONFLICT (store_id) DO NOTHING;
  ELSE
    DELETE FROM public.admin_test_stores WHERE store_id = p_store;
  END IF;
  RETURN jsonb_build_object('ok', true);
END
$fn$;

-- Lượt hỏi Boom. p_filter: all | down | refused | unanswered | error | unreviewed | teach | wrong
CREATE OR REPLACE FUNCTION public.admin_boom_turns_v1(
  p_store uuid DEFAULT NULL, p_from timestamptz DEFAULT NULL, p_to timestamptz DEFAULT NULL,
  p_filter text DEFAULT 'all', p_search text DEFAULT NULL, p_limit int DEFAULT 50, p_offset int DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_lim int := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
  v_off int := GREATEST(COALESCE(p_offset, 0), 0);
  v_q text := NULLIF(btrim(COALESCE(p_search, '')), '');
  r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF COALESCE(p_filter, 'all') NOT IN ('all', 'down', 'refused', 'unanswered', 'error', 'unreviewed', 'teach', 'wrong') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_FILTER');
  END IF;
  WITH t AS (
    SELECT f.id, f.created_at, f.store_id, f.source, f.tool, f.question, left(f.answer, 400) AS answer_preview,
           length(f.answer) AS answer_len, st.name AS store_name, u.display_name AS user_name,
           l.status AS log_status, l.rating, l.model, rv.verdict, rv.needs_teaching
      FROM public.boom_qa_full f
      LEFT JOIN public.boom_qa_log l ON l.id = f.log_id
      LEFT JOIN public.stores st ON st.id = f.store_id
      LEFT JOIN public.user_accounts u ON u.id = f.user_id
      LEFT JOIN public.boom_admin_reviews rv ON rv.qa_id = f.id
     WHERE (p_store IS NULL OR f.store_id = p_store)
       AND (p_from IS NULL OR f.created_at >= p_from) AND (p_to IS NULL OR f.created_at < p_to)
       AND (v_q IS NULL OR f.question ILIKE '%' || v_q || '%' OR f.answer ILIKE '%' || v_q || '%')
       AND CASE COALESCE(p_filter, 'all')
             WHEN 'down' THEN l.rating = 'down'
             -- nhãn câu app tự trả có tiền tố 'app:' → so trên nhãn đã bỏ tiền tố
             WHEN 'refused' THEN regexp_replace(COALESCE(f.tool, ''), '^app:', '') LIKE 'boom_tu_choi%'
                                 OR regexp_replace(COALESCE(f.tool, ''), '^app:', '') = 'boom_khong_quyen' OR l.status = 'blocked'
             WHEN 'unanswered' THEN regexp_replace(COALESCE(f.tool, ''), '^app:', '') IN ('huong_dan_none', 'huong_dan_suggest')
                                 OR l.status = 'no_context'
             WHEN 'error' THEN l.status = 'error' OR f.tool LIKE '%du_phong%'
             WHEN 'unreviewed' THEN rv.verdict IS NULL
             WHEN 'teach' THEN COALESCE(rv.needs_teaching, false)
             WHEN 'wrong' THEN rv.verdict IN ('sai', 'chua_dung')
             ELSE true END
  )
  SELECT jsonb_build_object('ok', true, 'total', (SELECT count(*) FROM t),
    'rows', COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC)
                        FROM (SELECT * FROM t ORDER BY created_at DESC LIMIT v_lim OFFSET v_off) x), '[]'::jsonb))
    INTO r;
  RETURN r;
END
$fn$;

CREATE OR REPLACE FUNCTION public.admin_boom_turn_v1(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE r jsonb; v_pack jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  SELECT content INTO v_pack FROM public.boom_help_packs ORDER BY version DESC LIMIT 1;
  SELECT jsonb_build_object('ok', true,
    'turn', to_jsonb(f) || jsonb_build_object('store_name', st.name, 'user_name', u.display_name),
    'log', CASE WHEN l.id IS NULL THEN NULL ELSE jsonb_build_object(
             'status', l.status, 'model', l.model, 'rating', l.rating, 'rating_reason', l.rating_reason,
             'input_tokens', l.input_tokens, 'output_tokens', l.output_tokens, 'cost_usd', l.cost_usd,
             'latency_ms', l.latency_ms, 'cache_id', l.cache_id) END,
    'chunks', (SELECT COALESCE(jsonb_agg(jsonb_build_object('id', c->>'id', 'title', c->>'title', 'module', c->>'module_name')), '[]'::jsonb)
                 FROM jsonb_array_elements(COALESCE(v_pack->'chunks', '[]'::jsonb)) c
                WHERE c->>'id' = ANY (f.chunk_ids)),
    'review', (SELECT to_jsonb(rv) FROM public.boom_admin_reviews rv WHERE rv.qa_id = f.id))
    INTO r
    FROM public.boom_qa_full f
    LEFT JOIN public.boom_qa_log l ON l.id = f.log_id
    LEFT JOIN public.stores st ON st.id = f.store_id
    LEFT JOIN public.user_accounts u ON u.id = f.user_id
   WHERE f.id = p_id;
  RETURN COALESCE(r, jsonb_build_object('ok', false, 'error', 'NOT_FOUND'));
END
$fn$;

CREATE OR REPLACE FUNCTION public.admin_boom_review_v1(p_id uuid, p_verdict text, p_note text, p_needs_teaching boolean)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF p_verdict IS NOT NULL AND p_verdict NOT IN ('dung', 'chua_dung', 'sai') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_VERDICT');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.boom_qa_full WHERE id = p_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND');
  END IF;
  INSERT INTO public.boom_admin_reviews (qa_id, verdict, note, needs_teaching, reviewer, updated_at)
  VALUES (p_id, p_verdict, NULLIF(left(btrim(COALESCE(p_note, '')), 2000), ''), COALESCE(p_needs_teaching, false), a, now())
  ON CONFLICT (qa_id) DO UPDATE SET verdict = EXCLUDED.verdict, note = EXCLUDED.note,
    needs_teaching = EXCLUDED.needs_teaching, reviewer = EXCLUDED.reviewer, updated_at = now();
  RETURN jsonb_build_object('ok', true);
END
$fn$;

-- Số đếm Boom trong p_days ngày
CREATE OR REPLACE FUNCTION public.admin_boom_stats_v1(p_days int DEFAULT 7)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_from timestamptz := now() - make_interval(days => LEAST(GREATEST(COALESCE(p_days, 7), 1), 90)); r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  SELECT jsonb_build_object('ok', true,
    'turns', (SELECT count(*) FROM public.boom_qa_full WHERE created_at >= v_from),
    'gpt_turns', (SELECT count(*) FROM public.boom_qa_full WHERE created_at >= v_from AND source = 'gpt'),
    'stores', (SELECT count(DISTINCT store_id) FROM public.boom_qa_full WHERE created_at >= v_from),
    'up', (SELECT count(*) FROM public.boom_qa_log WHERE created_at >= v_from AND rating = 'up'),
    'down', (SELECT count(*) FROM public.boom_qa_log WHERE created_at >= v_from AND rating = 'down'),
    'unanswered', (SELECT count(*) FROM public.boom_qa_log WHERE created_at >= v_from AND status = 'no_context'),
    'blocked', (SELECT count(*) FROM public.boom_qa_log WHERE created_at >= v_from AND status = 'blocked'),
    'errors', (SELECT count(*) FROM public.boom_qa_log WHERE created_at >= v_from AND status = 'error'),
    'cost_usd', (SELECT COALESCE(round(sum(cost_usd)::numeric, 4), 0) FROM public.boom_qa_log WHERE created_at >= v_from),
    'reviewed', (SELECT jsonb_build_object(
                   'dung', count(*) FILTER (WHERE rv.verdict = 'dung'),
                   'chua_dung', count(*) FILTER (WHERE rv.verdict = 'chua_dung'),
                   'sai', count(*) FILTER (WHERE rv.verdict = 'sai'),
                   'teach', count(*) FILTER (WHERE rv.needs_teaching))
                   FROM public.boom_admin_reviews rv JOIN public.boom_qa_full f ON f.id = rv.qa_id
                  WHERE f.created_at >= v_from),
    'by_tool', (SELECT COALESCE(jsonb_object_agg(k, n), '{}'::jsonb) FROM (
                  SELECT COALESCE(NULLIF(split_part(regexp_replace(COALESCE(tool, ''), '^app:', ''), ':', 1), ''), '?') AS k, count(*) AS n
                    FROM public.boom_qa_full WHERE created_at >= v_from GROUP BY 1) x)
  ) INTO r;
  RETURN r;
END
$fn$;

-- Những gì đã dạy Boom: bản hướng dẫn, mức dùng từng đoạn, bộ nhớ câu trả lời đã duyệt, nhật ký dạy
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

CREATE OR REPLACE FUNCTION public.admin_boom_chunk_v1(p_id text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  SELECT jsonb_build_object('ok', true, 'chunk', c) INTO r
    FROM (SELECT content FROM public.boom_help_packs ORDER BY version DESC LIMIT 1) p,
         jsonb_array_elements(COALESCE(p.content->'chunks', '[]'::jsonb)) c
   WHERE c->>'id' = p_id;
  RETURN COALESCE(r, jsonb_build_object('ok', false, 'error', 'NOT_FOUND'));
END
$fn$;

-- Quyền: hàm admin_* CHỈ cho vai trò qn_admin (bên trong còn kiểm vé + danh sách quản trị); người đăng nhập thường,
-- anon không gọi được
REVOKE ALL ON FUNCTION public.admin_whoami_v1(), public.admin_store_overview_v1(boolean),
  public.admin_store_list_v1(text, text, boolean, int, int), public.admin_set_test_store_v1(uuid, boolean),
  public.admin_boom_turns_v1(uuid, timestamptz, timestamptz, text, text, int, int), public.admin_boom_turn_v1(uuid),
  public.admin_boom_review_v1(uuid, text, text, boolean), public.admin_boom_stats_v1(int),
  public.admin_boom_knowledge_v1(), public.admin_boom_chunk_v1(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_whoami_v1(), public.admin_store_overview_v1(boolean),
  public.admin_store_list_v1(text, text, boolean, int, int), public.admin_set_test_store_v1(uuid, boolean),
  public.admin_boom_turns_v1(uuid, timestamptz, timestamptz, text, text, int, int), public.admin_boom_turn_v1(uuid),
  public.admin_boom_review_v1(uuid, text, text, boolean), public.admin_boom_stats_v1(int),
  public.admin_boom_knowledge_v1(), public.admin_boom_chunk_v1(text) TO qn_admin;

-- 5) Nhật ký dạy Boom — nhập sẵn (theo nhat_ky.md, giờ Việt Nam) -----------------------------------------------
INSERT INTO public.boom_changelog (applied_at, version, title, detail, checks)
SELECT * FROM (VALUES
  ('2026-10-23 18:03+07'::timestamptz, 'pack 202610231048', 'Đăng bộ hướng dẫn app cho Boom',
   '331 đoạn hướng dẫn / 16 module (bán hàng, in hoá đơn, QR, bàn, lương, khuyến mãi, nhân viên, kho, chấm công, thu chi, báo cáo, bếp, kho chuyên nghiệp, chuỗi, vận hành, nhật ký).', 'Bộ câu hỏi hướng dẫn kiểm tra tìm đúng đoạn'),
  ('2026-10-24 00:36+07', 'boom-chat v1', 'Boom AI v1 — GPT trả lời theo hướng dẫn',
   'GPT (gpt-4o-mini) diễn đạt lại đoạn hướng dẫn đã duyệt; sổ hỏi đáp; hạn mức theo người / quán; 👍/👎.', 'Test máy chủ 24/24 PASS'),
  ('2026-10-24 01:40+07', 'v2 luật', 'Luật phạm vi trả lời',
   'Được: cách dùng app, bán hàng, khách, báo cáo, vận hành. Cấm: chính trị, tôn giáo, lập trình, nội dung xấu.', 'Test luật PASS'),
  ('2026-10-24 02:41+07', 'v3 bộ nhớ', 'Bộ nhớ câu trả lời đã duyệt',
   'Câu trả lời hay được duyệt vào bộ nhớ dùng chung, trả ngay không tốn GPT.', 'Test bộ nhớ PASS'),
  ('2026-10-24 03:36+07', 'v4 chấm điểm', 'Chấm 👍/👎 cả câu không gọi GPT', 'Ghi phiếu chấm cho câu số liệu / hướng dẫn nguyên văn.', 'Test PASS'),
  ('2026-10-24 05:55+07', 'v5 xưng hô', 'Gọi đúng Anh / Chị', 'Boom hỏi một lần Anh hay Chị, lưu theo tài khoản.', 'Test PASS'),
  ('2026-10-24 09:39+07', 'cố vấn', 'Boom làm cố vấn kinh doanh',
   'Tư vấn định giá, khuyến mãi, nhân viên, dòng tiền, vận hành; khối kiến thức nghề (luật lao động, an toàn thực phẩm…).', 'Bộ 39 câu cố vấn, chấm mù'),
  ('2026-10-24 21:20+07', 'trí nhớ 5 giờ', 'Nhớ 4 lượt gần nhất trong 5 giờ', 'Máy chủ tự lấy từ sổ hỏi đáp, ~500 token.', '45 câu giữ riêng + nhiều lượt'),
  ('2026-10-24 21:40+07', 'số liệu', 'Phân tích trên số liệu thật của quán',
   'Xin báo cáo / phân tích → Boom đọc doanh thu, món theo nhóm, giờ, thứ rồi phân tích.', 'Test + GPT thật'),
  ('2026-10-24 22:50+07', 'gỡ luật chặt', 'Gỡ luật quá chặt', 'Hỏi "có giúp gì cho quán không" trước khi từ chối; từ chối sai 21 → 1.', '100 câu, chấm 2,61 → 3,60'),
  ('2026-10-24 23:07+07', 'tự đọc số', 'Không bắt chủ quán tự đọc báo cáo', 'Câu nói tiếp "chi tiết hơn" vẫn kèm số liệu.', 'Test PASS'),
  ('2026-10-25 17:16+07', 'chuỗi', 'So sánh chi nhánh bằng số thật', 'Đọc báo cáo chuỗi (chỉ chủ chuỗi): tỷ trọng, % so kỳ trước, cuối tuần, chi nhánh yếu.', '12 câu GPT thật + QC 3 vòng'),
  ('2026-10-25 19:42+07', 'đọc 5 mục', 'Đọc số Thu Chi, Kho, Chấm công/Lương, Khách, Khuyến mãi',
   'CHỈ ĐỌC, theo quyền từng vai trò như app; áp quyền cho cả số bán hàng.', '15 câu GPT thật + QC 3 vòng; 933 test app')
) v(applied_at, version, title, detail, checks)
WHERE NOT EXISTS (SELECT 1 FROM public.boom_changelog);

-- 6) Quản trị viên đầu tiên: tài khoản Chủ Quán (đặt khi áp, xem db-fix/trang_quan_tri_ap_dung.sh)
--    INSERT INTO public.platform_admins (user_id, note) VALUES ('<uuid>', 'Chủ Quán');

-- 7) Kiểm tra sau áp
DO $$
BEGIN
  IF has_table_privilege('authenticated', 'public.boom_qa_full', 'select')
     OR has_table_privilege('authenticated', 'public.platform_admins', 'select')
     OR has_function_privilege('anon', 'public.admin_store_list_v1(text,text,boolean,int,int)', 'execute')
     OR has_function_privilege('authenticated', 'public.admin_store_list_v1(text,text,boolean,int,int)', 'execute')
     OR has_table_privilege('qn_admin', 'public.stores', 'select')
     OR has_table_privilege('qn_admin', 'public.boom_qa_full', 'select')
     OR has_function_privilege('authenticated', 'public.boom_qa_full_write_v1(uuid,uuid,uuid,text,text,text,text,text[])', 'execute') THEN
    RAISE EXCEPTION 'TRANG QUAN TRI v1: quyền không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
