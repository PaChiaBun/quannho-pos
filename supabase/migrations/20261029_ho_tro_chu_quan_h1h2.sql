-- ============================================================================
-- HỖ TRỢ CHỦ QUÁN — ĐỢT H1 + H2 (ke-hoach-ho-tro-chu-quan.md, Chủ Quán chốt 26/10/2026)
-- H1 • bảng bug_reports — app ĐANG GHI vào bảng này ("Gửi phản hồi") nhưng production chưa từng có → mọi phản hồi mất.
--      Tạo đúng tên + cột app gửi để các bản app đã cài chạy được ngay (không cần phát hành).
--      Chỉ người đăng nhập (authenticated) được THÊM, không ai đọc thẳng; trigger chặn spam + đóng dấu người gửi thật.
--    • quản trị: admin_support_list_v1, admin_support_update_v1
-- H2 • quản trị tra tài khoản theo SĐT / tên, cấp MẬT KHẨU TẠM (máy tạo, hiện 1 lần — chủ quán đăng nhập rồi tự đổi),
--      xoá PIN nhanh; bắt buộc xác minh 3 bước + lý do; mọi thao tác ghi support_actions (không lưu mật khẩu).
-- Phần app (chủ quán đặt lại mật khẩu nhân viên — H3) làm sau. Hoàn tác: …_ROLLBACK.sql
-- ============================================================================
BEGIN;

DO $$
BEGIN
  IF to_regprocedure('public.qn_admin_caller()') IS NULL THEN RAISE EXCEPTION 'Cần trang quản trị v2 trước'; END IF;
  IF to_regclass('public.bug_reports') IS NOT NULL THEN RAISE EXCEPTION 'bug_reports đã tồn tại — kiểm tay trước khi áp'; END IF;
END $$;

-- 1) H1: bug_reports (khớp bug_reporter_service.dart: user_id / store_id là CHỮ — app gửi '' khi không có) ---------
CREATE TABLE public.bug_reports (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        text,
  store_id       text,
  description    text NOT NULL,
  screenshot_url text,
  device_info    jsonb,
  screen_name    text,
  status         text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'done')),
  kind           text NOT NULL DEFAULT 'bug' CHECK (kind IN ('bug', 'forgot_password', 'other')),
  verified_user  uuid,          -- người gửi thật (theo vé đăng nhập), máy chủ đóng dấu
  verified_store uuid,          -- quán thật nếu người gửi là thành viên
  admin_note     text,
  handled_by     uuid,
  handled_at     timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_bug_reports_status ON public.bug_reports (status, created_at DESC);
CREATE INDEX idx_bug_reports_user ON public.bug_reports (verified_user, created_at DESC);

ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.bug_reports FROM PUBLIC, anon, authenticated, qn_admin;
GRANT INSERT ON public.bug_reports TO authenticated;     -- chỉ thêm; không đọc / sửa / xoá
GRANT ALL ON public.bug_reports TO service_role;
CREATE POLICY bug_reports_insert_v1 ON public.bug_reports FOR INSERT TO authenticated WITH CHECK (true);

