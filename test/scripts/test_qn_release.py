#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
test/scripts/test_qn_release.py
─────────────────────────────────────────────────────────────────────────────
Comprehensive Unit & Integration Test Suite for scripts/qn_release.py
Verifies:
  1. CLI argument parsing (supports /qn, 'phát hành bản mới', options)
  2. Version parsing & bumping in pubspec.yaml (build, patch, minor, major)
  3. Pre-release Apple Guideline 3.1.1 invariant guardrail enforcement
  4. Multi-platform build matrix generation
  5. Artifact web synchronization & index.html version badge updates
  6. Supabase app_versions payload validation & schema constraint compliance
  7. Xcode Organizer command formation
  8. Dev Diary (nhat_ky.md) automated structured entry generation & prepend
  9. Subprocess end-to-end dry-run execution
─────────────────────────────────────────────────────────────────────────────
"""

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


class TestQnReleaseArgumentParsing(unittest.TestCase):
    """Verifies CLI argument normalization and parsing."""

    def test_default_arguments(self):
        config = parse_arguments([])
        self.assertEqual(config.bump_type, "build")
        self.assertFalse(config.dry_run)
        self.assertFalse(config.skip_build)
        self.assertIn("android", config.platforms)
        self.assertIn("ios", config.platforms)

    def test_dry_run_and_skip_build_flags(self):
        config = parse_arguments(["--dry-run", "--skip-build"])
        self.assertTrue(config.dry_run)
        self.assertTrue(config.skip_build)

    def test_vietnamese_command_normalization(self):
        config = parse_arguments(["phát hành bản mới", "Nâng cấp giao diện hóa đơn"])
        self.assertIn("Nâng cấp giao diện hóa đơn", config.description)

        config2 = parse_arguments(["/qn", "phát hành bản mới", "Sửa lỗi kết nối máy in", "--dry-run"])
        self.assertIn("Sửa lỗi kết nối máy in", config2.description)
        self.assertTrue(config2.dry_run)

    def test_platforms_filtering_flag(self):
        config = parse_arguments(["--platforms=android,web", "--dry-run"])
        self.assertEqual(config.platforms, ["android", "web"])

    def test_bump_type_options(self):
        for bump in ["build", "patch", "minor", "major"]:
            config = parse_arguments([f"--bump={bump}"])
            self.assertEqual(config.bump_type, bump)


class TestVersionManager(unittest.TestCase):
    """Verifies pubspec.yaml version extraction, incrementing, and updating."""

    SAMPLE_PUBSPEC = """name: quannho_pos
description: "Quán Nhỏ POS"
version: 1.0.2+7
environment:
  sdk: ^3.11.5
