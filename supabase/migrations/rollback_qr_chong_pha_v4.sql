-- ROLLBACK cho 20261014_qr_chong_pha_v4.sql
-- Khôi phục 3 hàm về bản 20261013 (không có chống phá), bỏ bảng/cột/hàm mới.
-- Cảnh báo: bảng qr_submit_attempts và cấu hình qr_security_config bị xoá. Mã QR đã xoay giữ nguyên mã mới.
BEGIN;
DROP FUNCTION IF EXISTS public.rotate_qr_channel_v4(uuid, text);
DROP FUNCTION IF EXISTS public.submit_qr_order_v4(text, jsonb, text, text, text, text);

CREATE OR REPLACE FUNCTION public.submit_qr_order_v4(
  p_channel_code text,
  p_items jsonb,
  p_table_id text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL,
  p_payload_hash text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  -- Giới hạn tần suất theo KÊNH (anon không có IP): chỉnh tại đây nếu cần
  c_max_unclaimed   constant integer := 40;  -- đơn submitted chưa nhận, chưa hết hạn / kênh
  c_max_per_minute  constant integer := 15;  -- đơn tạo trong 60 giây / kênh
  c_max_per_table   constant integer := 5;   -- đơn submitted chưa nhận / một bàn
  v_ch public.qr_channels%ROWTYPE;
  v_ex public.qr_requests%ROWTYPE;
  v_tbl record;
  v_price jsonb;
  v_key text;
  v_hash text;
  v_table_id text := NULL;
  v_table_name text := NULL;
  v_req_id uuid := gen_random_uuid();
  v_token text;
  v_date date := NULL;
  v_seq integer := NULL;
  v_code text := NULL;
  v_expires timestamptz := now() + interval '60 minutes';
  v_item jsonb;
BEGIN
  v_key := btrim(COALESCE(p_idempotency_key, ''));
  IF char_length(v_key) < 8 OR char_length(v_key) > 128 THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Khóa chống trùng (idempotency key) phải dài 8-128 ký tự');
  END IF;
  v_hash := NULLIF(lower(btrim(COALESCE(p_payload_hash, ''))), '');
  IF v_hash IS NOT NULL AND v_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Payload hash phải là SHA-256 hex (64 ký tự)');
  END IF;
  IF p_channel_code IS NULL OR char_length(p_channel_code) > 64 THEN
    RETURN public.qr_err_v4('INVALID_QR', 'Mã QR không hợp lệ');
  END IF;

  SELECT * INTO v_ch FROM public.qr_channels WHERE channel_code = btrim(p_channel_code) AND is_active;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('CHANNEL_DISABLED', 'Kênh gọi món này hiện đang tạm đóng');
  END IF;

  -- Thứ tự khóa cố định (khóa key -> khóa kênh) để không deadlock
  PERFORM pg_advisory_xact_lock(hashtext('qr_submit:' || v_ch.store_id::text), hashtext(v_key));

  -- Idempotency: cùng key trả lại đúng đơn cũ
  SELECT * INTO v_ex FROM public.qr_requests WHERE store_id = v_ch.store_id AND idempotency_key = v_key;
  IF FOUND THEN
    IF v_ex.channel_id <> v_ch.id
       OR (v_hash IS NOT NULL AND v_ex.payload_hash IS NOT NULL AND v_ex.payload_hash <> v_hash) THEN
      RETURN public.qr_err_v4('IDEMPOTENCY_CONFLICT', 'Khóa chống trùng đã dùng cho nội dung khác');
    END IF;
    RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
      'request_id', v_ex.id, 'tracking_token', v_ex.tracking_token, 'status', v_ex.status,
      'pickup_code', v_ex.pickup_code, 'table_id', v_ex.table_id, 'table_name', v_ex.table_name,
      'total_amount', v_ex.total_amount, 'expires_at', v_ex.expires_at, 'is_replay', true));
  END IF;

  -- Bàn (chỉ TABLE_SHARED): phải thuộc ĐÚNG quán của kênh
  IF v_ch.type = 'TABLE_SHARED' THEN
    v_table_id := btrim(COALESCE(p_table_id, ''));
    IF v_table_id = '' THEN
      RETURN public.qr_err_v4('TABLE_REQUIRED', 'Vui lòng chọn bàn');
    END IF;
    IF char_length(v_table_id) > 64 THEN
      RETURN public.qr_err_v4('TABLE_NOT_FOUND', 'Bàn không tồn tại');
    END IF;
    SELECT * INTO v_tbl FROM public.qr_table_info_v4(v_ch.store_id, v_table_id);
    IF NOT FOUND OR NOT v_tbl.t_active THEN
      RETURN public.qr_err_v4('TABLE_NOT_FOUND', 'Bàn không tồn tại hoặc đã ngừng sử dụng');
    END IF;
    v_table_id := v_tbl.t_id;
    v_table_name := v_tbl.t_name;
  END IF;

  -- Giới hạn tần suất theo kênh (khóa kênh để đếm nhất quán giữa các key khác nhau)
  PERFORM pg_advisory_xact_lock(hashtext('qr_channel'), hashtext(v_ch.id::text));
  IF (SELECT count(*) FROM public.qr_requests r
      WHERE r.channel_id = v_ch.id AND r.status = 'submitted' AND r.expires_at > now()) >= c_max_unclaimed
     OR (SELECT count(*) FROM public.qr_requests r
         WHERE r.channel_id = v_ch.id AND r.created_at > now() - interval '60 seconds') >= c_max_per_minute
     OR (v_table_id IS NOT NULL AND (SELECT count(*) FROM public.qr_requests r
         WHERE r.channel_id = v_ch.id AND r.table_id = v_table_id AND r.status = 'submitted'
           AND r.expires_at > now()) >= c_max_per_table) THEN
    RETURN public.qr_err_v4('RATE_LIMITED', 'Quán đang nhận quá nhiều đơn, vui lòng thử lại sau ít phút');
  END IF;

  v_price := public.qr_price_items_v4(v_ch.store_id, p_items);
  IF NOT (v_price->>'success')::boolean THEN RETURN v_price; END IF;

  -- Mã nhận món theo ngày của quán (không giới hạn 99)
  IF v_ch.type = 'COUNTER_TAKEAWAY' THEN
    v_date := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
    INSERT INTO public.qr_pickup_counters AS c (store_id, pickup_date, last_seq)
    VALUES (v_ch.store_id, v_date, 1)
    ON CONFLICT (store_id, pickup_date) DO UPDATE SET last_seq = c.last_seq + 1
    RETURNING c.last_seq INTO v_seq;
    -- lpad() CẮT chuỗi dài hơn độ rộng (lpad('100',2,'0') = '10'), nên chỉ đệm số 0 khi < 10.
    v_code := '#Q' || CASE WHEN v_seq < 10 THEN '0' || v_seq::text ELSE v_seq::text END;
  END IF;

  v_token := 'TRK_' || upper(encode(gen_random_bytes(16), 'hex'));

  INSERT INTO public.qr_requests (
    id, store_id, channel_id, type, table_id, table_name, pickup_date, pickup_seq, pickup_code,
    tracking_token, idempotency_key, payload_hash, status, payment_status,
    total_amount, original_items, expires_at
  ) VALUES (
    v_req_id, v_ch.store_id, v_ch.id, v_ch.type, v_table_id, v_table_name, v_date, v_seq, v_code,
    v_token, v_key, v_hash, 'submitted', 'unpaid',
    (v_price->>'total')::numeric, v_price->'items', v_expires
  );

  FOR v_item IN SELECT value FROM jsonb_array_elements(v_price->'items')
  LOOP
    INSERT INTO public.qr_request_items (
      request_id, product_id, product_name, unit_price, quantity, subtotal, modifiers_json, note
    ) VALUES (
      v_req_id, (v_item->>'product_id')::uuid, v_item->>'product_name',
      (v_item->>'unit_price')::numeric, (v_item->>'quantity')::integer,
      (v_item->>'subtotal')::numeric, v_item->'modifiers_json', COALESCE(v_item->>'note', '')
    );
  END LOOP;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'request_id', v_req_id, 'tracking_token', v_token, 'status', 'submitted',
    'pickup_code', v_code, 'table_id', v_table_id, 'table_name', v_table_name,
    'total_amount', (v_price->>'total')::numeric, 'expires_at', v_expires, 'is_replay', false));
