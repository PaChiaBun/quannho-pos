-- ============================================================================
-- ĐỔI TÊN AN TOÀN (Chủ Quán 26/10: "tại sao vẫn không đổi tên Chủ Quán được cũng như tên nhân viên")
-- Nguyên nhân: app gọi update_my_display_name_v4 nhưng 20261015_doi_ten_hien_thi_v4.sql CHƯA TỪNG áp; bản đó còn cấp
-- cho anon + dựa qn_caller_id() (tin header x-user-id khi không có vé) → ai chưa đăng nhập cũng đổi được tên người khác.
-- File này THAY bản 15/10 (KHÔNG áp file 15/10 nữa):
--   • update_my_display_name_v4 — giữ nguyên tên hàm + dạng kết quả app đang dùng ({success, display_name, message});
--     CHỈ vé authenticated thật; tên 2–50 ký tự, gộp khoảng trắng, bỏ ký tự điều khiển; ≤ 10 lần / giờ.
--   • store_staff_set_name_v1 — Chủ quán đổi tên nhân viên (màn Nhân viên). Cùng luật với đặt lại mật khẩu (H3):
--     chỉ chủ quán; người đó là thành viên, không phải chủ / chính mình; mọi quán người đó thuộc đều do người gọi làm chủ
--     (tên dùng chung mọi quán); người đó đã từng tự đăng nhập vào quán (chặn kẻ gian thêm SĐT người lạ rồi đổi tên).
--     Ghi support_actions 'owner_set_name' (tên cũ → mới). ≤ 30 lần / giờ / chủ quán.
--   • Danh sách nhân viên / bill đọc staff_members.name → hai hàm ghi luôn cột này; trigger buộc staff_members.name
--     do app ghi (anon/authenticated) luôn theo user_accounts.display_name (trước đây mọi thành viên quán PATCH được tên người khác).
--   • Đóng lỗ đang mở (QC 26/10): 20261007_fix04 cấp UPDATE(display_name) bảng user_accounts cho anon + policy
--     ua_update_self_v5 dựa qn_caller_id() (tin header x-user-id) → ai có khoá công khai PATCH được tên bất kỳ ai.
--     App không ghi thẳng bảng này → thu hồi; chỉ đổi tên qua 2 hàm dưới. Hoàn tác KHÔNG mở lại lỗ này.
--   • Sửa kèm (QC): giới hạn đặt mật khẩu H3 chỉ đếm 'owner_set_password'; /admin ghi "(tự đổi)" cho dòng tự đổi tên,
--     lịch sử ưu tiên thao tác hỗ trợ (tự đổi tên không đẩy khuất).
-- Hoàn tác: …_ROLLBACK.sql
-- ============================================================================
BEGIN;

DO $$
BEGIN
  IF to_regprocedure('public.qn_user_owns_store(uuid,uuid)') IS NULL OR to_regclass('public.support_actions') IS NULL THEN
    RAISE EXCEPTION 'Cần áp hỗ trợ chủ quán H1H2 + H3 trước';
  END IF;
END $$;

REVOKE UPDATE ON public.user_accounts FROM anon, authenticated;
REVOKE UPDATE (display_name) ON public.user_accounts FROM anon, authenticated;
DROP POLICY IF EXISTS ua_update_self_v5 ON public.user_accounts;

ALTER TABLE public.support_actions DROP CONSTRAINT IF EXISTS support_actions_action_check;
ALTER TABLE public.support_actions ADD CONSTRAINT support_actions_action_check
  CHECK (action IN ('temp_password', 'clear_quick_pin', 'owner_set_password', 'owner_set_name', 'self_set_name'));

-- Chuẩn hoá tên: dạng dựng sẵn (NFC), bỏ ký tự vô hình / đảo chiều / điều khiển, gộp khoảng trắng, cắt hai đầu. NULL nếu không hợp lệ (2–50 ký tự).
CREATE OR REPLACE FUNCTION public.qn_clean_display_name(p text)
RETURNS text LANGUAGE sql IMMUTABLE AS $fn$
  SELECT CASE WHEN char_length(v) BETWEEN 2 AND 50 THEN v END
    FROM (SELECT btrim(regexp_replace(regexp_replace(regexp_replace(normalize(COALESCE(p, ''), NFC),
            '[\u00AD\u034F\u115F\u1160\u180E\u200B-\u200F\u2028-\u202E\u2060-\u2069\u3164\uFEFF]', '', 'g'),  -- vô hình / đảo chiều chữ
            '[[:cntrl:]]', ' ', 'g'), '\s+', ' ', 'g')) AS v) x
