-- ============================================================================
-- BÀN TÍNH GIỜ v1 (23/11/2026) — giai đoạn 1 của .docs/ke-hoach-ban-tinh-gio.md
-- Bi da, phòng karaoke, sân: mở bàn là đồng hồ chạy, lúc tính tiền máy chủ chèn MỘT dòng tiền giờ
-- vào phiên bàn. settle_ban_session_v5 và các hàm báo cáo KHÔNG đổi: dòng tiền giờ là một dòng món
-- bình thường (gắn một món thật trong Menu, giá bán của món = giá một giờ).
--
-- Thêm 3 cột (đều để trống được, app đang chạy không bị ảnh hưởng):
--   ban_dining_tables.gia_gio_product_id  món giá giờ của bàn; trống = bàn thường
--   ban_sessions.gio_bat_dau              mốc bắt đầu đoạn đang tính; MÁY CHỦ đặt, app không sửa được
--   ban_session_items.gio_tu / gio_den    có giá trị = dòng tiền giờ (giờ vào, giờ ra)
--
-- Hai hàm app gọi:
--   ban_chot_gio_v1(phiên, quán)                 ghi / ghi đè dòng tiền giờ của đoạn đang chạy
--   ban_chuyen_ban_tinh_gio_v1(phiên, quán, bàn) chuyển bàn hoặc gộp bàn khi có tính giờ
--
-- Chốt chặn:
--   1. App không tự thêm / sửa tiền / xoá dòng tiền giờ. Huỷ dòng (đổi trạng thái 'huy') vẫn đi đường
--      duyệt sẵn có (guard_ban_item_sent_v1 → qn_ban_item_void_check_v1).
--   2. App không sửa được gio_bat_dau; không tự đổi bàn của phiên đang tính giờ hoặc sang bàn tính giờ.
--   3. Phiên đang tính giờ KHÔNG đóng được (mọi vai, kể cả hàm thanh toán) khi chưa chốt giờ, hoặc
--      chốt đã quá 15 phút. Lý do: app bản cũ thanh toán bàn mà không biết có tiền giờ.
--   4. Huỷ bàn đang tính giờ đã mở quá 5 phút: phải chốt giờ trước, khi đó dòng tiền giờ ('xong') kéo theo
--      luật duyệt huỷ bàn sẵn có (guard_ban_session_cancel_v1).
--   5. Chỉ Chủ quán / Quản lý gắn giá giờ cho bàn; món phải của đúng quán; không đổi khi bàn đang chạy giờ.
--
-- Cách tính bản đầu: theo phút (làm tròn lên, tối thiểu 1 phút), một giá cho mỗi bàn, tiền làm tròn lên 1.000đ.
-- Hoàn tác: 20261123_ban_tinh_gio_v1_ROLLBACK.sql. Test: supabase/tests/ban_tinh_gio_v1_test.sql
-- ============================================================================

DO $pf$
BEGIN
  IF (SELECT count(*) FROM information_schema.columns
      WHERE table_schema = 'public' AND (table_name, column_name) IN (
        ('ban_dining_tables', 'id'), ('ban_dining_tables', 'store_id'),
        ('ban_sessions', 'table_id'), ('ban_sessions', 'status'), ('ban_sessions', 'total_amount'),
        ('ban_session_items', 'kitchen_status'), ('ban_session_items', 'price'),
        ('ban_session_items', 'subtotal'), ('products', 'sell_price'))) <> 9 THEN
    RAISE EXCEPTION 'PREFLIGHT ban_tinh_gio_v1: thiếu cột nền';
  END IF;
  IF (SELECT count(DISTINCT proname) FROM pg_proc
      WHERE pronamespace = 'public'::regnamespace
        AND proname IN ('verify_staff_qr_membership_v4', 'qn_caller_id', 'qn_is_store_manager_v1')) <> 3 THEN
    RAISE EXCEPTION 'PREFLIGHT ban_tinh_gio_v1: thiếu hàm kiểm quyền';
  END IF;
  RAISE NOTICE 'PREFLIGHT ban_tinh_gio_v1: OK';
