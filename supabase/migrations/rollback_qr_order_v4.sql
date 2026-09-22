-- ============================================================================
-- ROLLBACK MIGRATION: QR Order V4 (Quán Nhỏ POS)
-- Target: Clean, safe rollback of QR Order V4 objects without touching core tables
-- Rule: NO CASCADE on core tables, reverse dependency drops, exact signatures
-- ============================================================================

-- ── 1. THU HỒI QUYỀN TRUY CẬP (REVOKE GRANTS) ────────────────────────────────
REVOKE EXECUTE ON FUNCTION public.get_qr_channel_info_v4(text) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_qr_menu_v4(text, text) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.submit_qr_order_v4(text, jsonb, text, text, text) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_qr_request_status_v4(text) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.regenerate_handoff_token_v4(text) FROM anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.claim_qr_handoff_v4(text, uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_qr_request_detail_v4(uuid, uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.update_qr_order_items_v4(uuid, uuid, integer, jsonb) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.assign_qr_order_table_v4(uuid, uuid, uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.mark_qr_order_paid_v4(uuid, uuid, text, text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.send_qr_order_to_kitchen_v4(uuid, uuid, text, text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.settle_ban_session_v4(uuid, uuid, text, text, uuid, integer, numeric, text, numeric) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.cancel_qr_order_v4(uuid, uuid, text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.manage_qr_channel_v4(uuid, text, boolean, text) FROM authenticated;

REVOKE SELECT ON TABLE public.qr_coupon_redemptions FROM authenticated;
REVOKE SELECT ON TABLE public.payment_settlements FROM authenticated;
REVOKE SELECT ON TABLE public.ban_session_order_items FROM authenticated;
REVOKE SELECT ON TABLE public.ban_session_orders FROM authenticated;
REVOKE SELECT ON TABLE public.qr_kitchen_idempotency FROM authenticated;
REVOKE SELECT ON TABLE public.qr_payment_idempotency FROM authenticated;
REVOKE SELECT ON TABLE public.qr_channels FROM authenticated;
REVOKE SELECT ON TABLE public.qr_requests FROM authenticated;
REVOKE SELECT ON TABLE public.qr_request_items FROM authenticated;
REVOKE SELECT ON TABLE public.qr_audit_logs FROM authenticated;
REVOKE SELECT ON TABLE public.product_topping_links FROM authenticated;

-- ── 2. XÓA CÁC RPC FUNCTIONS (EXACT SIGNATURES) ──────────────────────────────
DROP FUNCTION IF EXISTS public.manage_qr_channel_v4(uuid, text, boolean, text);
DROP FUNCTION IF EXISTS public.cancel_qr_order_v4(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.settle_ban_session_v4(uuid, uuid, text, text, uuid, integer, numeric, text, numeric);
DROP FUNCTION IF EXISTS public.send_qr_order_to_kitchen_v4(uuid, uuid, text, text);
DROP FUNCTION IF EXISTS public.mark_qr_order_paid_v4(uuid, uuid, text, text);
DROP FUNCTION IF EXISTS public.assign_qr_order_table_v4(uuid, uuid, uuid);
DROP FUNCTION IF EXISTS public.update_qr_order_items_v4(uuid, uuid, integer, jsonb);
DROP FUNCTION IF EXISTS public.get_qr_request_detail_v4(uuid, uuid);
DROP FUNCTION IF EXISTS public.claim_qr_handoff_v4(text, uuid);
DROP FUNCTION IF EXISTS public.regenerate_handoff_token_v4(text);
DROP FUNCTION IF EXISTS public.get_qr_request_status_v4(text);
DROP FUNCTION IF EXISTS public.submit_qr_order_v4(text, jsonb, text, text, text);
DROP FUNCTION IF EXISTS public.get_qr_menu_v4(text, text);
DROP FUNCTION IF EXISTS public.get_qr_channel_info_v4(text);
DROP FUNCTION IF EXISTS public.verify_staff_qr_membership_v4(uuid, boolean, boolean);

-- ── 3. XÓA RLS POLICIES ──────────────────────────────────────────────────────
DROP POLICY IF EXISTS qr_coupon_redemptions_select_policy ON public.qr_coupon_redemptions;
DROP POLICY IF EXISTS payment_settlements_select_policy ON public.payment_settlements;
DROP POLICY IF EXISTS ban_session_order_items_select_policy ON public.ban_session_order_items;
DROP POLICY IF EXISTS ban_session_orders_select_policy ON public.ban_session_orders;
DROP POLICY IF EXISTS qr_kitchen_idemp_select_policy ON public.qr_kitchen_idempotency;
DROP POLICY IF EXISTS qr_payment_idemp_select_policy ON public.qr_payment_idempotency;
DROP POLICY IF EXISTS product_topping_links_select_policy ON public.product_topping_links;
DROP POLICY IF EXISTS qr_audit_logs_staff_select_policy ON public.qr_audit_logs;
DROP POLICY IF EXISTS qr_request_items_staff_select_policy ON public.qr_request_items;
DROP POLICY IF EXISTS qr_requests_staff_select_policy ON public.qr_requests;
DROP POLICY IF EXISTS qr_channels_select_policy ON public.qr_channels;

-- ── 4. XÓA CÁC BẢNG QR V4 (THEO THỨ TỰ PHỤ THUỘC NGƯỢC, KHÔNG CASCADE) ───────
DROP TABLE IF EXISTS public.qr_coupon_redemptions;
DROP TABLE IF EXISTS public.payment_settlements;
DROP TABLE IF EXISTS public.ban_session_order_items;
DROP TABLE IF EXISTS public.ban_session_orders;
DROP TABLE IF EXISTS public.qr_kitchen_idempotency;
DROP TABLE IF EXISTS public.qr_payment_idempotency;
DROP TABLE IF EXISTS public.product_topping_links;
DROP TABLE IF EXISTS public.qr_audit_logs;
DROP TABLE IF EXISTS public.qr_handoff_tokens;
DROP TABLE IF EXISTS public.qr_request_items;
DROP TABLE IF EXISTS public.qr_requests;
DROP TABLE IF EXISTS public.qr_channels;
