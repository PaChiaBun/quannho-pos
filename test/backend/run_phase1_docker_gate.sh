#!/usr/bin/env bash
# =============================================================================
# run_phase1_docker_gate.sh  (Hardened V3 — COMPOSE_TOUCHED state machine)
# =============================================================================
# STATE MACHINE:
#   COMPOSE_TOUCHED=0  — invocation has NOT claimed the compose project
#   COMPOSE_TOUCHED=1  — set immediately BEFORE compose up, after ALL preflights
#                        and ALL collision checks pass
#
# CLEANUP CONTRACT:
#   - cleanup() is bound to EXIT trap; _signal_handler bound to INT TERM
#   - COMPOSE_TOUCHED=0 → skip compose down (no ownership)
#   - COMPOSE_TOUCHED=1 → run compose down exactly once
#   - cleanup failure → GATE_EXIT_CODE=1 (overrides passing runner result)
#   - "Cleanup complete" printed ONLY when compose down exits 0
#   - SIGTERM/SIGINT → _TERM_RECEIVED=1 → cleanup forces GATE_EXIT_CODE=1
#   - Anti-reentry: CLEANUP_CALLED guard + trap reset at top of cleanup
#
# SAFETY GUARANTEES:
#   - Never reads DATABASE_URL or STAGING_DATABASE_URL
#   - Fails if either is set (safety violation = exit 1)
#   - Only connects to 127.0.0.1:15432 (localhost-bound Docker port)
#   - Collision check fails-closed; never destroys another invocation's resources
#   - Fails-closed (exit 2) if Docker/Podman/daemon/compose unavailable
#   - Runner called exactly once via direct python3; no pytest fallback
#
# EXIT CODES:
#   0  Runtime gate PASSED and cleanup PASSED
#   1  Gate FAILED, cleanup FAILED, safety violation, or signal termination
#   2  BLOCKED: runtime unavailable or prerequisite missing
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.settle-v5-test.yml"
COMPOSE_PROJECT="settle-v5-test"       # Never sourced from environment
CONTAINER_NAME="settle-v5-test-postgres"
NETWORK_NAME="settle-v5-test-net"
VOLUME_NAME="settle-v5-test-pgdata"
LOCK_DIR="${TMPDIR:-/tmp}/settle-v5-test-gate.lock"
TEST_HOST="127.0.0.1"
TEST_PORT="15432"
TEST_USER="settle_v5_test_user"
TEST_PASS="settle_v5_test_pass_local_only"
TEST_DB="postgres"

# --- State variables ---
COMPOSE_TOUCHED=0  # 1 ONLY after ALL preflights pass, immediately before compose up
GATE_EXIT_CODE=1   # Default FAIL; updated by runner ($?) or blocked checks
CLEANUP_CALLED=0   # Anti-reentry guard
_TERM_RECEIVED=0   # Set by _signal_handler; causes cleanup to force exit 1
LOCK_ACQUIRED=0    # 1 only when this invocation owns LOCK_DIR

# =============================================================================
# SIGNAL HANDLER — registered for INT and TERM (not EXIT)
# Calling exit here triggers the EXIT trap (cleanup).
# =============================================================================
_signal_handler() {
    _TERM_RECEIVED=1
    exit 1
}

