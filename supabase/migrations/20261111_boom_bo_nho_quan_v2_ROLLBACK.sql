-- HOÀN TÁC 20261111_boom_bo_nho_quan_v2.sql — bỏ hạng mục, chi tiết (nội dung ghi nhớ giữ nguyên); hàm xem / sửa về bản v1.
-- Đưa mã boom-chat về bản trước TRƯỚC khi chạy tệp này (mã bản 2 ghi 2 cột bị bỏ).
BEGIN;
DROP INDEX IF EXISTS public.idx_boom_quan_ghi_nho_hang_muc;
ALTER TABLE public.boom_quan_ghi_nho DROP CONSTRAINT IF EXISTS boom_quan_ghi_nho_hang_muc_rieng;
ALTER TABLE public.boom_quan_ghi_nho DROP COLUMN IF EXISTS chi_tiet, DROP COLUMN IF EXISTS hang_muc;

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
COMMIT;
