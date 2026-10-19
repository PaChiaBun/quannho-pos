import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/bill_printer/utils/paper_sizes.dart';

void main() {
  test('có đủ các khổ giấy: 50mm, 58mm, 80mm, A5, A4 theo thứ tự', () {
    expect(kPaperSpecs.map((s) => s.key), ['50mm', '58mm', '80mm', 'a5', 'a4']);
  });

  test('bề rộng trang in từng khổ', () {
    expect(paperWidthMm('50mm'), 46);
    expect(paperWidthMm('58mm'), 48);
    expect(paperWidthMm('80mm'), 70);
    expect(paperWidthMm('a5'), 148);
    expect(paperWidthMm('a4'), 210);
  });

  test('khóa lạ, rỗng, hoa/thường -> 80mm hoặc nhận đúng', () {
    expect(paperWidthMm(null), 70);
    expect(paperWidthMm('xyz'), 70);
    expect(paperWidthMm('A4'), 210);
    expect(paperSpecOf('A5').key, 'a5');
  });

  test('phiếu bếp chỉ cho chọn khổ nhiệt: 50/58/80mm', () {
    expect(kKitchenPaperSpecs.map((s) => s.key), ['50mm', '58mm', '80mm']);
  });

  test('khổ nhỏ hơn thì khung xem trước hẹp hơn', () {
    final f = kPaperSpecs.map((s) => s.billPreview).toList();
    for (var i = 1; i < f.length; i++) {
      expect(f[i] >= f[i - 1], isTrue);
    }
  });
}
