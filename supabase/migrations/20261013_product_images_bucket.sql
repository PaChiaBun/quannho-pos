-- ============================================================================
-- KHO ẢNH MÓN (product-images) — tạo kho + chính sách. Trên máy chủ tự dựng kho này CHƯA TỪNG được tạo
-- nên mọi lần tải ảnh món đều lỗi 400 (không tìm thấy kho).
--
-- Thiết kế (Chủ Quán 13/10/2026): cho tải lên kích thước bất kỳ (tối đa 50 MB = trần của dịch vụ storage),
-- SAU ĐÓ bộ nén phía máy chủ tự nén nhỏ lại và dọn ảnh rác (xem services/image_optimizer.py).
--
-- Chính sách:
--   * Đọc: công khai (ảnh món hiện trên menu khách).
--   * Tải lên (INSERT): anon + authenticated — vì phần lớn máy nhân viên đang chạy vai anon. Tên tệp phải đúng
--     dạng <uuid>.<jpg|jpeg|png|webp> như app sinh, nên không tải được tên tùy ý. Loại tệp bị bucket giới hạn.
--   * Xóa: chỉ authenticated. (Anon không xóa được → ảnh cũ của máy anon thành "rác", bộ dọn rác xử lý.)
--   * Không cho sửa đè (không có chính sách UPDATE) — bộ nén dùng service_role nên không bị ảnh hưởng.
-- Hoàn tác: rollback_product_images_bucket.sql
-- ============================================================================
BEGIN;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('product-images', 'product-images', true, 52428800, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE
  SET public = true, file_size_limit = 52428800, allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

DROP POLICY IF EXISTS "product-images public read" ON storage.objects;
CREATE POLICY "product-images public read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "product-images upload" ON storage.objects;
CREATE POLICY "product-images upload" ON storage.objects
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    bucket_id = 'product-images'
    AND name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp)$'
  );

DROP POLICY IF EXISTS "product-images delete" ON storage.objects;
CREATE POLICY "product-images delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'product-images');

COMMIT;
