-- ============================================================================
-- HOÀN TÁC 20261028_cong_thu_phi_dot_a.sql
--   • Gỡ mọi hàm của cổng thu phí đợt A.
--   • GIỮ dữ liệu: bảng billing_plans / billing_orders, cài đặt 'billing_bank', các dòng nhật ký 'payment' và hạn Pro
--     đã gia hạn (xoá tay nếu chắc chắn: DROP TABLE public.billing_orders, public.billing_plans;).
--   • Ràng buộc platform_settings / admin_store_actions giữ bản mở rộng (dữ liệu cũ vẫn hợp lệ).
-- ============================================================================
BEGIN;
DROP FUNCTION IF EXISTS public.admin_billing_overview_v1(text, text, int, int);
DROP FUNCTION IF EXISTS public.admin_billing_set_bank_v1(text, text, text, text);
DROP FUNCTION IF EXISTS public.admin_billing_set_plan_v1(text, bigint, boolean);
DROP FUNCTION IF EXISTS public.admin_billing_mark_paid_v1(uuid, bigint, text);
DROP FUNCTION IF EXISTS public.admin_billing_cancel_order_v1(uuid);
DROP FUNCTION IF EXISTS public.billing_info_v1(uuid);
DROP FUNCTION IF EXISTS public.billing_create_order_v1(uuid, text);
DROP FUNCTION IF EXISTS public.billing_order_status_v1(uuid);
DROP FUNCTION IF EXISTS public.qn_billing_apply_order(uuid, uuid, text, bigint, text);
DROP FUNCTION IF EXISTS public.qn_billing_owner(uuid);
DROP FUNCTION IF EXISTS public.qn_billing_order_json(public.billing_orders);
DROP FUNCTION IF EXISTS public.qn_billing_order_state(public.billing_orders);
COMMIT;
NOTIFY pgrst, 'reload schema';
