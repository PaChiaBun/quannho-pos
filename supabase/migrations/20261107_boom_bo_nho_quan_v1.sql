-- ============================================================================
-- BỘ NHỚ RIÊNG TỪNG QUÁN cho Bé Boom — NHÁP 07/11/2026, CHƯA ÁP (.docs/ke-hoach-boom-bo-nho-thoi-tiet.md, giai đoạn 4).
-- Hoàn tác: 20261107_boom_bo_nho_quan_v1_ROLLBACK.sql. Kiểm thử: supabase/tests/boom_bo_nho_quan_v1_test.sql.
--
-- • boom_quan_ho_so: mỗi quán một dòng (loại quán, khách chính, gần gì, giờ mở, mục tiêu…) + công tắc tắt bộ nhớ của quán.
-- • boom_quan_ghi_nho: điều Boom biết về quán; nguồn (chủ quán nói / nhân viên nói / Boom đoán), trạng thái, mức xem,
--   ngày hiệu lực; sửa thì dòng cũ hết hiệu lực và dòng mới trỏ về dòng cũ (giữ lịch sử).
-- • boom_quan_loi_khuyen: lời khuyên, chỉ số đo, mốc đầu, ngày đo lại, kết quả, chủ quán có làm không.
--
-- QUYỀN: cả 3 bảng bật RLS và KHÔNG có policy → app không đọc / ghi thẳng được; chỉ hàm boom-chat (service_role) đọc, ghi.
-- Chủ quán xem, sửa, xoá, tắt bộ nhớ QUA các hàm boom_bo_nho_*_v1 (kiểm đúng chủ quán). Nhân viên không gọi được.
-- Không lưu: số bán hàng (đọc mới mỗi lần), số điện thoại khách, chuyện riêng nhân viên, tài khoản ngân hàng (máy chủ lọc trước khi ghi).
-- Sang nhượng quán (đổi owner_user_id): xoá ghi nhớ mức "chỉ chủ quán" và lời khuyên; xoá quán: xoá hết (ON DELETE CASCADE).
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS public.boom_quan_ho_so (
  store_id    uuid PRIMARY KEY REFERENCES public.stores(id) ON DELETE CASCADE,
  loai_quan   text CHECK (loai_quan IS NULL OR length(loai_quan) <= 120),
  khach_chinh text CHECK (khach_chinh IS NULL OR length(khach_chinh) <= 200),
  gan_gi      text CHECK (gan_gi IS NULL OR length(gan_gi) <= 200),
  gio_mo      text CHECK (gio_mo IS NULL OR length(gio_mo) <= 120),
  ngay_nghi   text CHECK (ngay_nghi IS NULL OR length(ngay_nghi) <= 120),
  muc_tieu    text CHECK (muc_tieu IS NULL OR length(muc_tieu) <= 200),
  tat         boolean NOT NULL DEFAULT false,
  cap_nhat    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.boom_quan_ghi_nho (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  noi_dung    text NOT NULL CHECK (length(noi_dung) BETWEEN 3 AND 300),
  loai        text NOT NULL CHECK (loai IN ('su_that', 'so_thich', 'da_thu', 'khong_hoi')),
  nguon       text NOT NULL CHECK (nguon IN ('chu_quan_noi', 'nhan_vien_noi', 'boom_doan')),
  trang_thai  text NOT NULL DEFAULT 'doan' CHECK (trang_thai IN ('xac_nhan', 'doan', 'het_hieu_luc')),
  muc_xem     text NOT NULL DEFAULT 'chu_quan' CHECK (muc_xem IN ('chu_quan', 'ca_quan')),
  tu_ngay     date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
  den_ngay    date,
  nguoi_noi   uuid,
  thay_cho    uuid REFERENCES public.boom_quan_ghi_nho(id) ON DELETE SET NULL,
  tao_luc     timestamptz NOT NULL DEFAULT now(),
  cap_nhat    timestamptz NOT NULL DEFAULT now(),
  -- chỉ điều chủ quán nói (hoặc chủ quán xác nhận lại) mới là "đã xác nhận"; Boom đoán, nhân viên nói thì chờ chủ quán
  CHECK (trang_thai <> 'xac_nhan' OR nguon = 'chu_quan_noi'),
  CHECK (den_ngay IS NULL OR den_ngay >= tu_ngay)
);
CREATE INDEX IF NOT EXISTS idx_boom_quan_ghi_nho_con ON public.boom_quan_ghi_nho (store_id, cap_nhat DESC)
  WHERE trang_thai <> 'het_hieu_luc';

CREATE TABLE IF NOT EXISTS public.boom_quan_loi_khuyen (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  noi_dung      text NOT NULL CHECK (length(noi_dung) BETWEEN 3 AND 500),
  chi_so        text NOT NULL CHECK (length(chi_so) BETWEEN 2 AND 80),
  moc_dau       numeric,
  ngay_bat_dau  date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
  ngay_do       date NOT NULL,
  ket_qua       numeric,
  chu_quan_lam  text NOT NULL DEFAULT 'chua_biet' CHECK (chu_quan_lam IN ('co', 'khong', 'chua_biet')),
  tao_luc       timestamptz NOT NULL DEFAULT now(),
  CHECK (ngay_do >= ngay_bat_dau)
);
CREATE INDEX IF NOT EXISTS idx_boom_quan_loi_khuyen_do ON public.boom_quan_loi_khuyen (store_id, ngay_do) WHERE ket_qua IS NULL;

ALTER TABLE public.boom_quan_ho_so     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boom_quan_ghi_nho    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boom_quan_loi_khuyen ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.boom_quan_ho_so, public.boom_quan_ghi_nho, public.boom_quan_loi_khuyen FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.boom_quan_ho_so, public.boom_quan_ghi_nho, public.boom_quan_loi_khuyen TO service_role;

-- Giới hạn mỗi quán 200 ghi nhớ còn hiệu lực: tránh phình, Boom chỉ gửi phần liên quan cho AI
CREATE OR REPLACE FUNCTION public._boom_ghi_nho_gioi_han()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NEW.trang_thai <> 'het_hieu_luc' AND (
       SELECT count(*) FROM public.boom_quan_ghi_nho
       WHERE store_id = NEW.store_id AND trang_thai <> 'het_hieu_luc' AND id <> NEW.id) >= 200 THEN
    RAISE EXCEPTION 'BOOM_GHI_NHO_DAY' USING ERRCODE = 'check_violation';
  END IF;
  NEW.cap_nhat := now();
  RETURN NEW;
END
$$;
DROP TRIGGER IF EXISTS trg_boom_ghi_nho_gioi_han ON public.boom_quan_ghi_nho;
CREATE TRIGGER trg_boom_ghi_nho_gioi_han BEFORE INSERT OR UPDATE ON public.boom_quan_ghi_nho
  FOR EACH ROW EXECUTE FUNCTION public._boom_ghi_nho_gioi_han();

-- Sang nhượng: chủ mới không thấy điều riêng của chủ cũ
CREATE OR REPLACE FUNCTION public._boom_bo_nho_doi_chu()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NEW.owner_user_id IS DISTINCT FROM OLD.owner_user_id THEN
    DELETE FROM public.boom_quan_ghi_nho WHERE store_id = NEW.id AND muc_xem = 'chu_quan';
    DELETE FROM public.boom_quan_loi_khuyen WHERE store_id = NEW.id;
    UPDATE public.boom_quan_ho_so SET muc_tieu = NULL, cap_nhat = now() WHERE store_id = NEW.id;
  END IF;
  RETURN NEW;
END
$$;
DROP TRIGGER IF EXISTS trg_boom_bo_nho_doi_chu ON public.stores;
CREATE TRIGGER trg_boom_bo_nho_doi_chu AFTER UPDATE OF owner_user_id ON public.stores
  FOR EACH ROW EXECUTE FUNCTION public._boom_bo_nho_doi_chu();

-- Chủ quán = chủ trên bảng stores hoặc thành viên có is_owner
CREATE OR REPLACE FUNCTION public._boom_la_chu(p_store uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (SELECT 1 FROM public.stores WHERE id = p_store AND owner_user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.store_members WHERE store_id = p_store AND user_id = auth.uid() AND is_owner IS TRUE));
$$;
REVOKE ALL ON FUNCTION public._boom_la_chu(uuid) FROM PUBLIC, anon, authenticated;

-- Chủ quán xem Boom đang nhớ gì (chỉ điều còn hiệu lực)
CREATE OR REPLACE FUNCTION public.boom_bo_nho_xem_v1(p_store uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NOT public._boom_la_chu(p_store) THEN RETURN NULL; END IF;
  RETURN jsonb_build_object(
    'ho_so', (SELECT to_jsonb(h) - 'store_id' FROM public.boom_quan_ho_so h WHERE h.store_id = p_store),
    'ghi_nho', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', g.id, 'noi_dung', g.noi_dung, 'loai', g.loai, 'nguon', g.nguon,
        'trang_thai', g.trang_thai, 'muc_xem', g.muc_xem, 'tu_ngay', g.tu_ngay, 'den_ngay', g.den_ngay) ORDER BY g.cap_nhat DESC)
      FROM public.boom_quan_ghi_nho g WHERE g.store_id = p_store AND g.trang_thai <> 'het_hieu_luc'), '[]'::jsonb));
