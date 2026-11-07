#!/usr/bin/env python3
"""
Independent Victory Audit Verification Runner
Auditor: teamwork_preview_victory_auditor
Project: Quán Nhỏ POS — Sửa lỗi tính năng "Định vị của quán"
Date: 2026-09-26
"""

import math
import re
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path('/Users/banhbao/Quan Nho/quan_nho')

# ─────────────────────────────────────────────────────────────────────────────
# AST & DELIMITER CHECKER
# ─────────────────────────────────────────────────────────────────────────────
def check_bracket_balance(filepath: Path) -> tuple[bool, str]:
    content = filepath.read_text(encoding='utf-8')
    stack = []
    pairs = {')': '(', '}': '{', ']': '['}
    in_str = False
    str_c = ''
    in_line_cmt = False
    in_block_cmt = False
    esc = False
    line = 1
    col = 0

    i = 0
    n = len(content)
    while i < n:
        c = content[i]
        col += 1
        if c == '\n':
            line += 1
            col = 0
            in_line_cmt = False

        if esc:
            esc = False
            i += 1
            continue

        if c == '\\' and in_str:
            esc = True
            i += 1
            continue

        if not in_str and not in_block_cmt:
            if content[i:i+2] == '//':
                in_line_cmt = True
                i += 2
                continue
            if content[i:i+2] == '/*':
                in_block_cmt = True
                i += 2
                continue

        if in_block_cmt:
            if content[i:i+2] == '*/':
                in_block_cmt = False
                i += 2
                continue
            i += 1
            continue

        if in_line_cmt:
            i += 1
            continue

        if c in ("'", '"'):
            if not in_str:
                in_str = True
                str_c = c
            elif str_c == c:
                in_str = False
            i += 1
            continue

        if in_str:
            i += 1
            continue

        if c in '({[':
            stack.append((c, line, col))
        elif c in ')}]':
            if not stack:
                return False, f"Unexpected '{c}' at {line}:{col}"
            top, tl, tc = stack.pop()
            if top != pairs[c]:
                return False, f"Mismatched '{c}' at {line}:{col}, expected matching for '{top}' from {tl}:{tc}"

        i += 1

    if stack:
        top, tl, tc = stack[-1]
        return False, f"Unclosed '{top}' from {tl}:{tc}"
    return True, "Balanced"


