-- ============================================================================
-- CỔNG THU PHÍ — ĐỢT A (ke-hoach-cong-thu-phi.md, Chủ Quán chốt 26/10/2026)
--   • billing_plans      — bảng giá (Pro tháng 99.000đ · 6 tháng 499.000đ · năm 899.000đ), sửa trên /admin
--   • billing_orders     — đơn thanh toán của quán: mã chuyển khoản QNxxxxxx (không trùng), số tiền, hết hạn sau 24 giờ
--   • platform_settings  — thêm 'billing_bank' (tài khoản công ty nhận tiền: mã ngân hàng BIN, số TK, tên TK) để app vẽ VietQR
--   • qn_billing_apply_order — gia hạn Pro theo đơn đã trả (dùng chung: đợt A quản trị bấm tay, đợt B SePay tự gọi)
--   • Chủ quán (vé authenticated): billing_info_v1, billing_create_order_v1, billing_order_status_v1
--   • Quản trị (qn_admin): admin_billing_overview_v1, admin_billing_set_bank_v1, admin_billing_set_plan_v1,
--     admin_billing_mark_paid_v1 (xác nhận đã nhận tiền), admin_billing_cancel_order_v1
-- Hết hạn chưa trả: CHỈ NHẮC (không khoá) — Chủ Quán chốt. App iOS / Android KHÔNG hiện giá (chặn ở app).
-- Cần đợt 1 trang quản trị (admin_store_actions, qn_store_plan_snapshot). Hoàn tác: …_ROLLBACK.sql
-- ============================================================================
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.admin_store_actions') IS NULL OR to_regprocedure('public.qn_store_plan_snapshot(public.stores)') IS NULL THEN
    RAISE EXCEPTION 'Cần áp 20261027_quan_tri_dot1_ho_so_goi.sql trước';
  END IF;
END $$;

-- 1) Bảng --------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.billing_plans (
  code       text PRIMARY KEY CHECK (code ~ '^[a-z0-9_]{2,30}$'),
  name       text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 60),
  months     int  NOT NULL CHECK (months BETWEEN 1 AND 36),
  price_vnd  bigint NOT NULL CHECK (price_vnd BETWEEN 1000 AND 100000000),
  active     boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.billing_plans (code, name, months, price_vnd, sort_order) VALUES
  ('pro_1m', 'Pro 1 tháng', 1, 99000, 1),
  ('pro_6m', 'Pro 6 tháng', 6, 499000, 2),
  ('pro_12m', 'Pro 12 tháng', 12, 899000, 3)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.billing_orders (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code        text NOT NULL UNIQUE CHECK (code ~ '^QN[A-Z2-9]{6}$'),
  store_id    uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  plan_code   text NOT NULL REFERENCES public.billing_plans(code),
  plan_name   text NOT NULL,
  months      int  NOT NULL,
  amount_vnd  bigint NOT NULL CHECK (amount_vnd > 0),
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'cancelled')),
  created_by  uuid NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL DEFAULT now() + interval '24 hours',
  paid_at     timestamptz,
  paid_amount_vnd bigint,
  paid_source text CHECK (paid_source IS NULL OR paid_source IN ('admin', 'sepay')),
  paid_by     uuid,
  paid_note   text
);
CREATE INDEX IF NOT EXISTS idx_billing_orders_store ON public.billing_orders (store_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_billing_orders_pending ON public.billing_orders (created_at DESC) WHERE status = 'pending';

ALTER TABLE public.billing_plans  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_orders ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.billing_plans, public.billing_orders FROM PUBLIC, anon, authenticated, qn_admin;
GRANT ALL ON public.billing_plans, public.billing_orders TO service_role;

-- platform_settings: thêm khoá 'billing_bank' (JSON {bin, bank_name, account_no, account_name})
ALTER TABLE public.platform_settings DROP CONSTRAINT IF EXISTS platform_settings_key_check;
ALTER TABLE public.platform_settings ADD CONSTRAINT platform_settings_key_check CHECK (key IN ('plan_contact', 'billing_bank'));

-- nhật ký thao tác: thêm 'payment' (gia hạn Pro do trả tiền)
ALTER TABLE public.admin_store_actions DROP CONSTRAINT IF EXISTS admin_store_actions_action_check;
ALTER TABLE public.admin_store_actions ADD CONSTRAINT admin_store_actions_action_check
  CHECK (action IN ('extend_trial', 'set_plan', 'lock', 'unlock', 'self_extend', 'payment'));

-- 2) Hàm dùng chung --------------------------------------------------------------------------------------------------
-- Trạng thái hiển thị: đơn 'pending' quá hạn 24 giờ → 'expired' (không cần việc chạy nền dọn)
CREATE OR REPLACE FUNCTION public.qn_billing_order_state(o public.billing_orders)
RETURNS text LANGUAGE sql STABLE AS $fn$
  SELECT CASE WHEN o.status = 'pending' AND o.expires_at <= now() THEN 'expired' ELSE o.status END
