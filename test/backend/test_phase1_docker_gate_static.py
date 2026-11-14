#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Static / Source-Invariant Tests for Phase 1 Docker Gate Artifacts (V3)

These tests verify source-level structural invariants — they do NOT simulate runtime behavior.
Behavioral runtime verification is in test_phase1_docker_gate_behavior.py.

Tests 01–14: Compose file and init SQL invariants
Tests 15–27: Shell script structural invariants (ownership state machine)

01. Compose: Port only bound to 127.0.0.1 (no bare external binding).
02. Compose: No production domain or env var names in active YAML lines.
03. Compose: Healthcheck block present.
04. Compose: Resource names use settle-v5-test prefix.
05. Compose: Init SQL mounted read-only (:ro).
06. Script: trap cleanup EXIT and trap _signal_handler INT TERM present.
07. Script: GATE_EXIT_CODE=$? captured and propagated via exit "${GATE_EXIT_CODE}".
08. Script: BLOCKED message with exit 2 when Docker/Podman absent.
09. Script: Never reads DATABASE_URL or STAGING_DATABASE_URL (only presence-checks them).
10. Script: compose down -v targets exactly project settle-v5-test.
11. Script: cleanup verifies compose project name with literal grep before down.
12. Script: No rm -rf with variable targets.
13. Init SQL: anon role created idempotently.
14. Init SQL: authenticated role created idempotently.
15. Script: COMPOSE_TOUCHED state machine — init=0, set=1 before compose up, guard in cleanup.
16. Script: cleanup prints "Cleanup INCOMPLETE" on failure, not "Cleanup complete".
17. Script: _TERM_RECEIVED flag overrides GATE_EXIT_CODE in cleanup.
18. Script: trap reset (trap - EXIT INT TERM) inside cleanup (anti-reentry).
19. Script: Collision checks present for container, network, volume, and Python socket port.
20. Script: Runner called exactly once via direct python3 (no pytest fallback).
21. Compose: Network is internal: true (no outbound from DB container).
22. Script: _signal_handler function is defined.
23. Script: Daemon reachability verified (docker info / podman info).
24. Script: compose subcommand verified before use (compose version).
25. Script: COMPOSE_TOUCHED=1 is ordered BEFORE compose up in source.
26. Script: Atomic invocation lock is acquired and released without recursive deletion.
27. Script: Compose project-label collision is checked before ownership claim.
"""

import os
import re
import sys
import unittest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
COMPOSE_FILE = os.path.join(SCRIPT_DIR, "docker-compose.settle-v5-test.yml")
SHELL_SCRIPT = os.path.join(SCRIPT_DIR, "run_phase1_docker_gate.sh")
INIT_SQL_FILE = os.path.join(SCRIPT_DIR, "settle-v5-test-init.sql")


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


# =============================================================================
# COMPOSE FILE
# =============================================================================
class TestDockerComposeFile(unittest.TestCase):

    def setUp(self):
        self.compose = read_file(COMPOSE_FILE)

    def test_01_postgres_bound_only_to_localhost(self):
        """Port binding must use 127.0.0.1 — never bare 0.0.0.0 or wildcard."""
        port_lines = [
            line.strip()
            for line in self.compose.splitlines()
            if re.search(r'"\d+:\d+"|127\.0\.0\.1:\d+:\d+', line)
        ]
        for line in port_lines:
            self.assertNotRegex(
                line,
                r'^\s*-\s*["\']?\d+:\d+["\']?\s*$',
                msg=f"Bare port mapping exposes to 0.0.0.0: {line}"
            )
        self.assertRegex(self.compose, r'127\.0\.0\.1:\d+:\d+',
                         msg="No localhost-bound port mapping found")

    def test_02_no_production_keywords_in_active_yaml(self):
        """Compose must not use production domains or env var names in active YAML lines."""
        active = "\n".join(
            l for l in self.compose.splitlines()
            if not l.strip().startswith("#") and l.strip()
        )
        for pattern in [r'quannho-db\.lpm\.vn', r'\bprod\b', r'DATABASE_URL', r'STAGING_DATABASE_URL']:
            self.assertNotRegex(active, pattern,
                                msg=f"Production keyword in active YAML: '{pattern}'")
        self.assertIn("settle_v5_test_user", self.compose)
        self.assertIn("settle_v5_test_pass_local_only", self.compose)

    def test_03_healthcheck_block_present(self):
        """Compose must declare a healthcheck with pg_isready."""
        self.assertIn("healthcheck:", self.compose)
        self.assertIn("pg_isready", self.compose)
        self.assertIn("interval:", self.compose)
        self.assertIn("retries:", self.compose)

    def test_04_all_resources_use_settle_v5_test_prefix(self):
        """Container, network, and volume names must use settle-v5-test prefix."""
        self.assertIn("container_name: settle-v5-test-postgres", self.compose)
        self.assertIn("settle-v5-test-net", self.compose)
        self.assertIn("settle-v5-test-pgdata", self.compose)
        self.assertIn("name: settle-v5-test", self.compose)

    def test_05_init_sql_mounted_read_only(self):
        """Init SQL must be mounted with :ro flag."""
        self.assertRegex(self.compose, r'settle-v5-test-init\.sql.*:ro')

    def test_21_network_is_internal_true(self):
        """Network must be internal: true — DB container needs no outbound access."""
        self.assertRegex(self.compose, r'internal:\s*true',
                         msg="Network must be 'internal: true'")
        active = "\n".join(
            l for l in self.compose.splitlines()
            if not l.strip().startswith("#")
        )
        self.assertNotRegex(active, r'internal:\s*false',
                            msg="Network must not be 'internal: false'")


# =============================================================================
# SHELL SCRIPT
# =============================================================================
class TestShellOrchestrationScript(unittest.TestCase):

    def setUp(self):
        self.script = read_file(SHELL_SCRIPT)
        self.lines = self.script.splitlines()

    def _find_line(self, pattern, exclude_comments=True):
        """Return 0-based index of first matching line, or -1."""
        for i, line in enumerate(self.lines):
            if exclude_comments and line.strip().startswith("#"):
                continue
            if re.search(pattern, line):
                return i
        return -1

    def test_06_traps_set_correctly(self):
        """cleanup must be on EXIT; _signal_handler on INT TERM (separate traps)."""
        self.assertRegex(self.script, r'trap\s+cleanup\s+EXIT',
                         msg="'trap cleanup EXIT' not found")
        self.assertRegex(self.script, r'trap\s+_signal_handler\s+INT\s+TERM',
                         msg="'trap _signal_handler INT TERM' not found")
        # Must NOT put all three in one trap line
        self.assertNotRegex(self.script, r'trap\s+\w+\s+EXIT\s+INT\s+TERM',
                            msg="EXIT and INT/TERM must be separate traps for correct signal routing")

    def test_07_gate_exit_code_captured_and_propagated(self):
        """GATE_EXIT_CODE=$? must be captured and script must exit with it."""
        self.assertIn("GATE_EXIT_CODE=$?", self.script,
                      msg="GATE_EXIT_CODE=$? not found")
        self.assertIn('exit "${GATE_EXIT_CODE}"', self.script,
                      msg="Must exit with GATE_EXIT_CODE")

    def test_08_blocked_exit_2_when_no_docker(self):
        """Script must print BLOCKED and exit 2 when Docker/Podman absent."""
        self.assertIn("BLOCKED:", self.script)
        self.assertIn("exit 2", self.script)
        self.assertIn("command -v docker", self.script)
        self.assertIn("command -v podman", self.script)

    def test_09_never_reads_production_env_vars(self):
        """Script must not read DATABASE_URL or STAGING_DATABASE_URL (only check presence)."""
        for i, line in enumerate(self.lines, 1):
            s = line.strip()
            if re.search(r'\bunset\b', s):
                continue
            if re.search(r'\$\{DATABASE_URL:-\}|\$\{STAGING_DATABASE_URL:-\}', s):
                continue
            self.assertNotRegex(s, r'\$DATABASE_URL\b',
                                msg=f"Line {i}: reads $DATABASE_URL — forbidden")
            self.assertNotRegex(s, r'\$STAGING_DATABASE_URL\b',
                                msg=f"Line {i}: reads $STAGING_DATABASE_URL — forbidden")

    def test_10_compose_down_targets_exact_project(self):
        """compose down -v must name the exact project settle-v5-test."""
        self.assertRegex(self.script,
                         r'-p\s+["\']?settle-v5-test["\']?[\s\\]',
                         msg="compose down -v does not name project settle-v5-test")
        self.assertIn("down -v", self.script)

    def test_11_cleanup_verifies_project_name_literal_grep(self):
        """Cleanup must use a literal grep for 'name: settle-v5-test' before issuing down."""
        self.assertRegex(self.script,
                         r'grep\s+-q\s+["\']name:\s+settle-v5-test["\']',
                         msg="Cleanup must grep for literal project name before compose down")

    def test_12_no_rm_rf_with_variable_targets(self):
        """Script must not use rm -rf with variable paths."""
        for line in self.lines:
            s = line.strip()
            if s.startswith("#"):
                continue
            self.assertNotRegex(s, r'\brm\s+-rf?\s+\$',
                                msg=f"rm -rf with variable target: {s}")

    def test_15_compose_touched_state_machine(self):
        """
        COMPOSE_TOUCHED=0 initialized; COMPOSE_TOUCHED=1 set before compose up;
        cleanup guards compose down on COMPOSE_TOUCHED; no COMPOSE_STARTED remnants.
        """
        # Must initialize to 0
        self.assertIn("COMPOSE_TOUCHED=0", self.script)
        # Must assign to 1 somewhere
        self.assertIn("COMPOSE_TOUCHED=1", self.script)
        # Cleanup must check COMPOSE_TOUCHED (not DOCKER_CMD or COMPOSE_STARTED)
        self.assertRegex(
            self.script,
            r'COMPOSE_TOUCHED.*!=.*["\']1["\']|COMPOSE_TOUCHED.*==.*["\']1["\']',
            msg="cleanup must guard compose down on COMPOSE_TOUCHED"
        )
        # Old design must not be present
        self.assertNotIn("COMPOSE_STARTED", self.script,
                         msg="Old COMPOSE_STARTED guard must not exist; use COMPOSE_TOUCHED")

    def test_16_cleanup_incomplete_on_failure_not_cleanup_complete(self):
        """Cleanup failure path must print 'Cleanup INCOMPLETE', NOT 'Cleanup complete'."""
        self.assertIn("Cleanup INCOMPLETE", self.script,
                      msg="Cleanup failure branch must print 'Cleanup INCOMPLETE'")
        self.assertIn("Cleanup complete", self.script,
                      msg="Cleanup success branch must print 'Cleanup complete'")
        # The incomplete message must be in a different branch (else clause or failure branch)
        incomplete_idx = self.script.find("Cleanup INCOMPLETE")
        complete_idx = self.script.find("Cleanup complete")
        self.assertGreater(incomplete_idx, 0)
        self.assertGreater(complete_idx, 0)
        self.assertNotEqual(incomplete_idx, complete_idx)

    def test_17_term_received_forces_gate_exit_code_1(self):
        """_TERM_RECEIVED flag must be initialized and used in cleanup to force GATE_EXIT_CODE=1."""
        self.assertIn("_TERM_RECEIVED=0", self.script)
        self.assertIn("_TERM_RECEIVED=1", self.script)
        # Cleanup must check _TERM_RECEIVED and set GATE_EXIT_CODE=1
        self.assertRegex(
            self.script,
            r'_TERM_RECEIVED.*==.*["\']1["\']',
            msg="cleanup must check _TERM_RECEIVED flag"
        )
        self.assertRegex(
            self.script,
            r'GATE_EXIT_CODE=1',
            msg="cleanup must set GATE_EXIT_CODE=1 when _TERM_RECEIVED or compose down fails"
        )

    def test_18_trap_reset_inside_cleanup(self):
        """cleanup must reset all traps at its start (anti-reentry)."""
        self.assertRegex(self.script, r'trap\s+-\s+EXIT\s+INT\s+TERM',
                         msg="Cleanup must reset traps via 'trap - EXIT INT TERM'")

    def test_19_collision_checks_present(self):
        """Script must check port (Python socket), container, network, and volume before compose up."""
        # Python socket port check — code spans multiple lines, check both keywords exist
        self.assertIn("socket", self.script,
                      msg="Port check via Python socket not found in script")
        self.assertRegex(self.script, r's\.bind\(|socket\.bind\(',
                         msg="Port check via s.bind() / socket.bind() not found")
        self.assertIn("15432", self.script)
        # Container collision check (script uses $CONTAINER_NAME variable)
        self.assertRegex(self.script,
                         r'inspect.*CONTAINER_NAME|inspect.*settle-v5-test-postgres',
                         msg="Container collision check not found")
        # Network collision check
        self.assertRegex(self.script,
                         r'network\s+inspect.*NETWORK_NAME|network\s+inspect.*settle-v5-test-net',
                         msg="Network collision check not found")
        # Volume collision check
        self.assertRegex(self.script,
                         r'volume\s+inspect.*VOLUME_NAME|volume\s+inspect.*settle-v5-test-pgdata',
                         msg="Volume collision check not found")

    def test_20_runner_called_exactly_once_no_pytest(self):
        """Runner must be invoked exactly once via python3 directly; no pytest fallback."""
        invocations = re.findall(r'python3\s+.*run_phase1_real_pg_gate\.py', self.script)
        self.assertEqual(len(invocations), 1,
                         msg=f"Runner must be called exactly once, found: {invocations}")
        pytest_calls = [
            l for l in self.lines
            if 'pytest' in l and not l.strip().startswith('#')
        ]
        self.assertEqual(len(pytest_calls), 0,
                         msg=f"pytest must not be used as runner: {pytest_calls}")

    def test_22_signal_handler_defined(self):
        """_signal_handler function must be defined to handle INT/TERM signals."""
        self.assertRegex(self.script, r'_signal_handler\s*\(\)',
                         msg="_signal_handler function not defined")
        # Must set _TERM_RECEIVED and call exit
        self.assertIn("_TERM_RECEIVED=1", self.script)

    def test_23_daemon_reachability_verified(self):
        """Script must verify daemon is reachable, not just that the binary exists."""
        self.assertRegex(self.script, r'docker info|podman info',
                         msg="Daemon reachability check (docker info / podman info) not found")

    def test_24_compose_subcommand_verified(self):
        """Script must verify 'compose version' before using compose."""
        self.assertRegex(self.script, r'compose version',
                         msg="'compose version' subcommand check not found")

    def test_25_compose_touched_1_ordered_before_compose_up(self):
        """COMPOSE_TOUCHED=1 must appear BEFORE the compose up invocation in source."""
        # Find COMPOSE_TOUCHED=1 (standalone assignment, not inside comment)
        touched1_idx = -1
        for i, line in enumerate(self.lines):
            s = line.strip()
            if s.startswith("#"):
                continue
            # Must be the actual assignment statement
            if re.match(r'COMPOSE_TOUCHED=1\s*$', s):
                touched1_idx = i
                break

        # Find the actual compose up call (the docker/podman compose ... up line)
        up_idx = -1
        for i, line in enumerate(self.lines):
            s = line.strip()
            if s.startswith("#"):
                continue
            # The actual compose up command line (contains 'up -d' or '--force-recreate')
            if re.search(r'\bup\s+-d\b|--force-recreate', s):
                up_idx = i
                break

        self.assertGreater(touched1_idx, 0,
                           msg="COMPOSE_TOUCHED=1 assignment not found as standalone statement")
        self.assertGreater(up_idx, 0,
                           msg="compose up -d / --force-recreate command not found")
        self.assertLess(touched1_idx, up_idx,
                        msg=f"COMPOSE_TOUCHED=1 (line {touched1_idx+1}) must precede "
                            f"compose up (line {up_idx+1})")

    def test_26_atomic_invocation_lock_is_safely_managed(self):
        """The cross-process lock must use atomic mkdir and non-recursive rmdir."""
        self.assertIn("LOCK_ACQUIRED=0", self.script)
        self.assertRegex(self.script, r'mkdir\s+["\']?\$\{LOCK_DIR\}',
                         msg="Invocation lock must be acquired with atomic mkdir")
        self.assertRegex(self.script, r'rmdir\s+["\']?\$\{LOCK_DIR\}',
                         msg="Invocation lock must be released with non-recursive rmdir")
        self.assertNotRegex(self.script, r'rm\s+-rf?\s+["\']?\$\{LOCK_DIR\}',
                            msg="Invocation lock must never be recursively deleted")

    def test_27_project_label_collision_checked_before_compose_claim(self):
        """Orphan containers bearing the fixed Compose project label must block startup."""
        self.assertIn("com.docker.compose.project=${COMPOSE_PROJECT}", self.script)
        label_idx = self._find_line(r'com\.docker\.compose\.project=')
        touched_idx = self._find_line(r'^\s*COMPOSE_TOUCHED=1\s*$')
        self.assertGreater(label_idx, 0, "Compose project-label collision check not found")
        self.assertGreater(touched_idx, 0, "COMPOSE_TOUCHED=1 assignment not found")
        self.assertLess(label_idx, touched_idx,
                        "Project-label collision check must run before Compose ownership claim")


# =============================================================================
# INIT SQL
# =============================================================================
class TestInitSQLFile(unittest.TestCase):

    def setUp(self):
        self.sql = read_file(INIT_SQL_FILE)

    def test_13_anon_role_created_idempotently(self):
        """Init SQL must create anon role only if it does not exist."""
        self.assertIn("'anon'", self.sql)
        self.assertIn("CREATE ROLE anon NOLOGIN", self.sql)
        self.assertIn("IF NOT EXISTS", self.sql)

    def test_14_authenticated_role_created_idempotently(self):
        """Init SQL must create authenticated role only if it does not exist."""
        self.assertIn("'authenticated'", self.sql)
        self.assertIn("CREATE ROLE authenticated NOLOGIN", self.sql)


if __name__ == "__main__":
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