END
$pf$;

ALTER TABLE public.ban_dining_tables ADD COLUMN IF NOT EXISTS gia_gio_product_id uuid;
ALTER TABLE public.ban_sessions      ADD COLUMN IF NOT EXISTS gio_bat_dau timestamptz;
ALTER TABLE public.ban_session_items ADD COLUMN IF NOT EXISTS gio_tu timestamptz;
ALTER TABLE public.ban_session_items ADD COLUMN IF NOT EXISTS gio_den timestamptz;

COMMENT ON COLUMN public.ban_dining_tables.gia_gio_product_id IS 'Bàn tính giờ: món giá giờ (sell_price = giá 1 giờ). NULL = bàn thường';
COMMENT ON COLUMN public.ban_sessions.gio_bat_dau IS 'Bàn tính giờ: mốc bắt đầu đoạn đang tính, máy chủ đặt. NULL = phiên không tính giờ';
COMMENT ON COLUMN public.ban_session_items.gio_tu IS 'Khác NULL = dòng tiền giờ do máy chủ ghi; gio_tu = mốc của đoạn';

-- ── Hàm phụ cho trigger (trigger chạy bằng quyền app nên tự đọc có thể bị RLS che) ──────────────
-- Chỉ gọi được từ trong trigger, như qn_ban_item_void_check_v1.

CREATE OR REPLACE FUNCTION public.qn_tinh_gio_mon_cua_ban_v1(p_store uuid, p_table text)
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
BEGIN
  IF pg_trigger_depth() < 1 THEN RAISE EXCEPTION 'TRIGGER_ONLY'; END IF;
  RETURN (SELECT gia_gio_product_id FROM public.ban_dining_tables WHERE id = p_table AND store_id = p_store);
END
$f$;

-- 'chua' = chưa có dòng tiền giờ của đoạn đang chạy; 'cu' = chốt đã quá 15 phút; 'ok' = đóng được
-- (dòng đã bị Quản lý huỷ cũng là 'ok': quán đã quyết không thu tiền giờ).
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_trang_thai_chot_v1(p_session uuid, p_moc timestamptz)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
DECLARE v_status text; v_den timestamptz;
BEGIN
  IF pg_trigger_depth() < 1 THEN RAISE EXCEPTION 'TRIGGER_ONLY'; END IF;
  SELECT kitchen_status, gio_den INTO v_status, v_den FROM public.ban_session_items
  WHERE session_id = p_session AND gio_tu = p_moc ORDER BY added_at LIMIT 1;
  IF NOT FOUND THEN RETURN 'chua'; END IF;
  IF v_status = 'huy' THEN RETURN 'ok'; END IF;
  IF v_den IS NULL OR v_den < clock_timestamp() - interval '15 minutes' THEN RETURN 'cu'; END IF;
  RETURN 'ok';
END
$f$;

-- 'khong_quyen' = người gọi (app) không phải Chủ quán / Quản lý; 'mon_sai' = món không thuộc quán / đã xoá;
-- 'dang_chay' = bàn đang có phiên tính giờ; 'ok'.
-- Kiểm quyền nằm ở đây vì qn_is_store_manager_v1 không cấp cho vai app (trigger chạy bằng quyền app).
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_kiem_ban_v1(p_store uuid, p_table text, p_product uuid, p_kiem_quyen boolean)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
BEGIN
  IF pg_trigger_depth() < 1 THEN RAISE EXCEPTION 'TRIGGER_ONLY'; END IF;
  IF p_kiem_quyen AND NOT public.qn_is_store_manager_v1(p_store, public.qn_caller_id()) THEN
    RETURN 'khong_quyen';
  END IF;
  IF p_product IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM public.products
       WHERE id = p_product AND store_id = p_store AND COALESCE(is_deleted, false) = false) THEN
    RETURN 'mon_sai';
  END IF;
  IF EXISTS (SELECT 1 FROM public.ban_sessions
             WHERE store_id = p_store AND table_id::text = p_table
               AND status = 'open' AND gio_bat_dau IS NOT NULL) THEN
    RETURN 'dang_chay';
  END IF;
  RETURN 'ok';
