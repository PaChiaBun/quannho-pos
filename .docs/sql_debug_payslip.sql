-- =====================================================================
-- DEBUG: Payslip visibility cho Staff (Pixel 6)
-- Chạy từng câu riêng trên Supabase SQL Editor
-- =====================================================================

-- BƯỚC 1: Xem tất cả staff names trong payroll_records
SELECT id, staff_name, user_id, net_pay 
FROM payroll_records 
ORDER BY created_at DESC 
LIMIT 10;

-- BƯỚC 2: Xem tên trong user_accounts
SELECT id, display_name, phone 
FROM user_accounts 
ORDER BY created_at DESC 
LIMIT 20;

-- BƯỚC 3: Cross-check — nếu biết display_name của Pixel 6 staff là "XYZ"
-- thì kiểm tra payroll_records có staff_name chứa "XYZ" không
-- SELECT * FROM payroll_records WHERE staff_name ILIKE '%XYZ%';

-- BƯỚC 4: FIX — Update user_id trong payroll_records để match auth uid
-- (chạy sau khi biết user_id của Pixel 6 staff từ bước 2)
-- UPDATE payroll_records
-- SET user_id = '<USER_ID_CUA_PIXEL_6>'
-- WHERE LOWER(staff_name) = LOWER('<TEN_NHAN_VIEN>');
