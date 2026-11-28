-- ============================================================================
-- Khoá huỷ / giảm món ĐÃ GỬI BẾP phía máy chủ — v1 (23/10/2026) — viec-can-sua #4
--
-- Lỗ: app chỉ hỏi PIN quản lý ở máy khách; máy chủ cho mọi nhân viên trong quán sửa thẳng
-- ban_session_items qua API: đặt 'huy', giảm số lượng, xoá, đổi giá, kéo món về "chưa gửi"
-- (rồi xoá tự do) — không cần duyệt, không để lại dấu vết đáng tin (void_audit_logs do máy
-- khách tự ghi SAU khi sửa, lại sửa/xoá được).
--
-- Cách vá (TƯƠNG THÍCH app đang dùng 1.0.5 — app cũ luôn gọi verify_manager_quick_pin_v4 TRƯỚC khi sửa):
--  1. verify_manager_quick_pin_v4 đúng PIN → ghi một "lượt duyệt" (ban_item_void_grants) cho
--     người gọi (auth.uid()). Thân hàm giữ nguyên bản production 23/10, chỉ thêm 1 câu INSERT.
--  2. Trigger guard_ban_item_sent_v1 (BEFORE UPDATE/DELETE, chỉ khi current_user là anon/authenticated
--     — RPC SECURITY DEFINER như send_kitchen_ticket_v2 không bị ảnh hưởng). Món đã gửi bếp
--     (da_gui / dang_lam / xong):
--       • huỷ ('huy') hoặc giảm số lượng → cần người gọi là Chủ quán/Quản lý của quán, HOẶC lượt
--         duyệt PIN ≤ 5 phút chưa dùng (mỗi lượt dùng cho 1 request và chỉ 1 bàn — cả bàn trong 1 câu
--         lệnh được, nhiều bàn thì không); giảm thì thành tiền phải đúng đơn giá × số lượng mới;
--       • xoá, tăng số lượng, số lượng ≤ 0, đổi giá/món/topping, kéo về 'chua_gui' → chặn hẳn;
--       • đổi ghi chú, người thêm, chuyển sang phiên khác (gộp bàn), tiến độ bếp → cho phép.
--     Món đã huỷ: không xoá, không đổi số lượng/giá; app bếp cũ ghi đè trạng thái lên món đã huỷ
--     (lỗi cũ) → máy chủ lặng lẽ giữ 'huy' thay vì báo lỗi (không làm hỏng màn bếp bản cũ).
--  3. Mỗi lần huỷ/giảm món đã gửi được máy chủ ghi vào ban_item_void_server_logs (app chỉ đọc,
--     không ghi/sửa/xoá được): ai làm, ai duyệt, số lượng trước/sau, số tiền.
--  4. void_audit_logs, ban_session_void_logs: app chỉ THÊM — thu quyền sửa/xoá qua API.
--  5. Huỷ bàn bằng cách đặt thẳng ban_sessions.status='cancelled' khi còn món đã gửi chưa huỷ → cũng
--     cần duyệt như trên (app bản mới huỷ món trước rồi mới huỷ bàn; bản cũ hỏi PIN trước khi huỷ).
--  6. Chặn số âm: số lượng > 0, đơn giá ≥ 0, thành tiền ≥ 0 (dòng âm từng trừ được tiền bill;
--     production 23/10 không có dòng nào vi phạm).
--  Trigger đặt tên guard_ban_item_a_sent_v1 để chạy TRƯỚC guard_ban_item_financial_change_v5
--  (Postgres chạy trigger theo thứ tự tên): bếp bản cũ ghi đè món đã huỷ ở bàn đã đóng → mình giữ
--  'huy' trước, v5 thấy không đổi gì nên không báo lỗi.
--
-- Còn hở (ghi ở viec-can-sua #33): danh tính người gọi khi KHÔNG có JWT lấy từ header x-user-id
-- (giả được) → ai giả được id Chủ quán vẫn qua được bước 2. Đóng hẳn khi chuyển hết sang JWT.
-- ============================================================================
BEGIN;

-- 1. Lượt duyệt PIN (chỉ hàm máy chủ đọc/ghi)
CREATE TABLE IF NOT EXISTS public.ban_item_void_grants (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  caller_id    uuid NOT NULL,
  manager_id   uuid,
  manager_name text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  session_id   uuid,          -- bàn mà lượt duyệt đã dùng (1 lượt = 1 bàn)
  used_txid    bigint,
  used_at      timestamptz
);
CREATE INDEX IF NOT EXISTS idx_ban_item_void_grants_lookup
  ON public.ban_item_void_grants (store_id, caller_id, created_at DESC);
ALTER TABLE public.ban_item_void_grants ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ban_item_void_grants FROM PUBLIC, anon, authenticated;

-- 2. Sổ huỷ/giảm món do máy chủ ghi
CREATE TABLE IF NOT EXISTS public.ban_item_void_server_logs (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  session_id    uuid,
  item_id       uuid NOT NULL,
  product_name  text,
  action        text NOT NULL CHECK (action IN ('huy', 'giam', 'huy_ban')),
  old_status    text,
  old_qty       numeric,
  new_qty       numeric,
  amount        numeric,
  caller_id     uuid,
  approver_id   uuid,
  approver_name text,
  approval_kind text NOT NULL CHECK (approval_kind IN ('quan_ly', 'pin')),
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ban_item_void_server_logs_store
  ON public.ban_item_void_server_logs (store_id, created_at DESC);
ALTER TABLE public.ban_item_void_server_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ban_item_void_server_logs_read ON public.ban_item_void_server_logs;
CREATE POLICY ban_item_void_server_logs_read ON public.ban_item_void_server_logs
  FOR SELECT USING (store_id = (SELECT public.current_store_id()));
REVOKE ALL ON public.ban_item_void_server_logs FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.ban_item_void_server_logs TO anon, authenticated;

-- 3. Người gọi có phải Chủ quán / Quản lý của quán (khớp cách app nhận "Quản lý tự duyệt":
--    StaffService.canonicalRole — owner/manager, "chủ quán", "quản lý", "quản trị", "admin"…)
CREATE OR REPLACE FUNCTION public.qn_is_store_manager_v1(p_store uuid, p_user uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT p_store IS NOT NULL AND p_user IS NOT NULL AND (
    EXISTS (SELECT 1 FROM public.stores s WHERE s.id = p_store AND s.owner_user_id = p_user)
    OR EXISTS (
      SELECT 1 FROM public.store_members sm
      WHERE sm.store_id = p_store AND sm.user_id = p_user
        AND (sm.is_owner = true
             OR lower(trim(COALESCE(sm.role, ''))) IN ('owner', 'manager', 'chủ', 'chu', 'ql')
             OR lower(COALESCE(sm.role, '')) ~ '(owner|manager|chủ quán|chu quan|quản lý|quan ly|quản trị|quan tri|admin)'))
  )
$$;
REVOKE ALL ON FUNCTION public.qn_is_store_manager_v1(uuid, uuid) FROM PUBLIC, anon, authenticated;

-- 4. Kiểm duyệt + ghi sổ (chỉ gọi được từ trong trigger: pg_trigger_depth() >= 1)
CREATE OR REPLACE FUNCTION public.qn_ban_item_void_check_v1(
  p_item_id uuid, p_action text, p_new_qty numeric, p_new_subtotal numeric
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller uuid := public.qn_caller_id();
  v_item   public.ban_session_items%ROWTYPE;
  v_grant  public.ban_item_void_grants%ROWTYPE;
  v_kind   text;
  v_appr   uuid;
  v_name   text;
BEGIN
  IF pg_trigger_depth() < 1 THEN RAISE EXCEPTION 'TRIGGER_ONLY'; END IF;
  SELECT * INTO v_item FROM public.ban_session_items WHERE id = p_item_id;
  IF NOT FOUND OR v_caller IS NULL THEN RETURN false; END IF;

  IF public.qn_is_store_manager_v1(v_item.store_id, v_caller) THEN
    v_kind := 'quan_ly'; v_appr := v_caller;
    SELECT NULLIF(display_name, '') INTO v_name FROM public.user_accounts WHERE id = v_caller;
  ELSE
    SELECT * INTO v_grant FROM public.ban_item_void_grants
    WHERE store_id = v_item.store_id AND caller_id = v_caller
      AND created_at > now() - interval '5 minutes'
      AND (used_txid IS NULL
           OR (used_txid = txid_current() AND session_id IS NOT DISTINCT FROM v_item.session_id))
    ORDER BY (used_txid IS NULL), created_at DESC   -- ưu tiên lượt đang dùng cho bàn này trong cùng request
    LIMIT 1
    FOR UPDATE;
    IF NOT FOUND THEN RETURN false; END IF;
    UPDATE public.ban_item_void_grants
       SET used_txid = txid_current(), used_at = COALESCE(used_at, now()),
           session_id = COALESCE(session_id, v_item.session_id)
     WHERE id = v_grant.id;
    v_kind := 'pin'; v_appr := v_grant.manager_id; v_name := v_grant.manager_name;
  END IF;

  INSERT INTO public.ban_item_void_server_logs
    (store_id, session_id, item_id, product_name, action, old_status, old_qty, new_qty, amount,
     caller_id, approver_id, approver_name, approval_kind)
  VALUES
    (v_item.store_id, v_item.session_id, v_item.id, v_item.product_name, p_action,
     v_item.kitchen_status, v_item.quantity, p_new_qty,
     COALESCE(v_item.subtotal, 0) - COALESCE(p_new_subtotal, 0),
     v_caller, v_appr, v_name, v_kind);
  RETURN true;
END
$$;
REVOKE ALL ON FUNCTION public.qn_ban_item_void_check_v1(uuid, text, numeric, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.qn_ban_item_void_check_v1(uuid, text, numeric, numeric) TO anon, authenticated;

-- 5. Trigger chặn (KHÔNG SECURITY DEFINER: cần current_user thật của người gọi)
CREATE OR REPLACE FUNCTION public.guard_ban_item_sent_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_sent boolean;
  v_old_qty numeric;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  END IF;

  v_sent := COALESCE(OLD.kitchen_status, '') IN ('da_gui', 'dang_lam', 'xong');

  IF TG_OP = 'DELETE' THEN
    IF v_sent OR OLD.kitchen_status = 'huy' THEN
      RAISE EXCEPTION 'SENT_ITEM_DELETE_FORBIDDEN: món đã gửi bếp / đã huỷ không xoá được'
        USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;

  -- Món đã huỷ: giữ nguyên trạng thái và số liệu
  IF OLD.kitchen_status = 'huy' THEN
    IF ROW(NEW.quantity, NEW.unit_price, NEW.subtotal, NEW.price, NEW.product_id, NEW.modifiers_json)
       IS DISTINCT FROM
       ROW(OLD.quantity, OLD.unit_price, OLD.subtotal, OLD.price, OLD.product_id, OLD.modifiers_json) THEN
      RAISE EXCEPTION 'VOIDED_ITEM_LOCKED: món đã huỷ không sửa được' USING ERRCODE = '42501';
    END IF;
    NEW.kitchen_status := 'huy';   -- app bếp cũ ghi đè trạng thái cả phiếu → lặng lẽ giữ 'huy'
    RETURN NEW;
  END IF;

  IF NOT v_sent THEN RETURN NEW; END IF;   -- món chưa gửi bếp: tự do như cũ

  IF COALESCE(NEW.kitchen_status, '') NOT IN ('da_gui', 'dang_lam', 'xong', 'huy') THEN
    RAISE EXCEPTION 'SENT_ITEM_UNSEND_FORBIDDEN: món đã gửi bếp không đưa về chưa gửi được'
      USING ERRCODE = '42501';
  END IF;
  IF ROW(NEW.unit_price, NEW.price, NEW.product_id, NEW.modifiers_json)
     IS DISTINCT FROM ROW(OLD.unit_price, OLD.price, OLD.product_id, OLD.modifiers_json) THEN
    RAISE EXCEPTION 'SENT_ITEM_PRICE_LOCKED: món đã gửi bếp không đổi giá / món / topping được'
      USING ERRCODE = '42501';
  END IF;
  v_old_qty := COALESCE(OLD.quantity, 1);
  IF NEW.quantity IS DISTINCT FROM OLD.quantity THEN
    IF NEW.kitchen_status = 'huy' OR NEW.quantity IS NULL OR NEW.quantity <= 0 OR NEW.quantity >= v_old_qty THEN
      RAISE EXCEPTION 'SENT_ITEM_QTY_FORBIDDEN: chỉ giảm được số lượng món đã gửi bếp (có duyệt)'
        USING ERRCODE = '42501';
    END IF;
    -- Giảm: thành tiền phải đúng đơn giá × số lượng mới (app: price × qty, price = unit_price)
    IF NEW.subtotal IS NULL OR abs(NEW.subtotal - COALESCE(OLD.unit_price, 0) * NEW.quantity) >= 1 THEN
      RAISE EXCEPTION 'SENT_ITEM_PRICE_LOCKED: thành tiền phải bằng đơn giá × số lượng'
        USING ERRCODE = '42501';
    END IF;
  ELSIF NEW.subtotal IS DISTINCT FROM OLD.subtotal THEN
    RAISE EXCEPTION 'SENT_ITEM_PRICE_LOCKED: món đã gửi bếp không đổi thành tiền được'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.kitchen_status = 'huy' THEN
    IF NOT public.qn_ban_item_void_check_v1(OLD.id, 'huy', 0, 0) THEN
      RAISE EXCEPTION 'VOID_APPROVAL_REQUIRED: huỷ món đã gửi bếp cần Quản lý duyệt'
        USING ERRCODE = '42501';
    END IF;
  ELSIF NEW.quantity < OLD.quantity THEN
    IF NOT public.qn_ban_item_void_check_v1(OLD.id, 'giam', NEW.quantity, NEW.subtotal) THEN
      RAISE EXCEPTION 'VOID_APPROVAL_REQUIRED: giảm món đã gửi bếp cần Quản lý duyệt'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END
$$;

-- Tên bắt đầu "guard_ban_item_a_" để chạy TRƯỚC guard_ban_item_financial_change_v5
DROP TRIGGER IF EXISTS guard_ban_item_sent_v1 ON public.ban_session_items;
DROP TRIGGER IF EXISTS guard_ban_item_a_sent_v1 ON public.ban_session_items;
CREATE TRIGGER guard_ban_item_a_sent_v1
  BEFORE UPDATE OR DELETE ON public.ban_session_items
  FOR EACH ROW EXECUTE FUNCTION public.guard_ban_item_sent_v1();

-- 5b. Huỷ bàn (status → cancelled) khi còn món đã gửi chưa huỷ → cần duyệt như huỷ món
CREATE OR REPLACE FUNCTION public.guard_ban_session_cancel_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE r record;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN RETURN NEW; END IF;
  IF NEW.status IS DISTINCT FROM 'cancelled' OR OLD.status IS NOT DISTINCT FROM 'cancelled' THEN
    RETURN NEW;
  END IF;
  FOR r IN
    SELECT id FROM public.ban_session_items
    WHERE session_id = OLD.id AND kitchen_status IN ('da_gui', 'dang_lam', 'xong')
  LOOP
    IF NOT public.qn_ban_item_void_check_v1(r.id, 'huy_ban', 0, 0) THEN
      RAISE EXCEPTION 'CANCEL_APPROVAL_REQUIRED: huỷ bàn còn món đã gửi bếp cần Quản lý duyệt'
        USING ERRCODE = '42501';
    END IF;
  END LOOP;
  RETURN NEW;
END
$$;
DROP TRIGGER IF EXISTS guard_ban_session_cancel_v1 ON public.ban_sessions;
CREATE TRIGGER guard_ban_session_cancel_v1
  BEFORE UPDATE OF status ON public.ban_sessions
  FOR EACH ROW EXECUTE FUNCTION public.guard_ban_session_cancel_v1();

-- 5c. Không số âm (production 23/10: 0 dòng vi phạm)
ALTER TABLE public.ban_session_items DROP CONSTRAINT IF EXISTS ban_session_items_khong_am_v1;
ALTER TABLE public.ban_session_items ADD CONSTRAINT ban_session_items_khong_am_v1
  CHECK (quantity > 0 AND unit_price >= 0 AND subtotal >= 0) NOT VALID;
ALTER TABLE public.ban_session_items VALIDATE CONSTRAINT ban_session_items_khong_am_v1;

-- 6. Sổ huỷ do app ghi: chỉ thêm, không sửa/xoá qua API
REVOKE UPDATE, DELETE ON public.void_audit_logs FROM anon, authenticated;
REVOKE UPDATE, DELETE ON public.ban_session_void_logs FROM anon, authenticated;

-- 7. Hàm kiểm PIN: bản production 23/10 + ghi lượt duyệt
CREATE OR REPLACE FUNCTION public.verify_manager_quick_pin_v4(p_store_id uuid, p_pin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_hash bytea;
  v_failures integer;
  v_manager record;
  v_matched boolean := false;
  v_manager_id uuid;
  v_manager_name text;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực phiên đăng nhập'
    );
  END IF;

  IF p_pin IS NULL OR p_pin !~ '^\d{6}$' THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 400,
      'error_code', 'INVALID_PIN_FORMAT', 'message', 'Mã PIN phải gồm đúng 6 chữ số'
    );
  END IF;

  IF NOT public.has_active_store_access_v4(p_store_id) THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 403,
      'error_code', 'STORE_MEMBERSHIP_FORBIDDEN', 'message', 'Tài khoản không thuộc cửa hàng này'
    );
  END IF;

  v_caller_hash := digest(convert_to(v_caller_id::text || ':' || p_store_id::text, 'utf8'), 'sha256');
  PERFORM pg_advisory_xact_lock(
    hashtextextended(encode(v_caller_hash, 'hex'), 0)
  );

  SELECT count(*) INTO v_failures
  FROM public.pos_auth_attempts_v4
  WHERE phone_hash = v_caller_hash
    AND attempt_type = 'quick_pin'
    AND is_success = false
    AND attempted_at >= now() - interval '5 minutes';

  IF v_failures >= 5 THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 429,
      'error_code', 'RATE_LIMIT_EXCEEDED',
      'message', 'Quá nhiều lần nhập sai mã PIN. Vui lòng thử lại sau 5 phút.'
    );
  END IF;

  FOR v_manager IN
    SELECT ua.id, ua.phone, ua.display_name, ua.quick_pin
    FROM public.user_accounts ua
    JOIN public.store_members sm ON sm.user_id = ua.id
    WHERE sm.store_id = p_store_id
      AND (sm.role IN ('owner', 'manager') OR sm.is_owner = true)
    UNION
    SELECT ua.id, ua.phone, ua.display_name, ua.quick_pin
    FROM public.user_accounts ua
    JOIN public.stores s ON s.owner_user_id = ua.id
    WHERE s.id = p_store_id
  LOOP
    IF v_manager.quick_pin IS NOT NULL AND v_manager.quick_pin <> '' THEN
      IF v_manager.quick_pin LIKE '$2a$%' OR v_manager.quick_pin LIKE '$2b$%' OR v_manager.quick_pin LIKE '$2y$%' THEN
        IF crypt(p_pin, v_manager.quick_pin) = v_manager.quick_pin THEN
          v_matched := true;
          v_manager_id := v_manager.id;
          v_manager_name := v_manager.display_name;
          EXIT;
        END IF;
      ELSE
        IF public.verify_password_hash_v4(v_manager.phone, p_pin, v_manager.quick_pin) THEN
          v_matched := true;
          v_manager_id := v_manager.id;
          v_manager_name := v_manager.display_name;
          UPDATE public.user_accounts
          SET quick_pin = crypt(p_pin, gen_salt('bf', 12))
          WHERE id = v_manager.id;
          EXIT;
        END IF;
      END IF;
    END IF;
  END LOOP;

  IF v_matched THEN
    DELETE FROM public.pos_auth_attempts_v4
    WHERE phone_hash = v_caller_hash AND attempt_type = 'quick_pin';

    -- [20261023_khoa_huy_mon_da_gui_v1] Ghi "lượt duyệt" cho người gọi: máy chủ chỉ cho huỷ/giảm
    -- món đã gửi bếp khi có lượt duyệt còn hạn (5 phút, dùng cho 1 thao tác, 1 bàn) — xem trigger.
    INSERT INTO public.ban_item_void_grants (store_id, caller_id, manager_id, manager_name)
    VALUES (p_store_id, v_caller_id, v_manager_id, v_manager_name);
    DELETE FROM public.ban_item_void_grants
    WHERE store_id = p_store_id AND created_at < now() - interval '1 day';

    RETURN jsonb_build_object(
      'success', true, 'status', 200,
      'manager_id', v_manager_id,
      'manager_name', COALESCE(v_manager_name, 'Quản lý')
    );
  ELSE
    INSERT INTO public.pos_auth_attempts_v4(phone_hash, attempt_type, is_success)
    VALUES (v_caller_hash, 'quick_pin', false);

    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'INVALID_PIN',
      'message', 'Mã PIN quản lý không chính xác'
    );
  END IF;
END;
$function$;

COMMIT;

NOTIFY pgrst, 'reload schema';
