-- ============================================================================
-- BỘ NHỚ QUÁN bản 3 (lần 248, giai đoạn 5 — .docs/thiet-ke-bo-nho-quan-boom.md mục 4.6): mốc dọn bộ nhớ của từng quán.
-- boom-chat dọn bộ nhớ quán (hết hiệu lực kế hoạch đã qua, gộp điều trùng ý) ở lượt hỏi đầu tiên sau ≥ 20 giờ, ghi mốc vào don_luc.
-- Không cron. Bảng vẫn chỉ service_role đọc / ghi. Hoàn tác: 20261112_boom_bo_nho_quan_v3_ROLLBACK.sql.
-- ============================================================================
BEGIN;
ALTER TABLE public.boom_quan_ho_so ADD COLUMN IF NOT EXISTS don_luc timestamptz;
COMMENT ON COLUMN public.boom_quan_ho_so.don_luc IS 'Lần dọn bộ nhớ quán gần nhất (boom-chat, lần 248)';
COMMIT;
