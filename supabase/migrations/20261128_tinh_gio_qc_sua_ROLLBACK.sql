-- Hoàn tác 20261128_tinh_gio_qc_sua.sql: ba hàm về nguyên văn (đợt 4: xử lý cọc, thanh toán v6; đợt 7: chọn gói),
-- bỏ hàm ghi lại dòng tiền giờ.
CREATE OR REPLACE FUNCTION public.ban_dat_truoc_xu_ly_coc_v1(p_store_id uuid, p_id uuid, p_cach text, p_quy text DEFAULT 'cash')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE v_staff record; v_d record; v_k record; v_tru numeric; v_moi numeric; v_tt text;
BEGIN
  IF p_cach = 'hoan' THEN
    SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true, p_require_manage => true);
  ELSE
    SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);
  END IF;
  IF p_cach IS NULL OR p_cach NOT IN ('trong_vi', 'quan_giu', 'hoan') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Cách xử lý cọc không hợp lệ');
  END IF;
  IF p_cach = 'hoan' AND (p_quy IS NULL OR p_quy NOT IN ('cash', 'bank')) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_FUND', 'message', 'Hoàn cọc bằng Tiền mặt hoặc Chuyển khoản');
  END IF;
  SELECT * INTO v_d FROM public.ban_dat_truoc WHERE id = p_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND OR v_d.coc_trang_thai IS DISTINCT FROM 'da_thu' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Lượt đặt không có cọc chờ xử lý');
  END IF;
  -- lịch cố định: cọc chỉ xử lý khi không còn buổi nào chờ khách
  IF v_d.trang_thai IN ('da_dat', 'da_nhan') OR (v_d.chuoi_id IS NOT NULL AND EXISTS (
       SELECT 1 FROM public.ban_dat_truoc x WHERE x.store_id = p_store_id AND x.chuoi_id = v_d.chuoi_id AND x.trang_thai = 'da_dat')) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Còn buổi chờ khách: huỷ lượt đặt trước rồi mới xử lý cọc');
  END IF;

  IF p_cach = 'trong_vi' THEN
    UPDATE public.ban_dat_truoc SET coc_trang_thai = 'trong_vi', updated_at = now() WHERE id = v_d.id;
    RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('cach', 'trong_vi', 'tru_vi', 0));
  END IF;

  SELECT id, name, COALESCE(real_balance, 0) AS real_balance, COALESCE(bonus_balance, 0) AS bonus_balance
    INTO v_k FROM public.customers WHERE id = v_d.customer_id AND store_id = p_store_id FOR UPDATE;
  v_tru := LEAST(v_d.tien_coc, GREATEST(COALESCE(v_k.real_balance, 0), 0));
  IF v_k.id IS NOT NULL AND v_tru > 0 THEN
    v_moi := v_k.real_balance - v_tru;
    UPDATE public.customers SET real_balance = v_moi, updated_at = now() WHERE id = v_k.id;
    INSERT INTO public.balance_transactions (id, store_id, customer_id, type, amount, balance_after, bonus_after, note, created_at)
    VALUES (gen_random_uuid(), p_store_id, v_k.id, 'spend_real', v_tru, v_moi, v_k.bonus_balance,
            CASE WHEN p_cach = 'hoan' THEN 'Hoàn cọc đặt sân' ELSE 'Mất cọc đặt sân (quán giữ)' END, now());
  END IF;
  IF p_cach = 'hoan' AND v_tru > 0 THEN
    INSERT INTO public.finance_records (id, store_id, type, amount, description, reference_id, is_auto, recorded_at, fund_type)
    VALUES (gen_random_uuid(), p_store_id, 'expense', v_tru,
            'Hoàn cọc đặt sân: ' || COALESCE(NULLIF(btrim(v_k.name), ''), 'Khách hàng'), v_d.id, true, now(), p_quy);
  END IF;
  v_tt := CASE WHEN p_cach = 'hoan' THEN 'da_hoan' ELSE 'quan_giu' END;
  UPDATE public.ban_dat_truoc SET coc_trang_thai = v_tt, updated_at = now() WHERE id = v_d.id;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('cach', p_cach, 'tru_vi', v_tru));
END
$f$;

