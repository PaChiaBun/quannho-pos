-- HOÀN TÁC 20261023_khoa_huy_mon_da_gui_v1.sql — trả hàm kiểm PIN về bản production 23/10,
-- gỡ trigger (món + huỷ bàn), bỏ ràng buộc không âm, trả quyền sửa/xoá 2 bảng sổ huỷ. GIỮ LẠI 2 bảng lượt duyệt / sổ máy chủ (dữ liệu kiểm toán).
BEGIN;
DROP TRIGGER IF EXISTS guard_ban_item_a_sent_v1 ON public.ban_session_items;
DROP TRIGGER IF EXISTS guard_ban_item_sent_v1 ON public.ban_session_items;
DROP FUNCTION IF EXISTS public.guard_ban_item_sent_v1();
DROP TRIGGER IF EXISTS guard_ban_session_cancel_v1 ON public.ban_sessions;
DROP FUNCTION IF EXISTS public.guard_ban_session_cancel_v1();
ALTER TABLE public.ban_session_items DROP CONSTRAINT IF EXISTS ban_session_items_khong_am_v1;
DROP FUNCTION IF EXISTS public.qn_ban_item_void_check_v1(uuid, text, numeric, numeric);
DROP FUNCTION IF EXISTS public.qn_is_store_manager_v1(uuid, uuid);
GRANT UPDATE, DELETE ON public.void_audit_logs TO anon, authenticated;
GRANT UPDATE, DELETE ON public.ban_session_void_logs TO anon, authenticated;
CREATE OR REPLACE FUNCTION public.verify_manager_quick_pin_v4(p_store_id uuid, p_pin text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_caller_hash bytea;
  v_failures integer;
  v_manager record;
  v_matched boolean := false;
  v_manager_id uuid;
  v_manager_name text;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực phiên đăng nhập'
    );
  END IF;

  IF p_pin IS NULL OR p_pin !~ '^\d{6}$' THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 400,
      'error_code', 'INVALID_PIN_FORMAT', 'message', 'Mã PIN phải gồm đúng 6 chữ số'
    );
  END IF;

  IF NOT public.has_active_store_access_v4(p_store_id) THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 403,
      'error_code', 'STORE_MEMBERSHIP_FORBIDDEN', 'message', 'Tài khoản không thuộc cửa hàng này'
    );
  END IF;

  v_caller_hash := digest(convert_to(v_caller_id::text || ':' || p_store_id::text, 'utf8'), 'sha256');
  PERFORM pg_advisory_xact_lock(
    hashtextextended(encode(v_caller_hash, 'hex'), 0)
  );

  SELECT count(*) INTO v_failures
  FROM public.pos_auth_attempts_v4
  WHERE phone_hash = v_caller_hash
    AND attempt_type = 'quick_pin'
    AND is_success = false
    AND attempted_at >= now() - interval '5 minutes';

  IF v_failures >= 5 THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 429,
      'error_code', 'RATE_LIMIT_EXCEEDED',
      'message', 'Quá nhiều lần nhập sai mã PIN. Vui lòng thử lại sau 5 phút.'
    );
  END IF;

  FOR v_manager IN
    SELECT ua.id, ua.phone, ua.display_name, ua.quick_pin
    FROM public.user_accounts ua
    JOIN public.store_members sm ON sm.user_id = ua.id
    WHERE sm.store_id = p_store_id
      AND (sm.role IN ('owner', 'manager') OR sm.is_owner = true)
    UNION
    SELECT ua.id, ua.phone, ua.display_name, ua.quick_pin
    FROM public.user_accounts ua
    JOIN public.stores s ON s.owner_user_id = ua.id
    WHERE s.id = p_store_id
  LOOP
    IF v_manager.quick_pin IS NOT NULL AND v_manager.quick_pin <> '' THEN
      IF v_manager.quick_pin LIKE '$2a$%' OR v_manager.quick_pin LIKE '$2b$%' OR v_manager.quick_pin LIKE '$2y$%' THEN
        IF crypt(p_pin, v_manager.quick_pin) = v_manager.quick_pin THEN
          v_matched := true;
          v_manager_id := v_manager.id;
          v_manager_name := v_manager.display_name;
          EXIT;
        END IF;
      ELSE
        IF public.verify_password_hash_v4(v_manager.phone, p_pin, v_manager.quick_pin) THEN
          v_matched := true;
          v_manager_id := v_manager.id;
          v_manager_name := v_manager.display_name;
          UPDATE public.user_accounts
          SET quick_pin = crypt(p_pin, gen_salt('bf', 12))
          WHERE id = v_manager.id;
          EXIT;
        END IF;
      END IF;
    END IF;
  END LOOP;

  IF v_matched THEN
    DELETE FROM public.pos_auth_attempts_v4
    WHERE phone_hash = v_caller_hash AND attempt_type = 'quick_pin';

    RETURN jsonb_build_object(
      'success', true, 'status', 200,
      'manager_id', v_manager_id,
      'manager_name', COALESCE(v_manager_name, 'Quản lý')
    );
  ELSE
    INSERT INTO public.pos_auth_attempts_v4(phone_hash, attempt_type, is_success)
    VALUES (v_caller_hash, 'quick_pin', false);

    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'INVALID_PIN',
      'message', 'Mã PIN quản lý không chính xác'
    );
  END IF;
END;
$function$;
COMMIT;
NOTIFY pgrst, 'reload schema';
