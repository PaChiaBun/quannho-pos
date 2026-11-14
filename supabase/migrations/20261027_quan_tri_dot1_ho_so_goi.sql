-- ============================================================================
-- TRANG QUẢN TRỊ — ĐỢT 1: HỒ SƠ QUÁN + GÓI / HẠN DÙNG THỬ + THAO TÁC (Chủ Quán chốt 26/10/2026)
--   • stores.plan_ends_at           — ngày hết hạn gói Pro (NULL = không thời hạn)
--   • admin_store_actions           — nhật ký MỌI thao tác quản trị lên quán (ai, lúc nào, trước / sau, số tiền, ghi chú)
--   • admin_store_notes             — sổ chăm sóc quán (ghi chú + ngày hẹn gọi lại)
--   • platform_settings             — cài đặt nền tảng (hiện chỉ 'plan_contact': câu liên hệ hiện trong dải nhắc ở app)
--   • Chốt cột gói: người đăng nhập quán (anon / authenticated) KHÔNG tự đổi được plan / status / trial_ends_at /
--     plan_ends_at (trước đây MỌI thành viên quán, kể cả thu ngân, UPDATE thẳng được — lỗ hổng có sẵn).
--     Tạo quán mới bằng INSERT thẳng: ép free / trial / 14 ngày.
--   • Chốt luôn owner_user_id / store_code: trước đây thu ngân tự đặt mình làm chủ quán được (QC 27/10).
--   • Khoá quán = stores.status 'locked': current_store_id() trả NULL → mọi bảng có RLS theo quán ngừng đọc / ghi
--     ngay (vé cũ sống 30 ngày vẫn bị chặn); 2 cổng verify_staff_qr_membership_v4 / qn_is_member chặn bán hàng,
--     quyết toán, báo cáo; app hiện màn "Quán đang tạm khoá". Vẫn đăng nhập được (để thấy màn khoá).
--   • Hàm admin_*_v1 mới (chỉ vé qn_admin) + store_plan_status_v1 (app hỏi gói / khoá của quán mình).
--   • store_self_extend_trial_v1: CHỦ QUÁN tự gia hạn thêm 30 ngày dùng thử từ dải nhắc (Chủ Quán 26/10: chưa thu phí,
--     không giới hạn số lần; chỉ bấm được khi còn ≤ 3 ngày hoặc đã hết hạn → không cộng dồn trước). Ghi admin_store_actions.
--   • admin_store_list_v1: cột "máy" đếm thiết bị thật từ app_logs 30 ngày (bảng devices trống → trước đây luôn 0).
-- Hoàn tác: 20261027_quan_tri_dot1_ho_so_goi_ROLLBACK.sql
-- ============================================================================
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.platform_admin_accounts') IS NULL THEN
    RAISE EXCEPTION 'Cần áp trang quản trị v2 (20261026_trang_quan_tri_v2_tai_khoan.sql) trước';
  END IF;
END $$;

-- 1) Cột + bảng -------------------------------------------------------------------------------------------------
ALTER TABLE public.stores ADD COLUMN IF NOT EXISTS plan_ends_at timestamptz;

