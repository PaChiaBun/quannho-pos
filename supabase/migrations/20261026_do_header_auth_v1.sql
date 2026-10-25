-- ============================================================================
-- KẾ HOẠCH JWT — PHA 1: ĐO ai còn gọi API bằng "anon key + header x-user-id" (CHỈ ĐO, không đổi hành vi)
-- (.docs/ke-hoach-dang-nhap-jwt.md mục 5, Pha 1). CHƯA áp production, chờ Chủ Quán duyệt.
--  • public.qn_pre_request(): PostgREST gọi TRƯỚC mọi yêu cầu API (db-pre-request). Chỉ làm việc khi vai là anon:
--      - anon + có x-user-id  → cộng 1 vào qn_header_auth_seen (giờ, quán theo x-store-id, x-user-id có phải thành viên
--        thật không, method, path, x-client-info, user-agent). KHÔNG lưu giá trị x-user-id, không lưu nội dung.
--    Mọi lỗi bị nuốt → không bao giờ làm hỏng yêu cầu thật. Vai authenticated / service_role: thoát ngay.
--  • Yêu cầu ĐỌC (GET) chạy trong giao dịch chỉ-đọc → không INSERT được → ghi qua dblink (kết nối nội bộ 127.0.0.1,
--    tự commit), tối đa 1 kết nối cùng lúc (khóa tư vấn); đang bận thì bỏ qua lần đếm đó (đếm thiếu, không treo).
--  • Chặn phình bảng: tối đa 5000 dòng mỗi giờ; path lạ gộp thành '/?'; chuỗi cắt ngắn.
--  • KHÔNG đếm anon không header (QR khách, đăng nhập): thử trên bản sao thấy đếm chung 1 dòng làm các yêu cầu
--    ghi đồng thời phải chờ nhau (khóa dòng tới hết yêu cầu) → bỏ; Pha 4 đo riêng nếu cần.
--  • Hook CHƯA bật trong file này (lệnh ALTER ROLE authenticator là lệnh cấp cụm, sẽ lọt sang production nếu chạy
--    trên bản sao cùng cụm). Bật/tắt bằng 20261026_do_header_auth_v1_BAT_HOOK.sql / _TAT_HOOK.sql qua script áp dụng.
--  Hoàn tác: _TAT_HOOK.sql TRƯỚC, rồi 20261026_do_header_auth_v1_ROLLBACK.sql
-- ============================================================================
BEGIN;

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA extensions;
-- dblink mặc định cho PUBLIC gọi → chỉ để chủ hàm (superuser) dùng
DO $rv$
DECLARE f regprocedure;
BEGIN
  FOR f IN SELECT p.oid::regprocedure FROM pg_proc p
             JOIN pg_depend d ON d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e'
             JOIN pg_extension e ON e.oid = d.refobjid AND e.extname = 'dblink' LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', f);
  END LOOP;
END $rv$;

-- 1) Bảng số đo (gộp theo giờ) ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.qn_header_auth_seen (
  gio           timestamptz NOT NULL,                 -- đầu giờ (UTC)
  store_id      uuid        NOT NULL,                 -- từ x-store-id; 0000… = thiếu / không hợp lệ
  la_thanh_vien boolean     NOT NULL,                 -- x-user-id là thành viên thật của quán (false = uuid lạ / giả)
  method        text        NOT NULL,
  path          text        NOT NULL,
  client_info   text        NOT NULL,                 -- header x-client-info (vd supabase-flutter/2.x)
  user_agent    text        NOT NULL,
  chi_doc       boolean     NOT NULL,                 -- yêu cầu đọc (ghi qua dblink)
  so_lan        bigint      NOT NULL DEFAULT 1,
  lan_cuoi      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (gio, store_id, la_thanh_vien, method, path, client_info, user_agent, chi_doc)
);
ALTER TABLE public.qn_header_auth_seen ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.qn_header_auth_seen FROM PUBLIC, anon, authenticated;

-- 2) Ghi 1 lần đếm (dùng chung cho đường trực tiếp và đường dblink) -----------------------------------------
-- Thủ tục (PROCEDURE) để dblink_exec gọi được bằng CALL (dblink_exec không nhận câu lệnh trả về dòng)
CREATE OR REPLACE PROCEDURE public.qn_header_auth_ghi(
  p_gio timestamptz, p_store uuid, p_member boolean, p_method text, p_path text,
  p_ci text, p_ua text, p_chi_doc boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF (SELECT count(*) FROM (SELECT 1 FROM public.qn_header_auth_seen WHERE gio = p_gio LIMIT 5000) x) >= 5000
     AND NOT EXISTS (SELECT 1 FROM public.qn_header_auth_seen WHERE gio = p_gio AND store_id = p_store
                       AND la_thanh_vien = p_member AND method = p_method AND path = p_path
                       AND client_info = p_ci AND user_agent = p_ua AND chi_doc = p_chi_doc) THEN
    RETURN;
  END IF;
  INSERT INTO public.qn_header_auth_seen AS t (gio, store_id, la_thanh_vien, method, path, client_info, user_agent, chi_doc)
  VALUES (p_gio, p_store, p_member, p_method, p_path, p_ci, p_ua, p_chi_doc)
  ON CONFLICT (gio, store_id, la_thanh_vien, method, path, client_info, user_agent, chi_doc)
  DO UPDATE SET so_lan = t.so_lan + 1, lan_cuoi = now();
END $$;
REVOKE ALL ON PROCEDURE public.qn_header_auth_ghi(timestamptz, uuid, boolean, text, text, text, text, boolean) FROM PUBLIC, anon, authenticated;

-- 3) Hook trước mỗi yêu cầu ------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.qn_pre_request()
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  h jsonb; v_role text; v_uid text; v_store_raw text; v_store uuid := '00000000-0000-0000-0000-000000000000';
  v_member boolean := false; v_ro boolean; v_gio timestamptz := date_trunc('hour', now());
  v_method text; v_path text; v_ci text; v_ua text;
  uuid_re CONSTANT text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