$fn$;
REVOKE ALL ON FUNCTION public.qn_billing_order_state(public.billing_orders) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.qn_billing_order_json(o public.billing_orders)
RETURNS jsonb LANGUAGE sql STABLE AS $fn$
  SELECT jsonb_build_object('id', o.id, 'code', o.code, 'plan_code', o.plan_code, 'plan_name', o.plan_name,
    'months', o.months, 'amount_vnd', o.amount_vnd, 'status', public.qn_billing_order_state(o),
    'created_at', o.created_at, 'expires_at', o.expires_at, 'paid_at', o.paid_at, 'paid_amount_vnd', o.paid_amount_vnd)
$fn$;
REVOKE ALL ON FUNCTION public.qn_billing_order_json(public.billing_orders) FROM PUBLIC, anon, authenticated;

-- Người gọi là Chủ quán của p_store (vé authenticated thật; KHÔNG tin header x-user-id)
CREATE OR REPLACE FUNCTION public.qn_billing_owner(p_store uuid)
RETURNS uuid
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE u uuid := public.qn_caller_id();
BEGIN
  IF u IS NULL OR p_store IS NULL
     OR NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role' IS DISTINCT FROM 'authenticated' THEN
    RETURN NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM public.stores s WHERE s.id = p_store AND s.owner_user_id = u)
     OR EXISTS (SELECT 1 FROM public.store_members m WHERE m.store_id = p_store AND m.user_id = u AND m.is_owner) THEN
    RETURN u;
  END IF;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END
$fn$;
REVOKE ALL ON FUNCTION public.qn_billing_owner(uuid) FROM PUBLIC, anon, authenticated;

