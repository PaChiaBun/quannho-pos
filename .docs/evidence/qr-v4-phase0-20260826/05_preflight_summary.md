# QR V4 PHASE 0B — EVIDENCE REVIEW / INVALIDATION NOTICE

> Review time: 26/08/2026  
> Verdict: **PHASE 0B FAILED — EVIDENCE IS PARTIAL AND CANNOT OPEN PHASE 1**

## 1. What Antigravity actually executed

Antigravity queried the production PostgREST endpoint and stored HTTP responses for table and RPC names. It also checked that the configured POS JWT gateway route returns HTTP 404.

The probe did **not** execute the required PostgreSQL catalog queries from the Phase 0 audit. There is no captured output from:

- `supabase_migrations.schema_migrations`;
- `pg_class`, `pg_namespace`, `pg_proc` or `pg_constraint`;
- `information_schema.columns`;
- `pg_policies`, grants or routine ACLs;
- a signed staff JWT and a read-only principal probe.

Therefore the description “PostgREST probing & catalog cross-check” was inaccurate. Only the PostgREST portion was performed.

## 2. Evidence retained

- `02_rpc_probe.json`: retained as evidence of observed PostgREST behavior only. A `PGRST202` response does not independently prove that a routine is absent from PostgreSQL.
- `04_auth_and_pos_jwt_probe.json`: retained because it confirms the intended production gateway URL returned 404 and the default build URL is empty. This is evidence that the staff principal foundation is **not deployed**, not evidence that `auth.uid()` works.

## 3. Evidence removed for security

The following untracked artifacts were deleted during review:

- `01_tables_probe.json`
- `03_core_schema_and_types.json`

Reason: both files stored sample production rows. They included phone numbers and `user_accounts.password_hash` values in plain JSON files with ordinary file permissions. Password hashes and personal data must never be committed as architecture evidence.

The deleted files are not recoverable from Git because they were untracked. Their deletion does not modify production data.

Future evidence must contain catalog metadata only. It must never contain row samples, credentials, hashes, tokens, API keys, phone numbers, emails or customer/staff data.

## 4. What the REST responses prove

They prove only the following observed behavior at the recorded time:

- the client used by the probe received HTTP 200 for several public-schema resources;
- it received `PGRST205` for requested table names not visible through that PostgREST context;
- it received `PGRST202` for requested routine signatures not visible through that PostgREST context;
- `/api/auth/pos-jwt` returned HTTP 404.

They do **not** prove:

- whether the QR V3 migrations exist in migration history;
- whether tables/routines exist but are hidden by grants or schema cache;
- column nullability, defaults, FK, CHECK, UNIQUE, indexes or triggers;
- RLS policies and grants;
- that `auth.uid()` is populated for a logged-in Quán Nhỏ staff session;
- that a clean V4 installation is safe.

## 5. Security finding discovered by the probe

The probe obtained `user_accounts.password_hash` and phone data before writing
the deleted artifacts. Source inspection confirmed that the **pre-review**
Flutter login flow directly selected `user_accounts.password_hash` before a
server-signed POS JWT existed. The reviewed local code no longer does this, but
the server RPC and RLS cutover are not deployed. Repository SQL also contains
legacy scripts that disable RLS and grant broad access on `user_accounts` and
`store_members`.

This is a **P0 authentication exposure in the observed deployed model**. The
local review removed direct password-hash access and made authentication
fail-closed, but deployment/RLS evidence is still missing. The existing SHA-256
scheme uses a static salt embedded in legacy clients, so exposed hashes may be
attacked offline. QR V4 staff RPCs must not be built on top of this principal
model.

Required containment and remediation:

1. Do not publish or commit the removed evidence.
2. Verify production grants/RLS through catalog queries without selecting row data.
3. Implement server-side password verification through the POS JWT gateway; do not return hashes to Flutter.
4. Revoke direct anon/authenticated access to password hashes and sensitive membership writes.
5. Remove production login paths that query hashes, auto-provision accounts from a phone lookup, or accept a hard-coded reviewer owner session.
6. Migrate password hashing to Argon2id or bcrypt server-side and force credential reset after containment.
7. Deploy/test the strict JWT/RLS foundation on staging before enabling staff QR RPCs.

Local verification after the final review: the backend POS JWT/route/gateway
suite passed 22 tests. The complete `flutter test test/core/` gate passed 146
tests; 4 live RLS tests were skipped because the staging host is unavailable.
The missing pieces are deployment/integration, real signed-principal/RLS
evidence, a deployable zero-store onboarding principal, and a server-side
replacement for staff membership administration. Device pairing is not a QR
Order credential; employees use their account plus store code.

## 6. Correct gate result

| Gate | Result | Reason |
|---|---:|---|
| Fresh production evidence | FAIL | REST evidence exists, catalog evidence does not |
| Migration strategy | FAIL | migration history was not queried |
| Core schema/FK/constraints/indexes | FAIL | inferred from sample values, not catalog |
| `product_topping_links` classification | FAIL | REST 404 cannot distinguish absent/hidden/cache |
| Staff principal | FAIL | gateway 404; `auth.uid()` not demonstrated |
| Session/order model | DESIGN ONLY | selected in docs but not checked against real constraints |
| State machine | DESIGN ONLY | selected but no SQL/Dart implementation or tests |
| TTL/payment permission | PASS AS DESIGN | business rule is locked |
| V3-to-V4 test mapping | PASS AS PLAN | files mapped but no V4 tests created or run |
| Atomic checkout settlement | FAIL | settlement schema and DB uniqueness contract are incomplete |

Overall result: **2 design/planning gates pass, 2 are design-only, 6 fail. Phase 1 is blocked.**

## 7. Required Phase 0C run

Perform one evidence-only remediation run:

1. Use a trusted SQL connection or Supabase SQL editor to run the catalog query pack in `.docs/qr-v4-phase0-audit.md`.
2. Save only sanitized metadata output with timestamp and project reference.
3. Prove the staff JWT principal on staging: signed token, expected claims, `auth.uid()`, active membership and forged-header rejection.
4. Add the missing settlement and staff-origin order contracts to the final schema diff.
5. Re-run the gate. Do not write QR V4 migrations until every evidence gate passes.
