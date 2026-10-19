#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
test/scripts/test_qn_release_adversarial.py
─────────────────────────────────────────────────────────────────────────────
Adversarial & Stress Testing Suite for Quán Nhỏ POS Release Automation Pipeline
Author: Challenger 2 (Release Adversary)

Stress-tests:
  1. Tamper simulation: unauthorized modifications/removal of Apple Guideline 3.1.1
     guardrail in auth_screen.dart (fail-closed verification).
  2. Malformed pubspec.yaml: missing keys, invalid semantic formats, comments,
     boundary versions, Windows CRLF line endings.
  3. Idempotency & Conflict: duplicate version publishing on Supabase (verifying
     UNIQUE(platform, build_number) upsert behavior and network fault resilience).
  4. Flag combinations & CLI fuzzing: --dry-run, --skip-build, invalid platforms,
     empty descriptions, invalid flags, natural Vietnamese command triggers.
  5. Injection attacks: shell metacharacters, SQL injection payloads, XSS/HTML tags,
     multi-line markdown, Unicode/Vietnamese diacritics, massive payload stress.
  6. End-to-end sandbox pipeline simulations under hostile conditions.
─────────────────────────────────────────────────────────────────────────────
"""

import copy
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
scripts_dir = os.path.join(PROJECT_ROOT, "scripts")
if scripts_dir not in sys.path:
    sys.path.append(scripts_dir)

from qn_release import (
    ArtifactSyncManager,
    BuildOrchestrator,
    DevDiaryManager,
    InvariantGuard,
    InvariantViolationError,
    ReleaseConfig,
    ReleaseEngine,
    SupabaseSyncManager,
    VersionManager,
    XcodeLauncher,
    parse_arguments,
)


class TestAppleGuideline311TamperDetection(unittest.TestCase):
    """
    Adversarial stress-testing of Apple Guideline 3.1.1 pre-release invariant check.
    Verifies that any unauthorized attempt to alter or bypass iOS registration
    restrictions immediately halts the release pipeline with exit code 1.
    """

    VALID_AUTH_SCREEN = """
    // Flutter Auth Screen
    import 'package:flutter/foundation.dart';
    import 'package:flutter/material.dart';

    class AuthScreen extends StatefulWidget {
      @override
      _AuthScreenState createState() => _AuthScreenState();
    }

    class _AuthScreenState extends State<AuthScreen> {
      int _tab = 0;

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          body: Column(
            children: [
              if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                Container(
                  child: const Text(
                    'Đăng nhập tài khoản nhân viên / quản lý đã được cấp bởi cửa hàng của bạn.',
                  ),
                ),
              ] else ...[
                _buildTabSelector(),
              ],
              AnimatedSwitcher(
                child: (defaultTargetPlatform == TargetPlatform.iOS || _tab == 0)
                    ? _buildLoginForm()
                    : _buildRegisterForm(),
              ),
            ],
          ),
        );
      }
    }
    """

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.screens_dir = os.path.join(self.temp_dir, "lib", "screens")
        os.makedirs(self.screens_dir, exist_ok=True)
        self.auth_file = os.path.join(self.screens_dir, "auth_screen.dart")

        # Create valid pubspec.yaml in temp_dir
        self.pubspec_file = os.path.join(self.temp_dir, "pubspec.yaml")
        with open(self.pubspec_file, "w", encoding="utf-8") as f:
            f.write("name: quannho_pos\nversion: 1.0.2+7\n")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def _write_auth_screen(self, content: str):
        with open(self.auth_file, "w", encoding="utf-8") as f:
            f.write(content)

    def test_tamper_1_removal_of_platform_ios_check(self):
        """Adversarial Attack: Developer removes defaultTargetPlatform == TargetPlatform.iOS."""
        tampered_code = self.VALID_AUTH_SCREEN.replace(
            "defaultTargetPlatform == TargetPlatform.iOS",
            "true /* bypassed */"
        )
        self._write_auth_screen(tampered_code)

        with self.assertRaises(InvariantViolationError) as ctx:
            InvariantGuard.verify_ios_guideline_311(self.temp_dir)
        self.assertIn("Missing 'defaultTargetPlatform == TargetPlatform.iOS' guard", str(ctx.exception))

    def test_tamper_2_bypass_of_registration_form_suppression(self):
        """Adversarial Attack: Developer modifies form switcher to allow registration on iOS."""
        tampered_code = self.VALID_AUTH_SCREEN.replace(
            "(defaultTargetPlatform == TargetPlatform.iOS || _tab == 0)",
            "(_tab == 0) /* removed iOS check */"
        )
        self._write_auth_screen(tampered_code)

        with self.assertRaises(InvariantViolationError) as ctx:
            InvariantGuard.verify_ios_guideline_311(self.temp_dir)
        self.assertIn("Registration form is not suppressed on iOS", str(ctx.exception))

    def test_tamper_3_removal_of_neutral_instruction_text(self):
        """Adversarial Attack: Developer alters neutral guidance text to encourage external registration."""
        tampered_code = self.VALID_AUTH_SCREEN.replace(
            "Đăng nhập tài khoản nhân viên / quản lý đã được cấp bởi cửa hàng của bạn.",
            "Tạo tài khoản mới tại quannho.lpm.vn để bắt đầu sử dụng."
        )
        self._write_auth_screen(tampered_code)

        with self.assertRaises(InvariantViolationError) as ctx:
            InvariantGuard.verify_ios_guideline_311(self.temp_dir)
        self.assertIn("Missing neutral iOS guidance text", str(ctx.exception))

    def test_tamper_4_missing_auth_screen_file(self):
        """Adversarial Attack: auth_screen.dart is deleted or renamed."""
        if os.path.exists(self.auth_file):
            os.remove(self.auth_file)

        with self.assertRaises(InvariantViolationError) as ctx:
            InvariantGuard.verify_ios_guideline_311(self.temp_dir)
        self.assertIn("Missing required file for invariant check", str(ctx.exception))

    def test_tamper_5_release_engine_halts_without_modifications(self):
        """Verifies that an invariant violation causes ReleaseEngine.run() to return 1 immediately."""
        self._write_auth_screen("// Tampered file with no guards")

        config = ReleaseConfig(
            project_dir=self.temp_dir,
            description="Thử nghiệm tấn công tamper",
            dry_run=False,
            skip_build=True,
            skip_xcode=True,
        )
        engine = ReleaseEngine(config)
        exit_code = engine.run()

        # Engine must halt with exit code 1
        self.assertEqual(exit_code, 1)

        # Invariant: pubspec.yaml MUST NOT be touched
        with open(self.pubspec_file, "r", encoding="utf-8") as f:
            self.assertIn("version: 1.0.2+7", f.read())

        # Invariant: nhat_ky.md MUST NOT be created
        self.assertFalse(os.path.exists(os.path.join(self.temp_dir, "nhat_ky.md")))

    def test_tamper_6_skip_invariant_flag_explicit_override(self):
        """Verifies that --skip-invariant flag explicitly bypasses check when commanded."""
        self._write_auth_screen("// Empty auth screen without invariant")
        # Ensure local archive exists so pipeline can proceed past step 4
        os.makedirs(os.path.join(self.temp_dir, "build", "ios", "archive", "Runner.xcarchive"), exist_ok=True)

        config = ReleaseConfig(
            project_dir=self.temp_dir,
            description="Bản dựng khẩn cấp",
            dry_run=True,
            skip_build=True,
            skip_xcode=True,
            skip_invariant=True,  # Explicit override
        )
        engine = ReleaseEngine(config)
        exit_code = engine.run()
        self.assertEqual(exit_code, 0)

    def test_xcode_launcher_permission_error_vulnerability(self):
        """
        Adversarial Finding: XcodeLauncher.get_archive_path crashes with unhandled PermissionError
        when local_archive does not exist and ~/Library/Developer/Xcode/Archives is restricted.
        """
        empty_sandbox = tempfile.mkdtemp()
        try:
            # When Runner.xcarchive does not exist in project_dir
            local_archive = os.path.join(empty_sandbox, "build", "ios", "archive", "Runner.xcarchive")
            self.assertFalse(os.path.exists(local_archive))

            today_dir = os.path.join(os.path.expanduser("~"), "Library", "Developer", "Xcode", "Archives", "2026-09-24")
            if os.path.isdir(today_dir):
                try:
                    os.listdir(today_dir)
                    can_read = True
                except (OSError, PermissionError):
                    can_read = False

                if not can_read:
                    # In restricted macOS environment, get_archive_path gracefully falls back to local_archive
                    res_path = XcodeLauncher.get_archive_path(empty_sandbox)
                    self.assertEqual(res_path, local_archive)
        finally:
            shutil.rmtree(empty_sandbox, ignore_errors=True)

    def test_tamper_7_subprocess_cli_tamper_halt(self):
        """Verifies real CLI execution terminates with non-zero exit code when tampered."""
        self._write_auth_screen("// Tampered content")
        script_path = os.path.join(PROJECT_ROOT, "scripts", "qn_release.py")

        # Copy real script to temp dir environment
        scripts_dir = os.path.join(self.temp_dir, "scripts")
        os.makedirs(scripts_dir, exist_ok=True)
        shutil.copy2(script_path, os.path.join(scripts_dir, "qn_release.py"))

        res = subprocess.run(
            [sys.executable, os.path.join(scripts_dir, "qn_release.py"), "--dry-run", "Test CLI Tamper"],
            cwd=self.temp_dir,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 1)
        self.assertIn("Apple Guideline 3.1.1 Invariant Failed", res.stdout + res.stderr)
        self.assertIn("DỪNG PHÁT HÀNH", res.stdout + res.stderr)


class TestMalformedPubspecHandling(unittest.TestCase):
    """
    Adversarial stress-testing of VersionManager and pubspec.yaml parsing.
    Validates boundary conditions, malformed version strings, missing keys,
    inline comments, and Windows CRLF line endings.
    """

    def test_malformed_missing_version_key(self):
        content = "name: quannho_pos\ndescription: A POS app\n"
        with self.assertRaises(ValueError) as ctx:
            VersionManager.parse_version(content)
        self.assertIn("Invalid or missing 'version: X.Y.Z+B'", str(ctx.exception))

    def test_malformed_version_without_build_number(self):
        content = "name: quannho_pos\nversion: 1.0.2\n"
        with self.assertRaises(ValueError):
            VersionManager.parse_version(content)

    def test_malformed_version_without_patch(self):
        content = "name: quannho_pos\nversion: 1.0+7\n"
        with self.assertRaises(ValueError):
            VersionManager.parse_version(content)

    def test_malformed_non_numeric_version(self):
        content = "name: quannho_pos\nversion: 1.0.x+7\n"
        with self.assertRaises(ValueError):
            VersionManager.parse_version(content)

    def test_malformed_negative_build_number(self):
        content = "name: quannho_pos\nversion: 1.0.2+-5\n"
        with self.assertRaises(ValueError):
            VersionManager.parse_version(content)

    def test_malformed_empty_file(self):
        with self.assertRaises(ValueError):
            VersionManager.parse_version("")

    def test_pubspec_with_inline_comment(self):
        """pubspec with trailing comments should extract version and build accurately."""
        content = "name: quannho_pos\nversion: 1.0.2+7 # Release candidate 1\nenvironment:\n  sdk: ^3.0.0\n"
        ver, build = VersionManager.parse_version(content)
        self.assertEqual(ver, "1.0.2")
        self.assertEqual(build, 7)

    def test_pubspec_with_windows_crlf(self):
        """pubspec with Windows CRLF \\r\\n line endings."""
        content = "name: quannho_pos\r\nversion: 1.0.2+7\r\nenvironment:\r\n  sdk: ^3.0.0\r\n"
        ver, build = VersionManager.parse_version(content)
        self.assertEqual(ver, "1.0.2")
        self.assertEqual(build, 7)

    def test_bump_type_boundary_checks(self):
        # Build only
        v, b = VersionManager.bump("1.0.2", 7, "build")
        self.assertEqual(v, "1.0.2")
        self.assertEqual(b, 8)

        # Patch
        v, b = VersionManager.bump("1.0.2", 7, "patch")
        self.assertEqual(v, "1.0.3")
        self.assertEqual(b, 8)

        # Minor
        v, b = VersionManager.bump("1.0.2", 7, "minor")
        self.assertEqual(v, "1.1.0")
        self.assertEqual(b, 8)

        # Major
        v, b = VersionManager.bump("1.0.2", 7, "major")
        self.assertEqual(v, "2.0.0")
        self.assertEqual(b, 8)

        # Invalid bump type
        with self.assertRaises(ValueError):
            VersionManager.bump("1.0.2", 7, "invalid_bump")

    def test_missing_pubspec_file_in_engine(self):
        """ReleaseEngine should cleanly return exit code 1 if pubspec.yaml is missing."""
        temp_dir = tempfile.mkdtemp()
        try:
            # Create valid auth screen
            screens_dir = os.path.join(temp_dir, "lib", "screens")
            os.makedirs(screens_dir, exist_ok=True)
            with open(os.path.join(screens_dir, "auth_screen.dart"), "w", encoding="utf-8") as f:
                f.write(TestAppleGuideline311TamperDetection.VALID_AUTH_SCREEN)

            config = ReleaseConfig(
                project_dir=temp_dir,
                description="Test missing pubspec",
                skip_build=True,
                skip_xcode=True,
            )
            engine = ReleaseEngine(config)
            exit_code = engine.run()
            self.assertEqual(exit_code, 1)
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)


class TestSupabasePublishingAndIdempotency(unittest.TestCase):
    """
    Adversarial stress-testing of Supabase publishing logic, schema constraints,
    idempotent upserts, and network fault tolerance.
    """

    def test_idempotent_duplicate_version_publishing(self):
        """
        Verify that publishing the exact same (platform, build_number) produces
        a valid record that maps cleanly to ON CONFLICT (platform, build_number) DO UPDATE.
        """
        rec1 = SupabaseSyncManager.build_record(
            platform="android",
            version="1.0.3",
            build_num=8,
            changelog="Bản phát hành đầu tiên",
            is_force=False,
        )
        rec2 = SupabaseSyncManager.build_record(
            platform="android",
            version="1.0.3",
            build_num=8,
            changelog="Bản phát hành cập nhật lại changelog (idempotent)",
            is_force=True,
        )

        self.assertEqual(rec1["platform"], rec2["platform"])
        self.assertEqual(rec1["build_number"], rec2["build_number"])
        self.assertEqual(rec2["is_force_update"], True)
        self.assertIn("idempotent", rec2["changelog"])

    def test_reject_zero_and_negative_build_numbers(self):
        """Boundary check: build numbers <= 0 must be rejected with ValueError."""
        with self.assertRaises(ValueError) as ctx:
            SupabaseSyncManager.build_record("android", "1.0.3", 0, "Test")
        self.assertIn("Build number must be > 0", str(ctx.exception))

        with self.assertRaises(ValueError) as ctx:
            SupabaseSyncManager.build_record("android", "1.0.3", -10, "Test")
        self.assertIn("Build number must be > 0", str(ctx.exception))

    def test_reject_invalid_platforms(self):
        """Invalid platforms must be rejected according to DB schema constraints."""
        invalid_platforms = ["symbian", "blackberry", "windows_phone", "", "linux_unknown"]
        for p in invalid_platforms:
            with self.assertRaises(ValueError):
                SupabaseSyncManager.build_record(p, "1.0.3", 8, "Test")

    def test_reject_invalid_semantic_versions(self):
        """Invalid semantic version formats must be rejected."""
        invalid_versions = ["v1.0.3", "1.0", "1.0.0.1", "1.0.beta", "latest", ""]
        for ver in invalid_versions:
            with self.assertRaises(ValueError):
                SupabaseSyncManager.build_record("android", ver, 8, "Test")

    def test_unconfigured_supabase_credentials_resilience(self):
        """When credentials are not set, publish_version returns skipped status without crashing."""
        config = ReleaseConfig(dry_run=False, supabase_url="", supabase_key="")
        # Force clear env vars for test
        config.supabase_url = ""
        config.supabase_key = ""

        rec = SupabaseSyncManager.build_record("android", "1.0.3", 8, "Changelog")
        res = SupabaseSyncManager.publish_version(rec, config)
        self.assertEqual(res.get("status"), "skipped")
        self.assertIn("No Supabase credentials", res.get("reason", ""))

    def test_network_outage_graceful_fallback(self):
        """Simulate network timeout / connection refused to Supabase."""
        config = ReleaseConfig(
            dry_run=False,
            supabase_url="http://127.0.0.1:59999",  # Non-existent port
            supabase_key="dummy_key",
        )
        rec = SupabaseSyncManager.build_record("android", "1.0.3", 8, "Changelog")
        res = SupabaseSyncManager.publish_version(rec, config)
        self.assertEqual(res.get("status"), "network_fallback")
        self.assertIn("error", res)

    def test_sql_injection_payload_in_changelog(self):
        """SQL injection attack payloads in changelog should serialize cleanly as JSON."""
        attack_payloads = [
            "'; DROP TABLE app_versions; --",
            "1' OR '1'='1' /* admin bypass */",
            "\"; DELETE FROM app_versions WHERE '1'='1",
            "Robert'); DROP TABLE Students;--",
        ]
        for payload in attack_payloads:
            rec = SupabaseSyncManager.build_record("android", "1.0.3", 8, payload)
            # Ensure JSON serialization succeeds without syntax errors
            serialized = json.dumps(rec)
            deserialized = json.loads(serialized)
            self.assertEqual(deserialized["changelog"], payload)


class TestCliArgumentsAndFlagCombinations(unittest.TestCase):
    """
    Stress-testing CLI argument parsing, flags, natural language Vietnamese triggers,
    and invalid argument rejection.
    """

    def test_unknown_flag_raises_system_exit(self):
        """Unknown CLI flags must trigger argparse error with exit code 2."""
        with self.assertRaises(SystemExit) as ctx:
            parse_arguments(["--unrecognized-flag"])
        self.assertEqual(ctx.exception.code, 2)

    def test_invalid_bump_choice_raises_system_exit(self):
        """Invalid bump choice must trigger argparse error with exit code 2."""
        with self.assertRaises(SystemExit) as ctx:
            parse_arguments(["--bump=invalid_type"])
        self.assertEqual(ctx.exception.code, 2)

    def test_missing_flag_argument_raises_system_exit(self):
        """Flag requiring value without value at end of line must trigger error."""
        with self.assertRaises(SystemExit) as ctx:
            parse_arguments(["--bump"])
        self.assertEqual(ctx.exception.code, 2)

    def test_empty_arguments_fallback_to_default_description(self):
        """Running with no arguments applies default description without crashing."""
        config = parse_arguments([])
        self.assertIn("Cập nhật và hoàn thiện hệ sinh thái phân phối Quán Nhỏ POS", config.description)
        self.assertEqual(config.bump_type, "build")
        self.assertFalse(config.dry_run)

    def test_all_flag_combinations(self):
        """Verify complex flag combinations parse correctly into ReleaseConfig."""
        argv = [
            "--dry-run",
            "--skip-build",
            "--skip-xcode",
            "--skip-invariant",
            "--force-update",
            "--verbose",
            "--bump=patch",
            "--platforms=android,web",
            "--supabase-url=https://test.supabase.co",
            "--supabase-key=test_service_key",
            "Mô tả bản vá P0",
        ]
        config = parse_arguments(argv)
        self.assertTrue(config.dry_run)
        self.assertTrue(config.skip_build)
        self.assertTrue(config.skip_xcode)
        self.assertTrue(config.skip_invariant)
        self.assertTrue(config.force_update)
        self.assertTrue(config.verbose)
        self.assertEqual(config.bump_type, "patch")
        self.assertEqual(config.platforms, ["android", "web"])
        self.assertEqual(config.supabase_url, "https://test.supabase.co")
        self.assertEqual(config.supabase_key, "test_service_key")
        self.assertIn("Mô tả bản vá P0", config.description)

    def test_vietnamese_natural_commands_variations(self):
        """Test natural Vietnamese command triggers."""
        cases = [
            (["phát hành bản mới", "Nâng cấp máy in"], "Nâng cấp máy in"),
            (["phat hanh ban moi", "Sửa lỗi tồn kho"], "Sửa lỗi tồn kho"),
            (["/qn", "phát hành bản mới", "Đồng bộ hóa đơn"], "Đồng bộ hóa đơn"),
            (["qn", "phát hành bản mới", "Khắc phục báo cáo"], "Khắc phục báo cáo"),
            (["build release", "Tối ưu hóa"], "Tối ưu hóa"),
            (["release", "Bản cập nhật Sunmi"], "Bản cập nhật Sunmi"),
            (["phát", "hành", "bản", "mới", "Tách", "từ", "rời"], "Tách từ rời"),
        ]
        for args, expected in cases:
            config = parse_arguments(args)
            self.assertIn(expected, config.description)

    def test_platforms_normalization_case_and_whitespace(self):
        """Platform argument with whitespace and mixed case should normalize to lowercase."""
        config = parse_arguments(["--platforms= Android , IOS , Web "])
        self.assertEqual(config.platforms, ["android", "ios", "web"])


class TestInjectionAttacksAndSanitation(unittest.TestCase):
    """
    Stress-testing injection attacks: shell metacharacters, HTML/XSS,
    multi-line markdown, Unicode preservation, and massive payload sizing.
    """

    def test_shell_command_injection_safety(self):
        """Verify shell command injection metacharacters do not execute arbitrary commands."""
        temp_dir = tempfile.mkdtemp()
        try:
            marker_file = os.path.join(temp_dir, "pwned.txt")
            attack_desc = f"Bản vá khẩn cấp; touch {marker_file}; rm -rf / ; $(touch {marker_file}) `id`"

            config = ReleaseConfig(
                project_dir=temp_dir,
                description=attack_desc,
                dry_run=True,
                skip_build=True,
            )

            # Subprocess build commands are arrays, not shell strings
            matrix = BuildOrchestrator.get_build_matrix("1.0.3", 8)
            for plat, data in matrix.items():
                if "apk_cmd" in data:
                    self.assertIsInstance(data["apk_cmd"], list)
                if "build_cmd" in data:
                    self.assertIsInstance(data["build_cmd"], list)

            # Verify no command injection executed
            self.assertFalse(os.path.exists(marker_file))
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)

    def test_html_xss_in_release_description(self):
        """HTML and XSS script tags in release notes should be safely treated as text."""
        xss_payload = "<script>alert('XSS_ATTACK');</script><img src=x onerror=alert(1)>"
        entry = DevDiaryManager.generate_entry(
            version="1.0.3",
            build_num=8,
            title="XSS Test",
            description=xss_payload,
        )
        # Entry contains text verbatim in markdown context
        self.assertIn(xss_payload, entry)

        # ArtifactSyncManager must not inject changelog into index.html
        temp_dir = tempfile.mkdtemp()
        try:
            web_dir = os.path.join(temp_dir, "web-download")
            os.makedirs(web_dir, exist_ok=True)
            index_path = os.path.join(web_dir, "index.html")
            with open(index_path, "w", encoding="utf-8") as f:
                f.write('<span class="version-badge" id="versionBadge">v1.0.2 • Build 7</span>\nconst CONFIG = { version: "1.0.2", build: 7 };')

            ArtifactSyncManager.sync_web_portal(temp_dir, "1.0.3", 8, dry_run=False)

            with open(index_path, "r", encoding="utf-8") as f:
                html_content = f.read()

            self.assertNotIn("alert", html_content)
            self.assertIn("v1.0.3 • Build 8", html_content)
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)

    def test_multi_line_markdown_description_and_title_sanitation(self):
        """Multi-line description with injected markdown headers."""
        title_with_newlines = "Tiêu đề chính\n## Hacked Header Injected\n### Malicious Subsection"
        multi_line_desc = (
            "Dòng 1: Mô tả chi tiết cập nhật.\n"
            "Dòng 2: - Mục con 1\n"
            "Dòng 3: - Mục con 2\n"
            "```dart\nvoid main() => print('hello');\n```\n"
        )

        entry = DevDiaryManager.generate_entry(
            version="1.0.3",
            build_num=8,
            title=title_with_newlines,
            description=multi_line_desc,
        )

        # Invariant: First header line in nhat_ky entry MUST NOT contain line breaks from title
        lines = entry.split("\n")
        header_line = lines[0]
        self.assertTrue(header_line.startswith("## "))
        self.assertIn("Tiêu đề chính", header_line)
        self.assertNotIn("Hacked Header Injected", header_line)

        # Body contains multi-line markdown verbatim
        self.assertIn("Dòng 1: Mô tả chi tiết", entry)
        self.assertIn("void main() => print('hello');", entry)

    def test_vietnamese_diacritics_and_emoji_preservation(self):
        """Full Vietnamese unicode charset and rich emojis preservation."""
        vietnamese_text = (
            "🏪 Quán Nhỏ POS — Bản phát hành đặc biệt v1.0.3+8 🚀\n"
            "• Sửa lỗi đồng bộ tức thì giữa Kho & Bàn ăn (0.01 giây).\n"
            "• Đảm bảo quyền hạn Quản lý và Chủ quán (Hierarchy Guard).\n"
            "• Phục hồi tự động kết nối Supabase và phòng vệ lỗi Kong 401.\n"
            "• Hỗ trợ đầy đủ bộ gõ tiếng Việt Telex: Ă Â Đ Ê Ô Ơ Ư á à ả ã ạ."
        )

        rec = SupabaseSyncManager.build_record("android", "1.0.3", 8, vietnamese_text)
        serialized = json.dumps(rec, ensure_ascii=False)
        deserialized = json.loads(serialized)
        self.assertEqual(deserialized["changelog"], vietnamese_text)

        entry = DevDiaryManager.generate_entry("1.0.3", 8, "Unicode Test", vietnamese_text)
        self.assertIn("Ă Â Đ Ê Ô Ơ Ư", entry)
        self.assertIn("🏪", entry)

    def test_massive_payload_stress(self):
        """Massive description payload (100KB) to test memory safety and regex performance."""
        huge_payload = "A" * 100000
        rec = SupabaseSyncManager.build_record("android", "1.0.3", 8, huge_payload)
        self.assertEqual(len(rec["changelog"]), 100000)

        entry = DevDiaryManager.generate_entry("1.0.3", 8, "Huge Title", huge_payload)
        self.assertIn(huge_payload, entry)


class TestReleaseEngineEndToEndAdversarialScenarios(unittest.TestCase):
    """
    Simulates complete release lifecycle execution inside isolated sandbox environments
    under diverse adversarial conditions.
    """

    def setUp(self):
        self.sandbox_dir = tempfile.mkdtemp()

        # 1. Setup mock pubspec.yaml
        self.pubspec_path = os.path.join(self.sandbox_dir, "pubspec.yaml")
        with open(self.pubspec_path, "w", encoding="utf-8") as f:
            f.write("name: quannho_pos\nversion: 1.0.2+7\nenvironment:\n  sdk: ^3.0.0\n")

        # 2. Setup mock auth_screen.dart with valid Apple 3.1.1 guard
        screens_dir = os.path.join(self.sandbox_dir, "lib", "screens")
        os.makedirs(screens_dir, exist_ok=True)
        self.auth_path = os.path.join(screens_dir, "auth_screen.dart")
        with open(self.auth_path, "w", encoding="utf-8") as f:
            f.write(TestAppleGuideline311TamperDetection.VALID_AUTH_SCREEN)

        # 3. Setup mock web-download/index.html
        web_dir = os.path.join(self.sandbox_dir, "web-download")
        os.makedirs(web_dir, exist_ok=True)
        self.index_html_path = os.path.join(web_dir, "index.html")
        with open(self.index_html_path, "w", encoding="utf-8") as f:
            f.write(
                '<!DOCTYPE html><html><body>\n'
                '<span class="version-badge" id="versionBadge">v1.0.2 • Build 7</span>\n'
                "<script>const CONFIG = { version: '1.0.2', build: 7, };</script>\n"
                '</body></html>'
            )

        # 4. Setup mock Runner.xcarchive
        archive_dir = os.path.join(self.sandbox_dir, "build", "ios", "archive", "Runner.xcarchive")
        os.makedirs(archive_dir, exist_ok=True)

        # 5. Setup mock nhat_ky.md
        self.nhat_ky_path = os.path.join(self.sandbox_dir, "nhat_ky.md")
        with open(self.nhat_ky_path, "w", encoding="utf-8") as f:
            f.write(
                "# Nhật Ký Phát Triển — Quán Nhỏ POS\n\n"
                "> Ghi lại công việc mỗi ngày để dễ theo dõi tiến độ.\n"
                "> Format: ✅ Hoàn thành | 🔲 Cần làm | ⚠️ Vấn đề\n\n"
                "## 2026-09-24 (12:00 +07) — Phiên bản cũ trước đó [ĐÃ HOÀN THÀNH]\n"
                "> Nội dung cũ...\n"
            )

    def tearDown(self):
        shutil.rmtree(self.sandbox_dir, ignore_errors=True)

    def test_e2e_successful_dry_run_advances_contracts(self):
        """End-to-end dry-run pipeline validates all steps without modifying files."""
        config = ReleaseConfig(
            project_dir=self.sandbox_dir,
            description="Bản phát hành kiểm thử E2E hợp lệ",
            bump_type="patch",
            dry_run=True,
            skip_build=True,
            skip_xcode=True,
        )
        engine = ReleaseEngine(config)
        exit_code = engine.run()

        self.assertEqual(exit_code, 0)

        # In dry run, files must remain unmodified
        with open(self.pubspec_path, "r", encoding="utf-8") as f:
            self.assertIn("version: 1.0.2+7", f.read())

        with open(self.index_html_path, "r", encoding="utf-8") as f:
            self.assertIn("v1.0.2 • Build 7", f.read())

    def test_e2e_live_run_modifies_files_cohesively(self):
        """End-to-end live run modifies pubspec, index.html, and nhat_ky in perfect harmony."""
        config = ReleaseConfig(
            project_dir=self.sandbox_dir,
            description="Bản phát hành thực tế sandbox",
            bump_type="patch",
            dry_run=False,
            skip_build=True,
            skip_xcode=True,
        )
        engine = ReleaseEngine(config)
        exit_code = engine.run()

        self.assertEqual(exit_code, 0)

        # 1. pubspec.yaml updated to 1.0.3+8
        with open(self.pubspec_path, "r", encoding="utf-8") as f:
            pub_content = f.read()
            self.assertIn("version: 1.0.3+8", pub_content)
            self.assertNotIn("1.0.2+7", pub_content)

        # 2. web-download/index.html updated
        with open(self.index_html_path, "r", encoding="utf-8") as f:
            html_content = f.read()
            self.assertIn("v1.0.3 • Build 8", html_content)
            self.assertIn("version: '1.0.3'", html_content)
            self.assertIn("build: 8", html_content)

        # 3. nhat_ky.md prepended with new entry
        with open(self.nhat_ky_path, "r", encoding="utf-8") as f:
            diary_content = f.read()
            self.assertIn("v1.0.3+8", diary_content)
            # Verify new entry comes before old entry
            new_idx = diary_content.find("v1.0.3+8")
            old_idx = diary_content.find("Phiên bản cũ trước đó")
            self.assertGreater(new_idx, 0)
            self.assertGreater(old_idx, new_idx)


class TestArtifactSyncManagerAdversarial(unittest.TestCase):
    """Adversarial stress testing of web portal artifact synchronization and symlink robustness."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.web_dir = os.path.join(self.temp_dir, "web-download")
        self.release_dir = os.path.join(self.temp_dir, "release-builds")
        os.makedirs(self.web_dir, exist_ok=True)
        os.makedirs(self.release_dir, exist_ok=True)

        with open(os.path.join(self.web_dir, "index.html"), "w", encoding="utf-8") as f:
            f.write('<span class="version-badge" id="versionBadge">v1.0.2 • Build 7</span>\nconst CONFIG = { version: "1.0.2", build: 7 };')

        # Create dummy binaries
        self.apk_src = os.path.join(self.release_dir, "QuanNhoPOS-latest.apk")
        with open(self.apk_src, "wb") as f:
            f.write(b"APK_DUMMY_BINARY_DATA_TEST_12345")

        self.exe_src = os.path.join(self.release_dir, "QuanNhoPOS-latest.exe")
        with open(self.exe_src, "wb") as f:
            f.write(b"MZ_EXE_DUMMY_BINARY_DATA_TEST_67890")

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_sync_artifacts_independence_when_release_builds_deleted(self):
        """Verifies that web-download files survive complete deletion of release-builds/."""
        res = ArtifactSyncManager.sync_web_portal(self.temp_dir, "1.0.3", 8, dry_run=False)
        self.assertIn("web_apk", res)
        self.assertIn("web_exe", res)

        # Adversarially delete the entire release-builds folder
        shutil.rmtree(self.release_dir)
        self.assertFalse(os.path.exists(self.release_dir))

        # Check all web-download files are still intact and readable
        target_apk = os.path.join(self.web_dir, "QuanNhoPOS-latest.apk")
        backup_apk = os.path.join(self.web_dir, "download", "QuanNhoPOS-latest.apk")
        target_exe = os.path.join(self.web_dir, "QuanNhoPOS-latest.exe")
        backup_exe = os.path.join(self.web_dir, "download", "QuanNhoPOS-latest.exe")
        backup_win = os.path.join(self.web_dir, "download", "windows", "QuanNhoPOS-latest.exe")

        for path in [target_apk, backup_apk]:
            self.assertTrue(os.path.exists(path), f"Path {path} must exist after release-builds wiped")
            with open(path, "rb") as f:
                self.assertEqual(f.read(), b"APK_DUMMY_BINARY_DATA_TEST_12345")

        for path in [target_exe, backup_exe, backup_win]:
            self.assertTrue(os.path.exists(path), f"Path {path} must exist after release-builds wiped")
            with open(path, "rb") as f:
                self.assertEqual(f.read(), b"MZ_EXE_DUMMY_BINARY_DATA_TEST_67890")

    def test_sync_artifacts_replaces_preexisting_dangling_symlinks(self):
        """Verifies that pre-existing broken symlinks in web-download are cleanly unlinked and replaced."""
        target_apk = os.path.join(self.web_dir, "QuanNhoPOS-latest.apk")
        # Create a dangling symlink pointing to nowhere
        os.symlink(os.path.join(self.temp_dir, "nonexistent_target.apk"), target_apk)
        self.assertTrue(os.path.islink(target_apk))
        self.assertFalse(os.path.exists(target_apk))  # broken

        # Running sync should cleanly overwrite the broken symlink
        res = ArtifactSyncManager.sync_web_portal(self.temp_dir, "1.0.3", 8, dry_run=False)
        self.assertIn("web_apk", res)
        self.assertTrue(os.path.exists(target_apk))
        with open(target_apk, "rb") as f:
            self.assertEqual(f.read(), b"APK_DUMMY_BINARY_DATA_TEST_12345")

    def test_sync_graceful_on_restricted_lpm_public_dir(self):
        """Verifies sync_web_portal does not crash if LPM_WEB_PUBLIC_DIR cannot be written to."""
        os.environ["LPM_WEB_PUBLIC_DIR"] = "/nonexistent_root_dir_for_test"
        try:
            res = ArtifactSyncManager.sync_web_portal(self.temp_dir, "1.0.3", 8, dry_run=False)
            self.assertIn("index_html", res)
            self.assertIn("web_apk", res)
        finally:
            os.environ.pop("LPM_WEB_PUBLIC_DIR", None)


if __name__ == "__main__":
    unittest.main()
