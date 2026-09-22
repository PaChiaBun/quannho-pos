# QR Order V4 — Phase 0 audit (final local review)

> Review date: 26/08/2026  
> Verdict: **BLOCKED — Phase 1 must not start**  
> Production changes: **none**

## Review outcome

Antigravity kept the SQL outside `supabase/migrations`, but the delivery was
not acceptable unchanged. Its green unit tests exercised mocks and source
wiring, while the RPCs called by production Dart code exist only in the
non-deployable proposal. The onboarding adapter also had no application caller,
used an in-memory replay set, and queried membership with the anonymous key.

The review hardened the local prototype and corrected the report. It did not
turn proposal code into a deployed feature. External and architectural gates
remain blocked.

### 27/08/2026 documentation follow-up

The follow-up produced no production catalog and made no code, migration or
deployment change. Its local test counts were independently reproduced: 160
Flutter tests passed, 4 live staging tests were skipped, and 35 Python backend
tests passed. A credential-free probe also reproduced HTTP 404 for the intended
production gateway and unresolved DNS for the staging hostname.

The first follow-up summary overstated two points: it described the local suite
as “100% passing” despite four skipped tests, and treated every repo-wide
analyzer finding as proven pre-existing. Both statements are corrected. The
catalog pack is now version `20260827.03` and suppresses catalog expression
bodies that can contain literals; exact expressions must be reviewed only in a
trusted SQL environment and must not be committed as raw evidence.

This follow-up remains evidence-only. It does not change the BLOCKED verdict.

## Problems found and corrected

1. `UserAuthService` described Quick PIN, create-store and join-store RPCs as
   fail-closed but silently fell back to direct credential and membership table
   access when an RPC failed. All such fallbacks were removed.
2. `StoreAuthService.createStore` fell back to direct store/device inserts. It
   now requires the server RPC.
3. Legacy device onboarding inserted directly into `devices` and accepted a
   role chosen by the client. That path is now disabled until a server-authorized
   pairing contract exists.
4. The gateway allowed every browser origin on an endpoint receiving passwords
   and returning JWTs. CORS now uses the exact `POS_ALLOWED_ORIGINS` allowlist;
   unlisted origins are rejected. Native requests without an `Origin` header
   remain supported.
5. Trusted proxy handling remains restricted by `POS_TRUSTED_PROXY_IPS`.
6. Concurrent manager PIN attempts could race past the DB counter. The proposal
   now takes a transaction advisory lock before checking the PIN attempt window.
7. `07_sql_catalog_output.json` contained no query output. It was renamed to
   [`07_sql_catalog_output.template.json`](evidence/qr-v4-phase0-20260826/07_sql_catalog_output.template.json)
   so it cannot be mistaken for evidence.
8. Existing tests that required direct membership mutation were updated to assert
   the new fail-closed contract. A source regression test now rejects legacy
   Quick PIN/device-role fallbacks.
9. The onboarding exchange now fails closed unless a PostgreSQL-backed atomic
   JTI consumer is configured. In-memory replay tracking was removed because it
   races across workers/restarts. Membership lookup now runs under the signed
   onboarding principal rather than the anon bearer.
10. Onboarding JWT verification now enforces algorithm, issuer, audience,
    standard claims, ten-minute maximum scope, no `store_id`, and zero-store
    eligibility. Server/infrastructure failures no longer consume password
    attempt quota.
11. Wildcard CORS was removed again; browser origins must exactly match
    `POS_ALLOWED_ORIGINS`. Client-controlled proxy headers are not allowed by
    CORS.
12. `StaffService.removeStaff` now sends the exact two-parameter proposal RPC
    contract. `updateRole` no longer logs/broadcasts a successful role change
    after an RPC failure or malformed response.
13. The staff proposal no longer accepts client-supplied module permissions,
    no longer invents an account UUID without an account row, blocks ambiguous
    cross-store writes, and prevents managers from modifying owner/manager
    targets.
14. The newly added V4 device-pairing adapter was removed. QR Order uses the
    employee account plus store code; `device_id` remains metadata and is not a
    QR credential.
15. A later onboarding wiring pass kept one global token without an account
    binding, swallowed SecureStorage write failures, and performed create/join
    mutations before token preflight. The review now scopes the in-memory token
    to its JWT subject, propagates storage failure, and rejects missing or
    mismatched onboarding state before any database RPC.
16. Create and join UI recovery is now symmetrical: password re-authentication
    is offered only when an authoritative membership was returned but JWT
    exchange failed. Preflight failures never manufacture a local membership.

## Unresolved architecture gates

### Zero-store bootstrap principal