CREATE TABLE IF NOT EXISTS public.admin_store_actions (
  id          bigserial PRIMARY KEY,
  store_id    uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  admin_id    uuid NOT NULL,
  action      text NOT NULL CHECK (action IN ('extend_trial', 'set_plan', 'lock', 'unlock', 'self_extend')),
  -- admin_id: tài khoản quản trị (platform_admin_accounts); riêng 'self_extend' là user_accounts.id của chủ quán
  before      jsonb NOT NULL,
  after       jsonb NOT NULL,
  amount_vnd  bigint CHECK (amount_vnd IS NULL OR amount_vnd >= 0),
  note        text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_admin_store_actions_store ON public.admin_store_actions (store_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.admin_store_notes (
  id           bigserial PRIMARY KEY,
  store_id     uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  admin_id     uuid NOT NULL,
  body         text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  follow_up_on date,
  done_at      timestamptz,
  done_by      uuid,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_admin_store_notes_store ON public.admin_store_notes (store_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_store_notes_follow ON public.admin_store_notes (follow_up_on) WHERE done_at IS NULL;

CREATE TABLE IF NOT EXISTS public.platform_settings (
  key        text PRIMARY KEY CHECK (key IN ('plan_contact')),
  value      text NOT NULL CHECK (char_length(value) <= 300),
  updated_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Khoá hẳn: RLS bật, không chính sách → chỉ hàm SECURITY DEFINER đọc / ghi
ALTER TABLE public.admin_store_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_store_notes   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_settings   ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_store_actions, public.admin_store_notes, public.platform_settings
  FROM PUBLIC, anon, authenticated, qn_admin;
REVOKE ALL ON SEQUENCE public.admin_store_actions_id_seq, public.admin_store_notes_id_seq
  FROM PUBLIC, anon, authenticated, qn_admin;
GRANT ALL ON public.admin_store_actions, public.admin_store_notes, public.platform_settings TO service_role;

-- 2) Chốt cột gói trên stores ------------------------------------------------------------------------------------
-- current_user = vai trò đang chạy câu lệnh: PostgREST gọi thẳng bảng → anon / authenticated; hàm SECURITY DEFINER
-- (tạo quán create_store_with_owner_v4, hàm admin_*) → chủ hàm → được phép.
CREATE OR REPLACE FUNCTION public.qn_stores_guard_plan_cols()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.plan := 'free';
    NEW.status := 'trial';
    NEW.trial_ends_at := now() + interval '14 days';
    NEW.plan_ends_at := NULL;
    RETURN NEW;
  END IF;
  IF NEW.plan IS DISTINCT FROM OLD.plan OR NEW.status IS DISTINCT FROM OLD.status
     OR NEW.trial_ends_at IS DISTINCT FROM OLD.trial_ends_at OR NEW.plan_ends_at IS DISTINCT FROM OLD.plan_ends_at
     OR NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id OR NEW.store_code IS DISTINCT FROM OLD.store_code
     OR NEW.id IS DISTINCT FROM OLD.id THEN
    RAISE EXCEPTION 'Không được tự đổi chủ quán / mã quán / gói / hạn dùng / trạng thái quán' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END
$fn$;
REVOKE ALL ON FUNCTION public.qn_stores_guard_plan_cols() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS qn_stores_guard_plan_cols ON public.stores;
CREATE TRIGGER qn_stores_guard_plan_cols
  BEFORE INSERT OR UPDATE ON public.stores
  FOR EACH ROW EXECUTE FUNCTION public.qn_stores_guard_plan_cols();

-- 3) Khoá quán: current_store_id() trả NULL cho quán 'locked' -----------------------------------------------------
-- Giữ NGUYÊN bản đang chạy (production 26/10), chỉ thêm 1 dòng kiểm khoá sau khi đọc được mã quán.
CREATE OR REPLACE FUNCTION public.current_store_id()
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE _raw text; _claims jsonb; _store uuid; _user uuid;
BEGIN
  BEGIN _claims := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb; EXCEPTION WHEN OTHERS THEN _claims := NULL; END;
  BEGIN _raw := NULLIF(current_setting('request.headers', true)::json->>'x-store-id', ''); EXCEPTION WHEN OTHERS THEN _raw := NULL; END;
  IF (_raw IS NULL OR _raw = '') AND _claims IS NOT NULL THEN _raw := NULLIF(_claims->>'store_id', ''); END IF;
  IF _raw IS NULL OR NOT (_raw ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') THEN RETURN NULL; END IF;
  _store := _raw::uuid;
  -- Quán bị quản trị khoá → không còn quyền dữ liệu theo quán (đợt 1 trang quản trị, 27/10)
  IF EXISTS (SELECT 1 FROM public.stores WHERE id = _store AND status = 'locked') THEN RETURN NULL; END IF;
  _user := public.qn_caller_id();
  IF _user IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.store_members WHERE store_id = _store AND user_id = _user)
       OR EXISTS (SELECT 1 FROM public.stores WHERE id = _store AND owner_user_id = _user) THEN
      RETURN _store;
    END IF;
    RETURN NULL;
  END IF;
  -- Không có người gọi: chỉ chấp nhận store_id nằm trong JWT đã ký
  IF _claims IS NOT NULL AND _claims->>'role' = 'authenticated' AND (_claims->>'store_id') = _raw THEN RETURN _store; END IF;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END $function$;

-- 3b) Khoá quán ở 2 "cổng" mà các hàm SECURITY DEFINER tự kiểm thành viên đi qua (QC 27/10: chỉ sửa current_store_id thì
--     quán khoá vẫn bán được qua complete_pos_sale_v1, vẫn xem báo cáo qua get_report_stats_for_range_v1):
--     • verify_staff_qr_membership_v4 → complete_pos_sale_v1, settle_ban_session_v5, reconcile_*, generate_daily_order_number_v1,
--       qr_staff_ctx_v4, payroll_actor_v1, batch_soft_delete_products_v1
--     • qn_is_member → 4 hàm báo cáo theo khoảng ngày + chính sách stores_select / stores_update
--     Giữ NGUYÊN bản đang chạy (production 26/10), chỉ thêm điều kiện khoá. qn_member_role_v1 KHÔNG đổi: vẫn đăng nhập được
--     để app hiện màn "Quán đang tạm khoá" (dữ liệu đã bị chặn ở các cổng trên).
CREATE OR REPLACE FUNCTION public.qn_is_member(p_store uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_store IS NOT NULL AND public.qn_caller_id() IS NOT NULL AND (
    EXISTS (SELECT 1 FROM public.store_members m WHERE m.store_id = p_store AND m.user_id = public.qn_caller_id())
    OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = p_store AND s.owner_user_id = public.qn_caller_id()))
    -- quán bị quản trị khoá → không còn là thành viên với mọi hàm / chính sách dùng qn_is_member (27/10)
    AND NOT EXISTS (SELECT 1 FROM public.stores s WHERE s.id = p_store AND s.status = 'locked');
$function$;

CREATE OR REPLACE FUNCTION public.verify_staff_qr_membership_v4(p_store_id uuid, p_require_checkout boolean DEFAULT false, p_require_manage boolean DEFAULT false)
 RETURNS TABLE(member_user_id uuid, member_role text, store_member_id uuid, is_owner_member boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid;
  v_sm_id uuid;
  v_role text;
  v_is_owner boolean;
  v_perms_json jsonb;
  v_has_checkout boolean := false;
BEGIN
  -- Trích xuất User ID qua auth.uid() hoặc JWT context đa tầng
  BEGIN
    v_uid := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_uid := NULL;
  END;

  IF v_uid IS NULL THEN
    BEGIN
      v_uid := NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_uid := NULL;
    END;
  END IF;

  IF v_uid IS NULL THEN
    BEGIN
      v_uid := NULLIF(((current_setting('request.jwt.claims', true)::jsonb)->>'sub'), '')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_uid := NULL;
    END;
  END IF;

  IF v_uid IS NULL THEN
    BEGIN
      v_uid := NULLIF((current_setting('request.headers', true)::jsonb)->>'x-user-id', '')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_uid := NULL;
    END;
  END IF;

  IF v_uid IS NULL THEN
    BEGIN
      v_uid := NULLIF(current_setting('request.header.x-user-id', true), '')::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_uid := NULL;
    END;
  END IF;

  IF v_uid IS NULL OR p_store_id IS NULL THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: authenticated store context is required'
      USING ERRCODE = '42501';
  END IF;

  -- Quán bị quản trị khoá → chặn bán hàng / quyết toán / sinh số đơn… (trang quản trị đợt 1, 27/10)
  IF EXISTS (SELECT 1 FROM public.stores WHERE id = p_store_id AND status = 'locked') THEN
    RAISE EXCEPTION 'STORE_LOCKED: cửa hàng đang tạm khoá' USING ERRCODE = '42501';
  END IF;

  -- 1. Tìm thông tin trong store_members
  SELECT sm.id, sm.role, COALESCE(sm.is_owner, false)
  INTO v_sm_id, v_role, v_is_owner
  FROM public.store_members sm
  WHERE sm.store_id = p_store_id AND sm.user_id = v_uid
  LIMIT 1;

  -- 2. Fallback: Nếu không có trong store_members, kiểm tra stores (Owner)
  IF v_role IS NULL THEN
    SELECT 'owner', true
    INTO v_role, v_is_owner
    FROM public.stores
    WHERE id = p_store_id AND owner_user_id = v_uid
    LIMIT 1;
  END IF;

  -- 3. Fallback: Kiểm tra trực tiếp trong staff_members
  IF v_role IS NULL THEN
    SELECT sm.role, false
    INTO v_role, v_is_owner
    FROM public.staff_members sm
    WHERE sm.store_id = p_store_id AND sm.id = v_uid
    LIMIT 1;
  END IF;

  IF v_role IS NULL THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: not a member of this store'
      USING ERRCODE = '42501';
  END IF;

  IF p_require_manage AND NOT (v_is_owner OR v_role IN ('owner', 'manager', 'admin')) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: manage permission required'
      USING ERRCODE = '42501';
  END IF;

  IF p_require_checkout AND NOT (v_is_owner OR v_role = 'owner') THEN
    -- 1. Ưu tiên vai trò chuẩn (owner, manager, cashier, admin, waiter) hoặc tiếng Việt
    IF v_role IN ('owner', 'manager', 'cashier', 'admin', 'waiter')
       OR lower(trim(v_role)) LIKE '%thu ngân%'
       OR lower(trim(v_role)) LIKE '%quản lý%'
       OR lower(trim(v_role)) LIKE '%quầy%'
       OR lower(trim(v_role)) LIKE '%phục vụ%'
       OR lower(trim(v_role)) LIKE '%chạy bàn%'
       OR lower(trim(v_role)) LIKE '%bán hàng%' THEN
      v_has_checkout := true;
    END IF;

    -- 2. Kiểm tra modules từ store_roles (Lego Modules)
    IF NOT v_has_checkout THEN
      BEGIN
        SELECT EXISTS (
          SELECT 1
          FROM public.store_roles sr,
               LATERAL jsonb_array_elements_text(
                 CASE
                   WHEN sr.modules IS NULL OR btrim(sr.modules::text) = '' THEN '[]'::jsonb
                   WHEN jsonb_typeof(sr.modules::jsonb) = 'array' THEN sr.modules::jsonb
                   ELSE '[]'::jsonb
                 END
               ) AS m(module_name)
          WHERE sr.store_id = p_store_id
            AND (sr.name = v_role OR lower(trim(sr.name)) = lower(trim(v_role)))
            AND m.module_name IN ('pos', 'ban')
        ) INTO v_has_checkout;
      EXCEPTION WHEN OTHERS THEN
        v_has_checkout := false;
      END;
    END IF;

    -- 3. Kiểm tra modules từ staff_members
    IF NOT v_has_checkout THEN
      BEGIN
        SELECT EXISTS (
          SELECT 1
          FROM public.staff_members sm,
               LATERAL jsonb_array_elements_text(
                 CASE
                   WHEN sm.modules IS NULL OR btrim(sm.modules::text) = '' THEN '[]'::jsonb
                   WHEN jsonb_typeof(sm.modules::jsonb) = 'array' THEN sm.modules::jsonb
                   ELSE '[]'::jsonb
                 END
               ) AS m(module_name)
          WHERE sm.store_id = p_store_id
            AND sm.id = v_uid
            AND m.module_name IN ('pos', 'ban')
        ) INTO v_has_checkout;
      EXCEPTION WHEN OTHERS THEN
        v_has_checkout := false;
      END;
    END IF;

    -- 4. Fallback kiểm tra app_settings (action_perms_*)
    IF NOT v_has_checkout THEN
      SELECT CASE
        WHEN s.value IS NULL OR btrim(s.value) = '' THEN '[]'::jsonb
        ELSE s.value::jsonb
      END
      INTO v_perms_json
      FROM public.app_settings s
      WHERE s.store_id = p_store_id
        AND (s.key = 'action_perms_' || v_role OR s.key = 'action_perms_cashier')
      LIMIT 1;
      IF jsonb_typeof(COALESCE(v_perms_json, '[]'::jsonb)) = 'array' THEN
        SELECT EXISTS (
          SELECT 1 FROM jsonb_array_elements_text(v_perms_json) permission
          WHERE permission = 'pos.checkout'
        ) INTO v_has_checkout;
      END IF;
    END IF;

    IF NOT v_has_checkout THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: pos.checkout permission required'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  member_user_id := v_uid;
  member_role := v_role;
  store_member_id := v_uid;
  is_owner_member := v_is_owner OR v_role = 'owner';
  RETURN NEXT;
END;
$function$;

-- 3c) Quán khoá vẫn ĐỌC được dòng stores / store_members của mình (tên quán, mình là thành viên) — chỉ 2 bảng này, không
--     có số liệu kinh doanh. Không có thì app coi như "mất quán": danh sách quán bỏ quán đó, 6 chủ quán thiếu dòng
--     store_members bị đẩy sang màn chọn quán thay vì thấy màn "Quán đang tạm khoá" (QC vòng 2, 27/10).
--     qn_is_member_any = qn_is_member bản trước đợt 1 (không kiểm khoá). stores_update_v5 vẫn dùng qn_is_member (khoá → không sửa).
CREATE OR REPLACE FUNCTION public.qn_is_member_any(p_store uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p_store IS NOT NULL AND public.qn_caller_id() IS NOT NULL AND (
    EXISTS (SELECT 1 FROM public.store_members m WHERE m.store_id = p_store AND m.user_id = public.qn_caller_id())
    OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = p_store AND s.owner_user_id = public.qn_caller_id()));
$function$;
ALTER POLICY stores_select_v5 ON public.stores USING (public.qn_is_member_any(id));
ALTER POLICY sm_select_v5 ON public.store_members USING ((user_id = public.qn_caller_id()) OR public.qn_is_member_any(store_id));

-- 4) Hàm dùng chung ------------------------------------------------------------------------------------------------
-- Ảnh chụp các cột gói của quán (để ghi trước / sau)
CREATE OR REPLACE FUNCTION public.qn_store_plan_snapshot(s public.stores)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $fn$
  SELECT jsonb_build_object('plan', s.plan, 'status', s.status, 'trial_ends_at', s.trial_ends_at,
                            'plan_ends_at', s.plan_ends_at)
$fn$;
REVOKE ALL ON FUNCTION public.qn_store_plan_snapshot(public.stores) FROM PUBLIC, anon, authenticated;

-- Thông báo gói cho một quán: trial_expired | trial_ending | pro_expired | pro_ending | NULL
CREATE OR REPLACE FUNCTION public.qn_store_plan_notice(p_plan text, p_status text, p_trial_ends timestamptz,
                                                     p_plan_ends timestamptz)
RETURNS text LANGUAGE sql STABLE AS $fn$
  SELECT CASE
    WHEN p_status = 'locked' THEN NULL
    WHEN p_plan = 'pro' AND p_plan_ends IS NOT NULL AND p_plan_ends <= now() THEN 'pro_expired'
    WHEN p_plan = 'pro' AND p_plan_ends IS NOT NULL AND p_plan_ends <= now() + interval '7 days' THEN 'pro_ending'
    WHEN p_plan = 'pro' THEN NULL
    WHEN p_trial_ends IS NOT NULL AND p_trial_ends <= now() THEN 'trial_expired'
    WHEN p_trial_ends IS NOT NULL AND p_trial_ends <= now() + interval '3 days' THEN 'trial_ending'
    ELSE NULL END
$fn$;
REVOKE ALL ON FUNCTION public.qn_store_plan_notice(text, text, timestamptz, timestamptz) FROM PUBLIC, anon, authenticated;

-- Chủ quán tự gia hạn được khi: gói free, không khoá, hạn dùng thử còn ≤ 3 ngày hoặc đã hết
CREATE OR REPLACE FUNCTION public.qn_store_can_self_extend(s public.stores)
RETURNS boolean LANGUAGE sql STABLE AS $fn$
  SELECT s.plan IS DISTINCT FROM 'pro' AND s.status IS DISTINCT FROM 'locked'
     AND s.trial_ends_at IS NOT NULL AND s.trial_ends_at <= now() + interval '3 days'
$fn$;
REVOKE ALL ON FUNCTION public.qn_store_can_self_extend(public.stores) FROM PUBLIC, anon, authenticated;

-- 5) App hỏi gói / khoá của quán mình (thành viên quán; KHÔNG dựa current_store_id để quán bị khoá vẫn hỏi được) ---
CREATE OR REPLACE FUNCTION public.store_plan_status_v1(p_store uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE u uuid := public.qn_caller_id(); s public.stores%ROWTYPE; v_owner boolean;
BEGIN
  IF u IS NULL OR p_store IS NULL OR NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role' IS DISTINCT FROM 'authenticated' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN');
  END IF;
  SELECT * INTO s FROM public.stores WHERE id = p_store;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  v_owner := COALESCE(s.owner_user_id = u, false) OR EXISTS (SELECT 1 FROM public.store_members m
                                             WHERE m.store_id = p_store AND m.user_id = u AND m.is_owner);
  IF NOT v_owner AND NOT EXISTS (SELECT 1 FROM public.store_members m WHERE m.store_id = p_store AND m.user_id = u) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN');
  END IF;
  RETURN jsonb_build_object('ok', true,
    'plan', s.plan, 'status', s.status, 'locked', s.status = 'locked', 'is_owner', v_owner,
    'trial_ends_at', s.trial_ends_at, 'plan_ends_at', s.plan_ends_at,
    'notice', public.qn_store_plan_notice(s.plan, s.status, s.trial_ends_at, s.plan_ends_at),
    'can_self_extend', v_owner AND public.qn_store_can_self_extend(s),
    'contact', (SELECT value FROM public.platform_settings WHERE key = 'plan_contact'));
