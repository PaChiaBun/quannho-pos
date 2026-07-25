-- ═══════════════════════════════════════════════════════════════════════════
-- SỬA LỖI: new row violates row-level security policy for table "user_accounts"
-- ═══════════════════════════════════════════════════════════════════════════
-- Chạy script này trong Supabase Studio SQL Editor (https://quannho-db.lpm.vn)
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Tắt RLS cho bảng user_accounts và store_members (Phù hợp với custom auth SĐT + mật khẩu)
ALTER TABLE public.user_accounts DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_members DISABLE ROW LEVEL SECURITY;

-- 2. Cấp đầy đủ quyền thao tác cho role anon và authenticated
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_accounts TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.store_members TO anon, authenticated;

-- 3. Reload schema cache cho PostgREST
NOTIFY pgrst, 'reload schema';
