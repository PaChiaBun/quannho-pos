-- ============================================================================
-- QR GỌI MÓN — CHỐNG BỊ PHÁ (14/10/2026). Hoàn tác: rollback_qr_chong_pha_v4.sql
--
-- Bối cảnh: mã QR công khai, ai chụp lại cũng có thể viết công cụ tự động gửi đơn liên tục.
--   Đơn chưa vào bếp/kho/tiền cho tới khi nhân viên duyệt, nhưng giới hạn cũ tính theo kênh nên
--   kẻ phá làm đầy hàng chờ và chặn luôn khách thật.
--
-- Lớp 1  Giới hạn theo IP: nginx gắn IP thật vào header x-qn-client-ip (khách không giả được);
--        hàm gửi đơn băm IP (SHA-256 + muối bí mật) rồi giới hạn: 12 lượt/phút, 60 lượt/giờ,
--        10 đơn chờ / IP. Không lưu IP gốc.
-- Lớp 2  Tự khoá: >= 100 lượt gửi trong 60 giây trên một kênh => kênh bị khoá (is_active=false,
--        locked_at, locked_reason='flood'), ghi qr_audit_logs. Khách thấy thông báo gọi nhân viên.
--        Nhân viên thấy cảnh báo và phải "Tạo mã QR mới" (rotate_qr_channel_v4) — mã cũ (đang nằm
--        trong tay kẻ phá) bị vô hiệu. Không cho bật lại bằng mã cũ.
-- Lớp 3  Vé xác minh người thật (Cloudflare Turnstile): bật bằng qr_security_config.require_ticket.
--        Cổng cấp token xác minh Turnstile rồi cấp vé HMAC gắn với mã kênh + khoá chống trùng + hạn;
--        hàm gửi đơn kiểm vé. Mỗi đơn cần một vé mới.
-- Cấu hình (bảng qr_security_config, chỉ service/admin đọc): require_ticket, turnstile_site_key,
--        ticket_secret, ip_salt, flood_per_min, ip_per_min, ip_pending, ip_per_hour.
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS public.qr_security_config (
  key text PRIMARY KEY,
  value text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.qr_security_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.qr_security_config FROM PUBLIC, anon, authenticated;

INSERT INTO public.qr_security_config (key, value) VALUES
  ('require_ticket', 'false'),
  ('turnstile_site_key', ''),
  ('ticket_secret', encode(gen_random_bytes(32), 'hex')),
  ('ip_salt', encode(gen_random_bytes(16), 'hex')),
  ('flood_per_min', '100'),
  ('ip_per_min', '12'),
  ('ip_pending', '10'),
  ('ip_per_hour', '60')
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.qr_submit_attempts (
  id bigserial PRIMARY KEY,
  at timestamptz NOT NULL DEFAULT now(),
  channel_id uuid NOT NULL,
  store_id uuid,
  ip_hash text
);
CREATE INDEX IF NOT EXISTS idx_qr_attempts_channel_at ON public.qr_submit_attempts (channel_id, at DESC);
CREATE INDEX IF NOT EXISTS idx_qr_attempts_ip_at ON public.qr_submit_attempts (ip_hash, at DESC) WHERE ip_hash IS NOT NULL;
ALTER TABLE public.qr_submit_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.qr_submit_attempts FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.qr_submit_attempts_id_seq FROM PUBLIC, anon, authenticated;

ALTER TABLE public.qr_channels ADD COLUMN IF NOT EXISTS locked_at timestamptz;
ALTER TABLE public.qr_channels ADD COLUMN IF NOT EXISTS locked_reason text;
ALTER TABLE public.qr_requests ADD COLUMN IF NOT EXISTS ip_hash text;
CREATE INDEX IF NOT EXISTS idx_qr_requests_iphash_status ON public.qr_requests (ip_hash, status) WHERE ip_hash IS NOT NULL;

-- Đọc cấu hình (SECURITY DEFINER; không cấp cho anon/authenticated)
CREATE OR REPLACE FUNCTION public.qr_cfg_v4(p_key text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$ SELECT value FROM public.qr_security_config WHERE key = p_key $fn$;

-- Băm IP khách (header do nginx gắn). NULL nếu không có header.
CREATE OR REPLACE FUNCTION public.qr_client_ip_hash_v4()
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_h json;
  v_ip text;
BEGIN
  BEGIN
    v_h := NULLIF(current_setting('request.headers', true), '')::json;
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;
  v_ip := btrim(COALESCE(v_h->>'x-qn-client-ip', ''));
  IF v_ip = '' OR char_length(v_ip) > 64 THEN RETURN NULL; END IF;
  RETURN encode(digest(COALESCE(public.qr_cfg_v4('ip_salt'), '') || v_ip, 'sha256'), 'hex');
END
$fn$;

-- Kiểm vé: "<hết hạn epoch>.<hmac hex>", hmac = HMAC-SHA256(secret, channel_code|exp|idempotency_key)
CREATE OR REPLACE FUNCTION public.qr_verify_ticket_v4(p_channel_code text, p_key text, p_ticket text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_exp bigint;
  v_sig text;
  v_now bigint := extract(epoch FROM now())::bigint;
BEGIN
  IF p_ticket IS NULL OR p_ticket !~ '^[0-9]{9,12}\.[0-9a-f]{64}$' THEN RETURN false; END IF;
  v_exp := split_part(p_ticket, '.', 1)::bigint;
  v_sig := split_part(p_ticket, '.', 2);
  IF v_exp < v_now OR v_exp > v_now + 900 THEN RETURN false; END IF;
  RETURN v_sig = encode(
    hmac(convert_to(btrim(p_channel_code) || '|' || v_exp::text || '|' || btrim(p_key), 'UTF8'),
         convert_to(COALESCE(public.qr_cfg_v4('ticket_secret'), ''), 'UTF8'), 'sha256'), 'hex');
END
$fn$;

REVOKE ALL ON FUNCTION public.qr_cfg_v4(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.qr_client_ip_hash_v4() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.qr_verify_ticket_v4(text, text, text) FROM PUBLIC, anon, authenticated;

-- Hàm gửi đơn đổi chữ ký (thêm p_ticket): bỏ bản cũ để PostgREST không bị nhập nhằng.
DROP FUNCTION IF EXISTS public.submit_qr_order_v4(text, jsonb, text, text, text);

CREATE OR REPLACE FUNCTION public.submit_qr_order_v4(
  p_channel_code text,
  p_items jsonb,
  p_table_id text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL,
  p_payload_hash text DEFAULT NULL,
  p_ticket text DEFAULT NULL
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
  v_iph text;
  v_flood integer;
  v_ip_min integer;
  v_ip_pend integer;
  v_ip_hour integer;
  v_cnt integer;
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
    IF EXISTS (SELECT 1 FROM public.qr_channels WHERE channel_code = btrim(p_channel_code) AND locked_at IS NOT NULL) THEN
      RETURN public.qr_err_v4('CHANNEL_LOCKED', 'Quán tạm ngừng nhận đơn qua mã QR này do có lượt quét bất thường. Vui lòng gọi nhân viên để được hỗ trợ.');
    END IF;
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

  -- ── CHỐNG PHÁ (lớp 1-3) ────────────────────────────────────────────────────
  -- Lớp 3: vé xác minh người thật (Cloudflare Turnstile) — chỉ bắt buộc khi quán bật require_ticket.
  IF public.qr_cfg_v4('require_ticket') = 'true' THEN
    IF NOT public.qr_verify_ticket_v4(v_ch.channel_code, v_key, p_ticket) THEN
      RETURN public.qr_err_v4('TICKET_INVALID', 'Cần xác minh bạn là người thật. Vui lòng tải lại trang rồi thử gửi lại.');
    END IF;
  END IF;

  -- Ghi nhận lượt gửi (kể cả lượt bị từ chối) để đếm theo kênh và theo IP.
  v_iph := public.qr_client_ip_hash_v4();
  INSERT INTO public.qr_submit_attempts (channel_id, store_id, ip_hash) VALUES (v_ch.id, v_ch.store_id, v_iph);
  IF random() < 0.01 THEN
    DELETE FROM public.qr_submit_attempts WHERE at < now() - interval '2 days';
  END IF;

  -- Lớp 2: quá nhiều lượt trong 1 phút (mặc định 100) => tạm khoá kênh, nhân viên sẽ thấy cảnh báo.
  v_flood := COALESCE(NULLIF(public.qr_cfg_v4('flood_per_min'), '')::integer, 100);
  SELECT count(*) INTO v_cnt FROM public.qr_submit_attempts a
   WHERE a.channel_id = v_ch.id AND a.at > now() - interval '60 seconds';
  IF v_cnt >= v_flood THEN
    UPDATE public.qr_channels SET is_active = false, locked_at = now(), locked_reason = 'flood'
     WHERE id = v_ch.id AND locked_at IS NULL;
    IF FOUND THEN
      INSERT INTO public.qr_audit_logs (store_id, request_id, action, actor_user_id, details)
      VALUES (v_ch.store_id, NULL, 'channel_locked_flood', NULL,
              jsonb_build_object('channel_id', v_ch.id, 'type', v_ch.type, 'attempts_last_minute', v_cnt));
    END IF;
    RETURN public.qr_err_v4('CHANNEL_LOCKED', 'Quán tạm ngừng nhận đơn qua mã QR này do có lượt quét bất thường. Vui lòng gọi nhân viên để được hỗ trợ.');
  END IF;

  -- Lớp 1: giới hạn theo IP (nginx gắn IP thật của khách; thiếu IP thì bỏ qua lớp này).
  IF v_iph IS NOT NULL THEN
    v_ip_min  := COALESCE(NULLIF(public.qr_cfg_v4('ip_per_min'), '')::integer, 12);
    v_ip_pend := COALESCE(NULLIF(public.qr_cfg_v4('ip_pending'), '')::integer, 10);
    v_ip_hour := COALESCE(NULLIF(public.qr_cfg_v4('ip_per_hour'), '')::integer, 60);
    IF (SELECT count(*) FROM public.qr_submit_attempts a
         WHERE a.ip_hash = v_iph AND a.at > now() - interval '60 seconds') > v_ip_min
       OR (SELECT count(*) FROM public.qr_submit_attempts a
            WHERE a.ip_hash = v_iph AND a.at > now() - interval '1 hour') > v_ip_hour
       OR (SELECT count(*) FROM public.qr_requests r
            WHERE r.ip_hash = v_iph AND r.status = 'submitted' AND r.expires_at > now()) >= v_ip_pend THEN
      RETURN public.qr_err_v4('RATE_LIMITED', 'Bạn gửi đơn quá nhanh, vui lòng thử lại sau ít phút');
    END IF;
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
    total_amount, original_items, expires_at, ip_hash
  ) VALUES (
    v_req_id, v_ch.store_id, v_ch.id, v_ch.type, v_table_id, v_table_name, v_date, v_seq, v_code,
    v_token, v_key, v_hash, 'submitted', 'unpaid',
    (v_price->>'total')::numeric, v_price->'items', v_expires, v_iph
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
    IF EXISTS (SELECT 1 FROM public.qr_channels WHERE channel_code = btrim(p_channel_code) AND locked_at IS NOT NULL) THEN
      RETURN public.qr_err_v4('CHANNEL_LOCKED', 'Quán tạm ngừng nhận đơn qua mã QR này do có lượt quét bất thường. Vui lòng gọi nhân viên để được hỗ trợ.');
    END IF;
    RETURN public.qr_err_v4('CHANNEL_DISABLED', 'Kênh gọi món này hiện đang tạm đóng hoặc không tồn tại');
  END IF;
  SELECT s.name INTO v_store_name FROM public.stores s WHERE s.id = v_ch.store_id;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'id', v_ch.id, 'channel_id', v_ch.id, 'store_id', v_ch.store_id,
    'store_name', COALESCE(v_store_name, 'Quán Nhỏ'),
    'type', v_ch.type, 'channel_code', v_ch.channel_code, 'name', v_ch.name,
    'payment_mode', v_ch.payment_mode, 'is_active', v_ch.is_active, 'created_at', v_ch.created_at,
    'require_ticket', (public.qr_cfg_v4('require_ticket') = 'true'),
    'turnstile_site_key', COALESCE(public.qr_cfg_v4('turnstile_site_key'), '')));
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
    IF v_ch.locked_at IS NOT NULL AND COALESCE(p_is_active, true) THEN
      RETURN public.qr_err_v4('LOCKED_NEEDS_NEW_CODE',
        'Kênh QR đang bị khoá do có người quét phá. Hãy bấm "Tạo mã QR mới" rồi in lại mã, không bật lại mã cũ.');
    END IF;
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
    'created_at', v_ch.created_at, 'locked_at', v_ch.locked_at, 'locked_reason', v_ch.locked_reason));
END
$fn$;

REVOKE ALL ON FUNCTION public.submit_qr_order_v4(text, jsonb, text, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_qr_order_v4(text, jsonb, text, text, text, text) TO anon, authenticated;
REVOKE ALL ON FUNCTION public.get_qr_channel_info_v4(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_qr_channel_info_v4(text) TO anon, authenticated;
REVOKE ALL ON FUNCTION public.manage_qr_channel_v4(uuid, text, boolean, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.manage_qr_channel_v4(uuid, text, boolean, text) TO authenticated;

-- Nhân viên (cần quyền quản lý QR): tạo mã QR mới cho kênh — mã cũ vô hiệu, mở khoá kênh.
CREATE OR REPLACE FUNCTION public.rotate_qr_channel_v4(p_store_id uuid, p_type text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ctx jsonb;
  v_type text;
  v_ch public.qr_channels%ROWTYPE;
  v_code text;
  v_tries integer := 0;
  v_old text;
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

  PERFORM pg_advisory_xact_lock(hashtext('qr_manage_channel:' || p_store_id::text), hashtext(v_type));
  SELECT * INTO v_ch FROM public.qr_channels WHERE store_id = p_store_id AND type = v_type;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('CHANNEL_DISABLED', 'Quán chưa có kênh QR này');
  END IF;
  v_old := v_ch.channel_code;

  LOOP
    v_code := CASE WHEN v_type = 'TABLE_SHARED' THEN 'TBL' ELSE 'CTR' END
              || '_' || upper(encode(gen_random_bytes(6), 'hex'));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.qr_channels WHERE channel_code = v_code);
    v_tries := v_tries + 1;
    IF v_tries > 10 THEN
      RAISE EXCEPTION 'QR_CHANNEL_CODE_FAIL: không sinh được mã kênh duy nhất';
    END IF;
  END LOOP;

  UPDATE public.qr_channels
     SET channel_code = v_code, is_active = true, locked_at = NULL, locked_reason = NULL
   WHERE id = v_ch.id
   RETURNING * INTO v_ch;

  -- Đơn đang chờ từ mã cũ (nếu có) hết hạn ngay để không lẫn vào hàng chờ mới.
  UPDATE public.qr_requests
     SET status = 'expired', version = version + 1, updated_at = now()
   WHERE channel_id = v_ch.id AND status = 'submitted';

  INSERT INTO public.qr_audit_logs (store_id, request_id, action, actor_user_id, details)
  VALUES (p_store_id, NULL, 'rotate_channel', (v_ctx->>'uid')::uuid,
          jsonb_build_object('type', v_type, 'channel_id', v_ch.id, 'old_code_prefix', left(v_old, 8)));

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'id', v_ch.id, 'store_id', v_ch.store_id, 'type', v_ch.type, 'channel_code', v_ch.channel_code,
    'name', v_ch.name, 'is_active', v_ch.is_active, 'payment_mode', v_ch.payment_mode,
    'created_at', v_ch.created_at, 'locked_at', v_ch.locked_at, 'locked_reason', v_ch.locked_reason));
END
$fn$;
REVOKE ALL ON FUNCTION public.rotate_qr_channel_v4(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rotate_qr_channel_v4(uuid, text) TO authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
