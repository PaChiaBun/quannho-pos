-- ============================================================================
-- TẮT hook đo đạc Pha 1 (hoàn tác tức thì, không đụng dữ liệu). Chạy được bất cứ lúc nào.
-- ============================================================================
ALTER ROLE authenticator IN DATABASE postgres RESET pgrst.db_pre_request;
NOTIFY pgrst, 'reload config';
