-- Migration 02: POS Device Sessions, Pairing Codes & Auth Rate-Limiting DDL
-- File: supabase/migrations/20260814091000_qr_v3_02_pos_sessions_and_pairing.sql

-- Preflight
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pos_device_sessions') THEN
    RAISE EXCEPTION 'MIGRATION_02_PREFLIGHT_FAIL: Table pos_device_sessions already exists';
  END IF;
END $$;

-- 6. pos_device_sessions
CREATE TABLE public.pos_device_sessions (
  id              uuid NOT NULL DEFAULT gen_random_uuid(),
  token_hash      bytea NOT NULL,
  device_id       uuid NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  store_id        uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  staff_id        uuid REFERENCES public.staff_members(id) ON DELETE SET NULL,
  user_account_id uuid REFERENCES public.user_accounts(id) ON DELETE SET NULL,
  expires_at      timestamptz NOT NULL,
  revoked_at      timestamptz,
  last_seen_at    timestamptz NOT NULL DEFAULT now(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_pos_device_sessions PRIMARY KEY (id),
  CONSTRAINT uq_pos_device_sessions_token_hash UNIQUE (token_hash),
  CONSTRAINT chk_pos_session_principal CHECK (
    (user_account_id IS NOT NULL AND staff_id IS NULL) OR
    (user_account_id IS NULL AND staff_id IS NOT NULL)
  )
);
CREATE INDEX idx_pos_device_sessions_lookup ON public.pos_device_sessions(token_hash, store_id);

CREATE UNIQUE INDEX idx_pos_single_active_session
ON public.pos_device_sessions(store_id, device_id)
WHERE revoked_at IS NULL;

ALTER TABLE public.pos_device_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_device_sessions FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.pos_device_sessions FROM PUBLIC, anon, authenticated;

-- 7. pos_store_bootstrap_state
CREATE TABLE public.pos_store_bootstrap_state (
  store_id          uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  bootstrapped_at   timestamptz NOT NULL DEFAULT now(),
  bootstrapped_by   uuid NOT NULL REFERENCES public.user_accounts(id) ON DELETE RESTRICT,
  initial_device_id uuid NOT NULL REFERENCES public.devices(id) ON DELETE RESTRICT,
  CONSTRAINT pk_pos_store_bootstrap_state PRIMARY KEY (store_id)
);

ALTER TABLE public.pos_store_bootstrap_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_store_bootstrap_state FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.pos_store_bootstrap_state FROM PUBLIC, anon, authenticated;

-- 8. store_pairing_codes
CREATE TABLE public.store_pairing_codes (
  id                uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id          uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  pairing_code_hash bytea NOT NULL,
  device_role       text NOT NULL DEFAULT 'staff',
  created_by_user   uuid REFERENCES public.user_accounts(id) ON DELETE SET NULL,
  created_by_staff  uuid REFERENCES public.staff_members(id) ON DELETE SET NULL,
  expires_at        timestamptz NOT NULL,
  used_at           timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_store_pairing_codes PRIMARY KEY (id),
  CONSTRAINT uq_store_pairing_codes_hash UNIQUE (pairing_code_hash),
  CONSTRAINT chk_store_pairing_role CHECK (device_role IN ('staff', 'kds', 'cashier', 'manager')),
  CONSTRAINT chk_store_pairing_creator_principal CHECK (
    (created_by_user IS NOT NULL AND created_by_staff IS NULL) OR
    (created_by_user IS NULL AND created_by_staff IS NOT NULL)
  )
);
CREATE INDEX idx_store_pairing_codes_lookup ON public.store_pairing_codes(store_id, expires_at);

ALTER TABLE public.store_pairing_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_pairing_codes FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.store_pairing_codes FROM PUBLIC, anon, authenticated;

-- 9. pos_auth_attempts
CREATE TABLE public.pos_auth_attempts (
  id              uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id        uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  attempt_type    text NOT NULL,
  identifier_hash bytea NOT NULL,
  is_success      boolean NOT NULL,
  ip_address      text NOT NULL DEFAULT '0.0.0.0',
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pk_pos_auth_attempts PRIMARY KEY (id),
  CONSTRAINT chk_pos_auth_attempt_type CHECK (attempt_type IN ('owner_password', 'manager_quick_pin', 'staff_pin', 'pairing_code', 'bootstrap'))
);
CREATE INDEX idx_pos_auth_attempts_rate ON public.pos_auth_attempts(store_id, attempt_type, identifier_hash, ip_address, created_at);

ALTER TABLE public.pos_auth_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_auth_attempts FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.pos_auth_attempts FROM PUBLIC, anon, authenticated;

-- Postflight Verification for ALL 4 created tables
DO $$
DECLARE
  v_tbl text;
BEGIN
  FOR v_tbl IN VALUES ('pos_device_sessions'), ('pos_store_bootstrap_state'), ('store_pairing_codes'), ('pos_auth_attempts') LOOP
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = v_tbl) THEN
      RAISE EXCEPTION 'MIGRATION_02_POSTFLIGHT_FAIL: Table public.% missing', v_tbl;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = v_tbl AND c.relrowsecurity = true AND c.relforcerowsecurity = true
    ) THEN
      RAISE EXCEPTION 'MIGRATION_02_POSTFLIGHT_FAIL: RLS not enabled/forced on public.%', v_tbl;
    END IF;
  END LOOP;
END $$;
