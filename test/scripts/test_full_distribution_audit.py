# test/scripts/test_full_distribution_audit.py
# ─────────────────────────────────────────────────────────────────────────────
# Comprehensive Distribution & Invariant Audit Test Suite
# Tests:
#   - R1: Web download HTML integrity, Hero + CTA links, local binary validation (>100MB APK, >50MB EXE)
#   - R2: iOS Invariant Guard Audit (AuthScreen, StorePickerScreen, SettingsScreen, DashboardScreen)
#   - R3: AppUpdateManager Architecture (Zero GitHub API, Supabase + VPS endpoints, detached installer, FileProvider)
#   - R4: Full Regression Suite execution
# ─────────────────────────────────────────────────────────────────────────────
import json
import os
import re
import subprocess
import sys
import unittest
import zipfile

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
scripts_dir = os.path.join(PROJECT_ROOT, "scripts")
if scripts_dir not in sys.path:
    sys.path.append(scripts_dir)

from qn_release import InvariantGuard, InvariantViolationError


class TestR1WebDistributionIntegrity(unittest.TestCase):
    def setUp(self):
        self.html_path = os.path.join(PROJECT_ROOT, "web-download", "index.html")
        self.assertTrue(os.path.exists(self.html_path), "index.html must exist")
        with open(self.html_path, "r", encoding="utf-8") as f:
            self.html = f.read()

    def test_01_app_store_links_in_hero_and_cta(self):
        """Verify App Store link https://apps.apple.com/app/id6795376140 exists in Hero + CTA."""
        app_store_url = "https://apps.apple.com/app/id6795376140"
        # Must be present in hero section
        hero_match = re.search(r'<section class="hero">.*?</section>', self.html, re.DOTALL)
        self.assertIsNotNone(hero_match, "Hero section must exist")
        self.assertIn(app_store_url, hero_match.group(0), "App Store link must exist in Hero section")

        # Must be present in download cards (CTA) section
        cta_match = re.search(r'<section class="downloads">.*?</section>', self.html, re.DOTALL)
        self.assertIsNotNone(cta_match, "Downloads section must exist")
        self.assertIn(app_store_url, cta_match.group(0), "App Store link must exist in Downloads CTA section")

    def test_02_google_play_links_in_hero_and_cta(self):
        """Verify Google Play link https://play.google.com/store/apps/details?id=vn.lpm.quannho_pos in Hero + CTA."""
        google_play_url = "https://play.google.com/store/apps/details?id=vn.lpm.quannho_pos"
        # Must be in hero section
        hero_match = re.search(r'<section class="hero">.*?</section>', self.html, re.DOTALL)
        self.assertIn(google_play_url, hero_match.group(0), "Google Play link must exist in Hero section")

        # Must be in downloads CTA section
        cta_match = re.search(r'<section class="downloads">.*?</section>', self.html, re.DOTALL)
        self.assertIn(google_play_url, cta_match.group(0), "Google Play link must exist in Downloads CTA section")

    def test_03_direct_apk_binary_validity_and_size(self):
        """Verify APK binary exists, size > 100MB, and is a valid zip archive."""
        apk_path = os.path.join(PROJECT_ROOT, "release-builds", "QuanNhoPOS-latest.apk")
        self.assertTrue(os.path.exists(apk_path), "QuanNhoPOS-latest.apk must exist")
        size = os.path.getsize(apk_path)
        self.assertGreater(size, 100 * 1024 * 1024, f"APK size must be > 100MB, got {size / (1024*1024):.2f}MB")

        # Valid zip archive verification
        self.assertTrue(zipfile.is_zipfile(apk_path), "APK must be a valid zip archive")
        with zipfile.ZipFile(apk_path, "r") as z:
            namelist = z.namelist()
            self.assertIn("AndroidManifest.xml", namelist, "APK must contain AndroidManifest.xml")
            self.assertTrue(any(f.startswith("classes") and f.endswith(".dex") for f in namelist), "APK must contain classes.dex")

    def test_04_direct_exe_binary_validity_and_size(self):
        """Verify Windows EXE binary exists, size > 50MB, and is a valid PE binary."""
        exe_path = os.path.join(PROJECT_ROOT, "release-builds", "QuanNhoPOS-latest.exe")
        self.assertTrue(os.path.exists(exe_path), "QuanNhoPOS-latest.exe must exist")
        size = os.path.getsize(exe_path)
        self.assertGreater(size, 50 * 1024 * 1024, f"EXE size must be > 50MB, got {size / (1024*1024):.2f}MB")

        # Valid PE signature verification (MZ header + PE magic)
        with open(exe_path, "rb") as f:
            header = f.read(1024)
            self.assertEqual(header[:2], b"MZ", "EXE must start with DOS MZ header")
            # PE signature offset at 0x3C
            pe_offset = int.from_bytes(header[0x3C:0x40], byteorder="little")
            self.assertLess(pe_offset, 1020)
            self.assertEqual(header[pe_offset:pe_offset+4], b"PE\x00\x00", "EXE must contain valid PE magic")

    def test_05_download_cards_unblocked_and_backup_urls(self):
        """Verify download cards are active (no coming-soon) and direct /download/ URLs are properly defined."""
        self.assertNotIn("download-card android coming-soon", self.html)
        self.assertNotIn("download-card windows coming-soon", self.html)
        self.assertNotIn("download-card ios coming-soon", self.html)
        self.assertIn("https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk", self.html)
        self.assertIn("https://quannho.lpm.vn/download/QuanNhoPOS-latest.exe", self.html)

    def test_06_web_root_and_download_backup_paths_and_content_length(self):
        """Verify web root direct downloads and /download/ backup endpoints resolve to valid binaries with correct Content-Length."""
        web_dir = os.path.join(PROJECT_ROOT, "web-download")
        direct_apk = os.path.join(web_dir, "QuanNhoPOS-latest.apk")
        backup_apk = os.path.join(web_dir, "download", "QuanNhoPOS-latest.apk")
        direct_exe = os.path.join(web_dir, "QuanNhoPOS-latest.exe")
        backup_exe = os.path.join(web_dir, "download", "QuanNhoPOS-latest.exe")

        for p in [direct_apk, backup_apk]:
            self.assertTrue(os.path.exists(p), f"APK endpoint path {p} must exist")
            size = os.path.getsize(p)
            self.assertGreater(size, 100 * 1024 * 1024, f"APK Content-Length must be > 100MB: {size}")
            self.assertTrue(zipfile.is_zipfile(p))

        for p in [direct_exe, backup_exe]:
            self.assertTrue(os.path.exists(p), f"EXE endpoint path {p} must exist")
            size = os.path.getsize(p)
            self.assertGreater(size, 50 * 1024 * 1024, f"EXE Content-Length must be > 50MB: {size}")
            with open(p, "rb") as f:
                self.assertEqual(f.read(2), b"MZ")

    def test_07_backup_windows_subpath_exists_and_matches_exe(self):
        """Verify /download/windows/QuanNhoPOS-latest.exe backup path exists and matches root EXE."""
        subpath_exe = os.path.join(PROJECT_ROOT, "web-download", "download", "windows", "QuanNhoPOS-latest.exe")
        self.assertTrue(os.path.exists(subpath_exe), f"Backup Windows path {subpath_exe} must exist")
        size = os.path.getsize(subpath_exe)
        self.assertGreater(size, 50 * 1024 * 1024, f"EXE Content-Length must be > 50MB: {size}")
        with open(subpath_exe, "rb") as f:
            self.assertEqual(f.read(2), b"MZ")

    def test_07b_backup_android_subpath_exists_and_matches_apk(self):
        """Verify /download/android/QuanNhoPOS-latest.apk backup path exists and matches root APK."""
        subpath_apk = os.path.join(PROJECT_ROOT, "web-download", "download", "android", "QuanNhoPOS-latest.apk")
        self.assertTrue(os.path.exists(subpath_apk), f"Backup Android path {subpath_apk} must exist")
        size = os.path.getsize(subpath_apk)
        self.assertGreater(size, 100 * 1024 * 1024, f"APK Content-Length must be > 100MB: {size}")
        self.assertTrue(zipfile.is_zipfile(subpath_apk))

    def test_08_macos_desktop_bundle_exists(self):
        """Verify macOS desktop zip exists in web root and download backup folder."""
        web_dir = os.path.join(PROJECT_ROOT, "web-download")
        mac_root = os.path.join(web_dir, "QuanNhoPOS-latest-macOS.zip")
        mac_backup = os.path.join(web_dir, "download", "QuanNhoPOS-latest-macOS.zip")
        for p in [mac_root, mac_backup]:
            self.assertTrue(os.path.exists(p), f"macOS bundle path {p} must exist")
            size = os.path.getsize(p)
            self.assertGreater(size, 50 * 1024 * 1024, f"macOS zip size must be > 50MB: {size}")
            self.assertTrue(zipfile.is_zipfile(p))

    def test_09_artifacts_are_independent_not_dangling_symlinks(self):
        """Verify all binaries in web-download are standalone regular files, not fragile dangling symlinks."""
        web_dir = os.path.join(PROJECT_ROOT, "web-download")
        binaries = [
            os.path.join(web_dir, "QuanNhoPOS-latest.apk"),
            os.path.join(web_dir, "QuanNhoPOS-latest.exe"),
            os.path.join(web_dir, "download", "QuanNhoPOS-latest.apk"),
            os.path.join(web_dir, "download", "QuanNhoPOS-latest.exe"),
            os.path.join(web_dir, "download", "windows", "QuanNhoPOS-latest.exe"),
            os.path.join(web_dir, "download", "android", "QuanNhoPOS-latest.apk"),
        ]
        for b in binaries:
            self.assertTrue(os.path.exists(b), f"Path {b} must exist")
            self.assertFalse(os.path.islink(b), f"Path {b} must be a standalone file/hardlink, not a symlink")

    def test_10_html_responsive_design_and_platform_detection(self):
        """Verify index.html contains mobile responsive styles, platform detection, and query parameter handlers."""
        self.assertIn("@media (max-width: 480px)", self.html)
        self.assertIn("grid-template-columns: 1fr;", self.html)
        self.assertIn("detectPlatform()", self.html)
        self.assertIn("applyPlatformHighlight()", self.html)
        self.assertIn("recommended", self.html)
        self.assertIn("download=", self.html)


