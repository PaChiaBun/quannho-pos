-- ============================================================================
-- KHOÁ DUYỆT & TRẢ LƯƠNG (22/10/2026) — P0-5 trong .docs/Huong_dan/viec-can-sua.md
-- Lỗi cũ: payroll_periods / payroll_records chỉ có RLS theo quán — ai có module Tính lương
--   (hoặc gọi API) đều duyệt kỳ, trả lương, sửa số tiền kể cả sau khi kỳ đã duyệt.
--   Đặc tả (quy-chuan-cham-cong-tinh-luong-chuan.md mục 5): chỉ Chủ quán duyệt kỳ;
--   đã duyệt là khoá số liệu.
-- Sửa (chỉ vai trò anon/authenticated; RPC SECURITY DEFINER và quản trị không bị chặn):
--   * kỳ lương: chuyển sang approved/paid chỉ Chủ quán; kỳ đã approved/paid không sửa/xoá
--     (trừ Chủ quán chuyển approved → paid);
--   * phiếu lương: kỳ chưa duyệt thì không được đổi trạng thái trả; kỳ đã duyệt thì khoá
--     mọi cột tiền, không thêm/xoá phiếu; trả lương (pending → pending_staff_confirm) chỉ
--     Chủ quán/Quản lý; xác nhận đã nhận (pending_staff_confirm → paid) chỉ đúng nhân viên
--     đó hoặc Chủ quán; đổi trạng thái khác chỉ Chủ quán.
-- Hiện production chưa có kỳ nào approved/paid → không ảnh hưởng dữ liệu cũ.
-- Rollback: 20261022_khoa_duyet_tra_luong_v1_ROLLBACK.sql
-- ============================================================================

DO $pf$
BEGIN
  IF to_regprocedure('public.verify_staff_qr_membership_v4(uuid,boolean,boolean)') IS NULL THEN
    RAISE EXCEPTION 'PREFLIGHT: thiếu verify_staff_qr_membership_v4';
  END IF;
  RAISE NOTICE 'PREFLIGHT khoa_duyet_tra_luong_v1: OK';
END
$pf$;

-- Người đang thao tác (theo phiên app). Không xác định được → uid NULL, không quyền gì.
CREATE OR REPLACE FUNCTION public.payroll_actor_v1(p_store_id uuid,
  OUT uid uuid, OUT is_owner boolean, OUT is_manager boolean)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE v_m record;
BEGIN
  is_owner := false; is_manager := false;
  BEGIN
    SELECT * INTO v_m FROM public.verify_staff_qr_membership_v4(p_store_id, false, false);
  EXCEPTION WHEN OTHERS THEN
    RETURN;
  END;
  uid := v_m.member_user_id;
  is_owner := COALESCE(v_m.is_owner_member, false) OR lower(COALESCE(v_m.member_role, '')) = 'owner';
  is_manager := is_owner OR lower(COALESCE(v_m.member_role, '')) IN ('manager', 'admin');
