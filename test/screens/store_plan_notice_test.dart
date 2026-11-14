import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/store_plan_repository.dart';
import 'package:quannho_pos/screens/store_plan_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Đợt 1 trang quản trị (27/10): dải nhắc hết dùng thử + màn "Quán đang tạm khoá".
StorePlanStatus _st({String? notice, bool owner = true, bool locked = false, String? contact, bool self = false}) => StorePlanStatus(
  plan: notice != null && notice.startsWith('pro') ? 'pro' : 'free',
  status: locked ? 'locked' : 'trial',
  locked: locked,
  isOwner: owner,
  trialEndsAt: DateTime(2026, 10, 20),
  planEndsAt: DateTime(2026, 10, 30),
  notice: notice,
  contact: contact,
  canSelfExtend: self,
);

final _now = DateTime(2026, 10, 27, 9);

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  group('storePlanNoticeText', () {
    test('iOS / Android: chỉ báo ngày hết hạn, KHÔNG nhắc mua / liên hệ mua (kể cả câu liên hệ quản trị đặt)', () {
      final t = storePlanNoticeText(_st(notice: 'trial_expired', contact: 'Zalo 0900 để mua'), _now)!;
      expect(t.title, 'Quán đã hết thời gian dùng thử');
      expect(t.body, 'Hết hạn từ 20/10/2026.');
      expect(storePlanNoticeText(_st(notice: 'trial_ending'), _now)!.body, 'Hết hạn ngày 20/10/2026.');
      expect(storePlanNoticeText(_st(notice: 'pro_ending'), _now)!.body, 'Hết hạn ngày 30/10/2026.');
      for (final n in ['trial_expired', 'trial_ending', 'pro_expired', 'pro_ending']) {
        final body = storePlanNoticeText(_st(notice: n, contact: 'Zalo'), _now)!.body;
        expect(body.contains('Mua') || body.contains('Zalo') || body.contains('thanh toán') || body.contains('Liên hệ'), isFalse,
            reason: n);
      }
    });
    test('web / máy tính: nhắc bấm "Mua gói Pro"', () {
      final t = storePlanNoticeText(_st(notice: 'pro_expired'), _now, billingAllowed: true)!;
      expect(t.body, 'Hết hạn từ 30/10/2026. $kStorePlanPayHint');
    });
    test('Pro sắp hết: đếm ngày còn lại', () {
      expect(storePlanNoticeText(_st(notice: 'pro_ending'), _now)!.title, 'Gói Pro còn 3 ngày');
    });
    test('tự gia hạn được → bảo bấm nút, không bảo liên hệ', () {
      final t = storePlanNoticeText(_st(notice: 'trial_expired', contact: 'Zalo 0900', self: true), _now)!;
      expect(t.body, 'Hết hạn từ 20/10/2026. $kStorePlanSelfExtendHint');
    });
    test('không có thông báo → không nhắc', () {
      expect(storePlanNoticeText(_st(), _now), isNull);
    });
  });

  group('StorePlanRepository', () {
    test('đọc đúng kết quả máy chủ', () async {
      final r = await StorePlanRepository(rpcOverride: (fn, p) async {
        expect(fn, 'store_plan_status_v1');
        expect(p, {'p_store': 's1'});
        return {'ok': true, 'plan': 'free', 'status': 'locked', 'locked': true, 'is_owner': true,
                'trial_ends_at': '2026-10-20T00:00:00+00:00', 'notice': null, 'contact': '  '};
      }).fetch('s1');
      expect(r!.locked, isTrue);
      expect(r.contact, isNull);
      expect(r.trialEndsAt, isNotNull);
    });
    test('máy chủ từ chối / lỗi mạng → null (không tự khoá vì lỗi)', () async {
      expect(await StorePlanRepository(rpcOverride: (fn, p) async => {'ok': false, 'error': 'FORBIDDEN'}).fetch('s1'), isNull);
      expect(await StorePlanRepository(rpcOverride: (fn, p) async => throw Exception('offline')).fetch('s1'), isNull);
      expect(await StorePlanRepository(rpcOverride: (fn, p) async => null).fetch('s1'), isNull);
    });
  });

  group('StorePlanRepository.selfExtend', () {
    test('thành công → null; máy chủ từ chối → mã lỗi; lỗi mạng → NETWORK', () async {
      expect(await StorePlanRepository(rpcOverride: (fn, p) async {
        expect(fn, 'store_self_extend_trial_v1');
        expect(p, {'p_store': 's1'});
        return {'ok': true, 'trial_ends_at': '2026-11-26T00:00:00+00:00'};
      }).selfExtend('s1'), isNull);
      expect(await StorePlanRepository(rpcOverride: (fn, p) async => {'ok': false, 'error': 'NOT_DUE'}).selfExtend('s1'), 'NOT_DUE');
      expect(await StorePlanRepository(rpcOverride: (fn, p) async => throw Exception('offline')).selfExtend('s1'), 'NETWORK');
    });
    test('đọc cờ can_self_extend', () {
      expect(StorePlanStatus.fromMap({'ok': true, 'can_self_extend': true}).canSelfExtend, isTrue);
      expect(StorePlanStatus.fromMap({'ok': true}).canSelfExtend, isFalse);
    });
  });

  group('Nút Gia hạn thêm 30 ngày', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('chủ quán bấm → gọi gia hạn đúng 1 lần, báo xong', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_wrap(StorePlanBanner(
        storeId: 's1',
        status: _st(notice: 'trial_expired', self: true),
        now: () => _now,
        onSelfExtend: () async { calls++; return null; },
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('store_plan_self_extend')));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Đã gia hạn thêm 30 ngày dùng thử.'), findsOneWidget);
      expect(find.byKey(const Key('store_plan_self_extend')), findsNothing);
    });

    testWidgets('lỗi → báo thử lại, nút bấm lại được', (tester) async {
      await tester.pumpWidget(_wrap(StorePlanBanner(
        storeId: 's1',
        status: _st(notice: 'trial_ending', self: true),
        now: () => _now,
        onSelfExtend: () async => 'NETWORK',
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('store_plan_self_extend')));
      await tester.pumpAndSettle();
      expect(find.text('Chưa gia hạn được, vui lòng thử lại.'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('store_plan_self_extend'))).onPressed, isNotNull);
    });

    testWidgets('máy chủ chưa cho tự gia hạn (vd gói Pro) → không có nút', (tester) async {
      await tester.pumpWidget(_wrap(StorePlanBanner(
        storeId: 's1',
        status: _st(notice: 'pro_expired'),
        now: () => _now,
        onSelfExtend: () async => null,
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store_plan_banner')), findsOneWidget);
      expect(find.byKey(const Key('store_plan_self_extend')), findsNothing);
    });
  });

  group('Nút Mua gói Pro', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('iOS / Android: không có nút Mua gói Pro dù có lối mở', (tester) async {
      await tester.pumpWidget(_wrap(StorePlanBanner(
        storeId: 's1', status: _st(notice: 'pro_expired'), now: () => _now,
        onOpenBilling: () {}, billingAllowed: false)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store_plan_banner')), findsOneWidget);
      expect(find.byKey(const Key('store_plan_open_billing')), findsNothing);
      expect(find.textContaining('Mua'), findsNothing);
    });

    testWidgets('web / máy tính: có nút, bấm mở màn thanh toán', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_wrap(StorePlanBanner(
        storeId: 's1', status: _st(notice: 'pro_expired'), now: () => _now,
        onOpenBilling: () => opened++, billingAllowed: true)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('store_plan_open_billing')));
      expect(opened, 1);
    });
  });

  group('StorePlanBanner', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('Chủ quán thấy dải nhắc, bấm ✕ thì ẩn và nhớ trong ngày', (tester) async {
      await tester.pumpWidget(_wrap(StorePlanBanner(storeId: 's1', status: _st(notice: 'trial_expired'), now: () => _now)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store_plan_banner')), findsOneWidget);
      expect(find.text('Quán đã hết thời gian dùng thử'), findsOneWidget);
      await tester.tap(find.byTooltip('Ẩn hôm nay'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store_plan_banner')), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(StorePlanBanner.prefsKey('s1')), StorePlanBanner.dayKey(_now));
    });

    testWidgets('app mở liền qua ngày mới → dải nhắc tự hiện lại', (tester) async {
      var now = _now;
      await tester.pumpWidget(_wrap(StorePlanBanner(storeId: 's1', status: _st(notice: 'trial_expired'), now: () => now)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ẩn hôm nay'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store_plan_banner')), findsNothing);
      now = _now.add(const Duration(days: 1));
      await tester.pumpWidget(_wrap(StorePlanBanner(storeId: 's1', status: _st(notice: 'trial_expired'), now: () => now)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store_plan_banner')), findsOneWidget);
    });

    testWidgets('đã ẩn hôm nay → không hiện; sang ngày mới → hiện lại', (tester) async {
      SharedPreferences.setMockInitialValues({StorePlanBanner.prefsKey('s1'): StorePlanBanner.dayKey(_now)});
      await tester.pumpWidget(_wrap(StorePlanBanner(storeId: 's1', status: _st(notice: 'trial_expired'), now: () => _now)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store_plan_banner')), findsNothing);
      await tester.pumpWidget(_wrap(StorePlanBanner(
        key: const ValueKey('ngay-mai'),
        storeId: 's1',
        status: _st(notice: 'trial_expired'),
        now: () => _now.add(const Duration(days: 1)),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store_plan_banner')), findsOneWidget);
    });

    testWidgets('nhân viên không thấy dải nhắc', (tester) async {
      await tester.pumpWidget(_wrap(StorePlanBanner(storeId: 's1', status: _st(notice: 'trial_expired', owner: false), now: () => _now)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('store_plan_banner')), findsNothing);
    });
  });

  testWidgets('StoreLockedView: tên quán, câu liên hệ, 2 nút hoạt động', (tester) async {
    var retried = 0, loggedOut = 0;
    await tester.pumpWidget(_wrap(StoreLockedView(
      storeName: 'Quán <b>A</b>',
      contact: 'Gọi 0900',
      onRetry: () => retried++,
      onLogout: () => loggedOut++,
    )));
    expect(find.byKey(const Key('store_locked_title')), findsOneWidget);
    expect(find.textContaining('"Quán <b>A</b>" đang tạm ngưng sử dụng. Gọi 0900'), findsOneWidget);
    await tester.tap(find.text('Kiểm tra lại'));
    await tester.tap(find.text('Đăng xuất / đổi quán'));
    expect((retried, loggedOut), (1, 1));
  });
}
