-- Migration 05: Staff Order State Machine RPCs (Pending Queue, Claim, Confirm, Reject & Expiry)
-- File: supabase/migrations/20260814092500_qr_v3_05_staff_state_rpcs.sql

-- Preflight
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_pending_qr_requests_v3') THEN
    RAISE EXCEPTION 'MIGRATION_05_PREFLIGHT_FAIL: Function get_pending_qr_requests_v3 already exists';
  END IF;
END $$;

-- 1. get_pending_qr_requests_v3
CREATE OR REPLACE FUNCTION public.get_pending_qr_requests_v3(
  p_raw_token text,
  p_status    text DEFAULT NULL,
  p_limit     integer DEFAULT 50,
  p_before    timestamptz DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess RECORD;
  v_reqs jsonb;
  v_lim  integer;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.view_pending') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền xem danh sách đơn QR');
  END IF;

  IF p_status IS NOT NULL AND p_status NOT IN ('pending_staff', 'processing', 'confirmed', 'sent_kitchen', 'rejected', 'expired') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_STATUS', 'message', 'Trạng thái tìm kiếm không hợp lệ');
  END IF;

  v_lim := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);

  -- Subquery ORDER BY / LIMIT before jsonb_agg for accurate pagination
  SELECT jsonb_agg(t.req_json) INTO v_reqs
  FROM (
    SELECT jsonb_build_object(
      'request_id', r.id,
      'status', r.status,
      'type', r.type,
      'table_id', r.table_id,
      'table_name', r.table_name,
      'pickup_code', r.pickup_code,
      'total_amount', r.total_amount,
      'item_count', (SELECT COUNT(*) FROM public.qr_request_items WHERE request_id = r.id),
      'created_at', r.created_at
    ) AS req_json
    FROM public.qr_requests r
    WHERE r.store_id = v_sess.store_id
      AND (p_status IS NULL OR r.status = p_status)
      AND (p_before IS NULL OR r.created_at < p_before)
    ORDER BY r.created_at DESC
    LIMIT v_lim
  ) t;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('requests', COALESCE(v_reqs, '[]'::jsonb)), 'error_code', NULL, 'message', NULL);
END;
$$;
ALTER FUNCTION public.get_pending_qr_requests_v3(text, text, integer, timestamptz) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_pending_qr_requests_v3(text, text, integer, timestamptz) FROM PUBLIC, anon, authenticated;

-- 2. claim_qr_request_v3
CREATE OR REPLACE FUNCTION public.claim_qr_request_v3(
  p_request_id uuid,
  p_raw_token  text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess RECORD;
  v_req  RECORD;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.claim') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền nhận đơn QR');
  END IF;

  SELECT * INTO v_req FROM public.qr_requests WHERE id = p_request_id AND store_id = v_sess.store_id FOR UPDATE;
  IF v_req.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'REQUEST_NOT_FOUND', 'message', 'Đơn QR không tồn tại');
  END IF;

  IF v_req.status <> 'pending_staff' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'ALREADY_CLAIMED', 'message', 'Đơn QR đã được xử lý bởi nhân viên khác');
  END IF;

  UPDATE public.qr_requests
  SET status = 'processing',
      claimed_by_staff_id = v_sess.staff_id,
      claimed_by_user_account_id = v_sess.user_account_id,
      updated_at = now()
  WHERE id = p_request_id;

  INSERT INTO public.qr_audit_logs(store_id, request_id, actor_type, actor_staff_id, actor_user_account_id, action, from_status, to_status)
  VALUES (v_sess.store_id, p_request_id, 'staff', v_sess.staff_id, v_sess.user_account_id, 'claim_request', 'pending_staff', 'processing');

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'request_id', p_request_id,
      'status', 'processing',
      'claimed_by_principal_type', v_sess.principal_type,
      'claimed_by_staff_id', v_sess.staff_id,
      'claimed_by_user_account_id', v_sess.user_account_id
    ),
    'error_code', NULL,
    'message', NULL
  );
