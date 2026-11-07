import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/ops/repository/ops_repository.dart';
import 'package:quannho_pos/modules/ops/widgets/ops_handover_card.dart';

OpsShiftHandoverModel handover({
  String? issues,
  String? notes,
  List<String> pending = const [],
}) => OpsShiftHandoverModel(
  id: 'h',
  storeId: 's',
  handoverDate: '2026-10-23',
  createdBy: 'u',
  createdByName: 'A',
  issues: issues,
  notes: notes,
  pendingTasks: pending,
  createdAt: '2026-10-23T03:00:00Z',
);

void main() {
  test('Báo cáo: dòng thuế GTGT không còn ghi 0đ như đã tính', () {
    final src = File('lib/screens/report_screen.dart').readAsStringSync();
    expect(src, contains("'  2. Tiền thuế GTGT (app chưa tính)'"));
    final i = src.indexOf('Tiền thuế GTGT');
    expect(src.substring(i, i + 120), contains("value: '—'"));
  });

  group('Vận hành: bàn giao ca', () {
    test('Thẻ bàn giao chỉ hiện khi có nội dung', () {
      expect(opsHandoverHasContent(handover()), isFalse);
      expect(opsHandoverHasContent(handover(issues: '  ', notes: '')), isFalse);
      expect(opsHandoverHasContent(handover(notes: 'Bàn 5 đặt 3pm')), isTrue);
      expect(opsHandoverHasContent(handover(issues: 'Máy hỏng')), isTrue);
      expect(opsHandoverHasContent(handover(pending: ['x'])), isTrue);
    });

    test('Thẻ bàn giao có ở màn nhân viên và Tổng Quan quản lý', () {
      for (final f in [
        'lib/modules/ops/screens/ops_staff_screen.dart',
        'lib/modules/ops/screens/ops_manager_dashboard.dart',
      ]) {
        expect(
          File(f).readAsStringSync(),
          contains('OpsHandoverCard()'),
          reason: f,
        );
      }
    });

    test('Lưu bàn giao lỗi thì báo, không im lặng; lưu xong làm mới thẻ', () {
      final src = File(
        'lib/modules/ops/screens/ops_staff_screen.dart',
      ).readAsStringSync();
      expect(src, contains("'Chưa lưu được bàn giao"));
      expect(src, contains('ref.invalidate(opsLatestHandoverProvider);'));
      // Phiên hết hạn không còn để nút quay mãi
      final submit = src.substring(src.indexOf('Future<void> _submit()'));
      expect(
        submit.indexOf('if (session == null)'),
        lessThan(submit.indexOf('_saving = true')),
      );
    });

    test('Đọc dòng bàn giao thiếu người tạo / danh sách lạ không lỗi', () {
      final h = OpsShiftHandoverModel.fromMap({
        'id': 'h',
        'store_id': 's',
        'created_by': null,
        'created_by_name': null,
        'pending_tasks': ['a', 1],
        'created_at': '2026-10-23T03:00:00.123456+00:00',
      });
      expect(h.createdBy, '');
      expect(h.pendingTasks, ['a', '1']);
    });

    test('Bảng bàn giao tự đóng chính nó, chặn đóng khi đang lưu', () {
      final src = File(
        'lib/modules/ops/screens/ops_staff_screen.dart',
      ).readAsStringSync();
      expect(src, contains('Navigator.of(context).pop(true);'));
      expect(src, contains('canPop: !_saving'));
      expect(
        src,
        isNot(
          contains('Navigator.pop(context);\n            ScaffoldMessenger'),
        ),
      );
    });

    test('Đọc bàn giao lỗi (máy chủ chưa có bảng) không làm vỡ màn', () {
      final src = File(
        'lib/modules/ops/providers/ops_providers.dart',
      ).readAsStringSync();
      final body = src.substring(
        src.indexOf('final opsLatestHandoverProvider'),
      );
      expect(body, contains('catch (_)'));
      expect(body, contains('return null;'));
    });
  });

  test('Vận hành: nhãn mức ưu tiên tiếng Việt', () {
    final src = File(
      'lib/modules/ops/screens/ops_config_screen.dart',
    ).readAsStringSync();
    for (final en in ["'Critical'", "'High'", "'Normal'", "'Low'"]) {
      expect(src, isNot(contains(en)), reason: en);
    }
    expect(src, contains("'Khẩn'"));
  });
}
