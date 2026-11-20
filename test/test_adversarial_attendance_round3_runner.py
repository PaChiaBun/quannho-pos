#!/usr/bin/env python3
"""
Adversarial Verification Suite Round 3: Store Attendance Location & GPS Configuration
Author: teamwork_preview_reviewer (Round 3)
"""

import math
import re
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# ─────────────────────────────────────────────────────────────────────────────
# 1. AST BRACKET & DELIMITER BALANCER
# ─────────────────────────────────────────────────────────────────────────────

def verify_bracket_balance(filepath: Path) -> tuple[bool, str]:
    """Verify that (), {}, [] tokens are strictly balanced in the Dart file."""
    content = filepath.read_text(encoding='utf-8')
    stack = []
    pairs = {')': '(', '}': '{', ']': '['}
    in_string = False
    string_char = ''
    in_line_comment = False
    in_block_comment = False
    escape = False

    i = 0
    line_no = 1
    col_no = 0

    while i < len(content):
        c = content[i]
        col_no += 1
        if c == '\n':
            line_no += 1
            col_no = 0
            in_line_comment = False

        if escape:
            escape = False
            i += 1
            continue

        if c == '\\' and in_string:
            escape = True
            i += 1
            continue

        if not in_string and not in_block_comment:
            if content[i:i+2] == '//':
                in_line_comment = True
                i += 2
                continue
            if content[i:i+2] == '/*':
                in_block_comment = True
                i += 2
                continue

        if in_block_comment:
            if content[i:i+2] == '*/':
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue

        if in_line_comment:
            i += 1
            continue

        if c in ("'", '"'):
            if not in_string:
                in_string = True
                string_char = c
            elif string_char == c:
                in_string = False
            i += 1
            continue

        if in_string:
            i += 1
            continue

        if c in '({[':
            stack.append((c, line_no, col_no))
        elif c in ')}]':
            if not stack:
                return False, f"Unexpected closing '{c}' at line {line_no}:{col_no}"
            top, top_line, top_col = stack.pop()
            if top != pairs[c]:
                return False, f"Mismatched '{c}' at line {line_no}:{col_no} matching '{top}' from line {top_line}:{top_col}"

        i += 1

    if stack:
        top, top_line, top_col = stack[-1]
        return False, f"Unclosed '{top}' from line {top_line}:{top_col}"
    return True, "Balanced"


# ─────────────────────────────────────────────────────────────────────────────
# 2. DART LOGIC SIMULATORS
# ─────────────────────────────────────────────────────────────────────────────

class AttendanceConfigSimulator:
    def __init__(self, lat=None, lng=None, address=None, radius=200.0):
        self.lat = lat
        self.lng = lng
        self.address = address
        self.radius = radius

    @property
    def has_location(self) -> bool:
        if self.lat is None or self.lng is None:
            return False
        if math.isnan(self.lat) or math.isinf(self.lat):
            return False
        if math.isnan(self.lng) or math.isinf(self.lng):
            return False
        return True


def simulate_validate_location_inputs(lat_text: str, lng_text: str, radius_text: str) -> str or None:
    try:
        lat = float(lat_text.strip().replace(',', '.'))
        lng = float(lng_text.strip().replace(',', '.'))
    except ValueError:
        return 'Vui lòng nhập hoặc lấy toạ độ vĩ độ/kinh độ hợp lệ.'

    if math.isnan(lat) or math.isinf(lat) or math.isnan(lng) or math.isinf(lng):
        return 'Vui lòng nhập hoặc lấy toạ độ vĩ độ/kinh độ hợp lệ.'

    if lat < -90 or lat > 90:
        return 'Vĩ độ không hợp lệ (-90 đến 90).'

    if lng < -180 or lng > 180:
        return 'Kinh độ không hợp lệ (-180 đến 180).'

    try:
        radius = float(radius_text.strip().replace(',', '.'))
    except ValueError:
        return 'Bán kính cho phép phải là số lớn hơn 0 mét.'

    if math.isnan(radius) or math.isinf(radius) or radius <= 0:
        return 'Bán kính cho phép phải là số lớn hơn 0 mét.'

    return None


def simulate_safe_preview_radius(radius_input: str, initial_radius: float) -> int:
    try:
        parsed = float(radius_input.strip().replace(',', '.'))
        if not math.isnan(parsed) and not math.isinf(parsed) and parsed > 0:
            return round(parsed)
    except (ValueError, TypeError):
        pass

    if not math.isnan(initial_radius) and not math.isinf(initial_radius) and initial_radius > 0:
        return round(initial_radius)
    return 200


