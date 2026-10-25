-- ============================================================================
-- HOÀN TÁC 20261026_va_quyen_bep_bao_cao_v1.sql — trả send_kitchen_ticket_v2 về bản 20260912 và quyền như cũ
-- (PUBLIC + anon gọi được cả 5 hàm). Chỉ chạy khi Chủ Quán đồng ý hoàn tác.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.send_kitchen_ticket_v2(
  p_session_id uuid,
  p_store_id uuid,
  p_table_label text,
  p_zone_label text,
  p_note text DEFAULT NULL,
  p_item_ids uuid[] DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_round integer;
  v_ticket_id uuid;
  v_now timestamptz := clock_timestamp();
  v_item RECORD;
  v_inserted_items_count integer := 0;
  v_locked_item_ids uuid[] := ARRAY[]::uuid[];
BEGIN
  -- 1. Khóa các hàng món cần gửi bằng FOR UPDATE để chống tranh chấp đồng thời
  FOR v_item IN
    SELECT bsi.id
    FROM public.ban_session_items bsi
    WHERE bsi.session_id = p_session_id
      AND bsi.kitchen_status = 'chua_gui'
      AND (p_item_ids IS NULL OR bsi.id = ANY(p_item_ids))
    ORDER BY bsi.added_at ASC
    FOR UPDATE OF bsi
  LOOP
    v_locked_item_ids := array_append(v_locked_item_ids, v_item.id);
  END LOOP;

  -- 2. Idempotency Guard: Nếu không còn món nào ở trạng thái 'chua_gui'
  -- (do request trước đã xử lý xong hoặc nhân viên bấm đúp), trả về thành công ngay mà không tạo ticket trùng
  IF cardinality(v_locked_item_ids) = 0 OR v_locked_item_ids IS NULL THEN
    SELECT id, round INTO v_ticket_id, v_round
    FROM public.kitchen_tickets
    WHERE session_id = p_session_id
    ORDER BY round DESC
    LIMIT 1;

    RETURN jsonb_build_object(
      'success', true,
      'already_sent', true,
      'ticket_id', v_ticket_id,
      'round', v_round,
      'items_count', 0,
      'message', 'Tất cả món đã được gửi bếp trước đó'
    );
  END IF;

  -- 3. Tính toán round tiếp theo một cách an toàn
  SELECT COALESCE(MAX(round), 0) + 1 INTO v_round
  FROM public.kitchen_tickets
  WHERE session_id = p_session_id;

  -- 4. Tạo Kitchen Ticket duy nhất
  v_ticket_id := gen_random_uuid();
  INSERT INTO public.kitchen_tickets (
    id,
    store_id,
    session_id,
    table_label,
    zone_label,
    round,
    status,
    sent_at,
    note
  ) VALUES (
    v_ticket_id,
    p_store_id,
    p_session_id,
    COALESCE(p_table_label, 'Bàn'),
    COALESCE(p_zone_label, 'Khu vực'),
    v_round,
    'cho',
    v_now,
    p_note
  );

  -- 5. Insert danh sách items vào kitchen_ticket_items kèm station_code từ products
  FOR v_item IN
    SELECT
      bsi.id AS session_item_id,
      bsi.product_id,
      bsi.product_name,
      bsi.quantity,
      bsi.note,
      bsi.modifiers_json,
      COALESCE(p.station_code, 'nong') AS station_code
    FROM public.ban_session_items bsi
    LEFT JOIN public.products p ON p.id = bsi.product_id
    WHERE bsi.id = ANY(v_locked_item_ids)
  LOOP
    INSERT INTO public.kitchen_ticket_items (
      id,
      store_id,
      ticket_id,
      session_item_id,
      product_id,
      name,
      product_name,
      qty,
      quantity,
      free_note,
      kitchen_note,
      modifiers_json,
      station_code,
      done
    ) VALUES (
      gen_random_uuid(),
      p_store_id,
      v_ticket_id,
      v_item.session_item_id,
      v_item.product_id,
      v_item.product_name,
      v_item.product_name,
      v_item.quantity::integer,
      v_item.quantity,
      v_item.note,
      v_item.modifiers_json,
      v_item.modifiers_json,
      COALESCE(v_item.station_code, 'nong'),
      false
    );
    v_inserted_items_count := v_inserted_items_count + 1;
  END LOOP;

  -- 6. Cập nhật trạng thái các món trong ban_session_items thành 'da_gui'
  UPDATE public.ban_session_items
  SET kitchen_status = 'da_gui'
  WHERE id = ANY(v_locked_item_ids);

  RETURN jsonb_build_object(
    'success', true,
    'already_sent', false,
    'ticket_id', v_ticket_id,
    'round', v_round,
    'items_count', v_inserted_items_count,
    'message', 'Gửi bếp thành công'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_kitchen_ticket_v2(uuid, uuid, text, text, text, uuid[]) TO PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION
  public.get_report_stats_for_range_v1(uuid, timestamptz, timestamptz),
  public.get_daily_revenue_for_range_v1(uuid, timestamptz, timestamptz, text),
  public.get_top_products_for_range_v1(uuid, timestamptz, timestamptz, text, integer),
  public.get_sold_categories_for_range_v1(uuid, timestamptz, timestamptz)
  TO PUBLIC, anon, authenticated, service_role;

DO $chk$
BEGIN
  IF md5((SELECT prosrc FROM pg_proc WHERE oid = to_regprocedure('public.send_kitchen_ticket_v2(uuid, uuid, text, text, text, uuid[])'))) <> '749c84bbf74a2e745b5104e83bba06ae' THEN
    RAISE EXCEPTION 'VA_QUYEN ROLLBACK: thân hàm không về đúng bản 20260912';
  END IF;
  RAISE NOTICE 'VA_QUYEN v1 ROLLBACK: xong';
END $chk$;

COMMIT;
