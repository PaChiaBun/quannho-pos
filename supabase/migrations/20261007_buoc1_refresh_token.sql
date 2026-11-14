-- ═════════════════════════════════════════════════════════════════════════════
-- BƯỚC 1 — Refresh token xoay vòng cho POS JWT gateway
-- Ngày: 2026-10-07 · Áp dụng: sau 23h (DDL ngắn, chỉ thêm mới, không sửa bảng cũ
--        ngoài 2 trigger AFTER trên store_members / user_accounts)
--
-- Ý tưởng:
--   * Access token (JWT) sống 12h, refresh token sống 30 ngày.
--   * Refresh token chỉ lưu SHA-256 (hex) trong DB, không lưu bản rõ.
--   * Mỗi lần refresh: token cũ bị đánh dấu used, cấp token mới cùng "family".
--   * Dùng lại token đã used (sau 120s ân hạn) => coi như bị đánh cắp, thu hồi cả family.
--   * Xoá nhân viên khỏi quán / đổi mật khẩu => thu hồi refresh token tương ứng.
--   * Chỉ service_role (gateway) gọi được các hàm này.
-- An toàn với app đang chạy: không đụng tới bảng / policy app đang dùng.
-- ═════════════════════════════════════════════════════════════════════════════

SET lock_timeout = '5s';
SET statement_timeout = '30s';

CREATE TABLE IF NOT EXISTS public.pos_refresh_tokens (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id    uuid NOT NULL,
  user_id      uuid NOT NULL,
  store_id     uuid NOT NULL,
  token_hash   text NOT NULL UNIQUE CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  created_at   timestamptz NOT NULL DEFAULT now(),
  expires_at   timestamptz NOT NULL,
  used_at      timestamptz,
  revoked_at   timestamptz,
  revoke_reason text,
  client_label text,
  client_ip    text
);

CREATE INDEX IF NOT EXISTS pos_refresh_tokens_family_idx ON public.pos_refresh_tokens(family_id);
CREATE INDEX IF NOT EXISTS pos_refresh_tokens_user_store_idx ON public.pos_refresh_tokens(user_id, store_id);
CREATE INDEX IF NOT EXISTS pos_refresh_tokens_expires_idx ON public.pos_refresh_tokens(expires_at);

ALTER TABLE public.pos_refresh_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_refresh_tokens FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.pos_refresh_tokens FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.pos_refresh_tokens TO service_role;
-- Không tạo policy nào: anon/authenticated không đọc/ghi được kể cả khi lỡ có GRANT.

-- ── Vai trò hiện tại của user trong quán (giống verify_user_login_v4) ─────────
CREATE OR REPLACE FUNCTION public.qn_member_role_v1(p_user_id uuid, p_store_id uuid)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT COALESCE(
    (SELECT sm.role FROM public.store_members sm
      WHERE sm.user_id = p_user_id AND sm.store_id = p_store_id
      ORDER BY sm.created_at NULLS LAST LIMIT 1),
    (SELECT 'owner' FROM public.stores s
      WHERE s.id = p_store_id AND s.owner_user_id = p_user_id)
  );
$$;
REVOKE ALL ON FUNCTION public.qn_member_role_v1(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qn_member_role_v1(uuid, uuid) TO service_role;

-- ── Cấp refresh token mới (sau khi đăng nhập bằng mật khẩu thành công) ────────
CREATE OR REPLACE FUNCTION public.qn_refresh_issue_v1(
  p_user_id uuid,
  p_store_id uuid,
  p_token_hash text,
  p_ttl_seconds integer DEFAULT 2592000,
  p_family_id uuid DEFAULT NULL,
  p_client_label text DEFAULT NULL,
  p_client_ip text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $$
DECLARE
  v_role text;
  v_family uuid := COALESCE(p_family_id, gen_random_uuid());
BEGIN
  IF p_token_hash IS NULL OR p_token_hash !~ '^[0-9a-f]{64}$'
     OR p_ttl_seconds IS NULL OR p_ttl_seconds < 60 OR p_ttl_seconds > 7776000 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PARAMETERS');
  END IF;

  v_role := public.qn_member_role_v1(p_user_id, p_store_id);
  IF v_role IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'STORE_MEMBERSHIP_FORBIDDEN');
  END IF;

  -- Dọn rác: token hết hạn quá 7 ngày
  DELETE FROM public.pos_refresh_tokens WHERE expires_at < now() - interval '7 days';

  INSERT INTO public.pos_refresh_tokens(family_id, user_id, store_id, token_hash, expires_at, client_label, client_ip)
  VALUES (v_family, p_user_id, p_store_id, p_token_hash,
          now() + make_interval(secs => p_ttl_seconds),
          left(p_client_label, 120), left(p_client_ip, 64));

  RETURN jsonb_build_object('success', true, 'family_id', v_family, 'role', v_role);
END;
$$;
REVOKE ALL ON FUNCTION public.qn_refresh_issue_v1(uuid, uuid, text, integer, uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qn_refresh_issue_v1(uuid, uuid, text, integer, uuid, text, text) TO service_role;

-- ── Xoay vòng: đổi refresh token cũ lấy token mới (nguyên tử) ─────────────────
CREATE OR REPLACE FUNCTION public.qn_refresh_rotate_v1(
  p_old_hash text,
  p_new_hash text,
  p_ttl_seconds integer DEFAULT 2592000,
  p_client_ip text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_temp'
AS $$
DECLARE
  v_tok public.pos_refresh_tokens%ROWTYPE;
  v_role text;
BEGIN
  IF p_old_hash IS NULL OR p_old_hash !~ '^[0-9a-f]{64}$'
     OR p_new_hash IS NULL OR p_new_hash !~ '^[0-9a-f]{64}$'
     OR p_old_hash = p_new_hash
     OR p_ttl_seconds IS NULL OR p_ttl_seconds < 60 OR p_ttl_seconds > 7776000 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PARAMETERS');
  END IF;

  SELECT * INTO v_tok FROM public.pos_refresh_tokens
  WHERE token_hash = p_old_hash
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'REFRESH_INVALID');
  END IF;

  IF v_tok.revoked_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'REFRESH_REVOKED');
  END IF;

  IF v_tok.used_at IS NOT NULL THEN
    -- Ân hạn 120s: 2 tab / 2 luồng refresh cùng lúc => không thu hồi, client đọc lại token mới.
    IF v_tok.used_at > now() - interval '120 seconds' THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'REFRESH_RACE');
    END IF;
    -- Dùng lại token cũ => nghi bị đánh cắp => thu hồi cả family.
    UPDATE public.pos_refresh_tokens
      SET revoked_at = now(), revoke_reason = 'reuse_detected'
    WHERE family_id = v_tok.family_id AND revoked_at IS NULL;
    RETURN jsonb_build_object('success', false, 'error_code', 'REFRESH_REUSED');
  END IF;

  IF v_tok.expires_at <= now() THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'REFRESH_EXPIRED');
  END IF;

  v_role := public.qn_member_role_v1(v_tok.user_id, v_tok.store_id);
  IF v_role IS NULL THEN
    UPDATE public.pos_refresh_tokens
      SET revoked_at = now(), revoke_reason = 'membership_removed'
    WHERE family_id = v_tok.family_id AND revoked_at IS NULL;
    RETURN jsonb_build_object('success', false, 'error_code', 'STORE_MEMBERSHIP_FORBIDDEN');
  END IF;

  UPDATE public.pos_refresh_tokens SET used_at = now() WHERE id = v_tok.id;

  INSERT INTO public.pos_refresh_tokens(family_id, user_id, store_id, token_hash, expires_at, client_label, client_ip)
  VALUES (v_tok.family_id, v_tok.user_id, v_tok.store_id, p_new_hash,
          now() + make_interval(secs => p_ttl_seconds),
          v_tok.client_label, left(COALESCE(p_client_ip, v_tok.client_ip), 64));

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_tok.user_id,
    'store_id', v_tok.store_id,
    'role', v_role,
    'family_id', v_tok.family_id
  );