# =============================================================================
# CLEANUP — registered for EXIT trap only
# Runs on: normal exit, set -e abort, explicit exit N, and via _signal_handler
# =============================================================================
cleanup() {
    # Anti-reentry: both guard and trap reset
    [[ "${CLEANUP_CALLED}" == "1" ]] && return
    CLEANUP_CALLED=1
    trap - EXIT INT TERM   # Prevent any further signal from re-entering cleanup

    echo ""
    echo "=== [Cleanup] Tearing down disposable test environment ==="

    # Signal termination overrides gate exit code regardless of runner result
    if [[ "${_TERM_RECEIVED}" == "1" ]]; then
        GATE_EXIT_CODE=1
    fi

    # Only run compose down if this invocation actually claimed the compose project.
    # COMPOSE_TOUCHED=0 means preflights or collision checks failed before compose up
    # was attempted; we must not touch another invocation's resources.
    if [[ "${COMPOSE_TOUCHED}" != "1" ]]; then
        echo "  Compose project was not touched by this invocation; skipping cleanup."
    else
        # Integrity check: verify compose file still names our project (not tampered)
        if ! grep -q "name: settle-v5-test" "${COMPOSE_FILE}" 2>/dev/null; then
            echo "  WARNING: Compose file does not contain expected project name 'settle-v5-test'."
            echo "  Manual cleanup required:"
            echo "    ${DOCKER_CMD:-docker} compose -f test/backend/docker-compose.settle-v5-test.yml -p settle-v5-test down -v"
            GATE_EXIT_CODE=1
        else
            # Run compose down exactly once; scope is precisely the compose project
            echo "  Running: ${DOCKER_CMD} compose -f [file] -p settle-v5-test down -v --remove-orphans"
            if "${DOCKER_CMD}" compose \
                -f "${COMPOSE_FILE}" \
                -p "settle-v5-test" \
                down -v --remove-orphans 2>&1; then
                echo "  ✓ Cleanup complete: containers, networks, volumes for project 'settle-v5-test' removed"
            else
                echo "  FATAL: Cleanup INCOMPLETE. Manual cleanup required:"
                echo "    ${DOCKER_CMD} compose -f test/backend/docker-compose.settle-v5-test.yml -p settle-v5-test down -v"
                GATE_EXIT_CODE=1   # Override: cleanup failure makes gate fail even if runner passed
            fi
        fi
    fi

    # Release only the lock acquired by this invocation. The lock directory is
    # deliberately empty, so rmdir cannot remove unrelated files recursively.
    if [[ "${LOCK_ACQUIRED}" == "1" ]]; then
        if rmdir "${LOCK_DIR}" 2>/dev/null; then
            LOCK_ACQUIRED=0
            echo "  ✓ Invocation lock released"
        else
            echo "  FATAL: Could not release invocation lock: ${LOCK_DIR}"
            echo "  Verify no gate process is running, then remove this empty directory manually."
            GATE_EXIT_CODE=1
        fi
    fi

    exit "${GATE_EXIT_CODE}"
}

trap cleanup EXIT
trap _signal_handler INT TERM

# =============================================================================
# RUNTIME CHECK — detect Docker or Podman binary AND running daemon
# =============================================================================
echo "=== [Phase 1 Docker Gate] Checking container runtime availability ==="

DOCKER_CMD=""
if command -v docker >/dev/null 2>&1; then
    DOCKER_CMD="docker"
    if ! docker info >/dev/null 2>&1; then
        echo "BLOCKED: 'docker' binary found but Docker daemon is not running or not accessible."
        echo "Please start Docker Desktop / dockerd and try again."
        GATE_EXIT_CODE=2
        exit 2
    fi
    echo "  ✓ Found and reachable: docker ($(docker --version 2>/dev/null))"
elif command -v podman >/dev/null 2>&1; then
    DOCKER_CMD="podman"
    if ! podman info >/dev/null 2>&1; then
        echo "BLOCKED: 'podman' binary found but Podman daemon is not running or not accessible."
        GATE_EXIT_CODE=2
        exit 2
    fi
    echo "  ✓ Found and reachable: podman ($(podman --version 2>/dev/null))"
else
    echo ""
    echo "BLOCKED: Neither 'docker' nor 'podman' found on PATH."
    echo "Please install Docker Desktop (https://www.docker.com/products/docker-desktop/) or Podman,"
    echo "then re-run: bash test/backend/run_phase1_docker_gate.sh"
    GATE_EXIT_CODE=2
    exit 2
fi

# Verify compose subcommand exists (binary alone is not sufficient)
if ! "${DOCKER_CMD}" compose version >/dev/null 2>&1; then
    echo "BLOCKED: '${DOCKER_CMD} compose' subcommand not available."
    echo "Please install Docker Compose v2 plugin and try again."
    GATE_EXIT_CODE=2
    exit 2
