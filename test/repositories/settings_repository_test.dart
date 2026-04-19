// test/repositories/settings_repository_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Unit tests cho AppSettingsRepository
// Các case: get/set key-value, default values, override values
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/database/app_database.dart';
import 'package:quannho_pos/core/repositories/module_repository.dart';
import '../helpers/test_database.dart';

void main() {
  late AppSettingsRepository repo;
  late AppDatabase db;

  setUp(() async {
    db   = createTestDatabase();
    repo = AppSettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── GET ─────────────────────────────────────────────────────────────────────
  group('get()', () {
    test('lấy giá trị mặc định shop_name sau seed', () async {
      final name = await repo.get('shop_name');
      expect(name, equals('Quán Nhỏ'));
    });

    test('trả về null cho key không tồn tại', () async {
      final val = await repo.get('key_khong_ton_tai');
      expect(val, isNull);
    });

    test('shopName getter hoạt động đúng', () async {
      final name = await repo.shopName;
      expect(name, equals('Quán Nhỏ'));
    });

    test('loyaltyRate mặc định = 10000', () async {
      final rate = await repo.loyaltyRate;
      expect(rate, equals(10000.0));
    });

    test('receiptEnabled mặc định = false', () async {
      final enabled = await repo.receiptEnabled;
      expect(enabled, isFalse);
    });
  });

  // ── SET ─────────────────────────────────────────────────────────────────────
  group('set()', () {
    test('set rồi get lại đúng giá trị', () async {
      await repo.set('shop_name', 'Quán Mới');
      final name = await repo.get('shop_name');
      expect(name, equals('Quán Mới'));
    });

    test('set key mới (chưa tồn tại) — insert thành công', () async {
      await repo.set('pin_enabled', 'true');
      final val = await repo.get('pin_enabled');
      expect(val, equals('true'));
    });

    test('set key đã tồn tại — upsert đúng', () async {
      await repo.set('pin_enabled', 'true');
      await repo.set('pin_enabled', 'false');  // ghi đè
      final val = await repo.get('pin_enabled');
      expect(val, equals('false'));
    });

    test('set PIN và verify flow', () async {
      await repo.set('app_pin', '1234');
      await repo.set('pin_enabled', 'true');

      final pin     = await repo.get('app_pin');
      final enabled = await repo.get('pin_enabled');

      expect(pin, equals('1234'));
      expect(enabled, equals('true'));
    });
  });

  // ── LOYALTY RATE ─────────────────────────────────────────────────────────────
  group('loyaltyRate getter', () {
    test('parse đúng từ string', () async {
      await repo.set('loyalty_rate', '5000');
      final rate = await repo.loyaltyRate;
      expect(rate, equals(5000.0));
    });

    test('trả về default 10000 nếu giá trị không phải số', () async {
      await repo.set('loyalty_rate', 'invalid');
      final rate = await repo.loyaltyRate;
      // getDouble dùng defaultValue = 10000 khi parse thất bại
      expect(rate, equals(10000.0));
    });
  });
}
