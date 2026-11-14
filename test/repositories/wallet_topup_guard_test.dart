import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/loyalty/repository/loyalty_repository.dart';

TopupPackageModel _pkg(
  String name,
  double min,
  double pct, {
  bool active = true,
}) => TopupPackageModel.fromMap({
  'id': name,
  'store_id': 's',
  'name': name,
  'min_amount': min,
  'bonus_pct': pct,
  'is_active': active,
  'sort_order': 0,
});

void main() {
  // Nạp ví phải đi qua RPC topup_customer_wallet_v1 (khoá dòng, chống trùng, bonus ở máy chủ).
  test(
    'topUpWallet không còn tự ghi số dư / lịch sử ví / thu chi ở client',
    () {
      final src = File(
        'lib/modules/loyalty/repository/loyalty_repository.dart',
      ).readAsStringSync();
      final start = src.indexOf('Future<WalletTopUpResult> topUpWallet(');
      expect(start, greaterThan(0));
      final body = src.substring(
        start,
        src.indexOf('Map<String, double> computeWalletUsage', start),
      );
      expect(body, contains("rpc('topup_customer_wallet_v1'"));
      for (final forbidden in const [
        "from('customers')",
        "from('balance_transactions')",
        "from('finance_records')",
        'double bonusAmount', // client không được tự quyết bonus
      ]) {
        expect(
          body,
          isNot(contains(forbidden)),
          reason: 'topUpWallet không được dùng $forbidden',
        );
      }
    },
  );

  group('findApplicablePackage khớp thứ tự máy chủ', () {
    final repo = LoyaltyRepository();
    final pkgs = [
      _pkg('Bac', 200000, 10),
      _pkg('Vang', 500000, 15),
      _pkg('Vang+', 500000, 18),
      _pkg('Tat', 300000, 50, active: false),
    ];
    test('chọn min_amount cao nhất ≤ số tiền, bằng nhau thì bonus cao hơn', () {
      expect(repo.findApplicablePackage(pkgs, 600000)?.name, 'Vang+');
    });
    test('bỏ qua gói đang tắt', () {
      expect(repo.findApplicablePackage(pkgs, 300000)?.name, 'Bac');
    });
    test('dưới mọi gói → null', () {
      expect(repo.findApplicablePackage(pkgs, 50000), isNull);
    });
  });
}