END
$$;

-- Chủ quán sửa một ghi nhớ: dòng cũ hết hiệu lực, dòng mới là chủ quán nói, đã xác nhận
CREATE OR REPLACE FUNCTION public.boom_bo_nho_sua_v1(p_id uuid, p_noi_dung text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE g public.boom_quan_ghi_nho; v_id uuid;
BEGIN
  SELECT * INTO g FROM public.boom_quan_ghi_nho WHERE id = p_id AND trang_thai <> 'het_hieu_luc';
  IF NOT FOUND OR NOT public._boom_la_chu(g.store_id) OR length(trim(coalesce(p_noi_dung, ''))) NOT BETWEEN 3 AND 300 THEN
    RETURN NULL;
  END IF;
  UPDATE public.boom_quan_ghi_nho SET trang_thai = 'het_hieu_luc',
    den_ngay = greatest(tu_ngay, (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date) WHERE id = p_id;
  INSERT INTO public.boom_quan_ghi_nho (store_id, noi_dung, loai, nguon, trang_thai, muc_xem, nguoi_noi, thay_cho)
  VALUES (g.store_id, trim(p_noi_dung), g.loai, 'chu_quan_noi', 'xac_nhan', g.muc_xem, auth.uid(), g.id)
  RETURNING id INTO v_id;
  RETURN v_id;
END
$$;

-- Chủ quán xoá hẳn một ghi nhớ (kể cả lịch sử của nó)
CREATE OR REPLACE FUNCTION public.boom_bo_nho_xoa_v1(p_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
DECLARE v_store uuid;
BEGIN
  SELECT store_id INTO v_store FROM public.boom_quan_ghi_nho WHERE id = p_id;
  IF v_store IS NULL OR NOT public._boom_la_chu(v_store) THEN RETURN false; END IF;
  WITH RECURSIVE cu AS (
    SELECT id, thay_cho FROM public.boom_quan_ghi_nho WHERE id = p_id
    UNION ALL
    SELECT g.id, g.thay_cho FROM public.boom_quan_ghi_nho g JOIN cu ON g.id = cu.thay_cho
  )
  DELETE FROM public.boom_quan_ghi_nho WHERE id IN (SELECT id FROM cu);
  RETURN true;
END
$$;

-- Chủ quán tắt / bật bộ nhớ của quán mình (tắt: Boom không đọc, không ghi; dữ liệu cũ giữ nguyên cho tới khi xoá)
CREATE OR REPLACE FUNCTION public.boom_bo_nho_tat_v1(p_store uuid, p_tat boolean)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF p_tat IS NULL OR NOT public._boom_la_chu(p_store) THEN RETURN false; END IF;
  INSERT INTO public.boom_quan_ho_so (store_id, tat) VALUES (p_store, p_tat)
  ON CONFLICT (store_id) DO UPDATE SET tat = EXCLUDED.tat, cap_nhat = now();
  RETURN true;
END
$$;

REVOKE ALL ON FUNCTION public.boom_bo_nho_xem_v1(uuid), public.boom_bo_nho_sua_v1(uuid, text),
  public.boom_bo_nho_xoa_v1(uuid), public.boom_bo_nho_tat_v1(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.boom_bo_nho_xem_v1(uuid), public.boom_bo_nho_sua_v1(uuid, text),
  public.boom_bo_nho_xoa_v1(uuid), public.boom_bo_nho_tat_v1(uuid, boolean) TO authenticated;

COMMIT;