END
$fn$;

CREATE OR REPLACE FUNCTION public.get_qr_channel_info_v4(p_channel_code text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ch public.qr_channels%ROWTYPE;
  v_store_name text;
BEGIN
  IF p_channel_code IS NULL OR char_length(p_channel_code) > 64 THEN
    RETURN public.qr_err_v4('INVALID_QR', 'Mã QR không hợp lệ');
  END IF;
  SELECT * INTO v_ch FROM public.qr_channels WHERE channel_code = btrim(p_channel_code) AND is_active;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('CHANNEL_DISABLED', 'Kênh gọi món này hiện đang tạm đóng hoặc không tồn tại');
  END IF;
  SELECT s.name INTO v_store_name FROM public.stores s WHERE s.id = v_ch.store_id;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'id', v_ch.id, 'channel_id', v_ch.id, 'store_id', v_ch.store_id,
    'store_name', COALESCE(v_store_name, 'Quán Nhỏ'),
    'type', v_ch.type, 'channel_code', v_ch.channel_code, 'name', v_ch.name,
    'payment_mode', v_ch.payment_mode, 'is_active', v_ch.is_active, 'created_at', v_ch.created_at));
END
$fn$;

CREATE OR REPLACE FUNCTION public.manage_qr_channel_v4(
  p_store_id uuid, p_type text, p_is_active boolean DEFAULT true, p_payment_mode text DEFAULT 'CASHIER_CONFIRM'
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ctx jsonb;
  v_type text;
  v_mode text;
  v_ch public.qr_channels%ROWTYPE;
  v_code text;
  v_tries integer := 0;
BEGIN
  v_ctx := public.qr_staff_ctx_v4(p_store_id, false, true);
  IF NOT (v_ctx->>'success')::boolean THEN RETURN v_ctx; END IF;

  v_type := CASE upper(btrim(COALESCE(p_type, '')))
              WHEN 'TABLE_SHARED' THEN 'TABLE_SHARED' WHEN 'TABLE' THEN 'TABLE_SHARED'
              WHEN 'COUNTER_TAKEAWAY' THEN 'COUNTER_TAKEAWAY' WHEN 'COUNTER' THEN 'COUNTER_TAKEAWAY'
              ELSE NULL END;
  IF v_type IS NULL THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Loại kênh không hợp lệ');
  END IF;
  v_mode := COALESCE(NULLIF(btrim(p_payment_mode), ''), 'CASHIER_CONFIRM');
  IF v_mode NOT IN ('PAY_BEFORE_KITCHEN', 'CASHIER_CONFIRM') THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Chế độ thanh toán không hợp lệ');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('qr_manage_channel:' || p_store_id::text), hashtext(v_type));

  SELECT * INTO v_ch FROM public.qr_channels WHERE store_id = p_store_id AND type = v_type;
  IF FOUND THEN
    UPDATE public.qr_channels
    SET is_active = COALESCE(p_is_active, true), payment_mode = v_mode
    WHERE id = v_ch.id
    RETURNING * INTO v_ch;
  ELSE
    LOOP
      v_code := CASE WHEN v_type = 'TABLE_SHARED' THEN 'TBL' ELSE 'CTR' END
                || '_' || upper(encode(gen_random_bytes(6), 'hex'));
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.qr_channels WHERE channel_code = v_code);
      v_tries := v_tries + 1;
      IF v_tries > 10 THEN
        RAISE EXCEPTION 'QR_CHANNEL_CODE_FAIL: không sinh được mã kênh duy nhất';
      END IF;
    END LOOP;
    INSERT INTO public.qr_channels (store_id, type, channel_code, name, is_active, payment_mode)
    VALUES (p_store_id, v_type, v_code,
            CASE WHEN v_type = 'TABLE_SHARED' THEN 'QR Dùng Chung Tại Bàn' ELSE 'Quầy Mang Đi' END,
            COALESCE(p_is_active, true), v_mode)
    RETURNING * INTO v_ch;
  END IF;

  INSERT INTO public.qr_audit_logs (store_id, request_id, action, actor_user_id, details)
  VALUES (p_store_id, NULL, 'manage_channel', (v_ctx->>'uid')::uuid,
          jsonb_build_object('type', v_type, 'is_active', v_ch.is_active, 'channel_id', v_ch.id));

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'id', v_ch.id, 'store_id', v_ch.store_id, 'type', v_ch.type, 'channel_code', v_ch.channel_code,
    'name', v_ch.name, 'is_active', v_ch.is_active, 'payment_mode', v_ch.payment_mode,
    'created_at', v_ch.created_at));
