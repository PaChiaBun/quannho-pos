-- Migration: 20260930_ban_zones_tables_created_at_defaults.sql
-- Description: Add default epoch milliseconds to created_at and updated_at on ban_zones and ban_dining_tables
-- to prevent 23502 (NOT NULL constraint violation) when inserts don't provide explicit timestamps.

ALTER TABLE public.ban_zones 
    ALTER COLUMN created_at SET DEFAULT (EXTRACT(EPOCH FROM now()) * 1000)::bigint,
    ALTER COLUMN updated_at SET DEFAULT (EXTRACT(EPOCH FROM now()) * 1000)::bigint;

ALTER TABLE public.ban_dining_tables 
    ALTER COLUMN created_at SET DEFAULT (EXTRACT(EPOCH FROM now()) * 1000)::bigint,
    ALTER COLUMN updated_at SET DEFAULT (EXTRACT(EPOCH FROM now()) * 1000)::bigint;
