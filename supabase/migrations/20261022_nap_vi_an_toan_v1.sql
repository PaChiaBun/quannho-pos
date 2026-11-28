-- ============================================================================
-- NẠP VÍ AN TOÀN (22/10/2026) — P0-1 trong .docs/Huong_dan/viec-can-sua.md
-- Lỗi cũ (LoyaltyRepository.topUpWallet, client):
--   * đọc số dư → cộng → ghi lại ở client: 2 máy nạp cùng lúc mất 1 lần nạp; bấm lại khi
--     mạng chập chờn nạp 2 lần;
--   * bonus do client tự tính rồi gửi lên → sửa app/gọi API là tặng bonus tuỳ ý;
--   * không kiểm quyền thu tiền; khoản thu luôn vào quỹ Tiền mặt.
-- Sửa: RPC topup_customer_wallet_v1 — một transaction, khoá dòng khách (FOR UPDATE),
--   kiểm quyền thu tiền (qr_staff_ctx_v4 need_checkout), tính bonus ở máy chủ từ
--   topup_packages, chống trùng theo p_idempotency_key (bảng wallet_topup_operations),
--   ghi customers + balance_transactions + finance_records (đúng quỹ cash/bank).
-- KHÔNG chặn ghi trực tiếp từ client cũ ở đợt này (app ≤ 1.0.5+20 vẫn nạp kiểu cũ cho tới
--   khi cập nhật) — đợt sau thêm trigger chặn sửa real_balance/bonus_balance từ client.
-- Rollback: 20261022_nap_vi_an_toan_v1_ROLLBACK.sql
-- ============================================================================

DO $pf$
BEGIN
  IF to_regprocedure('public.qr_staff_ctx_v4(uuid,boolean,boolean)') IS NULL
     OR to_regprocedure('public.qr_err_v4(text,text)') IS NULL THEN
    RAISE EXCEPTION 'PREFLIGHT: thiếu qr_staff_ctx_v4 / qr_err_v4 (cần 20261013_qr_order_simple_v4.sql)';
  END IF;
  IF to_regclass('public.topup_packages') IS NULL OR to_regclass('public.balance_transactions') IS NULL THEN
    RAISE EXCEPTION 'PREFLIGHT: thiếu topup_packages / balance_transactions';
  END IF;
  RAISE NOTICE 'PREFLIGHT nap_vi_an_toan_v1: OK';
END
$pf$;

CREATE TABLE IF NOT EXISTS public.wallet_topup_operations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id        uuid NOT NULL,
  idempotency_key text NOT NULL,
  customer_id     uuid NOT NULL,
  amount          numeric NOT NULL,
  bonus_amount    numeric NOT NULL DEFAULT 0,
  fund_type       text NOT NULL,
  bonus_months    integer,
  actor_user_id   uuid,
  actor_role      text,
  result          jsonb NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (store_id, idempotency_key)
);
ALTER TABLE public.wallet_topup_operations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.wallet_topup_operations FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.wallet_topup_operations TO service_role;

