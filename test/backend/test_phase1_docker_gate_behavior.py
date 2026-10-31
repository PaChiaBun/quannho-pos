#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Behavioral tests for run_phase1_docker_gate.sh  (Tests A–H)

Uses subprocess.run / subprocess.Popen with fake docker and python3 executables
in a disposable temp filesystem. Verifies actual runtime behavior, not source structure.

Fake executable behavior is controlled by environment variables:
  FAKE_CMD_LOG           path where both fakes write every invocation
  FAKE_DOCKER_INFO_EXIT  exit code for 'docker info' (0=running, 1=not)
  FAKE_CONTAINER_EXISTS  exit code for container inspect (0=found=collision, 1=not found=ok)
  FAKE_NETWORK_EXISTS    exit code for network inspect (0=found=collision, 1=not found=ok)
  FAKE_VOLUME_EXISTS     exit code for volume inspect (0=found=collision, 1=not found=ok)
  FAKE_PROJECT_EXISTS    1 when a container with the Compose project label exists
  FAKE_COMPOSE_UP_EXIT   exit code for compose up
  FAKE_COMPOSE_DOWN_EXIT exit code for compose down
  FAKE_HEALTH_STATUS     string returned for health status ('healthy'/'starting'/'unhealthy')
  FAKE_PSYCOPG2_EXIT     exit code for 'import psycopg2' check (0=available)
  FAKE_PORT_BIND_EXIT    exit code for Python socket.bind port check (0=free, 1=in use)
  FAKE_RUNNER_EXIT       exit code for the gate runner script
  FAKE_RUNNER_SLEEP      seconds fake runner sleeps before exiting (default 0)

Tests:
  A1 – Preflight failure (DATABASE_URL set): exit 1, compose up=0, down=0, runner=0
  A2 – Preflight failure (psycopg2 missing): exit 2, compose up=0, down=0, runner=0
  B  – Container collision: exit 2, compose up=0, compose down=0 (other invocation untouched)
  C  – Partial compose startup (up fails): exit 1, compose up=1, down=1, runner=0
  D  – Happy path: exit 0, compose up=1, runner=1, down=1
  E  – Runner failure: exit 1, runner=1, down=1
  F  – Cleanup failure: exit 1, no "Cleanup complete", has "Cleanup INCOMPLETE"
  G  – SIGTERM while runner sleeping: exit non-zero, runner=1, down=1, cleanup=1 (no loop)
  H  – No Docker/Podman: exit 2, no compose commands invoked
