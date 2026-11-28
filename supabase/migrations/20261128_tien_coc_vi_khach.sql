-- ============================================================================
-- 20261128_tien_coc_vi_khach.sql — đợt 4 lộ trình tính giờ (.docs/ke-hoach-tien-coc.md)
-- Tiền cọc đặt sân = tiền trong VÍ KHÁCH (module Khách hàng). Chủ Quán chốt 28/11:
--   ghi Thu Chi ngay lúc nhận cọc; thanh toán bàn tự trừ cọc từ ví; huỷ / không đến hỏi 3 cách;
--   lịch cố định một lần cọc, trừ buổi đầu khách đến; máy cũ thanh toán bàn có cọc thì chặn.
--
--   ban_dat_truoc: customer_id, coc_trang_thai (da_thu | da_tru | trong_vi | quan_giu | da_hoan), coc_quy,
--                  coc_finance_id, coc_settlement_id, coc_khoa
--   payment_settlements.vi_da_tru   số tiền thanh toán bàn trả bằng ví khách
--   ban_dat_truoc_gan_khach_v1      gắn khách hàng cho lượt đặt (cả lịch cố định)
--   ban_dat_truoc_nhan_coc_v1       nhận cọc: cộng ví thật (KHÔNG thưởng gói nạp) + phiếu thu Thu Chi đúng quỹ
--   ban_dat_truoc_xu_ly_coc_v1      lượt huỷ / không đến: để trong ví | quán giữ | hoàn (chỉ Quản lý, phiếu chi)
--   qn_coc_cua_phien_v1             cọc chưa trừ của phiên bàn (lượt đã nhận + cả lịch cố định của nó)
--   settle_ban_session_v6           gọi NGUYÊN v5 (đơn hàng, kho, điểm không đổi) rồi trả phần cọc + p_tra_vi bằng ví:
--                                   trừ ví, phiếu thu lúc thanh toán = tổng − phần ví, phần ví ghi quỹ 'wallet'
--                                   (Thu Chi không tính quỹ ví, như bán ở quầy trả ví) → cọc không bị đếm hai lần
--   settle_ban_session_v5           thêm ĐÚNG một đoạn kiểm đầu hàm: gọi thẳng (máy cũ) khi phiên có cọc → chặn
-- Hoàn tác: 20261128_tien_coc_vi_khach_ROLLBACK.sql (v5 nguyên văn production 28/11). Test: supabase/tests/tien_coc_vi_khach_test.sql
-- ============================================================================

DO $pf$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'settle_ban_session_v5')
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'customers' AND column_name = 'real_balance') THEN
    RAISE EXCEPTION 'PREFLIGHT tien_coc_vi_khach: thiếu settle_ban_session_v5 hoặc ví khách';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'ban_dat_truoc' AND column_name = 'chuoi_id') THEN
    RAISE EXCEPTION 'PREFLIGHT tien_coc_vi_khach: chưa áp 20261128_dat_truoc_lich_co_dinh.sql (đợt 3)';
  END IF;
  RAISE NOTICE 'PREFLIGHT tien_coc_vi_khach: OK';
END
$pf$;

ALTER TABLE public.ban_dat_truoc
  ADD COLUMN IF NOT EXISTS customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS coc_trang_thai text,
  ADD COLUMN IF NOT EXISTS coc_quy text,
  ADD COLUMN IF NOT EXISTS coc_finance_id uuid,
  ADD COLUMN IF NOT EXISTS coc_settlement_id uuid,
  ADD COLUMN IF NOT EXISTS coc_khoa text;
DO $c$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ban_dat_truoc_coc_trang_thai') THEN
    ALTER TABLE public.ban_dat_truoc ADD CONSTRAINT ban_dat_truoc_coc_trang_thai
      CHECK (coc_trang_thai IS NULL OR coc_trang_thai IN ('da_thu', 'da_tru', 'trong_vi', 'quan_giu', 'da_hoan'));
  END IF;
END
$c$;
CREATE INDEX IF NOT EXISTS ban_dat_truoc_customer_idx ON public.ban_dat_truoc (customer_id) WHERE customer_id IS NOT NULL;
ALTER TABLE public.payment_settlements ADD COLUMN IF NOT EXISTS vi_da_tru numeric NOT NULL DEFAULT 0;

-- ── Cọc chưa trừ của một phiên bàn ───────────────────────────────────────────────────────────
-- Lượt đặt đã nhận vào phiên (da_nhan, session_id) + mọi buổi cùng lịch cố định của nó; cọc 'da_thu'.
CREATE OR REPLACE FUNCTION public.qn_coc_cua_phien_v1(p_store uuid, p_session uuid)
RETURNS TABLE (dat_id uuid, tien numeric, customer_id uuid)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
  WITH nhan AS (
    SELECT id, chuoi_id FROM public.ban_dat_truoc
    WHERE store_id = p_store AND session_id = p_session AND trang_thai = 'da_nhan'
  )
  SELECT d.id, d.tien_coc, d.customer_id
  FROM public.ban_dat_truoc d
  WHERE d.store_id = p_store AND d.coc_trang_thai = 'da_thu' AND d.tien_coc > 0
    AND (d.id IN (SELECT id FROM nhan)
         OR d.chuoi_id IN (SELECT chuoi_id FROM nhan WHERE chuoi_id IS NOT NULL))
$f$;
REVOKE ALL ON FUNCTION public.qn_coc_cua_phien_v1(uuid, uuid) FROM PUBLIC, anon, authenticated;
-- settle_ban_session_v5 thuộc postgres (SECURITY DEFINER) gọi hàm này
GRANT EXECUTE ON FUNCTION public.qn_coc_cua_phien_v1(uuid, uuid) TO postgres, service_role;

-- ── Gắn khách hàng cho lượt đặt ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ban_dat_truoc_gan_khach_v1(p_store_id uuid, p_id uuid, p_customer_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE v_staff record; v_d record; v_so int;
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);
  SELECT * INTO v_d FROM public.ban_dat_truoc WHERE id = p_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy lượt đặt');
  END IF;
  IF p_customer_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM public.customers WHERE id = p_customer_id AND store_id = p_store_id AND COALESCE(is_deleted, false) = false) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'CUSTOMER_NOT_FOUND', 'message', 'Không tìm thấy khách hàng trong quán');
  END IF;
  IF v_d.coc_trang_thai = 'da_thu' AND p_customer_id IS DISTINCT FROM v_d.customer_id THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Lượt đặt đã có cọc trong ví khách, không đổi khách được');
  END IF;
  -- cả lịch cố định đổi theo
  UPDATE public.ban_dat_truoc SET customer_id = p_customer_id, updated_at = now()
  WHERE store_id = p_store_id
    AND (id = p_id OR (v_d.chuoi_id IS NOT NULL AND chuoi_id = v_d.chuoi_id AND trang_thai = 'da_dat'))
    AND (coc_trang_thai IS DISTINCT FROM 'da_thu' OR customer_id IS NOT DISTINCT FROM p_customer_id);
  GET DIAGNOSTICS v_so = ROW_COUNT;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('so_luot', v_so));