-- Gia hạn Pro theo đơn (MỘT giao dịch): đơn → 'paid'; Pro hết hạn mới = max(bây giờ, hạn Pro còn hiệu lực HOẶC hạn dùng thử
-- còn lại) + số tháng (không mất ngày dùng thử — QC 28/10); quán đang khoá giữ khoá; Pro không thời hạn giữ nguyên.
-- Đơn 'cancelled' / quá 24 giờ VẪN xác nhận được: khách có thể đã chuyển tiền rồi mới tạo đơn khác (QC 28/10).
-- Khoá dòng QUÁN trước rồi mới tới đơn — cùng thứ tự với billing_create_order_v1 (tránh kẹt nhau). Đã trả → ALREADY_PAID.
CREATE OR REPLACE FUNCTION public.qn_billing_apply_order(p_order uuid, p_actor uuid, p_source text, p_amount bigint, p_note text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE o public.billing_orders%ROWTYPE; s public.stores%ROWTYPE; v_before jsonb; v_base timestamptz; v_store uuid;
BEGIN
  IF p_source NOT IN ('admin', 'sepay') OR p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_PARAMS');
  END IF;
  SELECT store_id INTO v_store FROM public.billing_orders WHERE id = p_order;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND'); END IF;
  SELECT * INTO s FROM public.stores WHERE id = v_store FOR UPDATE;
  SELECT * INTO o FROM public.billing_orders WHERE id = p_order FOR UPDATE;
  IF o.status = 'paid' THEN RETURN jsonb_build_object('ok', false, 'error', 'ALREADY_PAID'); END IF;
  -- thiếu tiền: chỉ nhận khi có ghi chú lý do (vd đã thoả thuận) — tránh bấm nhầm gia hạn đủ cho khoản chuyển thiếu
  IF p_amount < o.amount_vnd AND NULLIF(btrim(COALESCE(p_note, '')), '') IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'AMOUNT_SHORT', 'expected', o.amount_vnd);
  END IF;
  v_before := public.qn_store_plan_snapshot(s);
  IF s.plan = 'pro' AND s.plan_ends_at IS NULL THEN
    v_base := NULL; -- Pro không thời hạn: giữ nguyên
  ELSE
    v_base := GREATEST(now(), CASE WHEN s.plan = 'pro' THEN COALESCE(s.plan_ends_at, now())
                                   ELSE COALESCE(s.trial_ends_at, now()) END);
  END IF;
  UPDATE public.stores
     SET plan = 'pro',
         plan_ends_at = CASE WHEN v_base IS NULL THEN NULL ELSE v_base + make_interval(months => o.months) END,
         status = CASE WHEN status = 'locked' THEN status ELSE 'active' END
   WHERE id = o.store_id RETURNING * INTO s;
  UPDATE public.billing_orders
     SET status = 'paid', paid_at = now(), paid_amount_vnd = p_amount, paid_source = p_source, paid_by = p_actor,
         paid_note = NULLIF(btrim(COALESCE(p_note, '')), '')
   WHERE id = o.id RETURNING * INTO o;
  INSERT INTO public.admin_store_actions (store_id, admin_id, action, before, after, amount_vnd, note)
  VALUES (o.store_id, COALESCE(p_actor, o.created_by), 'payment', v_before, public.qn_store_plan_snapshot(s), p_amount,
          left(format('Đơn %s · %s%s', o.code, o.plan_name, COALESCE(' · ' || NULLIF(btrim(COALESCE(p_note, '')), ''), '')), 500));
  RETURN jsonb_build_object('ok', true, 'order', public.qn_billing_order_json(o), 'plan_ends_at', s.plan_ends_at);
END
$fn$;
REVOKE ALL ON FUNCTION public.qn_billing_apply_order(uuid, uuid, text, bigint, text) FROM PUBLIC, anon, authenticated, qn_admin;
GRANT EXECUTE ON FUNCTION public.qn_billing_apply_order(uuid, uuid, text, bigint, text) TO service_role;

-- 3) Chủ quán --------------------------------------------------------------------------------------------------------
-- Màn "Gói & thanh toán": gói hiện tại, bảng giá, tài khoản nhận tiền, đơn đang chờ, 10 đơn gần nhất
CREATE OR REPLACE FUNCTION public.billing_info_v1(p_store uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE s public.stores%ROWTYPE; v_bank jsonb;
BEGIN
  IF public.qn_billing_owner(p_store) IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'OWNER_ONLY'); END IF;
  SELECT * INTO s FROM public.stores WHERE id = p_store;
  BEGIN v_bank := (SELECT value FROM public.platform_settings WHERE key = 'billing_bank')::jsonb;
  EXCEPTION WHEN OTHERS THEN v_bank := NULL; END;
  RETURN jsonb_build_object('ok', true,
    'store', jsonb_build_object('name', s.name, 'plan', s.plan, 'status', s.status, 'trial_ends_at', s.trial_ends_at,
                                'plan_ends_at', s.plan_ends_at),
    'plans', COALESCE((SELECT jsonb_agg(jsonb_build_object('code', p.code, 'name', p.name, 'months', p.months,
                                                           'price_vnd', p.price_vnd) ORDER BY p.sort_order, p.months)
                         FROM public.billing_plans p WHERE p.active), '[]'::jsonb),
    'bank', v_bank,
    'pending', (SELECT public.qn_billing_order_json(o) FROM public.billing_orders o
                 WHERE o.store_id = p_store AND o.status = 'pending' AND o.expires_at > now()
                 ORDER BY o.created_at DESC LIMIT 1),
    'history', COALESCE((SELECT jsonb_agg(public.qn_billing_order_json(h.r) ORDER BY (h.r).created_at DESC) FROM (
                  SELECT o AS r FROM public.billing_orders o WHERE o.store_id = p_store AND o.status = 'paid'
                   ORDER BY o.created_at DESC LIMIT 10) h), '[]'::jsonb));
