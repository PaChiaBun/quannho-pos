-- ============================================================================
-- BỘ NHỚ QUÁN bản 2, giai đoạn 1 (.docs/thiet-ke-bo-nho-quan-boom.md): mỗi ghi nhớ có HẠNG MỤC và CHI TIẾT.
-- Hoàn tác: 20261111_boom_bo_nho_quan_v2_ROLLBACK.sql. Kiểm thử: supabase/tests/boom_bo_nho_quan_v2_test.sql.
-- Chỉ THÊM cột (cho phép NULL, ghi nhớ cũ không đổi) và cập nhật 2 hàm xem / sửa để giữ hạng mục khi chủ quán sửa.
-- Phải áp TRƯỚC khi đưa mã boom-chat mới lên (mã mới ghi 2 cột này; thiếu cột thì lượt ghi nhớ lỗi, câu trả lời không sao).
-- ============================================================================
BEGIN;

ALTER TABLE public.boom_quan_ghi_nho
  ADD COLUMN IF NOT EXISTS hang_muc text CHECK (hang_muc IS NULL OR hang_muc IN
    ('ho_so', 'gio_giac', 'khach', 'mon', 'muc_tieu', 'da_thu', 'gioi_han', 'nhan_su_tien', 'cach_noi')),
  ADD COLUMN IF NOT EXISTS chi_tiet jsonb CHECK (chi_tiet IS NULL OR
    (jsonb_typeof(chi_tiet) = 'object' AND length(chi_tiet::text) <= 600));

-- Chuyện riêng của chủ không bao giờ để cả quán thấy
ALTER TABLE public.boom_quan_ghi_nho DROP CONSTRAINT IF EXISTS boom_quan_ghi_nho_hang_muc_rieng;
ALTER TABLE public.boom_quan_ghi_nho ADD CONSTRAINT boom_quan_ghi_nho_hang_muc_rieng
  CHECK (hang_muc IS NULL OR hang_muc NOT IN ('muc_tieu', 'da_thu', 'gioi_han', 'nhan_su_tien') OR muc_xem = 'chu_quan');

CREATE INDEX IF NOT EXISTS idx_boom_quan_ghi_nho_hang_muc ON public.boom_quan_ghi_nho (store_id, hang_muc)
  WHERE trang_thai <> 'het_hieu_luc';

-- Xem: thêm hang_muc, chi_tiet
CREATE OR REPLACE FUNCTION public.boom_bo_nho_xem_v1(p_store uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $$
BEGIN
  IF NOT public._boom_la_chu(p_store) THEN RETURN NULL; END IF;
  RETURN jsonb_build_object(
    'ho_so', (SELECT to_jsonb(h) - 'store_id' FROM public.boom_quan_ho_so h WHERE h.store_id = p_store),
    'ghi_nho', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', g.id, 'noi_dung', g.noi_dung, 'loai', g.loai, 'nguon', g.nguon,
        'trang_thai', g.trang_thai, 'muc_xem', g.muc_xem, 'tu_ngay', g.tu_ngay, 'den_ngay', g.den_ngay,
        'hang_muc', g.hang_muc, 'chi_tiet', g.chi_tiet) ORDER BY g.cap_nhat DESC)
      FROM public.boom_quan_ghi_nho g WHERE g.store_id = p_store AND g.trang_thai <> 'het_hieu_luc'), '[]'::jsonb));
END
$$;

-- Sửa: dòng mới giữ hạng mục; chi tiết bỏ vì chủ quán đã viết lại nội dung
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
  INSERT INTO public.boom_quan_ghi_nho (store_id, noi_dung, loai, nguon, trang_thai, muc_xem, nguoi_noi, thay_cho, hang_muc)
  VALUES (g.store_id, trim(p_noi_dung), g.loai, 'chu_quan_noi', 'xac_nhan', g.muc_xem, auth.uid(), g.id, g.hang_muc)
  RETURNING id INTO v_id;
  RETURN v_id;
END
$$;

COMMIT;
