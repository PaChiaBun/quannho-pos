-- ============================================================================
-- TEST: 20261126_qr_an_mon_tien_gio.sql — thực đơn QR và tính giá QR không nhận món "Tiền giờ".
-- Một giao dịch, kết thúc ROLLBACK. Mượn một kênh QR đang mở có sẵn, thêm món thử trong giao dịch.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._qrtg_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

DO $t$
DECLARE
  v_ch public.qr_channels%ROWTYPE;
  v_thuong uuid := gen_random_uuid();
  v_gio uuid := gen_random_uuid();
  v_nl uuid := gen_random_uuid();
  v_menu jsonb;
  v_ids text[];
  r jsonb;
BEGIN
  SELECT * INTO v_ch FROM public.qr_channels WHERE is_active ORDER BY created_at LIMIT 1;
  PERFORM public._qrtg_ok(v_ch.id IS NOT NULL, 'có kênh QR đang mở để thử');

  INSERT INTO public.products (id, store_id, name, category, unit, product_type, sell_price, cost_price,
                               is_active, is_deleted, is_available, is_topping, station_code, created_at, updated_at)
  VALUES
    (v_thuong, v_ch.store_id, 'QA món thường', 'QA', 'phần', 'finished', 25000, 0, true, false, true, false, 'nong', now(), 0),
    (v_gio,    v_ch.store_id, 'Tiền giờ 99.000 đ', 'Tiền giờ', 'giờ', 'finished', 99000, 0, true, false, true, false, 'nong', now(), 0),
    (v_nl,     v_ch.store_id, 'QA nguyên liệu', 'Nguyên liệu', 'kg', 'ingredient', 1000, 0, true, false, true, false, 'nong', now(), 0);

  v_menu := public.get_qr_menu_v4(v_ch.channel_code);
  PERFORM public._qrtg_ok((v_menu->>'success')::boolean, 'thực đơn QR vẫn trả được');
  SELECT array_agg(x->>'id') INTO v_ids FROM jsonb_array_elements(v_menu->'data'->'products') x;
  PERFORM public._qrtg_ok(v_thuong::text = ANY (v_ids), 'thực đơn QR còn món thường');
  PERFORM public._qrtg_ok(NOT (v_gio::text = ANY (v_ids)), 'thực đơn QR KHÔNG có món "Tiền giờ"');
  PERFORM public._qrtg_ok(NOT (v_nl::text = ANY (v_ids)), 'thực đơn QR vẫn không có nguyên liệu (bản vá 13/10 còn nguyên)');

  r := public.qr_price_items_v4(v_ch.store_id, jsonb_build_array(jsonb_build_object('product_id', v_gio, 'quantity', 1)));
  PERFORM public._qrtg_ok(NOT COALESCE((r->>'success')::boolean, false) AND r::text LIKE '%PRODUCT_NOT_AVAILABLE%',
    'tính giá QR từ chối món "Tiền giờ" (gửi đơn và sửa đơn đều đi qua đây)');

  r := public.qr_price_items_v4(v_ch.store_id, jsonb_build_array(jsonb_build_object('product_id', v_thuong, 'quantity', 2)));
  PERFORM public._qrtg_ok((r->>'success')::boolean AND (r->>'total')::numeric = 50000, 'tính giá QR món thường vẫn đúng (2 × 25.000)');

  PERFORM public._qrtg_ok(has_function_privilege('anon', 'public.get_qr_menu_v4(text)', 'execute'), 'khách (anon) vẫn mở được thực đơn QR');
  PERFORM public._qrtg_ok(NOT has_function_privilege('anon', 'public.qr_price_items_v4(uuid,jsonb)', 'execute'),
    'khách (anon) vẫn không gọi thẳng được hàm tính giá');
  RAISE NOTICE 'TẤT CẢ PASS';
END
$t$;

ROLLBACK;