END
$f$;

-- ── Trigger: bàn ───────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_ban_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $f$
DECLARE v_kq text;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.gia_gio_product_id IS NOT DISTINCT FROM OLD.gia_gio_product_id THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' AND NEW.gia_gio_product_id IS NULL THEN RETURN NEW; END IF;

  v_kq := public.qn_tinh_gio_kiem_ban_v1(NEW.store_id, NEW.id, NEW.gia_gio_product_id,
                                         current_user IN ('anon', 'authenticated'));
  IF v_kq = 'khong_quyen' THEN
    RAISE EXCEPTION 'TINH_GIO_CHI_QUAN_LY: chỉ Chủ quán / Quản lý đặt giá giờ cho bàn' USING ERRCODE = '42501';
  END IF;
  IF v_kq = 'mon_sai' THEN
    RAISE EXCEPTION 'TINH_GIO_MON_SAI: món giá giờ không thuộc quán này hoặc đã xoá' USING ERRCODE = '42501';
  END IF;
  IF TG_OP = 'UPDATE' AND v_kq = 'dang_chay' THEN
    RAISE EXCEPTION 'TINH_GIO_BAN_DANG_CHAY: bàn đang có khách tính giờ, tính tiền xong mới đổi giá giờ được'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END
$f$;

DROP TRIGGER IF EXISTS qn_tinh_gio_ban_v1 ON public.ban_dining_tables;
CREATE TRIGGER qn_tinh_gio_ban_v1 BEFORE INSERT OR UPDATE ON public.ban_dining_tables
  FOR EACH ROW EXECUTE FUNCTION public.qn_tinh_gio_ban_v1();

-- ── Trigger: phiên bàn ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_phien_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $f$
DECLARE
  v_client boolean := current_user IN ('anon', 'authenticated');
  v_mon uuid;
  v_kq text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF COALESCE(NEW.status, 'open') = 'open' AND NEW.table_id IS NOT NULL THEN
      v_mon := public.qn_tinh_gio_mon_cua_ban_v1(NEW.store_id, NEW.table_id::text);
    END IF;
    IF v_mon IS NOT NULL THEN
      -- giờ của máy chủ; clock_timestamp để hai phiên mở trong cùng giao dịch vẫn khác mốc
      IF v_client OR NEW.gio_bat_dau IS NULL THEN NEW.gio_bat_dau := clock_timestamp(); END IF;
    ELSIF v_client THEN
      NEW.gio_bat_dau := NULL;
    END IF;
    RETURN NEW;
  END IF;

  IF v_client THEN
    NEW.gio_bat_dau := OLD.gio_bat_dau;   -- app không sửa được mốc (lặng lẽ giữ, upsert cũ không vỡ)
    IF COALESCE(OLD.status, 'open') = 'open' THEN
      IF NEW.table_id IS DISTINCT FROM OLD.table_id
         AND (OLD.gio_bat_dau IS NOT NULL
              OR (NEW.table_id IS NOT NULL
                  AND public.qn_tinh_gio_mon_cua_ban_v1(NEW.store_id, NEW.table_id::text) IS NOT NULL)) THEN
        RAISE EXCEPTION 'TINH_GIO_CHUYEN_BAN: bàn tính giờ phải chuyển qua ban_chuyen_ban_tinh_gio_v1 (cập nhật app)'
          USING ERRCODE = '42501';
      END IF;
      IF NEW.status = 'cancelled' AND OLD.gio_bat_dau IS NOT NULL
         AND OLD.gio_bat_dau < clock_timestamp() - interval '5 minutes'
         AND public.qn_tinh_gio_trang_thai_chot_v1(OLD.id, OLD.gio_bat_dau) = 'chua' THEN
        RAISE EXCEPTION 'TINH_GIO_HUY_CAN_CHOT: bàn tính giờ mở quá 5 phút phải chốt giờ trước khi huỷ'
          USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;

  -- Mọi vai (kể cả settle_ban_session_v5 / complete_pos_sale_v1): chưa chốt giờ thì không đóng được.
  IF COALESCE(OLD.status, 'open') = 'open' AND NEW.status = 'closed'
     AND OLD.gio_bat_dau IS NOT NULL AND NEW.gio_bat_dau IS NOT NULL THEN
    v_kq := public.qn_tinh_gio_trang_thai_chot_v1(OLD.id, OLD.gio_bat_dau);
    IF v_kq = 'chua' THEN
      RAISE EXCEPTION 'CHUA_CHOT_GIO: bàn tính giờ chưa chốt giờ, chưa thanh toán được (cập nhật app)';
    ELSIF v_kq = 'cu' THEN
      RAISE EXCEPTION 'CHOT_GIO_QUA_CU: giờ đã chốt quá 15 phút, hãy tính lại giờ rồi thanh toán';
    END IF;
  END IF;
  RETURN NEW;
