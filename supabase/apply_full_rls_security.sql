-- ── 1. Đảm bảo hàm current_store_id() tồn tại ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.current_store_id()
RETURNS uuid AS $$
DECLARE
  _store_id text;
BEGIN
  -- Lấy x-store-id từ request headers
  _store_id := current_setting('request.headers', true)::json->>'x-store-id';
  IF _store_id IS NULL OR _store_id = '' THEN
    RETURN NULL;
  END IF;
  RETURN _store_id::uuid;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 2. Chạy Script PL/pgSQL tự động cấu hình bảo mật RLS cho TẤT CẢ các bảng ─────
DO $$
DECLARE
    r RECORD;
    t_name TEXT;
BEGIN
    -- Lặp qua toàn bộ các bảng dữ liệu trong schema public
    FOR r IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
          AND table_type = 'BASE TABLE'
    LOOP
        t_name := r.table_name;
        
        -- Kích hoạt tính năng bảo mật Row-Level Security (RLS)
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t_name);
        
        -- TRƯỜNG HỢP A: Bảng có cột 'store_id' (Cô lập dữ liệu theo từng quán)
        IF EXISTS (
            SELECT 1 
            FROM information_schema.columns 
            WHERE table_schema = 'public' 
              AND table_name = t_name 
              AND column_name = 'store_id'
        ) THEN
            -- Xóa policy cũ nếu có trùng tên
            EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', t_name || '_isolation', t_name);
            
            -- Tạo chính sách phân quyền: Chỉ cho truy cập dữ liệu của chính cửa hàng (store_id) đó (Ép kiểu về ::text để tránh lỗi lệch kiểu dữ liệu)
            EXECUTE format('
                CREATE POLICY %I ON public.%I 
                FOR ALL 
                USING (store_id::text = public.current_store_id()::text) 
                WITH CHECK (store_id::text = public.current_store_id()::text);
            ', t_name || '_isolation', t_name);
            
        -- TRƯỜNG HỢP B: Bảng 'stores' (Thông tin cửa hàng)
        ELSIF t_name = 'stores' THEN
            EXECUTE 'DROP POLICY IF EXISTS stores_isolation ON public.stores;';
            EXECUTE '
                CREATE POLICY stores_isolation ON public.stores 
                FOR ALL 
                USING (id::text = public.current_store_id()::text) 
                WITH CHECK (id::text = public.current_store_id()::text);
            ';
            
        -- TRƯỜNG HỢP C: Các bảng cấu hình chung không chứa store_id (ví dụ: app_versions, bug_reports)
        ELSE
            EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', t_name || '_read_all', t_name);
            
            -- Cho phép tất cả mọi người đọc thông tin (SELECT) nhưng không được tự ý sửa đổi
            EXECUTE format('
                CREATE POLICY %I ON public.%I 
                FOR SELECT 
                USING (true);
            ', t_name || '_read_all', t_name);
        END IF;
    END LOOP;
END $$;
