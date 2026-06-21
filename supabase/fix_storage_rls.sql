-- Fix RLS Storage: Cho phép anon key upload/read/delete
-- Chạy trong Supabase Dashboard → SQL Editor → New Query

-- Xoá policy cũ nếu có
DROP POLICY IF EXISTS "Allow upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow delete product images" ON storage.objects;
DROP POLICY IF EXISTS "Allow update product images" ON storage.objects;

-- Tạo policy mới — cho phép tất cả (anon + authenticated)
CREATE POLICY "product-images: allow all"
ON storage.objects
FOR ALL
TO public
USING (bucket_id = 'product-images')
WITH CHECK (bucket_id = 'product-images');