END
$fn$;
-- Chỉ vé đăng nhập thật: anon + header x-user-id (qn_caller_id còn tin) không được hỏi (QC 27/10)
REVOKE ALL ON FUNCTION public.store_plan_status_v1(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.store_plan_status_v1(uuid) TO authenticated;

-- Chủ quán tự gia hạn thêm 30 ngày dùng thử (chỉ vé đăng nhập thật; chỉ chủ quán; điều kiện ở qn_store_can_self_extend)
CREATE OR REPLACE FUNCTION public.store_self_extend_trial_v1(p_store uuid)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE u uuid := public.qn_caller_id(); s public.stores%ROWTYPE; v_before jsonb;
BEGIN
  IF u IS NULL OR p_store IS NULL OR NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role' IS DISTINCT FROM 'authenticated' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN');
  END IF;
  SELECT * INTO s FROM public.stores WHERE id = p_store FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF NOT (COALESCE(s.owner_user_id = u, false) OR EXISTS (SELECT 1 FROM public.store_members m
            WHERE m.store_id = p_store AND m.user_id = u AND m.is_owner)) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'OWNER_ONLY');
  END IF;
  IF NOT public.qn_store_can_self_extend(s) THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_DUE'); END IF;
  v_before := public.qn_store_plan_snapshot(s);
  UPDATE public.stores SET trial_ends_at = GREATEST(trial_ends_at, now()) + interval '30 days', status = 'trial'
   WHERE id = p_store RETURNING * INTO s;
  INSERT INTO public.admin_store_actions (store_id, admin_id, action, before, after, note)
  VALUES (p_store, u, 'self_extend', v_before, public.qn_store_plan_snapshot(s), 'Chủ quán tự gia hạn 30 ngày trên app');
  RETURN jsonb_build_object('ok', true, 'trial_ends_at', s.trial_ends_at);