END
$fn$;

-- Tạo đơn: huỷ đơn đang chờ cũ của quán (vẫn xác nhận được nếu tiền về sau); tối đa 10 đơn / giờ / quán;
-- chưa có tài khoản nhận tiền → BANK_NOT_SET
CREATE OR REPLACE FUNCTION public.billing_create_order_v1(p_store uuid, p_plan text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE u uuid := public.qn_billing_owner(p_store); p public.billing_plans%ROWTYPE; o public.billing_orders%ROWTYPE;
        v_code text; i int; k int; v_alpha text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
BEGIN
  IF u IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'OWNER_ONLY'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.platform_settings WHERE key = 'billing_bank') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BANK_NOT_SET');
  END IF;
  SELECT * INTO p FROM public.billing_plans WHERE code = p_plan AND active;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_PLAN'); END IF;
  -- khoá dòng quán: 2 lần bấm cùng lúc không tạo 2 đơn chờ
  PERFORM 1 FROM public.stores WHERE id = p_store FOR UPDATE;
  IF (SELECT count(*) FROM public.billing_orders WHERE store_id = p_store AND created_at > now() - interval '1 hour') >= 10 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'TOO_MANY');
  END IF;
  UPDATE public.billing_orders SET status = 'cancelled' WHERE store_id = p_store AND status = 'pending';
  FOR k IN 1..20 LOOP
    v_code := 'QN';
    FOR i IN 1..6 LOOP
      v_code := v_code || substr(v_alpha, 1 + floor(random() * length(v_alpha))::int, 1);
    END LOOP;
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.billing_orders WHERE code = v_code);
    v_code := NULL;
  END LOOP;
  IF v_code IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'TRY_AGAIN'); END IF;
  INSERT INTO public.billing_orders (code, store_id, plan_code, plan_name, months, amount_vnd, created_by)
  VALUES (v_code, p_store, p.code, p.name, p.months, p.price_vnd, u) RETURNING * INTO o;
  RETURN jsonb_build_object('ok', true, 'order', public.qn_billing_order_json(o));
END
$fn$;