"""

import os
import re
import sys
import time
import shutil
import signal as signal_module
import subprocess
import tempfile
import unittest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REAL_SCRIPT = os.path.join(SCRIPT_DIR, "run_phase1_docker_gate.sh")
REAL_COMPOSE = os.path.join(SCRIPT_DIR, "docker-compose.settle-v5-test.yml")
REAL_INIT_SQL = os.path.join(SCRIPT_DIR, "settle-v5-test-init.sql")

# Use system bash — do NOT use env PATH to find it (may be fake in tests)
BASH_EXEC = shutil.which("bash") or "/bin/bash"

# =============================================================================
# FAKE EXECUTABLE TEMPLATES
# =============================================================================

# Fake docker: logs every invocation, returns configurable exit codes
_FAKE_DOCKER = r"""#!/usr/bin/env bash
FAKE_CMD_LOG="${FAKE_CMD_LOG:-/tmp/fk_cmd.log}"
printf "docker %s\n" "$*" >> "${FAKE_CMD_LOG}"
SUBCMD="${1:-}"
case "${SUBCMD}" in
    "--version")
        echo "Docker version 24.0.0, build abc123"
        exit 0
        ;;
    "info")
        exit "${FAKE_DOCKER_INFO_EXIT:-0}"
        ;;
    "inspect")
        # Detect health-status query by scanning args for 'Health.Status'
        if printf '%s\n' "$@" | grep -q "Health.Status" 2>/dev/null; then
            echo "${FAKE_HEALTH_STATUS:-healthy}"
            exit 0
        fi
        # Generic inspect = container existence check
        exit "${FAKE_CONTAINER_EXISTS:-1}"
        ;;
    "network")
        shift
        [[ "${1:-}" == "inspect" ]] && exit "${FAKE_NETWORK_EXISTS:-1}"
        exit 0
        ;;
    "volume")
        shift
        [[ "${1:-}" == "inspect" ]] && exit "${FAKE_VOLUME_EXISTS:-1}"
        exit 0
        ;;
    "ps")
        if [[ "${FAKE_PROJECT_EXISTS:-0}" == "1" ]]; then
            echo "fake-project-container-id"
        fi
        exit 0
        ;;
    "logs")
        echo "fake-container-log-output"
        exit 0
        ;;
    "compose")
        # Scan all positional args to find compose action
        COMPOSE_ACTION=""
        for arg in "$@"; do
            case "${arg}" in
                version|up|down|ps) COMPOSE_ACTION="${arg}"; break ;;
            esac
        done
        case "${COMPOSE_ACTION}" in
            "version") echo "Docker Compose version v2.20.0"; exit 0 ;;
            "up")      exit "${FAKE_COMPOSE_UP_EXIT:-0}" ;;
            "down")    exit "${FAKE_COMPOSE_DOWN_EXIT:-0}" ;;
            "ps")      exit 0 ;;
            *)         exit 0 ;;
        esac
        ;;
    *)
        exit 0
        ;;
esac
"""

# Fake python3: intercepts psycopg2 check, port check, and runner invocation
_FAKE_PYTHON3 = r"""#!/usr/bin/env bash
FAKE_CMD_LOG="${FAKE_CMD_LOG:-/tmp/fk_cmd.log}"
case "${1:-}" in
    "--version")
        echo "Python 3.11.0"
        exit 0
        ;;
    "-c")
        # $2 (after shift) is the inline code string
        shift
        CMD_TEXT="${1:-}"
        if echo "${CMD_TEXT}" | grep -qE "psycopg2"; then
            printf "python3 -c [psycopg2 check]\n" >> "${FAKE_CMD_LOG}"
            exit "${FAKE_PSYCOPG2_EXIT:-0}"
        fi
        if echo "${CMD_TEXT}" | grep -qE "socket|15432"; then
            printf "python3 -c [port check]\n" >> "${FAKE_CMD_LOG}"
            exit "${FAKE_PORT_BIND_EXIT:-0}"
        fi
        exit 0
        ;;
    *)
        # Any script invocation — detect runner by path
        if printf '%s\n' "$@" | grep -q "run_phase1_real_pg_gate"; then
            printf "python3 [runner]\n" >> "${FAKE_CMD_LOG}"
            SLEEP_SEC="${FAKE_RUNNER_SLEEP:-0}"
            if [[ "${SLEEP_SEC}" != "0" && "${SLEEP_SEC}" != "0.0" ]]; then
                sleep "${SLEEP_SEC}"
            fi
            exit "${FAKE_RUNNER_EXIT:-0}"
        fi
        exit 0
        ;;