$fn$;
REVOKE ALL ON FUNCTION public.qn_clean_display_name(text) FROM PUBLIC, anon, authenticated, qn_admin;

-- Tự đổi tên của mình (ô "Tên hiển thị" trong Cài đặt — app đã có sẵn)
CREATE OR REPLACE FUNCTION public.update_my_display_name_v4(p_display_name text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE u uuid := public.qn_caller_id(); v_role text; v_name text := public.qn_clean_display_name(p_display_name);
BEGIN
  BEGIN v_role := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role'; EXCEPTION WHEN OTHERS THEN v_role := NULL; END;
  IF u IS NULL OR v_role IS DISTINCT FROM 'authenticated' THEN
    RETURN jsonb_build_object('success', false, 'status', 401, 'error_code', 'UNAUTHORIZED',
                              'message', 'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.');
  END IF;
  IF v_name IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'INVALID_NAME',
                              'message', 'Tên hiển thị phải từ 2 đến 50 ký tự');
  END IF;
  PERFORM pg_advisory_xact_lock(hashtext('self_name:' || u::text));
  IF (SELECT count(*) FROM public.support_actions WHERE target_user = u AND action = 'self_set_name'
        AND created_at > now() - interval '1 hour') >= 10 THEN
    RETURN jsonb_build_object('success', false, 'status', 429, 'error_code', 'TOO_MANY',
                              'message', 'Đổi tên quá nhiều lần trong 1 giờ. Vui lòng thử lại sau.');
  END IF;
  UPDATE public.user_accounts SET display_name = v_name WHERE id = u;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'status', 404, 'error_code', 'NOT_FOUND', 'message', 'Không tìm thấy tài khoản');
  END IF;
  UPDATE public.staff_members SET name = v_name WHERE id = u;  -- danh sách nhân viên / bill đọc cột này
  INSERT INTO public.support_actions (admin_id, actor_user, target_user, action, reason)
  VALUES (NULL, u, u, 'self_set_name', left('Tự đổi tên → ' || v_name, 500));
  RETURN jsonb_build_object('success', true, 'status', 200, 'display_name', v_name, 'message', 'Đã đổi tên hiển thị');
END
$fn$;
REVOKE ALL ON FUNCTION public.update_my_display_name_v4(text) FROM PUBLIC, anon, qn_admin;
GRANT EXECUTE ON FUNCTION public.update_my_display_name_v4(text) TO authenticated;

-- Chủ quán đổi tên nhân viên
CREATE OR REPLACE FUNCTION public.store_staff_set_name_v1(p_store uuid, p_user uuid, p_name text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE u uuid := public.qn_caller_id(); v_role text; v_name text := public.qn_clean_display_name(p_name); v_old text;
BEGIN
  BEGIN v_role := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role'; EXCEPTION WHEN OTHERS THEN v_role := NULL; END;
  IF u IS NULL OR v_role IS DISTINCT FROM 'authenticated' OR p_store IS NULL OR p_user IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN');
  END IF;
  IF NOT public.qn_user_owns_store(u, p_store) THEN RETURN jsonb_build_object('ok', false, 'error', 'OWNER_ONLY'); END IF;
  IF p_user = u THEN RETURN jsonb_build_object('ok', false, 'error', 'SELF'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.store_members m WHERE m.store_id = p_store AND m.user_id = p_user) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'NOT_MEMBER');
  END IF;
  IF public.qn_user_owns_store(p_user, p_store) THEN RETURN jsonb_build_object('ok', false, 'error', 'TARGET_OWNER'); END IF;
  IF EXISTS (SELECT 1 FROM public.store_members m WHERE m.user_id = p_user AND NOT public.qn_user_owns_store(u, m.store_id))
     OR EXISTS (SELECT 1 FROM public.stores s WHERE s.owner_user_id = p_user) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'OTHER_STORES');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.pos_refresh_tokens t WHERE t.user_id = p_user AND t.store_id = p_store) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'NOT_ACTIVE');
  END IF;
  IF v_name IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_NAME'); END IF;
  PERFORM pg_advisory_xact_lock(hashtext('staff_name:' || u::text));
  IF (SELECT count(*) FROM public.support_actions WHERE actor_user = u AND action = 'owner_set_name'
        AND created_at > now() - interval '1 hour') >= 30 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'TOO_MANY');
  END IF;
  SELECT display_name INTO v_old FROM public.user_accounts WHERE id = p_user FOR UPDATE;
  UPDATE public.user_accounts SET display_name = v_name WHERE id = p_user;
  UPDATE public.staff_members SET name = v_name WHERE id = p_user;
  INSERT INTO public.support_actions (admin_id, actor_user, target_user, action, reason)
  VALUES (NULL, u, p_user, 'owner_set_name', left(format('Chủ quán đổi tên: %s → %s', COALESCE(v_old, ''), v_name), 500));
  RETURN jsonb_build_object('ok', true, 'display_name', v_name);