-- Trước khi thêm: đóng dấu người / quán thật, ép trạng thái 'open', cắt độ dài, đoán loại, chặn spam.
-- SECURITY DEFINER (cần đếm / đọc bảng mà người gửi không có quyền) → nhận biết người gửi bằng vé đăng nhập (claims),
-- không dùng current_user. Câu lệnh không mang vé authenticated (service_role, quản trị DB) → để nguyên.
CREATE OR REPLACE FUNCTION public.qn_bug_reports_before_insert()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE u uuid; v_store uuid; n int; v_desc text; v_role text;
BEGIN
  BEGIN v_role := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role'; EXCEPTION WHEN OTHERS THEN v_role := NULL; END;
  IF v_role IS DISTINCT FROM 'authenticated' THEN
    IF current_setting('role', true) IN ('authenticated', 'anon') THEN
      RAISE EXCEPTION 'Cần đăng nhập để gửi phản hồi' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;
  u := public.qn_caller_id();
  -- người gửi phải là tài khoản thật của app (vé có `sub` lạ → từ chối; QC 29/10)
  IF u IS NULL OR NOT EXISTS (SELECT 1 FROM public.user_accounts WHERE id = u) THEN
    RAISE EXCEPTION 'Cần đăng nhập để gửi phản hồi' USING ERRCODE = '42501';
  END IF;
  -- tối đa 10 phản hồi / giờ / người; khoá theo người để nhiều yêu cầu song song không lọt quá giới hạn
  PERFORM pg_advisory_xact_lock(hashtext('bug_reports:' || u::text));
  SELECT count(*) INTO n FROM public.bug_reports WHERE verified_user = u AND created_at > now() - interval '1 hour';
  IF n >= 10 THEN RAISE EXCEPTION 'Gửi quá nhiều phản hồi, vui lòng thử lại sau' USING ERRCODE = '54000'; END IF;
  v_desc := left(btrim(COALESCE(NEW.description, '')), 4000);
  IF v_desc = '' THEN RAISE EXCEPTION 'Nội dung trống' USING ERRCODE = '22023'; END IF;
  BEGIN v_store := NULLIF(NEW.store_id, '')::uuid; EXCEPTION WHEN OTHERS THEN v_store := NULL; END;
  IF v_store IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM public.store_members m WHERE m.store_id = v_store AND m.user_id = u
       UNION ALL SELECT 1 FROM public.stores s WHERE s.id = v_store AND s.owner_user_id = u) THEN
    v_store := NULL;
  END IF;
  NEW.id := gen_random_uuid();
  NEW.description := v_desc;
  NEW.user_id := left(COALESCE(NEW.user_id, ''), 64);
  NEW.store_id := left(COALESCE(NEW.store_id, ''), 64);
  NEW.screen_name := left(NEW.screen_name, 200);
  NEW.screenshot_url := left(NEW.screenshot_url, 500);
  IF NEW.device_info IS NOT NULL AND pg_column_size(NEW.device_info) > 20000 THEN NEW.device_info := NULL; END IF;
  NEW.status := 'open';
  NEW.kind := CASE WHEN lower(v_desc) ~ '(quên|quen|lấy lại|cấp lại|đặt lại|reset).{0,20}(mật khẩu|mat khau|pass|pin)'
                     OR lower(v_desc) ~ '(mật khẩu|mat khau|password).{0,20}(quên|quen)' THEN 'forgot_password' ELSE 'bug' END;
  NEW.verified_user := u;
  NEW.verified_store := v_store;
  NEW.admin_note := NULL; NEW.handled_by := NULL; NEW.handled_at := NULL;
  NEW.created_at := now(); NEW.updated_at := now();
  RETURN NEW;
END
$fn$;
REVOKE ALL ON FUNCTION public.qn_bug_reports_before_insert() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER qn_bug_reports_before_insert BEFORE INSERT ON public.bug_reports
  FOR EACH ROW EXECUTE FUNCTION public.qn_bug_reports_before_insert();