END
$fn$;

REVOKE ALL ON FUNCTION public.submit_qr_order_v4(text, jsonb, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_qr_order_v4(text, jsonb, text, text, text) TO anon, authenticated;
REVOKE ALL ON FUNCTION public.get_qr_channel_info_v4(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_qr_channel_info_v4(text) TO anon, authenticated;
REVOKE ALL ON FUNCTION public.manage_qr_channel_v4(uuid, text, boolean, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.manage_qr_channel_v4(uuid, text, boolean, text) TO authenticated;

DROP FUNCTION IF EXISTS public.qr_verify_ticket_v4(text, text, text);
DROP FUNCTION IF EXISTS public.qr_client_ip_hash_v4();
DROP FUNCTION IF EXISTS public.qr_cfg_v4(text);
DROP INDEX IF EXISTS public.idx_qr_requests_iphash_status;
ALTER TABLE public.qr_requests DROP COLUMN IF EXISTS ip_hash;
-- Kênh đang bị khoá: mở lại để quán không mất kênh sau khi hoàn tác
UPDATE public.qr_channels SET is_active = true WHERE locked_at IS NOT NULL;
ALTER TABLE public.qr_channels DROP COLUMN IF EXISTS locked_reason;
ALTER TABLE public.qr_channels DROP COLUMN IF EXISTS locked_at;
DROP TABLE IF EXISTS public.qr_submit_attempts;
DROP TABLE IF EXISTS public.qr_security_config;
COMMIT;
NOTIFY pgrst, 'reload schema';