END
$fn$;
-- Trigger chạy với vai trò của app nên app cần quyền gọi; hàm chỉ trả về danh tính của chính người gọi.
REVOKE ALL ON FUNCTION public.payroll_actor_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.payroll_actor_v1(uuid) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.guard_payroll_periods_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_a record;
  v_old_locked boolean;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF COALESCE(NEW.status, 'draft') IN ('approved', 'paid') THEN
      SELECT * INTO v_a FROM public.payroll_actor_v1(NEW.store_id);
      IF NOT v_a.is_owner THEN
        RAISE EXCEPTION 'PAYROLL_OWNER_ONLY: Chỉ Chủ quán được duyệt kỳ lương' USING ERRCODE = '42501';
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  v_old_locked := COALESCE(OLD.status, '') IN ('approved', 'paid');

  IF TG_OP = 'DELETE' THEN
    IF v_old_locked THEN
      RAISE EXCEPTION 'PAYROLL_LOCKED: Kỳ lương đã duyệt/đã trả, không xoá được' USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;

  IF v_old_locked THEN
    -- Chỉ cho Chủ quán chuyển approved → paid (kèm paid_at/locked_at); mọi thay đổi khác bị chặn.
    IF OLD.status = 'approved' AND NEW.status = 'paid'
       AND ROW(NEW.store_id, NEW.name, NEW.period_type, NEW.from_date, NEW.to_date, NEW.total_amount,
               NEW.approval_config, NEW.current_step, NEW.note, NEW.created_by)
           IS NOT DISTINCT FROM
           ROW(OLD.store_id, OLD.name, OLD.period_type, OLD.from_date, OLD.to_date, OLD.total_amount,
               OLD.approval_config, OLD.current_step, OLD.note, OLD.created_by) THEN
      SELECT * INTO v_a FROM public.payroll_actor_v1(OLD.store_id);
      IF v_a.is_owner THEN RETURN NEW; END IF;
      RAISE EXCEPTION 'PAYROLL_OWNER_ONLY: Chỉ Chủ quán được chốt đã trả kỳ lương' USING ERRCODE = '42501';
    END IF;
    IF ROW(NEW.*) IS NOT DISTINCT FROM ROW(OLD.*) THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'PAYROLL_LOCKED: Kỳ lương đã duyệt/đã trả, số liệu bị khoá' USING ERRCODE = '42501';
  END IF;

  IF COALESCE(NEW.status, 'draft') IN ('approved', 'paid') THEN
    SELECT * INTO v_a FROM public.payroll_actor_v1(OLD.store_id);
    IF NOT v_a.is_owner THEN
      RAISE EXCEPTION 'PAYROLL_OWNER_ONLY: Chỉ Chủ quán được duyệt kỳ lương' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END
$fn$;

DROP TRIGGER IF EXISTS guard_payroll_periods_v1 ON public.payroll_periods;
CREATE TRIGGER guard_payroll_periods_v1
  BEFORE INSERT OR UPDATE OR DELETE ON public.payroll_periods
  FOR EACH ROW EXECUTE FUNCTION public.guard_payroll_periods_v1();