def calculate_haversine_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Standard Haversine formula implemented identical to Geolocator.distanceBetween."""
    earth_radius = 6371000.0  # meters
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (math.sin(d_lat / 2.0) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(d_lng / 2.0) ** 2)
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return earth_radius * c


# ─────────────────────────────────────────────────────────────────────────────
# 3. UNITTEST TEST CASES
# ─────────────────────────────────────────────────────────────────────────────

class TestAttendanceAdversarialRound3(unittest.TestCase):

    def test_01_syntax_bracket_balance_across_all_modified_files(self):
        modified_files = [
            REPO_ROOT / 'lib/core/repositories/module_repository.dart',
            REPO_ROOT / 'lib/screens/chamcong_screen.dart',
            REPO_ROOT / 'lib/screens/report_screen.dart',
            REPO_ROOT / 'test/core/attendance_location_config_test.dart',
            REPO_ROOT / 'test/repositories/settings_repository_test.dart',
        ]
        for f in modified_files:
            self.assertTrue(f.exists(), f"File does not exist: {f}")
            balanced, msg = verify_bracket_balance(f)
            self.assertTrue(balanced, f"Syntax error in {f.name}: {msg}")

    def test_02_web_geocoding_isolation(self):
        """Confirm placemarkFromCoordinates is only called inside !kIsWeb blocks."""
        chamcong_path = REPO_ROOT / 'lib/screens/chamcong_screen.dart'
        content = chamcong_path.read_text(encoding='utf-8')
        matches = [m.start() for m in re.finditer(r'placemarkFromCoordinates', content)]
        self.assertGreater(len(matches), 0, "Expected placemarkFromCoordinates calls")
        for idx in matches:
            preceding = content[max(0, idx - 250):idx]
            self.assertIn('!kIsWeb', preceding,
                          f"placemarkFromCoordinates at pos {idx} is NOT guarded by !kIsWeb")

    def test_03_no_deprecated_with_opacity_in_attendance_code(self):
        """Ensure withOpacity is not present in attendance location badges or dialogs."""
        chamcong_path = REPO_ROOT / 'lib/screens/chamcong_screen.dart'
        content = chamcong_path.read_text(encoding='utf-8')
        self.assertNotIn('_kNavy.withOpacity', content)

    def test_04_attendance_config_has_location_invariants(self):
        cfg1 = AttendanceConfigSimulator(lat=10.776889, lng=106.700806)
        self.assertTrue(cfg1.has_location)

        self.assertFalse(AttendanceConfigSimulator(lat=None, lng=106.700806).has_location)
        self.assertFalse(AttendanceConfigSimulator(lat=10.776889, lng=None).has_location)
        self.assertFalse(AttendanceConfigSimulator().has_location)

        self.assertFalse(AttendanceConfigSimulator(lat=float('nan'), lng=106.700806).has_location)
        self.assertFalse(AttendanceConfigSimulator(lat=10.776889, lng=float('nan')).has_location)
        self.assertFalse(AttendanceConfigSimulator(lat=float('inf'), lng=106.700806).has_location)
        self.assertFalse(AttendanceConfigSimulator(lat=10.776889, lng=float('-inf')).has_location)

    def test_05_manual_input_validation_boundary_and_comma_matrix(self):
        # Valid cases with dots
        self.assertIsNone(simulate_validate_location_inputs('10.776889', '106.700806', '200'))
        self.assertIsNone(simulate_validate_location_inputs('-90.0', '-180.0', '1'))
        self.assertIsNone(simulate_validate_location_inputs('90.0', '180.0', '500.5'))

        # Valid cases with Vietnamese decimal comma
        self.assertIsNone(simulate_validate_location_inputs('10,776889', '106,700806', '200'))
        self.assertIsNone(simulate_validate_location_inputs('10,776889', '106,700806', '250,5'))
        self.assertIsNone(simulate_validate_location_inputs('-90,0', '-180,0', '1,5'))

        # IEEE 754 non-finite strings
        self.assertIn('Vui lòng nhập', simulate_validate_location_inputs('NaN', '106.700806', '200'))
        self.assertIn('Vui lòng nhập', simulate_validate_location_inputs('Infinity', '106.700806', '200'))
        self.assertIn('Vui lòng nhập', simulate_validate_location_inputs('-Infinity', '106.700806', '200'))
        self.assertIn('Vui lòng nhập', simulate_validate_location_inputs('10.776889', 'NaN', '200'))
        self.assertIn('Bán kính cho phép', simulate_validate_location_inputs('10.776889', '106.700806', 'NaN'))
        self.assertIn('Bán kính cho phép', simulate_validate_location_inputs('10.776889', '106.700806', 'Infinity'))
        self.assertIn('Bán kính cho phép', simulate_validate_location_inputs('10.776889', '106.700806', 'abc'))

        # Out-of-bounds latitude / longitude
        self.assertIn('Vĩ độ không hợp lệ', simulate_validate_location_inputs('90.0001', '106.7', '200'))
        self.assertIn('Vĩ độ không hợp lệ', simulate_validate_location_inputs('-90.0001', '106.7', '200'))
        self.assertIn('Kinh độ không hợp lệ', simulate_validate_location_inputs('10.7', '180.0001', '200'))
        self.assertIn('Kinh độ không hợp lệ', simulate_validate_location_inputs('10.7', '-180.0001', '200'))

        # Zero and negative radius
        self.assertIn('Bán kính cho phép', simulate_validate_location_inputs('10.7', '106.7', '0'))
        self.assertIn('Bán kính cho phép', simulate_validate_location_inputs('10.7', '106.7', '-100'))

    def test_06_safe_preview_radius_never_crashes_and_handles_commas(self):
        self.assertEqual(simulate_safe_preview_radius('NaN', 200.0), 200)
        self.assertEqual(simulate_safe_preview_radius('Infinity', 200.0), 200)
        self.assertEqual(simulate_safe_preview_radius('-Infinity', 200.0), 200)
        self.assertEqual(simulate_safe_preview_radius('abc', 200.0), 200)
        self.assertEqual(simulate_safe_preview_radius('', 200.0), 200)
        self.assertEqual(simulate_safe_preview_radius('-50', 200.0), 200)
        self.assertEqual(simulate_safe_preview_radius('0', 200.0), 200)
        self.assertEqual(simulate_safe_preview_radius('350', 200.0), 350)
        self.assertEqual(simulate_safe_preview_radius('150.7', 200.0), 151)
        self.assertEqual(simulate_safe_preview_radius('150,7', 200.0), 151)

    def test_07_haversine_distance_and_out_of_range_alert(self):
        store_lat = 10.776889
        store_lng = 106.700806
        radius = 200.0

        d0 = calculate_haversine_distance(store_lat, store_lng, store_lat, store_lng)
        self.assertEqual(d0, 0.0)
        self.assertFalse(d0 > radius)

        d40 = calculate_haversine_distance(10.777200, 106.700806, store_lat, store_lng)
        self.assertLess(d40, radius)
        self.assertFalse(d40 > radius)

        d800 = calculate_haversine_distance(10.784000, 106.700806, store_lat, store_lng)
        self.assertGreater(d800, radius)
        self.assertTrue(d800 > radius)
        self.assertGreater(round(d800), 700)

    def test_08_try_finally_controller_disposal_in_dialog(self):
        chamcong_path = REPO_ROOT / 'lib/screens/chamcong_screen.dart'
        content = chamcong_path.read_text(encoding='utf-8')
        self.assertIn('finally {', content)
        self.assertIn('latCtrl.dispose();', content)
        self.assertIn('lngCtrl.dispose();', content)
        self.assertIn('radiusCtrl.dispose();', content)
        self.assertIn('addrCtrl.dispose();', content)

    def test_09_save_attendance_config_upsert_contract(self):
        mod_repo = REPO_ROOT / 'lib/core/repositories/module_repository.dart'
        content = mod_repo.read_text(encoding='utf-8')
        self.assertIn("onConflict: 'store_id,key'", content)
        self.assertIn("key': 'attendance_latitude'", content)
        self.assertIn("key': 'attendance_longitude'", content)
        self.assertIn("key': 'attendance_address'", content)
        self.assertIn("key': 'attendance_radius'", content)

    def test_10_safe_set_dialog_state_guard_in_dialog(self):
        """Confirm safeSetDialogState is declared and guards against setState called after dispose."""
        chamcong_path = REPO_ROOT / 'lib/screens/chamcong_screen.dart'
        content = chamcong_path.read_text(encoding='utf-8')
        self.assertIn('void safeSetDialogState(VoidCallback fn)', content)
        self.assertIn('if (ctx.mounted)', content)
        # Ensure all asynchronous setDialogState calls in _showLocationSettingsDialog use safeSetDialogState
        dialog_snippet = content[content.find('_showLocationSettingsDialog'):content.find('latCtrl.dispose()')]
        raw_set_states = re.findall(r'(?<!safe)setDialogState\s*\(', dialog_snippet)
        # The only raw setDialogState should be the inner call inside safeSetDialogState itself
        self.assertEqual(len(raw_set_states), 1,
                         f"Found unguarded setDialogState calls in dialog: {raw_set_states}")

    def test_11_module_repo_comma_normalization(self):
        """Verify module_repository.dart normalizes commas in getDouble, attendanceLat/Lng, and getAttendanceConfig."""
        mod_repo = REPO_ROOT / 'lib/core/repositories/module_repository.dart'
        content = mod_repo.read_text(encoding='utf-8')
        self.assertIn("val.replaceAll(',', '.')", content)
        self.assertIn("v.replaceAll(',', '.')", content)

    def test_12_photo_audit_dialog_uses_cached_provider(self):
        """Verify _showPhotoAuditDialog checks cached _storeLocationProvider before making Supabase call."""
        chamcong_path = REPO_ROOT / 'lib/screens/chamcong_screen.dart'
        content = chamcong_path.read_text(encoding='utf-8')
        self.assertIn('ref.read(_storeLocationProvider).valueOrNull', content)


if __name__ == '__main__':
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TestAttendanceAdversarialRound3)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