CREATE OR REPLACE FUNCTION public.billing_order_status_v1(p_order uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE o public.billing_orders%ROWTYPE;
BEGIN
  SELECT * INTO o FROM public.billing_orders WHERE id = p_order;
  IF NOT FOUND OR public.qn_billing_owner(o.store_id) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND');
  END IF;
  RETURN jsonb_build_object('ok', true, 'order', public.qn_billing_order_json(o),
    'plan_ends_at', (SELECT plan_ends_at FROM public.stores WHERE id = o.store_id));
END
$fn$;

REVOKE ALL ON FUNCTION public.billing_info_v1(uuid), public.billing_create_order_v1(uuid, text),
  public.billing_order_status_v1(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.billing_info_v1(uuid), public.billing_create_order_v1(uuid, text),
  public.billing_order_status_v1(uuid) TO authenticated;

-- 4) Quản trị --------------------------------------------------------------------------------------------------------
-- p_filter: pending (đang chờ, chưa quá 24 giờ) | paid | all
CREATE OR REPLACE FUNCTION public.admin_billing_overview_v1(p_filter text DEFAULT 'pending', p_search text DEFAULT NULL,
                                                           p_limit int DEFAULT 50, p_offset int DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_lim int := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
  v_off int := GREATEST(COALESCE(p_offset, 0), 0);
  v_q text := upper(NULLIF(btrim(COALESCE(p_search, '')), ''));
  v_f text := COALESCE(p_filter, 'pending');
  v_bank jsonb; r jsonb;
BEGIN
  IF public.qn_admin_caller() IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF v_f NOT IN ('pending', 'paid', 'all') THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_FILTER'); END IF;
  BEGIN v_bank := (SELECT value FROM public.platform_settings WHERE key = 'billing_bank')::jsonb;
  EXCEPTION WHEN OTHERS THEN v_bank := NULL; END;
  WITH f AS (
    SELECT o AS r, o.created_at, st.name AS store_name, st.store_code
      FROM public.billing_orders o JOIN public.stores st ON st.id = o.store_id
     WHERE CASE v_f WHEN 'pending' THEN o.status = 'pending' AND o.expires_at > now()
                    WHEN 'paid' THEN o.status = 'paid' ELSE true END
       AND (v_q IS NULL OR o.code LIKE '%' || v_q || '%' OR upper(st.name) LIKE '%' || v_q || '%'
            OR upper(COALESCE(st.store_code, '')) LIKE '%' || v_q || '%')
  )
  SELECT jsonb_build_object('ok', true, 'bank', v_bank,
    'plans', COALESCE((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.sort_order, p.months) FROM public.billing_plans p), '[]'::jsonb),
    'pending_count', (SELECT count(*) FROM public.billing_orders WHERE status = 'pending' AND expires_at > now()),
    'paid_30d_vnd', (SELECT COALESCE(sum(paid_amount_vnd), 0) FROM public.billing_orders
                      WHERE status = 'paid' AND paid_at > now() - interval '30 days'),
    'paid_30d_count', (SELECT count(*) FROM public.billing_orders WHERE status = 'paid' AND paid_at > now() - interval '30 days'),
    'total', (SELECT count(*) FROM f),
    'rows', COALESCE((SELECT jsonb_agg(public.qn_billing_order_json(x.r)
                                       || jsonb_build_object('store_id', (x.r).store_id, 'store_name', x.store_name,
                                                             'store_code', x.store_code, 'paid_source', (x.r).paid_source,
                                                             'paid_note', (x.r).paid_note)
                                       ORDER BY x.created_at DESC)
                        FROM (SELECT * FROM f ORDER BY created_at DESC LIMIT v_lim OFFSET v_off) x), '[]'::jsonb))
  INTO r;
  RETURN r;
END
$fn$;

-- Tài khoản nhận tiền. BIN = mã ngân hàng 6 số (Napas); số TK 4–19 chữ số; tên TK IN HOA không dấu (chuẩn VietQR)
CREATE OR REPLACE FUNCTION public.admin_billing_set_bank_v1(p_bin text, p_bank_name text, p_account_no text, p_account_name text)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller(); v jsonb;
        v_bin text := btrim(COALESCE(p_bin, '')); v_no text := btrim(COALESCE(p_account_no, ''));
        v_name text := upper(btrim(COALESCE(p_account_name, ''))); v_bank text := btrim(COALESCE(p_bank_name, ''));
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF v_bin !~ '^[0-9]{6}$' THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_BIN'); END IF;
  IF v_no !~ '^[0-9]{4,19}$' THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_ACCOUNT_NO'); END IF;
  IF v_name !~ '^[A-Z0-9 .&-]{2,50}$' THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_ACCOUNT_NAME'); END IF;
  IF char_length(v_bank) NOT BETWEEN 2 AND 60 THEN RETURN jsonb_build_object('ok', false, 'error', 'BAD_BANK_NAME'); END IF;
  v := jsonb_build_object('bin', v_bin, 'bank_name', v_bank, 'account_no', v_no, 'account_name', v_name);
  INSERT INTO public.platform_settings (key, value, updated_by, updated_at) VALUES ('billing_bank', v::text, a, now())
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_by = EXCLUDED.updated_by, updated_at = now();
  RETURN jsonb_build_object('ok', true, 'bank', v);
END
$fn$;

CREATE OR REPLACE FUNCTION public.admin_billing_set_plan_v1(p_code text, p_price_vnd bigint, p_active boolean)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF p_price_vnd IS NULL OR p_price_vnd < 1000 OR p_price_vnd > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_PRICE');
  END IF;
  -- đơn đang chờ giữ giá lúc tạo (cột amount_vnd của đơn), đổi giá chỉ áp cho đơn mới
  UPDATE public.billing_plans SET price_vnd = p_price_vnd, active = COALESCE(p_active, active), updated_at = now()
   WHERE code = p_code;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_FOUND'); END IF;
  RETURN jsonb_build_object('ok', true);
END
$fn$;

-- Xác nhận ĐÃ NHẬN TIỀN (đợt A làm tay; đợt B SePay tự gọi qn_billing_apply_order). Đơn quá 24 giờ / đã huỷ vẫn xác nhận
-- được (tiền đã vào thì phải gia hạn). Thiếu tiền → bắt ghi chú lý do.
CREATE OR REPLACE FUNCTION public.admin_billing_mark_paid_v1(p_order uuid, p_amount_vnd bigint, p_note text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  IF p_amount_vnd IS NULL OR p_amount_vnd <= 0 OR p_amount_vnd > 100000000 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BAD_AMOUNT');
  END IF;
  IF char_length(COALESCE(p_note, '')) > 300 THEN RETURN jsonb_build_object('ok', false, 'error', 'NOTE_TOO_LONG'); END IF;
  RETURN public.qn_billing_apply_order(p_order, a, 'admin', p_amount_vnd, p_note);
END
$fn$;

CREATE OR REPLACE FUNCTION public.admin_billing_cancel_order_v1(p_order uuid)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE a uuid := public.qn_admin_caller();
BEGIN
  IF a IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'FORBIDDEN'); END IF;
  UPDATE public.billing_orders SET status = 'cancelled' WHERE id = p_order AND status = 'pending';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'NOT_PENDING'); END IF;
  RETURN jsonb_build_object('ok', true);