END
$f$;

DROP TRIGGER IF EXISTS qn_tinh_gio_phien_v1 ON public.ban_sessions;
CREATE TRIGGER qn_tinh_gio_phien_v1 BEFORE INSERT OR UPDATE ON public.ban_sessions
  FOR EACH ROW EXECUTE FUNCTION public.qn_tinh_gio_phien_v1();

-- ── Trigger: dòng tiền giờ (chỉ áp vai app) ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_mon_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $f$
BEGIN
  IF current_user NOT IN ('anon', 'authenticated') THEN
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  END IF;
  IF TG_OP = 'DELETE' THEN
    IF OLD.gio_tu IS NOT NULL OR OLD.gio_den IS NOT NULL THEN
      RAISE EXCEPTION 'TINH_GIO_DONG_KHOA: dòng tiền giờ không xoá được, Quản lý huỷ dòng nếu cần' USING ERRCODE = '42501';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.gio_tu IS NOT NULL OR NEW.gio_den IS NOT NULL THEN
      RAISE EXCEPTION 'TINH_GIO_DONG_KHOA: dòng tiền giờ chỉ máy chủ ghi' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;
  IF OLD.gio_tu IS NULL AND OLD.gio_den IS NULL THEN
    IF NEW.gio_tu IS NOT NULL OR NEW.gio_den IS NOT NULL THEN
      RAISE EXCEPTION 'TINH_GIO_DONG_KHOA: dòng tiền giờ chỉ máy chủ ghi' USING ERRCODE = '42501';
    END IF;
    RETURN NEW;
  END IF;
  -- Dòng tiền giờ: app chỉ đổi được trạng thái (huỷ có duyệt do guard_ban_item_sent_v1 lo) và ghi chú.
  IF ROW(NEW.gio_tu, NEW.gio_den, NEW.store_id, NEW.session_id, NEW.product_id, NEW.product_name,
         NEW.quantity, NEW.unit_price, NEW.price, NEW.subtotal, NEW.modifiers_json)
     IS DISTINCT FROM
     ROW(OLD.gio_tu, OLD.gio_den, OLD.store_id, OLD.session_id, OLD.product_id, OLD.product_name,
         OLD.quantity, OLD.unit_price, OLD.price, OLD.subtotal, OLD.modifiers_json) THEN
    RAISE EXCEPTION 'TINH_GIO_DONG_KHOA: dòng tiền giờ không sửa được' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END
$f$;

DROP TRIGGER IF EXISTS qn_tinh_gio_mon_v1 ON public.ban_session_items;
CREATE TRIGGER qn_tinh_gio_mon_v1 BEFORE INSERT OR UPDATE OR DELETE ON public.ban_session_items
  FOR EACH ROW EXECUTE FUNCTION public.qn_tinh_gio_mon_v1();

