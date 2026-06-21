-- Tạo bucket product-images trên Supabase Storage
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  true,           -- public để đọc không cần auth
  2097152,        -- 2MB max per file
  ARRAY['image/jpeg','image/png','image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Policy: bất kỳ user auth nào cũng có thể upload
CREATE POLICY "Authenticated upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product-images');

-- Policy: public read
CREATE POLICY "Public read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'product-images');

-- Policy: authenticated delete (chủ quán xoá ảnh cũ)
CREATE POLICY "Authenticated delete"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'product-images');