END;
$$;
REVOKE ALL ON FUNCTION public.qn_refresh_rotate_v1(text, text, integer, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qn_refresh_rotate_v1(text, text, integer, text) TO service_role;

-- ── Đăng xuất: thu hồi cả family của refresh token ───────────────────────────
CREATE OR REPLACE FUNCTION public.qn_refresh_revoke_v1(p_token_hash text, p_reason text DEFAULT 'logout')
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_family uuid;
  v_count integer := 0;
BEGIN
  SELECT family_id INTO v_family FROM public.pos_refresh_tokens WHERE token_hash = p_token_hash;
  IF v_family IS NOT NULL THEN
    UPDATE public.pos_refresh_tokens
      SET revoked_at = now(), revoke_reason = left(COALESCE(p_reason, 'logout'), 40)
    WHERE family_id = v_family AND revoked_at IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
  END IF;
  RETURN jsonb_build_object('success', true, 'revoked', v_count);
END;
$$;
REVOKE ALL ON FUNCTION public.qn_refresh_revoke_v1(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.qn_refresh_revoke_v1(text, text) TO service_role;

-- ── Tự động thu hồi khi bị xoá khỏi quán ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.qn_trg_revoke_refresh_on_member_delete()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  UPDATE public.pos_refresh_tokens
    SET revoked_at = now(), revoke_reason = 'membership_removed'
  WHERE user_id = OLD.user_id AND store_id = OLD.store_id AND revoked_at IS NULL;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  -- Không bao giờ để việc thu hồi token làm hỏng thao tác xoá nhân viên.
  RAISE WARNING 'qn_trg_revoke_refresh_on_member_delete: %', SQLERRM;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.qn_trg_revoke_refresh_on_member_delete() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS qn_revoke_refresh_on_member_delete ON public.store_members;
CREATE TRIGGER qn_revoke_refresh_on_member_delete
  AFTER DELETE ON public.store_members
  FOR EACH ROW EXECUTE FUNCTION public.qn_trg_revoke_refresh_on_member_delete();

-- ── Tự động thu hồi khi đổi mật khẩu (trừ lần nâng cấp hash cũ -> bcrypt) ───
CREATE OR REPLACE FUNCTION public.qn_trg_revoke_refresh_on_password_change()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NEW.password_hash IS DISTINCT FROM OLD.password_hash
     AND (OLD.password_hash LIKE '$2a$%' OR OLD.password_hash LIKE '$2b$%' OR OLD.password_hash LIKE '$2y$%') THEN
    UPDATE public.pos_refresh_tokens
      SET revoked_at = now(), revoke_reason = 'password_changed'
    WHERE user_id = NEW.id AND revoked_at IS NULL;
  END IF;
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'qn_trg_revoke_refresh_on_password_change: %', SQLERRM;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.qn_trg_revoke_refresh_on_password_change() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS qn_revoke_refresh_on_password_change ON public.user_accounts;
CREATE TRIGGER qn_revoke_refresh_on_password_change
  AFTER UPDATE OF password_hash ON public.user_accounts
  FOR EACH ROW EXECUTE FUNCTION public.qn_trg_revoke_refresh_on_password_change();
