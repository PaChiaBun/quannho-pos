-- Máy chủ tự gieo cấu hình module mặc định (app_settings.key = 'module_config_v2') ngay khi có quán mới.
--
-- Lý do (Nhai Nhai - PVC 17/11, LILY Q10 18/11, Lily Q10 19/11): việc gieo nằm ở app, quán tạo qua
-- đường nhập lại mật khẩu (hoặc bấm Hủy ở ô mật khẩu, hoặc bản app cũ) không được gieo. Từ 11/11 app
-- KHÔNG ghi khi không thấy dòng cấu hình (chống ghi đè như KAY) nên màn Chức năng bỏ qua mọi lần bật/tắt.
--
-- Chỉ gieo module: danh mục Thu Chi và vai trò vẫn do app gieo bằng INSERT, gieo thêm ở đây sẽ sinh trùng.
-- Giá trị chép đúng StoreAuthService.seedDefaults; app upsert lại cùng giá trị nên không xung đột.

CREATE OR REPLACE FUNCTION public.qn_seed_module_config()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  INSERT INTO public.app_settings (store_id, key, value)
  VALUES (NEW.id, 'module_config_v2', '["pos","report","finance","kho"]')
  ON CONFLICT (store_id, key) DO NOTHING;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;   -- gieo không bao giờ được làm hỏng việc tạo quán
END
$function$;

REVOKE ALL ON FUNCTION public.qn_seed_module_config() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS qn_stores_seed_module_config ON public.stores;
CREATE TRIGGER qn_stores_seed_module_config
  AFTER INSERT ON public.stores
  FOR EACH ROW EXECUTE FUNCTION public.qn_seed_module_config();
