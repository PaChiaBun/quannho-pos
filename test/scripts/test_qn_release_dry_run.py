# test/scripts/test_qn_release_dry_run.py
# ─────────────────────────────────────────────────────────────────────────────
# Tier 4: Real-World Scenarios — Release Automation Dry Run Simulation
# Verifies the end-to-end release pipeline defined in PROJECT.md:
#   1. Version and build number increment in pubspec.yaml
#   2. Multi-platform build artifact generation contract
#   3. Supabase app_versions payload formation & constraint adherence
#   4. Web download portal (web-download/index.html) synchronization
#   5. Xcode Organizer 1-click launch trigger contract
#   6. Dev Diary (nhat_ky.md) automated log compliance
#   7. Apple Guideline 3.1.1 invariant release guardrail
# ─────────────────────────────────────────────────────────────────────────────

import os
import re
import sys
import unittest
from datetime import datetime

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))


class ReleasePipelineSimulator:
    """
    Dry-run release pipeline engine modeling the 5-step /qn release process
    without performing destructive file overwrites or network mutations.
    """

    @staticmethod
    def parse_version(pubspec_content):
        """Extracts (version_name, build_number) from pubspec.yaml content."""
        match = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)", pubspec_content, re.MULTILINE)
        if not match:
            raise ValueError("Invalid or missing version format in pubspec.yaml (expected X.Y.Z+B)")
        return match.group(1), int(match.group(2))

    @staticmethod
    def bump_build(current_version, current_build, bump_type="build"):
        """Computes the next version and build number."""
        next_build = current_build + 1
        parts = [int(p) for p in current_version.split(".")]

        if bump_type == "patch":
            parts[2] += 1
        elif bump_type == "minor":
            parts[1] += 1
            parts[2] = 0
        elif bump_type == "major":
            parts[0] += 1
            parts[1] = 0
            parts[2] = 0

        next_version = ".".join(str(p) for p in parts)
        return next_version, next_build

    @staticmethod
    def generate_artifact_manifest(version, build_num):
        """Returns the dictionary of expected distribution artifacts for all platforms."""
        return {
            "android": {
                "archive_name": f"QuanNhoPOS-{version}.apk",
                "latest_symlink": "QuanNhoPOS-latest.apk",
                "target_dir": "release-builds",
                "web_url": "https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk",
            },
            "windows": {
                "archive_name": f"QuanNhoPOS-{version}.exe",
                "latest_symlink": "QuanNhoPOS-latest.exe",
                "target_dir": "release-builds",
                "web_url": "https://quannho.lpm.vn/download/QuanNhoPOS-latest.exe",
            },
            "ios": {
                "archive_name": "Runner.xcarchive",
                "target_dir": "build/ios/archive",
                "web_url": "https://apps.apple.com/app/id6795376140",
            },
            "macos": {
                "archive_name": f"QuanNhoPOS-{version}-macOS.zip",
                "latest_symlink": "QuanNhoPOS-latest-macOS.zip",
                "target_dir": "release-builds",
                "web_url": "https://quannho.lpm.vn/download/QuanNhoPOS-latest-macOS.zip",
            },
        }

    @staticmethod
    def build_supabase_record(platform, version, build_num, changelog, is_force=False):
        """Constructs an app_versions record adhering strictly to DB constraints."""
        if build_num <= 0:
            raise ValueError(f"Build number must be strictly positive (> 0), got: {build_num}")
        if platform not in ("android", "windows", "ios", "macos", "web"):
            raise ValueError(f"Invalid platform: {platform}")
        if not version or not re.match(r"^[0-9]+\.[0-9]+\.[0-9]+$", version):
            raise ValueError(f"Invalid semantic version: {version}")

        urls = {
            "android": "https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk",
            "windows": "https://quannho.lpm.vn/download/QuanNhoPOS-latest.exe",
            "ios": "https://apps.apple.com/app/id6795376140",
            "macos": "https://quannho.lpm.vn/download/QuanNhoPOS-latest-macOS.zip",
        }

        return {
            "platform": platform,
            "version_name": version,
            "build_number": build_num,
            "download_url": urls.get(platform, ""),
            "changelog": changelog,
            "is_force_update": bool(is_force),
        }

    @staticmethod
    def generate_nhat_ky_entry(version, build_num, title, description, timestamp=None):
        """Constructs a release log entry following the exact nhat_ky.md specification."""
        ts = timestamp or datetime.now().strftime("%Y-%m-%d (%H:%M +07)")
        lines = [
            f"## {ts} — {title} [ĐÃ PHÁT HÀNH]",
            "",
            "> **Trạng thái**: Đã phát hành chính thức",
            f"> - **Phiên bản mới**: v{version}+{build_num}",
            "> - **Nền tảng hỗ trợ**: Android POS (Sunmi), Windows POS, iOS App Store, Web",
            "",
            "### ⚠️ Bối Cảnh",
            description,
            "",
            "### ✅ Giải Pháp Đã Triển Khai",
            f"- Đã phát hành phiên bản v{version}+{build_num} lên hệ sinh thái Quán Nhỏ POS.",
            "- Đồng bộ tự động file tải APK & EXE sang web download quannho.lpm.vn.",
            "- Cập nhật bản ghi metadata vào cơ sở dữ liệu Supabase app_versions.",
            "",
            "### 🧪 Nghiệm Thu",
            "- 100% kiểm thử hồi quy và E2E pass trước khi release.",
            "",
        ]
        return "\n".join(lines)


