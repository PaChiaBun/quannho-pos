import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/screens/ban_screen.dart';

void main() {
  test('đóng phiên là bước CUỐI, sau mọi bước phụ', () async {
    final order = <String>[];
    await runCancelSteps(
      sessionId: 's1',
      tableLabel: 'B 1',
      steps: [
        CancelStep('audit', () async => order.add('audit')),
        CancelStep('món', () async => order.add('món')),
        CancelStep('phiếu bếp', () async => order.add('bếp')),
      ],
      closeSession: () async => order.add('đóng'),
    );
    expect(order, ['audit', 'món', 'bếp', 'đóng']);
  });

  test('bước bắt buộc lỗi -> KHÔNG đóng phiên, báo đúng tên bước', () async {
    var closed = false;
    final ran = <String>[];
    Object? err;
    try {
      await runCancelSteps(
        sessionId: 's1',
        tableLabel: 'B 1',
        steps: [
          CancelStep('audit', () async => ran.add('audit')),
          CancelStep('món', () async => throw Exception('SESSION_NOT_OPEN')),
          CancelStep('bếp', () async => ran.add('bếp')),
        ],
        closeSession: () async => closed = true,
      );
    } catch (e) {
      err = e;
    }
    expect(err, isA<CancelStepFailure>());
    expect((err as CancelStepFailure).step, 'món');
    expect(closed, isFalse, reason: 'phiên không được đóng khi bước món lỗi');
    expect(ran, ['audit'], reason: 'các bước sau bước lỗi không chạy');
  });

  test('bước phụ (optional) lỗi -> vẫn hủy được', () async {
    var closed = false;
    await runCancelSteps(
      sessionId: 's1',
      tableLabel: 'B 1',
      steps: [
        CancelStep(
          'void log',
          () async => throw Exception('x'),
          optional: true,
        ),
      ],
      closeSession: () async => closed = true,
    );
    expect(closed, isTrue);
  });

  test('đóng phiên lỗi -> báo lỗi (không nuốt)', () async {
    Object? err;
    try {
      await runCancelSteps(
        sessionId: 's1',
        tableLabel: 'B 1',
        steps: const [],
        closeSession: () async => throw Exception('network'),
      );
    } catch (e) {
      err = e;
    }
    expect((err as CancelStepFailure).step, 'đóng phiên');
  });
}
