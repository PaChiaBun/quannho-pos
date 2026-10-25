-- Khoá cấu hình module (app_settings.key = 'module_config_v2'): CHỈ CHỦ QUÁN được sửa.
--
-- Lý do (KAY 18/10 và 21/10): chính sách RLS của app_settings chỉ kiểm tra "cùng quán" nên MỌI thành viên
-- (kể cả thu ngân) ghi được mọi dòng. Bản app cũ lại tự ghi danh sách mặc định khi đọc ra rỗng -> mất Bếp/Bàn/In hóa đơn.
-- Chặn tại máy chủ để bản app nào (kể cả bản cũ trên điện thoại) cũng không phá được.
--
-- Quy tắc:
--  • Vai admin (postgres/service_role/supabase_admin, migration, công cụ) -> luôn được.
--  • anon/authenticated: chỉ khi người gọi (qn_caller_id) là chủ quán của đúng quán đó
--    (store_members.is_owner hoặc stores.owner_user_id).
--  • Riêng INSERT khi quán CHƯA có dòng này (tạo quán mới tự gieo mặc định) -> cho phép.
--  • Mọi thay đổi (cả của chủ quán) được ghi vào module_config_history để khôi phục.
-- Chỉ động tới đúng khoá module_config_v2; các khoá khác của app_settings không đổi.
-- Giới hạn đã biết: máy còn dùng khoá anon + header x-user-id (chưa có JWT) được nhận diện theo header đó,
-- giống mọi RPC hiện hành; sẽ chặt hơn khi mọi máy đã dùng JWT.

CREATE TABLE IF NOT EXISTS public.module_config_history (
  id         bigserial PRIMARY KEY,
  at         timestamptz NOT NULL DEFAULT now(),
  store_id   uuid        NOT NULL,
  op         text        NOT NULL,
  old_value  text,
  new_value  text,
  caller_id  uuid,
  db_role    text,
  client     text
);
CREATE INDEX IF NOT EXISTS module_config_history_store_at ON public.module_config_history (store_id, at DESC);
ALTER TABLE public.module_config_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.module_config_history FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.module_config_history_id_seq FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.qn_guard_module_config()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role     text := COALESCE(current_setting('role', true), '');
  v_store    uuid;
  v_uid      uuid;
  v_is_owner boolean := false;
BEGIN
  -- Vai quản trị (migration, service_role, công cụ nội bộ): không chặn.
  IF v_role NOT IN ('anon', 'authenticated') THEN
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  END IF;

  v_store := CASE WHEN TG_OP = 'DELETE' THEN OLD.store_id ELSE NEW.store_id END;
  v_uid   := public.qn_caller_id();

  IF v_uid IS NOT NULL THEN
    v_is_owner :=
      EXISTS (SELECT 1 FROM public.store_members
              WHERE store_id = v_store AND user_id = v_uid AND is_owner)
      OR EXISTS (SELECT 1 FROM public.stores WHERE id = v_store AND owner_user_id = v_uid);
  END IF;

  IF v_is_owner THEN
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
  END IF;

  -- Quán chưa có dòng này (tạo quán mới gieo mặc định): cho tạo. Upsert lên dòng đã có sẽ rơi xuống nhánh chặn.
  IF TG_OP = 'INSERT' AND v_uid IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM public.app_settings WHERE store_id = v_store AND key = 'module_config_v2') THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'MODULE_CONFIG_OWNER_ONLY: chi Chu quan duoc thay doi cau hinh module'
    USING ERRCODE = '42501';
END
$function$;

CREATE OR REPLACE FUNCTION public.qn_log_module_config()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_hdr json;
BEGIN
  BEGIN v_hdr := NULLIF(current_setting('request.headers', true), '')::json; EXCEPTION WHEN OTHERS THEN v_hdr := NULL; END;
  INSERT INTO public.module_config_history (store_id, op, old_value, new_value, caller_id, db_role, client)
  VALUES (
    CASE WHEN TG_OP = 'DELETE' THEN OLD.store_id ELSE NEW.store_id END,
    TG_OP,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE OLD.value END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE NEW.value END,
    public.qn_caller_id(),
    COALESCE(current_setting('role', true), ''),
    left(COALESCE(v_hdr->>'x-client-info', ''), 60)
  );
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;   -- ghi lịch sử không bao giờ được làm hỏng nghiệp vụ
END
$function$;

REVOKE ALL ON FUNCTION public.qn_guard_module_config() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.qn_log_module_config() FROM PUBLIC;

DROP TRIGGER IF EXISTS qn_module_config_guard_iu ON public.app_settings;
DROP TRIGGER IF EXISTS qn_module_config_guard_d  ON public.app_settings;
DROP TRIGGER IF EXISTS qn_module_config_log_iu   ON public.app_settings;
DROP TRIGGER IF EXISTS qn_module_config_log_d    ON public.app_settings;

CREATE TRIGGER qn_module_config_guard_iu
  BEFORE INSERT OR UPDATE ON public.app_settings
  FOR EACH ROW WHEN (NEW.key = 'module_config_v2')
  EXECUTE FUNCTION public.qn_guard_module_config();

CREATE TRIGGER qn_module_config_guard_d
  BEFORE DELETE ON public.app_settings
  FOR EACH ROW WHEN (OLD.key = 'module_config_v2')
  EXECUTE FUNCTION public.qn_guard_module_config();

CREATE TRIGGER qn_module_config_log_iu
  AFTER INSERT OR UPDATE ON public.app_settings
  FOR EACH ROW WHEN (NEW.key = 'module_config_v2')
  EXECUTE FUNCTION public.qn_log_module_config();

CREATE TRIGGER qn_module_config_log_d
  AFTER DELETE ON public.app_settings
  FOR EACH ROW WHEN (OLD.key = 'module_config_v2')
  EXECUTE FUNCTION public.qn_log_module_config();