# ─────────────────────────────────────────────────────────────────────────────
# INDEPENDENT AUDIT SUITE
# ─────────────────────────────────────────────────────────────────────────────
class TestVictoryAuditorAttendance(unittest.TestCase):

    def test_phase_b_01_all_modified_files_exist_and_are_ast_balanced(self):
        files = [
            REPO_ROOT / 'lib/core/repositories/module_repository.dart',
            REPO_ROOT / 'lib/screens/chamcong_screen.dart',
            REPO_ROOT / 'lib/screens/report_screen.dart',
            REPO_ROOT / 'test/core/attendance_location_config_test.dart',
            REPO_ROOT / 'test/repositories/settings_repository_test.dart',
        ]
        for f in files:
            self.assertTrue(f.exists(), f"Target file missing: {f}")
            balanced, msg = check_bracket_balance(f)
            self.assertTrue(balanced, f"Syntax/delimiter error in {f.name}: {msg}")

    def test_phase_b_02_web_crash_elimination_and_geocoding_guard(self):
        """AC1: Verify placemarkFromCoordinates is strictly guarded by !kIsWeb."""
        content = (REPO_ROOT / 'lib/screens/chamcong_screen.dart').read_text(encoding='utf-8')
        
        # Check that placemarkFromCoordinates exists and is only used behind !kIsWeb
        matches = [m.start() for m in re.finditer(r'placemarkFromCoordinates', content)]
        self.assertGreater(len(matches), 0, "No placemarkFromCoordinates found in chamcong_screen.dart")
        for pos in matches:
            preceding = content[max(0, pos - 300):pos]
            self.assertIn('!kIsWeb', preceding, f"Unguarded placemarkFromCoordinates call at pos {pos}")

        # Check that coordinates are captured BEFORE geocoding
        dialog_snippet = content[content.find('_showLocationSettingsDialog'):content.find('HIỆU CHỈNH HOẶC NHẬP')]
        lat_extraction = dialog_snippet.find('currentLat = pos.latitude;')
        geo_call = dialog_snippet.find('placemarkFromCoordinates')
        self.assertNotEqual(lat_extraction, -1, "currentLat extraction missing before geocoding")
        self.assertNotEqual(geo_call, -1, "placemarkFromCoordinates missing in dialog")
        self.assertLess(lat_extraction, geo_call, "Coordinates must be extracted BEFORE geocoding")

    def test_phase_b_03_manual_input_modal_and_lifecycle_safety(self):
        """AC2: Modal allows viewing, checking, entering manual lat/lng/radius with controller disposal."""
        content = (REPO_ROOT / 'lib/screens/chamcong_screen.dart').read_text(encoding='utf-8')
        
        # Check text controllers
        self.assertIn('final latCtrl = TextEditingController(', content)
        self.assertIn('final lngCtrl = TextEditingController(', content)
        self.assertIn('final radiusCtrl = TextEditingController(', content)
        self.assertIn('final addrCtrl = TextEditingController(', content)

        # Check disposal in finally block
        self.assertIn('try {', content)
        self.assertIn('await showDialog(', content)
        self.assertIn('} finally {', content)
        self.assertIn('latCtrl.dispose();', content)
        self.assertIn('lngCtrl.dispose();', content)
        self.assertIn('radiusCtrl.dispose();', content)
        self.assertIn('addrCtrl.dispose();', content)

        # Check safeSetDialogState with ctx.mounted guard
        self.assertIn('void safeSetDialogState(VoidCallback fn)', content)
        self.assertIn('if (ctx.mounted)', content)

    def test_phase_b_04_vietnamese_comma_decimal_and_boundary_validation(self):
        """Verify Vietnamese keyboard comma ',' support and bounds checking."""
        content_chamcong = (REPO_ROOT / 'lib/screens/chamcong_screen.dart').read_text(encoding='utf-8')
        content_repo = (REPO_ROOT / 'lib/core/repositories/module_repository.dart').read_text(encoding='utf-8')

        # Check comma replacement in UI
        self.assertIn("latCtrl.text.trim().replaceAll(',', '.')", content_chamcong)
        self.assertIn("lngCtrl.text.trim().replaceAll(',', '.')", content_chamcong)
        self.assertIn("radiusCtrl.text.trim().replaceAll(',', '.')", content_chamcong)

        # Check comma replacement in repository
        self.assertIn("val.replaceAll(',', '.')", content_repo)
        self.assertIn("v.replaceAll(',', '.')", content_repo)

        # Check bounds
        self.assertIn('parsedLat < -90 || parsedLat > 90', content_chamcong)
        self.assertIn('parsedLng < -180 || parsedLng > 180', content_chamcong)
        self.assertIn('parsedRadius <= 0', content_chamcong)

    def test_phase_b_05_centralized_store_id_persistence_contract(self):
        """AC3: Verify configuration is stored centrally in Supabase app_settings by store_id."""
        content_repo = (REPO_ROOT / 'lib/core/repositories/module_repository.dart').read_text(encoding='utf-8')
        content_chamcong = (REPO_ROOT / 'lib/screens/chamcong_screen.dart').read_text(encoding='utf-8')
        content_report = (REPO_ROOT / 'lib/screens/report_screen.dart').read_text(encoding='utf-8')

        # AppSettingsRepository constructor with storeId override
        self.assertIn('AppSettingsRepository([this._storeIdOverride]);', content_repo)
        self.assertIn('onConflict: \'store_id,key\'', content_repo)
        self.assertIn('\'store_id\': storeId', content_repo)

        # UI calls bound to storeId
        self.assertIn('AppSettingsRepository(session?.storeId)', content_chamcong)
        self.assertIn('AppSettingsRepository(session.storeId)', content_chamcong)
        self.assertIn('AppSettingsRepository(storeId)', content_report)

        # Provider invalidation on save
        self.assertIn('ref.invalidate(_storeLocationProvider);', content_chamcong)
        self.assertIn('ref.invalidate(_myShiftsProvider);', content_chamcong)

    def test_phase_b_06_checkin_distance_verification_and_alert(self):
        """AC4: Check-in distance verification alerts when outside allowed radius."""
        content = (REPO_ROOT / 'lib/screens/chamcong_screen.dart').read_text(encoding='utf-8')
        
        # Verify distance comparison in _checkIn()
        self.assertIn('Geolocator.distanceBetween(', content)
        self.assertIn('distance.isFinite && distance > storeRadius', content)
        self.assertIn('Định vị lệch phạm vi', content)
        self.assertIn('cách quán khoảng ${distanceMeters}m', content)
        self.assertIn('vượt quá giới hạn ${storeRadiusMeters}m', content)
        self.assertIn('confirmCC != true', content)

    def test_phase_b_07_no_facade_or_hardcoded_bypass(self):
        """Integrity check: Ensure real parsing and calculations are used without hardcoded test mocks."""
        content_repo = (REPO_ROOT / 'lib/core/repositories/module_repository.dart').read_text(encoding='utf-8')
        content_chamcong = (REPO_ROOT / 'lib/screens/chamcong_screen.dart').read_text(encoding='utf-8')

        # Verify no hardcoded coordinates
        self.assertNotIn('return 10.776889;', content_repo)
        self.assertNotIn('return 106.700806;', content_repo)
        # Verify genuine Supabase query
        self.assertIn(".from('app_settings')", content_repo)
        self.assertIn(".eq('store_id', storeId)", content_repo)

    def test_phase_c_haversine_formula_math_simulation(self):
        """Phase C: Verify mathematical correctness of Haversine distance and radius checks."""
        earth_radius = 6371000.0
        def haversine(lat1, lon1, lat2, lon2):
            dlat = math.radians(lat2 - lat1)
            dlon = math.radians(lon2 - lon1)
            a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
            c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
            return earth_radius * c

        store_lat = 10.776889
        store_lon = 106.700806
        radius = 200.0

        # Exact location
        self.assertEqual(haversine(store_lat, store_lon, store_lat, store_lon), 0.0)

        # Inside store radius (approx 40m north)
        d_in = haversine(store_lat + 0.00036, store_lon, store_lat, store_lon)
        self.assertLess(d_in, radius)
        self.assertEqual(d_in > radius, False)

        # Outside store radius (approx 800m north)
        d_out = haversine(store_lat + 0.0072, store_lon, store_lat, store_lon)
        self.assertGreater(d_out, radius)
        self.assertEqual(d_out > radius, True)
        self.assertGreater(round(d_out), 700)


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TestVictoryAuditorAttendance)
    runner = unittest.TextTestRunner(verbosity=2)
    res = runner.run(suite)
    sys.exit(0 if res.wasSuccessful() else 1)