fi
echo "  ✓ compose subcommand: $(${DOCKER_CMD} compose version 2>/dev/null | head -1)"

# =============================================================================
# PYTHON / DEPENDENCY CHECK
# =============================================================================
echo ""
echo "=== [Preflight] Checking Python dependencies ==="

if ! command -v python3 >/dev/null 2>&1; then
    echo "BLOCKED: python3 not found on PATH."
    GATE_EXIT_CODE=2
    exit 2
fi
echo "  ✓ python3: $(python3 --version)"

if ! python3 -c "import psycopg2" 2>/dev/null; then
    echo "BLOCKED: psycopg2 not available in python3. Install with:"
    echo "  pip3 install psycopg2-binary"
    GATE_EXIT_CODE=2
    exit 2
fi
echo "  ✓ psycopg2 available"

# =============================================================================
# REQUIRED FILE CHECK
# =============================================================================
echo ""
echo "=== [Safety Check] Verifying required files ==="

REQUIRED_FILES=(
    "${COMPOSE_FILE}"
    "${SCRIPT_DIR}/settle-v5-test-init.sql"
    "${SCRIPT_DIR}/run_phase1_real_pg_gate.py"
    "${REPO_ROOT}/supabase/migrations/20260902_atomic_settlement_v5.sql"
    "${REPO_ROOT}/supabase/tests/settle_v5_concurrency_test.sql"
    "${SCRIPT_DIR}/test_settlement_v5_concurrency_real_pg.py"
)
for f in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        echo "BLOCKED: Required file missing: $f"
        GATE_EXIT_CODE=2
        exit 2
    fi
    echo "  ✓ Found: $(basename "$f")"
done

# SAFETY: Refuse to run if production environment variables are present
# (indicates the shell might be pointing at a live database)
if [[ -n "${DATABASE_URL:-}" ]]; then
    echo "BLOCKED: DATABASE_URL is set in environment. Refusing to run — may be connected to live database."
    echo "Unset it: unset DATABASE_URL"
    GATE_EXIT_CODE=1
    exit 1
fi
if [[ -n "${STAGING_DATABASE_URL:-}" ]]; then
    echo "BLOCKED: STAGING_DATABASE_URL is set in environment. Refusing to run."
    echo "Unset it: unset STAGING_DATABASE_URL"
    GATE_EXIT_CODE=1
    exit 1
fi

# =============================================================================
# COLLISION CHECK — fail-closed; never destroys another invocation's resources
# All four checks must pass before COMPOSE_TOUCHED=1 is set.
# =============================================================================
echo ""
echo "=== [Collision Check] Verifying project resources are free ==="

# Atomic cross-process ownership lock. This closes the check-then-create race
# where two invocations could both observe an empty project before compose up.
if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
    echo "BLOCKED: Another Phase 1 Docker gate invocation owns the lock: ${LOCK_DIR}"
    echo "If no gate process is running, remove the stale empty lock directory manually."
    GATE_EXIT_CODE=2
    exit 2
fi
LOCK_ACQUIRED=1
echo "  ✓ Invocation lock acquired"

# 1. Port check via Python socket — cross-platform (macOS/Linux; no lsof/ss dependency)
#    If port bind succeeds, port is free. If it raises OSError, port is in use.
if ! python3 -c "
import socket, sys
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 0)
    s.bind(('127.0.0.1', 15432))
    s.close()
    sys.exit(0)
except OSError:
    sys.exit(1)
" 2>/dev/null; then
    echo "BLOCKED: Port ${TEST_PORT} (${TEST_HOST}:${TEST_PORT}) is already in use."
    echo "Another invocation of this gate may be running."
    echo "If it was a previous failed run, clean up manually:"
    echo "  ${DOCKER_CMD} compose -f test/backend/docker-compose.settle-v5-test.yml -p settle-v5-test down -v"
    GATE_EXIT_CODE=2
    exit 2