END
$fn$;

REVOKE ALL ON FUNCTION public.admin_billing_overview_v1(text, text, int, int), public.admin_billing_set_bank_v1(text, text, text, text),
  public.admin_billing_set_plan_v1(text, bigint, boolean), public.admin_billing_mark_paid_v1(uuid, bigint, text),
  public.admin_billing_cancel_order_v1(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_billing_overview_v1(text, text, int, int), public.admin_billing_set_bank_v1(text, text, text, text),
  public.admin_billing_set_plan_v1(text, bigint, boolean), public.admin_billing_mark_paid_v1(uuid, bigint, text),
  public.admin_billing_cancel_order_v1(uuid) TO qn_admin;

-- 5) Kiểm tra sau áp
DO $$
BEGIN
  IF has_table_privilege('authenticated', 'public.billing_orders', 'select')
     OR has_table_privilege('qn_admin', 'public.billing_orders', 'select')
     OR has_table_privilege('anon', 'public.billing_plans', 'select')
     OR has_function_privilege('authenticated', 'public.qn_billing_apply_order(uuid,uuid,text,bigint,text)', 'execute')
     OR has_function_privilege('qn_admin', 'public.qn_billing_apply_order(uuid,uuid,text,bigint,text)', 'execute')
     OR has_function_privilege('anon', 'public.billing_create_order_v1(uuid,text)', 'execute')
     OR has_function_privilege('authenticated', 'public.admin_billing_mark_paid_v1(uuid,bigint,text)', 'execute')
     OR NOT has_function_privilege('authenticated', 'public.billing_info_v1(uuid)', 'execute') THEN
    RAISE EXCEPTION 'CONG THU PHI DOT A: quyền không đúng thiết kế';
  END IF;
END $$;

COMMIT;
NOTIFY pgrst, 'reload schema';
