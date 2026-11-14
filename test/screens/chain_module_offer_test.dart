import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quannho_pos/core/repositories/chain_repository.dart';
import 'package:quannho_pos/screens/chain_module_offer.dart';

Map<String, dynamic> _owned(int n, {bool chain = false}) => {
  'success': true,
  'chains': chain
      ? [
          {
            'id': 'c1',
            'name': 'Chuoi',
            'stores': [for (var i = 0; i < n; i++) {'store_id': 's$i', 'name': 'Q$i', 'store_code': 'C$i'}],
          },
        ]
      : [],
  'owned_stores': [for (var i = 0; i < n; i++) {'store_id': 's$i', 'name': 'Q$i', 'store_code': 'C$i', 'chain_id': null}],
};

Future<(int, int)> _pump(WidgetTester t) async {
  var activated = 0, enabled = 0;
  await t.pumpWidget(MaterialApp(
    home: ChainModuleOffer(
      storeId: 'store-1',
      repository: ChainRepository(),
      activateModule: () async => activated++,
      onEnabled: () => enabled++,
    ),
  ));
  await t.pumpAndSettle();
  return (activated, enabled);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => ChainRepository.rpcOverride = null);

  testWidgets('chủ có 2 cửa hàng: bật module một lần và nhớ cờ', (t) async {
    ChainRepository.rpcOverride = (fn, p) async => _owned(2);
    final (a, e) = await _pump(t);
    expect((a, e), (1, 1));
    expect((await SharedPreferences.getInstance()).getBool(ChainModuleOffer.prefsKey('store-1')), isTrue);
  });

  testWidgets('đã bật trước đó: không bật lại (chủ đã gỡ thì không tự quay lại)', (t) async {
    SharedPreferences.setMockInitialValues({ChainModuleOffer.prefsKey('store-1'): true});
    ChainRepository.rpcOverride = (fn, p) async => fail('không được gọi server khi đã có cờ');
    final (a, e) = await _pump(t);
    expect((a, e), (0, 0));
  });

  testWidgets('chủ chỉ có 1 cửa hàng: không bật, không đặt cờ (lần sau kiểm tra lại)', (t) async {
    ChainRepository.rpcOverride = (fn, p) async => _owned(1);
    final (a, e) = await _pump(t);
    expect((a, e), (0, 0));
    expect((await SharedPreferences.getInstance()).getBool(ChainModuleOffer.prefsKey('store-1')), isNull);
  });

  testWidgets('đã có chuỗi (kể cả chỉ 1 cửa hàng còn lại): bật module', (t) async {
    ChainRepository.rpcOverride = (fn, p) async => _owned(1, chain: true);
    final (a, e) = await _pump(t);
    expect((a, e), (1, 1));
  });

  testWidgets('lỗi server / chưa có JWT: im lặng, không đặt cờ, không crash', (t) async {
    ChainRepository.rpcOverride = (fn, p) async => {'success': false, 'error': 'UNAUTHENTICATED'};
    final (a, e) = await _pump(t);
    expect((a, e), (0, 0));
    expect((await SharedPreferences.getInstance()).getBool(ChainModuleOffer.prefsKey('store-1')), isNull);
  });

  testWidgets('bật module lỗi thì KHÔNG đặt cờ để lần sau thử lại', (t) async {
    ChainRepository.rpcOverride = (fn, p) async => _owned(2);
    var enabled = 0;
    await t.pumpWidget(MaterialApp(
      home: ChainModuleOffer(
        storeId: 'store-1',
        repository: ChainRepository(),
        activateModule: () async => throw Exception('db down'),
        onEnabled: () => enabled++,
      ),
    ));
    await t.pumpAndSettle();
    expect(enabled, 0);
    expect((await SharedPreferences.getInstance()).getBool(ChainModuleOffer.prefsKey('store-1')), isNull);
  });
}