"""

    def test_parse_valid_version(self):
        version, build = VersionManager.parse_version(self.SAMPLE_PUBSPEC)
        self.assertEqual(version, "1.0.2")
        self.assertEqual(build, 7)

    def test_parse_invalid_version_raises(self):
        with self.assertRaises(ValueError):
            VersionManager.parse_version("name: test\nversion: invalid\n")

    def test_bump_build_number_only(self):
        ver, build = VersionManager.bump("1.0.2", 7, "build")
        self.assertEqual(ver, "1.0.2")
        self.assertEqual(build, 8)

    def test_bump_patch(self):
        ver, build = VersionManager.bump("1.0.2", 7, "patch")
        self.assertEqual(ver, "1.0.3")
        self.assertEqual(build, 8)

    def test_bump_minor(self):
        ver, build = VersionManager.bump("1.0.2", 7, "minor")
        self.assertEqual(ver, "1.1.0")
        self.assertEqual(build, 8)

    def test_bump_major(self):
        ver, build = VersionManager.bump("1.0.2", 7, "major")
        self.assertEqual(ver, "2.0.0")
        self.assertEqual(build, 8)

    def test_bump_invalid_type_raises(self):
        with self.assertRaises(ValueError):
            VersionManager.bump("1.0.2", 7, "unknown_type")

    def test_update_pubspec_file_content(self):
        temp_dir = tempfile.mkdtemp()
        try:
            pubspec_file = os.path.join(temp_dir, "pubspec.yaml")
            with open(pubspec_file, "w", encoding="utf-8") as f:
                f.write(self.SAMPLE_PUBSPEC)

            # Test dry_run doesn't write
            VersionManager.update_pubspec_file(pubspec_file, "1.0.3", 8, dry_run=True)
            with open(pubspec_file, "r", encoding="utf-8") as f:
                self.assertIn("version: 1.0.2+7", f.read())

            # Test live write updates version line and preserves others
            VersionManager.update_pubspec_file(pubspec_file, "1.0.3", 8, dry_run=False)
            with open(pubspec_file, "r", encoding="utf-8") as f:
                content = f.read()
                self.assertIn("version: 1.0.3+8", content)
                self.assertIn("name: quannho_pos", content)
                self.assertIn("sdk: ^3.11.5", content)
        finally:
            shutil.rmtree(temp_dir)


class TestInvariantGuard(unittest.TestCase):
    """Verifies Apple App Store Guideline 3.1.1 pre-release invariant enforcement."""

    def test_live_auth_screen_passes_invariant(self):
        ok, msg = InvariantGuard.verify_ios_guideline_311(PROJECT_ROOT)
        self.assertTrue(ok)
        self.assertIn("Apple Guideline 3.1.1 invariant verified", msg)

    def test_missing_ios_guard_raises_violation(self):
        temp_dir = tempfile.mkdtemp()
        try:
            screens_dir = os.path.join(temp_dir, "lib", "screens")
            os.makedirs(screens_dir, exist_ok=True)
            auth_file = os.path.join(screens_dir, "auth_screen.dart")

            # Corrupt content: missing TargetPlatform.iOS guard
            with open(auth_file, "w", encoding="utf-8") as f:
                f.write("class AuthScreen extends StatefulWidget {}")

            with self.assertRaises(InvariantViolationError):
                InvariantGuard.verify_ios_guideline_311(temp_dir)
        finally:
            shutil.rmtree(temp_dir)

    def test_missing_neutral_instruction_raises_violation(self):
        temp_dir = tempfile.mkdtemp()
        try:
            screens_dir = os.path.join(temp_dir, "lib", "screens")
            os.makedirs(screens_dir, exist_ok=True)
            auth_file = os.path.join(screens_dir, "auth_screen.dart")

            # Missing neutral instruction text
            with open(auth_file, "w", encoding="utf-8") as f:
                f.write("""
                if (defaultTargetPlatform == TargetPlatform.iOS) {
                  // missing neutral text
                }
                child: (defaultTargetPlatform == TargetPlatform.iOS || _tab == 0)
                """)

            with self.assertRaises(InvariantViolationError):
                InvariantGuard.verify_ios_guideline_311(temp_dir)
        finally:
            shutil.rmtree(temp_dir)


class TestBuildOrchestrator(unittest.TestCase):
    """Verifies build matrix commands, targets, and simulated compilation."""

    def test_build_matrix_coverage(self):
        matrix = BuildOrchestrator.get_build_matrix("1.0.3", 8)
        self.assertIn("android", matrix)
        self.assertIn("ios", matrix)
        self.assertIn("macos", matrix)
        self.assertIn("web", matrix)
        self.assertIn("windows", matrix)

        self.assertEqual(matrix["android"]["dist_apk"], "release-builds/QuanNhoPOS-1.0.3.apk")
        self.assertEqual(matrix["ios"]["archive_path"], "build/ios/archive/Runner.xcarchive")
        self.assertEqual(matrix["web"]["dist_tar"], "release-builds/QuanNhoPOS-1.0.3-web.tar.gz")

    def test_simulated_build_dry_run_returns_true(self):
        config = ReleaseConfig(dry_run=True, skip_build=False)
        for platform in ["android", "ios", "macos", "web", "windows"]:
            result = BuildOrchestrator.execute_build(platform, config, "1.0.3", 8)
            self.assertTrue(result, f"Build simulation failed for {platform}")


class TestArtifactSyncManager(unittest.TestCase):
    """Verifies web portal badge and script CONFIG synchronization."""

    SAMPLE_HTML = """<!DOCTYPE html>
