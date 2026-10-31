-- ============================================================================
-- Boom — bộ hướng dẫn cập nhật qua máy chủ v1 (23/10/2026)
-- App đóng gói sẵn assets/boom_help/huong_dan.json (tool/xuat_huong_dan_boom.dart). Bảng này cho
-- phép đưa bản mới hơn mà không cần phát hành app: app đọc dòng có version lớn nhất (> bản đóng gói),
-- tự kiểm cấu trúc + lọt tên kỹ thuật, hỏng thì dùng bản đóng gói (boom_help_repository.dart).
-- Nội dung là hướng dẫn dùng app chung cho mọi quán (không có dữ liệu quán) → ai cũng ĐỌC được;
-- chỉ quản trị (supabase_admin / service_role) GHI — đăng bằng db-fix/dang_huong_dan_boom.sh.
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS public.boom_help_packs (
  version     bigint PRIMARY KEY CHECK (version > 0),
  content     jsonb NOT NULL CHECK (
                jsonb_typeof(content) = 'object'
                AND jsonb_typeof(content -> 'chunks') = 'array'
                AND (content ->> 'version')::bigint = version),
  chunk_count integer GENERATED ALWAYS AS (jsonb_array_length(content -> 'chunks')) STORED,
  note        text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.boom_help_packs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS boom_help_packs_read ON public.boom_help_packs;
CREATE POLICY boom_help_packs_read ON public.boom_help_packs FOR SELECT USING (true);

REVOKE ALL ON public.boom_help_packs FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.boom_help_packs TO anon, authenticated;
GRANT ALL ON public.boom_help_packs TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
