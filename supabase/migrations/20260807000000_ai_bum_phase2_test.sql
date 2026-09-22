-- =============================================================================
-- AI BUM PILOT PHASE 2: SECURITY & FUNCTIONAL TEST SCRIPT
-- Date: 2026-08-07
-- File: supabase/migrations/20260807000000_ai_bum_phase2_test.sql
-- =============================================================================

-- TEST 1: Kiểm thử RPC get_today_sales_summary cho đúng store
SELECT * FROM public.get_today_sales_summary('00000000-0000-0000-0000-000000009999');

-- TEST 2: Kiểm thử RPC get_top_products (tối đa 5 món)
SELECT * FROM public.get_top_products('00000000-0000-0000-0000-000000009999', 5);

-- TEST 3: Kiểm thử RPC get_low_stock_items
SELECT * FROM public.get_low_stock_items('00000000-0000-0000-0000-000000009999');

-- TEST 4: Kiểm thử RPC get_staff_on_shift (Đảm bảo không trả SĐT hay PIN)
SELECT * FROM public.get_staff_on_shift('00000000-0000-0000-0000-000000009999');

-- TEST 5: Kiểm thử RPC cách cô lập store_id với ID không tồn tại (Phải trả về 0 / rỗng)
SELECT * FROM public.get_today_sales_summary('11111111-2222-3333-4444-555555555555');