esac
"""


# =============================================================================
# BASE CLASS
# =============================================================================
class DockerGateBehaviorBase(unittest.TestCase):
    """
    Creates a disposable temp filesystem with the gate script, compose file,
    required stubs, and fake docker/python3 executables.
    """

    # Per-test subprocess timeout in seconds. Keep short for CI/CD.
    TIMEOUT_SECS = 15

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp(prefix="gate_bhv_")

        # Directories matching the repo layout (script computes REPO_ROOT as ../.. from script)
        self.bin_dir = os.path.join(self.tmpdir, "bin")
        self.no_runtime_bin = os.path.join(self.tmpdir, "no-runtime-bin")
        self.script_dir = os.path.join(self.tmpdir, "test", "backend")
        self.migration_dir = os.path.join(self.tmpdir, "supabase", "migrations")
        self.sql_tests_dir = os.path.join(self.tmpdir, "supabase", "tests")

        for d in [self.bin_dir, self.no_runtime_bin, self.script_dir,
                  self.migration_dir, self.sql_tests_dir]:
            os.makedirs(d, exist_ok=True)

        # Test H needs dirname for SCRIPT_DIR resolution but must not inherit a
        # real docker/podman from the developer machine's PATH.
        dirname_bin = shutil.which("dirname")
        if not dirname_bin:
            self.fail("System dirname executable is required for behavioral tests")
        os.symlink(dirname_bin, os.path.join(self.no_runtime_bin, "dirname"))

        # Shared command log file (used by fake executables)
        self.cmd_log = os.path.join(self.tmpdir, "cmd.log")

        # Copy real artifacts into the temp tree
        shutil.copy(REAL_SCRIPT,  os.path.join(self.script_dir, "run_phase1_docker_gate.sh"))
        shutil.copy(REAL_COMPOSE, os.path.join(self.script_dir, "docker-compose.settle-v5-test.yml"))
        shutil.copy(REAL_INIT_SQL, os.path.join(self.script_dir, "settle-v5-test-init.sql"))

        # Required stubs (the gate script checks existence; content is irrelevant for fakes)
        for stub in [
            os.path.join(self.script_dir, "run_phase1_real_pg_gate.py"),
            os.path.join(self.script_dir, "test_settlement_v5_concurrency_real_pg.py"),
            os.path.join(self.migration_dir, "20260902_atomic_settlement_v5.sql"),
            os.path.join(self.sql_tests_dir, "settle_v5_concurrency_test.sql"),
        ]:
            with open(stub, "w") as f:
                f.write("# stub\n")

        # Write fake executables (both with default = happy-path behavior)
        self._write_exec(os.path.join(self.bin_dir, "docker"),  _FAKE_DOCKER)
        self._write_exec(os.path.join(self.bin_dir, "python3"), _FAKE_PYTHON3)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @staticmethod
    def _write_exec(path, content):
        with open(path, "w") as f:
            f.write(content)
        os.chmod(path, 0o755)

    # -------------------------------------------------------------------------
    # Environment helpers
    # -------------------------------------------------------------------------
    def _base_env(self, overrides=None):
        """Build minimal, isolated environment for subprocess invocation."""
        env = {}
        # Carry only safe, non-secret keys from the test process environment
        for key in ("HOME", "USER", "LOGNAME", "SHELL", "TERM", "TMPDIR",
                    "LANG", "LC_ALL", "TZ"):
            if key in os.environ:
                env[key] = os.environ[key]

        # Fake binaries come first; real system utilities after (grep, sleep, etc.)
        env["PATH"] = f"{self.bin_dir}:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["TMPDIR"] = self.tmpdir

        # Shared log file for both fakes
        env["FAKE_CMD_LOG"] = self.cmd_log

        # Default: happy-path values (all pass)
        env["FAKE_DOCKER_INFO_EXIT"] = "0"     # daemon running
        env["FAKE_CONTAINER_EXISTS"] = "1"     # not found → no collision
        env["FAKE_NETWORK_EXISTS"]   = "1"     # not found → no collision
        env["FAKE_VOLUME_EXISTS"]    = "1"     # not found → no collision
        env["FAKE_PROJECT_EXISTS"]   = "0"     # no compose-project label collision
        env["FAKE_COMPOSE_UP_EXIT"]  = "0"     # compose up success
        env["FAKE_COMPOSE_DOWN_EXIT"] = "0"    # compose down success
        env["FAKE_HEALTH_STATUS"]    = "healthy"
        env["FAKE_PSYCOPG2_EXIT"]    = "0"     # psycopg2 available
        env["FAKE_PORT_BIND_EXIT"]   = "0"     # port 15432 is free
        env["FAKE_RUNNER_EXIT"]      = "0"     # runner success
        env["FAKE_RUNNER_SLEEP"]     = "0"     # no sleep in runner

        if overrides:
            env.update(overrides)
        return env

    def _clear_log(self):
        with open(self.cmd_log, "w") as f:
            f.write("")

    def _read_log(self):
        try:
            with open(self.cmd_log, "r") as f:
                return f.read()
        except FileNotFoundError:
            return ""

    def _count(self, log_text, *patterns):
        """Count lines in log that contain ALL given patterns."""
        return sum(
            1 for line in log_text.splitlines()
            if all(p in line for p in patterns)
        )

    # -------------------------------------------------------------------------
    # Subprocess runners
    # -------------------------------------------------------------------------
    def _run(self, env_overrides=None):
        """Run gate script synchronously. Returns (exit_code, stdout, stderr, cmd_log)."""
        self._clear_log()
        script = os.path.join(self.script_dir, "run_phase1_docker_gate.sh")
        proc = subprocess.run(
            [BASH_EXEC, script],
            env=self._base_env(env_overrides),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=self.TIMEOUT_SECS,
            cwd=self.tmpdir,
        )
        return proc.returncode, proc.stdout, proc.stderr, self._read_log()

    def _run_with_signal(self, sig, signal_after_secs, env_overrides=None):
        """
        Start gate script, wait for signal_after_secs, send signal, wait for exit.
        Blocks until the process finishes (or TIMEOUT_SECS elapses).
        Returns (exit_code, stdout, stderr, cmd_log).
        """
        self._clear_log()
        script = os.path.join(self.script_dir, "run_phase1_docker_gate.sh")
        proc = subprocess.Popen(
            [BASH_EXEC, script],
            env=self._base_env(env_overrides),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=self.tmpdir,
        )
        try:
            # Wait until runner logs its start (runner is running → signal is meaningful)
            deadline = time.monotonic() + signal_after_secs + 5
            while time.monotonic() < deadline:
                if "[runner]" in self._read_log():
                    break
                time.sleep(0.05)
            else:
                # Still send signal even if we timed out looking for runner start marker
                pass

            # Give runner a brief moment to enter its sleep
            time.sleep(0.1)
            proc.send_signal(sig)

            try:
                stdout, stderr = proc.communicate(timeout=self.TIMEOUT_SECS)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.communicate()
                self.fail(f"Process did not exit within {self.TIMEOUT_SECS}s after signal {sig}. "
                          f"Possible trap re-entrance loop.")
        except Exception:
            if proc.poll() is None:
                proc.kill()
                proc.communicate()
            raise

        return proc.returncode, stdout, stderr, self._read_log()


# =============================================================================
# BEHAVIORAL TESTS
# =============================================================================
class TestDockerGateBehavior(DockerGateBehaviorBase):

    # -----------------------------------------------------------------------
    # A1 — Preflight failure: DATABASE_URL set
    # -----------------------------------------------------------------------
    def test_A1_database_url_set_exits_1_no_compose_invoked(self):
        """
        A. Preflight failure: DATABASE_URL set in environment.
        Expected: exit 1; compose up = 0; compose down = 0; runner = 0.
        COMPOSE_TOUCHED must remain 0 → cleanup skips compose down.
        """
        exit_code, stdout, stderr, cmd_log = self._run(
            env_overrides={"DATABASE_URL": "postgresql://danger:secret@prod.db/live"}
        )
        self.assertEqual(exit_code, 1,
                         f"DATABASE_URL set must exit 1, got {exit_code}\nSTDOUT:\n{stdout}")
        self.assertIn("BLOCKED", stdout, "Must print BLOCKED for production env var")

        up_count   = self._count(cmd_log, "compose", " up")
        down_count = self._count(cmd_log, "compose", " down")
        runner_count = self._count(cmd_log, "[runner]")

        self.assertEqual(up_count,     0, f"compose up must not run; log:\n{cmd_log}")
        self.assertEqual(down_count,   0, f"compose down must not run (COMPOSE_TOUCHED=0); log:\n{cmd_log}")
        self.assertEqual(runner_count, 0, f"runner must not run; log:\n{cmd_log}")

    # -----------------------------------------------------------------------
    # A2 — Preflight failure: psycopg2 missing
    # -----------------------------------------------------------------------
    def test_A2_psycopg2_missing_exits_2_no_compose_invoked(self):
        """
        A. Preflight failure: psycopg2 not importable.
        Expected: exit 2 (BLOCKED); compose up = 0; compose down = 0; runner = 0.
        """
        exit_code, stdout, stderr, cmd_log = self._run(
            env_overrides={"FAKE_PSYCOPG2_EXIT": "1"}
        )
        self.assertEqual(exit_code, 2,
                         f"psycopg2 missing must exit 2, got {exit_code}\nSTDOUT:\n{stdout}")
        self.assertIn("BLOCKED", stdout)

        self.assertEqual(self._count(cmd_log, "compose", " up"),   0,
                         f"compose up must not run\n{cmd_log}")
        self.assertEqual(self._count(cmd_log, "compose", " down"), 0,
                         f"compose down must not run (COMPOSE_TOUCHED=0)\n{cmd_log}")
        self.assertEqual(self._count(cmd_log, "[runner]"),         0,
                         f"runner must not run\n{cmd_log}")

    # -----------------------------------------------------------------------
    # B — Collision: container already exists
    # -----------------------------------------------------------------------
    def test_B_container_collision_exits_2_does_not_run_compose(self):
        """
        B. Collision: container settle-v5-test-postgres already exists.
        Expected: exit 2; compose up = 0; compose down = 0.
        Must NOT destroy existing resources (another invocation's environment).
        """
        exit_code, stdout, stderr, cmd_log = self._run(
            env_overrides={"FAKE_CONTAINER_EXISTS": "0"}  # 0 = found = collision
        )
        self.assertEqual(exit_code, 2,
                         f"Container collision must exit 2, got {exit_code}\nSTDOUT:\n{stdout}")
        self.assertIn("BLOCKED", stdout)

        up_count   = self._count(cmd_log, "compose", " up")
        down_count = self._count(cmd_log, "compose", " down")
        self.assertEqual(up_count,   0, f"compose up must not run\n{cmd_log}")
        self.assertEqual(down_count, 0,
                         f"compose down must not run — must not destroy other invocation's resources\n{cmd_log}")
        self.assertFalse(os.path.exists(os.path.join(self.tmpdir, "settle-v5-test-gate.lock")),
                         "Invocation lock must be released after collision preflight")

    def test_B2_network_volume_and_project_collisions_are_non_destructive(self):
        """Every named/project-labelled collision must block without up/down."""
        cases = [
            ("network", {"FAKE_NETWORK_EXISTS": "0"}),
            ("volume", {"FAKE_VOLUME_EXISTS": "0"}),
            ("project-label", {"FAKE_PROJECT_EXISTS": "1"}),
        ]
        for label, overrides in cases:
            with self.subTest(collision=label):
                exit_code, stdout, stderr, cmd_log = self._run(env_overrides=overrides)
                self.assertEqual(exit_code, 2, f"{label} collision must exit 2\n{stdout}")
                self.assertIn("BLOCKED", stdout)
                self.assertEqual(self._count(cmd_log, "compose", " up"), 0, cmd_log)
                self.assertEqual(self._count(cmd_log, "compose", " down"), 0, cmd_log)
                self.assertFalse(
                    os.path.exists(os.path.join(self.tmpdir, "settle-v5-test-gate.lock")),
                    f"Invocation lock leaked after {label} collision",
                )

    def test_B3_existing_invocation_lock_blocks_before_resource_checks(self):
        """An atomic lock prevents two concurrent invocations passing preflight together."""
        lock_dir = os.path.join(self.tmpdir, "settle-v5-test-gate.lock")
        os.mkdir(lock_dir)

        exit_code, stdout, stderr, cmd_log = self._run()

        self.assertEqual(exit_code, 2, stdout)
        self.assertIn("Another Phase 1 Docker gate invocation owns the lock", stdout)
        self.assertEqual(self._count(cmd_log, "compose", " up"), 0, cmd_log)
        self.assertEqual(self._count(cmd_log, "compose", " down"), 0, cmd_log)
        self.assertTrue(os.path.isdir(lock_dir),
                        "A lock not owned by this invocation must not be removed")

    # -----------------------------------------------------------------------
    # C — Partial compose startup (compose up fails)
    # -----------------------------------------------------------------------
    def test_C_partial_compose_up_failure_cleanup_runs_once(self):
        """
        C. compose up exits non-zero (partial creation).
        Expected: exit 1; compose up called once (it ran and failed);
                  compose down called exactly once (cleanup ran);
                  runner not called (never reached).
        """
        exit_code, stdout, stderr, cmd_log = self._run(
            env_overrides={"FAKE_COMPOSE_UP_EXIT": "1"}
        )
        self.assertEqual(exit_code, 1,
                         f"compose up failure must exit 1, got {exit_code}\nSTDOUT:\n{stdout}")

        up_count     = self._count(cmd_log, "compose", " up")
        down_count   = self._count(cmd_log, "compose", " down")
        runner_count = self._count(cmd_log, "[runner]")

        self.assertEqual(up_count,     1, f"compose up must be called once\n{cmd_log}")
        self.assertEqual(down_count,   1, f"compose down must be called once (COMPOSE_TOUCHED=1)\n{cmd_log}")
        self.assertEqual(runner_count, 0, f"runner must not run (compose up failed before it)\n{cmd_log}")

    # -----------------------------------------------------------------------
    # D — Happy path
    # -----------------------------------------------------------------------
    def test_D_happy_path_exit_0_all_counts_1(self):
        """
        D. All steps succeed.
        Expected: exit 0; compose up = 1; runner = 1; compose down = 1;
                  stdout contains 'Cleanup complete'.
        """
        exit_code, stdout, stderr, cmd_log = self._run()
        self.assertEqual(exit_code, 0,
                         f"Happy path must exit 0, got {exit_code}\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}")

        up_count     = self._count(cmd_log, "compose", " up")
        down_count   = self._count(cmd_log, "compose", " down")
        runner_count = self._count(cmd_log, "[runner]")

        self.assertEqual(up_count,     1, f"compose up must be called once\n{cmd_log}")
        self.assertEqual(runner_count, 1, f"runner must be called once\n{cmd_log}")
        self.assertEqual(down_count,   1, f"compose down must be called once\n{cmd_log}")
        self.assertIn("Cleanup complete", stdout,
                      "Happy path must print 'Cleanup complete'")
        self.assertNotIn("Cleanup INCOMPLETE", stdout)

    # -----------------------------------------------------------------------
    # E — Runner failure
    # -----------------------------------------------------------------------
    def test_E_runner_failure_exits_1_cleanup_runs(self):
        """
        E. Runner exits non-zero.
        Expected: exit 1; runner = 1; compose down = 1.
        Cleanup must still run (compose down once).
        """
        exit_code, stdout, stderr, cmd_log = self._run(
            env_overrides={"FAKE_RUNNER_EXIT": "1"}
        )
        self.assertEqual(exit_code, 1,
                         f"Runner failure must exit 1, got {exit_code}\nSTDOUT:\n{stdout}")

        runner_count = self._count(cmd_log, "[runner]")
        down_count   = self._count(cmd_log, "compose", " down")

        self.assertEqual(runner_count, 1, f"runner must be called once\n{cmd_log}")
        self.assertEqual(down_count,   1, f"compose down must run after runner failure\n{cmd_log}")

    # -----------------------------------------------------------------------
    # F — Cleanup failure
    # -----------------------------------------------------------------------
    def test_F_cleanup_failure_exits_1_incomplete_message(self):
        """
        F. compose down exits non-zero.
        Expected: exit 1 even though runner passed;
                  stdout has 'Cleanup INCOMPLETE';
                  stdout does NOT have 'Cleanup complete'.
        """
        exit_code, stdout, stderr, cmd_log = self._run(
            env_overrides={"FAKE_COMPOSE_DOWN_EXIT": "1"}
        )
        self.assertEqual(exit_code, 1,
                         f"Cleanup failure must exit 1, got {exit_code}\nSTDOUT:\n{stdout}")
        self.assertIn("Cleanup INCOMPLETE", stdout,
                      "Must print 'Cleanup INCOMPLETE' when compose down fails")
        self.assertNotIn("Cleanup complete", stdout,
                         "Must NOT print 'Cleanup complete' when compose down fails")

    # -----------------------------------------------------------------------
    # G — SIGTERM while runner is sleeping
    # -----------------------------------------------------------------------
    def test_G_sigterm_exits_nonzero_cleanup_runs_exactly_once(self):
        """
        G. SIGTERM arrives while fake runner is sleeping.
        Expected:
          - process exits non-zero;
          - runner count = 1 (runner ran to completion, bash deferred SIGTERM);
          - compose down count = 1 (cleanup ran after SIGTERM was processed);
          - cleanup count = 1 (no re-entrance / trap loop).
        """
        # Runner sleeps 0.8s; we send SIGTERM after runner starts but before it finishes.
        exit_code, stdout, stderr, cmd_log = self._run_with_signal(
            sig=signal_module.SIGTERM,
            signal_after_secs=0.3,
            env_overrides={"FAKE_RUNNER_SLEEP": "0.8", "FAKE_RUNNER_EXIT": "0"},
        )

        self.assertNotEqual(exit_code, 0,
                            f"SIGTERM must cause non-zero exit, got {exit_code}\nSTDOUT:\n{stdout}")

        runner_count = self._count(cmd_log, "[runner]")
        down_count   = self._count(cmd_log, "compose", " down")

        self.assertEqual(runner_count, 1,
                         f"runner must be called exactly once (bash deferred SIGTERM until runner finished)\n{cmd_log}")
        self.assertEqual(down_count,   1,
                         f"compose down must run exactly once (cleanup after SIGTERM)\n{cmd_log}")

        # Cleanup must not be called more than once (no trap re-entrance loop)
        cleanup_count = stdout.count("=== [Cleanup]")
        self.assertEqual(cleanup_count, 1,
                         f"Cleanup section must appear exactly once\nSTDOUT:\n{stdout}")

    # -----------------------------------------------------------------------
    # H — No Docker or Podman available
    # -----------------------------------------------------------------------
    def test_H_no_docker_exits_2_no_compose_cleanup(self):
        """
        H. Neither docker nor podman on PATH.
        Expected: exit 2; no compose commands logged; cleanup does not run compose down.
        """
        # Use a hermetic PATH containing only dirname. Never depend on whether
        # the developer machine has Docker Desktop installed.
        exit_code, stdout, stderr, cmd_log = self._run(
            env_overrides={"PATH": self.no_runtime_bin}
        )
        self.assertEqual(exit_code, 2,
                         f"No docker/podman must exit 2, got {exit_code}\nSTDOUT:\n{stdout}")
        self.assertIn("BLOCKED", stdout)
        # compose must never have been invoked
        compose_calls = self._count(cmd_log, "compose")
        self.assertEqual(compose_calls, 0,
                         f"No compose commands must run when docker absent\n{cmd_log}")


if __name__ == "__main__":
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
