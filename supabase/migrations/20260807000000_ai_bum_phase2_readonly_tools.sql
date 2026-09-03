-- =============================================================================
-- AI BUM PILOT PHASE 2: DATABASE SCHEMAS & READ-ONLY TOOLS (QUÁN KAY PILOT)
-- Date: 2026-08-07
-- File: supabase/migrations/20260807000000_ai_bum_phase2_readonly_tools.sql
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. BẢNG DỮ LIỆU BUM AI (AI BUM TABLES WITH RLS)
-- -----------------------------------------------------------------------------

-- 1.1 Bảng bum_conversations
CREATE TABLE IF NOT EXISTS public.bum_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    title TEXT DEFAULT 'Hội thoại mới',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 1.2 Bảng bum_messages
CREATE TABLE IF NOT EXISTS public.bum_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.bum_conversations(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    sender_role TEXT NOT NULL CHECK (sender_role IN ('user', 'bum')),
    content TEXT NOT NULL,
    intent TEXT,
    confidence NUMERIC(4, 3),
    data_sources JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 1.3 Bảng bum_feedback
CREATE TABLE IF NOT EXISTS public.bum_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.bum_messages(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    rating TEXT NOT NULL CHECK (rating IN ('thumbs_up', 'thumbs_down')),
    feedback_text TEXT,
    reason_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 1.4 Bảng bum_memories (Trí nhớ riêng từng quán)
CREATE TABLE IF NOT EXISTS public.bum_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    category TEXT NOT NULL,
    memory_key TEXT NOT NULL,
    memory_value TEXT NOT NULL,
    created_by UUID NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_store_memory_key UNIQUE (store_id, memory_key)
);

-- Enable RLS
ALTER TABLE public.bum_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bum_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bum_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bum_memories ENABLE ROW LEVEL SECURITY;


-- -----------------------------------------------------------------------------
-- 2. 10 READ-ONLY RPC TOOLS CHO PILOT QUÁN KAY
-- -----------------------------------------------------------------------------

-- 2.1 get_today_sales_summary: Doanh thu hôm nay
CREATE OR REPLACE FUNCTION public.get_today_sales_summary(
    p_store_id UUID
)
RETURNS TABLE (
    total_orders BIGINT,
    total_sales NUMERIC,
    avg_order_value NUMERIC,
    total_discount NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(id)::BIGINT AS total_orders,
        COALESCE(SUM(final_amount), 0)::NUMERIC AS total_sales,
        COALESCE(AVG(final_amount), 0)::NUMERIC AS avg_order_value,
        COALESCE(SUM(discount_amount), 0)::NUMERIC AS total_discount
    FROM public.orders
    WHERE store_id = p_store_id
      AND status = 'completed'
      AND created_at >= CURRENT_DATE;
END;
$$;

-- 2.2 compare_sales_periods: So sánh doanh thu các kỳ
CREATE OR REPLACE FUNCTION public.compare_sales_periods(
    p_store_id UUID,
    p_period TEXT DEFAULT 'yesterday'
)
RETURNS TABLE (
    current_sales NUMERIC,
    previous_sales NUMERIC,
    growth_percentage NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_curr NUMERIC := 0;
    v_prev NUMERIC := 0;
    v_pct NUMERIC := 0;
BEGIN
    SELECT COALESCE(SUM(final_amount), 0) INTO v_curr
    FROM public.orders
    WHERE store_id = p_store_id AND status = 'completed' AND created_at >= CURRENT_DATE;

    IF p_period = 'yesterday' THEN
        SELECT COALESCE(SUM(final_amount), 0) INTO v_prev
        FROM public.orders
        WHERE store_id = p_store_id AND status = 'completed'
          AND created_at >= (CURRENT_DATE - INTERVAL '1 day')
          AND created_at < CURRENT_DATE;
    END IF;

    IF v_prev > 0 THEN
        v_pct := ROUND(((v_curr - v_prev) / v_prev) * 100, 2);
    END IF;

    RETURN QUERY SELECT v_curr, v_prev, v_pct;
END;
$$;

-- 2.3 get_top_products: Món bán chạy nhất
CREATE OR REPLACE FUNCTION public.get_top_products(
    p_store_id UUID,
    p_limit INT DEFAULT 5
)
RETURNS TABLE (
    product_name TEXT,
    total_quantity BIGINT,
    total_revenue NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        oi.product_name,
        SUM(oi.quantity)::BIGINT AS total_quantity,
        SUM(oi.total_price)::NUMERIC AS total_revenue
    FROM public.order_items oi
    JOIN public.orders o ON o.id = oi.order_id
    WHERE o.store_id = p_store_id
      AND o.status = 'completed'
      AND o.created_at >= CURRENT_DATE
    GROUP BY oi.product_name
    ORDER BY total_quantity DESC
    LIMIT LEAST(p_limit, 20);
END;
$$;

-- 2.4 get_slow_products: Món bán ế / bán chậm
CREATE OR REPLACE FUNCTION public.get_slow_products(
    p_store_id UUID,
    p_days INT DEFAULT 7
)
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    sold_quantity BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS product_id,
        p.name AS product_name,
        COALESCE(SUM(oi.quantity), 0)::BIGINT AS sold_quantity
    FROM public.products p
    LEFT JOIN public.order_items oi ON oi.product_id = p.id
    LEFT JOIN public.orders o ON o.id = oi.order_id 
        AND o.status = 'completed' 
        AND o.created_at >= (CURRENT_DATE - (p_days || ' days')::INTERVAL)
    WHERE p.store_id = p_store_id
      AND p.is_active = true
    GROUP BY p.id, p.name
    ORDER BY sold_quantity ASC
    LIMIT 10;
END;
$$;

-- 2.5 get_low_stock_items: Nguyên liệu / món sắp hết kho
CREATE OR REPLACE FUNCTION public.get_low_stock_items(
    p_store_id UUID
)
RETURNS TABLE (
    product_name TEXT,
    stock_quantity NUMERIC,
    min_stock_alert NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        name AS product_name,
        stock_quantity::NUMERIC,
        min_stock_alert::NUMERIC
    FROM public.products
    WHERE store_id = p_store_id
      AND is_active = true
      AND stock_quantity <= min_stock_alert
    ORDER BY stock_quantity ASC;
END;
$$;

-- 2.6 get_stock_forecast_inputs: Dữ liệu dự báo kho
CREATE OR REPLACE FUNCTION public.get_stock_forecast_inputs(
    p_store_id UUID
)
RETURNS TABLE (
    product_name TEXT,
    current_stock NUMERIC,
    avg_daily_sales NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.name AS product_name,
        p.stock_quantity::NUMERIC AS current_stock,
        COALESCE(SUM(oi.quantity) / 7.0, 0)::NUMERIC AS avg_daily_sales
    FROM public.products p
    LEFT JOIN public.order_items oi ON oi.product_id = p.id
    LEFT JOIN public.orders o ON o.id = oi.order_id 
        AND o.status = 'completed' 
        AND o.created_at >= (CURRENT_DATE - INTERVAL '7 days')
    WHERE p.store_id = p_store_id
    GROUP BY p.id, p.name, p.stock_quantity;
END;
$$;

-- 2.7 get_finance_summary: Tổng quan thu chi
CREATE OR REPLACE FUNCTION public.get_finance_summary(
    p_store_id UUID,
    p_month INT DEFAULT EXTRACT(MONTH FROM CURRENT_DATE)::INT,
    p_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT
)
RETURNS TABLE (
    total_income NUMERIC,
    total_expense NUMERIC,
    net_profit NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_inc NUMERIC := 0;
    v_exp NUMERIC := 0;
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_inc
    FROM public.finance_records
    WHERE store_id = p_store_id AND type = 'income'
      AND EXTRACT(MONTH FROM created_at) = p_month
      AND EXTRACT(YEAR FROM created_at) = p_year;

    SELECT COALESCE(SUM(amount), 0) INTO v_exp
    FROM public.finance_records
    WHERE store_id = p_store_id AND type = 'expense'
      AND EXTRACT(MONTH FROM created_at) = p_month
      AND EXTRACT(YEAR FROM created_at) = p_year;

    RETURN QUERY SELECT v_inc, v_exp, (v_inc - v_exp);
END;
$$;

-- 2.8 get_staff_on_shift: Nhân viên đang trong ca (loại bỏ PII SĐT/PIN)
CREATE OR REPLACE FUNCTION public.get_staff_on_shift(
    p_store_id UUID
)
RETURNS TABLE (
    staff_id UUID,
    staff_name TEXT,
    staff_role TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        id AS staff_id,
        name AS staff_name,
        role AS staff_role
    FROM public.staff_members
    WHERE store_id = p_store_id
      AND is_active = true;
END;
$$;

-- 2.9 get_pending_operations_tasks: Cảnh báo vận hành & hủy đơn
CREATE OR REPLACE FUNCTION public.get_pending_operations_tasks(
    p_store_id UUID
)
RETURNS TABLE (
    task_type TEXT,
    label TEXT,
    total_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        void_type AS task_type,
        label,
        COUNT(id)::BIGINT AS total_count
    FROM public.void_audit_logs
    WHERE store_id = p_store_id
      AND created_at >= CURRENT_DATE
    GROUP BY void_type, label;
END;
$$;

-- 2.10 get_store_context_for_bum: Bối cảnh thông tin Quán Kay
CREATE OR REPLACE FUNCTION public.get_store_context_for_bum(
    p_store_id UUID
)
RETURNS TABLE (
    store_id UUID,
    store_name TEXT,
    store_code TEXT,
    status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        id AS store_id,
        name AS store_name,
        store_code,
        status
    FROM public.stores
    WHERE id = p_store_id;
END;
$$;

COMMIT;
