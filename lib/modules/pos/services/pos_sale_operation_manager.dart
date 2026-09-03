import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../qr_order/services/settlement_operation_manager.dart';

class PosSaleOperationManager {
  static const _prefix = 'pos_sale_v1_pending';
  static const _uuid = Uuid();
  static final Map<String, Future<void>> _queues = {};
  final SettlementOperationStorage storage;

  PosSaleOperationManager({SettlementOperationStorage? storage})
    : storage = storage ?? SharedPreferencesSettlementOperationStorage();

  Future<T> _serialized<T>(String scope, Future<T> Function() action) {
    final previous = _queues[scope] ?? Future<void>.value();
    final result = previous.then((_) => action());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _queues[scope] = tail;
    tail.then((_) {
      if (identical(_queues[scope], tail)) _queues.remove(scope);
    });
    return result;
  }

  Future<String> getOrCreateKey({
    required String storeId,
    required Map<String, dynamic> intent,
  }) {
    final scope = '$_prefix:$storeId';
    return _serialized(scope, () async {
      final fingerprint = sha256
          .convert(utf8.encode(jsonEncode(intent)))
          .toString();
      final raw = await storage.read(scope);
      if (raw != null) {
        Map<String, dynamic> saved;
        try {
          saved = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          throw StateError(
            'Khóa thanh toán POS bị lỗi; cần đối soát trước khi tạo đơn mới',
          );
        }
        if (saved['fingerprint'] == fingerprint &&
            saved['idempotency_key'] is String &&
            (saved['idempotency_key'] as String).isNotEmpty) {
          return saved['idempotency_key'] as String;
        }
        throw StateError(
          'Còn thanh toán POS chưa rõ kết quả. Giữ nguyên giỏ hàng và phương thức để thử lại; không tạo đơn mới trước khi đối soát.',
        );
      }

      final key = _uuid.v4();
      final persisted = await storage.write(
        scope,
        jsonEncode({
          'fingerprint': fingerprint,
          'idempotency_key': key,
          'intent': intent,
        }),
      );
      if (!persisted) {
        throw StateError('Không thể lưu khóa chống thanh toán POS trùng');
      }
      return key;
    });
  }

  Future<Map<String, dynamic>?> pending(String storeId) {
    final scope = '$_prefix:$storeId';
    return _serialized(scope, () async {
      final raw = await storage.read(scope);
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    });
  }

  Future<void> clear(String storeId, {required String idempotencyKey}) {
    final scope = '$_prefix:$storeId';
    return _serialized(scope, () async {
      final raw = await storage.read(scope);
      if (raw == null) return;
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      if (saved['idempotency_key'] != idempotencyKey) return;
      if (!await storage.remove(scope)) {
        throw StateError(
          'Không thể xóa khóa thanh toán đã xác nhận; thử lại để đối soát',
        );
      }
    });
  }
}
