-- Migration 07: Atomic Kitchen Dispatch RPC with Pre-Mutation Validation & Single-Pass Station Normalization
-- File: supabase/migrations/20260814093500_qr_v3_07_kitchen_dispatch_rpc.sql

-- Preflight
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'send_to_kitchen_qr_v3') THEN
    RAISE EXCEPTION 'MIGRATION_07_PREFLIGHT_FAIL: Function send_to_kitchen_qr_v3 already exists';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.send_to_kitchen_qr_v3(
  p_request_id uuid,
  p_raw_token  text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sess            RECORD;
  v_req             RECORD;
  v_existing_order  uuid;
  v_table_uuid      uuid;
  v_table_name      text;
  v_zone_name       text := 'Khu vực';

  v_item            RECORD;
  v_prod            RECORD;
  v_mod_elem        jsonb;
  v_top_id          uuid;
  v_top_rec         RECORD;

  v_live_unit_price numeric(12,2);
  v_discrepancies   jsonb := '[]'::jsonb;
  v_has_discrepancy boolean := false;
  v_raw_station     text;
  v_norm_station    text;
  v_has_nong        boolean := false;
  v_has_bar         boolean := false;
  v_ticket_station  text;

  -- Section D.2: Single-pass validated items buffer
  v_validated_items_buf jsonb := '[]'::jsonb;
  v_val_item        jsonb;

  v_bsession_id     uuid;
  v_order_id        uuid;
  v_bsession_item_id uuid;
  v_ticket_id       uuid;
  v_round           integer := 1;
BEGIN
  SELECT * INTO v_sess FROM public.verify_pos_token_internal(p_raw_token);
  IF v_sess.session_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_TOKEN', 'message', 'Phiên làm việc không hợp lệ');
  END IF;

  IF NOT public.check_pos_staff_action_permission(v_sess.store_id, v_sess.staff_id, v_sess.user_account_id, 'qr_order.send_kitchen') THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'PERMISSION_DENIED', 'message', 'Không có quyền gửi bếp đơn QR');
  END IF;

  SELECT * INTO v_req FROM public.qr_requests WHERE id = p_request_id AND store_id = v_sess.store_id FOR UPDATE;
  IF v_req.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'REQUEST_NOT_FOUND', 'message', 'Đơn QR không tồn tại');
  END IF;

  -- Duplicate dispatch retry guard
  IF v_req.status = 'sent_kitchen' THEN
    SELECT id INTO v_existing_order FROM public.orders WHERE store_id = v_sess.store_id AND source_type = 'qr_order' AND source_id = p_request_id::text LIMIT 1;
    IF v_existing_order IS NULL THEN
      RAISE EXCEPTION 'MIGRATION_07_ERROR: CONSISTENCY_ERROR: Core order missing for sent_kitchen request %', p_request_id;
    END IF;
    RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('request_id', p_request_id, 'status', 'sent_kitchen', 'order_id', v_existing_order, 'is_duplicate_dispatch', true), 'error_code', NULL, 'message', NULL);
  END IF;

  IF v_req.status <> 'confirmed' THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'INVALID_STATE', 'message', 'Đơn QR chưa được xác nhận bởi nhân viên');
  END IF;

  -- Enforce claimant match
  IF (v_sess.staff_id IS NOT NULL AND (v_req.claimed_by_staff_id IS NULL OR v_req.claimed_by_staff_id <> v_sess.staff_id)) OR
     (v_sess.user_account_id IS NOT NULL AND (v_req.claimed_by_user_account_id IS NULL OR v_req.claimed_by_user_account_id <> v_sess.user_account_id)) THEN
    RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'CLAIMANT_MISMATCH', 'message', 'Đơn QR đã được xử lý bởi nhân viên khác');
  END IF;

  -- =========================================================================
  -- PHASE 1: PRE-MUTATION VALIDATION & SINGLE-PASS STATION NORMALIZATION
  -- =========================================================================

  FOR v_item IN SELECT * FROM public.qr_request_items WHERE request_id = p_request_id LOOP
    SELECT id, name, sell_price, station_code, is_active, is_available, is_deleted INTO v_prod
    FROM public.products
    WHERE id = v_item.product_id AND store_id = v_sess.store_id FOR SHARE;

    IF v_prod.id IS NULL OR v_prod.is_active IS NOT TRUE OR v_prod.is_available IS NOT TRUE OR v_prod.is_deleted IS TRUE THEN
      v_has_discrepancy := true;
      v_discrepancies := v_discrepancies || jsonb_build_object('product_id', v_item.product_id, 'product_name', v_item.product_name, 'reason', 'item_unavailable', 'old_unit_price', v_item.unit_price, 'new_unit_price', 0);
      CONTINUE;
    END IF;

    v_live_unit_price := v_prod.sell_price;

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
          v_has_discrepancy := true;
          v_discrepancies := v_discrepancies || jsonb_build_object('product_id', v_item.product_id, 'product_name', v_item.product_name, 'reason', 'topping_unavailable', 'old_unit_price', v_item.unit_price, 'new_unit_price', 0);
          EXIT;
        END IF;

        v_live_unit_price := v_live_unit_price + v_top_rec.sell_price;
      END LOOP;
    END IF;

    IF v_live_unit_price <> v_item.unit_price THEN
      v_has_discrepancy := true;
      v_discrepancies := v_discrepancies || jsonb_build_object('product_id', v_item.product_id, 'product_name', v_item.product_name, 'reason', 'price_changed', 'old_unit_price', v_item.unit_price, 'new_unit_price', v_live_unit_price);
    END IF;

    -- Station code normalization once in validation pass
    v_raw_station := LOWER(COALESCE(v_prod.station_code, ''));
    IF v_raw_station IN ('bep_nong', 'nong') THEN
      v_norm_station := 'nong';
      v_has_nong := true;
    ELSIF v_raw_station IN ('bep_bar', 'bar', 'nuoc', 'pha_che') THEN
      v_norm_station := 'bar';
      v_has_bar := true;
    ELSE
      -- Section D.3: Unknown station fail-closed (NO CORE ROWS CREATED)
      UPDATE public.qr_requests SET status = 'processing', updated_at = now() WHERE id = p_request_id;

      INSERT INTO public.qr_audit_logs(store_id, request_id, actor_type, actor_staff_id, actor_user_account_id, action, from_status, to_status, payload)
      VALUES (v_sess.store_id, p_request_id, 'staff', v_sess.staff_id, v_sess.user_account_id, 'unknown_station_revert', 'confirmed', 'processing', jsonb_build_object('product_id', v_item.product_id, 'raw_station_code', v_prod.station_code));

      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'UNKNOWN_STATION_CODE', 'message', 'Sản phẩm ' || v_prod.name || ' chưa được cấu hình bếp/bar hợp lệ');
    END IF;

    -- Buffer validated item along with normalized station
    v_validated_items_buf := v_validated_items_buf || jsonb_build_object(
      'product_id', v_item.product_id,
      'product_name', v_item.product_name,
      'unit_price', v_item.unit_price,
      'quantity', v_item.quantity,
      'subtotal', v_item.subtotal,
      'note', v_item.note,
      'modifiers_json', v_item.modifiers_json,
      'normalized_station', v_norm_station
    );
  END LOOP;

  -- Reconfirm required handling
  IF v_has_discrepancy THEN
    UPDATE public.qr_requests SET status = 'processing', updated_at = now() WHERE id = p_request_id;

    INSERT INTO public.qr_audit_logs(store_id, request_id, actor_type, actor_staff_id, actor_user_account_id, action, from_status, to_status, payload)
    VALUES (v_sess.store_id, p_request_id, 'staff', v_sess.staff_id, v_sess.user_account_id, 'price_discrepancy_revert', 'confirmed', 'processing', jsonb_build_object('discrepancy_items', v_discrepancies));

    RETURN jsonb_build_object('success', false, 'data', jsonb_build_object('discrepancy_items', v_discrepancies), 'error_code', 'ORDER_RECONFIRM_REQUIRED', 'message', 'Giá hoặc trạng thái món ăn đã thay đổi. Vui lòng xác nhận lại với khách');
  END IF;

  -- Ticket station determination
  IF v_has_nong AND v_has_bar THEN
    v_ticket_station := NULL;
  ELSIF v_has_bar THEN
    v_ticket_station := 'bar';
  ELSE
    v_ticket_station := 'nong';
  END IF;

  -- =========================================================================
  -- PHASE 2: CORE MUTATION (READING NORMALIZED STATION DIRECTLY FROM BUFFER)
  -- =========================================================================

  IF v_req.type = 'table' THEN
    BEGIN
      v_table_uuid := v_req.table_id::uuid;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('success', false, 'data', NULL, 'error_code', 'TABLE_ID_NOT_QR_COMPATIBLE', 'message', 'Bàn hiện tại có ID không hợp lệ với hệ thống QR');
    END;

    -- Lookup table & zone name from database
    SELECT t.name, z.name INTO v_table_name, v_zone_name
    FROM public.ban_dining_tables t
    LEFT JOIN public.ban_zones z ON z.id = t.zone_id AND z.store_id = v_sess.store_id
    WHERE t.id = v_req.table_id AND t.store_id = v_sess.store_id;

    IF v_table_name IS NULL THEN
      v_table_name := COALESCE(v_req.table_name, 'Bàn ' || v_req.table_id);
    END IF;
    IF v_zone_name IS NULL THEN
      v_zone_name := 'Khu vực';
    END IF;

    -- Lock table session
    PERFORM pg_advisory_xact_lock(hashtext(v_sess.store_id::text || '_table_session_' || v_table_uuid::text));

    -- Reuse or open session
    SELECT id INTO v_bsession_id FROM public.ban_sessions WHERE store_id = v_sess.store_id AND table_id = v_table_uuid AND status = 'open' LIMIT 1;

    IF v_bsession_id IS NULL THEN
      v_bsession_id := gen_random_uuid();
      INSERT INTO public.ban_sessions(id, store_id, table_id, status, opened_at, guest_count, waiter_id)
      VALUES (v_bsession_id, v_sess.store_id, v_table_uuid, 'open', now(), 1, v_sess.staff_id);
    END IF;

    -- Lock parent session for ticket round
    PERFORM id FROM public.ban_sessions WHERE id = v_bsession_id FOR UPDATE;

    SELECT COALESCE(MAX(round), 0) + 1 INTO v_round FROM public.kitchen_tickets WHERE session_id = v_bsession_id;

    -- Create POS order
    v_order_id := gen_random_uuid();
    INSERT INTO public.orders(id, store_id, device_id, staff_id, source_type, source_id, total, status, note)
    VALUES (v_order_id, v_sess.store_id, v_sess.device_id, v_sess.staff_id, 'qr_order', p_request_id::text, v_req.total_amount, 'open', v_req.note);

    -- Create Ticket
    v_ticket_id := gen_random_uuid();
    INSERT INTO public.kitchen_tickets(id, store_id, order_id, session_id, table_label, zone_label, round, station_code, status, sent_at)
    VALUES (v_ticket_id, v_sess.store_id, v_order_id, v_bsession_id, v_table_name, v_zone_name, v_round, v_ticket_station, 'cho', now());

    -- Section D.4: Insert Items reading normalized_station directly from buffer (NO SECOND QUERY OR FALLBACK)
    FOR v_val_item IN SELECT * FROM jsonb_array_elements(v_validated_items_buf) LOOP
      v_bsession_item_id := gen_random_uuid();
      INSERT INTO public.ban_session_items(id, store_id, session_id, product_id, product_name, unit_price, quantity, subtotal, modifiers_json, added_by, kitchen_status)
      VALUES (
        v_bsession_item_id, v_sess.store_id, v_bsession_id,
        (v_val_item ->> 'product_id')::uuid, v_val_item ->> 'product_name',
        (v_val_item ->> 'unit_price')::numeric, (v_val_item ->> 'quantity')::integer,
        (v_val_item ->> 'subtotal')::numeric, (v_val_item -> 'modifiers_json')::text,
        v_sess.staff_id, 'da_gui'
      );

      INSERT INTO public.order_items(id, store_id, order_id, product_id, name, qty, unit_price, note, modifiers_json)
      VALUES (
        gen_random_uuid(), v_sess.store_id, v_order_id,
        (v_val_item ->> 'product_id')::uuid, v_val_item ->> 'product_name',
        (v_val_item ->> 'quantity')::integer, (v_val_item ->> 'unit_price')::numeric,
        v_val_item ->> 'note', (v_val_item -> 'modifiers_json')::text
      );

      INSERT INTO public.kitchen_ticket_items(id, store_id, ticket_id, session_item_id, product_id, name, product_name, qty, quantity, status, modifiers_json, station_code)
      VALUES (
        gen_random_uuid(), v_sess.store_id, v_ticket_id, v_bsession_item_id,
        v_val_item ->> 'product_id', v_val_item ->> 'product_name', v_val_item ->> 'product_name',
        (v_val_item ->> 'quantity')::integer, (v_val_item ->> 'quantity')::integer,
        'cho', (v_val_item -> 'modifiers_json')::text, v_val_item ->> 'normalized_station'
      );
    END LOOP;

  ELSE -- COUNTER BRANCH
    v_order_id := gen_random_uuid();
    INSERT INTO public.orders(id, store_id, device_id, staff_id, source_type, source_id, total, status, note)
    VALUES (v_order_id, v_sess.store_id, v_sess.device_id, v_sess.staff_id, 'qr_order', p_request_id::text, v_req.total_amount, 'open', v_req.note);

    v_ticket_id := gen_random_uuid();
    INSERT INTO public.kitchen_tickets(id, store_id, order_id, session_id, table_label, zone_label, round, station_code, status, sent_at)
    VALUES (v_ticket_id, v_sess.store_id, v_order_id, NULL, 'Mang đi ' || v_req.pickup_code, 'Mang đi', 1, v_ticket_station, 'cho', now());

    FOR v_val_item IN SELECT * FROM jsonb_array_elements(v_validated_items_buf) LOOP
      INSERT INTO public.order_items(id, store_id, order_id, product_id, name, qty, unit_price, note, modifiers_json)
      VALUES (
        gen_random_uuid(), v_sess.store_id, v_order_id,
        (v_val_item ->> 'product_id')::uuid, v_val_item ->> 'product_name',
        (v_val_item ->> 'quantity')::integer, (v_val_item ->> 'unit_price')::numeric,
        v_val_item ->> 'note', (v_val_item -> 'modifiers_json')::text
      );

      INSERT INTO public.kitchen_ticket_items(id, store_id, ticket_id, session_item_id, product_id, name, product_name, qty, quantity, status, modifiers_json, station_code)
      VALUES (
        gen_random_uuid(), v_sess.store_id, v_ticket_id, NULL,
        v_val_item ->> 'product_id', v_val_item ->> 'product_name', v_val_item ->> 'product_name',
        (v_val_item ->> 'quantity')::integer, (v_val_item ->> 'quantity')::integer,
        'cho', (v_val_item -> 'modifiers_json')::text, v_val_item ->> 'normalized_station'
      );
    END LOOP;
  END IF;

  -- Complete state transition
  UPDATE public.qr_requests SET status = 'sent_kitchen', updated_at = now() WHERE id = p_request_id;

  INSERT INTO public.qr_audit_logs(store_id, request_id, actor_type, actor_staff_id, actor_user_account_id, action, from_status, to_status, payload)
  VALUES (v_sess.store_id, p_request_id, 'staff', v_sess.staff_id, v_sess.user_account_id, 'send_kitchen', 'confirmed', 'sent_kitchen', jsonb_build_object('order_id', v_order_id, 'ticket_id', v_ticket_id));

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'request_id', p_request_id,
      'status', 'sent_kitchen',
      'order_id', v_order_id,
      'is_duplicate_dispatch', false
    ),
    'error_code', NULL,
    'message', NULL
  );
END;
$$;
ALTER FUNCTION public.send_to_kitchen_qr_v3(uuid, text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.send_to_kitchen_qr_v3(uuid, text) FROM PUBLIC, anon, authenticated;

-- Postflight Exact Function Signature Check
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'send_to_kitchen_qr_v3') THEN
    RAISE EXCEPTION 'MIGRATION_07_POSTFLIGHT_FAIL: Function send_to_kitchen_qr_v3 missing';
  END IF;
END $$;
