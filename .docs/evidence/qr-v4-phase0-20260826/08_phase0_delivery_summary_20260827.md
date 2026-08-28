# QR Order V4 Phase 0 — Delivery & Gate Evidence Summary

> Date: 2026-08-27  
> Status: **Phase 1 BLOCKED — P0 containment and Disposable Staging verification required**  
> Delivery Mode: **Documentation-only gate review; no migration or deployment**

---

## 1. Data Hygiene & Security Attestation

The checks below apply to the artifacts committed in this evidence directory.
They do not claim that arbitrary PostgreSQL catalog expressions can never hold
literals. Query pack version `20260827.03` suppresses expression bodies that
require review inside the trusted SQL environment.

- [x] **Zero customer rows** collected or logged.
- [x] **Zero phone numbers** collected or logged.
- [x] **Zero password / PIN hashes** collected or logged.
- [x] **Zero secrets, service keys, DB connection strings or JWT tokens** written to repository or logs.
- [x] **Zero fake catalog or guessed schemas** manufactured.

---

## 2. Gate-by-Gate Verification & Evidence

### A. Real PostgreSQL Catalog Collection (Read-Only)
- **Executed target**: authenticated self-hosted Studio at
  `quannho-db.lpm.vn`, project endpoint `quannho.lpm.vn`.
- **Evidence**: [`07_sql_catalog_output.json`](07_sql_catalog_output.json),
  query-pack version `20260827.03`, SHA-256
  `d7da89e8a0d5b66bc727e9d04401c4136621e230cac3c7e015c896f75b7531a2`.
- **P0 finding**: RLS is disabled on `user_accounts` and `store_members` while
  `anon` has broad grants, including credential-column privileges on
  `user_accounts.password_hash`.
- **Migration history**: query returned `42P01`; the expected Supabase migration
  relation does not exist.
- **Data hygiene**: metadata only; no row samples, hash values, credentials,
  keys, expression bodies or SQL Editor history were committed.

### B. Migration Strategy Decision
- **Status**: **COMPATIBILITY + SECURITY CONTAINMENT FIRST**.
- **Candidate Proposal**: [`proposed_auth_security_containment_p0.sql`](proposed_auth_security_containment_p0.sql) is strictly retained in `evidence/qr-v4-phase0-20260826/` with header:
  `NON-DEPLOYABLE — DISPOSABLE STAGING VALIDATION REQUIRED`.
- **Deployment Isolation**: No migration has been placed into `supabase/migrations/`.

### C. Disposable Staging Verification
- **Target**: `quannho-staging.lpm.vn` (currently not resolvable / not provisioned).
- **Status**: **BLOCKED**.
- **Live RLS Tests**: 4 tests in `test/core/rls_stale_header_security_test.dart` remain explicitly **SKIPPED (4 SKIP)** until staging database is provisioned. Skipped tests are strictly NOT counted as passing.

### D. Gateway Staging Verification
- **Status**: **BLOCKED** pending deployment of staging reverse proxy and gateway service.
- **Local Prototype Status**: Python gateway server (`services/pos_gateway_server.py`) and auth service (`services/pos_jwt_auth_service.py`) are fully covered by local unit tests (35/35 PASS).

---

## 3. Local Deterministic Verification Results

| Verification Suite | Target / Command | Result | Notes |
|---|---|:---:|---|
| **Python Backend Tests** | `python3 -m unittest discover -s test/backend -p 'test_*.py' -v` | **35 PASS / 0 FAIL / 0 SKIP** | 100% deterministic local tests (replay attack, tampering, TTL, CORS allowlist, zero credential logging) |
| **Python Compilation** | `python3 -m py_compile services/*.py test/backend/*.py` | **PASS (Clean)** | All gateway and auth modules compiled without errors |
| **Flutter Core Tests** | `flutter test test/core/` | **160 PASS / 0 FAIL / 4 SKIP** | Local tests passed; the suite is not fully green because 4 live staging tests did not run |
| **Flutter Analyze (Target)** | `flutter analyze lib/core/... test/core/...` | **0 issues** | 0 warnings, 0 errors on changed onboarding & auth files |
| **Flutter Analyze (Repo)** | `flutter analyze` | **678 repo-wide warning/info findings** | This documentation-only delivery changed no Dart; no claim is made that every finding predates the wider dirty worktree |
| **Git Diff Check** | `git diff --check` | **PASS (Clean)** | Exit code 0, zero whitespace or formatting errors |
| **CodeGraph Status** | `codegraph status .` | **PASS** | 7,189 nodes, 19,836 edges; index fully up to date |
| **Graphify Status** | `graphify update .` | **PASS LOCAL** | Structural graph only; no semantic/source upload performed |

---

## 4. Acceptance Gate Decision

> 🛑 **Phase 1 Status: BLOCKED**

### Prerequisite Checklist to Open Phase 1:
1. [x] Execute sanitized catalog pack on the real self-hosted project.
2. [x] Select COMPATIBILITY + SECURITY CONTAINMENT FIRST.
3. [ ] Finalize and verify the P0 containment migration on Disposable Staging DB.
4. [ ] Run 4 live RLS tests (`flutter test test/core/rls_stale_header_security_test.dart --dart-define=ENABLE_RLS_INTEGRATION_TEST=true`) against Staging DB $\rightarrow$ 4 PASS.
5. [ ] Ensure zero P0/P1 blockers remain.
