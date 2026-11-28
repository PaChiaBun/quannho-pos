-- ============================================================================
-- VÁ QUYỀN: gửi bếp + RPC báo cáo (QC độc lập 26/10/2026) — CHƯA áp production, chờ Chủ Quán duyệt
--  1. send_kitchen_ticket_v2 (SECURITY DEFINER, PUBLIC gọi được, không kiểm người gọi): ai có anon key
--     cũng đánh dấu "đã gửi bếp" món của quán khác và tạo phiếu bếp với p_store_id tùy ý.
--     → thêm chốt: người gọi phải là thành viên quán (qn_is_member) + phiên bàn phải thuộc p_store_id;
--       bỏ quyền PUBLIC, giữ anon/authenticated/service_role (app gọi ở ban_screen.dart; app cũ/mở app lúc
--       mất mạng còn chạy anon + x-user-id — lỗi quyền ở đây KHÔNG lùi về đường cũ mà báo lỗi gửi bếp).
--       QR: approve_and_send_table_v4 gọi lồng (chạy bằng quyền chủ hàm) → không cần quyền EXECUTE của khách.
--  2. 4 RPC báo cáo *_for_range_v1: bỏ quyền PUBLIC + anon, chỉ authenticated/service_role.
--     anon + header x-user-id (giả được) hết đọc báo cáo qua RPC. App vẫn chạy: dashboard_repository.dart
--     bắt mọi lỗi RPC và tự tính từ bảng (với JWT thì RLS như cũ).
--  KHÔNG đổi qn_caller_id(): đường header còn dùng cho RLS cả hệ thống — đóng theo kế hoạch JWT (Pha 1–3).
--  Không có lệnh cấp/đổi ROLE (chỉ GRANT/REVOKE trên hàm) → chạy bản sao cùng cụm an toàn.
--  Hoàn tác: 20261026_va_quyen_bep_bao_cao_v1_ROLLBACK.sql
-- ============================================================================
BEGIN;

-- PREFLIGHT: thân hàm hiện tại phải đúng bản 20260912 (md5 prosrc) — khác thì dừng, không ghi đè bản lạ
DO $pf$
DECLARE v_md5 text;
BEGIN
  SELECT md5(prosrc) INTO v_md5 FROM pg_proc WHERE oid = to_regprocedure('public.send_kitchen_ticket_v2(uuid, uuid, text, text, text, uuid[])');
  RAISE NOTICE 'VA_QUYEN PREFLIGHT: send_kitchen_ticket_v2 md5=%', v_md5;
  IF v_md5 IS NULL THEN RAISE EXCEPTION 'VA_QUYEN PREFLIGHT_FAIL: thiếu send_kitchen_ticket_v2'; END IF;
  IF v_md5 <> '749c84bbf74a2e745b5104e83bba06ae' THEN
    RAISE EXCEPTION 'VA_QUYEN PREFLIGHT_FAIL: send_kitchen_ticket_v2 khác bản 20260912 (md5 %) — so lại trước khi áp', v_md5;
  END IF;
  IF to_regprocedure('public.qn_is_member(uuid)') IS NULL THEN RAISE EXCEPTION 'VA_QUYEN PREFLIGHT_FAIL: thiếu qn_is_member'; END IF;
END $pf$;

-- 1) send_kitchen_ticket_v2: thêm bước 0 kiểm người gọi; phần còn lại giữ nguyên bản 20260912
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
  v_role text;
BEGIN
  -- 0. Kiểm người gọi (vá 26/10/2026): chỉ thành viên của ĐÚNG quán, và phiên bàn phải thuộc quán đó.
  --    Gọi lồng từ approve_and_send_table_v4 (QR) vẫn qua vì người gọi là nhân viên đã được kiểm ở ngoài.
  BEGIN v_role := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role';
  EXCEPTION WHEN OTHERS THEN v_role := NULL; END;
  IF v_role IS DISTINCT FROM 'service_role' AND NOT public.qn_is_member(p_store_id) THEN
    RAISE EXCEPTION 'KITCHEN_FORBIDDEN: không phải thành viên quán' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ban_sessions s WHERE s.id = p_session_id AND s.store_id = p_store_id) THEN
    RAISE EXCEPTION 'KITCHEN_SESSION_NOT_IN_STORE: phiên bàn không thuộc quán này' USING ERRCODE = '42501';
  END IF;

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

REVOKE ALL ON FUNCTION public.send_kitchen_ticket_v2(uuid, uuid, text, text, text, uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_kitchen_ticket_v2(uuid, uuid, text, text, text, uuid[]) TO anon, authenticated, service_role;

-- 2) RPC báo cáo: chỉ phiên JWT
REVOKE ALL ON FUNCTION
  public.get_report_stats_for_range_v1(uuid, timestamptz, timestamptz),
  public.get_daily_revenue_for_range_v1(uuid, timestamptz, timestamptz, text),
  public.get_top_products_for_range_v1(uuid, timestamptz, timestamptz, text, integer),
  public.get_sold_categories_for_range_v1(uuid, timestamptz, timestamptz)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION
  public.get_report_stats_for_range_v1(uuid, timestamptz, timestamptz),
  public.get_daily_revenue_for_range_v1(uuid, timestamptz, timestamptz, text),
  public.get_top_products_for_range_v1(uuid, timestamptz, timestamptz, text, integer),
  public.get_sold_categories_for_range_v1(uuid, timestamptz, timestamptz)
  TO authenticated, service_role;

DO $chk$
BEGIN
  IF has_function_privilege('anon', 'public.get_report_stats_for_range_v1(uuid,timestamptz,timestamptz)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.get_report_stats_for_range_v1(uuid,timestamptz,timestamptz)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.send_kitchen_ticket_v2(uuid, uuid, text, text, text, uuid[])', 'EXECUTE') THEN
    RAISE EXCEPTION 'VA_QUYEN: quyền sau khi áp không đúng';
  END IF;
  RAISE NOTICE 'VA_QUYEN v1: áp xong';
END $chk$;

COMMIT;