CREATE OR REPLACE FUNCTION public.topup_customer_wallet_v1(
  p_store_id        uuid,
  p_customer_id     uuid,
  p_amount          numeric,
  p_fund_type       text,
  p_idempotency_key text,
  p_bonus_months    integer DEFAULT NULL,
  p_expected_bonus  numeric DEFAULT NULL,
  p_note            text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog, pg_temp
AS $fn$
DECLARE
  v_ctx       jsonb;
  v_uid       uuid;
  v_op        public.wallet_topup_operations%ROWTYPE;
  v_cust      record;
  v_amount    numeric;
  v_pct       numeric := 0;
  v_pkg_name  text;
  v_bonus     numeric := 0;
  v_new_real  numeric;
  v_new_bonus numeric;
  v_expires   text;
  v_now       timestamptz := now();
  v_result    jsonb;
  v_label     text;
BEGIN
  v_ctx := public.qr_staff_ctx_v4(p_store_id, true, false);
  IF NOT COALESCE((v_ctx->>'success')::boolean, false) THEN
    RETURN v_ctx;
  END IF;
  v_uid := NULLIF(v_ctx->>'uid', '')::uuid;

  IF p_idempotency_key IS NULL OR length(btrim(p_idempotency_key)) < 8 OR length(p_idempotency_key) > 120 THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Thiếu mã chống trùng của lần nạp');
  END IF;
  IF p_amount IS NULL OR p_amount <> trunc(p_amount) OR p_amount < 1000 OR p_amount > 100000000 THEN
    RETURN public.qr_err_v4('INVALID_AMOUNT', 'Số tiền nạp phải là số nguyên từ 1.000đ đến 100.000.000đ');
  END IF;
  IF p_fund_type IS NULL OR p_fund_type NOT IN ('cash', 'bank') THEN
    RETURN public.qr_err_v4('INVALID_FUND', 'Quỹ nhận tiền phải là Tiền mặt hoặc Tiền gửi');
  END IF;
  IF p_bonus_months IS NOT NULL AND p_bonus_months NOT IN (0, 6, 12, 24) THEN
    RETURN public.qr_err_v4('INVALID_PAYLOAD', 'Thời hạn bonus không hợp lệ');
  END IF;
  v_amount := p_amount;

  -- Chống trùng: khoá theo (quán, mã) để 2 lần gửi cùng mã không chạy song song.
  PERFORM pg_advisory_xact_lock(hashtext(p_store_id::text), hashtext('wallet_topup:' || p_idempotency_key));
  SELECT * INTO v_op FROM public.wallet_topup_operations
   WHERE store_id = p_store_id AND idempotency_key = p_idempotency_key;
  IF FOUND THEN
    IF v_op.customer_id <> p_customer_id OR v_op.amount <> v_amount OR v_op.fund_type <> p_fund_type THEN
      RETURN public.qr_err_v4('IDEMPOTENCY_CONFLICT', 'Mã chống trùng đã dùng cho một lần nạp khác');
    END IF;
    RETURN jsonb_set(v_op.result, '{data,is_replay}', 'true'::jsonb);
  END IF;

  SELECT id, name, COALESCE(real_balance, 0) AS real_balance, COALESCE(bonus_balance, 0) AS bonus_balance,
         COALESCE(total_topup, 0) AS total_topup
    INTO v_cust
    FROM public.customers
   WHERE id = p_customer_id AND store_id = p_store_id AND COALESCE(is_deleted, false) = false
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN public.qr_err_v4('CUSTOMER_NOT_FOUND', 'Không tìm thấy khách hàng trong quán');
  END IF;

  -- Bonus tính ở máy chủ: gói đang bật có min_amount cao nhất mà vẫn ≤ số tiền nạp.
  SELECT bonus_pct, name INTO v_pct, v_pkg_name
    FROM public.topup_packages
   WHERE store_id = p_store_id AND is_active AND min_amount <= v_amount
   ORDER BY min_amount DESC, bonus_pct DESC
   LIMIT 1;
  v_pct := COALESCE(v_pct, 0);
  IF v_pct < 0 OR v_pct > 100 THEN v_pct := 0; END IF;
  v_bonus := floor(v_amount * v_pct / 100);

  IF p_expected_bonus IS NOT NULL AND p_expected_bonus <> v_bonus THEN
    RETURN public.qr_err_v4('QUOTE_CHANGED',
      format('Gói nạp vừa thay đổi: bonus đúng là %sđ. Mở lại màn nạp để xem số mới.', v_bonus));
  END IF;

  v_new_real  := v_cust.real_balance + v_amount;
  v_new_bonus := v_cust.bonus_balance + v_bonus;
  IF COALESCE(p_bonus_months, 0) > 0 THEN
    v_expires := to_char((v_now + make_interval(days => p_bonus_months * 30)) AT TIME ZONE 'UTC',
                         'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  END IF;

  UPDATE public.customers
     SET real_balance  = v_new_real,
         bonus_balance = v_new_bonus,
         total_topup   = v_cust.total_topup + v_amount,
         bonus_expires_at = COALESCE(v_expires, bonus_expires_at),
         updated_at    = v_now
   WHERE id = p_customer_id;

  INSERT INTO public.balance_transactions (id, store_id, customer_id, type, amount, balance_after, bonus_after, note, created_at)
  VALUES (gen_random_uuid(), p_store_id, p_customer_id, 'topup_real', v_amount, v_new_real, v_new_bonus,
          COALESCE(NULLIF(btrim(p_note), ''), 'Nạp tiền'), v_now);
  IF v_bonus > 0 THEN
    INSERT INTO public.balance_transactions (id, store_id, customer_id, type, amount, balance_after, bonus_after, note, created_at)
    VALUES (gen_random_uuid(), p_store_id, p_customer_id, 'topup_bonus', v_bonus, v_new_real, v_new_bonus,
            'Thưởng +' || v_bonus::bigint || 'đ' || COALESCE(' (' || v_pkg_name || ')', ''), v_now);
  END IF;

  v_label := COALESCE(NULLIF(btrim(v_cust.name), ''), 'Khách hàng');
  INSERT INTO public.finance_records (id, store_id, type, amount, description, reference_id, is_auto, recorded_at, fund_type)
  VALUES (gen_random_uuid(), p_store_id, 'income', v_amount,
          'Nạp ví: ' || v_label || CASE WHEN v_bonus > 0 THEN ' (tặng thêm ' || v_bonus::bigint || 'đ bonus)' ELSE '' END,
          p_customer_id, true, v_now, p_fund_type);

  v_result := jsonb_build_object('success', true, 'data', jsonb_build_object(
    'customer_id', p_customer_id,
    'amount', v_amount,
    'bonus_amount', v_bonus,
    'package_name', v_pkg_name,
    'real_balance', v_new_real,
    'bonus_balance', v_new_bonus,
    'fund_type', p_fund_type,
    'is_replay', false
  ));

  INSERT INTO public.wallet_topup_operations
    (store_id, idempotency_key, customer_id, amount, bonus_amount, fund_type, bonus_months, actor_user_id, actor_role, result)
  VALUES
    (p_store_id, p_idempotency_key, p_customer_id, v_amount, v_bonus, p_fund_type, p_bonus_months, v_uid, v_ctx->>'role', v_result);

  RETURN v_result;
END
$fn$;

REVOKE ALL ON FUNCTION public.topup_customer_wallet_v1(uuid, uuid, numeric, text, text, integer, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.topup_customer_wallet_v1(uuid, uuid, numeric, text, text, integer, numeric, text)
  TO anon, authenticated, service_role;

DO $chk$
BEGIN
  IF to_regprocedure('public.topup_customer_wallet_v1(uuid,uuid,numeric,text,text,integer,numeric,text)') IS NULL THEN
    RAISE EXCEPTION 'POSTCHECK: thiếu topup_customer_wallet_v1';
  END IF;
  RAISE NOTICE 'POSTCHECK nap_vi_an_toan_v1: OK';
END
$chk$;
