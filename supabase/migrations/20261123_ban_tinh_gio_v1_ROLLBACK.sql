-- ============================================================================
-- HOÀN TÁC 20261123_ban_tinh_gio_v1.sql
-- ⚠ Xoá 3 cột nên MẤT cấu hình giá giờ của bàn và giờ vào / giờ ra trên các dòng tiền giờ.
--   Dòng tiền giờ đã ghi (kể cả trong hoá đơn đã thanh toán) GIỮ NGUYÊN như một dòng món thường.
-- ⚠ Chạy khi không còn bàn nào đang tính giờ, nếu không các bàn đó sẽ thanh toán mà không có tiền giờ.
-- ============================================================================
DO $pf$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.ban_sessions WHERE status = 'open' AND gio_bat_dau IS NOT NULL;
  RAISE NOTICE 'ROLLBACK ban_tinh_gio_v1: % phiên đang tính giờ sẽ thành phiên thường', n;
END
$pf$;

DROP TRIGGER IF EXISTS qn_tinh_gio_mon_v1   ON public.ban_session_items;
DROP TRIGGER IF EXISTS qn_tinh_gio_phien_v1 ON public.ban_sessions;
DROP TRIGGER IF EXISTS qn_tinh_gio_ban_v1   ON public.ban_dining_tables;

DROP FUNCTION IF EXISTS public.ban_chuyen_ban_tinh_gio_v1(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.ban_chot_gio_v1(uuid, uuid);
DROP FUNCTION IF EXISTS public.qn_tinh_gio_ghi_dong_v1(uuid, uuid);
DROP FUNCTION IF EXISTS public.qn_tinh_gio_mon_v1();
DROP FUNCTION IF EXISTS public.qn_tinh_gio_phien_v1();
DROP FUNCTION IF EXISTS public.qn_tinh_gio_ban_v1();
DROP FUNCTION IF EXISTS public.qn_tinh_gio_kiem_ban_v1(uuid, text, uuid, boolean);
DROP FUNCTION IF EXISTS public.qn_tinh_gio_trang_thai_chot_v1(uuid, timestamptz);
DROP FUNCTION IF EXISTS public.qn_tinh_gio_mon_cua_ban_v1(uuid, text);

ALTER TABLE public.ban_session_items DROP COLUMN IF EXISTS gio_den;
ALTER TABLE public.ban_session_items DROP COLUMN IF EXISTS gio_tu;
ALTER TABLE public.ban_sessions      DROP COLUMN IF EXISTS gio_bat_dau;
ALTER TABLE public.ban_dining_tables DROP COLUMN IF EXISTS gia_gio_product_id;

NOTIFY pgrst, 'reload schema';

DO $done$ BEGIN RAISE NOTICE 'ROLLBACK ban_tinh_gio_v1: xong'; END $done$;