<html>
<head><title>Quán Nhỏ POS</title></head>
<body>
  <span class="version-badge" id="versionBadge">v1.0.2 • Build 7</span>
  <script>
    const CONFIG = {
      version: '1.0.2',
      build: 7,
    };
  </script>
</body>
</html>
"""

    def test_web_portal_html_sync(self):
        temp_dir = tempfile.mkdtemp()
        try:
            web_dir = os.path.join(temp_dir, "web-download")
            os.makedirs(web_dir, exist_ok=True)
            index_path = os.path.join(web_dir, "index.html")

            with open(index_path, "w", encoding="utf-8") as f:
                f.write(self.SAMPLE_HTML)

            # Test dry_run doesn't write
            results = ArtifactSyncManager.sync_web_portal(temp_dir, "1.0.3", 8, dry_run=True)
            self.assertEqual(results.get("index_html"), "v1.0.3 • Build 8")
            with open(index_path, "r", encoding="utf-8") as f:
                self.assertIn("v1.0.2 • Build 7", f.read())

            # Test live write updates badge and config
            ArtifactSyncManager.sync_web_portal(temp_dir, "1.0.3", 8, dry_run=False)
            with open(index_path, "r", encoding="utf-8") as f:
                updated = f.read()
                self.assertIn("v1.0.3 • Build 8", updated)
                self.assertIn("version: '1.0.3',", updated)
                self.assertIn("build: 8,", updated)
        finally:
            shutil.rmtree(temp_dir)


class TestSupabaseSyncManager(unittest.TestCase):
    """Verifies Supabase app_versions payload generation and boundary validation."""

    def test_build_valid_records(self):
        for platform in ["android", "windows", "ios", "macos"]:
            rec = SupabaseSyncManager.build_record(
                platform=platform,
                version="1.0.3",
                build_num=8,
                changelog="Cập nhật hệ thống POS",
                is_force=False,
            )
            self.assertEqual(rec["platform"], platform)
            self.assertEqual(rec["version_name"], "1.0.3")
            self.assertEqual(rec["build_number"], 8)
            self.assertTrue(rec["download_url"].startswith("https://"))

    def test_reject_zero_or_negative_build_number(self):
        with self.assertRaises(ValueError):
            SupabaseSyncManager.build_record("android", "1.0.3", 0, "Changelog")
        with self.assertRaises(ValueError):
            SupabaseSyncManager.build_record("android", "1.0.3", -1, "Changelog")

    def test_reject_invalid_platform(self):
        with self.assertRaises(ValueError):
            SupabaseSyncManager.build_record("blackberry", "1.0.3", 8, "Changelog")

    def test_reject_invalid_version_string(self):
        with self.assertRaises(ValueError):
            SupabaseSyncManager.build_record("android", "invalid_ver", 8, "Changelog")

    def test_dry_run_publish_returns_dry_run_status(self):
        config = ReleaseConfig(dry_run=True)
        rec = SupabaseSyncManager.build_record("android", "1.0.3", 8, "Changelog")
        res = SupabaseSyncManager.publish_version(rec, config)
        self.assertEqual(res.get("status"), "dry-run")


class TestXcodeLauncher(unittest.TestCase):
    """Verifies Xcode Organizer command formation and execution logic."""

    def test_xcode_command_in_dry_run(self):
        config = ReleaseConfig(dry_run=True)
        ok, cmd = XcodeLauncher.launch(PROJECT_ROOT, config)
        self.assertTrue(ok)
        self.assertTrue(cmd.startswith("open -a Xcode"))
        self.assertIn("Runner.xcarchive", cmd)


class TestDevDiaryManager(unittest.TestCase):
    """Verifies nhat_ky.md release log formatting and prepend insertion."""

    SAMPLE_NHAT_KY = """# Nhật Ký Phát Triển — Quán Nhỏ POS

> Ghi lại công việc mỗi ngày để dễ theo dõi tiến độ.
> Format: ✅ Hoàn thành | 🔲 Cần làm | ⚠️ Vấn đề | ➡️ Tiếp theo

