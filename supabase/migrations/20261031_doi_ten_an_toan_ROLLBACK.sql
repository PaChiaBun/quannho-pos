-- ============================================================================
-- HOÀN TÁC 20261031_doi_ten_an_toan.sql — gỡ 2 hàm đổi tên + trigger tên staff_members, trả 2 hàm H3 về bản cũ (app sẽ lại báo "chưa sẵn sàng" như trước khi áp).
-- GIỮ: tên đã đổi, dòng nhật ký support_actions và ràng buộc mở rộng (dữ liệu cũ vẫn hợp lệ).
-- KHÔNG trả lại quyền UPDATE(display_name) bảng user_accounts cho anon/authenticated (lỗ đổi tên người khác).
-- KHÔNG áp lại 20261015_doi_ten_hien_thi_v4.sql (bản đó cho người chưa đăng nhập đổi tên người khác).
-- ============================================================================
BEGIN;
DROP TRIGGER IF EXISTS qn_staff_members_name_follow_account ON public.staff_members;
DROP FUNCTION IF EXISTS public.qn_staff_members_name_follow_account();
DROP FUNCTION IF EXISTS public.store_staff_set_name_v1(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.update_my_display_name_v4(text);
DROP FUNCTION IF EXISTS public.qn_clean_display_name(text);

-- Trả 2 hàm H3 về bản 20261030
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
$fn$;
REVOKE ALL ON FUNCTION public.qn_admin_account_json(uuid) FROM PUBLIC, anon, authenticated, qn_admin;
COMMIT;
NOTIFY pgrst, 'reload schema';
