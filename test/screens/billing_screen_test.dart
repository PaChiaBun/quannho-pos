import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/billing_repository.dart';
import 'package:quannho_pos/core/utils/billing_platform.dart';
import 'package:quannho_pos/core/utils/vietqr.dart';
import 'package:quannho_pos/screens/billing_screen.dart';

// Cổng thu phí đợt A (28/10): VietQR vẽ tại máy, chặn hiện giá trên iOS / Android, màn Gói & thanh toán.
void main() {
  group('billingAllowedHere — App Store / CH Play không hiện giá', () {
    test('web và máy tính được; iOS / Android không', () {
      expect(billingAllowedHere(isWeb: true, platform: TargetPlatform.iOS), isTrue);
      expect(billingAllowedHere(isWeb: false, platform: TargetPlatform.windows), isTrue);
      expect(billingAllowedHere(isWeb: false, platform: TargetPlatform.macOS), isTrue);
      expect(billingAllowedHere(isWeb: false, platform: TargetPlatform.iOS), isFalse);
      expect(billingAllowedHere(isWeb: false, platform: TargetPlatform.android), isFalse);
      expect(billingAllowedHere(isWeb: false, platform: TargetPlatform.fuchsia), isFalse);
    });
  });

  group('VietQR', () {
    test('CRC-16/CCITT-FALSE đúng chuẩn ("123456789" → 29B1)', () {
      expect(vietQrCrc16('123456789'), '29B1');
    });
    test('chuỗi mã đúng cấu trúc EMVCo / Napas', () {
      final p = buildVietQrPayload(bin: '970436', accountNo: '0123456789', amount: 499000, content: 'QNAB12CD');
      expect(p.startsWith('000201010212'), isTrue);
      expect(p, contains('38540010A00000072701240006970436011001234567890208QRIBFTTA'));
      expect(p, contains('5303704'));
      expect(p, contains('5406499000'));
      expect(p, contains('5802VN'));
      expect(p, contains('62120808QNAB12CD'));
      final body = p.substring(0, p.length - 4);
      expect(body.endsWith('6304'), isTrue);
      expect(p.substring(p.length - 4), vietQrCrc16(body));
    });
    test('thông tin sai → không vẽ mã', () {
      expect(() => buildVietQrPayload(bin: '97043', accountNo: '0123', amount: 1, content: 'QN'), throwsArgumentError);
      expect(() => buildVietQrPayload(bin: '970436', accountNo: '01a3', amount: 1, content: 'QN'), throwsArgumentError);
      expect(() => buildVietQrPayload(bin: '970436', accountNo: '0123456', amount: 0, content: 'QN'), throwsArgumentError);
      expect(() => buildVietQrPayload(bin: '970436', accountNo: '0123456', amount: 1, content: 'Có dấu'), throwsArgumentError);
    });
  });

  group('BillingRepository', () {
    test('lỗi máy chủ → BillingException có câu tiếng Việt', () async {
      final repo = BillingRepository(rpcOverride: (fn, p) async => {'ok': false, 'error': 'BANK_NOT_SET'});
      await expectLater(repo.createOrder('s1', 'pro_1m'),
          throwsA(isA<BillingException>().having((e) => e.message, 'message', contains('chưa mở thanh toán'))));
      final offline = BillingRepository(rpcOverride: (fn, p) async => throw Exception('x'));
      await expectLater(offline.info('s1'), throwsA(isA<BillingException>().having((e) => e.code, 'code', 'NETWORK')));
    });
  });

  group('BillingScreen', () {
    Map<String, dynamic> info({Map<String, dynamic>? pending, bool bank = true, String plan = 'free', String? planEnds}) => {
      'ok': true,
      'store': {'name': 'Quán A', 'plan': plan, 'status': 'trial', 'trial_ends_at': '2026-11-20T00:00:00+00:00',
                'plan_ends_at': planEnds},
      'plans': [
        {'code': 'pro_1m', 'name': 'Pro 1 tháng', 'months': 1, 'price_vnd': 99000},
        {'code': 'pro_12m', 'name': 'Pro 12 tháng', 'months': 12, 'price_vnd': 899000},
      ],
      'bank': bank ? {'bin': '970436', 'bank_name': 'Vietcombank', 'account_no': '0123456789', 'account_name': 'CONG TY QN'} : null,
      'pending': pending,
      'history': [],
    };
    Map<String, dynamic> order(String status) => {
      'id': 'o1', 'code': 'QNAB12CD', 'plan_name': 'Pro 12 tháng', 'months': 12, 'amount_vnd': 899000,
      'status': status, 'expires_at': '2026-10-29T10:00:00+00:00',
    };

    testWidgets('chọn gói → hiện mã QR + nội dung; tiền vào → báo đã nhận', (tester) async {
      var paid = false;
      final calls = <String>[];
      final repo = BillingRepository(rpcOverride: (fn, p) async {
        calls.add(fn);
        switch (fn) {
          case 'billing_info_v1':
            return paid ? info(plan: 'pro', planEnds: '2027-10-28T00:00:00+00:00') : info();
          case 'billing_create_order_v1':
            expect(p, {'p_store': 's1', 'p_plan': 'pro_12m'});
            return {'ok': true, 'order': order('pending')};
          case 'billing_order_status_v1':
            return {'ok': true, 'order': order(paid ? 'paid' : 'pending')};
        }
        return null;
      });
      await tester.pumpWidget(MaterialApp(home: BillingScreen(
        storeId: 's1', repository: repo, pollEvery: const Duration(milliseconds: 200), allowedOverride: true)));
      await tester.pumpAndSettle();
      expect(find.text('899.000 đ'), findsOneWidget);
      await tester.tap(find.byKey(const Key('billing_choose_pro_12m')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('billing_qr')), findsOneWidget);
      expect(find.byKey(const Key('billing_order_code')), findsOneWidget);
      expect(find.text('QNAB12CD'), findsOneWidget);
      paid = true;
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('billing_paid_banner')), findsOneWidget);
      expect(find.byKey(const Key('billing_qr')), findsNothing);
      expect(find.text('Gói Pro'), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // đóng màn → dừng hỏi trạng thái
      final n = calls.length;
      await tester.pump(const Duration(seconds: 1));
      expect(calls.length, n);
    });

    testWidgets('chưa có tài khoản nhận tiền → báo chưa mở, không có nút chọn', (tester) async {
      final repo = BillingRepository(rpcOverride: (fn, p) async => info(bank: false));
      await tester.pumpWidget(MaterialApp(home: BillingScreen(storeId: 's1', repository: repo, allowedOverride: true)));
      await tester.pumpAndSettle();
      expect(find.textContaining('chưa mở thanh toán'), findsOneWidget);
      expect(find.byKey(const Key('billing_choose_pro_1m')), findsNothing);
    });

    testWidgets('mở lại màn khi có đơn đang chờ → hiện luôn mã QR', (tester) async {
      final repo = BillingRepository(rpcOverride: (fn, p) async =>
          fn == 'billing_info_v1' ? info(pending: order('pending')) : {'ok': true, 'order': order('pending')});
      await tester.pumpWidget(MaterialApp(home: BillingScreen(
        storeId: 's1', repository: repo, pollEvery: const Duration(hours: 1), allowedOverride: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('billing_qr')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('"Chọn gói khác" hỏi đã chuyển khoản chưa: đã chuyển → giữ mã; chưa → về bảng giá', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = BillingRepository(rpcOverride: (fn, p) async =>
          fn == 'billing_info_v1' ? info(pending: order('pending')) : {'ok': true, 'order': order('pending')});
      await tester.pumpWidget(MaterialApp(home: BillingScreen(
        storeId: 's1', repository: repo, pollEvery: const Duration(hours: 1), allowedOverride: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('billing_choose_other')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('billing_already_paid')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('billing_qr')), findsOneWidget);
      await tester.tap(find.byKey(const Key('billing_choose_other')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('billing_not_paid')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('billing_qr')), findsNothing);
      expect(find.byKey(const Key('billing_choose_pro_1m')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('iOS / Android → không hiện giá, không gọi máy chủ', (tester) async {
      var called = false;
      final repo = BillingRepository(rpcOverride: (fn, p) async {
        called = true;
        return info();
      });
      await tester.pumpWidget(MaterialApp(home: BillingScreen(storeId: 's1', repository: repo, allowedOverride: false)));
      await tester.pumpAndSettle();
      expect(called, isFalse);
      expect(find.textContaining('đ'), findsNothing);
    });
  });
}
