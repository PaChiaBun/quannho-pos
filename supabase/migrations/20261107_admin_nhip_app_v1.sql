-- ============================================================================
-- /admin THEO DÕI TĂNG TRƯỞNG — ĐỢT 2 (ke-hoach-admin-tang-truong-dot2.md): nhịp app, phiên bản, lỗi toàn hệ thống, nguồn khách
--   • app_device_days               — mỗi máy mỗi ngày mỗi quán 1 dòng. KHÔNG lưu IP, tên, số điện thoại. Khoá hẳn, không ai đọc thẳng.
--   • app_heartbeat_v1              — app báo nhịp (vé quán thật, thành viên quán)
--   • stores.signup_source          — quán mới biết Quán Nhỏ từ đâu (không bắt buộc)
--   • store_signup_source_set_v1    — chủ quán ghi 1 lần sau khi tạo quán; KHÔNG đổi create_store_with_owner_v4
--   • admin_app_health_v1           — chỉ vé quản trị, chỉ đọc
-- shortcut: chưa dọn dòng cũ của app_device_days (ước tính < 100.000 dòng/năm); quá 1 triệu dòng thì thêm lịch dọn.
-- shortcut: thành viên quán vẫn UPDATE thẳng được stores.signup_source qua chính sách cũ; số thống kê, không có giá trị tiền.
-- Hoàn tác: …_ROLLBACK.sql
-- ============================================================================
BEGIN;
SET LOCAL lock_timeout = '5s';  -- ALTER TABLE stores: không xếp hàng chặn cả quán nếu đang có giao dịch dài

DO $$
BEGIN
  IF to_regprocedure('public.qn_admin_caller()') IS NULL OR to_regprocedure('public.qn_is_member(uuid)') IS NULL
     OR to_regprocedure('public.qn_billing_owner(uuid)') IS NULL OR to_regprocedure('public.qn_vn_day(timestamptz)') IS NULL
     OR to_regclass('public.admin_test_stores') IS NULL OR to_regclass('public.app_versions') IS NULL THEN
    RAISE EXCEPTION 'Cần áp trang quản trị đợt 1 và thu phí đợt A trước';
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.app_device_days (
  day         date NOT NULL,
  store_id    uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  device_id   text NOT NULL,
  platform    text NOT NULL CHECK (platform IN ('web', 'android', 'ios', 'windows', 'macos', 'linux')),
  app_version text NOT NULL,
  build       int  NOT NULL,
  last_seen   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (day, store_id, device_id)
);
ALTER TABLE public.app_device_days ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_device_days FROM PUBLIC, anon, authenticated, qn_admin;

ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS signup_source text
  CHECK (signup_source IS NULL OR signup_source IN ('friend', 'facebook', 'google', 'sales', 'other'));

CREATE OR REPLACE FUNCTION public.app_heartbeat_v1(p_store uuid, p_device text, p_platform text, p_version text, p_build int)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_day date := public.qn_vn_day(now());
BEGIN
  -- Bắt buộc vé thật: qn_caller_id còn tin header x-user-id khi không có vé
  IF NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role' IS DISTINCT FROM 'authenticated'
     OR NOT COALESCE(public.qn_is_member(p_store), false) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN');
  END IF;
  IF p_device IS NULL OR p_device !~ '^[A-Za-z0-9_.:-]{1,64}$'
     OR p_platform IS NULL OR p_platform NOT IN ('web', 'android', 'ios', 'windows', 'macos', 'linux')
     OR p_version IS NULL OR p_version !~ '^[0-9A-Za-z.+-]{1,20}$'
     OR p_build IS NULL OR p_build NOT BETWEEN 0 AND 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_PARAMS');
  END IF;
  -- Chặn ghi rác bằng mã máy tự chế: một quán thật không có quá 50 máy trong một ngày
  IF NOT EXISTS (SELECT 1 FROM public.app_device_days d WHERE d.day = v_day AND d.store_id = p_store AND d.device_id = p_device)
     AND (SELECT count(*) FROM public.app_device_days d WHERE d.day = v_day AND d.store_id = p_store) >= 50 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'TOO_MANY_DEVICES');
  END IF;
  INSERT INTO public.app_device_days (day, store_id, device_id, platform, app_version, build)
  VALUES (v_day, p_store, p_device, p_platform, p_version, p_build)
  ON CONFLICT (day, store_id, device_id) DO UPDATE
    SET platform = EXCLUDED.platform, app_version = EXCLUDED.app_version, build = EXCLUDED.build, last_seen = now();
  RETURN jsonb_build_object('ok', true);
END
$fn$;

CREATE OR REPLACE FUNCTION public.store_signup_source_set_v1(p_store uuid, p_source text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF public.qn_billing_owner(p_store) IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'OWNER_ONLY'); END IF;
  IF p_source IS NULL OR p_source NOT IN ('friend', 'facebook', 'google', 'sales', 'other') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_SOURCE');
  END IF;
  UPDATE public.stores SET signup_source = p_source WHERE id = p_store AND signup_source IS NULL;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'ALREADY_SET'); END IF;
  RETURN jsonb_build_object('ok', true);
END
$fn$;

