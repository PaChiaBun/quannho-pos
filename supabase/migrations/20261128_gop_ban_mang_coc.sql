-- ============================================================================
-- 20261128_gop_ban_mang_coc.sql — gộp bàn có cọc: tự mang cọc sang bàn đích (Chủ Quán chốt 28/11 "Tự mang cọc sang").
-- Áp sau 20261128_goi_gio.sql (tự kiểm). Chép nguyên ban_chuyen_ban_tinh_gio_v1 bản đợt 7, chỉ thêm đoạn ghi "28/11":
--   gộp: lượt đặt đã nhận của bàn nguồn (còn cọc chưa trừ) gắn sang phiên đích → thanh toán bàn đích trừ cọc.
--   Bàn đích đã có cọc của khách khác → không mang, trả coc_mang = false (app báo xử lý trong Lịch đặt).
-- Hoàn tác: 20261128_gop_ban_mang_coc_ROLLBACK.sql. Test: tien_coc_vi_khach_test.sql (M1–M3).
-- ============================================================================

DO $pf$
BEGIN
  IF to_regclass('public.ban_goi_gio') IS NULL OR to_regproc('public.qn_coc_cua_phien_v1') IS NULL THEN
    RAISE EXCEPTION 'PREFLIGHT gop_ban_mang_coc: chưa áp 20261128_goi_gio.sql / 20261128_tien_coc_vi_khach.sql';
  END IF;
  RAISE NOTICE 'PREFLIGHT gop_ban_mang_coc: OK';
END
$pf$;

CREATE OR REPLACE FUNCTION public.ban_chuyen_ban_tinh_gio_v1(p_session_id uuid, p_store_id uuid, p_table_dich text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp'
AS $function$
DECLARE
  v_s record; v_t record; v_dich_id uuid; v_d record; v_chot jsonb; v_kieu text; v_tong numeric;
  v_coc_nguon numeric := 0; v_kh_nguon uuid; v_coc_mang boolean;
BEGIN
  PERFORM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);

  IF p_table_dich IS NULL OR p_table_dich !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Bàn đích không hợp lệ');
  END IF;
  SELECT * INTO v_t FROM public.ban_dining_tables WHERE id = p_table_dich AND store_id = p_store_id;
  IF NOT FOUND OR COALESCE(v_t.is_active, true) = false THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy bàn đích');
  END IF;

  -- Khoá cả hai phiên theo thứ tự id (cùng thứ tự với guard_ban_item_financial_change_v5) để không khoá chéo.
  SELECT id INTO v_dich_id FROM public.ban_sessions
  WHERE store_id = p_store_id AND table_id = p_table_dich::uuid AND status = 'open';
  PERFORM 1 FROM public.ban_sessions
  WHERE store_id = p_store_id AND id IN (p_session_id, v_dich_id) ORDER BY id FOR UPDATE;

  SELECT * INTO v_s FROM public.ban_sessions WHERE id = p_session_id AND store_id = p_store_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy phiên bàn');
  END IF;
  IF v_s.status <> 'open' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'SESSION_NOT_OPEN', 'message', 'Phiên bàn không còn mở');
  END IF;
  IF v_s.table_id::text = p_table_dich THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Bàn đích trùng bàn hiện tại');
  END IF;
  SELECT * INTO v_d FROM public.ban_sessions
  WHERE store_id = p_store_id AND table_id = p_table_dich::uuid AND status = 'open';
  IF v_d.id IS DISTINCT FROM v_dich_id THEN   -- bàn đích vừa đổi trạng thái giữa lúc đọc và lúc khoá
    RETURN jsonb_build_object('success', false, 'error_code', 'RETRY', 'message', 'Bàn đích vừa thay đổi, hãy thử lại');
  END IF;

  IF v_s.gio_bat_dau IS NOT NULL THEN
    v_chot := public.qn_tinh_gio_ghi_dong_v1(p_store_id, p_session_id, false);
  END IF;

  IF v_d.id IS NULL THEN
    v_kieu := 'chuyen';
    UPDATE public.ban_sessions
       SET table_id = p_table_dich::uuid,
           gio_bat_dau = CASE WHEN v_t.gia_gio_product_id IS NOT NULL THEN clock_timestamp() END,
           -- đợt 7: đoạn bàn cũ đã chốt đủ giá gói; bàn mới nhận phần gói còn lại (giá 0), hết thì tính như thường
           goi_phut = CASE WHEN v_t.gia_gio_product_id IS NOT NULL AND COALESCE(v_s.goi_phut, 0) > 0
                             AND (v_chot->>'so_phut_choi')::int < v_s.goi_phut
                           THEN v_s.goi_phut - (v_chot->>'so_phut_choi')::int END,
           goi_gia = CASE WHEN v_t.gia_gio_product_id IS NOT NULL AND COALESCE(v_s.goi_phut, 0) > 0
                            AND (v_chot->>'so_phut_choi')::int < v_s.goi_phut
                          THEN 0 END
     WHERE id = p_session_id;
  ELSE
    v_kieu := 'gop';
    UPDATE public.ban_session_items SET session_id = v_d.id
    WHERE session_id = p_session_id AND store_id = p_store_id;
    -- 28/11 (Chủ Quán "Tự mang cọc sang"): lượt đặt đã nhận của bàn nguồn còn cọc chưa trừ → gắn sang phiên đích để
    -- thanh toán bàn đích tự trừ cọc. Bàn đích đã có cọc của KHÁCH KHÁC thì không mang (v6 trừ mọi cọc vào ví một
    -- khách → trừ nhầm); cọc đó xử lý tay trong Lịch đặt (lượt đã nhận, phiên đã đóng).
    SELECT COALESCE(sum(tien), 0), (array_agg(customer_id) FILTER (WHERE customer_id IS NOT NULL))[1]
      INTO v_coc_nguon, v_kh_nguon
    FROM public.qn_coc_cua_phien_v1(p_store_id, p_session_id);
    IF v_coc_nguon > 0 THEN
      v_coc_mang := NOT EXISTS (SELECT 1 FROM public.qn_coc_cua_phien_v1(p_store_id, v_d.id) c
                                WHERE c.customer_id IS DISTINCT FROM v_kh_nguon);
      IF v_coc_mang THEN
        UPDATE public.ban_dat_truoc SET session_id = v_d.id, updated_at = now()
         WHERE store_id = p_store_id AND session_id = p_session_id AND trang_thai = 'da_nhan';
      END IF;
    END IF;
    UPDATE public.ban_sessions
       SET status = 'closed', closed_at = now(), total_amount = 0, gio_bat_dau = NULL, goi_phut = NULL, goi_gia = NULL
     WHERE id = p_session_id;
    SELECT COALESCE(sum(subtotal), 0) INTO v_tong FROM public.ban_session_items
    WHERE session_id = v_d.id AND store_id = p_store_id AND COALESCE(kitchen_status, '') <> 'huy';
    UPDATE public.ban_sessions SET total_amount = v_tong WHERE id = v_d.id;
  END IF;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'kieu', v_kieu, 'session_id', CASE WHEN v_kieu = 'gop' THEN v_d.id ELSE p_session_id END,
    'chot', v_chot, 'coc_tien', v_coc_nguon, 'coc_mang', v_coc_mang));
END
$function$
;