The Flutter client has locally integrated the zero-store onboarding state machine into
`UserAuthService.register/login/createStore/joinStoreByCode` and UI sheets (`create_store_sheet`, `join_store_sheet`).
Tokens are kept in RAM, bound to the exact account subject, applied to Supabase client under `allowOnboardingToken: true`, and
exchanged atomically for store-scoped POS JWT upon store creation/joining.
However, because the backing RPC `consume_onboarding_exchange_v4` and table `onboarding_jti_consumptions_v4`
exist only in the proposal and have not yet been executed on the production/staging database, live staging calls fail-closed
with `REPLAY_STORE_UNAVAILABLE`. This gate remains **AWAITING STAGING/DEPLOYMENT**.

### Device metadata versus employee authentication

QR Order V4 must not introduce a POS device-pairing credential. Employees use
their personal phones, authenticate with their account, and enter the store
code. Existing V3 device-session infrastructure is a separate legacy/POS topic;
it must not be listed as a QR V4 gate or wired into this flow.

### Staff membership administration

The Dart adapter is wired to `admin_create/update/revoke_*_v4`, but those RPCs
exist only in the proposal and have not been catalog-checked, migrated or run.
This is a contract prototype, not a working production feature. The canonical
multi-store key shape of `staff_members`, server-derived permissions, audit and
idempotency still require real catalog evidence before final migration.

### Catalog, rollback and idempotency

The sanitized catalog query pack was executed read-only on the authenticated
self-hosted Supabase project. Real metadata proves that no scoped QR V3/V4
tables or routines exist, but it also exposes a production P0: RLS is disabled
on `user_accounts` and `store_members`, while `anon` has broad table grants and
column privileges including `SELECT`/`UPDATE` on
`user_accounts.password_hash`. No hash values or application rows were read.

The migration-history query returned `42P01` because
`supabase_migrations.schema_migrations` does not exist. The safe strategy is
therefore **COMPATIBILITY + SECURITY CONTAINMENT FIRST**. The auth proposal still
requires catalog-derived rollback and disposable-staging validation and remains
non-deployable.

## Verification

| Gate | Result | Evidence |
|---|---:|---|
| Changed Dart files analyze | PASS | 0 issues across 6 reviewed Dart/test files; whole repo still has 678 pre-existing warning/info findings |
| Flutter core regression | PASS LOCAL | 160 passed, 4 live staging tests skipped |
| Python gateway/auth tests | PASS LOCAL | 35 passed (including replay, tampering, TTL, CORS) |
| Python compilation | PASS | auth service, route adapter and WSGI gateway |
| Legacy credential fallback scan | PASS LOCAL | no direct Quick PIN/hash fallback remains in auth methods |
| Gateway CORS/proxy tests | PASS LOCAL | POS_ALLOWED_ORIGINS and POS_TRUSTED_PROXY_IPS covered |
| Bootstrap onboarding principal & exchange | PASS CLIENT / BLOCKED SERVER | Client integrated; persistent replay RPC pending DB deployment |
| QR employee authentication | PASS AS DESIGN | account + store code; no V4 device pairing dependency |
| Staff membership RPC contract | BLOCKED SERVER | Client wired; proposal RPCs pending DB deployment |
| PostgreSQL catalog evidence | PASS WITH P0 FINDING | sanitized real output captured from self-hosted Studio; RLS/grant exposure proven |
| Auth SQL execution | NOT RUN | proposal only (proposed_auth_security_containment_p0.sql) |
| Live JWT/RLS integration | FAIL/BLOCKED | staging host unavailable/not deployed |
| QR V4 migration/test suite | NOT STARTED | correctly gated behind Phase 0 |

Skipped tests are not counted as passing evidence.

## Required next execution

1. Finalize one idempotent compatibility/containment migration and exact
   rollback from the real catalog evidence.
2. Apply it only to a disposable staging clone; verify revocation, RLS,
   cross-store isolation and preserved legitimate access.
3. Finalize and stage the onboarding JTI consumer, then verify the locally wired
   register/login/create/join flow against disposable staging with rollback and
   concurrency tests.
4. Deploy the WSGI app with a hardened server/reverse proxy, exact
   `POS_ALLOWED_ORIGINS`, `POS_TRUSTED_PROXY_IPS`, persistent rate limiting and
   a server-only `SUPABASE_SERVICE_ROLE_KEY`.
5. Execute live signed-principal, forged-token, RLS isolation and SQL proposal
   tests on disposable staging (`proposed_auth_security_containment_v4_test.sql`).
6. Only after every gate passes may QR V4 schema/RPC implementation begin.

Current authoritative status: **Phase 1 BLOCKED pending P0 containment and
Disposable Staging DB verification**.
