-- ============================================================================
-- Vận hành — Bàn giao ca v1 (23/10/2026)
-- App đã có nút "Bàn Giao Ca" (ops_staff_screen.dart → OpsRepository.createHandover) nhưng bảng
-- ops_shift_handovers CHƯA TỪNG được tạo trên production → mọi lần bàn giao đều lỗi, không lưu gì.
-- Migration này tạo bảng, cách ly theo quán (current_store_id()), chỉ cho THÊM và ĐỌC
-- (bàn giao là biên bản — không sửa, không xoá từ app). Người tạo được đóng dấu theo người gọi.
-- ============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS public.ops_shift_handovers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id        uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  from_shift_id   text,
  to_shift_id     text,
  handover_date   date NOT NULL DEFAULT CURRENT_DATE,
  created_by      text,
  created_by_name text,
  issues          text CHECK (issues IS NULL OR length(issues) <= 2000),
  notes           text CHECK (notes  IS NULL OR length(notes)  <= 2000),
  pending_tasks   jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(pending_tasks) = 'array'),
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ops_handovers_store_created
  ON public.ops_shift_handovers (store_id, created_at DESC);

ALTER TABLE public.ops_shift_handovers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ops_shift_handovers_isolation ON public.ops_shift_handovers;
CREATE POLICY ops_shift_handovers_isolation ON public.ops_shift_handovers
  FOR ALL
  USING      (store_id = (SELECT public.current_store_id()))
  WITH CHECK (store_id = (SELECT public.current_store_id()));

REVOKE ALL ON public.ops_shift_handovers FROM anon, authenticated;
GRANT SELECT, INSERT ON public.ops_shift_handovers TO anon, authenticated;

-- Đóng dấu người tạo (id + tên) + giờ tạo theo máy chủ (app không tự khai người khác / giờ khác).
CREATE OR REPLACE FUNCTION public.guard_ops_shift_handover_v1()
RETURNS trigger
LANGUAGE plpgsql
-- KHÔNG dùng SECURITY DEFINER: cần current_user là vai trò thật của người gọi (anon/authenticated).
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE v_uid uuid;
BEGIN
  IF current_user IN ('anon', 'authenticated') THEN
    v_uid := public.qn_caller_id();
    IF v_uid IS NOT NULL THEN
      NEW.created_by := v_uid::text;
      -- Tên hiển thị trên thẻ cũng lấy từ tài khoản, không tin tên app gửi lên.
      NEW.created_by_name := COALESCE(
        (SELECT NULLIF(display_name, '') FROM public.user_accounts WHERE id = v_uid),
        NEW.created_by_name);
    END IF;
    NEW.created_at := now();
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS trg_guard_ops_shift_handover_v1 ON public.ops_shift_handovers;
CREATE TRIGGER trg_guard_ops_shift_handover_v1
  BEFORE INSERT ON public.ops_shift_handovers
  FOR EACH ROW EXECUTE FUNCTION public.guard_ops_shift_handover_v1();

COMMIT;

NOTIFY pgrst, 'reload schema';