-- ── Ghi dòng tiền giờ của đoạn đang chạy (nội bộ: người gọi đã kiểm quyền và khoá phiên) ─────────────
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_ghi_dong_v1(p_store uuid, p_session uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  v_s record; v_t record; v_p record; v_line record;
  v_den timestamptz; v_phut integer; v_tien numeric; v_ten text; v_id uuid; v_tong numeric;
  TZ constant text := 'Asia/Ho_Chi_Minh';
BEGIN
  SELECT * INTO v_s FROM public.ban_sessions WHERE id = p_session AND store_id = p_store;
  IF NOT FOUND OR v_s.status <> 'open' THEN RAISE EXCEPTION 'TINH_GIO: phiên bàn không mở'; END IF;
  IF v_s.gio_bat_dau IS NULL THEN RETURN jsonb_build_object('tinh_gio', false); END IF;

  SELECT * INTO v_t FROM public.ban_dining_tables WHERE id = v_s.table_id::text AND store_id = p_store;
  IF NOT FOUND OR v_t.gia_gio_product_id IS NULL THEN
    RAISE EXCEPTION 'TINH_GIO_BAN_MAT_GIA: bàn đang tính giờ nhưng không còn giá giờ';
  END IF;
  -- món đã xoá mềm vẫn tính (không chặn quán thu tiền bàn đang chơi)
  SELECT id, name, sell_price INTO v_p FROM public.products
  WHERE id = v_t.gia_gio_product_id AND store_id = p_store;
  IF NOT FOUND THEN RAISE EXCEPTION 'TINH_GIO_MON_SAI: không thấy món giá giờ của bàn'; END IF;

  SELECT * INTO v_line FROM public.ban_session_items
  WHERE session_id = p_session AND store_id = p_store AND gio_tu = v_s.gio_bat_dau
  ORDER BY added_at LIMIT 1;
  IF FOUND AND v_line.kitchen_status = 'huy' THEN   -- Quản lý đã bỏ tiền giờ: không ghi lại
    RETURN jsonb_build_object('tinh_gio', true, 'da_huy', true, 'item_id', v_line.id,
      'gio_tu', v_line.gio_tu, 'gio_den', v_line.gio_den, 'thanh_tien', 0);
  END IF;

  v_den  := clock_timestamp();
  v_phut := GREATEST(1, ceil(extract(epoch FROM (v_den - v_s.gio_bat_dau)) / 60.0))::integer;
  v_tien := ceil(v_phut * GREATEST(COALESCE(v_p.sell_price, 0), 0) / 60.0 / 1000.0) * 1000;
  v_ten  := v_p.name || ' · ' || COALESCE(NULLIF(trim(v_t.label), ''), v_t.name)
            || ' · ' || to_char(v_s.gio_bat_dau AT TIME ZONE TZ, 'HH24:MI')
            || '–' || to_char(v_den AT TIME ZONE TZ, 'HH24:MI')
            || ' (' || CASE WHEN v_phut >= 60 THEN (v_phut / 60) || 'g' || lpad((v_phut % 60)::text, 2, '0')
                            ELSE v_phut || 'p' END || ')';

  IF v_line.id IS NOT NULL THEN
    UPDATE public.ban_session_items
       SET product_id = v_p.id, product_name = v_ten, quantity = 1,
           unit_price = v_tien, price = v_tien::bigint, subtotal = v_tien, gio_den = v_den
     WHERE id = v_line.id;
    v_id := v_line.id;
  ELSE
    v_id := gen_random_uuid();
    INSERT INTO public.ban_session_items
      (id, store_id, session_id, product_id, product_name, unit_price, price, quantity, subtotal,
       added_by, kitchen_status, added_at, gio_tu, gio_den)
    VALUES
      (v_id, p_store, p_session, v_p.id, v_ten, v_tien, v_tien::bigint, 1, v_tien,
       'Tính giờ', 'xong', v_den, v_s.gio_bat_dau, v_den);
  END IF;

  SELECT COALESCE(sum(subtotal), 0) INTO v_tong FROM public.ban_session_items
  WHERE session_id = p_session AND store_id = p_store AND COALESCE(kitchen_status, '') <> 'huy';
  UPDATE public.ban_sessions SET total_amount = v_tong WHERE id = p_session;

  RETURN jsonb_build_object('tinh_gio', true, 'da_huy', false, 'item_id', v_id,
    'gio_tu', v_s.gio_bat_dau, 'gio_den', v_den, 'so_phut', v_phut,
    'gia_gio', COALESCE(v_p.sell_price, 0), 'thanh_tien', v_tien, 'ten', v_ten, 'tong_ban', v_tong);
END
$f$;
REVOKE ALL ON FUNCTION public.qn_tinh_gio_ghi_dong_v1(uuid, uuid) FROM PUBLIC, anon, authenticated;

-- ── App gọi: chốt giờ ───────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ban_chot_gio_v1(p_session_id uuid, p_store_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE v_s record;
BEGIN
  PERFORM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);

  SELECT * INTO v_s FROM public.ban_sessions
  WHERE id = p_session_id AND store_id = p_store_id FOR UPDATE;   -- hai máy chốt cùng lúc: xếp hàng
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy phiên bàn');
  END IF;
  IF v_s.status <> 'open' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'SESSION_NOT_OPEN', 'message', 'Phiên bàn không còn mở');
  END IF;
  RETURN jsonb_build_object('success', true,
    'data', public.qn_tinh_gio_ghi_dong_v1(p_store_id, p_session_id));
