-- ============================================================================
-- HỖ TRỢ CHỦ QUÁN — ĐỢT H3 (ke-hoach-ho-tro-chu-quan.md; Chủ Quán chốt 26/10: CHỈ Chủ quán, chủ quán TỰ GÕ mật khẩu mới)
--   • store_staff_set_password_v1 — Chủ quán đặt mật khẩu mới cho nhân viên ngay trong app (màn Nhân viên).
--     Điều kiện: vé đăng nhập thật (authenticated), người gọi là chủ của quán; người được đổi là thành viên quán, KHÔNG phải
--     chủ quán, không phải chính mình; MỌI quán người đó đang thuộc đều do người gọi làm chủ (mật khẩu dùng chung mọi quán
--     — tránh chủ quán A đổi mật khẩu của người cũng làm ở quán B) → khác thì OTHER_STORES (nhờ hỗ trợ);
--     người đó PHẢI ĐÃ TỪNG TỰ ĐĂNG NHẬP vào chính quán này (có vé làm mới của quán) → NOT_ACTIVE. Chặn chiếm tài khoản:
--     kẻ gian tự tạo quán, thêm SĐT nạn nhân bằng admin_create_staff_member_v4 (không cần nạn nhân đồng ý) rồi đặt mật khẩu
--     (QC 30/10 chạy thử thành công trên bản trước — 52 / 246 tài khoản không thuộc quán nào có nguy cơ).
--     Mật khẩu 8–72 ký tự, lưu bcrypt; thu hồi vé làm mới của người đó; ghi support_actions (không lưu mật khẩu); ≤ 20 lần / giờ.
--   • support_actions: thêm loại 'owner_set_password' + cột actor_user (chủ quán làm); trang hỗ trợ hiện tên chủ quán.
--   • Chốt cờ chủ quán trên store_members (lỗ có sẵn — QC 29/10): chính sách sm_update_v5 / sm_insert_v5 cho QUẢN LÝ ghi
--     store_members → quản lý tự đặt is_owner = true / role 'owner' cho mình được → thành "chủ quán" (đổi mật khẩu người
--     khác, xem thanh toán…). Trigger: người đăng nhập (anon / authenticated) chỉ đặt / đổi is_owner, role chủ quán,
--     user_id, store_id khi CHÍNH họ đứng tên chủ trên stores.owner_user_id của quán đó. Hàm SECURITY DEFINER (tạo quán,
--     tham gia quán…) không bị ảnh hưởng.
-- Hoàn tác: …_ROLLBACK.sql
-- ============================================================================
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.support_actions') IS NULL THEN RAISE EXCEPTION 'Cần áp 20261029_ho_tro_chu_quan_h1h2.sql trước'; END IF;
END $$;

ALTER TABLE public.support_actions ADD COLUMN IF NOT EXISTS actor_user uuid;  -- chủ quán (user_accounts) khi chủ quán tự làm
ALTER TABLE public.support_actions DROP CONSTRAINT IF EXISTS support_actions_action_check;
ALTER TABLE public.support_actions ADD CONSTRAINT support_actions_action_check
  CHECK (action IN ('temp_password', 'clear_quick_pin', 'owner_set_password'));
CREATE INDEX IF NOT EXISTS idx_support_actions_actor ON public.support_actions (actor_user, created_at DESC) WHERE actor_user IS NOT NULL;

-- Người gọi có phải chủ của quán p_store không (dùng cho mọi kiểm "quán do người gọi làm chủ")
CREATE OR REPLACE FUNCTION public.qn_user_owns_store(p_user uuid, p_store uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
  SELECT EXISTS (SELECT 1 FROM public.stores s WHERE s.id = p_store AND s.owner_user_id = p_user)
      OR EXISTS (SELECT 1 FROM public.store_members m WHERE m.store_id = p_store AND m.user_id = p_user AND m.is_owner)
$fn$;
REVOKE ALL ON FUNCTION public.qn_user_owns_store(uuid, uuid) FROM PUBLIC, anon, authenticated, qn_admin;

CREATE OR REPLACE FUNCTION public.qn_store_members_guard_owner()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $fn$
DECLARE v_owner_role boolean; v_named_owner boolean;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN RETURN NEW; END IF;
  v_owner_role := COALESCE(NEW.is_owner, false)
                  OR lower(btrim(COALESCE(NEW.role, ''))) IN ('owner', 'chủ quán', 'chu quan');
  -- chủ đứng tên trên quán (stores.owner_user_id) — không tính cờ is_owner để không tự nâng quyền theo chuỗi
  v_named_owner := EXISTS (SELECT 1 FROM public.stores s WHERE s.id = NEW.store_id AND s.owner_user_id = public.qn_caller_id());
  IF TG_OP = 'INSERT' THEN
    IF v_owner_role AND NOT v_named_owner THEN
      RAISE EXCEPTION 'Chỉ chủ quán mới cấp quyền chủ quán' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.user_id IS DISTINCT FROM OLD.user_id OR NEW.store_id IS DISTINCT FROM OLD.store_id THEN
    RAISE EXCEPTION 'Không được đổi người / quán của dòng thành viên' USING ERRCODE = '42501';
  END IF;
  IF (COALESCE(NEW.is_owner, false) IS DISTINCT FROM COALESCE(OLD.is_owner, false)
      OR (v_owner_role AND lower(btrim(COALESCE(OLD.role, ''))) NOT IN ('owner', 'chủ quán', 'chu quan')))
     AND NOT v_named_owner THEN
    RAISE EXCEPTION 'Chỉ chủ quán mới cấp / gỡ quyền chủ quán' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END
$fn$;
REVOKE ALL ON FUNCTION public.qn_store_members_guard_owner() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS qn_store_members_guard_owner ON public.store_members;
CREATE TRIGGER qn_store_members_guard_owner BEFORE INSERT OR UPDATE ON public.store_members
  FOR EACH ROW EXECUTE FUNCTION public.qn_store_members_guard_owner();

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
  IF (SELECT count(*) FROM public.support_actions WHERE actor_user = u AND created_at > now() - interval '1 hour') >= 20 THEN
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
                                                             'admin', COALESCE(pa.display_name, ou.display_name || ' (chủ quán)'))
                                          ORDER BY a.created_at DESC)
              FROM (SELECT * FROM public.support_actions sa WHERE sa.target_user = u.id ORDER BY sa.created_at DESC LIMIT 10) a
              LEFT JOIN public.platform_admin_accounts pa ON pa.id = a.admin_id
              LEFT JOIN public.user_accounts ou ON ou.id = a.actor_user), '[]'::jsonb))
    FROM public.user_accounts u WHERE u.id = p_user
$fn$;;
REVOKE ALL ON FUNCTION public.qn_admin_account_json(uuid) FROM PUBLIC, anon, authenticated, qn_admin;

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.store_staff_set_password_v1(uuid,uuid,text)', 'execute')
     OR NOT has_function_privilege('authenticated', 'public.store_staff_set_password_v1(uuid,uuid,text)', 'execute')
     OR has_function_privilege('authenticated', 'public.qn_user_owns_store(uuid,uuid)', 'execute')
     OR has_table_privilege('authenticated', 'public.support_actions', 'select') THEN
    RAISE EXCEPTION 'HO TRO H3: quyền không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
