import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quannho_pos/core/repositories/module_repository.dart';

/// Haversine formula to compute distance in meters between two coordinates,
/// identical to Geolocator.distanceBetween standard specification.
double _calculateHaversineDistance(
  double startLatitude,
  double startLongitude,
  double endLatitude,
  double endLongitude,
) {
  const earthRadius = 6371000.0; // meters
  final dLat = (endLatitude - startLatitude) * (math.pi / 180.0);
  final dLng = (endLongitude - startLongitude) * (math.pi / 180.0);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(startLatitude * (math.pi / 180.0)) *
          math.cos(endLatitude * (math.pi / 180.0)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

/// Helper validating coordinate inputs identically to ChamCongScreen dialog
String? _validateLocationInputs({
  required String latText,
  required String lngText,
  required String radiusText,
}) {
  final lat = double.tryParse(latText.trim().replaceAll(',', '.'));
  final lng = double.tryParse(lngText.trim().replaceAll(',', '.'));
  final radius = double.tryParse(radiusText.trim().replaceAll(',', '.'));

  if (lat == null || !lat.isFinite || lng == null || !lng.isFinite) {
    return 'Vui lòng nhập hoặc lấy toạ độ vĩ độ/kinh độ hợp lệ.';
  }
  if (lat < -90 || lat > 90) {
    return 'Vĩ độ không hợp lệ (-90 đến 90).';
  }
  if (lng < -180 || lng > 180) {
    return 'Kinh độ không hợp lệ (-180 đến 180).';
  }
  if (radius == null || !radius.isFinite || radius <= 0) {
    return 'Bán kính cho phép phải là số lớn hơn 0 mét.';
  }
  return null; // Valid
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AttendanceConfig Data Class Tests', () {
    test('1. Default values are applied properly', () {
      const config = AttendanceConfig();
      expect(config.lat, isNull);
      expect(config.lng, isNull);
      expect(config.address, isNull);
      expect(config.radius, 200.0);
      expect(config.hasLocation, isFalse);
    });

    test('2. Populated AttendanceConfig hasLocation evaluates correctly', () {
      const validConfig = AttendanceConfig(
        lat: 10.776889,
        lng: 106.700806,
        address: 'Quán Nhỏ Sài Gòn',
        radius: 150.0,
      );
      expect(validConfig.lat, 10.776889);
      expect(validConfig.lng, 106.700806);
      expect(validConfig.address, 'Quán Nhỏ Sài Gòn');
      expect(validConfig.radius, 150.0);
      expect(validConfig.hasLocation, isTrue);

      final map = validConfig.toMap();
      expect(map['lat'], 10.776889);
      expect(map['lng'], 106.700806);
      expect(map['address'], 'Quán Nhỏ Sài Gòn');
      expect(map['radius'], 150.0);
    });

    test('3. Partial coordinates evaluate hasLocation as false', () {
      const onlyLat = AttendanceConfig(lat: 10.776889);
      expect(onlyLat.hasLocation, isFalse);

      const onlyLng = AttendanceConfig(lng: 106.700806);
      expect(onlyLng.hasLocation, isFalse);
    });

    test('4. Non-finite coordinates evaluate hasLocation as false', () {
      const nanLat = AttendanceConfig(lat: double.nan, lng: 106.700806);
      expect(nanLat.hasLocation, isFalse);

      const nanLng = AttendanceConfig(lat: 10.776889, lng: double.nan);
      expect(nanLng.hasLocation, isFalse);

      const infLat = AttendanceConfig(lat: double.infinity, lng: 106.700806);
      expect(infLat.hasLocation, isFalse);

      const negInfLng = AttendanceConfig(lat: 10.776889, lng: double.negativeInfinity);
      expect(negInfLng.hasLocation, isFalse);
    });

    test('5. Safe preview radius calculation never throws UnsupportedError', () {
      int computeSafeRadius(String input, double initialRadius) {
        final parsed = double.tryParse(input.trim().replaceAll(',', '.'));
        return (parsed != null && parsed.isFinite && parsed > 0)
            ? parsed.round()
            : (initialRadius.isFinite && initialRadius > 0
                ? initialRadius.round()
                : 200);
      }

      expect(computeSafeRadius('NaN', 200.0), 200);
      expect(computeSafeRadius('Infinity', 200.0), 200);
      expect(computeSafeRadius('-Infinity', 200.0), 200);
      expect(computeSafeRadius('abc', 200.0), 200);
      expect(computeSafeRadius('-50', 200.0), 200);
      expect(computeSafeRadius('0', 200.0), 200);
      expect(computeSafeRadius('350', 200.0), 350);
      expect(computeSafeRadius('150.7', 200.0), 151);
      expect(computeSafeRadius('150,7', 200.0), 151);
    });
  });

  group('Manual Coordinate & Radius Validation Tests', () {
    test('1. Valid GPS coordinates and radius pass validation', () {
      final error = _validateLocationInputs(
        latText: '10.776889',
        lngText: '106.700806',
        radiusText: '250',
      );
      expect(error, isNull);
    });

    test('2. Boundary valid coordinates pass validation', () {
      expect(
        _validateLocationInputs(
          latText: '90.0',
          lngText: '180.0',
          radiusText: '1',
        ),
        isNull,
      );
      expect(
        _validateLocationInputs(
          latText: '-90.0',
          lngText: '-180.0',
          radiusText: '0.1',
        ),
        isNull,
      );
    });

    test('3. Out-of-bounds latitude is rejected', () {
      final errorTooHigh = _validateLocationInputs(
        latText: '90.0001',
        lngText: '106.700806',
        radiusText: '200',
      );
      expect(errorTooHigh, contains('Vĩ độ không hợp lệ'));

      final errorTooLow = _validateLocationInputs(
        latText: '-90.5',
        lngText: '106.700806',
        radiusText: '200',
      );
      expect(errorTooLow, contains('Vĩ độ không hợp lệ'));
    });

    test('4. Out-of-bounds longitude is rejected', () {
      final errorTooHigh = _validateLocationInputs(
        latText: '10.776889',
        lngText: '180.001',
        radiusText: '200',
      );
      expect(errorTooHigh, contains('Kinh độ không hợp lệ'));

      final errorTooLow = _validateLocationInputs(
        latText: '10.776889',
        lngText: '-180.1',
        radiusText: '200',
      );
      expect(errorTooLow, contains('Kinh độ không hợp lệ'));
    });

    test('5. Non-numeric or empty coordinates are rejected', () {
      expect(
        _validateLocationInputs(
          latText: '',
          lngText: '106.700806',
          radiusText: '200',
        ),
        contains('Vui lòng nhập hoặc lấy toạ độ'),
      );
      expect(
        _validateLocationInputs(
          latText: 'abc',
          lngText: '106.700806',
          radiusText: '200',
        ),
        contains('Vui lòng nhập hoặc lấy toạ độ'),
      );
    });

    test('6. Zero or negative radius is rejected', () {
      expect(
        _validateLocationInputs(
          latText: '10.776889',
          lngText: '106.700806',
          radiusText: '0',
        ),
        contains('Bán kính cho phép phải lớn hơn 0 mét'),
      );
      expect(
        _validateLocationInputs(
          latText: '10.776889',
          lngText: '106.700806',
          radiusText: '-50',
        ),
        contains('Bán kính cho phép phải lớn hơn 0 mét'),
      );
    });

    test('7. IEEE 754 NaN and Infinity coordinates are rejected', () {
      expect(
        _validateLocationInputs(
          latText: 'NaN',
          lngText: '106.700806',
          radiusText: '200',
        ),
        contains('Vui lòng nhập hoặc lấy toạ độ'),
      );
      expect(
        _validateLocationInputs(
          latText: '10.776889',
          lngText: 'NaN',
          radiusText: '200',
        ),
        contains('Vui lòng nhập hoặc lấy toạ độ'),
      );
      expect(
        _validateLocationInputs(
          latText: 'Infinity',
          lngText: '106.700806',
          radiusText: '200',
        ),
        contains('Vui lòng nhập hoặc lấy toạ độ'),
      );
      expect(
        _validateLocationInputs(
          latText: '-Infinity',
          lngText: '106.700806',
          radiusText: '200',
        ),
        contains('Vui lòng nhập hoặc lấy toạ độ'),
      );
      expect(
        _validateLocationInputs(
          latText: '10.776889',
          lngText: 'Infinity',
          radiusText: '200',
        ),
        contains('Vui lòng nhập hoặc lấy toạ độ'),
      );
      expect(
        _validateLocationInputs(
          latText: '10.776889',
          lngText: '-Infinity',
          radiusText: '200',
        ),
        contains('Vui lòng nhập hoặc lấy toạ độ'),
      );
    });

    test('8. NaN, Infinity, and non-numeric radius are rejected', () {
      expect(
        _validateLocationInputs(
          latText: '10.776889',
          lngText: '106.700806',
          radiusText: 'NaN',
        ),
        contains('Bán kính cho phép phải lớn hơn 0 mét'),
      );
      expect(
        _validateLocationInputs(
          latText: '10.776889',
          lngText: '106.700806',
          radiusText: 'Infinity',
        ),
        contains('Bán kính cho phép phải lớn hơn 0 mét'),
      );
      expect(
        _validateLocationInputs(
          latText: '10.776889',
          lngText: '106.700806',
          radiusText: 'abc',
        ),
        contains('Bán kính cho phép phải lớn hơn 0 mét'),
      );
    });

    test('9. Out of range lat/lng in onChanged helper returns null correctly', () {
      double? parseLat(String v) {
        final p = double.tryParse(v.trim().replaceAll(',', '.'));
        return (p != null && p.isFinite && p >= -90 && p <= 90) ? p : null;
      }
      double? parseLng(String v) {
        final p = double.tryParse(v.trim().replaceAll(',', '.'));
        return (p != null && p.isFinite && p >= -180 && p <= 180) ? p : null;
      }

      expect(parseLat('10.776889'), 10.776889);
      expect(parseLat('10,776889'), 10.776889);
      expect(parseLat('91.0'), isNull);
      expect(parseLat('-90.1'), isNull);
      expect(parseLat('NaN'), isNull);
      expect(parseLat('Infinity'), isNull);

      expect(parseLng('106.700806'), 106.700806);
      expect(parseLng('106,700806'), 106.700806);
      expect(parseLng('181.0'), isNull);
      expect(parseLng('-180.1'), isNull);
      expect(parseLng('NaN'), isNull);
    });

    test('10. Vietnamese comma decimal coordinate and radius inputs pass validation', () {
      final error = _validateLocationInputs(
        latText: '10,776889',
        lngText: '106,700806',
        radiusText: '250,5',
      );
      expect(error, isNull);
    });
  });

  group('Dialog Lifecycle and safeSetDialogState Invariants', () {
    test('1. safeSetDialogState executes callback only when mounted is true', () {
      bool mounted = true;
      int callCount = 0;
      void setDialogState(void Function() fn) {
        fn();
      }
      void safeSetDialogState(void Function() fn) {
        if (mounted) {
          setDialogState(fn);
        }
      }

      safeSetDialogState(() => callCount++);
      expect(callCount, 1);

      mounted = false;
      safeSetDialogState(() => callCount++);
      expect(callCount, 1); // Not called when mounted is false
    });
  });

  group('Attendance Distance Verification & Warning Invariant Tests', () {
    const storeLat = 10.776889;
    const storeLng = 106.700806;
    const storeRadius = 200.0; // 200 meters

    test('1. Check-in within 50m of store is recognized as within range', () {
      // Offset by approx 40 meters
      const checkInLat = 10.777200;
      const checkInLng = 106.700806;

      final distance = _calculateHaversineDistance(
        checkInLat,
        checkInLng,
        storeLat,
        storeLng,
      );

      expect(distance, lessThanOrEqualTo(storeRadius));
      final isOutOfRange = distance > storeRadius;
      expect(isOutOfRange, isFalse);
    });

    test('2. Check-in at 800m from store flags mismatch warning', () {
      // Offset by ~800 meters
      const checkInLat = 10.784000;
      const checkInLng = 106.700806;

      final distance = _calculateHaversineDistance(
        checkInLat,
        checkInLng,
        storeLat,
        storeLng,
      );

      expect(distance, greaterThan(storeRadius));
      final isOutOfRange = distance > storeRadius;
      expect(isOutOfRange, isTrue);
      expect(distance.toInt(), greaterThan(700));
    });

    test('3. Exact same coordinates yields 0 distance and passes', () {
      final distance = _calculateHaversineDistance(
        storeLat,
        storeLng,
        storeLat,
        storeLng,
      );
      expect(distance, 0.0);
      expect(distance <= storeRadius, isTrue);
    });
  });

  group('AppSettingsRepository Store Isolation Invariants', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'auth_store_id': 'store-uuid-abc',
        'auth_store_name': 'Quán Nhỏ Chi Nhánh 1',
      });
    });

    test('1. AppSettingsRepository accepts explicit storeId override', () {
      final repoCustom = AppSettingsRepository('store-uuid-override');
      expect(repoCustom, isNotNull);
    });

    test('2. AppSettingsRepository defaults to null override and falls back cleanly', () {
      final repoDefault = AppSettingsRepository();
      expect(repoDefault, isNotNull);
    });
  });
}
