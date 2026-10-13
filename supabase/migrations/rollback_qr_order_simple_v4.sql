-- ============================================================================
-- ROLLBACK cho 20261013_qr_order_simple_v4.sql
--
-- CHỈ gỡ đối tượng QR do migration đó tạo. KHÔNG đụng (thuộc V5 prerequisites / settlement):
--   payment_settlements, ban_session_orders, ban_session_order_items, qr_audit_logs,
--   qr_coupon_redemptions, verify_staff_qr_membership_v4, settle_ban_session_v5,
--   send_kitchen_ticket_v2, generate_daily_order_number_v1, daily_order_counters.
-- KHÔNG hoàn tác: orders / order_items / ban_sessions / ban_session_items / kitchen_tickets /
--   finance_records / stock_movements đã sinh ra từ đơn QR (là dữ liệu kinh doanh thật).
-- Dòng qr_audit_logs của QR được giữ nguyên.
--
-- AN TOÀN: nếu đã có đơn QR, script từ chối chạy trừ khi bật cờ xác nhận trong cùng phiên:
--   SET app.qr_rollback_confirm = 'yes';
-- (xuất/backup qr_requests, qr_request_items, qr_channels trước khi xác nhận)
-- ============================================================================

BEGIN;

DO $guard$
DECLARE
  v_n bigint := 0;
BEGIN
  -- Dynamic SQL: chạy lại rollback khi bảng đã không còn thì không lỗi.
  IF to_regclass('public.qr_requests') IS NOT NULL THEN
    EXECUTE 'SELECT count(*) FROM public.qr_requests' INTO v_n;
  END IF;
  IF v_n > 0 AND COALESCE(current_setting('app.qr_rollback_confirm', true), '') <> 'yes' THEN
    RAISE EXCEPTION 'QR_ROLLBACK_BLOCKED: public.qr_requests còn dữ liệu. Backup rồi chạy: SET app.qr_rollback_confirm = ''yes''; sau đó chạy lại rollback.';
  END IF;
END
$guard$;

-- RPC công khai + nhân viên
DROP FUNCTION IF EXISTS public.get_qr_channel_info_v4(text);
DROP FUNCTION IF EXISTS public.get_qr_menu_v4(text);
DROP FUNCTION IF EXISTS public.submit_qr_order_v4(text, jsonb, text, text, text);
DROP FUNCTION IF EXISTS public.get_qr_request_status_v4(text);
DROP FUNCTION IF EXISTS public.get_qr_request_detail_v4(uuid, uuid);
DROP FUNCTION IF EXISTS public.claim_qr_request_v4(uuid, uuid);
DROP FUNCTION IF EXISTS public.update_qr_order_items_v4(uuid, uuid, integer, jsonb);
DROP FUNCTION IF EXISTS public.set_qr_order_table_v4(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.approve_and_send_table_v4(uuid, uuid, integer);
DROP FUNCTION IF EXISTS public.pay_and_send_counter_v4(uuid, uuid, integer, text);
DROP FUNCTION IF EXISTS public.cancel_qr_order_v4(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.manage_qr_channel_v4(uuid, text, boolean, text);

-- Hàm nội bộ của migration này
DROP FUNCTION IF EXISTS public.qr_request_json_v4(public.qr_requests);
DROP FUNCTION IF EXISTS public.qr_open_session_v4(uuid, text);
DROP FUNCTION IF EXISTS public.qr_deduct_stock_v4(uuid, uuid, text, uuid, numeric, text);
DROP FUNCTION IF EXISTS public.qr_price_items_v4(uuid, jsonb);
DROP FUNCTION IF EXISTS public.qr_ensure_staff_v4(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.qr_staff_ctx_v4(uuid, boolean, boolean);
DROP FUNCTION IF EXISTS public.qr_list_tables_v4(uuid);
DROP FUNCTION IF EXISTS public.qr_table_info_v4(uuid, text);
-- qr_is_active_member_v4 còn được policy RLS dùng: bỏ policy (cùng với bảng) trước khi drop hàm
DROP TABLE IF EXISTS public.qr_request_items;
DROP TABLE IF EXISTS public.qr_requests;
DROP TABLE IF EXISTS public.qr_pickup_counters;
DROP TABLE IF EXISTS public.qr_channels;
DROP FUNCTION IF EXISTS public.qr_is_active_member_v4(uuid, uuid);
DROP FUNCTION IF EXISTS public.qr_err_v4(text, text);

-- Index một-phiên-mở-mỗi-bàn do migration tạo trên ban_sessions (chỉ index, không đụng dữ liệu)
DROP INDEX IF EXISTS public.uq_ban_sessions_one_open_per_table;

COMMIT;
