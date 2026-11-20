-- ============================================================================
-- HOÀN TÁC 20261030_ho_tro_h3_chu_quan_dat_mat_khau.sql
--   • Gỡ store_staff_set_password_v1, qn_user_owns_store, trigger chốt cờ chủ quán; trả qn_admin_account_json về bản H1H2.
--   • GIỮ cột support_actions.actor_user, dòng nhật ký 'owner_set_password' và ràng buộc mở rộng (dữ liệu cũ vẫn hợp lệ).
--   • Mật khẩu chủ quán đã đặt cho nhân viên giữ nguyên.
-- ============================================================================
BEGIN;
DROP FUNCTION IF EXISTS public.store_staff_set_password_v1(uuid, uuid, text);
DROP TRIGGER IF EXISTS qn_store_members_guard_owner ON public.store_members;
DROP FUNCTION IF EXISTS public.qn_store_members_guard_owner();
DROP FUNCTION IF EXISTS public.qn_user_owns_store(uuid, uuid);
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
$fn$;;
REVOKE ALL ON FUNCTION public.qn_admin_account_json(uuid) FROM PUBLIC, anon, authenticated, qn_admin;
COMMIT;
NOTIFY pgrst, 'reload schema';