END
$f$;

-- ── Nhận cọc: cộng ví thật (không thưởng gói nạp) + phiếu thu Thu Chi ngay ─────────────────────
CREATE OR REPLACE FUNCTION public.ban_dat_truoc_nhan_coc_v1(
  p_store_id uuid, p_id uuid, p_so_tien numeric, p_quy text, p_idempotency_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  TZ constant text := 'Asia/Ho_Chi_Minh';
  v_staff record; v_d record; v_k record; v_ban text; v_moi numeric; v_fin uuid := gen_random_uuid(); v_mo text;
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);
  IF p_idempotency_key IS NULL OR length(btrim(p_idempotency_key)) < 8 OR length(p_idempotency_key) > 120 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Thiếu mã chống trùng');
  END IF;
  IF p_so_tien IS NULL OR p_so_tien <> trunc(p_so_tien) OR p_so_tien < 1000 OR p_so_tien > 100000000 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_AMOUNT', 'message', 'Tiền cọc là số nguyên từ 1.000đ đến 100.000.000đ');
  END IF;
  IF p_quy IS NULL OR p_quy NOT IN ('cash', 'bank') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_FUND', 'message', 'Nhận cọc bằng Tiền mặt hoặc Chuyển khoản');
  END IF;

  SELECT * INTO v_d FROM public.ban_dat_truoc WHERE id = p_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy lượt đặt');
  END IF;
  -- gửi lại cùng mã: trả kết quả cũ
  IF v_d.coc_khoa = p_idempotency_key THEN
    IF v_d.tien_coc <> p_so_tien OR v_d.coc_quy IS DISTINCT FROM p_quy THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'IDEMPOTENCY_CONFLICT', 'message', 'Mã chống trùng đã dùng cho lần nhận cọc khác');
    END IF;
    RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('is_replay', true, 'tien_coc', v_d.tien_coc));
  END IF;
  IF v_d.trang_thai NOT IN ('da_dat', 'da_nhan') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Lượt đặt đã huỷ hoặc khách không đến');
  END IF;
  IF v_d.customer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'CAN_KHACH_HANG', 'message', 'Chọn khách hàng cho lượt đặt trước khi nhận cọc');
  END IF;
  IF COALESCE(v_d.coc_trang_thai, '') <> '' OR EXISTS (
       SELECT 1 FROM public.ban_dat_truoc x
       WHERE v_d.chuoi_id IS NOT NULL AND x.store_id = p_store_id AND x.chuoi_id = v_d.chuoi_id AND x.coc_trang_thai = 'da_thu') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Lượt đặt (hoặc lịch cố định này) đã có cọc');
  END IF;

  SELECT id, name, COALESCE(real_balance, 0) AS real_balance, COALESCE(bonus_balance, 0) AS bonus_balance
    INTO v_k FROM public.customers
   WHERE id = v_d.customer_id AND store_id = p_store_id AND COALESCE(is_deleted, false) = false FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'CUSTOMER_NOT_FOUND', 'message', 'Không tìm thấy khách hàng trong quán');
  END IF;
  SELECT COALESCE(NULLIF(trim(label), ''), name) INTO v_ban FROM public.ban_dining_tables WHERE id = v_d.table_id;
  v_mo := COALESCE(v_ban, 'bàn') || ' · ' || to_char(v_d.gio_tu AT TIME ZONE TZ, 'DD/MM HH24:MI')
          || CASE WHEN v_d.chuoi_id IS NOT NULL THEN ' (lịch cố định)' ELSE '' END;
  v_moi := v_k.real_balance + p_so_tien;

  UPDATE public.customers SET real_balance = v_moi, updated_at = now() WHERE id = v_k.id;
  INSERT INTO public.balance_transactions (id, store_id, customer_id, type, amount, balance_after, bonus_after, note, created_at)
  VALUES (gen_random_uuid(), p_store_id, v_k.id, 'topup_real', p_so_tien, v_moi, v_k.bonus_balance, 'Cọc đặt ' || v_mo, now());
  INSERT INTO public.finance_records (id, store_id, type, amount, description, reference_id, is_auto, recorded_at, fund_type)
  VALUES (v_fin, p_store_id, 'income', p_so_tien,
          'Cọc đặt sân: ' || COALESCE(NULLIF(btrim(v_k.name), ''), 'Khách hàng') || ' · ' || v_mo,
          v_d.id, true, now(), p_quy);
  UPDATE public.ban_dat_truoc
     SET tien_coc = p_so_tien, coc_trang_thai = 'da_thu', coc_quy = p_quy, coc_finance_id = v_fin,
         coc_khoa = p_idempotency_key, updated_at = now()
   WHERE id = v_d.id;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'is_replay', false, 'tien_coc', p_so_tien, 'so_du_vi', v_moi, 'finance_id', v_fin));
END
$f$;

-- ── Xử lý cọc khi huỷ / khách không đến ──────────────────────────────────────────────────────
-- p_cach: 'trong_vi' (để trong ví khách, dùng lần sau) | 'quan_giu' (trừ ví, Thu Chi giữ nguyên vì đã thu)
--         | 'hoan' (trừ ví + phiếu chi "Hoàn cọc" quỹ p_quy; chỉ Chủ quán / Quản lý)
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

-- "60.000" (dấu chấm hàng nghìn) cho chữ trong lịch sử ví / Thu Chi; không phụ thuộc migration khung giá.
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_tien_chu_v0(p_tien numeric)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'pg_catalog' AS $f$
  SELECT replace(to_char(round(GREATEST(COALESCE(p_tien, 0), 0)), 'FM999,999,999,990'), ',', '.')
$f$;