END
$fn$;
REVOKE ALL ON FUNCTION public.store_staff_set_name_v1(uuid, uuid, text) FROM PUBLIC, anon, qn_admin;
GRANT EXECUTE ON FUNCTION public.store_staff_set_name_v1(uuid, uuid, text) TO authenticated;

-- staff_members.name do app ghi (upsert hồ sơ, PATCH thẳng) luôn theo tên tài khoản — chặn thành viên quán sửa tên người khác.
-- Người không có tài khoản (hồ sơ cũ) giữ tên cũ khi sửa. Áp cả trong hàm SECURITY DEFINER app gọi (vd admin_create_staff_member_v4:
-- tên gõ khi thêm nhân viên nhường tên tài khoản). Chỉ postgres / service_role / qn_admin bỏ qua. Production 26/10: 0 hồ sơ lệch tên.
CREATE OR REPLACE FUNCTION public.qn_staff_members_name_follow_account()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  -- SECURITY DEFINER đổi current_user nhưng không đổi GUC role (PostgREST đặt SET LOCAL ROLE)
  IF current_setting('role', true) NOT IN ('anon', 'authenticated') THEN RETURN NEW; END IF;
  NEW.name := COALESCE((SELECT NULLIF(btrim(ua.display_name), '') FROM public.user_accounts ua WHERE ua.id = NEW.id),
                       CASE WHEN TG_OP = 'UPDATE' THEN OLD.name END, NEW.name);
  RETURN NEW;
END
$fn$;
REVOKE ALL ON FUNCTION public.qn_staff_members_name_follow_account() FROM PUBLIC, anon, authenticated, qn_admin;
DROP TRIGGER IF EXISTS qn_staff_members_name_follow_account ON public.staff_members;
CREATE TRIGGER qn_staff_members_name_follow_account
  BEFORE INSERT OR UPDATE ON public.staff_members
  FOR EACH ROW EXECUTE FUNCTION public.qn_staff_members_name_follow_account();

