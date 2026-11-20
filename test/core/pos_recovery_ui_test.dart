import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quannho_pos/core/repositories/core_product_repository.dart';
import 'package:quannho_pos/core/repositories/core_customer_repository.dart';
import 'package:quannho_pos/modules/kho_chuyen_nghiep/repository/kho_chuyen_nghiep_repository.dart';
import 'package:quannho_pos/modules/pos/repository/pos_repository.dart';
import 'package:quannho_pos/modules/pos/providers/pos_providers.dart';
import 'package:quannho_pos/modules/pos/screens/checkout_sheet.dart';

class _Products implements CoreProductRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Customers implements CoreCustomerRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stock implements KhoProRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecoveryRepo extends PosRepository {
  _RecoveryRepo() : super(_Products(), _Customers(), _Stock());
  final completion = Completer<PosSaleResult>();
  int recoverCalls = 0;
  int acknowledgments = 0;
  @override
  Future<Map<String, dynamic>?> pendingSale() async => {
    'idempotency_key': 'durable-key',
    'intent': {'expected_total': 59000, 'payment_method': 'cash'},
  };
  @override
  Future<PosSaleResult> recoverSale() {
    recoverCalls++;
    return completion.future;
  }

  @override
  Future<void> acknowledgeSale(PosSaleResult result) async {
    expect(result.operationKey, 'durable-key');
    acknowledgments++;
  }
}

Future<void> _open(WidgetTester tester, _RecoveryRepo repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [posRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => recoverPendingPosSale(context, ref),
              child: const Text('Recover'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Recover'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'recovery requires explicit confirmation; cancel sends no payment',
    (tester) async {
      final repo = _RecoveryRepo();
      await _open(tester, repo);
      expect(find.textContaining('59000'), findsOneWidget);
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(repo.recoverCalls, 0);
      expect(repo.acknowledgments, 0);
    },
  );
  testWidgets(
    'delayed recovery remains pending until result and acknowledgment',
    (tester) async {
      final repo = _RecoveryRepo();
      await _open(tester, repo);
      await tester.tap(find.text('Đối soát / tiếp tục đơn cũ'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      expect(repo.recoverCalls, 1);
      expect(repo.acknowledgments, 0);
      expect(find.textContaining('Đang đối soát với server'), findsOneWidget);
      repo.completion.complete(
        const PosSaleResult(
          orderId: 'o',
          orderNumber: 'QN-001',
          totalAmount: 59000,
          isReplay: true,
          operationKey: 'durable-key',
          storeId: 's',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('QN-001'), findsOneWidget);
      expect(repo.acknowledgments, 0);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(repo.acknowledgments, 1);
    },
  );
  testWidgets(
    'network failure never acknowledges or deletes pending operation',
    (tester) async {
      final repo = _RecoveryRepo();
      await _open(tester, repo);
      await tester.tap(find.text('Đối soát / tiếp tục đơn cũ'));
      await tester.pumpAndSettle();
      repo.completion.completeError(StateError('Network unavailable'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Network unavailable'), findsOneWidget);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(repo.acknowledgments, 0);
    },
  );
}
