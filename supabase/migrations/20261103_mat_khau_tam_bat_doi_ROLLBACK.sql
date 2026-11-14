-- ============================================================================
-- HOÀN TÁC 20261103_mat_khau_tam_bat_doi.sql — trả nguyên văn verify_user_login_v4 + admin_account_reset_password_v1
-- (bản production trước 26/10), gỡ change_temp_password_v1 + trigger + cột (mật khẩu tạm đang cấp vẫn dùng được, không hết hạn).
-- ============================================================================
BEGIN;
CREATE OR REPLACE FUNCTION public.admin_account_reset_password_v1(p_user uuid, p_reason text, p_checks jsonb, p_report uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_temp'
AS $function$
DECLARE a uuid := public.qn_admin_caller(); v_reason text := btrim(COALESCE(p_reason, '')); v_pw text := ''; i int;
        v_alpha text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF char_length(v_reason) < 5 OR char_length(v_reason) > 500 THEN RETURN jsonb_build_object('ok', false, 'error', 'REASON_REQUIRED'); END IF;
  IF p_checks IS NULL OR (p_checks->>'callback') IS DISTINCT FROM 'true' OR (p_checks->>'store_info') IS DISTINCT FROM 'true'
     OR (p_checks->>'secret') IS DISTINCT FROM 'true' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'CHECKS_REQUIRED');
  END IF;
  IF (SELECT count(*) FROM public.support_actions WHERE admin_id = a AND created_at > now() - interval '1 hour') >= 20 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'TOO_MANY');
  END IF;
  PERFORM 1 FROM public.user_accounts WHERE id = p_user FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND'); END IF;
  FOR i IN 1..10 LOOP
    v_pw := v_pw || substr(v_alpha, 1 + (get_byte(gen_random_bytes(1), 0) % length(v_alpha)), 1);
  END LOOP;
  UPDATE public.user_accounts SET password_hash = crypt(v_pw, gen_salt('bf', 12)) WHERE id = p_user;
  -- thu hồi vé làm mới cho MỌI kiểu mật khẩu cũ (trigger sẵn có chỉ chạy khi mật khẩu cũ là bcrypt — QC 29/10).
  -- Giới hạn còn lại: vé đang dùng (access token) sống tới 30 ngày, chưa bị đá ngay.
  UPDATE public.pos_refresh_tokens SET revoked_at = now(), revoke_reason = 'admin_temp_password'
   WHERE user_id = p_user AND revoked_at IS NULL;
  INSERT INTO public.support_actions (admin_id, target_user, action, reason, checks, report_id)
  VALUES (a, p_user, 'temp_password', v_reason, p_checks, p_report);
  RETURN jsonb_build_object('ok', true, 'temp_password', v_pw);
END
$function$;

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

  SELECT ua.id, ua.phone, ua.display_name, ua.password_hash
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

DROP FUNCTION IF EXISTS public.change_temp_password_v1(text, text, text);
DROP TRIGGER IF EXISTS qn_user_accounts_clear_temp_password ON public.user_accounts;
DROP FUNCTION IF EXISTS public.qn_user_accounts_clear_temp_password();
ALTER TABLE public.user_accounts DROP COLUMN IF EXISTS temp_password_expires_at;
COMMIT;
NOTIFY pgrst, 'reload schema';