-- ── Thanh toán bàn v6: nguyên v5 + trả phần cọc / ví bằng ví khách ───────────────────────────
-- p_tra_vi: thu ngân chọn trả THÊM bằng ví (ngoài cọc). Phần ví = min(tổng, cọc + p_tra_vi, số dư ví thật).
-- Phiên có cọc: khách của hoá đơn = khách của lượt đặt (chọn khách khác thì báo lỗi, tránh trừ nhầm ví).
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
REVOKE ALL ON FUNCTION public.settle_ban_session_v6(uuid, uuid, text, text, uuid, integer, numeric, text, numeric, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.settle_ban_session_v6(uuid, uuid, text, text, uuid, integer, numeric, text, numeric, numeric) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION public.ban_dat_truoc_gan_khach_v1(uuid, uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ban_dat_truoc_nhan_coc_v1(uuid, uuid, numeric, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ban_dat_truoc_xu_ly_coc_v1(uuid, uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ban_dat_truoc_gan_khach_v1(uuid, uuid, uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ban_dat_truoc_nhan_coc_v1(uuid, uuid, numeric, text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ban_dat_truoc_xu_ly_coc_v1(uuid, uuid, text, text) TO anon, authenticated, service_role;

-- ── settle_ban_session_v5: nguyên văn production 28/11 + đoạn chặn máy cũ khi phiên có cọc ─────────
CREATE OR REPLACE FUNCTION public.settle_ban_session_v5(p_session_id uuid, p_store_id uuid, p_payment_method text DEFAULT 'cash'::text, p_idempotency_key text DEFAULT NULL::text, p_customer_id uuid DEFAULT NULL::uuid, p_points_used integer DEFAULT 0, p_discount numeric DEFAULT 0, p_coupon_code text DEFAULT NULL::text, p_surcharge numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp'
AS $function$
DECLARE
  v_staff record;
  v_session record;
  v_table record;
  v_settlement_id uuid;
  v_existing_settle record;
  v_request_fingerprint text;
  v_raw_subtotal numeric := 0;
  v_actual_points_used integer := 0;
  v_points_discount numeric := 0;
  v_redeem_rate_str text;
  v_redeem_rate numeric := 1000;
  v_coupon_id uuid;
  v_coupon_active boolean;
  v_coupon_start timestamptz;
  v_coupon_end timestamptz;
  v_coupon_type text;
  v_coupon_val numeric;
  v_coupon_min_order numeric;
  v_coupon_max_disc numeric;
  v_coupon_discount numeric := 0;
  v_discount numeric := 0;
  v_surcharge numeric := 0;
  v_final_total numeric := 0;
  v_fund_type text;
  v_order record;
  v_item record;
  v_prod record;
  v_mod jsonb;
  v_manual_order_id uuid;
  v_manual_order_num text;
  v_manual_subtotal numeric := 0;
  v_manual_item_row record;
  v_order_item_id uuid;
  v_rec_ing record;
  v_actual_ing_qty numeric;
  v_has_recipe boolean;
  v_staff_member_id uuid;
  v_user_name text;
  v_user_phone text;
  v_canonical_order_ids jsonb;
  v_order_numbers jsonb;
  v_loyalty_rate_str text;
  v_loyalty_rate numeric := 10000;
  v_pts_earned numeric := 0;
  v_customer record;
  v_current_pts numeric := 0;
  v_current_spent numeric := 0;
  v_current_visit integer := 0;
  v_current_stamps integer := 0;
  v_stamp_threshold_str text;
  v_stamp_threshold integer := 10;
  v_next_stamps integer;
  v_new_stamp_count integer;
  v_remaining_subtotal numeric;
  v_remaining_discount numeric;
  v_remaining_surcharge numeric;
  v_remaining_earned numeric;
  v_remaining_used numeric;
  v_order_waiter_id text;
  v_order_staff_id uuid;
  v_order_subtotal numeric;
  v_order_discount numeric;
  v_order_surcharge numeric;
  v_order_earned numeric;
  v_order_used numeric;
BEGIN
  -- 1. Xác thực quyền pos.checkout (100% Fail-Closed)
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);

  -- 2. Validate payload cơ bản & Whitelist Payment Method
  IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_PAYLOAD',
      'message', 'Idempotency key là bắt buộc khi quyết toán bàn'
    );
  END IF;

  p_payment_method := lower(trim(COALESCE(p_payment_method, 'cash')));
  IF p_payment_method NOT IN ('cash', 'transfer', 'card', 'bank') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_PAYMENT_METHOD',
      'message', 'Phương thức thanh toán không hợp lệ (' || p_payment_method || ')'
    );
  END IF;

  -- 20261128 (tiền cọc, đợt 4): bàn có cọc trong ví khách chỉ thanh toán qua settle_ban_session_v6 (app mới tự trừ
  -- cọc); máy chưa cập nhật gọi thẳng v5 thì chặn, tránh thu thừa tiền khách.
  IF COALESCE(current_setting('qn.settle_v6', true), '') <> '1'
     AND EXISTS (SELECT 1 FROM public.qn_coc_cua_phien_v1(p_store_id, p_session_id)) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'COC_CAN_CAP_NHAT_APP',
      'message', 'Bàn này có tiền cọc trong ví khách. Cập nhật app để thanh toán (app mới tự trừ cọc).');
  END IF;

  -- 3. Khóa Transaction-Scoped Advisory Lock trên Idempotency Key
  PERFORM pg_advisory_xact_lock(hashtext(p_store_id::text), hashtext('settle_ban_session:' || p_idempotency_key));

  -- 4. Khóa phiên bàn FOR UPDATE
  SELECT * INTO v_session
  FROM public.ban_sessions
  WHERE id = p_session_id AND store_id = p_store_id
  FOR UPDATE;

  IF v_session IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy phiên bàn');
  END IF;

  SELECT * INTO v_table
  FROM public.ban_dining_tables
  WHERE id = v_session.table_id::text AND store_id = p_store_id;

  -- 5. Băm Financial Intent Fingerprint SHA-256
  v_request_fingerprint := encode(digest(
    p_store_id::text || ':' ||
    p_session_id::text || ':' ||
    p_payment_method || ':' ||
    COALESCE(p_customer_id::text, '') || ':' ||
    COALESCE(p_points_used, 0)::text || ':' ||
    lower(trim(COALESCE(p_coupon_code, ''))) || ':' ||
    round(COALESCE(p_surcharge, 0), 0)::text || ':' ||
    round(COALESCE(p_discount, 0), 0)::text,
    'sha256'
  ), 'hex');

  -- 6. Lookup Idempotency Key (Ưu tiên trả Replay trước)
  SELECT * INTO v_existing_settle
  FROM public.payment_settlements
  WHERE store_id = p_store_id AND idempotency_key = p_idempotency_key
  LIMIT 1;

  IF v_existing_settle.id IS NOT NULL THEN
    IF v_existing_settle.session_id = p_session_id AND v_existing_settle.request_fingerprint = v_request_fingerprint THEN
      SELECT COALESCE(jsonb_agg(order_id), '[]'::jsonb) INTO v_canonical_order_ids
      FROM public.ban_session_orders
      WHERE session_id = p_session_id;

      SELECT COALESCE(jsonb_agg(o.order_number), '[]'::jsonb) INTO v_order_numbers
      FROM public.orders o
      JOIN public.ban_session_orders bso ON bso.order_id = o.id
      WHERE bso.session_id = p_session_id;

      RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
          'session_id', p_session_id,
          'settlement_id', v_existing_settle.id,
          'canonical_order_ids', v_canonical_order_ids,
          'order_numbers', v_order_numbers,
          'subtotal', v_existing_settle.subtotal,
          'discount', v_existing_settle.discount,
          'points_discount', v_existing_settle.points_discount,
          'coupon_discount', v_existing_settle.coupon_discount,
          'surcharge', v_existing_settle.surcharge,
          'total_amount', v_existing_settle.total_amount,
          'payment_method', v_existing_settle.payment_method,
          'customer_id', v_existing_settle.customer_id,
          'is_replay', true
        )
      );
    ELSE
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'IDEMPOTENCY_CONFLICT',
        'message', 'Idempotency key đã được sử dụng với nội dung thanh toán khác'
      );
    END IF;
  END IF;

  -- 7. Lookup Session Settlement (Phiên đã quyết toán trước đó)
  SELECT * INTO v_existing_settle
  FROM public.payment_settlements
  WHERE session_id = p_session_id
  LIMIT 1;

  IF v_existing_settle.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'SESSION_ALREADY_SETTLED',
      'message', 'Phiên bàn này đã được quyết toán trước đó'
    );
  END IF;

  -- 8. Kiểm tra trạng thái Session phải là 'open'
  IF v_session.status <> 'open' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'SESSION_NOT_OPEN',
      'message', 'Phiên bàn không ở trạng thái mở để thanh toán'
    );
  END IF;

  -- 9. Đọc Subtotal Authoritative từ ban_session_items
  SELECT COALESCE(SUM(subtotal), 0) INTO v_raw_subtotal
  FROM public.ban_session_items
  WHERE session_id = p_session_id AND store_id = p_store_id
    AND COALESCE(kitchen_status, '') <> 'huy';

  IF v_raw_subtotal <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_SESSION_ITEMS',
      'message', 'Phiên bàn không có món ăn để thanh toán'
    );
  END IF;

  -- 10. Xác thực Khách Hàng & Điểm Tích Lũy
  IF p_points_used IS NOT NULL AND p_points_used < 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_POINTS',
      'message', 'Số điểm sử dụng không hợp lệ (không thể là số âm)'
    );
  END IF;

  IF p_points_used IS NOT NULL AND p_points_used > 0 AND p_customer_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'CUSTOMER_REQUIRED',
      'message', 'Vui lòng chọn thông tin khách hàng để sử dụng điểm'
    );
  END IF;

  v_actual_points_used := 0;
  v_points_discount := 0;

  IF p_customer_id IS NOT NULL THEN
    SELECT * INTO v_customer
    FROM public.customers
    WHERE id = p_customer_id AND store_id = p_store_id AND is_deleted = false
    FOR UPDATE;

    IF v_customer IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'CUSTOMER_NOT_FOUND',
        'message', 'Khách hàng không tồn tại hoặc không thuộc cửa hàng này'
      );
    END IF;

    IF p_points_used IS NOT NULL AND p_points_used > 0 THEN
      IF p_points_used > COALESCE(v_customer.loyalty_pts, 0) THEN
        RETURN jsonb_build_object(
          'success', false,
          'error_code', 'INSUFFICIENT_POINTS',
          'message', 'Số điểm yêu cầu (' || p_points_used || ') vượt quá số dư điểm của khách (' || COALESCE(v_customer.loyalty_pts, 0) || ')'
        );
      END IF;

      SELECT value INTO v_redeem_rate_str
      FROM public.app_settings
      WHERE store_id = p_store_id AND key = 'loyalty_redeem_rate'
      LIMIT 1;

      IF v_redeem_rate_str IS NULL OR trim(v_redeem_rate_str) = '' THEN
        RETURN jsonb_build_object(
          'success', false,
          'error_code', 'INVALID_LOYALTY_CONFIG',
          'message', 'Chưa cấu hình tỷ lệ quy đổi điểm loyalty_redeem_rate trong app_settings'
        );
      END IF;

      BEGIN
        v_redeem_rate := v_redeem_rate_str::numeric;
      EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object(
          'success', false,
          'error_code', 'INVALID_LOYALTY_CONFIG',
          'message', 'Cấu hình loyalty_redeem_rate không phải là số hợp lệ'
        );
      END;

      IF v_redeem_rate <= 0 THEN
        RETURN jsonb_build_object(
          'success', false,
          'error_code', 'INVALID_LOYALTY_CONFIG',
          'message', 'Tỷ lệ quy đổi điểm loyalty_redeem_rate phải lớn hơn 0'
        );
      END IF;

      v_actual_points_used := p_points_used;
      v_points_discount := v_actual_points_used * v_redeem_rate;
    END IF;
  END IF;

  -- 11. Xác thực Mã Giảm Giá / Coupon
  v_coupon_discount := 0;
  IF p_coupon_code IS NOT NULL AND trim(p_coupon_code) <> '' THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'coupons'
    ) THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_SCHEMA_UNAVAILABLE',
        'message', 'Hệ thống voucher/coupon chưa được khởi tạo'
      );
    END IF;

    EXECUTE '
      SELECT id, is_active, start_date, end_date, discount_type, value, min_order_amount, max_discount_amount
      FROM public.coupons
      WHERE store_id = $1 AND upper(trim(code)) = upper(trim($2))
      LIMIT 1
    ' INTO v_coupon_id, v_coupon_active, v_coupon_start, v_coupon_end, v_coupon_type, v_coupon_val, v_coupon_min_order, v_coupon_max_disc
    USING p_store_id, p_coupon_code;

    IF v_coupon_id IS NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_NOT_FOUND',
        'message', 'Mã giảm giá không tồn tại'
      );
    END IF;

    IF v_coupon_active IS NOT TRUE THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_DISABLED',
        'message', 'Mã giảm giá hiện đang bị vô hiệu hóa'
      );
    END IF;

    IF v_coupon_start IS NOT NULL AND now() < v_coupon_start THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_NOT_STARTED',
        'message', 'Mã giảm giá chưa đến thời gian áp dụng'
      );
    END IF;

    IF v_coupon_end IS NOT NULL AND now() > v_coupon_end THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_EXPIRED',
        'message', 'Mã giảm giá đã hết hạn sử dụng'
      );
    END IF;

    IF v_coupon_min_order IS NOT NULL AND v_raw_subtotal < v_coupon_min_order THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'COUPON_MIN_ORDER_NOT_MET',
        'message', 'Đơn hàng chưa đạt giá trị tối thiểu ' || v_coupon_min_order::text || 'đ để áp dụng voucher'
      );
    END IF;

    IF v_coupon_type = 'percent' THEN
      v_coupon_discount := (v_raw_subtotal * COALESCE(v_coupon_val, 0)) / 100.0;
      IF v_coupon_max_disc IS NOT NULL AND v_coupon_max_disc > 0 THEN
        v_coupon_discount := LEAST(v_coupon_discount, v_coupon_max_disc);
      END IF;
    ELSIF v_coupon_type = 'fixed' THEN
      v_coupon_discount := LEAST(v_raw_subtotal, COALESCE(v_coupon_val, 0));
    ELSE
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'INVALID_COUPON_TYPE',
        'message', 'Loại giảm giá không được hỗ trợ'
      );
    END IF;
  END IF;

  -- 12. Validate Phụ Phí
  IF p_surcharge IS NOT NULL THEN
    IF p_surcharge < 0 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error_code', 'INVALID_SURCHARGE',
        'message', 'Phụ phí không thể là số âm'
      );
    END IF;
    v_surcharge := p_surcharge;
  ELSE
    v_surcharge := 0;
  END IF;

  -- 13. Tính Tổng Giảm Giá & Tổng Thanh Toán Authoritative
  v_discount := LEAST(v_raw_subtotal, v_coupon_discount + v_points_discount);
  v_final_total := GREATEST(0, (v_raw_subtotal - v_discount + v_surcharge));

  -- 14. Đối Chiếu Expected Quote Từ Client
  IF p_discount IS NOT NULL AND round(p_discount, 0) <> round(v_discount, 0) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'FINANCIAL_QUOTE_CHANGED',
      'message', 'Số tiền giảm giá trên hóa đơn đã thay đổi. Vui lòng xác nhận lại số tiền trước khi thanh toán.',
      'data', jsonb_build_object(
        'authoritative_subtotal', v_raw_subtotal,
        'authoritative_discount', v_discount,
        'authoritative_points_discount', v_points_discount,
        'authoritative_coupon_discount', v_coupon_discount,
        'authoritative_surcharge', v_surcharge,
        'authoritative_total', v_final_total
      )
    );
  END IF;

  -- 15. COMMIT ATOMIC TRONG 1 TRANSACTION DUY NHẤT
  -- 15.1. Staff Upsert
  v_staff_member_id := v_staff.store_member_id;
  SELECT display_name, phone INTO v_user_name, v_user_phone
  FROM public.user_accounts WHERE id = v_staff.member_user_id;

  INSERT INTO public.staff_members (
    id, store_id, name, role, phone, is_active, updated_at
  ) VALUES (
    v_staff_member_id, p_store_id, COALESCE(v_user_name, 'Staff'), COALESCE(v_staff.member_role, 'cashier'),
    v_user_phone, true, extract(epoch from now()) * 1000
  )
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    role = EXCLUDED.role,
    is_active = true,
    updated_at = EXCLUDED.updated_at;

  -- 15.2. Gom món manual thành canonical order với số QN-YYYYMMDD-XXX nguyên tử
  SELECT COALESCE(SUM(subtotal), 0) INTO v_manual_subtotal
  FROM public.ban_session_items bsi
  WHERE bsi.session_id = p_session_id
    AND bsi.store_id = p_store_id AND COALESCE(bsi.kitchen_status, '') <> 'huy'
    AND NOT EXISTS (
      SELECT 1 FROM public.ban_session_order_items bsoi
      WHERE bsoi.session_item_id = bsi.id
    );

  IF v_manual_subtotal > 0 THEN
    v_manual_order_id := gen_random_uuid();
    v_manual_order_num := public.generate_daily_order_number_v1(p_store_id, 'QN');

    v_order_waiter_id := NULL;
    IF v_session.waiter_id IS NOT NULL THEN
      SELECT id::text INTO v_order_waiter_id FROM public.staff_members WHERE id::text = v_session.waiter_id;
      IF v_order_waiter_id IS NULL THEN
        v_order_waiter_id := v_session.waiter_id;
      END IF;
    END IF;

    v_order_staff_id := NULL;
    IF v_staff_member_id IS NOT NULL THEN
      SELECT id INTO v_order_staff_id FROM public.staff_members WHERE id = v_staff_member_id;
    END IF;

    INSERT INTO public.orders (
      id, store_id, order_number, subtotal, discount, tax, total, total_amount,
      payment_method, status, source_type, source_id, staff_id, waiter_id, receipt_printed, created_at, note
    ) VALUES (
      v_manual_order_id, p_store_id, v_manual_order_num, v_manual_subtotal, 0, 0, v_manual_subtotal, v_manual_subtotal,
      p_payment_method, 'completed', 'ban', v_session.table_id::text, v_order_staff_id, v_order_waiter_id, false, now(),
      'Món thanh toán tại bàn ' || COALESCE(v_table.name, v_table.label, 'bàn')
    );

    INSERT INTO public.ban_session_orders (
      id, store_id, session_id, order_id, qr_request_id, created_at
    ) VALUES (
      gen_random_uuid(), p_store_id, p_session_id, v_manual_order_id, NULL, now()
    );

    FOR v_manual_item_row IN (
      SELECT bsi.* FROM public.ban_session_items bsi
      WHERE bsi.session_id = p_session_id
        AND bsi.store_id = p_store_id AND COALESCE(bsi.kitchen_status, '') <> 'huy'
        AND NOT EXISTS (
          SELECT 1 FROM public.ban_session_order_items bsoi
          WHERE bsoi.session_item_id = bsi.id
        )
    )
    LOOP
      SELECT cost_price_latest INTO v_prod FROM public.products WHERE id = v_manual_item_row.product_id;
      v_order_item_id := gen_random_uuid();

      INSERT INTO public.order_items (
        id, store_id, order_id, product_id, name, product_name, qty, quantity,
        unit_price, cost_price, subtotal, modifiers_json
      ) VALUES (
        v_order_item_id, p_store_id, v_manual_order_id, v_manual_item_row.product_id,
        v_manual_item_row.product_name, v_manual_item_row.product_name,
        v_manual_item_row.quantity, v_manual_item_row.quantity,
        v_manual_item_row.unit_price, COALESCE(v_prod.cost_price_latest, 0),
        v_manual_item_row.subtotal,
        CASE WHEN v_manual_item_row.modifiers_json IS NOT NULL AND trim(v_manual_item_row.modifiers_json) <> ''
             THEN v_manual_item_row.modifiers_json::jsonb ELSE '[]'::jsonb END
      );

      INSERT INTO public.ban_session_order_items (
        id, store_id, session_id, session_item_id, order_id, order_item_id, source_type, created_at
      ) VALUES (
        gen_random_uuid(), p_store_id, p_session_id, v_manual_item_row.id, v_manual_order_id, v_order_item_id, 'ban_manual', now()
      );
    END LOOP;
  END IF;

  -- 15.3. Tính điểm tích lũy
  SELECT value INTO v_loyalty_rate_str
  FROM public.app_settings
  WHERE store_id = p_store_id AND key = 'loyalty_rate'
  LIMIT 1;

  IF v_loyalty_rate_str IS NOT NULL AND trim(v_loyalty_rate_str) <> '' THEN
    BEGIN
      v_loyalty_rate := COALESCE(v_loyalty_rate_str::numeric, 10000);
      IF v_loyalty_rate <= 0 THEN v_loyalty_rate := 10000; END IF;
    EXCEPTION WHEN OTHERS THEN
      v_loyalty_rate := 10000;
    END;
  END IF;

  IF p_customer_id IS NOT NULL THEN
    v_pts_earned := FLOOR(v_final_total / v_loyalty_rate);
  END IF;

  v_settlement_id := gen_random_uuid();
  v_fund_type := CASE WHEN p_payment_method IN ('transfer', 'card', 'bank') THEN 'bank' ELSE 'cash' END;

  -- 15.4. Ghi Payment Settlement
  INSERT INTO public.payment_settlements (
    id, store_id, session_id, idempotency_key, request_fingerprint, subtotal, discount,
    points_discount, coupon_discount, surcharge, total_amount, payment_method, customer_id,
    points_used, coupon_code, cashier_staff_id, status, created_at
  ) VALUES (
    v_settlement_id, p_store_id, p_session_id, p_idempotency_key, v_request_fingerprint, v_raw_subtotal, v_discount,
    v_points_discount, v_coupon_discount, v_surcharge, v_final_total, p_payment_method, p_customer_id,
    v_actual_points_used, p_coupon_code, v_staff_member_id, 'completed', now()
  );

  -- 15.5. Ghi Coupon Redemption nếu có
  IF v_coupon_discount > 0 AND p_coupon_code IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'qr_coupon_redemptions') THEN
      INSERT INTO public.qr_coupon_redemptions (
        id, store_id, session_id, settlement_id, coupon_id, coupon_code, discount_amount, created_at
      ) VALUES (
        gen_random_uuid(), p_store_id, p_session_id, v_settlement_id, v_coupon_id, p_coupon_code, v_coupon_discount, now()
      );
    END IF;
  END IF;

  -- 15.6. Chuyển toàn bộ Canonical Orders sang Completed & Trừ kho (Đa đơn vị F&B)
  UPDATE public.order_items oi
  SET qty = CASE WHEN COALESCE(bsi.kitchen_status, '') = 'huy' THEN 0 ELSE bsi.quantity END,
      quantity = CASE WHEN COALESCE(bsi.kitchen_status, '') = 'huy' THEN 0 ELSE bsi.quantity END,
      unit_price = bsi.unit_price,
      subtotal = CASE WHEN COALESCE(bsi.kitchen_status, '') = 'huy' THEN 0 ELSE bsi.subtotal END
  FROM public.ban_session_order_items link JOIN public.ban_session_items bsi ON bsi.id = link.session_item_id
  WHERE oi.id = link.order_item_id AND oi.store_id = p_store_id
    AND link.session_id = p_session_id AND link.store_id = p_store_id AND bsi.store_id = p_store_id;

  v_remaining_subtotal := v_raw_subtotal;
  v_remaining_discount := v_discount;
  v_remaining_surcharge := v_surcharge;
  v_remaining_earned := v_pts_earned;
  v_remaining_used := v_actual_points_used;

  FOR v_order IN (
    SELECT o.* FROM public.orders o
    JOIN public.ban_session_orders bso ON bso.order_id = o.id
    WHERE bso.session_id = p_session_id
      AND bso.store_id = p_store_id AND o.store_id = p_store_id ORDER BY o.id
  )
  LOOP
    SELECT COALESCE(sum(subtotal), 0) INTO v_order_subtotal FROM public.order_items
    WHERE order_id = v_order.id AND store_id = p_store_id;
    IF v_order_subtotal = v_remaining_subtotal THEN
      v_order_discount := v_remaining_discount; v_order_surcharge := v_remaining_surcharge;
      v_order_earned := v_remaining_earned; v_order_used := v_remaining_used;
    ELSE
      v_order_discount := round(v_remaining_discount * v_order_subtotal / NULLIF(v_remaining_subtotal, 0));
      v_order_surcharge := round(v_remaining_surcharge * v_order_subtotal / NULLIF(v_remaining_subtotal, 0));
      v_order_earned := floor(v_remaining_earned * v_order_subtotal / NULLIF(v_remaining_subtotal, 0));
      v_order_used := floor(v_remaining_used * v_order_subtotal / NULLIF(v_remaining_subtotal, 0));
    END IF;
    v_remaining_subtotal := v_remaining_subtotal - v_order_subtotal;
    v_remaining_discount := v_remaining_discount - v_order_discount;
    v_remaining_surcharge := v_remaining_surcharge - v_order_surcharge;
    v_remaining_earned := v_remaining_earned - v_order_earned;
    v_remaining_used := v_remaining_used - v_order_used;

    UPDATE public.orders
    SET status = 'completed',
        subtotal = v_order_subtotal, discount = v_order_discount, tax = v_order_surcharge,
        total = v_order_subtotal - v_order_discount + v_order_surcharge,
        total_amount = v_order_subtotal - v_order_discount + v_order_surcharge,
        payment_method = p_payment_method,
        customer_id = COALESCE(p_customer_id, customer_id),
        staff_id = COALESCE(
          (SELECT id FROM public.staff_members WHERE id = v_staff_member_id),
          staff_id
        ),
        loyalty_pts_earned = v_order_earned,
        loyalty_pts_used = v_order_used
    WHERE id = v_order.id;

    -- Trừ kho sản phẩm & công thức món chính
    FOR v_item IN
      SELECT oi.id, oi.product_id, bsi.product_name, bsi.quantity,
        CASE
          WHEN oi.modifiers_json IS NULL OR btrim(oi.modifiers_json::text) = ''
            THEN '[]'::jsonb
          ELSE oi.modifiers_json::jsonb
        END AS modifiers_json
      FROM public.order_items oi
      JOIN public.ban_session_order_items link ON link.order_item_id = oi.id
      JOIN public.ban_session_items bsi ON bsi.id = link.session_item_id
      WHERE oi.order_id = v_order.id AND oi.store_id = p_store_id
        AND link.session_id = p_session_id AND link.store_id = p_store_id
        AND bsi.store_id = p_store_id AND COALESCE(bsi.kitchen_status, '') <> 'huy'
    LOOP
      v_has_recipe := false;
      IF EXISTS (
        SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'recipes'
      ) AND EXISTS (
        SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'recipe_ingredients'
      ) THEN
        EXECUTE '
          SELECT EXISTS (
            SELECT 1 FROM public.recipes r
            JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
            WHERE r.pos_product_id::text = $1::text AND r.is_deleted = false
          )
        ' INTO v_has_recipe USING v_item.product_id;
      END IF;

      IF v_has_recipe THEN
        FOR v_rec_ing IN EXECUTE '
          SELECT ri.ingredient_id, ri.quantity, ri.yield_factor, ri.unit AS recipe_unit,
                 p.unit AS prod_unit, COALESCE(p.conversion_rate, 0) AS conversion_rate,
                 COALESCE(p.conversion_unit, '''') AS conversion_unit, p.name AS prod_name
          FROM public.recipes r
          JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
          LEFT JOIN public.products p ON p.id::text = ri.ingredient_id::text AND p.store_id = $2
          WHERE r.pos_product_id::text = $1::text AND r.is_deleted = false AND ri.ingredient_id IS NOT NULL
        ' USING v_item.product_id, p_store_id
        LOOP
          -- Quy đổi định lượng nguyên liệu F&B đa đơn vị
          v_actual_ing_qty := public.convert_recipe_ingredient_qty_v1(
            (v_rec_ing.quantity / CASE WHEN v_rec_ing.yield_factor IS NULL OR v_rec_ing.yield_factor <= 0 THEN 1.0 ELSE v_rec_ing.yield_factor END) * v_item.quantity,
            v_rec_ing.recipe_unit,
            v_rec_ing.prod_unit,
            v_rec_ing.conversion_rate,
            v_rec_ing.conversion_unit
          );

          INSERT INTO public.stock_movements (
            id, store_id, product_id, delta, reason, reference_id, note, created_at
          ) VALUES (
            gen_random_uuid(), p_store_id, v_rec_ing.ingredient_id::uuid, -v_actual_ing_qty,
            'recipe_usage', v_settlement_id, 'Xuất kho công thức bàn ' || COALESCE(v_table.label, v_table.name, 'bàn') || ': ' || v_item.product_name, now()
          );

          UPDATE public.products
          SET stock_qty = COALESCE(stock_qty, 0) - v_actual_ing_qty,
              updated_at = extract(epoch from now()) * 1000
          WHERE id = v_rec_ing.ingredient_id::uuid AND store_id = p_store_id;
        END LOOP;
      ELSE
        INSERT INTO public.stock_movements (
          id, store_id, product_id, delta, reason, reference_id, note, created_at
        ) VALUES (
          gen_random_uuid(), p_store_id, v_item.product_id, -v_item.quantity,
          'sale', v_settlement_id, 'Bán hàng bàn ' || COALESCE(v_table.label, v_table.name, 'bàn'), now()
        );

        UPDATE public.products
        SET stock_qty = COALESCE(stock_qty, 0) - v_item.quantity,
            updated_at = extract(epoch from now()) * 1000
        WHERE id = v_item.product_id AND store_id = p_store_id;
      END IF;

      -- Trừ kho toppings / modifiers nếu có (Tích hợp quy đổi đa đơn vị F&B)
      IF v_item.modifiers_json IS NOT NULL AND jsonb_typeof(v_item.modifiers_json) = 'array' THEN
        FOR v_mod IN SELECT * FROM jsonb_array_elements(v_item.modifiers_json)
        LOOP
          IF (v_mod->>'id') IS NOT NULL AND EXISTS (SELECT 1 FROM public.products WHERE store_id = p_store_id AND id::text = (v_mod->>'id')) THEN
            v_has_recipe := false;
            IF EXISTS (
              SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'recipes'
            ) AND EXISTS (
              SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'recipe_ingredients'
            ) THEN
              EXECUTE '
                SELECT EXISTS (
                  SELECT 1 FROM public.recipes r
                  JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
                  WHERE r.pos_product_id::text = $1::text AND r.is_deleted = false
                )
              ' INTO v_has_recipe USING (v_mod->>'id')::uuid;
            END IF;

            IF v_has_recipe THEN
              FOR v_rec_ing IN EXECUTE '
                SELECT ri.ingredient_id, ri.quantity, ri.yield_factor, ri.unit AS recipe_unit,
                       p.unit AS prod_unit, COALESCE(p.conversion_rate, 0) AS conversion_rate,
                       COALESCE(p.conversion_unit, '''') AS conversion_unit, p.name AS prod_name
                FROM public.recipes r
                JOIN public.recipe_ingredients ri ON ri.recipe_id = r.id
                LEFT JOIN public.products p ON p.id::text = ri.ingredient_id::text AND p.store_id = $2
                WHERE r.pos_product_id::text = $1::text AND r.is_deleted = false AND ri.ingredient_id IS NOT NULL
              ' USING (v_mod->>'id')::uuid, p_store_id
              LOOP
                v_actual_ing_qty := public.convert_recipe_ingredient_qty_v1(
                  (v_rec_ing.quantity / CASE WHEN v_rec_ing.yield_factor IS NULL OR v_rec_ing.yield_factor <= 0 THEN 1.0 ELSE v_rec_ing.yield_factor END) * (COALESCE((jsonb_path_query_first(v_mod, '$.qty.double()', '{}', true))::numeric, COALESCE((jsonb_path_query_first(v_mod, '$.quantity.double()', '{}', true))::numeric, 1) * v_item.quantity)),
                  v_rec_ing.recipe_unit,
                  v_rec_ing.prod_unit,
                  v_rec_ing.conversion_rate,
                  v_rec_ing.conversion_unit
                );

                INSERT INTO public.stock_movements (
                  id, store_id, product_id, delta, reason, reference_id, note, created_at
                ) VALUES (
                  gen_random_uuid(), p_store_id, v_rec_ing.ingredient_id::uuid, -v_actual_ing_qty,
                  'recipe_usage', v_settlement_id, 'Xuất kho topping công thức bàn ' || COALESCE(v_table.label, v_table.name, 'bàn'), now()
                );

                UPDATE public.products
                SET stock_qty = COALESCE(stock_qty, 0) - v_actual_ing_qty,
                    updated_at = extract(epoch from now()) * 1000
                WHERE id = v_rec_ing.ingredient_id::uuid AND store_id = p_store_id;
              END LOOP;
            ELSE
              INSERT INTO public.stock_movements (
                id, store_id, product_id, delta, reason, reference_id, note, created_at
              ) VALUES (
                gen_random_uuid(), p_store_id, (v_mod->>'id')::uuid,
                -(COALESCE((jsonb_path_query_first(v_mod, '$.qty.double()', '{}', true))::numeric, COALESCE((jsonb_path_query_first(v_mod, '$.quantity.double()', '{}', true))::numeric, 1) * v_item.quantity)),
                'sale', v_settlement_id, 'Bán topping bàn ' || COALESCE(v_table.label, v_table.name, 'bàn'), now()
              );

              UPDATE public.products
              SET stock_qty = COALESCE(stock_qty, 0) - (COALESCE((jsonb_path_query_first(v_mod, '$.qty.double()', '{}', true))::numeric, COALESCE((jsonb_path_query_first(v_mod, '$.quantity.double()', '{}', true))::numeric, 1) * v_item.quantity)),
                  updated_at = extract(epoch from now()) * 1000
              WHERE id = (v_mod->>'id')::uuid AND store_id = p_store_id;
            END IF;
          END IF;
        END LOOP;
      END IF;
    END LOOP;
  END LOOP;

  -- 15.7. Ghi ĐÚNG 1 bản ghi sổ quỹ finance_records với reference_id = v_settlement_id
  INSERT INTO public.finance_records (
    id, store_id, type, amount, description, reference_id, is_auto, recorded_at, fund_type
  ) VALUES (
    gen_random_uuid(), p_store_id, 'income', v_final_total,
    'Thanh toán bàn ' || COALESCE(v_table.label, v_table.name, 'bàn') || CASE WHEN p_coupon_code IS NOT NULL THEN ' [Voucher: ' || p_coupon_code || ']' ELSE '' END,
    v_settlement_id, true, now(), v_fund_type
  );

  -- 15.8. Tích điểm / Trừ điểm cho Khách hàng & Loyalty Transactions
  IF p_customer_id IS NOT NULL THEN
    v_current_pts := COALESCE(v_customer.loyalty_pts, 0);
    v_current_spent := COALESCE(v_customer.total_spent, 0);
    v_current_visit := COALESCE(v_customer.visit_count, 0);
    v_current_stamps := COALESCE(v_customer.stamp_count, 0);

    SELECT value INTO v_stamp_threshold_str
    FROM public.app_settings
    WHERE store_id = p_store_id AND key = 'stamp_threshold'
    LIMIT 1;

    IF v_stamp_threshold_str IS NOT NULL THEN
      v_stamp_threshold := COALESCE(v_stamp_threshold_str::integer, 10);
    END IF;

    v_next_stamps := v_current_stamps + 1;
    v_new_stamp_count := CASE WHEN v_next_stamps >= v_stamp_threshold THEN 0 ELSE v_next_stamps END;

    UPDATE public.customers
    SET loyalty_pts = GREATEST(0, v_current_pts + v_pts_earned - v_actual_points_used),
        total_spent = v_current_spent + v_final_total,
        visit_count = v_current_visit + 1,
        stamp_count = v_new_stamp_count,
        stamp_total = COALESCE(v_customer.stamp_total, 0) + 1,
        updated_at = now()
    WHERE id = p_customer_id;

    IF v_pts_earned > 0 OR v_actual_points_used > 0 THEN
      INSERT INTO public.loyalty_transactions (
        id, store_id, customer_id, order_id, pts_earned, pts_used, note, created_at
      ) VALUES (
        gen_random_uuid(), p_store_id, p_customer_id, v_settlement_id,
        v_pts_earned, v_actual_points_used,
        'Thanh toán bàn ' || COALESCE(v_table.label, v_table.name, 'bàn'), now()
      );
    END IF;
  END IF;

  -- 15.9. Đóng Session bàn
  UPDATE public.ban_sessions
  SET status = 'closed',
      closed_at = now(),
      total_amount = v_final_total
  WHERE id = p_session_id;

  -- 15.11. Audit log
  INSERT INTO public.qr_audit_logs (
    store_id, request_id, action, actor_user_id, details
  ) VALUES (
    p_store_id, NULL, 'settle_session_v5', v_staff.member_user_id,
    jsonb_build_object(
      'session_id', p_session_id,
      'settlement_id', v_settlement_id,
      'subtotal', v_raw_subtotal,
      'discount', v_discount,
      'points_discount', v_points_discount,
      'coupon_discount', v_coupon_discount,
      'surcharge', v_surcharge,
      'total_amount', v_final_total,
      'request_fingerprint', v_request_fingerprint,
      'idempotency_key', p_idempotency_key
    )
  );

  SELECT COALESCE(jsonb_agg(order_id), '[]'::jsonb) INTO v_canonical_order_ids
  FROM public.ban_session_orders
  WHERE session_id = p_session_id;

  SELECT COALESCE(jsonb_agg(o.order_number), '[]'::jsonb) INTO v_order_numbers
  FROM public.orders o
  JOIN public.ban_session_orders bso ON bso.order_id = o.id
  WHERE bso.session_id = p_session_id;

  RETURN jsonb_build_object(
    'success', true,
    'data', jsonb_build_object(
      'session_id', p_session_id,
      'settlement_id', v_settlement_id,
      'canonical_order_ids', v_canonical_order_ids,
      'order_numbers', v_order_numbers,
      'subtotal', v_raw_subtotal,
      'discount', v_discount,
      'points_discount', v_points_discount,
      'coupon_discount', v_coupon_discount,
      'surcharge', v_surcharge,
      'total_amount', v_final_total,
      'payment_method', p_payment_method,
      'customer_id', p_customer_id,
      'pts_earned', v_pts_earned,
      'is_replay', false
    )
  );
END;
$function$
;