BEGIN
  BEGIN
    v_role := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role';
    -- không có JWT: lấy vai PostgREST đã SET ROLE (SECURITY DEFINER không đổi GUC role)
    IF v_role IS NULL THEN v_role := NULLIF(current_setting('role'), 'none'); END IF;
    IF v_role IS DISTINCT FROM 'anon' THEN RETURN; END IF;          -- JWT thật / service_role / qn_admin: không đo
    h := NULLIF(current_setting('request.headers', true), '')::jsonb;
    v_uid := NULLIF(h->>'x-user-id', '');
    IF v_uid IS NULL THEN RETURN; END IF;                            -- anon không header (QR khách…): không đo
    v_ro := current_setting('transaction_read_only') = 'on';
    v_method := left(COALESCE(NULLIF(current_setting('request.method', true), ''), '?'), 10);
    v_path := COALESCE(NULLIF(current_setting('request.path', true), ''), '?');
    IF v_path !~ '^/[A-Za-z0-9_/.-]{0,100}$' THEN v_path := '/?'; END IF;
    v_ci := left(COALESCE(h->>'x-client-info', ''), 80);
    v_ua := left(COALESCE(h->>'user-agent', ''), 120);
    v_store_raw := NULLIF(h->>'x-store-id', '');
    IF v_store_raw ~* uuid_re THEN v_store := v_store_raw::uuid; END IF;
    IF v_uid ~* uuid_re THEN
      v_member := CASE WHEN v_store_raw ~* uuid_re
        THEN EXISTS (SELECT 1 FROM public.store_members m WHERE m.store_id = v_store AND m.user_id = v_uid::uuid)
             OR EXISTS (SELECT 1 FROM public.stores s WHERE s.id = v_store AND s.owner_user_id = v_uid::uuid)
        ELSE EXISTS (SELECT 1 FROM public.store_members m WHERE m.user_id = v_uid::uuid) END;
    END IF;

    IF NOT v_ro THEN
      CALL public.qn_header_auth_ghi(v_gio, v_store, v_member, v_method, v_path, v_ci, v_ua, false);
    ELSIF pg_try_advisory_xact_lock(726102610) THEN                -- tối đa 1 kết nối dblink cùng lúc (giữa các phiên)
      PERFORM extensions.dblink_exec(
        format('host=127.0.0.1 port=5432 dbname=%s user=%s connect_timeout=2 application_name=qn_header_auth',
               current_database(), current_user),
        format('SET statement_timeout = ''2s''; CALL public.qn_header_auth_ghi(%L, %L, %L, %L, %L, %L, %L, true)',
               v_gio, v_store, v_member, v_method, v_path, v_ci, v_ua));
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;                                                            -- đo đạc không bao giờ làm hỏng yêu cầu
  END;
END $$;
-- PostgREST gọi hook bằng vai của yêu cầu (anon / authenticated / service_role / qn_admin) → để PUBLIC gọi được.
GRANT EXECUTE ON FUNCTION public.qn_pre_request() TO PUBLIC;

COMMENT ON TABLE public.qn_header_auth_seen IS 'Pha 1 kế hoạch JWT: số lần gọi API bằng anon + x-user-id, gộp theo giờ (không lưu giá trị header). Xem db-fix/do_header_auth_ap_dung.sh REPORT=1';

DO $chk$
BEGIN
  IF has_table_privilege('anon', 'public.qn_header_auth_seen', 'SELECT')
     OR has_function_privilege('anon', 'public.qn_header_auth_ghi(timestamptz,uuid,boolean,text,text,text,text,boolean)', 'EXECUTE')
     OR has_function_privilege('anon', 'extensions.dblink_exec(text,text)', 'EXECUTE')
     OR NOT has_function_privilege('anon', 'public.qn_pre_request()', 'EXECUTE') THEN
    RAISE EXCEPTION 'DO_HEADER v1: quyền sau khi áp không đúng';
  END IF;
  RAISE NOTICE 'DO_HEADER v1: áp xong (hook CHƯA bật)';
END $chk$;

COMMIT;
