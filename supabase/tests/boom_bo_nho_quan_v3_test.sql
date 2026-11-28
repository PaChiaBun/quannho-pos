-- ============================================================================
-- TEST: bộ nhớ quán bản 3 (20261112_boom_bo_nho_quan_v3.sql) — mốc dọn. Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;
CREATE OR REPLACE FUNCTION pg_temp._ok(p_cond boolean, p_msg text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
DO $$ BEGIN
  IF to_regclass('public.user_accounts') IS NOT NULL THEN
    EXECUTE $q$INSERT INTO public.user_accounts (id, phone, password_hash) VALUES ('a0000000-0000-0000-0000-0000000000b1', '0900000b01', 'x')$q$;
  END IF;
END $$;
INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
  ('a0000000-0000-0000-0000-00000000000b', 'QN-TBNB', 'Quán B thử', 'a0000000-0000-0000-0000-0000000000b1');

SELECT pg_temp._ok(EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'boom_quan_ho_so' AND column_name = 'don_luc'), 'có cột don_luc');
-- như boom-chat: upsert theo store_id, chỉ gửi don_luc → quán chưa có hồ sơ thì tạo dòng, tat mặc định false
SET LOCAL ROLE service_role;
INSERT INTO public.boom_quan_ho_so (store_id, don_luc) VALUES ('a0000000-0000-0000-0000-00000000000b', now() - interval '1 day')
  ON CONFLICT (store_id) DO UPDATE SET don_luc = EXCLUDED.don_luc;
UPDATE public.boom_quan_ho_so SET tat = true WHERE store_id = 'a0000000-0000-0000-0000-00000000000b';
INSERT INTO public.boom_quan_ho_so (store_id, don_luc) VALUES ('a0000000-0000-0000-0000-00000000000b', now())
  ON CONFLICT (store_id) DO UPDATE SET don_luc = EXCLUDED.don_luc;
RESET ROLE;
SELECT pg_temp._ok((SELECT tat AND don_luc > now() - interval '1 minute' FROM public.boom_quan_ho_so WHERE store_id = 'a0000000-0000-0000-0000-00000000000b'),
  'cập nhật don_luc không đụng công tắc tắt của chủ quán');
SET LOCAL ROLE authenticated;
SELECT pg_temp._ok(NOT has_column_privilege('authenticated', 'public.boom_quan_ho_so', 'don_luc', 'SELECT'), 'app không đọc thẳng được');
RESET ROLE;
ROLLBACK;
