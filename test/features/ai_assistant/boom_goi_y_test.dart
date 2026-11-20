import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/services/boom_module_data_service.dart';

BoomPerms _q(String role, List<String> mods, {bool owner = false}) => BoomPerms(
  isOwner: owner,
  canonicalRole: role,
  modules: mods,
  active: const {'pos', 'kho', 'report', 'chamcong'},
);

void main() {
  test('chủ quán thấy đủ câu số', () {
    expect(boomGoiYTheoQuyen(_q('owner', [], owner: true)), [
      'Hôm nay bán được bao nhiêu?',
      'Huỷ món đã gửi bếp thế nào?',
      'Kho có gì sắp hết?',
      'Món nào bán chạy nhất?',
      'Hôm nay ai đang làm?',
    ]);
  });

  test('nhân viên không xem Báo cáo: không gợi ý câu sẽ bị từ chối', () {
    expect(
      boomGoiYTheoQuyen(_q('staff', const ['pos', 'chamcong'])),
      kBoomGoiYChung,
    );
  });

  test(
    'thu ngân có Báo cáo thấy câu bán hàng, không thấy câu kho và ai đang làm',
    () {
      final g = boomGoiYTheoQuyen(
        _q('cashier', const ['pos', 'report', 'chamcong']),
      );
      expect(g, contains('Hôm nay bán được bao nhiêu?'));
      expect(g, isNot(contains('Kho có gì sắp hết?')));
      expect(g, isNot(contains('Hôm nay ai đang làm?')));
    },
  );

  test('chưa rõ quyền: chỉ câu chung', () {
    expect(boomGoiYTheoQuyen(null), kBoomGoiYChung);
  });

  test('câu gợi ý dưới trả lời: bỏ câu số không xem được, giữ câu khác', () {
    const g = [
      'Món nào bán ế?',
      'Doanh thu tháng này?',
      'Doanh thu tháng trước?',
      'Hôm nay ai đang làm?',
      'Kho có gì sắp hết?',
      'Quản lý Bàn: Sửa, giảm, huỷ món',
    ];
    expect(boomLocGoiY(g, _q('staff', const ['pos'])), [
      'Quản lý Bàn: Sửa, giảm, huỷ món',
    ]);
    expect(boomLocGoiY(g, _q('owner', const [], owner: true)), g);
  });
}
