-- =============================================================================
-- 13/11/2026 — Bật kênh đẩy tức thì (realtime) cho bảng ghi chú món product_modifiers.
-- Lý do: Bò Đen tối 12/11 tải lại ghi chú món 410 lần / 4 giờ (17 MB) vì app hỏi lại
--        mỗi 30 giây và mỗi lần mở bảng chọn món. App mới chỉ tải lại khi máy chủ báo
--        bảng này đổi (watchByRefetch), nên bảng phải nằm trong publication.
-- Chỉ thêm bảng vào publication, không đổi dữ liệu / quyền. Chạy lại nhiều lần vẫn an toàn.
-- Hoàn tác: ALTER PUBLICATION supabase_realtime DROP TABLE public.product_modifiers;
-- =============================================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'product_modifiers'
     ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.product_modifiers;
  END IF;
END $$;