CREATE OR REPLACE FUNCTION public.guard_payroll_records_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_a       record;
  v_status  text;
  v_locked  boolean;
  v_old_pay text;
  v_new_pay text;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Đọc trạng thái kỳ với quyền của app (RLS giới hạn đúng quán).
  SELECT status INTO v_status FROM public.payroll_periods
  WHERE id = CASE WHEN TG_OP = 'DELETE' THEN OLD.period_id ELSE NEW.period_id END;
  v_locked := COALESCE(v_status, '') IN ('approved', 'paid');

  IF TG_OP = 'UPDATE' AND NEW.period_id IS DISTINCT FROM OLD.period_id THEN
    RAISE EXCEPTION 'PAYROLL_LOCKED: Không chuyển phiếu lương sang kỳ khác' USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'DELETE' THEN
    IF v_locked THEN
      RAISE EXCEPTION 'PAYROLL_LOCKED: Kỳ lương đã duyệt, không xoá phiếu lương' USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF v_locked THEN
      RAISE EXCEPTION 'PAYROLL_LOCKED: Kỳ lương đã duyệt, không thêm phiếu lương' USING ERRCODE = '42501';
    END IF;
    IF COALESCE(NEW.payment_status, 'pending') <> 'pending' THEN
      RAISE EXCEPTION 'PAYROLL_NOT_APPROVED: Chưa duyệt kỳ thì chưa trả lương' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE
  v_old_pay := COALESCE(OLD.payment_status, 'pending');
  v_new_pay := COALESCE(NEW.payment_status, 'pending');

  IF NOT v_locked THEN
    IF v_new_pay IS DISTINCT FROM v_old_pay OR NEW.paid_at IS DISTINCT FROM OLD.paid_at
       OR NEW.payment_method IS DISTINCT FROM OLD.payment_method THEN
      RAISE EXCEPTION 'PAYROLL_NOT_APPROVED: Chưa duyệt kỳ thì chưa trả lương' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- Kỳ đã duyệt: chỉ được đổi 3 cột trả lương.
  IF ROW(NEW.store_id, NEW.user_id, NEW.staff_name, NEW.role, NEW.salary_mode, NEW.base_salary, NEW.hourly_rate,
         NEW.total_hours, NEW.overtime_hours, NEW.regular_pay, NEW.overtime_pay, NEW.bonus_revenue, NEW.bonus_manual,
         NEW.deduction_late, NEW.deduction_absent, NEW.deduction_manual, NEW.allowance_total, NEW.gross_pay,
         NEW.net_pay, NEW.absent_days, NEW.late_count, NEW.note, NEW.created_at)
     IS DISTINCT FROM
     ROW(OLD.store_id, OLD.user_id, OLD.staff_name, OLD.role, OLD.salary_mode, OLD.base_salary, OLD.hourly_rate,
         OLD.total_hours, OLD.overtime_hours, OLD.regular_pay, OLD.overtime_pay, OLD.bonus_revenue, OLD.bonus_manual,
         OLD.deduction_late, OLD.deduction_absent, OLD.deduction_manual, OLD.allowance_total, OLD.gross_pay,
         OLD.net_pay, OLD.absent_days, OLD.late_count, OLD.note, OLD.created_at) THEN
    RAISE EXCEPTION 'PAYROLL_LOCKED: Kỳ lương đã duyệt, số liệu bị khoá' USING ERRCODE = '42501';
  END IF;

  IF v_new_pay = v_old_pay AND NEW.paid_at IS NOT DISTINCT FROM OLD.paid_at
     AND NEW.payment_method IS NOT DISTINCT FROM OLD.payment_method THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_a FROM public.payroll_actor_v1(OLD.store_id);

  IF v_old_pay = 'pending' AND v_new_pay = 'pending_staff_confirm' THEN
    IF v_a.is_manager THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'PAYROLL_PAY_DENIED: Chỉ Chủ quán hoặc Quản lý được trả lương' USING ERRCODE = '42501';
  END IF;

  IF v_old_pay = 'pending_staff_confirm' AND v_new_pay = 'paid'
     AND NEW.paid_at IS NOT DISTINCT FROM OLD.paid_at
     AND NEW.payment_method IS NOT DISTINCT FROM OLD.payment_method THEN
    IF v_a.is_owner OR (v_a.uid IS NOT NULL AND v_a.uid = OLD.user_id) THEN RETURN NEW; END IF;
    RAISE EXCEPTION 'PAYROLL_CONFIRM_DENIED: Chỉ nhân viên nhận lương được xác nhận đã nhận' USING ERRCODE = '42501';
  END IF;

  IF v_a.is_owner THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'PAYROLL_OWNER_ONLY: Chỉ Chủ quán được đổi trạng thái trả lương này' USING ERRCODE = '42501';
END
$fn$;

DROP TRIGGER IF EXISTS guard_payroll_records_v1 ON public.payroll_records;
CREATE TRIGGER guard_payroll_records_v1
  BEFORE INSERT OR UPDATE OR DELETE ON public.payroll_records
  FOR EACH ROW EXECUTE FUNCTION public.guard_payroll_records_v1();

DO $chk$
BEGIN
  IF (SELECT count(*) FROM pg_trigger WHERE tgname IN ('guard_payroll_periods_v1', 'guard_payroll_records_v1')) <> 2 THEN
    RAISE EXCEPTION 'POSTCHECK: thiếu trigger khoá lương';
  END IF;
  RAISE NOTICE 'POSTCHECK khoa_duyet_tra_luong_v1: OK';
END
$chk$;
