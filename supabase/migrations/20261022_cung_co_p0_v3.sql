-- ============================================================================
-- CỦNG CỐ P0 v3 (22/10/2026) — vá các lỗ do QC vòng 3 (tấn công thử trên bản sao) và
-- phiên khảo sát đăng nhập JWT (K1–K3 trong .docs/ke-hoach-dang-nhap-jwt.md) tìm ra.
--   K1. publish_app_version_v1: anon gọi được → ai cũng đăng "bản cập nhật bắt buộc" giả với
--       đường tải tuỳ ý. App chỉ ĐỌC app_versions. → chỉ service_role/quản trị.
--       LƯU Ý: scripts/qn_release.py rơi về khoá anon nếu thiếu SUPABASE_SERVICE_ROLE_KEY →
--       sau khi áp phải đặt khoá đó, hoặc phát hành bằng SQL như db-fix/phat_hanh_105_app_versions.sql.
--   K2. lookup_staff_by_phone: anon/authenticated gọi được, lộ id/vai trò nhân viên; app không dùng.
--   K3. revoke_store_member: tin header; app dùng admin_revoke_staff_membership_v4 → bỏ quyền gọi.
--   A.  app_settings: nhân viên ghi được 'action_perms_<vai trò>' / 'perm_<vai trò>' qua API
--       (tự cấp quyền thu tiền — máy chủ đọc action_perms_*) → chỉ Chủ quán/Quản lý (qn_is_manager).
--   B.  ban_sessions: phiên đã đóng/đã huỷ vẫn sửa được total/total_amount/guest_count/waiter_id
--       → khoá toàn bộ dòng khi status <> 'open' (đổi trạng thái đã do guard_ban_session_status_v1).
--   C.  finance_records: nhân viên không có module Thu Chi vẫn ghi được phiếu NHẬP TAY qua API
--       → phiếu is_auto=false chỉ Chủ quán/Quản lý hoặc vai trò có module 'finance' (tính module
--       giống app: store_roles theo tên/loại vai trò, staff_members.modules, app_settings perm_*).
--       Phiếu tự động (bán hàng, kho, lương) vẫn mở vì app đang tự ghi — chặn sau khi chuyển về máy chủ.
-- KHÔNG làm ở đây (ghi trong viec-can-sua): app_logs INSERT theo quán (sẽ làm mất log lúc đăng
--   xuất — chờ đăng nhập JWT); finance_records INSERT, customers/balance_transactions ghi trực
--   tiếp (app hiện vẫn tự ghi — cần app mới trên mọi máy); phiếu thu chi tự động (is_auto=true).
-- Rollback: 20261022_cung_co_p0_v3_ROLLBACK.sql
-- ============================================================================

DO $pf$
BEGIN
  IF to_regprocedure('public.qn_is_manager(uuid)') IS NULL THEN
    RAISE EXCEPTION 'PREFLIGHT: thiếu qn_is_manager (cần 20261022_khoa_ghi_phan_quyen_v1.sql)';
  END IF;
  RAISE NOTICE 'PREFLIGHT cung_co_p0_v3: OK';
END
$pf$;

-- K1–K3: thu quyền gọi hàm ------------------------------------------------------------
DO $k$
BEGIN
  IF to_regprocedure('public.publish_app_version_v1(text,text,integer,text,text,boolean)') IS NOT NULL THEN
    REVOKE EXECUTE ON FUNCTION public.publish_app_version_v1(text,text,integer,text,text,boolean) FROM PUBLIC, anon, authenticated;
    GRANT EXECUTE ON FUNCTION public.publish_app_version_v1(text,text,integer,text,text,boolean) TO service_role;
  END IF;
  IF to_regprocedure('public.lookup_staff_by_phone(text)') IS NOT NULL THEN
    REVOKE EXECUTE ON FUNCTION public.lookup_staff_by_phone(text) FROM PUBLIC, anon, authenticated;
    GRANT EXECUTE ON FUNCTION public.lookup_staff_by_phone(text) TO service_role;
  END IF;
  IF to_regprocedure('public.revoke_store_member(uuid,uuid,uuid)') IS NOT NULL THEN
    REVOKE EXECUTE ON FUNCTION public.revoke_store_member(uuid,uuid,uuid) FROM PUBLIC, anon, authenticated;
    GRANT EXECUTE ON FUNCTION public.revoke_store_member(uuid,uuid,uuid) TO service_role;
  END IF;