## 2026-09-24 (14:00 +07) — Mục cũ trước đó [ĐÃ HOÀN THÀNH]
> Nội dung cũ...
"""

    def test_generate_entry_contains_required_sections(self):
        entry = DevDiaryManager.generate_entry(
            version="1.0.3",
            build_num=8,
            title="Bản Phát Hành Mới",
            description="Tự động hóa hoàn toàn luồng phát hành.",
            timestamp="2026-09-24 (21:00 +07)",
        )
        self.assertIn("## 2026-09-24 (21:00 +07) — Phát Hành Phiên Bản v1.0.3+8: Bản Phát Hành Mới [ĐÃ PHÁT HÀNH]", entry)
        self.assertIn("> - **Phiên bản mới**: v1.0.3+8 (Build 8).", entry)
        self.assertIn("### ⚠️ Bối Cảnh", entry)
        self.assertIn("### ✅ Giải Pháp Đã Triển Khai", entry)
        self.assertIn("### 🧪 Nghiệm Thu", entry)

    def test_prepend_to_nhat_ky(self):
        temp_dir = tempfile.mkdtemp()
        try:
            nhat_ky_file = os.path.join(temp_dir, "nhat_ky.md")
            with open(nhat_ky_file, "w", encoding="utf-8") as f:
                f.write(self.SAMPLE_NHAT_KY)

            entry = DevDiaryManager.generate_entry("1.0.3", 8, "Test Title", "Test Desc", "2026-09-24 (21:00 +07)")

            # Dry run test
            DevDiaryManager.prepend_to_nhat_ky(nhat_ky_file, entry, dry_run=True)
            with open(nhat_ky_file, "r", encoding="utf-8") as f:
                self.assertNotIn("v1.0.3+8", f.read())

            # Live prepend test
            DevDiaryManager.prepend_to_nhat_ky(nhat_ky_file, entry, dry_run=False)
            with open(nhat_ky_file, "r", encoding="utf-8") as f:
                content = f.read()
                # Verify new entry is placed before the old entry
                new_idx = content.find("v1.0.3+8")
                old_idx = content.find("Mục cũ trước đó")
                self.assertGreater(new_idx, 0)
                self.assertGreater(old_idx, new_idx)
        finally:
            shutil.rmtree(temp_dir)


class TestCliSubprocessExecution(unittest.TestCase):
    """End-to-end integration tests executing scripts via subprocess."""

    def test_python_script_dry_run(self):
        cmd = [
            sys.executable,
            os.path.join(PROJECT_ROOT, "scripts", "qn_release.py"),
            "--dry-run",
            "Kiểm tra luồng dry-run toàn diện",
        ]
        res = subprocess.run(cmd, cwd=PROJECT_ROOT, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Error: {res.stderr}")
        self.assertIn("QUÁN NHỎ POS", res.stdout)
        self.assertIn("PHÁT HÀNH HOÀN TẤT THÀNH CÔNG", res.stdout)
        self.assertIn("Apple Guideline 3.1.1 invariant verified", res.stdout)

    def test_bash_qn_wrapper_dry_run(self):
        wrapper = os.path.join(PROJECT_ROOT, "scripts", "qn")
        cmd = [wrapper, "phát hành bản mới", "Kiểm tra bash wrapper", "--dry-run"]
        res = subprocess.run(cmd, cwd=PROJECT_ROOT, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Error: {res.stderr}")
        self.assertIn("PHÁT HÀNH HOÀN TẤT THÀNH CÔNG", res.stdout)

    def test_bash_qn_cli_wrapper_dry_run(self):
        wrapper = os.path.join(PROJECT_ROOT, "scripts", "qn_cli.sh")
        cmd = [wrapper, "--dry-run", "Kiểm tra qn_cli.sh wrapper"]
        res = subprocess.run(cmd, cwd=PROJECT_ROOT, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Error: {res.stderr}")
        self.assertIn("PHÁT HÀNH HOÀN TẤT THÀNH CÔNG", res.stdout)


if __name__ == "__main__":
    unittest.main()