CREATE OR REPLACE FUNCTION public.settle_ban_session_v6(
  p_session_id uuid, p_store_id uuid, p_payment_method text DEFAULT 'cash', p_idempotency_key text DEFAULT NULL,
  p_customer_id uuid DEFAULT NULL, p_points_used integer DEFAULT 0, p_discount numeric DEFAULT 0,
  p_coupon_code text DEFAULT NULL, p_surcharge numeric DEFAULT 0, p_tra_vi numeric DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  v_r jsonb; v_data jsonb; v_set uuid; v_tong numeric; v_coc numeric := 0; v_khach_coc uuid; v_khach uuid;
  v_k record; v_tru numeric := 0; v_moi numeric; v_bt uuid; v_ban text; v_don uuid; v_fin record; v_ghi text;
BEGIN
  IF p_tra_vi IS NULL OR p_tra_vi < 0 OR p_tra_vi <> trunc(p_tra_vi) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Số tiền trả bằng ví không hợp lệ');
  END IF;

  SELECT COALESCE(sum(tien), 0), (array_agg(customer_id) FILTER (WHERE customer_id IS NOT NULL))[1]
    INTO v_coc, v_khach_coc
  FROM public.qn_coc_cua_phien_v1(p_store_id, p_session_id);
  IF v_coc > 0 AND p_customer_id IS NOT NULL AND p_customer_id IS DISTINCT FROM v_khach_coc THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'COC_KHAC_KHACH',
      'message', 'Bàn có tiền cọc trong ví của khách đã đặt; chọn đúng khách đó (hoặc bỏ chọn khách)');
  END IF;
  -- khách của hoá đơn: chọn tay → khách có cọc → khách của lượt đặt đã nhận vào phiên
  v_khach := COALESCE(p_customer_id, v_khach_coc,
    (SELECT customer_id FROM public.ban_dat_truoc
      WHERE store_id = p_store_id AND session_id = p_session_id AND trang_thai = 'da_nhan' AND customer_id IS NOT NULL
      ORDER BY gio_tu LIMIT 1));
  IF p_tra_vi > 0 AND v_khach IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'CAN_KHACH_HANG', 'message', 'Chọn khách hàng để trả bằng ví');
  END IF;

  PERFORM set_config('qn.settle_v6', '1', true);
  v_r := public.settle_ban_session_v5(p_session_id, p_store_id, p_payment_method, p_idempotency_key, v_khach,
                                      p_points_used, p_discount, p_coupon_code, p_surcharge);
  PERFORM set_config('qn.settle_v6', '', true);
  IF NOT COALESCE((v_r->>'success')::boolean, false) THEN RETURN v_r; END IF;
  v_data := v_r->'data';
  v_set := (v_data->>'settlement_id')::uuid;
  IF COALESCE((v_data->>'is_replay')::boolean, false) THEN
    v_tru := COALESCE((SELECT vi_da_tru FROM public.payment_settlements WHERE id = v_set), 0);
    v_tong := (v_data->>'total_amount')::numeric;
    RETURN jsonb_set(v_r, '{data}', v_data || jsonb_build_object('vi_da_tru', v_tru, 'khach_tra_them', v_tong - v_tru));
  END IF;

  v_tong := (v_data->>'total_amount')::numeric;
  IF v_khach IS NOT NULL AND v_coc + p_tra_vi > 0 AND v_tong > 0 THEN
    SELECT id, name, COALESCE(real_balance, 0) AS real_balance, COALESCE(bonus_balance, 0) AS bonus_balance
      INTO v_k FROM public.customers WHERE id = v_khach AND store_id = p_store_id FOR UPDATE;
    v_tru := LEAST(v_tong, v_coc + p_tra_vi, GREATEST(COALESCE(v_k.real_balance, 0), 0));
  END IF;

  IF v_tru > 0 THEN
    SELECT COALESCE(NULLIF(trim(t.label), ''), t.name) INTO v_ban
    FROM public.ban_sessions s JOIN public.ban_dining_tables t ON t.id = s.table_id::text WHERE s.id = p_session_id;
    v_ghi := CASE WHEN v_coc > 0 THEN ' (cọc ' || public.qn_tinh_gio_tien_chu_v0(v_coc) || 'đ)' ELSE '' END;
    v_moi := v_k.real_balance - v_tru;
    v_don := NULLIF(v_data->'canonical_order_ids'->>0, '')::uuid;
    v_bt := gen_random_uuid();
    UPDATE public.customers SET real_balance = v_moi, updated_at = now() WHERE id = v_k.id;
    INSERT INTO public.balance_transactions (id, store_id, customer_id, order_id, type, amount, balance_after, bonus_after, note, created_at)
    VALUES (v_bt, p_store_id, v_k.id, v_don, 'spend_real', v_tru, v_moi, v_k.bonus_balance,
            'Thanh toán ' || COALESCE(v_ban, 'bàn') || v_ghi, now());
    -- phiếu thu lúc thanh toán chỉ còn phần khách trả thêm; phần ví ghi quỹ 'wallet' (Thu Chi không tính quỹ ví)
    SELECT id, amount INTO v_fin FROM public.finance_records
     WHERE store_id = p_store_id AND reference_id = v_set AND type = 'income' AND is_auto FOR UPDATE;
    IF v_fin.id IS NOT NULL THEN
      IF v_fin.amount - v_tru <= 0 THEN
        DELETE FROM public.finance_records WHERE id = v_fin.id;
      ELSE
        UPDATE public.finance_records
           SET amount = amount - v_tru,
               description = description || ' (đã trừ ví khách ' || public.qn_tinh_gio_tien_chu_v0(v_tru) || 'đ)'
         WHERE id = v_fin.id;
      END IF;
    END IF;
    INSERT INTO public.finance_records (id, store_id, type, amount, description, reference_id, is_auto, recorded_at, fund_type)
    VALUES (gen_random_uuid(), p_store_id, 'income', v_tru,
            'Trả bằng ví khách: ' || COALESCE(NULLIF(btrim(v_k.name), ''), 'Khách hàng') || ' · ' || COALESCE(v_ban, 'bàn') || v_ghi,
            v_bt, true, now(), 'wallet');
    UPDATE public.payment_settlements SET vi_da_tru = v_tru WHERE id = v_set;
  END IF;
  IF v_coc > 0 THEN
    UPDATE public.ban_dat_truoc SET coc_trang_thai = 'da_tru', coc_settlement_id = v_set, updated_at = now()
     WHERE id IN (SELECT dat_id FROM public.qn_coc_cua_phien_v1(p_store_id, p_session_id));
  END IF;

  RETURN jsonb_set(v_r, '{data}', v_data || jsonb_build_object(
    'customer_id', v_khach, 'coc', v_coc, 'vi_da_tru', v_tru, 'khach_tra_them', v_tong - v_tru));
