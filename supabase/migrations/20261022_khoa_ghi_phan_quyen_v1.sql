-- ============================================================================
-- KHÓA GHI PHÂN QUYỀN v1 (22/10/2026)
-- Vấn đề: store_roles và staff_members có chính sách RLS chỉ kiểm "thuộc quán",
-- và authenticated có INSERT/UPDATE/DELETE → bất kỳ nhân viên nào gọi thẳng API
-- cũng sửa được danh sách module của vai trò mình, đổi vai trò/lương trong staff_members.
-- Cách khóa: trigger BEFORE (SECURITY INVOKER) chỉ áp cho người gọi qua API
-- (current_user = anon/authenticated). Hàm SECURITY DEFINER, service_role, postgres không bị ảnh hưởng.
--   store_roles   : chỉ Chủ quán / Quản lý (qn_is_manager) được INSERT/UPDATE/DELETE.
--   staff_members : Chủ quán toàn quyền. Quản lý không đụng được dòng Chủ quán/Quản lý khác
--                   và không nâng ai lên owner/manager. Người khác chỉ ghi được dòng CỦA MÌNH,
--                   và máy chủ ÉP: role = vai trò thật trong store_members, modules/lương/PIN/is_active giữ nguyên.
-- Hoàn tác: 20261022_khoa_ghi_phan_quyen_v1_ROLLBACK.sql
-- ============================================================================

CREATE OR REPLACE FUNCTION public.qn_guard_store_roles_write()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_store uuid := COALESCE(NEW.store_id, OLD.store_id);
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  IF NOT public.qn_is_manager(v_store) THEN
    RAISE EXCEPTION 'Chỉ Chủ quán hoặc Quản lý mới được sửa vai trò và phân quyền'
      USING ERRCODE = '42501', HINT = 'QN_ROLES_WRITE_FORBIDDEN';
  END IF;
  -- Không cho chuyển dòng vai trò sang quán khác.
  IF TG_OP = 'UPDATE' AND NEW.store_id IS DISTINCT FROM OLD.store_id THEN
    RAISE EXCEPTION 'Không được đổi quán của vai trò' USING ERRCODE = '42501';
  END IF;
  RETURN COALESCE(NEW, OLD);
END
$$;

CREATE OR REPLACE FUNCTION public.qn_guard_staff_members_write()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_store uuid := COALESCE(NEW.store_id, OLD.store_id);
  v_caller uuid := public.qn_caller_id();
  v_is_owner boolean;
  v_member_role text;
  v_own boolean;
  v_old_role text;
  v_new_role text;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.store_id IS DISTINCT FROM OLD.store_id THEN
    RAISE EXCEPTION 'Không được đổi quán của nhân viên' USING ERRCODE = '42501';
  END IF;

  -- ── Chủ quán / Quản lý ──────────────────────────────────────────────────
  IF public.qn_is_manager(v_store) THEN
    v_is_owner := public.qn_is_store_owner(v_store);
    IF NOT v_is_owner THEN
      v_old_role := CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE public.normalize_role_code_v4(OLD.role) END;
      v_new_role := CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE public.normalize_role_code_v4(NEW.role) END;
      -- Quản lý không được tạo/nâng ai lên owner/manager, và không sửa/xóa Chủ quán/Quản lý khác (trừ chính mình).
      IF v_new_role IN ('owner', 'manager') AND (TG_OP = 'INSERT' OR v_new_role IS DISTINCT FROM v_old_role) THEN
        RAISE EXCEPTION 'Quản lý không được gán vai trò Quản lý hoặc Chủ quán'
          USING ERRCODE = '42501', HINT = 'QN_STAFF_HIERARCHY';
      END IF;
      IF v_old_role IN ('owner', 'manager') AND COALESCE(OLD.id, '00000000-0000-0000-0000-000000000000'::uuid) IS DISTINCT FROM v_caller THEN
        RAISE EXCEPTION 'Quản lý không được sửa hoặc xóa Chủ quán / Quản lý khác'
          USING ERRCODE = '42501', HINT = 'QN_STAFF_HIERARCHY';
      END IF;
    END IF;
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- ── Người không phải chủ/quản lý ────────────────────────────────────────
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Không có quyền xóa nhân viên' USING ERRCODE = '42501', HINT = 'QN_STAFF_WRITE_FORBIDDEN';
  END IF;

  SELECT m.role,
         (m.user_id = COALESCE(NEW.id, OLD.id) OR m.id = COALESCE(NEW.id, OLD.id))
    INTO v_member_role, v_own
  FROM public.store_members m
  WHERE m.store_id = v_store AND m.user_id = v_caller
  LIMIT 1;

  IF v_caller IS NULL OR v_member_role IS NULL OR v_own IS NOT TRUE THEN
    RAISE EXCEPTION 'Chỉ được cập nhật hồ sơ của chính mình'
      USING ERRCODE = '42501', HINT = 'QN_STAFF_WRITE_FORBIDDEN';
  END IF;

  -- Ép các cột nhạy cảm: người thường không tự đổi vai trò, module, lương, PIN, trạng thái.
  NEW.role := v_member_role;
  IF TG_OP = 'INSERT' THEN
    NEW.modules := '[]'::jsonb;
    NEW.hourly_rate := 0;
    NEW.pin_hash := NULL;
  ELSE
    NEW.modules := OLD.modules;
    NEW.hourly_rate := OLD.hourly_rate;
    NEW.pin_hash := OLD.pin_hash;
    NEW.is_active := OLD.is_active;
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS qn_guard_store_roles_write ON public.store_roles;
CREATE TRIGGER qn_guard_store_roles_write
  BEFORE INSERT OR UPDATE OR DELETE ON public.store_roles
  FOR EACH ROW EXECUTE FUNCTION public.qn_guard_store_roles_write();

DROP TRIGGER IF EXISTS qn_guard_staff_members_write ON public.staff_members;
CREATE TRIGGER qn_guard_staff_members_write
  BEFORE INSERT OR UPDATE OR DELETE ON public.staff_members
  FOR EACH ROW EXECUTE FUNCTION public.qn_guard_staff_members_write();

-- Kiểm tra sau khi áp: hai trigger phải tồn tại.
DO $$
BEGIN
  IF (SELECT count(*) FROM pg_trigger
       WHERE tgname IN ('qn_guard_store_roles_write', 'qn_guard_staff_members_write') AND NOT tgisinternal) <> 2 THEN
    RAISE EXCEPTION 'KHOA GHI PHAN QUYEN v1: thiếu trigger sau khi áp';
  END IF;
  RAISE NOTICE 'KHOA GHI PHAN QUYEN v1: đã áp 2 trigger';
END $$;