END
$k$;

-- A. Cài đặt quyền chỉ Chủ quán/Quản lý ghi -----------------------------------------------
CREATE OR REPLACE FUNCTION public.app_setting_is_permission_key(p_key text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_catalog, pg_temp
AS $fn$
  SELECT COALESCE(p_key, '') LIKE 'action\_perms\_%' OR COALESCE(p_key, '') LIKE 'perm\_%';
$fn$;

CREATE OR REPLACE FUNCTION public.guard_app_settings_perms_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_store uuid := COALESCE(NEW.store_id, OLD.store_id);
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  IF (TG_OP <> 'INSERT' AND public.app_setting_is_permission_key(OLD.key))
     OR (TG_OP <> 'DELETE' AND public.app_setting_is_permission_key(NEW.key)) THEN
    IF NOT public.qn_is_manager(v_store) THEN
      RAISE EXCEPTION 'PERMISSION_SETTING_LOCKED: Chỉ Chủ quán hoặc Quản lý được đổi phân quyền'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN COALESCE(NEW, OLD);
END
$fn$;

DROP TRIGGER IF EXISTS guard_app_settings_perms_v1 ON public.app_settings;
CREATE TRIGGER guard_app_settings_perms_v1
  BEFORE INSERT OR UPDATE OR DELETE ON public.app_settings
  FOR EACH ROW EXECUTE FUNCTION public.guard_app_settings_perms_v1();

-- B. Phiên bàn đã đóng/huỷ: khoá toàn bộ dòng ----------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_ban_session_closed_row_v3()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog, pg_temp
AS $fn$
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN NEW;
  END IF;
  IF COALESCE(OLD.status, '') <> 'open' AND ROW(NEW.*) IS DISTINCT FROM ROW(OLD.*) THEN
    RAISE EXCEPTION 'BAN_SESSION_FINAL: Phiên bàn đã đóng/huỷ, không sửa được'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END
$fn$;

DROP TRIGGER IF EXISTS guard_ban_session_closed_row_v3 ON public.ban_sessions;
CREATE TRIGGER guard_ban_session_closed_row_v3
  BEFORE UPDATE ON public.ban_sessions
  FOR EACH ROW EXECUTE FUNCTION public.guard_ban_session_closed_row_v3();

-- C. Phiếu thu chi nhập tay chỉ cho người có quyền Thu Chi ---------------------------------
-- Loại vai trò chuẩn — giống StaffService.canonicalRole trong app.
CREATE OR REPLACE FUNCTION public.qn_canonical_role(p_role text)
RETURNS text
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_catalog, pg_temp
AS $fn$
  SELECT CASE
    WHEN n ~ '(owner|chủ quán|chu quan)' OR n IN ('chủ', 'chu') THEN 'owner'
    WHEN n ~ '(manager|quản lý|quan ly|quản trị|quan tri|admin)' OR n = 'ql' THEN 'manager'
    WHEN n ~ '(cashier|thu ngân|thu ngan|quầy|quay|bán hàng|ban hang)' OR n = 'tn' THEN 'cashier'
    WHEN n ~ '(waiter|waitress|phục vụ|phuc vu|chạy bàn|chay ban)' OR n = 'pv' THEN 'waiter'
    WHEN n ~ '(kitchen|bếp|bep|đầu bếp|dau bep|chef|cook)' THEN 'kitchen'
    WHEN n ~ '(stock|kho)' THEN 'stock'
    ELSE n
  END
  FROM (SELECT lower(btrim(COALESCE(p_role, ''))) AS n) x;
$fn$;

-- Người gọi (theo phiên app) có module p_module ở quán p_store không.
CREATE OR REPLACE FUNCTION public.qn_caller_has_module(p_store uuid, p_module text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_uid  uuid := public.qn_caller_id();
  v_role text;
  v_canon text;
BEGIN
  IF v_uid IS NULL OR p_store IS NULL THEN RETURN false; END IF;
  IF public.qn_is_manager(p_store) THEN RETURN true; END IF;
  SELECT role INTO v_role FROM public.store_members WHERE store_id = p_store AND user_id = v_uid LIMIT 1;
  IF v_role IS NULL THEN RETURN false; END IF;   -- không còn là thành viên
  v_canon := public.qn_canonical_role(v_role);
  IF v_canon IN ('owner', 'manager') THEN RETURN true; END IF;
  -- Module theo vai trò của quán (khớp tên hoặc cùng loại chuẩn).
  IF EXISTS (
    SELECT 1 FROM public.store_roles sr
    WHERE sr.store_id = p_store
      AND (lower(btrim(sr.name)) = lower(btrim(v_role)) OR public.qn_canonical_role(sr.name) = v_canon)
      AND CASE WHEN btrim(COALESCE(sr.modules::text, '')) ~ '^\[' THEN sr.modules::jsonb ? p_module ELSE false END
  ) THEN RETURN true; END IF;
  -- Module gán riêng cho nhân viên.
  IF EXISTS (
    SELECT 1 FROM public.staff_members sm
    WHERE sm.store_id = p_store AND sm.id = v_uid
      AND jsonb_typeof(sm.modules) = 'array' AND sm.modules ? p_module
  ) THEN RETURN true; END IF;
  -- Cài đặt kiểu cũ app_settings perm_<vai trò>.
  IF EXISTS (
    SELECT 1 FROM public.app_settings s
    WHERE s.store_id = p_store AND s.key IN ('perm_' || v_role, 'perm_' || v_canon)
      AND CASE WHEN btrim(COALESCE(s.value, '')) ~ '^\[' THEN s.value::jsonb ? p_module ELSE false END
  ) THEN RETURN true; END IF;
  RETURN false;
EXCEPTION WHEN OTHERS THEN
  RETURN false;
END
$fn$;
REVOKE ALL ON FUNCTION public.qn_caller_has_module(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qn_caller_has_module(uuid, text) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.guard_finance_manual_insert_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog, pg_temp
AS $fn$
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') OR COALESCE(NEW.is_auto, false) THEN
    RETURN NEW;
  END IF;
  IF NOT public.qn_caller_has_module(NEW.store_id, 'finance') THEN
    RAISE EXCEPTION 'FINANCE_MANUAL_DENIED: Chỉ người có quyền Thu Chi được ghi phiếu thu/chi'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END
$fn$;

DROP TRIGGER IF EXISTS guard_finance_manual_insert_v1 ON public.finance_records;
CREATE TRIGGER guard_finance_manual_insert_v1
  BEFORE INSERT ON public.finance_records
  FOR EACH ROW EXECUTE FUNCTION public.guard_finance_manual_insert_v1();

NOTIFY pgrst, 'reload schema';

DO $chk$
BEGIN
  IF has_function_privilege('anon', 'public.publish_app_version_v1(text,text,integer,text,text,boolean)', 'EXECUTE')
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'guard_app_settings_perms_v1')
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'guard_ban_session_closed_row_v3')
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'guard_finance_manual_insert_v1')
     OR public.qn_canonical_role('Thu ngân') <> 'cashier' THEN
    RAISE EXCEPTION 'POSTCHECK cung_co_p0_v3: chưa đủ';
  END IF;
  RAISE NOTICE 'POSTCHECK cung_co_p0_v3: OK';
END
$chk$;
