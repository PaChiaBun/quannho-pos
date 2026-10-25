-- HOÀN TÁC 20261023_khoa_phieu_bep_thu_chi_tu_dong_v1.sql — gỡ các chốt, trả guard món bàn về bản #4 (không đụng dữ liệu).
BEGIN;
DROP TRIGGER IF EXISTS guard_kitchen_ticket_v1 ON public.kitchen_tickets;
DROP FUNCTION IF EXISTS public.guard_kitchen_ticket_v1();
DROP TRIGGER IF EXISTS guard_kitchen_ticket_item_v1 ON public.kitchen_ticket_items;
DROP FUNCTION IF EXISTS public.guard_kitchen_ticket_item_v1();
DROP TRIGGER IF EXISTS guard_finance_auto_insert_v1 ON public.finance_records;
DROP FUNCTION IF EXISTS public.guard_finance_auto_insert_v1();
DROP INDEX IF EXISTS public.idx_finance_records_store_reference;
DROP TRIGGER IF EXISTS guard_ban_item_insert_v1 ON public.ban_session_items;
DROP FUNCTION IF EXISTS public.guard_ban_item_insert_v1();
-- guard_ban_item_sent_v1: trả về bản của 20261023_khoa_huy_mon_da_gui_v1 (chỉ xét kitchen_status)
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
COMMIT;