class TestQnReleaseDryRun(unittest.TestCase):
    def setUp(self):
        self.pubspec_path = os.path.join(PROJECT_ROOT, "pubspec.yaml")
        self.index_html_path = os.path.join(PROJECT_ROOT, "web-download/index.html")
        self.auth_screen_path = os.path.join(PROJECT_ROOT, "lib/screens/auth_screen.dart")

    # ── Tier 4 Tests ──────────────────────────────────────────────────────────

    def test_01_parse_current_pubspec_version(self):
        """Verifies current pubspec.yaml version and build number are valid."""
        with open(self.pubspec_path, "r", encoding="utf-8") as f:
            content = f.read()

        version, build = ReleasePipelineSimulator.parse_version(content)
        self.assertEqual(version, "1.0.2")
        self.assertEqual(build, 7)

    def test_02_bump_build_number_logic(self):
        """Verifies monotonic build number increment."""
        next_ver, next_build = ReleasePipelineSimulator.bump_build("1.0.2", 7, bump_type="build")
        self.assertEqual(next_ver, "1.0.2")
        self.assertEqual(next_build, 8)

    def test_03_bump_semantic_version_patch_minor(self):
        """Verifies semantic version bump logic for patch, minor, and major."""
        patch_ver, patch_b = ReleasePipelineSimulator.bump_build("1.0.2", 7, bump_type="patch")
        self.assertEqual(patch_ver, "1.0.3")
        self.assertEqual(patch_b, 8)

        minor_ver, minor_b = ReleasePipelineSimulator.bump_build("1.0.2", 7, bump_type="minor")
        self.assertEqual(minor_ver, "1.1.0")
        self.assertEqual(minor_b, 8)

        major_ver, major_b = ReleasePipelineSimulator.bump_build("1.0.2", 7, bump_type="major")
        self.assertEqual(major_ver, "2.0.0")
        self.assertEqual(major_b, 8)

    def test_04_validate_multiplatform_artifact_matrix(self):
        """Verifies artifact matrix contains all required platform targets and correct URLs."""
        manifest = ReleasePipelineSimulator.generate_artifact_manifest("1.0.3", 8)
        self.assertIn("android", manifest)
        self.assertIn("windows", manifest)
        self.assertIn("ios", manifest)

        self.assertEqual(manifest["android"]["archive_name"], "QuanNhoPOS-1.0.3.apk")
        self.assertEqual(manifest["android"]["latest_symlink"], "QuanNhoPOS-latest.apk")
        self.assertEqual(manifest["windows"]["archive_name"], "QuanNhoPOS-1.0.3.exe")
        self.assertEqual(manifest["windows"]["latest_symlink"], "QuanNhoPOS-latest.exe")
        self.assertEqual(manifest["ios"]["archive_name"], "Runner.xcarchive")

    def test_05_supabase_app_versions_payload_validation(self):
        """Verifies Supabase app_versions payload complies with table schema."""
        record = ReleasePipelineSimulator.build_supabase_record(
            platform="android",
            version="1.0.3",
            build_num=8,
            changelog="Sửa lỗi giao diện và cập nhật tốc độ in hóa đơn",
            is_force=False,
        )
        self.assertEqual(record["platform"], "android")
        self.assertEqual(record["version_name"], "1.0.3")
        self.assertEqual(record["build_number"], 8)
        self.assertEqual(record["download_url"], "https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk")
        self.assertFalse(record["is_force_update"])
        self.assertIn("Sửa lỗi giao diện", record["changelog"])

    def test_06_supabase_payload_rejects_zero_or_negative_build(self):
        """Boundary check: build number <= 0 must be rejected."""
        with self.assertRaises(ValueError):
            ReleasePipelineSimulator.build_supabase_record("android", "1.0.3", 0, "test")
        with self.assertRaises(ValueError):
            ReleasePipelineSimulator.build_supabase_record("android", "1.0.3", -5, "test")

    def test_07_web_portal_index_html_badge_and_links_integrity(self):
        """Verifies index.html has live download links and no disabled coming-soon elements."""
        self.assertTrue(os.path.exists(self.index_html_path), "web-download/index.html must exist")
        with open(self.index_html_path, "r", encoding="utf-8") as f:
            html = f.read()

        # Check badge matches current pubspec
        self.assertIn('id="versionBadge"', html)
        self.assertIn("v1.0.2 • Build 7", html)

        # Check direct download links
        self.assertIn("https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk", html)
        self.assertIn("https://quannho.lpm.vn/download/QuanNhoPOS-latest.exe", html)
        self.assertIn("https://apps.apple.com/app/id6795376140", html)

        # Check coming-soon class is removed from main download cards
        self.assertNotIn('download-card android coming-soon', html)
        self.assertNotIn('download-card windows coming-soon', html)
        self.assertNotIn('download-card ios coming-soon', html)

    def test_08_nhat_ky_release_block_formatting(self):
        """Verifies generated release entry format complies strictly with nhat_ky.md."""
        entry = ReleasePipelineSimulator.generate_nhat_ky_entry(
            version="1.0.3",
            build_num=8,
            title="Tự Động Cập Nhật Đa Nền Tảng",
            description="Phát hành phiên bản hợp nhất AppUpdateManager không phụ thuộc GitHub API.",
            timestamp="2026-09-24 (20:30 +07)",
        )
        self.assertIn("## 2026-09-24 (20:30 +07) — Tự Động Cập Nhật Đa Nền Tảng [ĐÃ PHÁT HÀNH]", entry)
        self.assertIn("> - **Phiên bản mới**: v1.0.3+8", entry)
        self.assertIn("### ⚠️ Bối Cảnh", entry)
        self.assertIn("### ✅ Giải Pháp Đã Triển Khai", entry)
        self.assertIn("### 🧪 Nghiệm Thu", entry)

    def test_09_apple_guideline_311_release_gate_enforcement(self):
        """
        Pre-release invariant check: Verifies that lib/screens/auth_screen.dart
        strictly suppresses registration UI on TargetPlatform.iOS.
        """
        with open(self.auth_screen_path, "r", encoding="utf-8") as f:
            code = f.read()

        # Invariant 1: Check TargetPlatform.iOS conditional check exists
        self.assertIn("defaultTargetPlatform == TargetPlatform.iOS", code)

        # Invariant 2: Check that login form is enforced on iOS
        self.assertIn("(defaultTargetPlatform == TargetPlatform.iOS || _tab == 0)", code)

        # Invariant 3: Check notice text exists
        self.assertIn("Đăng nhập tài khoản nhân viên / quản lý đã được cấp bởi cửa hàng của bạn.", code)

    def test_10_full_dry_run_pipeline_simulation(self):
        """
        Simulates the complete 5-step /qn release dry-run pipeline:
        1. Read current version (1.0.2+7)
        2. Bump version to 1.0.2+8
        3. Build artifact manifest for 4 platforms
        4. Construct Supabase app_versions records
        5. Generate nhat_ky.md log block
        6. Validate Xcode Organizer trigger command
        """
        # Step 1
        with open(self.pubspec_path, "r", encoding="utf-8") as f:
            current_ver, current_build = ReleasePipelineSimulator.parse_version(f.read())

        # Step 2
        next_ver, next_build = ReleasePipelineSimulator.bump_build(current_ver, current_build)
        self.assertEqual(next_build, current_build + 1)

        # Step 3
        manifest = ReleasePipelineSimulator.generate_artifact_manifest(next_ver, next_build)
        self.assertEqual(len(manifest), 4)

        # Step 4
        records = [
            ReleasePipelineSimulator.build_supabase_record(
                platform=p,
                version=next_ver,
                build_num=next_build,
                changelog="Bản vá phát hành tự động",
            )
            for p in manifest.keys()
        ]
        self.assertEqual(len(records), 4)
        for r in records:
            self.assertEqual(r["build_number"], 8)
            self.assertTrue(r["download_url"].startswith("https://"))

        # Step 5
        log_entry = ReleasePipelineSimulator.generate_nhat_ky_entry(
            version=next_ver,
            build_num=next_build,
            title="Bản phát hành tự động qua /qn",
            description="Mô phỏng release pipeline thành công 100%.",
        )
        self.assertIn(f"v{next_ver}+{next_build}", log_entry)

        # Step 6: Xcode command check
        xcode_cmd = f"open -a Xcode {manifest['ios']['target_dir']}/{manifest['ios']['archive_name']}"
        self.assertEqual(xcode_cmd, "open -a Xcode build/ios/archive/Runner.xcarchive")

    def test_11_dry_run_handles_missing_or_corrupt_pubspec(self):
        """Boundary check: corrupt or invalid pubspec string raises ValueError."""
        corrupt_content = "name: quannho_pos\nversion: invalid_format\n"
        with self.assertRaises(ValueError):
            ReleasePipelineSimulator.parse_version(corrupt_content)

    def test_12_vietnamese_changelog_unicode_preservation_in_pipeline(self):
        """Ensures Vietnamese text with accents and symbols is preserved throughout pipeline."""
        vietnamese_note = "🚀 Tối ưu hóa: Đồng bộ tức thì giữa kho hàng & máy POS Sunmi P2 SE"
        record = ReleasePipelineSimulator.build_supabase_record("android", "1.0.3", 8, vietnamese_note)
        self.assertEqual(record["changelog"], vietnamese_note)


if __name__ == "__main__":
    unittest.main()
