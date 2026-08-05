-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION: 20260731_create_pos_device_sessions.sql
-- Module: Architecture v3 POS QR Security & Session Management
-- Status: DRAFT_CREATED_NOT_EXECUTED (Draft SQL for Staging review only)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Create Migration Metadata Table FIRST to record PRE-state truth immutably
CREATE TABLE IF NOT EXISTS public.qr_v3_migration_metadata (
  key         text PRIMARY KEY,
  value       jsonb NOT NULL,
  recorded_at timestamptz DEFAULT now() NOT NULL
);

-- Record PRE-state truth for qr_requests tracking columns & v3 isolated tables/types BEFORE creating or altering
DO $$
DECLARE
  v_cols text[] := ARRAY[
    'claimed_by_user_account_id',
    'claimed_by_staff_id',
    'claimed_at',
    'confirmed_at',
    'sent_kitchen_at',
    'reject_reason',
    'idempotency_key'
  ];
  v_col text;
  v_exists boolean;
  v_tables text[] := ARRAY[
    'pos_store_bootstrap_state',
    'pos_device_sessions',
    'store_pairing_codes',
    'pos_auth_attempts',
    'qr_audit_logs'
  ];
  v_tbl text;
BEGIN
  -- Record tracking column pre-state
  FOREACH v_col IN ARRAY v_cols LOOP
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'qr_requests' AND column_name = v_col
    ) INTO v_exists;

    INSERT INTO public.qr_v3_migration_metadata (key, value, recorded_at)
    VALUES ('column_' || v_col || '_existed', jsonb_build_object('existed', v_exists), now())
    ON CONFLICT (key) DO NOTHING;
  END LOOP;

  -- Record composite type pos_session_info pre-state (exact public schema scope)
  SELECT EXISTS (
    SELECT 1 
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public' AND t.typname = 'pos_session_info'
  ) INTO v_exists;

  INSERT INTO public.qr_v3_migration_metadata (key, value, recorded_at)
  VALUES ('v3_type_pos_session_info_existed_before', jsonb_build_object('existed', v_exists), now())
  ON CONFLICT (key) DO NOTHING;

  -- Record v3 isolated tables pre-state (exact public schema scope)
  FOREACH v_tbl IN ARRAY v_tables LOOP
    SELECT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = v_tbl
    ) INTO v_exists;

    INSERT INTO public.qr_v3_migration_metadata (key, value, recorded_at)
    VALUES ('v3_table_' || v_tbl || '_existed_before', jsonb_build_object('existed', v_exists), now())
    ON CONFLICT (key) DO NOTHING;
  END LOOP;
END $$;

-- 2. ONLY AFTER PRE-state metadata is recorded: Idempotently add missing tracking columns
ALTER TABLE public.qr_requests ADD COLUMN IF NOT EXISTS claimed_by_user_account_id uuid REFERENCES public.user_accounts(id);
ALTER TABLE public.qr_requests ADD COLUMN IF NOT EXISTS claimed_by_staff_id uuid REFERENCES public.staff_members(id);
ALTER TABLE public.qr_requests ADD COLUMN IF NOT EXISTS claimed_at timestamptz;
ALTER TABLE public.qr_requests ADD COLUMN IF NOT EXISTS confirmed_at timestamptz;
ALTER TABLE public.qr_requests ADD COLUMN IF NOT EXISTS sent_kitchen_at timestamptz;
ALTER TABLE public.qr_requests ADD COLUMN IF NOT EXISTS reject_reason text;
ALTER TABLE public.qr_requests ADD COLUMN IF NOT EXISTS idempotency_key text;

-- 3. Composite Return Type for Internal Token Verification (Avoids RETURNS record)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public' AND t.typname = 'pos_session_info'
  ) THEN
    CREATE TYPE public.pos_session_info AS (
      session_id      uuid,
      store_id        uuid,
      device_id       uuid,
      principal_type  text,
      user_account_id uuid,
      staff_id        uuid
    );
  END IF;
END $$;

-- 4. Persistent Store Bootstrap State Table (Immutable per store across session lifecycles)
CREATE TABLE IF NOT EXISTS public.pos_store_bootstrap_state (
  store_id          uuid PRIMARY KEY REFERENCES public.stores(id) ON DELETE CASCADE,
  bootstrapped_at   timestamptz DEFAULT now() NOT NULL,
  bootstrapped_by   uuid NOT NULL REFERENCES public.user_accounts(id),
  initial_device_id uuid NOT NULL REFERENCES public.devices(id)
);

-- 5. POS Device Sessions Table (Token Hash-Only Storage)
CREATE TABLE IF NOT EXISTS public.pos_device_sessions (
  id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id        uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  device_id       uuid NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  principal_type  text NOT NULL CHECK (principal_type IN ('staff_member', 'user_account')),
  user_account_id uuid REFERENCES public.user_accounts(id) ON DELETE SET NULL,
  staff_id        uuid REFERENCES public.staff_members(id) ON DELETE SET NULL,
  token_hash      bytea NOT NULL UNIQUE,
  ip_address      inet,
  user_agent      text,
  created_at      timestamptz DEFAULT now() NOT NULL,
  expires_at      timestamptz NOT NULL,
  revoked_at      timestamptz,
  last_used_at    timestamptz DEFAULT now() NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_pos_single_active_session 
  ON public.pos_device_sessions(store_id, device_id) 
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_pos_sessions_lookup 
  ON public.pos_device_sessions(token_hash) 
  WHERE revoked_at IS NULL;

-- 6. Store Pairing Codes Table (Manager Pairing Flow - Max 5 min expiry)
CREATE TABLE IF NOT EXISTS public.store_pairing_codes (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id    uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  code_hash   bytea NOT NULL,
  created_by  uuid NOT NULL,
  created_at  timestamptz DEFAULT now() NOT NULL,
  expires_at  timestamptz NOT NULL,
  used_at     timestamptz
);

CREATE INDEX IF NOT EXISTS idx_pairing_codes_store 
  ON public.store_pairing_codes(store_id, expires_at) 
  WHERE used_at IS NULL;

-- 7. POS Auth Attempts Table (Brute-Force Protection with Unique Constraint on ip_address, store_code)
CREATE TABLE IF NOT EXISTS public.pos_auth_attempts (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  ip_address       inet NOT NULL,
  store_code       text NOT NULL,
  attempt_count    int DEFAULT 1 NOT NULL,
  first_attempt_at timestamptz DEFAULT now() NOT NULL,
  blocked_until    timestamptz,
  CONSTRAINT unq_pos_auth_attempt_key UNIQUE (ip_address, store_code)
);

CREATE INDEX IF NOT EXISTS idx_pos_auth_ip_store 
  ON public.pos_auth_attempts(ip_address, store_code, blocked_until);

-- 8. QR Audit Logs Table
CREATE TABLE IF NOT EXISTS public.qr_audit_logs (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id    uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  request_id  uuid,
  actor_type  text NOT NULL CHECK (actor_type IN ('customer', 'staff', 'system')),
  actor_id    uuid,
  action      text NOT NULL,
  from_status text,
  to_status   text,
  payload     jsonb,
  created_at  timestamptz DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_qr_audit_request 
  ON public.qr_audit_logs(request_id, created_at);

-- Revoke direct permissions from anon on v3 isolated tables
REVOKE ALL ON TABLE public.pos_device_sessions FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.store_pairing_codes FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.pos_auth_attempts FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.pos_store_bootstrap_state FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.qr_audit_logs FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.qr_v3_migration_metadata FROM PUBLIC, anon;
