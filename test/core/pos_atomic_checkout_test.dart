import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quannho_pos/modules/pos/services/pos_sale_operation_manager.dart';
import 'package:quannho_pos/modules/pos/providers/pos_providers.dart';
import 'package:quannho_pos/modules/pos/repository/pos_repository.dart';
import 'package:quannho_pos/modules/qr_order/services/settlement_operation_manager.dart';

class MemoryStorage implements SettlementOperationStorage {
  final values = <String, String>{};
  bool failWrites = false;
  bool failRemoves = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<bool> write(String key, String value) async {
    if (failWrites) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    if (failRemoves) return false;
    return values.remove(key) != null;
  }
}

void main() {
  const intent = {'payment_method': 'cash', 'total': 30000};
  group('POS durable idempotency', () {
    late MemoryStorage storage;
    late PosSaleOperationManager manager;
    setUp(() {
      storage = MemoryStorage();
      manager = PosSaleOperationManager(storage: storage);
    });
    test('50 concurrent calls across managers persist one key', () async {
      final keys = await Future.wait(
        List.generate(
          50,
          (_) => PosSaleOperationManager(
            storage: storage,
          ).getOrCreateKey(storeId: 'a', intent: intent),
        ),
      );
      expect(keys.toSet(), hasLength(1));
      expect(storage.values, hasLength(1));
    });
    test('restart reuses pending key and isolates store', () async {
      final first = await manager.getOrCreateKey(storeId: 'a', intent: intent);
      final restarted = PosSaleOperationManager(storage: storage);
      expect(
        await restarted.getOrCreateKey(storeId: 'a', intent: intent),
        first,
      );
      expect(
        await restarted.getOrCreateKey(storeId: 'b', intent: intent),
        isNot(first),
      );
    });
    test(
      'restart retains full recovery request including kitchen batches',
      () async {
        final request = {
          ...intent,
          'lines': [
            {'product_id': 'p', 'quantity': 2},
          ],
          'kitchen_session_ids': ['session-a'],
          'note': 'ít đá',
          'discount': 1.5,
        };
        final key = await manager.getOrCreateKey(storeId: 'a', intent: request);
        final restarted = PosSaleOperationManager(storage: storage);
        final pending = await restarted.pending('a');
        expect(pending!['idempotency_key'], key);
        expect(pending['intent'], request);
        expect(await restarted.pending('b'), isNull);
      },
    );
    test('changed intent cannot overwrite an uncertain payment', () async {
      final first = await manager.getOrCreateKey(storeId: 'a', intent: intent);
      await expectLater(
        manager.getOrCreateKey(
          storeId: 'a',
          intent: {'payment_method': 'transfer'},
        ),
        throwsStateError,
      );
      expect(await manager.getOrCreateKey(storeId: 'a', intent: intent), first);
    });
    test('corrupt storage is not silently replaced', () async {
      storage.values['pos_sale_v1_pending:a'] = 'broken';
      await expectLater(
        manager.getOrCreateKey(storeId: 'a', intent: intent),
        throwsStateError,
      );
      expect(storage.values.values.single, 'broken');
    });
    test('persistence failure prevents checkout key delivery', () async {
      storage.failWrites = true;
      await expectLater(
        manager.getOrCreateKey(storeId: 'a', intent: intent),
        throwsStateError,
      );
    });
    test('stale completion cannot remove a newer key', () async {
      final first = await manager.getOrCreateKey(storeId: 'a', intent: intent);
      await manager.clear('a', idempotencyKey: 'stale');
      expect(
        jsonDecode(storage.values.values.single)['idempotency_key'],
        first,
      );
      await manager.clear('a', idempotencyKey: first);
      expect(
        await manager.getOrCreateKey(storeId: 'a', intent: intent),
        isNot(first),
      );
    });
    test('failed cleanup preserves the key for replay', () async {
      final key = await manager.getOrCreateKey(storeId: 'a', intent: intent);
      storage.failRemoves = true;
      await expectLater(
        manager.clear('a', idempotencyKey: key),
        throwsStateError,
      );
      expect(await manager.getOrCreateKey(storeId: 'a', intent: intent), key);
    });
  });
  group('POS points quote', () {
    test('discount uses configured VND per point, not one VND', () {
      final cart = CartState(
        lines: [
          CartLine(
            productId: 'p',
            productName: 'Coffee',
            quantity: 1,
            unitPrice: 30000,
            costPrice: 0,
          ),
        ],
        loyaltyPtsUsed: 3,
        loyaltyRedeemRate: 2000,
      );
      expect(cart.pointsDiscount, 6000);
      expect(cart.total, 24000);
    });
    test('invalid conversion rates are rejected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      for (final rate in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          () =>
              container.read(cartProvider.notifier).setLoyaltyRedeemRate(rate),
          throwsArgumentError,
        );
      }
    });
    test('wallet selection clears points', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).setPaymentMethod('wallet');
      expect(container.read(cartProvider).loyaltyPtsUsed, 0);
    });
  });
}
