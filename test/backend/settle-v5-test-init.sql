-- SQL init script run by docker-entrypoint-initdb.d ONLY on first startup of the disposable test container.
-- Creates the anon and authenticated roles expected by the Supabase RPC security model.
-- These roles are TEST-ONLY and have no privileges except NOLOGIN.
-- File: settle-v5-test-init.sql
-- Container: settle-v5-test-postgres

-- Role: anon (used by anonymous PostgREST/RPC callers in test)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
    RAISE NOTICE 'Created test role: anon';
  ELSE
    RAISE NOTICE 'Role anon already exists, skipping.';
  END IF;
END $$;

-- Role: authenticated (used by authenticated PostgREST/RPC callers in test)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
    RAISE NOTICE 'Created test role: authenticated';
  ELSE
    RAISE NOTICE 'Role authenticated already exists, skipping.';
  END IF;
END $$;