END;
$$;
ALTER FUNCTION public.claim_qr_request_v3(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.claim_qr_request_v3(uuid, text) FROM PUBLIC, anon, authenticated;

-- 3. confirm_qr_request_v3 (Enforces Claimant Match & Revalidates Prices)
CREATE OR REPLACE FUNCTION public.confirm_qr_request_v3(
  p_request_id uuid,
  p_raw_token  text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess           RECORD;
  v_req            RECORD;
  v_item           RECORD;
  v_prod           RECORD;
  v_mod_elem       jsonb;
  v_top_id         uuid;
  v_top_rec        RECORD;
  v_new_unit_price numeric(12,2);
  v_new_subtotal   numeric(12,2);
  v_new_mods       jsonb;
  v_new_req_total  numeric(12,2) := 0.00;
  v_new_quote_ver  integer;

  v_updates_buf    jsonb := '[]'::jsonb;
  v_upd_item       jsonb;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.confirm') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền xác nhận đơn QR');
  END IF;

  SELECT * INTO v_req FROM public.qr_requests WHERE id = p_request_id AND store_id = v_sess.store_id FOR UPDATE;
  IF v_req.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'REQUEST_NOT_FOUND', 'message', 'Đơn QR không tồn tại');
  END IF;

  IF v_req.status <> 'processing' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_STATE', 'message', 'Đơn QR không ở trạng thái đang xử lý');
  END IF;

  -- Enforce claimant match (confirm must be executed by the principal who claimed the request)
  IF (v_sess.staff_id IS NOT NULL AND (v_req.claimed_by_staff_id IS NULL OR v_req.claimed_by_staff_id <> v_sess.staff_id)) OR
     (v_sess.user_account_id IS NOT NULL AND (v_req.claimed_by_user_account_id IS NULL OR v_req.claimed_by_user_account_id <> v_sess.user_account_id)) THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'CLAIMANT_MISMATCH', 'message', 'Đơn QR đã được nhận bởi nhân viên khác');
  END IF;

  -- Two-Pass: Pass 1 calculates and validates all items before modifying database
  FOR v_item IN SELECT * FROM public.qr_request_items WHERE request_id = p_request_id LOOP
    SELECT id, name, sell_price, is_active, is_available, is_deleted INTO v_prod
    FROM public.products
    WHERE id = v_item.product_id AND store_id = v_sess.store_id FOR SHARE;

    IF v_prod.id IS NULL OR v_prod.is_active IS NOT TRUE OR v_prod.is_available IS NOT TRUE OR v_prod.is_deleted IS TRUE THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'ITEM_UNAVAILABLE', 'message', 'Sản phẩm ' || v_item.product_name || ' không còn kinh doanh hoặc đã tạm ngưng');
    END IF;

    v_new_unit_price := v_prod.sell_price;
    v_new_mods := '[]'::jsonb;

    IF jsonb_typeof(v_item.modifiers_json) = 'array' THEN
      FOR v_mod_elem IN SELECT * FROM jsonb_array_elements(v_item.modifiers_json) LOOP
        v_top_id := (v_mod_elem ->> 'topping_id')::uuid;

        SELECT t.id, t.name, t.sell_price INTO v_top_rec
        FROM public.product_topping_links l
        JOIN public.products t ON t.id = l.topping_id
        WHERE l.product_id = v_item.product_id
          AND l.topping_id = v_top_id
          AND t.store_id = v_sess.store_id
          AND t.is_active = true
          AND t.is_available = true
          AND t.is_deleted = false
          AND t.is_topping = true FOR SHARE;

        IF v_top_rec.id IS NULL THEN
          RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'ITEM_UNAVAILABLE', 'message', 'Topping chọn kèm không còn kinh doanh hoặc đã tạm ngưng');
        END IF;

        v_new_unit_price := v_new_unit_price + v_top_rec.sell_price;
        v_new_mods := v_new_mods || jsonb_build_object('topping_id', v_top_rec.id, 'name', v_top_rec.name, 'unit_price', v_top_rec.sell_price);
      END LOOP;
    END IF;

    v_new_subtotal := v_new_unit_price * v_item.quantity;
    v_new_req_total := v_new_req_total + v_new_subtotal;

    v_updates_buf := v_updates_buf || jsonb_build_object(
      'item_id', v_item.id,
      'product_name', v_prod.name,
      'unit_price', v_new_unit_price,
      'subtotal', v_new_subtotal,
      'modifiers_json', v_new_mods
    );
  END LOOP;

  -- Pass 2: Apply updates after 100% validation success
  FOR v_upd_item IN SELECT * FROM jsonb_array_elements(v_updates_buf) LOOP
    UPDATE public.qr_request_items
    SET product_name = v_upd_item ->> 'product_name',
        unit_price = (v_upd_item ->> 'unit_price')::numeric,
        subtotal = (v_upd_item ->> 'subtotal')::numeric,
        modifiers_json = v_upd_item -> 'modifiers_json'
    WHERE id = (v_upd_item ->> 'item_id')::uuid;
  END LOOP;

  v_new_quote_ver := v_req.quote_version + 1;

  UPDATE public.qr_requests
  SET status = 'confirmed',
      total_amount = v_new_req_total,
      quote_version = v_new_quote_ver,
      updated_at = now()
  WHERE id = p_request_id;

  INSERT INTO public.qr_audit_logs(store_id, request_id, actor_type, actor_staff_id, actor_user_account_id, action, from_status, to_status, payload)
  VALUES (v_sess.store_id, p_request_id, 'staff', v_sess.staff_id, v_sess.user_account_id, 'confirm_request', 'processing', 'confirmed', jsonb_build_object('quote_version', v_new_quote_ver, 'total_amount', v_new_req_total));

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object('request_id', p_request_id, 'status', 'confirmed', 'quote_version', v_new_quote_ver, 'total_amount', v_new_req_total),
    'error_code', NULL,
    'message', NULL
  );