CREATE OR REPLACE FUNCTION public.admin_app_health_v1(p_include_test boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_today date := public.qn_vn_day(now()); r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  WITH base AS (
    SELECT st.id, st.created_at, st.signup_source FROM public.stores st
     WHERE p_include_test OR NOT EXISTS (SELECT 1 FROM public.admin_test_stores t WHERE t.store_id = st.id)
  ), seen AS (
    SELECT d.* FROM public.app_device_days d JOIN base b ON b.id = d.store_id WHERE d.day > v_today - 30
  ), latest AS (  -- 7 ngày: mỗi máy chỉ tính phiên bản gần nhất, máy đã cập nhật không bị đếm hai lần
    SELECT DISTINCT ON (device_id) * FROM seen WHERE day > v_today - 7 ORDER BY device_id, day DESC, last_seen DESC
  ), selling AS (
    SELECT DISTINCT o.store_id FROM public.orders o JOIN base b ON b.id = o.store_id
     WHERE o.status = 'completed' AND o.created_at > now() - interval '7 days'
  ), err AS (
    SELECT l.store_id, l.tag, l.message, l.created_at FROM public.app_logs l JOIN base b ON b.id = l.store_id
     WHERE l.level = 'ERROR' AND l.created_at > now() - interval '14 days'
  )
  SELECT jsonb_build_object('ok', true,
    'days', (SELECT jsonb_agg(jsonb_build_object('day', g::date, 'devices', COALESCE(x.devices, 0), 'stores', COALESCE(x.stores, 0)) ORDER BY g)
               FROM generate_series(v_today - 29, v_today, interval '1 day') g
               LEFT JOIN (SELECT day, count(DISTINCT device_id) AS devices, count(DISTINCT store_id) AS stores FROM seen GROUP BY 1) x ON x.day = g::date),
    'versions', COALESCE((SELECT jsonb_agg(v ORDER BY v.platform, v.build DESC, v.app_version) FROM (
        -- Mới nhất = từ bản đã công bố trong app_versions trở lên; nền tảng chưa có dòng (web) thì lấy bản cao nhất đang chạy.
        -- Số quán: mọi quán máy đó đã mở trong 7 ngày (chủ nhiều chi nhánh dùng chung điện thoại).
        SELECT l.platform, l.app_version, l.build, count(DISTINCT l.device_id) AS devices, count(DISTINCT s.store_id) AS stores,
               l.build >= COALESCE((SELECT max(a.build_number) FROM public.app_versions a WHERE a.platform = l.platform),
                                   max(l.build) OVER (PARTITION BY l.platform)) AS is_latest
          FROM latest l JOIN seen s ON s.device_id = l.device_id AND s.day > v_today - 7
         GROUP BY l.platform, l.app_version, l.build) v), '[]'::jsonb),
    'coverage', jsonb_build_object(
      'selling_7d', (SELECT count(*) FROM selling),
      'silent_7d', (SELECT count(*) FROM selling s WHERE NOT EXISTS (SELECT 1 FROM seen d WHERE d.store_id = s.store_id AND d.day > v_today - 7))),
    'errors', jsonb_build_object(
      'n_7d', (SELECT count(*) FROM err WHERE created_at > now() - interval '7 days'),
      'n_prev7', (SELECT count(*) FROM err WHERE created_at <= now() - interval '7 days'),
      'stores_7d', (SELECT count(DISTINCT store_id) FROM err WHERE created_at > now() - interval '7 days'),
      'uncaught_7d', (SELECT count(*) FROM err WHERE tag = 'uncaught' AND created_at > now() - interval '7 days'),
      'top', COALESCE((SELECT jsonb_agg(t ORDER BY t.n DESC, t.tag) FROM (
          SELECT COALESCE(tag, '(không nhãn)') AS tag, count(*) AS n, count(DISTINCT store_id) AS stores, max(created_at) AS last_at,
                 -- che dãy số dài: lỗi mạng có thể mang số điện thoại khách trong URL
                 regexp_replace(left((array_agg(message ORDER BY created_at DESC))[1], 160), '[0-9]{9,}', '***', 'g') AS sample
            FROM err WHERE created_at > now() - interval '7 days'
           GROUP BY 1 ORDER BY count(*) DESC, 1 LIMIT 10) t), '[]'::jsonb)),
    'sources', COALESCE((SELECT jsonb_agg(s ORDER BY s.n DESC, s.source) FROM (
        SELECT COALESCE(signup_source, 'unknown') AS source, count(*) AS n
          FROM base WHERE created_at > now() - interval '90 days' GROUP BY 1) s), '[]'::jsonb)
  ) INTO r;
  RETURN r;
END
$fn$;

REVOKE ALL ON FUNCTION public.app_heartbeat_v1(uuid, text, text, text, int) FROM PUBLIC, anon, authenticated, service_role, qn_admin;
REVOKE ALL ON FUNCTION public.store_signup_source_set_v1(uuid, text) FROM PUBLIC, anon, authenticated, service_role, qn_admin;
REVOKE ALL ON FUNCTION public.admin_app_health_v1(boolean) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.app_heartbeat_v1(uuid, text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.store_signup_source_set_v1(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_app_health_v1(boolean) TO qn_admin;

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.app_heartbeat_v1(uuid,text,text,text,int)', 'execute')
     OR has_function_privilege('anon', 'public.store_signup_source_set_v1(uuid,text)', 'execute')
     OR has_function_privilege('anon', 'public.admin_app_health_v1(boolean)', 'execute')
     OR has_function_privilege('authenticated', 'public.admin_app_health_v1(boolean)', 'execute')
     OR has_table_privilege('authenticated', 'public.app_device_days', 'select')
     OR has_table_privilege('qn_admin', 'public.app_device_days', 'select')
     OR NOT has_function_privilege('qn_admin', 'public.admin_app_health_v1(boolean)', 'execute') THEN
    RAISE EXCEPTION 'NHIP APP: quyền không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