fi
echo "  ✓ Port ${TEST_PORT} is free"

# 2. Container collision — any container with our name means conflict
if "${DOCKER_CMD}" inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    echo "BLOCKED: Container '${CONTAINER_NAME}' already exists."
    echo "Another invocation may be running. Manual cleanup (if safe):"
    echo "  ${DOCKER_CMD} compose -f test/backend/docker-compose.settle-v5-test.yml -p settle-v5-test down -v"
    GATE_EXIT_CODE=2
    exit 2
fi
echo "  ✓ Container '${CONTAINER_NAME}' does not exist"

# 3. Network collision
if "${DOCKER_CMD}" network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
    echo "BLOCKED: Network '${NETWORK_NAME}' already exists."
    echo "Manual cleanup (if safe):"
    echo "  ${DOCKER_CMD} compose -f test/backend/docker-compose.settle-v5-test.yml -p settle-v5-test down -v"
    GATE_EXIT_CODE=2
    exit 2
fi
echo "  ✓ Network '${NETWORK_NAME}' does not exist"

# 4. Volume collision
if "${DOCKER_CMD}" volume inspect "${VOLUME_NAME}" >/dev/null 2>&1; then
    echo "BLOCKED: Volume '${VOLUME_NAME}' already exists."
    echo "Manual cleanup (if safe):"
    echo "  ${DOCKER_CMD} compose -f test/backend/docker-compose.settle-v5-test.yml -p settle-v5-test down -v"
    GATE_EXIT_CODE=2
    exit 2
fi
echo "  ✓ Volume '${VOLUME_NAME}' does not exist"

# 5. Compose project-label collision catches orphan containers whose explicit
# name differs but which would still be affected by --remove-orphans.
if ! PROJECT_CONTAINERS=$("${DOCKER_CMD}" ps -a \
    --filter "label=com.docker.compose.project=${COMPOSE_PROJECT}" \
    --format '{{.ID}}' 2>/dev/null); then
    echo "BLOCKED: Unable to inspect existing Compose project resources."
    GATE_EXIT_CODE=2
    exit 2
fi
if [[ -n "${PROJECT_CONTAINERS}" ]]; then
    echo "BLOCKED: Existing container resources belong to Compose project '${COMPOSE_PROJECT}'."
    echo "Manual cleanup (only after confirming no other gate is running):"
    echo "  ${DOCKER_CMD} compose -f test/backend/docker-compose.settle-v5-test.yml -p settle-v5-test down -v"
    GATE_EXIT_CODE=2
    exit 2
fi
echo "  ✓ No existing containers carry project label '${COMPOSE_PROJECT}'"

# =============================================================================
# CLAIM OWNERSHIP — all preflights and collision checks passed
# COMPOSE_TOUCHED=1 authorizes cleanup to run compose down.
# Set BEFORE compose up so that even a partial startup is cleaned up.
# =============================================================================
COMPOSE_TOUCHED=1

# =============================================================================
# START CONTAINER
# =============================================================================
echo ""
echo "=== [Docker] Starting disposable test PostgreSQL 16 container ==="
echo "  Compose file:  ${COMPOSE_FILE}"
echo "  Project name:  ${COMPOSE_PROJECT}"
echo "  Container:     ${CONTAINER_NAME}"
echo "  Bound to:      ${TEST_HOST}:${TEST_PORT} (localhost only)"
echo "  Network:       ${NETWORK_NAME} (internal=true, no outbound)"

# If compose up fails (partial creation), the EXIT trap will still run compose down
# because COMPOSE_TOUCHED=1. set -e will abort here and trigger the trap.
"${DOCKER_CMD}" compose \
    -f "${COMPOSE_FILE}" \
    -p "${COMPOSE_PROJECT}" \
    up -d --force-recreate --remove-orphans
echo "  ✓ compose up completed"