END;
$$;
ALTER FUNCTION public.confirm_qr_request_v3(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.confirm_qr_request_v3(uuid, text) FROM PUBLIC, anon, authenticated;

-- 4. reject_qr_request_v3 (Requires Reason, Trimmed, Max 255 Chars)
CREATE OR REPLACE FUNCTION public.reject_qr_request_v3(
  p_request_id    uuid,
  p_raw_token     text,
  p_reject_reason text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess       RECORD;
  v_req        RECORD;
  v_clean_reason text;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.reject') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền từ chối đơn QR');
  END IF;

  v_clean_reason := TRIM(COALESCE(p_reject_reason, ''));
  IF v_clean_reason = '' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'REASON_REQUIRED', 'message', 'Vui lòng nhập lý do từ chối đơn hàng');
  END IF;

  IF length(v_clean_reason) > 255 THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'REASON_TOO_LONG', 'message', 'Lý do từ chối không được vượt quá 255 ký tự');
  END IF;

  SELECT * INTO v_req FROM public.qr_requests WHERE id = p_request_id AND store_id = v_sess.store_id FOR UPDATE;
  IF v_req.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'REQUEST_NOT_FOUND', 'message', 'Đơn QR không tồn tại');
  END IF;

  IF v_req.status NOT IN ('pending_staff', 'processing', 'confirmed') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_STATE', 'message', 'Không thể từ chối đơn ở trạng thái hiện tại');
  END IF;

  UPDATE public.qr_requests
  SET status = 'rejected',
      reject_reason = v_clean_reason,
      updated_at = now()
  WHERE id = p_request_id;

  INSERT INTO public.qr_audit_logs(store_id, request_id, actor_type, actor_staff_id, actor_user_account_id, action, from_status, to_status, payload)
  VALUES (v_sess.store_id, p_request_id, 'staff', v_sess.staff_id, v_sess.user_account_id, 'reject_request', v_req.status, 'rejected', jsonb_build_object('reason', v_clean_reason));

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object('request_id', p_request_id, 'status', 'rejected', 'reject_reason', v_clean_reason),
    'error_code', NULL,
    'message', NULL
  );
END;
$$;
ALTER FUNCTION public.reject_qr_request_v3(uuid, text, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.reject_qr_request_v3(uuid, text, text) FROM PUBLIC, anon, authenticated;

-- 5. cleanup_expired_qr_requests_v3 (Service Role Maintenance with SKIP LOCKED)
CREATE OR REPLACE FUNCTION public.cleanup_expired_qr_requests_v3()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_rec RECORD;
  v_cnt integer := 0;
BEGIN
  FOR v_rec IN
    SELECT id, store_id FROM public.qr_requests
    WHERE status = 'pending_staff' AND created_at < (now() - INTERVAL '30 minutes')
    FOR UPDATE SKIP LOCKED
    LIMIT 100
  LOOP
    UPDATE public.qr_requests SET status = 'expired', updated_at = now() WHERE id = v_rec.id;

    INSERT INTO public.qr_audit_logs(store_id, request_id, actor_type, action, from_status, to_status)
    VALUES (v_rec.store_id, v_rec.id, 'system', 'expire_request', 'pending_staff', 'expired');

    v_cnt := v_cnt + 1;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('expired_count', v_cnt), 'error_code', NULL, 'message', NULL);
END;
$$;
ALTER FUNCTION public.cleanup_expired_qr_requests_v3() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.cleanup_expired_qr_requests_v3() FROM PUBLIC, anon, authenticated;

-- Postflight Exact Function Signatures Check
DO $$
DECLARE
  v_func text;
BEGIN
  FOR v_func IN VALUES ('get_pending_qr_requests_v3'), ('claim_qr_request_v3'), ('confirm_qr_request_v3'), ('reject_qr_request_v3'), ('cleanup_expired_qr_requests_v3') LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = v_func) THEN
      RAISE EXCEPTION 'MIGRATION_05_POSTFLIGHT_FAIL: Function public.% missing', v_func;
    END IF;
  END LOOP;
END $$;
