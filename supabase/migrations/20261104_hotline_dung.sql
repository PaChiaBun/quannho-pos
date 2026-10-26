-- ============================================================================
-- SỬA SỐ HOTLINE trong câu báo mật khẩu tạm hết hạn (Chủ Quán 26/10: số đúng là 0927 55 8888, không phải 0838.518.618)
-- Định nghĩa lại verify_user_login_v4 + change_temp_password_v1 đúng bản 20261103, chỉ đổi số trong câu báo; quyền giữ nguyên.
-- Hoàn tác: …_ROLLBACK.sql (trả câu cũ).
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.verify_user_login_v4(p_phone text, p_password text, p_store_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_phone text := public.normalize_phone_digits_v4(COALESCE(p_phone, ''));
  v_phone_hash bytea;
  v_user record;
  v_valid boolean := false;
  v_failures integer;
  v_stores jsonb := '[]'::jsonb;
  v_selected_role text;
BEGIN
  IF v_phone = '' OR COALESCE(p_password, '') = '' THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 400,
      'error_code', 'MISSING_PARAMETERS',
      'message', 'Số điện thoại và mật khẩu là bắt buộc'
    );
  END IF;

  v_phone_hash := digest(convert_to(v_phone, 'utf8'), 'sha256');
  PERFORM pg_advisory_xact_lock(hashtextextended(encode(v_phone_hash, 'hex'), 0));

  DELETE FROM public.pos_auth_attempts_v4
  WHERE attempted_at < now() - interval '24 hours';

  SELECT count(*) INTO v_failures
  FROM public.pos_auth_attempts_v4
  WHERE phone_hash = v_phone_hash
    AND attempt_type = 'login'
    AND is_success = false
    AND attempted_at >= now() - interval '5 minutes';

  IF v_failures >= 5 THEN
    RETURN jsonb_build_object(
      'success', false, 'status', 429,
      'error_code', 'RATE_LIMIT_EXCEEDED',
      'message', 'Quá nhiều lần thử thất bại. Vui lòng thử lại sau 5 phút.'
    );
  END IF;

  SELECT ua.id, ua.phone, ua.display_name, ua.password_hash, ua.temp_password_expires_at
  INTO v_user
  FROM public.user_accounts ua
  WHERE public.normalize_phone_digits_v4(ua.phone) = v_phone
  ORDER BY ua.id
  LIMIT 1
  FOR UPDATE;

  IF v_user.id IS NOT NULL THEN
    v_valid := public.verify_password_hash_v4(
      v_user.phone,
      p_password,
      v_user.password_hash
    );
  END IF;

  IF NOT v_valid THEN
    INSERT INTO public.pos_auth_attempts_v4(phone_hash, attempt_type, is_success)
    VALUES (v_phone_hash, 'login', false);
    RETURN jsonb_build_object(
      'success', false, 'status', 401,
      'error_code', 'INVALID_CREDENTIALS',
      'message', 'Số điện thoại hoặc mật khẩu không chính xác'
    );
  END IF;

  IF v_user.password_hash NOT LIKE '$2a$%'
     AND v_user.password_hash NOT LIKE '$2b$%'
     AND v_user.password_hash NOT LIKE '$2y$%' THEN
    UPDATE public.user_accounts
    SET password_hash = crypt(p_password, gen_salt('bf', 12))
    WHERE id = v_user.id;
  END IF;

  DELETE FROM public.pos_auth_attempts_v4
  WHERE phone_hash = v_phone_hash AND attempt_type = 'login';

  -- Mật khẩu tạm do quản trị cấp (26/10): quá 24 giờ → từ chối; còn hạn → KHÔNG cấp phiên, bắt đặt mật khẩu mới
  -- (app gọi change_temp_password_v1). Cổng đăng nhập dùng chung hàm này nên cũng không cấp vé bằng mật khẩu tạm.
  IF v_user.temp_password_expires_at IS NOT NULL THEN
    IF v_user.temp_password_expires_at <= now() THEN
      RETURN jsonb_build_object(
        'success', false, 'status', 401,
        'error_code', 'TEMP_PASSWORD_EXPIRED',
        'message', 'Mật khẩu tạm đã hết hạn (quá 24 giờ). Vui lòng gọi Hotline 0927 55 8888 để được cấp lại.'
      );
    END IF;
    RETURN jsonb_build_object(
      'success', false, 'status', 403,
      'error_code', 'MUST_CHANGE_PASSWORD',
      'message', 'Đây là mật khẩu tạm. Vui lòng đặt mật khẩu mới để tiếp tục.'
    );
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'store_id', s.id,
    'store_name', s.name,
    'store_code', s.store_code,
    'role', sm.role,
    'is_owner', COALESCE(sm.is_owner, false)
  ) ORDER BY s.name), '[]'::jsonb)
  INTO v_stores
  FROM public.store_members sm
  JOIN public.stores s ON s.id = sm.store_id
  WHERE sm.user_id = v_user.id;

  IF p_store_id IS NOT NULL THEN
    SELECT sm.role INTO v_selected_role
    FROM public.store_members sm
    WHERE sm.user_id = v_user.id AND sm.store_id = p_store_id;

    IF v_selected_role IS NULL AND EXISTS (
      SELECT 1 FROM public.stores s
      WHERE s.id = p_store_id AND s.owner_user_id = v_user.id
    ) THEN
      v_selected_role := 'owner';
    END IF;

    IF v_selected_role IS NULL THEN
      RETURN jsonb_build_object(
        'success', false, 'status', 403,
        'error_code', 'STORE_MEMBERSHIP_FORBIDDEN',
        'message', 'Tài khoản không thuộc cửa hàng này'
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true, 'status', 200,
    'user_id', v_user.id,
    'phone', v_phone,
    'display_name', COALESCE(v_user.display_name, 'Người dùng'),
    'stores', v_stores,
    'selected_role', v_selected_role
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.change_temp_password_v1(p_phone text, p_temp_password text, p_new_password text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $fn$
DECLARE
  v_phone text := public.normalize_phone_digits_v4(COALESCE(p_phone, ''));
  v_phone_hash bytea;
  v_user record;
  v_failures integer;
BEGIN
  IF v_phone = '' OR COALESCE(p_temp_password, '') = '' THEN
    RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'MISSING_PARAMETERS',
      'message', 'Số điện thoại và mật khẩu tạm là bắt buộc');
  END IF;
  -- 8–72 ký tự như chủ quán đặt cho nhân viên (bcrypt chỉ dùng 72 byte đầu)
  IF char_length(COALESCE(p_new_password, '')) < 8 OR char_length(p_new_password) > 72 THEN
    RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'INVALID_PASSWORD_LENGTH',
      'message', 'Mật khẩu mới phải từ 8 đến 72 ký tự');
  END IF;

  -- cùng khoá + cùng bộ đếm lần thử với đăng nhập (không mở thêm đường dò mật khẩu)
  v_phone_hash := digest(convert_to(v_phone, 'utf8'), 'sha256');
  PERFORM pg_advisory_xact_lock(hashtextextended(encode(v_phone_hash, 'hex'), 0));
  SELECT count(*) INTO v_failures FROM public.pos_auth_attempts_v4
   WHERE phone_hash = v_phone_hash AND attempt_type = 'login' AND is_success = false
     AND attempted_at >= now() - interval '5 minutes';
  IF v_failures >= 5 THEN
    RETURN jsonb_build_object('success', false, 'status', 429, 'error_code', 'RATE_LIMIT_EXCEEDED',
      'message', 'Quá nhiều lần thử thất bại. Vui lòng thử lại sau 5 phút.');
  END IF;

  SELECT ua.id, ua.phone, ua.password_hash, ua.temp_password_expires_at INTO v_user
    FROM public.user_accounts ua
   WHERE public.normalize_phone_digits_v4(ua.phone) = v_phone
   ORDER BY ua.id LIMIT 1 FOR UPDATE;

  IF v_user.id IS NULL OR NOT public.verify_password_hash_v4(v_user.phone, p_temp_password, v_user.password_hash) THEN
    INSERT INTO public.pos_auth_attempts_v4(phone_hash, attempt_type, is_success) VALUES (v_phone_hash, 'login', false);
    RETURN jsonb_build_object('success', false, 'status', 401, 'error_code', 'INVALID_CREDENTIALS',
      'message', 'Số điện thoại hoặc mật khẩu tạm không chính xác');
  END IF;
  IF v_user.temp_password_expires_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 409, 'error_code', 'NOT_TEMP_PASSWORD',
      'message', 'Mật khẩu này không phải mật khẩu tạm — hãy đăng nhập bình thường.');
  END IF;
  IF v_user.temp_password_expires_at <= now() THEN
    RETURN jsonb_build_object('success', false, 'status', 401, 'error_code', 'TEMP_PASSWORD_EXPIRED',
      'message', 'Mật khẩu tạm đã hết hạn (quá 24 giờ). Vui lòng gọi Hotline 0927 55 8888 để được cấp lại.');
  END IF;
  IF p_new_password = p_temp_password THEN
    RETURN jsonb_build_object('success', false, 'status', 400, 'error_code', 'SAME_AS_TEMP',
      'message', 'Mật khẩu mới phải khác mật khẩu tạm');
  END IF;

  -- trigger tự xoá cờ mật khẩu tạm + thu hồi vé làm mới cũ
  UPDATE public.user_accounts SET password_hash = crypt(p_new_password, gen_salt('bf', 12)) WHERE id = v_user.id;
  DELETE FROM public.pos_auth_attempts_v4 WHERE phone_hash = v_phone_hash AND attempt_type = 'login';
  RETURN jsonb_build_object('success', true, 'status', 200, 'message', 'Đã đặt mật khẩu mới');
END
$fn$;

DO $$
BEGIN
  IF position('0838' IN pg_get_functiondef('public.verify_user_login_v4(text,text,uuid)'::regprocedure)) > 0
     OR position('0838' IN pg_get_functiondef('public.change_temp_password_v1(text,text,text)'::regprocedure)) > 0
     OR NOT has_function_privilege('anon', 'public.verify_user_login_v4(text,text,uuid)', 'execute')
     OR NOT has_function_privilege('anon', 'public.change_temp_password_v1(text,text,text)', 'execute') THEN
    RAISE EXCEPTION 'HOTLINE: còn số cũ hoặc quyền sai';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
