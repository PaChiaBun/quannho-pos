# QR Order V4 — Real Catalog Analysis (2026-08-27)

## Outcome

The sanitized read-only catalog pack was executed against the authenticated
self-hosted Supabase Studio at `quannho-db.lpm.vn` for project endpoint
`quannho.lpm.vn`. No application rows, credentials, hash values, expression
bodies, API keys or connection strings were collected.

Phase 1 remains **BLOCKED**. The correct path is
**COMPATIBILITY + SECURITY CONTAINMENT FIRST**, not a destructive clean install.

## Proven catalog facts

- Fifteen relevant legacy/core tables exist. No queried QR V3/V4, handoff,
  settlement or `product_topping_links` table exists.
- No matching QR V3/V4 routines or V4 account-auth routines exist.
- Migration-history query failed with PostgreSQL `42P01` because
  `supabase_migrations.schema_migrations` does not exist. This is an error, not
  evidence that migrations never ran.
- `public.user_accounts` and `public.store_members` have RLS disabled.
- `anon` has `DELETE`, `INSERT`, `REFERENCES`, `SELECT`, `TRIGGER`, `TRUNCATE`
  and `UPDATE` on `staff_members`, `store_members` and `user_accounts`.
- `anon` has `INSERT`, `REFERENCES`, `SELECT` and `UPDATE` column privileges on
  `user_accounts.password_hash`. This records metadata only; no hash value was
  queried or committed.
- Thirty-one policy definitions were found, but policies do not enforce
  isolation on a table while RLS is disabled.
- Thirty indexes and zero non-internal triggers were found on the scoped tables.

## P0 remediation direction

Do not edit production ad hoc. Produce one idempotent containment migration,
derive its rollback from this live catalog, and validate it first on a disposable
copy of the same schema/data shape. The migration must at minimum:

1. Revoke broad `anon` access from `user_accounts`, `store_members` and
   `staff_members`, including column grants on credential fields.
2. Enable RLS on `user_accounts` and `store_members` and verify that existing
   policies are correct before relying on them.
3. Replace direct client credential/membership mutations with narrowly scoped,
   authenticated server/RPC contracts and explicit grants.
4. Preserve existing production tables and canonical orders; do not drop or
   recreate live core tables merely to install QR V4.
5. Prove rollback, idempotency, cross-store isolation, forged-token rejection,
   replay resistance and manager/owner authorization on disposable staging.

## Gate decision

Catalog execution is complete, but Phase 1 cannot open until the containment
migration passes staging and the migration-history/rollback strategy is resolved.
Production was not mutated during this audit.
