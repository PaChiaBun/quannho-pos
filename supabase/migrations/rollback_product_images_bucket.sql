-- ROLLBACK cho 20261013_product_images_bucket.sql
-- Bỏ 3 chính sách. KHÔNG xóa kho nếu đang có ảnh (xóa kho kéo theo mất ảnh); chỉ xóa khi kho rỗng.
BEGIN;
DROP POLICY IF EXISTS "product-images public read" ON storage.objects;
DROP POLICY IF EXISTS "product-images upload" ON storage.objects;
DROP POLICY IF EXISTS "product-images delete" ON storage.objects;
DELETE FROM storage.buckets b WHERE b.id = 'product-images'
  AND NOT EXISTS (SELECT 1 FROM storage.objects o WHERE o.bucket_id = 'product-images');
COMMIT;
