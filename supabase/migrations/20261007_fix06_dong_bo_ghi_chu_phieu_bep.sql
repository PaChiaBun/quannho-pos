-- FIX 06 (07/10/2026) — Ghi chú món luôn đi theo phiếu bếp, kể cả khi sửa sau khi gửi
-- 1) Khi tạo dòng phiếu bếp mà free_note trống → lấy ghi chú từ ban_session_items.
-- 2) Khi ghi chú món (ban_session_items.note) đổi → cập nhật free_note của dòng phiếu bếp chưa xong.
-- Không đổi cấu trúc bảng, không xóa dữ liệu. Rollback: 20261007_fix06_ROLLBACK.sql

CREATE OR REPLACE FUNCTION public.kti_fill_free_note_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.session_item_id IS NOT NULL AND COALESCE(btrim(NEW.free_note), '') = '' THEN
    SELECT NULLIF(btrim(note), '') INTO NEW.free_note
    FROM public.ban_session_items
    WHERE id = NEW.session_item_id AND store_id = NEW.store_id;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS kti_fill_free_note_v1 ON public.kitchen_ticket_items;
CREATE TRIGGER kti_fill_free_note_v1 BEFORE INSERT ON public.kitchen_ticket_items
FOR EACH ROW EXECUTE FUNCTION public.kti_fill_free_note_v1();

CREATE OR REPLACE FUNCTION public.bsi_sync_note_to_ticket_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.note IS DISTINCT FROM OLD.note THEN
    UPDATE public.kitchen_ticket_items
    SET free_note = NULLIF(btrim(NEW.note), '')
    WHERE session_item_id = NEW.id AND store_id = NEW.store_id AND COALESCE(done, false) = false;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS bsi_sync_note_to_ticket_v1 ON public.ban_session_items;
CREATE TRIGGER bsi_sync_note_to_ticket_v1 AFTER UPDATE OF note ON public.ban_session_items
FOR EACH ROW EXECUTE FUNCTION public.bsi_sync_note_to_ticket_v1();
