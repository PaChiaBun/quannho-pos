-- =========================================================
-- QUÁN NHỎ — Full Customer & Wallet Schema Migration
-- Chạy trong Supabase Dashboard → SQL Editor
-- =========================================================

-- 1. Bảng customers (tạo mới nếu chưa có)
CREATE TABLE IF NOT EXISTS public.customers (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id            UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name                TEXT NOT NULL,
  phone               TEXT,
  email               TEXT,
  note                TEXT,

  -- Loyalty points (hệ thống điểm tích lũy cũ)
  loyalty_pts         DOUBLE PRECISION NOT NULL DEFAULT 0,
  total_spent         DOUBLE PRECISION NOT NULL DEFAULT 0,
  visit_count         INTEGER NOT NULL DEFAULT 0,

  -- Stamp card (mua N tặng 1)
  stamp_count         INTEGER NOT NULL DEFAULT 0,
  stamp_total         INTEGER NOT NULL DEFAULT 0,

  -- *** Wallet (hệ thống ví nạp tiền — MỚI) ***
  real_balance        DOUBLE PRECISION NOT NULL DEFAULT 0,
  -- Tiền thật khách nạp vào (trừ tự do)

  bonus_balance       DOUBLE PRECISION NOT NULL DEFAULT 0,
  -- Tiền thưởng (trừ tối đa bonus_cap_pct% mỗi bill)

  bonus_cap_pct       INTEGER NOT NULL DEFAULT 15,
  -- % tối đa bonus được dùng mỗi bill (mặc định 15%)

  bonus_expires_at    TIMESTAMPTZ,
  -- Thời hạn sử dụng bonus (NULL = không hết hạn)

  total_topup         DOUBLE PRECISION NOT NULL DEFAULT 0,
  -- Tổng tiền thật đã nạp (không tính bonus)

  -- Metadata
  is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index cho tìm kiếm theo store + phone
CREATE INDEX IF NOT EXISTS idx_customers_store_id ON public.customers(store_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone    ON public.customers(phone);
CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_store_phone
  ON public.customers(store_id, phone)
  WHERE phone IS NOT NULL AND is_deleted = FALSE;

-- 2. Bảng balance_transactions (lịch sử nạp/tiêu ví)
CREATE TABLE IF NOT EXISTS public.balance_transactions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  customer_id   UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  order_id      UUID,  -- NULL nếu là giao dịch nạp tiền

  type          TEXT NOT NULL,
  -- 'topup_real'    : nạp tiền thật
  -- 'topup_bonus'   : thêm bonus kèm nạp tiền
  -- 'spend_real'    : tiêu real_balance (khi mua hàng)
  -- 'spend_bonus'   : tiêu bonus_balance (khi mua hàng)
  -- 'bonus_expired' : bonus hết hạn bị thu hồi
  -- 'refund'        : hoàn tiền

  amount        DOUBLE PRECISION NOT NULL DEFAULT 0,
  -- Số tiền giao dịch (luôn dương, type cho biết +/-)

  balance_after DOUBLE PRECISION NOT NULL DEFAULT 0,
  -- Số dư real_balance sau giao dịch (để audit)

  bonus_after   DOUBLE PRECISION NOT NULL DEFAULT 0,
  -- Số dư bonus_balance sau giao dịch (để audit)

  note          TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_balance_tx_customer
  ON public.balance_transactions(customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_balance_tx_store
  ON public.balance_transactions(store_id, created_at DESC);

-- 3. Bảng loyalty_transactions (lịch sử điểm — đã có, tạo an toàn)
CREATE TABLE IF NOT EXISTS public.loyalty_transactions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      UUID NOT NULL,
  customer_id   UUID NOT NULL,
  order_id      UUID,
  pts_earned    DOUBLE PRECISION NOT NULL DEFAULT 0,
  pts_used      DOUBLE PRECISION NOT NULL DEFAULT 0,
  note          TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_loyalty_tx_customer
  ON public.loyalty_transactions(customer_id, created_at DESC);

-- 4. Bảng loyalty_rewards (phần thưởng đổi điểm — đã có, tạo an toàn)
CREATE TABLE IF NOT EXISTS public.loyalty_rewards (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id        UUID NOT NULL,
  name            TEXT NOT NULL,
  pts_required    DOUBLE PRECISION NOT NULL DEFAULT 0,
  discount_amount DOUBLE PRECISION,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Đảm bảo app_settings có các key mới cho wallet
-- (Chạy sau khi bảng app_settings đã tồn tại)
-- Thêm loyalty_redeem_rate và stamp_threshold nếu chưa có
-- (Dùng store_id của store hiện tại)
-- Ghi chú: thay <YOUR_STORE_ID> bằng UUID thực của store
-- INSERT INTO app_settings (id, store_id, key, value)
-- SELECT gen_random_uuid(), '<YOUR_STORE_ID>', 'loyalty_redeem_rate', '1000'
-- WHERE NOT EXISTS (SELECT 1 FROM app_settings WHERE store_id='<YOUR_STORE_ID>' AND key='loyalty_redeem_rate');

-- 6. RLS Policies (nếu có bật RLS)
-- ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.balance_transactions ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "store_access" ON public.customers
--   USING (store_id = (SELECT store_id FROM store_sessions WHERE user_id = auth.uid()));

-- 7. Xác nhận
SELECT
  table_name,
  COUNT(*) as column_count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('customers', 'balance_transactions', 'loyalty_transactions', 'loyalty_rewards')
GROUP BY table_name
ORDER BY table_name;
