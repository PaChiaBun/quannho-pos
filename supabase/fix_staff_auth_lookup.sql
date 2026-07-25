-- ═══════════════════════════════════════════════════════════════════════════
-- SỬA DỨT ĐIỂM: Auto-provisioning & Lookup Nhân viên mới khi Đăng nhập
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Hàm tra cứu nhân viên an toàn qua SECURITY DEFINER (Không bị RLS chặn khi chưa có session)
CREATE OR REPLACE FUNCTION public.lookup_staff_by_phone(phone_input text)
RETURNS TABLE (
  id uuid,
  store_id uuid,
  name text,
  role text,
  phone text
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  clean_phone text;
BEGIN
  -- Chuẩn hoá SĐT đầu vào: xoá khoảng trắng, dấu gạch
  clean_phone := regexp_replace(phone_input, '[^0-9+]', '', 'g');
  
  RETURN QUERY
  SELECT 
    sm.id,
    sm.store_id,
    sm.name,
    sm.role,
    sm.phone
  FROM public.staff_members sm
  WHERE sm.is_active = true
    AND (
      regexp_replace(sm.phone, '[^0-9+]', '', 'g') = clean_phone
      OR (length(clean_phone) >= 9 AND sm.phone LIKE '%' || right(clean_phone, 9))
    )
  LIMIT 1;
END;
$$;

-- 2. Cấp quyền thực thi hàm cho anon & authenticated
GRANT EXECUTE ON FUNCTION public.lookup_staff_by_phone(text) TO anon, authenticated;

-- 3. Hàm tự động sửa các bản ghi lệch giữa staff_members và user_accounts / store_members
CREATE OR REPLACE FUNCTION public.repair_missing_staff_accounts()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  repaired_count integer := 0;
  r RECORD;
BEGIN
  FOR r IN 
    SELECT sm.id, sm.store_id, sm.name, sm.role, sm.phone
    FROM public.staff_members sm
    LEFT JOIN public.user_accounts ua ON sm.id = ua.id
    WHERE ua.id IS NULL AND sm.is_active = true AND sm.phone IS NOT NULL AND sm.phone != ''
  LOOP
    -- Tự động tạo user_accounts với pass mặc định (123456)
    INSERT INTO public.user_accounts (id, phone, display_name, password_hash)
    VALUES (
      r.id,
      r.phone,
      r.name,
      encode(digest(r.phone || ':123456:qn_pos_2024_salt', 'sha256'), 'hex')
    )
    ON CONFLICT (id) DO UPDATE 
    SET phone = EXCLUDED.phone, display_name = EXCLUDED.display_name;

    -- Tự động tạo store_members tương ứng
    INSERT INTO public.store_members (id, user_id, store_id, role, is_owner)
    VALUES (
      r.id,
      r.id,
      r.store_id,
      r.role,
      (lower(r.role) = 'owner')
    )
    ON CONFLICT (user_id, store_id) DO UPDATE
    SET role = EXCLUDED.role;

    repaired_count := repaired_count + 1;
  END LOOP;

  RETURN repaired_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.repair_missing_staff_accounts() TO anon, authenticated;

-- Notify PostgREST reload schema
NOTIFY pgrst, 'reload schema';
