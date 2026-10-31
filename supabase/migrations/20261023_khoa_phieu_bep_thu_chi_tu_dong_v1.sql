-- ============================================================================
-- Khoá phiếu bếp + phiếu thu chi "tự động" phía máy chủ — v1 (23/10/2026)
-- viec-can-sua #41 (phiếu thu chi is_auto giả) + lỗ phiếu bếp QC tìm ra khi vá #4.
--
-- Lỗ:
--  • kitchen_tickets / kitchen_ticket_items: app (anon/authenticated) thêm/sửa/xoá tuỳ ý qua API →
--    xoá dấu vết món đã gửi bếp, đổi số lượng, đánh dấu huỷ / xong tuỳ ý.
--  • finance_records: phiếu nhập tay đã khoá (guard_finance_manual_insert_v1), sửa/xoá đã khoá
--    (guard_finance_records_v1) — nhưng phiếu is_auto=true vẫn THÊM được tuỳ ý → doanh thu giả
--    (Tổng quan cộng mọi phiếu thu tự động).
--
-- TƯƠNG THÍCH app đang dùng 1.0.5 (dò code 23/10): chỉ chặn những gì app không làm, hoặc kiểm
-- đúng dạng app làm. RPC SECURITY DEFINER (send_kitchen_ticket_v2, complete_pos_sale_v1,
-- settle_ban_session_v5, pay_and_send_counter_v4, topup_customer_wallet_v1…) không bị ảnh hưởng
-- (trigger chỉ kiểm khi current_user là anon/authenticated).
--
-- Phiếu bếp:
--  • Xoá: chặn (app chỉ xoá ở đường dự phòng khi thiếu RPC — không xảy ra).
--  • Thêm phiếu (POS mang đi gửi bếp): phải thuộc phiên bàn đang mở cùng quán, trạng thái 'cho'.
--  • Sửa phiếu: khoá cột định danh (quán, phiên, bàn, khu, đợt, giờ gửi, trạm, đơn); trạng thái chỉ
--    pending/cho/dang_lam/xong/huy; sang 'huy' chỉ khi có món đã huỷ thật (ban_session_items='huy')
--    và mọi món còn lại đã xong / đã huỷ; đã 'huy' thì giữ 'huy' (app bếp bấm trễ không báo lỗi).
-- Món trên phiếu bếp:
--  • Xoá: chặn. Thêm: phiếu cùng quán, đang 'cho'/'pending'; món bàn thuộc đúng phiên của phiếu,
--    số lượng = số lượng món bàn, chưa nằm ở phiếu khác, chưa xong.
--  • Sửa: chỉ đổi done / quantity / free_note / kitchen_note; quantity chỉ giảm và phải bằng số lượng
--    món bàn; món bàn đã huỷ → done luôn true (app bếp "mở lại" phiếu không làm sống lại món đã huỷ).
-- Phiếu thu chi tự động do app tự ghi — chỉ nhận 4 dạng app 1.0.5 đang ghi, đối chiếu dữ liệu thật,
-- mỗi phiếu gốc một lần:
--  1. Chi "Nhập hàng" theo phiếu kho stock_movements (reason 'purchase', tạo ≤ 10 phút).
--  2. Chi theo phiếu nhập purchase_orders 'received', số tiền = tổng phiếu.
--  3. Thu hoàn theo phiếu nhập đã 'cancelled', số tiền = tổng phiếu, đã có phiếu chi gốc.
--  4. Thu "Nạp ví" (app cũ ghi thẳng; app mới dùng RPC) — có giao dịch topup_real cùng khách,
--     cùng số tiền, ≤ 10 phút, chưa được ghi.
--  Còn lại (vd "Giá vốn NL" app cũ ghi khi huỷ món — lỗi tính trùng đã gỡ 23/10) → chặn.
--  App bọc các lệnh ghi này trong "lỗi thì bỏ qua" → không màn hình nào vỡ.
-- Phiếu thu chi tự động (bản sửa sau QC 23/10): chỉ người có module Kho (dạng 1–3) / Khách hàng
--  (dạng 4) ghi được; dạng 1 đối chiếu số tiền = số lượng nhập × giá nhập của món; không dùng giờ máy.
-- Món ở bàn đã nằm trên phiếu bếp = đã gửi (áp luật duyệt của #4); không đưa món huỷ lên phiếu;
--  app không thêm thẳng món ở trạng thái đang làm / xong / huỷ.
-- CÒN HỞ (giai đoạn 2, cần app mới trên mọi máy): người CÓ module Kho / Khách hàng vẫn tự tạo được
--  "chứng từ gốc" (phiếu kho, phiếu nhập, giao dịch nạp ví) rồi ghi phiếu thu/chi tự động theo nó —
--  các bảng đó app còn ghi thẳng. Đóng hẳn = chuyển nhập kho / phiếu nhập / huỷ phiếu nhập sang hàm
--  máy chủ, rồi chặn mọi phiếu is_auto từ app.
-- CÒN HỞ — #33 (QUAN TRỌNG): mọi chốt dựa trên "người gọi là ai" (module Kho/Khách hàng ở đây, duyệt
--  Quản lý ở #4) chỉ chặn được máy đã đăng nhập JWT. Request không JWT gửi header x-user-id = id Chủ quán
--  (đọc được từ store_members) thì qua hết. Đóng hẳn khi máy chủ thôi tin header (kế hoạch JWT).
-- CÒN HỞ — chuyển món: gộp bàn (app 1.0.5 gọi thẳng update session_id) vẫn chuyển được món đã gửi bếp sang
--  một bàn ĐANG MỞ khác của quán (vd bàn mở quên) → món rời bill thật. Bản này chỉ bắt phiên đích đang mở,
--  cùng quán. Đóng hẳn = gộp bàn qua hàm máy chủ (đóng luôn phiên nguồn) rồi khoá session_id.
-- ============================================================================
BEGIN;

-- ── Phiếu bếp ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.guard_kitchen_ticket_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_status text;
  v_store  uuid;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'KITCHEN_TICKET_DELETE_FORBIDDEN: không xoá được phiếu bếp' USING ERRCODE = '42501';
  END IF;

  IF TG_OP = 'INSERT' THEN
    SELECT status, store_id INTO v_status, v_store FROM public.ban_sessions WHERE id = NEW.session_id;
    IF NEW.session_id IS NULL OR v_store IS DISTINCT FROM NEW.store_id OR v_status IS DISTINCT FROM 'open' THEN
      RAISE EXCEPTION 'KITCHEN_TICKET_SESSION_INVALID: phiếu bếp phải thuộc bàn đang mở của quán'
        USING ERRCODE = '42501';
    END IF;
    IF COALESCE(NEW.status, 'cho') <> 'cho' OR NEW.done_at IS NOT NULL OR NEW.started_at IS NOT NULL THEN
      RAISE EXCEPTION 'KITCHEN_TICKET_INSERT_STATE: phiếu bếp mới phải ở trạng thái chờ' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE
  IF ROW(NEW.store_id, NEW.session_id, NEW.order_id, NEW.table_label, NEW.zone_label, NEW.round,
         NEW.sent_at, NEW.station_code, NEW.station_id, NEW.created_at)
     IS DISTINCT FROM
     ROW(OLD.store_id, OLD.session_id, OLD.order_id, OLD.table_label, OLD.zone_label, OLD.round,
         OLD.sent_at, OLD.station_code, OLD.station_id, OLD.created_at) THEN
    RAISE EXCEPTION 'KITCHEN_TICKET_LOCKED: không đổi được bàn / đợt / giờ gửi của phiếu bếp' USING ERRCODE = '42501';
  END IF;
  IF OLD.status = 'huy' THEN
    NEW.status := 'huy';           -- đã huỷ thì giữ huỷ (bếp bấm "Xong" trễ không báo lỗi)
    RETURN NEW;
  END IF;
  IF COALESCE(NEW.status, '') NOT IN ('pending', 'cho', 'dang_lam', 'xong', 'huy') THEN
    RAISE EXCEPTION 'KITCHEN_TICKET_STATUS_INVALID: trạng thái phiếu bếp không hợp lệ' USING ERRCODE = '42501';
  END IF;
  IF NEW.status = 'huy' THEN
    -- Chỉ huỷ phiếu khi đã huỷ món thật (huỷ món / huỷ bàn có duyệt) và mọi món khác đã xong / đã huỷ.
    -- Món cũ không gắn món bàn (session_item_id NULL — 3 dòng mang đi 13–17/10) không cản việc huỷ.
    IF (NOT EXISTS (
          SELECT 1 FROM public.kitchen_ticket_items i
          JOIN public.ban_session_items b ON b.id = i.session_item_id
          WHERE i.ticket_id = OLD.id AND b.kitchen_status = 'huy')
        AND EXISTS (
          SELECT 1 FROM public.kitchen_ticket_items i
          WHERE i.ticket_id = OLD.id AND i.session_item_id IS NOT NULL))
       OR EXISTS (
         SELECT 1 FROM public.kitchen_ticket_items i
         JOIN public.ban_session_items b ON b.id = i.session_item_id
         WHERE i.ticket_id = OLD.id AND NOT COALESCE(i.done, false)
           AND COALESCE(b.kitchen_status, '') <> 'huy') THEN
      RAISE EXCEPTION 'KITCHEN_TICKET_CANCEL_DENIED: chỉ huỷ phiếu bếp khi món đã được huỷ (có duyệt)'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS guard_kitchen_ticket_v1 ON public.kitchen_tickets;
CREATE TRIGGER guard_kitchen_ticket_v1
  BEFORE INSERT OR UPDATE OR DELETE ON public.kitchen_tickets
  FOR EACH ROW EXECUTE FUNCTION public.guard_kitchen_ticket_v1();

-- ── Món trên phiếu bếp ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.guard_kitchen_ticket_item_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_t_store   uuid;
  v_t_status  text;
  v_t_session uuid;
  v_b         public.ban_session_items%ROWTYPE;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'KITCHEN_ITEM_DELETE_FORBIDDEN: không xoá được món trên phiếu bếp' USING ERRCODE = '42501';
  END IF;

  IF NEW.session_item_id IS NOT NULL THEN
    -- FOR SHARE: xoá / giảm món bàn chạy cùng lúc phải chờ, rồi thấy món bếp này (chống chen ngang)
    SELECT * INTO v_b FROM public.ban_session_items WHERE id = NEW.session_item_id FOR SHARE;
  END IF;

  IF TG_OP = 'INSERT' THEN
    SELECT store_id, status, session_id INTO v_t_store, v_t_status, v_t_session
    FROM public.kitchen_tickets WHERE id = NEW.ticket_id;
    IF v_t_store IS DISTINCT FROM NEW.store_id OR COALESCE(v_t_status, '') NOT IN ('cho', 'pending') THEN
      RAISE EXCEPTION 'KITCHEN_ITEM_TICKET_INVALID: món phải thuộc phiếu bếp đang chờ của quán' USING ERRCODE = '42501';
    END IF;
    IF NEW.session_item_id IS NULL OR v_b.id IS NULL OR v_b.session_id IS DISTINCT FROM v_t_session
       OR v_b.store_id IS DISTINCT FROM NEW.store_id OR v_b.kitchen_status = 'huy' THEN
      RAISE EXCEPTION 'KITCHEN_ITEM_SOURCE_INVALID: món trên phiếu bếp phải là món của đúng bàn' USING ERRCODE = '42501';
    END IF;
    IF COALESCE(NEW.quantity, NEW.qty) IS DISTINCT FROM v_b.quantity OR COALESCE(NEW.done, false) THEN
      RAISE EXCEPTION 'KITCHEN_ITEM_QTY_INVALID: số lượng món trên phiếu bếp phải bằng món ở bàn' USING ERRCODE = '42501';
    END IF;
    IF EXISTS (SELECT 1 FROM public.kitchen_ticket_items WHERE session_item_id = NEW.session_item_id) THEN
      RAISE EXCEPTION 'KITCHEN_ITEM_DUPLICATE: món này đã có trên phiếu bếp khác' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE: chỉ done / quantity / free_note / kitchen_note
  IF ROW(NEW.store_id, NEW.ticket_id, NEW.session_item_id, NEW.product_id, NEW.name, NEW.product_name,
         NEW.qty, NEW.station_code, NEW.modifiers_json, NEW.status, NEW.started_at, NEW.done_at,
         NEW.edit_history_json)
     IS DISTINCT FROM
     ROW(OLD.store_id, OLD.ticket_id, OLD.session_item_id, OLD.product_id, OLD.name, OLD.product_name,
         OLD.qty, OLD.station_code, OLD.modifiers_json, OLD.status, OLD.started_at, OLD.done_at,
         OLD.edit_history_json) THEN
    RAISE EXCEPTION 'KITCHEN_ITEM_LOCKED: không đổi được món / trạm / phiếu của món bếp' USING ERRCODE = '42501';
  END IF;
  IF NEW.quantity IS DISTINCT FROM OLD.quantity THEN
    IF NEW.quantity IS NULL OR NEW.quantity >= COALESCE(OLD.quantity, OLD.qty)
       OR v_b.id IS NULL OR NEW.quantity IS DISTINCT FROM v_b.quantity THEN
      RAISE EXCEPTION 'KITCHEN_ITEM_QTY_LOCKED: số lượng món bếp chỉ giảm theo món ở bàn (có duyệt)'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  IF v_b.kitchen_status = 'huy' THEN
    NEW.done := true;              -- món đã huỷ: luôn coi là xong (bếp "mở lại" không làm sống lại)
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS guard_kitchen_ticket_item_v1 ON public.kitchen_ticket_items;
CREATE TRIGGER guard_kitchen_ticket_item_v1
  BEFORE INSERT OR UPDATE OR DELETE ON public.kitchen_ticket_items
  FOR EACH ROW EXECUTE FUNCTION public.guard_kitchen_ticket_item_v1();

-- ── Phiếu thu chi tự động do app tự ghi ────────────────────────────────────
-- Không dùng giờ do máy gửi lên (đồng hồ máy có thể lệch) — đối chiếu số tiền + quyền module.
CREATE OR REPLACE FUNCTION public.guard_finance_auto_insert_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_ok boolean := false;
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') OR NOT COALESCE(NEW.is_auto, false) THEN
    RETURN NEW;
  END IF;
  IF NEW.reference_id IS NOT NULL AND NEW.amount IS NOT NULL AND NEW.amount > 0
     AND NEW.category_id IS NULL THEN
    IF NEW.type = 'expense' AND public.qn_caller_has_module(NEW.store_id, 'kho') THEN
      -- 1. Nhập kho nhanh: số tiền = số lượng nhập × giá nhập vừa cập nhật của món
      v_ok := EXISTS (
          SELECT 1 FROM public.stock_movements m
          JOIN public.products pr ON pr.id = m.product_id
          WHERE m.id = NEW.reference_id AND m.store_id = NEW.store_id AND m.reason = 'purchase'
            AND m.delta > 0 AND pr.cost_price_latest > 0
            AND abs(NEW.amount - m.delta * pr.cost_price_latest) < 1)
        -- 2. Phiếu nhập hàng đã nhận, đúng tổng tiền
        OR EXISTS (
          SELECT 1 FROM public.purchase_orders po
          WHERE po.id = NEW.reference_id AND po.store_id = NEW.store_id AND po.status = 'received'
            AND NEW.amount IN (po.total_amount, po.total_cost));
    ELSIF NEW.type = 'income' THEN
      IF public.qn_caller_has_module(NEW.store_id, 'kho') THEN
        -- 3. Thu hoàn khi huỷ phiếu nhập (đã có phiếu chi gốc)
        v_ok := EXISTS (
            SELECT 1 FROM public.purchase_orders po
            WHERE po.id = NEW.reference_id AND po.store_id = NEW.store_id AND po.status = 'cancelled'
              AND NEW.amount IN (po.total_amount, po.total_cost)
              AND EXISTS (SELECT 1 FROM public.finance_records f
                          WHERE f.reference_id = po.id AND f.store_id = NEW.store_id AND f.type = 'expense'));
      END IF;
      IF NOT v_ok AND public.qn_caller_has_module(NEW.store_id, 'loyalty') THEN
        -- 4. Nạp ví (app cũ ghi thẳng): số lần nạp thật (cả lịch sử) phải nhiều hơn số phiếu thu đã ghi
        v_ok :=
          (SELECT count(*) FROM public.balance_transactions bt
           WHERE bt.customer_id = NEW.reference_id AND bt.store_id = NEW.store_id
             AND bt.type = 'topup_real' AND bt.amount = NEW.amount)
          >
          (SELECT count(*) FROM public.finance_records f
           WHERE f.reference_id = NEW.reference_id AND f.store_id = NEW.store_id
             AND f.type = 'income' AND f.amount = NEW.amount);
      END IF;
    END IF;
    -- mỗi phiếu gốc (trừ nạp ví) chỉ ghi một lần mỗi loại
    IF v_ok AND EXISTS (
         SELECT 1 FROM public.finance_records f
         WHERE f.reference_id = NEW.reference_id AND f.store_id = NEW.store_id AND f.type = NEW.type
           AND f.is_auto
           AND NOT EXISTS (SELECT 1 FROM public.customers c WHERE c.id = NEW.reference_id)) THEN
      v_ok := false;
    END IF;
  END IF;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'FINANCE_AUTO_INSERT_DENIED: phiếu thu/chi tự động chỉ do hệ thống ghi' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS guard_finance_auto_insert_v1 ON public.finance_records;
CREATE TRIGGER guard_finance_auto_insert_v1
  BEFORE INSERT ON public.finance_records
  FOR EACH ROW EXECUTE FUNCTION public.guard_finance_auto_insert_v1();

CREATE INDEX IF NOT EXISTS idx_finance_records_store_reference
  ON public.finance_records (store_id, reference_id);

-- ── Món ở bàn: đã lên phiếu bếp thì coi như đã gửi (vá #4 bị lách bằng món "chưa gửi") ──
-- Bản 20261023_khoa_huy_mon_da_gui_v1 chỉ khoá món có kitchen_status đã gửi; món "chưa gửi" nhưng đã
-- nằm trên phiếu bếp (gắn tay qua API) vẫn xoá / giảm được → bếp làm mà bill không tính.
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

  v_sent := COALESCE(OLD.kitchen_status, '') IN ('da_gui', 'dang_lam', 'xong')
    OR EXISTS (SELECT 1 FROM public.kitchen_ticket_items k WHERE k.session_item_id = OLD.id);

  -- Chuyển món sang phiên khác (gộp bàn): phiên đích phải đang mở, cùng quán.
  IF TG_OP = 'UPDATE' AND NEW.session_id IS DISTINCT FROM OLD.session_id AND NOT EXISTS (
       SELECT 1 FROM public.ban_sessions s
       WHERE s.id = NEW.session_id AND s.store_id = OLD.store_id AND s.status = 'open') THEN
    RAISE EXCEPTION 'BAN_ITEM_MOVE_DENIED: chỉ chuyển món sang bàn đang mở của quán' USING ERRCODE = '42501';
  END IF;

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

  -- Chỉ cấm KÉO món đã gửi về "chưa gửi"; món chưa gửi mà đã lên phiếu bếp thì giữ "chưa gửi" được
  IF COALESCE(NEW.kitchen_status, '') NOT IN ('da_gui', 'dang_lam', 'xong', 'huy')
     AND COALESCE(OLD.kitchen_status, '') IN ('da_gui', 'dang_lam', 'xong') THEN
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

-- Không thêm thẳng món ở bàn với trạng thái bếp đang làm / xong / huỷ (app chỉ thêm 'chua_gui' hoặc 'da_gui').
CREATE OR REPLACE FUNCTION public.guard_ban_item_insert_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated')
     AND COALESCE(NEW.kitchen_status, 'chua_gui') NOT IN ('chua_gui', 'da_gui') THEN
    RAISE EXCEPTION 'BAN_ITEM_INSERT_STATE: món mới chỉ ở trạng thái chưa gửi / đã gửi bếp' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS guard_ban_item_insert_v1 ON public.ban_session_items;
CREATE TRIGGER guard_ban_item_insert_v1
  BEFORE INSERT ON public.ban_session_items
  FOR EACH ROW EXECUTE FUNCTION public.guard_ban_item_insert_v1();

COMMIT;