-- 2) Nhật ký hỗ trợ (H2) ------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.support_actions (
  id          bigserial PRIMARY KEY,
  admin_id    uuid,                       -- tài khoản quản trị (platform_admin_accounts)
  target_user uuid NOT NULL,              -- user_accounts.id bị tác động
  action      text NOT NULL CHECK (action IN ('temp_password', 'clear_quick_pin')),
  reason      text NOT NULL,
  checks      jsonb,                      -- các bước xác minh đã tick
  report_id   uuid,                       -- phản hồi liên quan (nếu xử lý từ hàng yêu cầu)
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_support_actions_user ON public.support_actions (target_user, created_at DESC);
ALTER TABLE public.support_actions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.support_actions FROM PUBLIC, anon, authenticated, qn_admin;
REVOKE ALL ON SEQUENCE public.support_actions_id_seq FROM PUBLIC, anon, authenticated, qn_admin;
GRANT ALL ON public.support_actions TO service_role;

-- 3) Quản trị: hàng yêu cầu hỗ trợ -----------------------------------------------------------------------------------
-- p_status: open | in_progress | done | all ; p_kind: all | bug | forgot_password | other
CREATE OR REPLACE FUNCTION public.admin_support_list_v1(p_status text DEFAULT 'open', p_kind text DEFAULT 'all',
                                                       p_limit int DEFAULT 50, p_offset int DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_lim int := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200); v_off int := GREATEST(COALESCE(p_offset, 0), 0);
        v_s text := COALESCE(p_status, 'open'); v_k text := COALESCE(p_kind, 'all'); r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF v_s NOT IN ('open', 'in_progress', 'done', 'all') OR v_k NOT IN ('all', 'bug', 'forgot_password', 'other') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_FILTER');
  END IF;
  WITH f AS (
    SELECT b.*, u.display_name AS user_name, u.phone AS user_phone, st.name AS store_name, st.store_code
      FROM public.bug_reports b
      LEFT JOIN public.user_accounts u ON u.id = b.verified_user
      LEFT JOIN public.stores st ON st.id = b.verified_store
     WHERE (v_s = 'all' OR b.status = v_s) AND (v_k = 'all' OR b.kind = v_k)
  )
  SELECT jsonb_build_object('ok', true,
    'counts', (SELECT jsonb_object_agg(status, n) FROM (SELECT status, count(*) AS n FROM public.bug_reports GROUP BY status) c),
    'total', (SELECT count(*) FROM f),
    'rows', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', x.id, 'kind', x.kind, 'status', x.status,
                 'description', x.description, 'screen_name', x.screen_name, 'created_at', x.created_at,
                 'app_version', x.device_info->>'app_version', 'os', x.device_info->>'os',
                 'user_id', x.verified_user, 'user_name', x.user_name, 'user_phone', x.user_phone,
                 'store_id', x.verified_store, 'store_name', x.store_name, 'store_code', x.store_code,
                 'admin_note', x.admin_note, 'handled_at', x.handled_at) ORDER BY x.created_at DESC)
               FROM (SELECT * FROM f ORDER BY created_at DESC LIMIT v_lim OFFSET v_off) x), '[]'::jsonb))
  INTO r;
  RETURN r;
END
$fn$;

