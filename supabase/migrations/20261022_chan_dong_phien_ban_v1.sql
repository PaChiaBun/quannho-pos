-- ============================================================================
-- CHẶN CLIENT TỰ ĐÓNG PHIÊN BÀN KHI CHƯA THANH TOÁN (22/10/2026)
-- Lỗ hổng: nút "X" ở cột "Đang phục vụ" (app ≤ 1.0.5+20) gọi thẳng
--   UPDATE ban_sessions SET status='closed' → bàn còn món đóng mà không thu tiền,
--   không lý do, không duyệt, không audit. App mới đã bỏ nút; migration này chặn
--   ở máy chủ cho app cũ và cho người gọi thẳng API.
--
-- Luật (chỉ áp cho vai trò client `anon`, `authenticated`; RPC SECURITY DEFINER như
-- settle_ban_session_v5 / complete_pos_sale_v1 chạy với quyền chủ sở hữu nên không bị chặn):
--   1. Phiên đã kết thúc (khác 'open') không được đổi trạng thái nữa (không mở lại, không đổi qua lại).
--   2. open → 'closed' chỉ khi phiên KHÔNG còn món nào chưa huỷ (trường hợp gộp bàn:
--      chuyển hết món sang bàn đích rồi mới đóng phiên nguồn).
--   3. open → 'cancelled' (huỷ bàn) VẪN cho phép: app cũ (< 1.0.5+16) đặt 'cancelled'
--      TRƯỚC rồi mới huỷ món và ghi audit. Siết thêm (bắt buộc void_audit_logs) khi mọi
--      máy đã lên bản ≥ 1.0.5+16 — xem mục "Còn lại" trong nhat_ky.md.
--   4. Trạng thái khác ('paid', ...) từ client → chặn.
--   5. Xoá phiên còn món chưa huỷ từ client → chặn.
-- Không đổi bảng, không đổi dữ liệu. Rollback: 20261022_chan_dong_phien_ban_v1_ROLLBACK.sql
-- ============================================================================

-- Preflight: cột dùng để đếm món phải tồn tại.
DO $pf$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ban_session_items' AND column_name = 'kitchen_status'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ban_sessions' AND column_name = 'status'
  ) THEN
    RAISE EXCEPTION 'PREFLIGHT: thiếu ban_session_items.kitchen_status hoặc ban_sessions.status';
  END IF;
  RAISE NOTICE 'PREFLIGHT chan_dong_phien_ban_v1: OK';
END
$pf$;

-- Đếm món chưa huỷ của một phiên, bỏ qua RLS (trigger chạy với quyền client nên tự đếm
-- có thể bị RLS che → ra 0 → lọt). Chỉ trả về một con số.
CREATE OR REPLACE FUNCTION public.ban_session_active_item_count_v1(p_session_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
  SELECT count(*)::integer
  FROM public.ban_session_items
  WHERE session_id = p_session_id
    AND COALESCE(kitchen_status, '') <> 'huy';
$fn$;

REVOKE ALL ON FUNCTION public.ban_session_active_item_count_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ban_session_active_item_count_v1(uuid) TO anon, authenticated, service_role;

-- Hàm trigger KHÔNG phải SECURITY DEFINER: cần current_user = vai trò thật của người gọi.
CREATE OR REPLACE FUNCTION public.guard_ban_session_status_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_active integer;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF TG_OP = 'DELETE' THEN
    IF COALESCE(OLD.status, 'open') = 'open' THEN
      v_active := public.ban_session_active_item_count_v1(OLD.id);
      IF v_active > 0 THEN
        RAISE EXCEPTION 'BAN_SESSION_CLOSE_REQUIRES_PAYMENT: Không xoá được bàn còn % món. Hãy Thanh toán hoặc Huỷ bàn.', v_active
          USING ERRCODE = '42501';
      END IF;
    END IF;
    RETURN OLD;
  END IF;

  -- UPDATE
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  IF COALESCE(OLD.status, 'open') <> 'open' THEN
    RAISE EXCEPTION 'BAN_SESSION_FINAL: Phiên bàn đã kết thúc (%), không đổi trạng thái được.', OLD.status
      USING ERRCODE = '42501';
  END IF;

  IF NEW.status = 'cancelled' THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'closed' THEN
    v_active := public.ban_session_active_item_count_v1(NEW.id);
    IF v_active > 0 THEN
      RAISE EXCEPTION 'BAN_SESSION_CLOSE_REQUIRES_PAYMENT: Bàn còn % món chưa thanh toán. Hãy Thanh toán hoặc Huỷ bàn.', v_active
        USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'BAN_SESSION_STATUS_DENIED: App không được đặt trạng thái phiên bàn "%".', NEW.status
    USING ERRCODE = '42501';
END
$fn$;

DROP TRIGGER IF EXISTS guard_ban_session_status_v1 ON public.ban_sessions;
CREATE TRIGGER guard_ban_session_status_v1
  BEFORE UPDATE OF status OR DELETE ON public.ban_sessions
  FOR EACH ROW EXECUTE FUNCTION public.guard_ban_session_status_v1();

-- Kiểm tra sau khi áp
DO $chk$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'guard_ban_session_status_v1' AND tgrelid = 'public.ban_sessions'::regclass AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'POSTCHECK: trigger guard_ban_session_status_v1 chưa được tạo';
  END IF;
  RAISE NOTICE 'POSTCHECK chan_dong_phien_ban_v1: trigger OK';
END
$chk$;
