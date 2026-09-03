import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/ban_repository.dart';
import 'package:quannho_pos/modules/qr_order/models/qr_order_model.dart';
import 'package:quannho_pos/modules/qr_order/services/settlement_operation_manager.dart';

class _MemorySettlementStorage implements SettlementOperationStorage {
  final Map<String, String> values = {};
  bool failWrites = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<bool> remove(String key) async => values.remove(key) != null;

  @override
  Future<bool> write(String key, String value) async {
    if (failWrites) return false;
    values[key] = value;
    return true;
  }
}

void main() {
  group('Settlement V5 error classification', () {
    test('missing RPC is reported as server schema mismatch', () {
      final result = classifyBanSettlementTransportFailure(
        Exception(
          'PGRST202 Could not find the function public.settle_ban_session_v5 in the schema cache',
        ),
      );

      expect(result['error_code'], QrErrorCode.serverSchemaOutdated);
      expect(result['message'], contains('chưa được cập nhật'));
    });

    test('permission failure is not mislabeled as a network timeout', () {
      final result = classifyBanSettlementTransportFailure(
        Exception('POS_CHECKOUT_PERMISSION_DENIED'),
      );

      expect(result['error_code'], QrErrorCode.permissionDenied);
    });

    test('unknown transport failure remains fail-closed and uncertain', () {
      final result = classifyBanSettlementTransportFailure(
        Exception('connection reset after request'),
      );

      expect(result['error_code'], QrErrorCode.networkUncertain);
    });
  });

  group('Settlement V5 persistent idempotency', () {
    test('restart with same store/session/intent reuses key', () async {
      final storage = _MemorySettlementStorage();
      final first = SettlementOperationManager(storage: storage);
      final key1 = await first.getOrCreatePersistentKey(
        storeId: 'store-a',
        sessionId: 'session-a',
        paymentMethod: 'cash',
        discount: 1000,
      );

      final restarted = SettlementOperationManager(storage: storage);
      final key2 = await restarted.getOrCreatePersistentKey(
        storeId: 'store-a',
        sessionId: 'session-a',
        paymentMethod: 'cash',
        discount: 1000,
      );
      expect(key2, key1);
    });

    test('store scope prevents cross-store key reuse', () async {
      final storage = _MemorySettlementStorage();
      final manager = SettlementOperationManager(storage: storage);
      final keyA = await manager.getOrCreatePersistentKey(
        storeId: 'store-a',
        sessionId: 'same-session',
        paymentMethod: 'cash',
      );
      final keyB = await manager.getOrCreatePersistentKey(
        storeId: 'store-b',
        sessionId: 'same-session',
        paymentMethod: 'cash',
      );
      expect(keyB, isNot(keyA));
    });

    test('clear only removes the requested store/session operation', () async {
      final storage = _MemorySettlementStorage();
      final manager = SettlementOperationManager(storage: storage);
      final key = await manager.getOrCreatePersistentKey(
        storeId: 'store-a',
        sessionId: 'session-a',
        paymentMethod: 'transfer',
      );
      await manager.clearPersistent(storeId: 'store-a', sessionId: 'session-a');
      final restarted = SettlementOperationManager(storage: storage);
      final next = await restarted.getOrCreatePersistentKey(
        storeId: 'store-a',
        sessionId: 'session-a',
        paymentMethod: 'transfer',
      );
      expect(next, isNot(key));
    });

    test('fails closed when operation key cannot be persisted', () async {
      final storage = _MemorySettlementStorage()..failWrites = true;
      final manager = SettlementOperationManager(storage: storage);
      expect(
        () => manager.getOrCreatePersistentKey(
          storeId: 'store-a',
          sessionId: 'session-a',
          paymentMethod: 'cash',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