CREATE OR REPLACE FUNCTION public.admin_support_update_v1(p_id uuid, p_status text, p_note text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF p_status NOT IN ('open', 'in_progress', 'done') THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_STATUS'); END IF;
  IF char_length(COALESCE(p_note, '')) > 1000 THEN RETURN jsonb_build_object('ok', false, 'error', 'NOTE_TOO_LONG'); END IF;
  UPDATE public.bug_reports
     SET status = p_status, admin_note = COALESCE(NULLIF(btrim(COALESCE(p_note, '')), ''), admin_note),
         handled_by = a, handled_at = CASE WHEN p_status = 'done' THEN now() ELSE handled_at END, updated_at = now()
   WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND'); END IF;
  RETURN jsonb_build_object('ok', true);
END
$fn$;

-- 4) Quản trị: tra tài khoản (SĐT — chuẩn hoá 0 / 84 / +84 — hoặc tên) --------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_account_search_v1(p_q text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE v_q text := btrim(COALESCE(p_q, '')); v_digits text; v_last9 text;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF char_length(v_q) < 3 THEN RETURN jsonb_build_object('ok', false, 'error', 'QUERY_TOO_SHORT'); END IF;
  v_digits := regexp_replace(v_q, '\D', '', 'g');
  v_last9 := CASE WHEN char_length(v_digits) >= 9 THEN right(v_digits, 9) END;
  RETURN jsonb_build_object('ok', true, 'rows', COALESCE((SELECT jsonb_agg(public.qn_admin_account_json(u.id) ORDER BY u.created_at DESC)
    FROM (SELECT * FROM public.user_accounts u
           WHERE (v_last9 IS NOT NULL AND right(regexp_replace(u.phone, '\D', '', 'g'), 9) = v_last9)
              OR (v_last9 IS NULL AND char_length(v_digits) >= 3 AND regexp_replace(u.phone, '\D', '', 'g') LIKE '%' || v_digits || '%')
              OR (u.display_name ILIKE '%' || v_q || '%')
           ORDER BY u.created_at DESC LIMIT 30) u), '[]'::jsonb));
END
$fn$;

-- Thông tin 1 tài khoản cho trang hỗ trợ (KHÔNG trả mật khẩu / PIN — chỉ cho biết có hay không, kiểu lưu)
CREATE OR REPLACE FUNCTION public.qn_admin_account_json(p_user uuid)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
  SELECT jsonb_build_object('id', u.id, 'name', u.display_name, 'phone', u.phone, 'created_at', u.created_at,
    'has_quick_pin', u.quick_pin IS NOT NULL AND u.quick_pin <> '',
    'password_kind', CASE WHEN COALESCE(u.password_hash, '') = '' THEN 'none'
                          WHEN u.password_hash ~ '^\$2[aby]\$' THEN 'bcrypt' ELSE 'legacy' END,
    'last_login', (SELECT max(t.created_at) FROM public.pos_refresh_tokens t WHERE t.user_id = u.id),
    'stores', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'code', s.store_code, 'role', x.role,
                                                            'is_owner', x.is_owner, 'status', s.status) ORDER BY s.name)
              FROM (SELECT m.store_id, m.role, COALESCE(m.is_owner, false) OR st.owner_user_id = m.user_id AS is_owner
                      FROM public.store_members m JOIN public.stores st ON st.id = m.store_id WHERE m.user_id = u.id
                    UNION
                    SELECT st.id, 'owner', true FROM public.stores st WHERE st.owner_user_id = u.id
                      AND NOT EXISTS (SELECT 1 FROM public.store_members m WHERE m.store_id = st.id AND m.user_id = u.id)) x
              JOIN public.stores s ON s.id = x.store_id), '[]'::jsonb),
    'support', COALESCE((SELECT jsonb_agg(jsonb_build_object('action', a.action, 'reason', a.reason, 'created_at', a.created_at,
                                                             'admin', pa.display_name) ORDER BY a.created_at DESC)
              FROM (SELECT * FROM public.support_actions sa WHERE sa.target_user = u.id ORDER BY sa.created_at DESC LIMIT 10) a
              LEFT JOIN public.platform_admin_accounts pa ON pa.id = a.admin_id), '[]'::jsonb))
    FROM public.user_accounts u WHERE u.id = p_user
$fn$;
REVOKE ALL ON FUNCTION public.qn_admin_account_json(uuid) FROM PUBLIC, anon, authenticated, qn_admin;