-- H3: giới hạn 20 lần / giờ chỉ đếm lượt đặt mật khẩu (đổi tên không ăn vào)
CREATE OR REPLACE FUNCTION public.store_staff_set_password_v1(p_store uuid, p_user uuid, p_new_password text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $fn$
DECLARE u uuid := public.qn_caller_id(); v_role text;
BEGIN
  BEGIN v_role := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role'; EXCEPTION WHEN OTHERS THEN v_role := NULL; END;
  IF u IS NULL OR v_role IS DISTINCT FROM 'authenticated' OR p_store IS NULL OR p_user IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN');
  END IF;
  IF NOT public.qn_user_owns_store(u, p_store) THEN RETURN jsonb_build_object('ok', false, 'error', 'OWNER_ONLY'); END IF;
  IF p_user = u THEN RETURN jsonb_build_object('ok', false, 'error', 'SELF'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.store_members m WHERE m.store_id = p_store AND m.user_id = p_user) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'NOT_MEMBER');
  END IF;
  IF public.qn_user_owns_store(p_user, p_store) THEN RETURN jsonb_build_object('ok', false, 'error', 'TARGET_OWNER'); END IF;
  -- mọi quán người đó thuộc (hoặc làm chủ) đều phải do người gọi làm chủ
  IF EXISTS (SELECT 1 FROM public.store_members m WHERE m.user_id = p_user AND NOT public.qn_user_owns_store(u, m.store_id))
     OR EXISTS (SELECT 1 FROM public.stores s WHERE s.owner_user_id = p_user) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'OTHER_STORES');
  END IF;
  -- bằng chứng chính người đó đã vào quán này (đăng nhập bằng mật khẩu của họ) — kẻ gian không tự tạo được
  IF NOT EXISTS (SELECT 1 FROM public.pos_refresh_tokens t WHERE t.user_id = p_user AND t.store_id = p_store) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'NOT_ACTIVE');
  END IF;
  IF char_length(COALESCE(p_new_password, '')) < 8 OR char_length(p_new_password) > 72 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_PASSWORD');
  END IF;
  PERFORM pg_advisory_xact_lock(hashtext('staff_pw:' || u::text));  -- gửi song song không lọt giới hạn
  IF (SELECT count(*) FROM public.support_actions WHERE actor_user = u AND action = 'owner_set_password'
        AND created_at > now() - interval '1 hour') >= 20 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'TOO_MANY');
  END IF;
  UPDATE public.user_accounts SET password_hash = crypt(p_new_password, gen_salt('bf', 12)) WHERE id = p_user;
  UPDATE public.pos_refresh_tokens SET revoked_at = now(), revoke_reason = 'owner_set_password'
   WHERE user_id = p_user AND revoked_at IS NULL;
  INSERT INTO public.support_actions (admin_id, actor_user, target_user, action, reason)
  VALUES (NULL, u, p_user, 'owner_set_password', 'Chủ quán đặt mật khẩu mới trong app (quán ' || p_store::text || ')');
  RETURN jsonb_build_object('ok', true);
END
$fn$;
REVOKE ALL ON FUNCTION public.store_staff_set_password_v1(uuid, uuid, text) FROM PUBLIC, anon, qn_admin;
GRANT EXECUTE ON FUNCTION public.store_staff_set_password_v1(uuid, uuid, text) TO authenticated;

-- /admin: dòng tự đổi tên ghi "(tự đổi)", không ghi "(chủ quán)"
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
                                                             'admin', CASE WHEN a.action = 'self_set_name' THEN ou.display_name || ' (tự đổi)'
                                                                      ELSE COALESCE(pa.display_name, ou.display_name || ' (chủ quán)') END)
                                          ORDER BY a.created_at DESC)
              FROM (SELECT * FROM public.support_actions sa WHERE sa.target_user = u.id
                     ORDER BY sa.action = 'self_set_name', sa.created_at DESC LIMIT 15) a  -- tự đổi tên không đẩy thao tác hỗ trợ khuất
              LEFT JOIN public.platform_admin_accounts pa ON pa.id = a.admin_id
              LEFT JOIN public.user_accounts ou ON ou.id = a.actor_user), '[]'::jsonb))
    FROM public.user_accounts u WHERE u.id = p_user
$fn$;
REVOKE ALL ON FUNCTION public.qn_admin_account_json(uuid) FROM PUBLIC, anon, authenticated, qn_admin;

DO $$
BEGIN
  IF has_column_privilege('anon', 'public.user_accounts', 'display_name', 'UPDATE')
     OR has_column_privilege('authenticated', 'public.user_accounts', 'display_name', 'UPDATE')
     OR has_function_privilege('anon', 'public.update_my_display_name_v4(text)', 'execute')
     OR has_function_privilege('anon', 'public.store_staff_set_name_v1(uuid,uuid,text)', 'execute')
     OR NOT has_function_privilege('authenticated', 'public.update_my_display_name_v4(text)', 'execute')
     OR NOT has_function_privilege('authenticated', 'public.store_staff_set_name_v1(uuid,uuid,text)', 'execute') THEN
    RAISE EXCEPTION 'DOI TEN AN TOAN: quyền không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