# =============================================================================
# HEALTHCHECK POLL
# =============================================================================
echo ""
echo "=== [Healthcheck] Waiting for PostgreSQL to be ready ==="
MAX_WAIT=60
ELAPSED=0
HEALTHY=0
while [[ ${ELAPSED} -lt ${MAX_WAIT} ]]; do
    HEALTH_STATUS=$("${DOCKER_CMD}" inspect \
        --format '{{.State.Health.Status}}' \
        "${CONTAINER_NAME}" 2>/dev/null || echo "not_found")
    if [[ "${HEALTH_STATUS}" == "healthy" ]]; then
        HEALTHY=1
        break
    fi
    echo "  Waiting... (${ELAPSED}s / ${MAX_WAIT}s, status: ${HEALTH_STATUS})"
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

if [[ "${HEALTHY}" != "1" ]]; then
    echo "FATAL: PostgreSQL container did not become healthy within ${MAX_WAIT}s."
    echo "Container logs:"
    "${DOCKER_CMD}" logs "${CONTAINER_NAME}" 2>&1 | tail -20
    GATE_EXIT_CODE=1
    exit 1
fi
echo "  ✓ PostgreSQL is healthy at ${TEST_HOST}:${TEST_PORT}"

# Safety assertion: host must be localhost (belt-and-suspenders)
if [[ "${TEST_HOST}" != "127.0.0.1" && "${TEST_HOST}" != "localhost" && "${TEST_HOST}" != "::1" ]]; then
    echo "FATAL: TEST_HOST '${TEST_HOST}' is not localhost. Refusing to connect."
    GATE_EXIT_CODE=1
    exit 1
fi
echo "  ✓ Target host: ${TEST_HOST}:${TEST_PORT} (localhost confirmed)"

# =============================================================================
# CONFIGURE GATE RUNNER ENVIRONMENT
# =============================================================================
echo ""
echo "=== [Config] Setting gate runner environment ==="

LOCAL_TEST_DATABASE_URL="postgresql://${TEST_USER}:${TEST_PASS}@${TEST_HOST}:${TEST_PORT}/${TEST_DB}"
export LOCAL_TEST_DATABASE_URL
export SETTLE_V5_ALLOW_STAGING_MUTATION="YES"
export IS_ISOLATED_LOCAL_TEST_CLUSTER="YES"
export AUTO_PROVISION_LOCAL_TEST_ROLES="YES"

# Explicitly unset production-adjacent vars so runner cannot accidentally inherit them
unset DATABASE_URL 2>/dev/null || true
unset STAGING_DATABASE_URL 2>/dev/null || true

echo "  ✓ LOCAL_TEST_DATABASE_URL: postgresql://***:***@${TEST_HOST}:${TEST_PORT}/${TEST_DB}"
echo "  ✓ SETTLE_V5_ALLOW_STAGING_MUTATION=YES"
echo "  ✓ IS_ISOLATED_LOCAL_TEST_CLUSTER=YES"
echo "  ✓ AUTO_PROVISION_LOCAL_TEST_ROLES=YES"

# =============================================================================
# RUN GATE — exactly once, direct python3, stderr preserved
# =============================================================================
echo ""
echo "=== [Runtime Gate] Running run_phase1_real_pg_gate.py ==="
echo "    Repository root: ${REPO_ROOT}"
echo ""

# Disable errexit around runner so cleanup trap always fires (not just on success)
set +e
python3 "${SCRIPT_DIR}/run_phase1_real_pg_gate.py"
GATE_EXIT_CODE=$?
set -e

echo ""
if [[ "${GATE_EXIT_CODE}" == "0" ]]; then
    echo "==================================================================="
    echo "✅ PHASE 1 RUNTIME GATE: ALL TESTS PASSED"
    echo "   Exit code: 0"
    echo "==================================================================="
else
    echo "==================================================================="
    echo "❌ PHASE 1 RUNTIME GATE: FAILED"
    echo "   Exit code: ${GATE_EXIT_CODE}"
    echo "==================================================================="
fi

# Cleanup runs automatically via trap EXIT