END
$f$;

CREATE OR REPLACE FUNCTION public.ban_chon_goi_gio_v1(p_store_id uuid, p_session_id uuid, p_goi_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE v_s record; v_g record;
BEGIN
  PERFORM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);
  SELECT * INTO v_s FROM public.ban_sessions WHERE id = p_session_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy phiên bàn');
  END IF;
  IF v_s.status <> 'open' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'SESSION_NOT_OPEN', 'message', 'Phiên bàn không còn mở');
  END IF;
  IF v_s.gio_bat_dau IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Bàn này không tính giờ');
  END IF;
  IF v_s.goi_phut IS NOT NULL THEN   -- đổi / bỏ gói đã chọn: đụng tiền khách đã thoả thuận
    PERFORM public.verify_staff_qr_membership_v4(p_store_id, p_require_manage => true);
  END IF;

  IF p_goi_id IS NULL THEN
    UPDATE public.ban_sessions SET goi_phut = NULL, goi_gia = NULL WHERE id = p_session_id;
    RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('goi_phut', NULL, 'goi_gia', NULL));
  END IF;
  SELECT * INTO v_g FROM public.ban_goi_gio
  WHERE id = p_goi_id AND store_id = p_store_id AND table_id = v_s.table_id::text;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Gói không còn ở bàn này');
  END IF;
  UPDATE public.ban_sessions SET goi_phut = v_g.so_phut, goi_gia = v_g.gia WHERE id = p_session_id;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('goi_phut', v_g.so_phut, 'goi_gia', v_g.gia));
END
$f$;

DROP FUNCTION IF EXISTS public.qn_tinh_gio_ghi_lai_neu_da_chot_v1(uuid, uuid, timestamptz);
