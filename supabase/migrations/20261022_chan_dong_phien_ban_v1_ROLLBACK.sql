-- Hoàn tác 20261022_chan_dong_phien_ban_v1.sql: bỏ trigger chặn client đóng phiên bàn.
-- Không xoá/đổi dữ liệu nào.
DROP TRIGGER IF EXISTS guard_ban_session_status_v1 ON public.ban_sessions;
DROP FUNCTION IF EXISTS public.guard_ban_session_status_v1();
DROP FUNCTION IF EXISTS public.ban_session_active_item_count_v1(uuid);