END
$fn$;
REVOKE ALL ON FUNCTION public.store_self_extend_trial_v1(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.store_self_extend_trial_v1(uuid) TO authenticated;

-- 6) Hồ sơ quán chi tiết ----------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_store_detail_v1(p_store uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE s public.stores%ROWTYPE; v_today date := public.qn_vn_day(now()); v_mod jsonb; v_raw text;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  SELECT * INTO s FROM public.stores WHERE id = p_store;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND'); END IF;

  SELECT value INTO v_raw FROM public.app_settings WHERE store_id = p_store AND key = 'module_config_v2' LIMIT 1;
  BEGIN v_mod := v_raw::jsonb; EXCEPTION WHEN OTHERS THEN v_mod := NULL; END;
  IF v_mod IS NULL OR jsonb_typeof(v_mod) <> 'array' THEN v_mod := '[]'::jsonb; END IF;

  RETURN jsonb_build_object('ok', true,
    'store', jsonb_build_object('id', s.id, 'name', s.name, 'store_code', s.store_code, 'plan', s.plan,
        'status', s.status, 'trial_ends_at', s.trial_ends_at, 'plan_ends_at', s.plan_ends_at,
        'created_at', s.created_at, 'last_active_at', s.last_active_at,
        'notice', public.qn_store_plan_notice(s.plan, s.status, s.trial_ends_at, s.plan_ends_at),
        'is_test', EXISTS (SELECT 1 FROM public.admin_test_stores t WHERE t.store_id = s.id)),
    -- chủ: ghi trên quán, thiếu thì lấy thành viên đánh dấu chủ sớm nhất (vd KAY-Rạch Giá không có owner_user_id)
    'owner', (SELECT jsonb_build_object('name', u.display_name, 'phone', u.phone, 'since', u.created_at)
                FROM public.user_accounts u
               WHERE u.id = COALESCE(s.owner_user_id, (SELECT m.user_id FROM public.store_members m
                                                        WHERE m.store_id = p_store AND m.is_owner
                                                        ORDER BY m.created_at LIMIT 1))),
    'modules', v_mod,
    'accounts', COALESCE((SELECT jsonb_agg(x ORDER BY x->>'joined') FROM (
        SELECT jsonb_build_object('name', u.display_name, 'phone', u.phone, 'role', m.role,
                 'is_owner', COALESCE(m.is_owner, false) OR m.user_id = s.owner_user_id, 'joined', m.created_at) AS x
          FROM public.store_members m LEFT JOIN public.user_accounts u ON u.id = m.user_id
         WHERE m.store_id = p_store ORDER BY m.created_at LIMIT 60) a), '[]'::jsonb),
    'pin_staff', jsonb_build_object(
        'active', (SELECT count(*) FROM public.staff_members sm WHERE sm.store_id = p_store AND COALESCE(sm.is_active, true)),
        'total', (SELECT count(*) FROM public.staff_members sm WHERE sm.store_id = p_store)),
    'menu_items', (SELECT count(*) FROM public.products p WHERE p.store_id = p_store AND p.product_type = 'finished'
                     AND NOT COALESCE(p.is_deleted, false) AND COALESCE(p.is_active, true)
                     AND NOT COALESCE(p.is_raw_material, false)),
    'sales', (SELECT jsonb_build_object(
        'revenue_7d', round(COALESCE(sum(COALESCE(o.total_amount, o.total)) FILTER (WHERE o.created_at > now() - interval '7 days'), 0)),
        'revenue_30d', round(COALESCE(sum(COALESCE(o.total_amount, o.total)), 0)),
        'orders_7d', count(*) FILTER (WHERE o.created_at > now() - interval '7 days'),
        'orders_30d', count(*),
        'last_order_at', (SELECT max(o2.created_at) FROM public.orders o2 WHERE o2.store_id = p_store AND o2.status = 'completed'))
        FROM public.orders o WHERE o.store_id = p_store AND o.status = 'completed' AND o.created_at > now() - interval '30 days'),
    'sales_by_day', (SELECT COALESCE(jsonb_agg(jsonb_build_object('day', d.day, 'orders', COALESCE(a.n, 0),
                                                                 'revenue', round(COALESCE(a.rev, 0))) ORDER BY d.day), '[]'::jsonb)
        FROM (SELECT g::date AS day FROM generate_series(v_today - 29, v_today, interval '1 day') g) d
        LEFT JOIN (SELECT public.qn_vn_day(o.created_at) AS day, count(*) AS n, sum(COALESCE(o.total_amount, o.total)) AS rev
                     FROM public.orders o WHERE o.store_id = p_store AND o.status = 'completed'
                      AND o.created_at > now() - interval '31 days' GROUP BY 1) a ON a.day = d.day),
    'devices', COALESCE((SELECT jsonb_agg(x ORDER BY x->>'last_seen' DESC) FROM (
        SELECT jsonb_build_object('device', l.device_id, 'last_seen', max(l.created_at),
                 'staff', (array_agg(l.staff_name ORDER BY l.created_at DESC) FILTER (WHERE l.staff_name IS NOT NULL))[1],
                 'logs', count(*), 'errors', count(*) FILTER (WHERE l.level = 'ERROR')) AS x
          FROM public.app_logs l
         WHERE l.store_id = p_store AND l.created_at > now() - interval '30 days'
           AND l.device_id IS NOT NULL AND l.device_id <> 'Unknown'
         GROUP BY l.device_id ORDER BY max(l.created_at) DESC LIMIT 20) d), '[]'::jsonb),
    'sessions', jsonb_build_object(
        'active', (SELECT count(*) FROM public.pos_refresh_tokens t WHERE t.store_id = p_store
                     AND t.revoked_at IS NULL AND t.used_at IS NULL AND t.expires_at > now()),
        'recent', COALESCE((SELECT jsonb_agg(x ORDER BY x->>'at' DESC) FROM (
            -- 1 dòng = 1 lần đăng nhập (một family refresh token); IP không ghi vì cổng nằm sau proxy (luôn 127.0.0.1)
            SELECT jsonb_build_object('at', min(t.created_at), 'last_used', max(t.created_at), 'user', u.display_name,
                     'label', t.client_label,
                     'live', bool_or(t.revoked_at IS NULL AND t.used_at IS NULL AND t.expires_at > now())) AS x
              FROM public.pos_refresh_tokens t LEFT JOIN public.user_accounts u ON u.id = t.user_id
             WHERE t.store_id = p_store GROUP BY t.family_id, u.display_name, t.client_label
             ORDER BY min(t.created_at) DESC LIMIT 8) r), '[]'::jsonb)),
    'errors', COALESCE((SELECT jsonb_agg(x ORDER BY x->>'at' DESC) FROM (
        SELECT jsonb_build_object('at', l.created_at, 'tag', l.tag, 'message', left(l.message, 300),
                 'staff', l.staff_name, 'device', l.device_id) AS x
          FROM public.app_logs l WHERE l.store_id = p_store AND l.level = 'ERROR'
           AND l.created_at > now() - interval '14 days'
         ORDER BY l.created_at DESC LIMIT 20) e), '[]'::jsonb),
    'errors_14d', (SELECT count(*) FROM public.app_logs l WHERE l.store_id = p_store AND l.level = 'ERROR'
                     AND l.created_at > now() - interval '14 days'),
    'boom', (SELECT jsonb_build_object('turns_30d', count(*), 'cost_usd_30d', COALESCE(round(sum(b.cost_usd), 4), 0),
                                       'last_at', max(b.created_at))
               FROM public.boom_qa_log b WHERE b.store_id = p_store AND b.created_at > now() - interval '30 days'),
    'notes', COALESCE((SELECT jsonb_agg(x ORDER BY x->>'created_at' DESC) FROM (
        SELECT jsonb_build_object('id', n.id, 'body', n.body, 'follow_up_on', n.follow_up_on, 'done_at', n.done_at,
                 'created_at', n.created_at, 'author', a.display_name) AS x
          FROM public.admin_store_notes n LEFT JOIN public.platform_admin_accounts a ON a.id = n.admin_id
         WHERE n.store_id = p_store ORDER BY n.created_at DESC LIMIT 50) nn), '[]'::jsonb),
    'actions', COALESCE((SELECT jsonb_agg(x ORDER BY x->>'created_at' DESC) FROM (
        SELECT jsonb_build_object('action', c.action, 'before', c.before, 'after', c.after, 'amount_vnd', c.amount_vnd,
                 'note', c.note, 'created_at', c.created_at,
                 'author', CASE WHEN c.action = 'self_extend' THEN COALESCE(ua.display_name, 'Chủ quán') ELSE a.display_name END) AS x
          FROM public.admin_store_actions c LEFT JOIN public.platform_admin_accounts a ON a.id = c.admin_id
          LEFT JOIN public.user_accounts ua ON ua.id = c.admin_id AND c.action = 'self_extend'
         WHERE c.store_id = p_store ORDER BY c.created_at DESC LIMIT 30) cc), '[]'::jsonb));
END
$fn$;

-- 7) Tab Gói: tổng quan + danh sách ----------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_plan_overview_v1(p_include_test boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  WITH b AS (
    SELECT st.*, public.qn_store_plan_notice(st.plan, st.status, st.trial_ends_at, st.plan_ends_at) AS notice
      FROM public.stores st
     WHERE p_include_test OR NOT EXISTS (SELECT 1 FROM public.admin_test_stores t WHERE t.store_id = st.id)
  )
  SELECT jsonb_build_object('ok', true,
    'total', (SELECT count(*) FROM b),
    'free', (SELECT count(*) FROM b WHERE plan <> 'pro'),
    'pro', (SELECT count(*) FROM b WHERE plan = 'pro'),
    'trial_ok', (SELECT count(*) FROM b WHERE plan <> 'pro' AND status <> 'locked' AND notice IS NULL),
    'trial_ending', (SELECT count(*) FROM b WHERE notice = 'trial_ending'),
    'trial_expired', (SELECT count(*) FROM b WHERE notice = 'trial_expired'),
    'pro_ending', (SELECT count(*) FROM b WHERE notice = 'pro_ending'),
    'pro_expired', (SELECT count(*) FROM b WHERE notice = 'pro_expired'),
    'locked', (SELECT count(*) FROM b WHERE status = 'locked'),
    'follow_ups_due', (SELECT count(DISTINCT n.store_id) FROM public.admin_store_notes n JOIN b ON b.id = n.store_id
                        WHERE n.done_at IS NULL AND n.follow_up_on <= public.qn_vn_day(now())),
    'revenue_vnd_30d', (SELECT COALESCE(sum(c.amount_vnd), 0) FROM public.admin_store_actions c JOIN b ON b.id = c.store_id
                         WHERE c.created_at > now() - interval '30 days'),
    'contact', (SELECT value FROM public.platform_settings WHERE key = 'plan_contact'))
  INTO r;
  RETURN r;
END
$fn$;

-- p_filter: all | trial_ending | trial_expired | pro | pro_ending | pro_expired | pro_due (sắp + đã hết) | locked | follow_up
CREATE OR REPLACE FUNCTION public.admin_plan_list_v1(
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
  v_f text := COALESCE(p_filter, 'all');
  v_today date := public.qn_vn_day(now());
  r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF v_f NOT IN ('all', 'trial_ending', 'trial_expired', 'pro', 'pro_ending', 'pro_expired', 'pro_due', 'locked', 'follow_up') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_FILTER');
  END IF;
  WITH b AS (
    SELECT st.id, st.name, st.store_code, st.plan, st.status, st.trial_ends_at, st.plan_ends_at, st.created_at,
           public.qn_store_plan_notice(st.plan, st.status, st.trial_ends_at, st.plan_ends_at) AS notice,
           ow.display_name AS owner_name, ow.phone AS owner_phone,
           EXISTS (SELECT 1 FROM public.admin_test_stores t WHERE t.store_id = st.id) AS is_test,
           (SELECT count(*) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed'
               AND o.created_at > now() - interval '7 days') AS orders_7d,
           (SELECT max(o.created_at) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed') AS last_order_at,
           (SELECT min(n.follow_up_on) FROM public.admin_store_notes n
             WHERE n.store_id = st.id AND n.done_at IS NULL AND n.follow_up_on IS NOT NULL) AS next_follow_up,
           (SELECT left(n.body, 140) FROM public.admin_store_notes n WHERE n.store_id = st.id
             ORDER BY n.created_at DESC LIMIT 1) AS last_note
      FROM public.stores st
      -- chủ: ghi trên quán, thiếu thì thành viên đánh dấu chủ sớm nhất
      LEFT JOIN LATERAL (SELECT u.display_name, u.phone FROM public.user_accounts u
                          WHERE u.id = COALESCE(st.owner_user_id, (SELECT m.user_id FROM public.store_members m
                                                                    WHERE m.store_id = st.id AND m.is_owner
                                                                    ORDER BY m.created_at LIMIT 1))) ow ON true
     WHERE v_q IS NULL OR st.name ILIKE '%' || v_q || '%' OR st.store_code ILIKE '%' || v_q || '%'
  ), f AS (
    SELECT *, COALESCE(CASE WHEN plan = 'pro' THEN plan_ends_at ELSE trial_ends_at END, 'infinity'::timestamptz) AS ends_at
      FROM b
     WHERE (p_include_test OR NOT is_test) AND CASE v_f
             WHEN 'trial_ending' THEN notice = 'trial_ending'
             WHEN 'trial_expired' THEN notice = 'trial_expired'
             WHEN 'pro' THEN plan = 'pro'
             WHEN 'pro_ending' THEN notice = 'pro_ending'
             WHEN 'pro_expired' THEN notice = 'pro_expired'
             WHEN 'pro_due' THEN notice IN ('pro_ending', 'pro_expired')
             WHEN 'locked' THEN status = 'locked'
             WHEN 'follow_up' THEN next_follow_up <= v_today
             ELSE true END
  )
  SELECT jsonb_build_object('ok', true, 'total', (SELECT count(*) FROM f),
    'rows', COALESCE((SELECT jsonb_agg(to_jsonb(x) - 'ends_at' - 'rn' ORDER BY x.rn) FROM (
        -- còn hạn: hạn gần nhất trước; đã hết hạn: vừa hết gần đây trước (không để 169 quán hết hạn lâu chiếm trang đầu)
        SELECT f.*, row_number() OVER (ORDER BY
                 CASE WHEN v_f = 'follow_up' THEN f.next_follow_up END NULLS LAST,
                 (f.ends_at <= now()),
                 CASE WHEN f.ends_at > now() THEN f.ends_at END,
                 f.ends_at DESC, f.created_at DESC) AS rn
          FROM f ORDER BY rn LIMIT v_lim OFFSET v_off) x), '[]'::jsonb))
  INTO r;
  RETURN r;
END
$fn$;

-- 8) Thao tác (mỗi lần ghi admin_store_actions) ----------------------------------------------------------------------
-- Gia hạn dùng thử: cộng N ngày (1–365) tính từ max(hạn hiện tại, bây giờ). Chỉ quán gói free.
CREATE OR REPLACE FUNCTION public.admin_store_extend_trial_v1(p_store uuid, p_days int, p_note text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller(); s public.stores%ROWTYPE; v_before jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF p_days IS NULL OR p_days < 1 OR p_days > 365 THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_DAYS'); END IF;
  IF char_length(COALESCE(p_note, '')) > 500 THEN RETURN jsonb_build_object('ok', false, 'error', 'NOTE_TOO_LONG'); END IF;
  SELECT * INTO s FROM public.stores WHERE id = p_store FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND'); END IF;
  IF s.plan = 'pro' THEN RETURN jsonb_build_object('ok', false, 'error', 'PLAN_NOT_TRIAL'); END IF;
  v_before := public.qn_store_plan_snapshot(s);
  UPDATE public.stores
     SET trial_ends_at = GREATEST(COALESCE(trial_ends_at, now()), now()) + make_interval(days => p_days),
         status = CASE WHEN status = 'locked' THEN status ELSE 'trial' END
   WHERE id = p_store RETURNING * INTO s;
  INSERT INTO public.admin_store_actions (store_id, admin_id, action, before, after, note)
  VALUES (p_store, a, 'extend_trial', v_before, public.qn_store_plan_snapshot(s), NULLIF(btrim(p_note), ''));
  RETURN jsonb_build_object('ok', true, 'store', public.qn_store_plan_snapshot(s));
END
$fn$;

-- Đổi gói: 'pro' (hạn = p_ends_at, NULL = không thời hạn; phải sau bây giờ) | 'free' (về dùng thử, giữ hạn cũ).
-- Quán đang khoá vẫn giữ khoá. p_amount_vnd: số tiền đã thu (tuỳ chọn).
CREATE OR REPLACE FUNCTION public.admin_store_set_plan_v1(p_store uuid, p_plan text, p_ends_at timestamptz DEFAULT NULL,
                                                         p_amount_vnd bigint DEFAULT NULL, p_note text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller(); s public.stores%ROWTYPE; v_before jsonb;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF p_plan IS NULL OR p_plan NOT IN ('free', 'pro') THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_PLAN'); END IF;
  IF p_plan = 'pro' AND p_ends_at IS NOT NULL AND (p_ends_at <= now() OR p_ends_at > now() + interval '10 years') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_ENDS_AT');
  END IF;
  IF p_amount_vnd IS NOT NULL AND (p_amount_vnd < 0 OR p_amount_vnd > 10000000000) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_AMOUNT');
  END IF;
  IF char_length(COALESCE(p_note, '')) > 500 THEN RETURN jsonb_build_object('ok', false, 'error', 'NOTE_TOO_LONG'); END IF;
  SELECT * INTO s FROM public.stores WHERE id = p_store FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND'); END IF;
  v_before := public.qn_store_plan_snapshot(s);
  IF p_plan = 'pro' THEN
    UPDATE public.stores SET plan = 'pro', plan_ends_at = p_ends_at,
           status = CASE WHEN status = 'locked' THEN status ELSE 'active' END
     WHERE id = p_store RETURNING * INTO s;
  ELSE
    UPDATE public.stores SET plan = 'free', plan_ends_at = NULL,
           status = CASE WHEN status = 'locked' THEN status ELSE 'trial' END
     WHERE id = p_store RETURNING * INTO s;
  END IF;
  INSERT INTO public.admin_store_actions (store_id, admin_id, action, before, after, amount_vnd, note)
  VALUES (p_store, a, 'set_plan', v_before, public.qn_store_plan_snapshot(s), p_amount_vnd, NULLIF(btrim(p_note), ''));
  RETURN jsonb_build_object('ok', true, 'store', public.qn_store_plan_snapshot(s));
END
$fn$;

-- Khoá / mở quán. Khoá: lý do bắt buộc (3–500 ký tự). Mở: về 'active' (pro) / 'trial'.
-- KHÔNG thu hồi phiên: đăng nhập lại vẫn được cấp vé mới (QC 27/10) nên thu hồi vô tác dụng; giữ phiên để app hỏi được
-- trạng thái, hiện màn khoá, và dùng lại ngay khi mở khoá. Dữ liệu đã bị chặn ở current_store_id + 2 cổng.
CREATE OR REPLACE FUNCTION public.admin_store_set_locked_v1(p_store uuid, p_locked boolean, p_reason text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller(); s public.stores%ROWTYPE; v_before jsonb; v_reason text := btrim(COALESCE(p_reason, ''));
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF p_locked IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_PARAMS'); END IF;
  IF char_length(v_reason) > 500 THEN RETURN jsonb_build_object('ok', false, 'error', 'NOTE_TOO_LONG'); END IF;
  IF p_locked AND char_length(v_reason) < 3 THEN RETURN jsonb_build_object('ok', false, 'error', 'REASON_REQUIRED'); END IF;
  SELECT * INTO s FROM public.stores WHERE id = p_store FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND'); END IF;
  IF p_locked = (s.status = 'locked') THEN RETURN jsonb_build_object('ok', false, 'error', 'NO_CHANGE'); END IF;
  v_before := public.qn_store_plan_snapshot(s);
  IF p_locked THEN
    UPDATE public.stores SET status = 'locked' WHERE id = p_store RETURNING * INTO s;
  ELSE
    UPDATE public.stores SET status = CASE WHEN plan = 'pro' THEN 'active' ELSE 'trial' END
     WHERE id = p_store RETURNING * INTO s;
  END IF;
  INSERT INTO public.admin_store_actions (store_id, admin_id, action, before, after, note)
  VALUES (p_store, a, CASE WHEN p_locked THEN 'lock' ELSE 'unlock' END, v_before, public.qn_store_plan_snapshot(s),
          NULLIF(v_reason, ''));
  RETURN jsonb_build_object('ok', true, 'store', public.qn_store_plan_snapshot(s));
END
$fn$;

-- Sổ chăm sóc quán
CREATE OR REPLACE FUNCTION public.admin_store_note_add_v1(p_store uuid, p_body text, p_follow_up_on date DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller(); v_body text := btrim(COALESCE(p_body, '')); v_id bigint;
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF char_length(v_body) < 1 OR char_length(v_body) > 2000 THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_BODY'); END IF;
  IF p_follow_up_on IS NOT NULL AND (p_follow_up_on < public.qn_vn_day(now()) - 1
                                     OR p_follow_up_on > public.qn_vn_day(now()) + 366) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_DATE');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.stores WHERE id = p_store) THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND'); END IF;
  INSERT INTO public.admin_store_notes (store_id, admin_id, body, follow_up_on) VALUES (p_store, a, v_body, p_follow_up_on)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END
$fn$;

CREATE OR REPLACE FUNCTION public.admin_store_note_done_v1(p_id bigint, p_done boolean)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  UPDATE public.admin_store_notes SET done_at = CASE WHEN COALESCE(p_done, false) THEN now() END,
         done_by = CASE WHEN COALESCE(p_done, false) THEN a END
   WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND'); END IF;
  RETURN jsonb_build_object('ok', true);
END
$fn$;

-- Câu liên hệ hiện trong dải nhắc ở app (rỗng → app dùng câu mặc định)
CREATE OR REPLACE FUNCTION public.admin_platform_setting_set_v1(p_key text, p_value text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller(); v text := btrim(COALESCE(p_value, ''));
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF p_key IS DISTINCT FROM 'plan_contact' THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_KEY'); END IF;
  IF char_length(v) > 300 THEN RETURN jsonb_build_object('ok', false, 'error', 'TOO_LONG'); END IF;
  IF v = '' THEN
    DELETE FROM public.platform_settings WHERE key = p_key;
  ELSE
    INSERT INTO public.platform_settings (key, value, updated_by, updated_at) VALUES (p_key, v, a, now())
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_by = EXCLUDED.updated_by, updated_at = now();
  END IF;
  RETURN jsonb_build_object('ok', true);
END
$fn$;

-- 9) Danh sách quán: "máy" = thiết bị có ghi nhật ký trong 30 ngày (bảng devices không được app ghi → luôn 0) ------
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
    SELECT st.id, st.name, st.store_code, st.plan, st.status, st.trial_ends_at, st.plan_ends_at, st.last_active_at, st.created_at,
           (SELECT display_name FROM public.user_accounts u WHERE u.id = st.owner_user_id) AS owner_name,
           EXISTS (SELECT 1 FROM public.admin_test_stores t WHERE t.store_id = st.id) AS is_test,
           (SELECT count(*) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed'
               AND o.created_at > now() - interval '7 days') AS orders_7d,
           (SELECT count(*) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed'
               AND o.created_at > now() - interval '30 days') AS orders_30d,
           (SELECT max(o.created_at) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed') AS last_order_at,
           (SELECT count(DISTINCT l.device_id) FROM public.app_logs l WHERE l.store_id = st.id
               AND l.created_at > now() - interval '30 days' AND l.device_id IS NOT NULL AND l.device_id <> 'Unknown') AS devices,
           (SELECT max(l.created_at) FROM public.app_logs l WHERE l.store_id = st.id
               AND l.created_at > now() - interval '30 days') AS device_last_seen,
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

-- 10) Quyền ----------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.admin_store_detail_v1(uuid), public.admin_plan_overview_v1(boolean),
  public.admin_plan_list_v1(text, text, boolean, int, int), public.admin_store_extend_trial_v1(uuid, int, text),
  public.admin_store_set_plan_v1(uuid, text, timestamptz, bigint, text), public.admin_store_set_locked_v1(uuid, boolean, text),
  public.admin_store_note_add_v1(uuid, text, date), public.admin_store_note_done_v1(bigint, boolean),
  public.admin_platform_setting_set_v1(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_store_detail_v1(uuid), public.admin_plan_overview_v1(boolean),
  public.admin_plan_list_v1(text, text, boolean, int, int), public.admin_store_extend_trial_v1(uuid, int, text),
  public.admin_store_set_plan_v1(uuid, text, timestamptz, bigint, text), public.admin_store_set_locked_v1(uuid, boolean, text),
  public.admin_store_note_add_v1(uuid, text, date), public.admin_store_note_done_v1(bigint, boolean),
  public.admin_platform_setting_set_v1(text, text) TO qn_admin;
-- admin_store_list_v1: CREATE OR REPLACE giữ nguyên quyền cũ (chỉ qn_admin)

-- 11) Kiểm tra sau áp
DO $$
BEGIN
  IF has_table_privilege('authenticated', 'public.admin_store_actions', 'select')
     OR has_table_privilege('authenticated', 'public.admin_store_notes', 'select')
     OR has_table_privilege('qn_admin', 'public.admin_store_notes', 'select')
     OR has_table_privilege('anon', 'public.platform_settings', 'select')
     OR has_function_privilege('authenticated', 'public.admin_store_set_locked_v1(uuid,boolean,text)', 'execute')
     OR has_function_privilege('anon', 'public.admin_store_detail_v1(uuid)', 'execute')
     OR has_function_privilege('authenticated', 'public.admin_store_list_v1(text,text,boolean,int,int)', 'execute')
     OR NOT has_function_privilege('qn_admin', 'public.admin_store_list_v1(text,text,boolean,int,int)', 'execute')
     OR NOT has_function_privilege('authenticated', 'public.store_plan_status_v1(uuid)', 'execute')
     OR has_function_privilege('anon', 'public.store_plan_status_v1(uuid)', 'execute')
     OR has_function_privilege('anon', 'public.store_self_extend_trial_v1(uuid)', 'execute')
     OR NOT has_function_privilege('authenticated', 'public.store_self_extend_trial_v1(uuid)', 'execute') THEN
    RAISE EXCEPTION 'QUAN TRI DOT 1: quyền không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