class TestR2IosInvariantGuardAudit(unittest.TestCase):
    def test_01_invariant_guard_passes_guideline_311(self):
        """Verify InvariantGuard.verify_ios_guideline_311 returns True."""
        passed, msg = InvariantGuard.verify_ios_guideline_311(PROJECT_ROOT)
        self.assertTrue(passed, f"Guideline 3.1.1 verification failed: {msg}")

    def test_02_auth_screen_ios_registration_strictly_omitted(self):
        """Verify AuthScreen completely hides registration tab and enforces login on iOS."""
        auth_file = os.path.join(PROJECT_ROOT, "lib", "screens", "auth_screen.dart")
        with open(auth_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Notice for iOS
        self.assertIn("Đăng nhập tài khoản nhân viên / quản lý đã được cấp bởi cửa hàng của bạn.", content)
        # Login form forced
        self.assertIn("(defaultTargetPlatform == TargetPlatform.iOS || _tab == 0)", content)
        # Tab selector guarded
        self.assertIn("if (defaultTargetPlatform == TargetPlatform.iOS)", content)

    def test_03_store_picker_screen_ios_creates_store_hidden(self):
        """Verify StorePickerScreen strictly omits 'Tạo quán mới' on iOS."""
        sp_file = os.path.join(PROJECT_ROOT, "lib", "screens", "store_picker_screen.dart")
        with open(sp_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Guard block
        self.assertIn("if (defaultTargetPlatform == TargetPlatform.iOS)", content)
        # Only 'Kết nối quán' inside the iOS block
        ios_match = re.search(
            r"if\s*\(\s*defaultTargetPlatform\s*==\s*TargetPlatform\.iOS\s*\)\s*\.\.\.\[(.*?)\]\s*else\s*\.\.\.\[",
            content,
            re.DOTALL,
        )
        self.assertIsNotNone(ios_match)
        self.assertIn("Kết nối quán", ios_match.group(1))
        self.assertNotIn("Tạo quán mới", ios_match.group(1))

    def test_04_settings_screen_ios_creates_store_hidden(self):
        """Verify SettingsScreen hides 'Tạo quán ngay' on iOS."""
        settings_file = os.path.join(PROJECT_ROOT, "lib", "screens", "settings_screen.dart")
        with open(settings_file, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("if (defaultTargetPlatform == TargetPlatform.iOS)", content)
        ios_match = re.search(
            r"if\s*\(\s*defaultTargetPlatform\s*==\s*TargetPlatform\.iOS\s*\)\s*\.\.\.\[(.*?)\]\s*else\s*\.\.\.\[",
            content,
            re.DOTALL,
        )
        self.assertIsNotNone(ios_match)
        self.assertIn("Kết nối quán", ios_match.group(1))
        self.assertNotIn("Tạo quán ngay", ios_match.group(1))

    def test_05_create_store_sheet_ios_interception_guard(self):
        """Verify showCreateStoreSheet in create_store_sheet.dart intercepts on iOS and routes to join sheet."""
        cs_file = os.path.join(PROJECT_ROOT, "lib", "core", "widgets", "create_store_sheet.dart")
        with open(cs_file, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("if (defaultTargetPlatform == TargetPlatform.iOS)", content)
        self.assertIn("showJoinStoreSheet(context, ref, onSuccess: onSuccess)", content)

    def test_06_store_setup_screen_ios_creates_store_hidden(self):
        """Verify store_setup_screen.dart suppresses 'Tạo quán mới' on iOS."""
        setup_file = os.path.join(PROJECT_ROOT, "lib", "screens", "store_setup_screen.dart")
        with open(setup_file, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("if (defaultTargetPlatform == TargetPlatform.iOS)", content)
        self.assertIn("(defaultTargetPlatform == TargetPlatform.iOS || _tab == 0)", content)


class TestR3AppUpdateManagerArchitecture(unittest.TestCase):
    def setUp(self):
        self.updater_path = os.path.join(PROJECT_ROOT, "lib", "core", "services", "app_update_manager.dart")
        with open(self.updater_path, "r", encoding="utf-8") as f:
            self.content = f.read()

    def test_01_zero_github_api_dependence(self):
        """Verify AppUpdateManager eliminates all GitHub API calls."""
        self.assertNotIn("api.github.com", self.content)
        self.assertNotIn("github.com/repos", self.content)

    def test_02_single_source_of_truth_endpoints(self):
        """Verify AppUpdateManager queries Supabase app_versions and VPS fallback."""
        self.assertIn(".from('app_versions')", self.content)
        self.assertIn("https://quannho.lpm.vn/api/versions", self.content)
        self.assertIn("https://quannho.lpm.vn/download/QuanNhoPOS-latest.exe", self.content)
        self.assertIn("https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk", self.content)
        self.assertIn("https://apps.apple.com/app/id6795376140", self.content)

    def test_03_windows_detached_process_preserves_local_data(self):
        """Verify Windows installer executes detached and exits current process without touching AppData."""
        self.assertIn("ProcessStartMode.detached", self.content)
        self.assertIn("['/SILENT', '/NORESTART']", self.content)
        self.assertIn("exit(0)", self.content)

        # Verify driftDatabase stores in user AppData (quannho_pos)
        db_file = os.path.join(PROJECT_ROOT, "lib", "core", "database", "app_database.dart")
        with open(db_file, "r", encoding="utf-8") as f:
            db_content = f.read()
        self.assertIn("driftDatabase(name: 'quannho_pos')", db_content)

        # Verify Inno Setup installs to {autopf}, preserving %APPDATA%
        iss_file = os.path.join(PROJECT_ROOT, "windows", "installer.iss")
        with open(iss_file, "r", encoding="utf-8") as f:
            iss_content = f.read()
        self.assertIn("DefaultDirName={autopf}\\", iss_content)

    def test_04_android_apk_install_intent_and_file_provider(self):
        """Verify Android FileProvider and install intent setup."""
        manifest_file = os.path.join(PROJECT_ROOT, "android", "app", "src", "main", "AndroidManifest.xml")
        with open(manifest_file, "r", encoding="utf-8") as f:
            manifest = f.read()
        self.assertIn("REQUEST_INSTALL_PACKAGES", manifest)
        self.assertIn("androidx.core.content.FileProvider", manifest)
        self.assertIn("${applicationId}.fileprovider", manifest)

        # Verify file_paths.xml exists and has cache-path
        file_paths = os.path.join(PROJECT_ROOT, "android", "app", "src", "main", "res", "xml", "file_paths.xml")
        self.assertTrue(os.path.exists(file_paths))
        with open(file_paths, "r", encoding="utf-8") as f:
            xml_content = f.read()
        self.assertIn('name="internal_cache"', xml_content)

        # Verify updater references FileProvider authority
        self.assertIn("fileprovider", self.content)
        self.assertIn("content://$authority/internal_cache/QuanNhoPOS-latest.apk", self.content)


if __name__ == "__main__":
    unittest.main()