-- 5) Quản trị: cấp mật khẩu tạm / xoá PIN nhanh ---------------------------------------------------------------------
-- Bắt buộc: lý do ≥ 5 ký tự + đủ 3 bước xác minh (p_checks = {"callback":true,"store_info":true,"secret":true}).
-- Mật khẩu tạm 10 ký tự, dễ đọc qua điện thoại (bỏ 0/O/1/I/L), trả về MỘT LẦN, lưu dạng bcrypt — không lưu nguyên văn ở đâu.
-- Trigger có sẵn thu hồi vé làm mới (refresh token) khi đổi mật khẩu. Tối đa 20 lần / giờ / quản trị.
CREATE OR REPLACE FUNCTION public.admin_account_reset_password_v1(p_user uuid, p_reason text, p_checks jsonb,
                                                                 p_report uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller(); v_reason text := btrim(COALESCE(p_reason, '')); v_pw text := ''; i int;
        v_alpha text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF char_length(v_reason) < 5 OR char_length(v_reason) > 500 THEN RETURN jsonb_build_object('ok', false, 'error', 'REASON_REQUIRED'); END IF;
  IF p_checks IS NULL OR (p_checks->>'callback') IS DISTINCT FROM 'true' OR (p_checks->>'store_info') IS DISTINCT FROM 'true'
     OR (p_checks->>'secret') IS DISTINCT FROM 'true' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'CHECKS_REQUIRED');
  END IF;
  IF (SELECT count(*) FROM public.support_actions WHERE admin_id = a AND created_at > now() - interval '1 hour') >= 20 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'TOO_MANY');
  END IF;
  PERFORM 1 FROM public.user_accounts WHERE id = p_user FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND'); END IF;
  FOR i IN 1..10 LOOP
    v_pw := v_pw || substr(v_alpha, 1 + (get_byte(gen_random_bytes(1), 0) % length(v_alpha)), 1);
  END LOOP;
  UPDATE public.user_accounts SET password_hash = crypt(v_pw, gen_salt('bf', 12)) WHERE id = p_user;
  -- thu hồi vé làm mới cho MỌI kiểu mật khẩu cũ (trigger sẵn có chỉ chạy khi mật khẩu cũ là bcrypt — QC 29/10).
  -- Giới hạn còn lại: vé đang dùng (access token) sống tới 30 ngày, chưa bị đá ngay.
  UPDATE public.pos_refresh_tokens SET revoked_at = now(), revoke_reason = 'admin_temp_password'
   WHERE user_id = p_user AND revoked_at IS NULL;
  INSERT INTO public.support_actions (admin_id, target_user, action, reason, checks, report_id)
  VALUES (a, p_user, 'temp_password', v_reason, p_checks, p_report);
  RETURN jsonb_build_object('ok', true, 'temp_password', v_pw);
END
$fn$;

CREATE OR REPLACE FUNCTION public.admin_account_clear_pin_v1(p_user uuid, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller(); v_reason text := btrim(COALESCE(p_reason, ''));
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF char_length(v_reason) < 5 OR char_length(v_reason) > 500 THEN RETURN jsonb_build_object('ok', false, 'error', 'REASON_REQUIRED'); END IF;
  UPDATE public.user_accounts SET quick_pin = NULL WHERE id = p_user;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND'); END IF;
  INSERT INTO public.support_actions (admin_id, target_user, action, reason) VALUES (a, p_user, 'clear_quick_pin', v_reason);
  RETURN jsonb_build_object('ok', true);
END
$fn$;

CREATE OR REPLACE FUNCTION public.admin_account_detail_v1(p_user uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  r := public.qn_admin_account_json(p_user);
  IF r IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND'); END IF;
  RETURN jsonb_build_object('ok', true, 'account', r);
END
$fn$;

-- 6) Quyền ----------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.admin_support_list_v1(text, text, int, int), public.admin_support_update_v1(uuid, text, text),
  public.admin_account_search_v1(text), public.admin_account_detail_v1(uuid),
  public.admin_account_reset_password_v1(uuid, text, jsonb, uuid), public.admin_account_clear_pin_v1(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_support_list_v1(text, text, int, int), public.admin_support_update_v1(uuid, text, text),
  public.admin_account_search_v1(text), public.admin_account_detail_v1(uuid),
  public.admin_account_reset_password_v1(uuid, text, jsonb, uuid), public.admin_account_clear_pin_v1(uuid, text)
  TO qn_admin;

DO $$
BEGIN
  IF has_table_privilege('authenticated', 'public.bug_reports', 'select')
     OR has_table_privilege('anon', 'public.bug_reports', 'insert')
     OR NOT has_table_privilege('authenticated', 'public.bug_reports', 'insert')
     OR has_table_privilege('qn_admin', 'public.bug_reports', 'select')
     OR has_table_privilege('authenticated', 'public.support_actions', 'select')
     OR has_function_privilege('authenticated', 'public.admin_account_reset_password_v1(uuid,text,jsonb,uuid)', 'execute')
     OR has_function_privilege('qn_admin', 'public.qn_admin_account_json(uuid)', 'execute') THEN
    RAISE EXCEPTION 'HO TRO H1H2: quyền không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
