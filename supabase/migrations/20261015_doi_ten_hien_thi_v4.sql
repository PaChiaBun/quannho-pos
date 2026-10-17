-- Cho người dùng tự đổi tên hiển thị của chính mình.
-- Bảng user_accounts không cấp quyền UPDATE trực tiếp cho anon/authenticated (chỉ có policy),
-- nên đi qua hàm SECURITY DEFINER; định danh lấy từ qn_caller_id() (JWT hoặc header x-user-id).
-- Chỉ sửa cột display_name của chính người gọi. Không đụng tới quyền/vai trò.
CREATE OR REPLACE FUNCTION public.update_my_display_name_v4(p_display_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid  uuid := public.qn_caller_id();
  v_name text := btrim(regexp_replace(COALESCE(p_display_name, ''), '\s+', ' ', 'g'));
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'status', 401,
      'error_code', 'UNAUTHORIZED', 'message', 'Chưa xác thực phiên đăng nhập');
  END IF;
  IF char_length(v_name) < 2 OR char_length(v_name) > 50 THEN
    RETURN jsonb_build_object('success', false, 'status', 400,
      'error_code', 'INVALID_NAME', 'message', 'Tên hiển thị phải từ 2 đến 50 ký tự');
  END IF;

  UPDATE public.user_accounts SET display_name = v_name WHERE id = v_uid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'status', 404,
      'error_code', 'NOT_FOUND', 'message', 'Không tìm thấy tài khoản');
  END IF;

  RETURN jsonb_build_object('success', true, 'status', 200,
    'display_name', v_name, 'message', 'Đã đổi tên hiển thị');
END;
$function$;

REVOKE ALL ON FUNCTION public.update_my_display_name_v4(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_my_display_name_v4(text) TO anon, authenticated, service_role;