END
$f$;

-- ── App gọi: chuyển bàn / gộp bàn khi có tính giờ ───────────────────────────────────────────────
-- Bàn đích trống: chuyển. Bàn đích đang có khách: gộp (dời hết món sang phiên đích, đóng phiên nguồn).
-- Giờ ở bàn cũ được chốt thành một dòng theo giá bàn cũ trước khi dời.
CREATE OR REPLACE FUNCTION public.ban_chuyen_ban_tinh_gio_v1(p_session_id uuid, p_store_id uuid, p_table_dich text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  v_s record; v_t record; v_dich_id uuid; v_d record; v_chot jsonb; v_kieu text; v_tong numeric;
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
    v_chot := public.qn_tinh_gio_ghi_dong_v1(p_store_id, p_session_id);
  END IF;

  IF v_d.id IS NULL THEN
    v_kieu := 'chuyen';
    UPDATE public.ban_sessions
       SET table_id = p_table_dich::uuid,
           gio_bat_dau = CASE WHEN v_t.gia_gio_product_id IS NOT NULL THEN clock_timestamp() END
     WHERE id = p_session_id;
  ELSE
    v_kieu := 'gop';
    UPDATE public.ban_session_items SET session_id = v_d.id
    WHERE session_id = p_session_id AND store_id = p_store_id;
    UPDATE public.ban_sessions
       SET status = 'closed', closed_at = now(), total_amount = 0, gio_bat_dau = NULL
     WHERE id = p_session_id;
    SELECT COALESCE(sum(subtotal), 0) INTO v_tong FROM public.ban_session_items
    WHERE session_id = v_d.id AND store_id = p_store_id AND COALESCE(kitchen_status, '') <> 'huy';
    UPDATE public.ban_sessions SET total_amount = v_tong WHERE id = v_d.id;
  END IF;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'kieu', v_kieu, 'session_id', CASE WHEN v_kieu = 'gop' THEN v_d.id ELSE p_session_id END,
    'chot', v_chot));
END
$f$;

GRANT EXECUTE ON FUNCTION public.ban_chot_gio_v1(uuid, uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ban_chuyen_ban_tinh_gio_v1(uuid, uuid, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.qn_tinh_gio_mon_cua_ban_v1(uuid, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.qn_tinh_gio_trang_thai_chot_v1(uuid, timestamptz) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.qn_tinh_gio_kiem_ban_v1(uuid, text, uuid, boolean) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';

DO $done$ BEGIN RAISE NOTICE 'PATCH ban_tinh_gio_v1: xong'; END $done$;
