import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/widgets/boom_answer_text.dart';

void main() {
  test(
    'tách câu trả lời theo mục: kết luận, tiêu đề, gạch đầu dòng, khoảng cách',
    () {
      const a =
          'Dạ Chị Thanh, tháng 10 quán chưa mở buổi chiều.\n\n'
          'Vì sao: 18h đạt 252.000đ.\n\n'
          'Việc tuần này:\n- Thử combo giờ tối;\n  đo số combo.\n- Chuẩn bị người cho 20h–22h.\n\n'
          'Tuần 1: Hạ combo.\n1. Món A — 49 món\n\nCần xem lại: quán nghỉ Thứ 2.';
      final d = tachBoomTraLoi(a);
      expect(d.first.loai, BoomDongLoai.ketLuan);
      final td = d
          .where((x) => x.loai == BoomDongLoai.tieuDe)
          .map((x) => '${x.nhan}|${x.chu}')
          .toList();
      expect(td, [
        'Vì sao|18h đạt 252.000đ.',
        'Việc tuần này|',
        'Tuần 1|Hạ combo.',
        'Cần xem lại|quán nghỉ Thứ 2.',
      ]);
      final g = d
          .where((x) => x.loai == BoomDongLoai.gach)
          .map((x) => '${x.nhan}|${x.chu}')
          .toList();
      expect(g, [
        '•|Thử combo giờ tối;',
        '•|Chuẩn bị người cho 20h–22h.',
        '1.|Món A — 49 món',
      ]);
      // dòng nối tiếp (không có dấu đầu dòng) giữ là chữ thường
      expect(
        d.any((x) => x.loai == BoomDongLoai.chu && x.chu == 'đo số combo.'),
        isTrue,
      );
    },
  );

  test(
    'câu ngắn một đoạn không in đậm kết luận; số đầu dòng như "14–17h" không bị coi là gạch',
    () {
      expect(
        tachBoomTraLoi('Dạ, Bé Boom nhớ rồi ạ!').single.loai,
        BoomDongLoai.chu,
      );
      expect(tachBoomTraLoi('14–17h vắng nhất.').single.loai, BoomDongLoai.chu);
    },
  );

  testWidgets('vẽ được câu có mục', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BoomAnswerText(
            text: 'Dạ, kết luận.\n\nViệc tuần này:\n- Việc một.',
            style: TextStyle(fontSize: 15),
          ),
        ),
      ),
    );
    expect(find.text('Dạ, kết luận.'), findsOneWidget);
    expect(find.text('Việc một.'), findsOneWidget);
    expect(find.text('•'), findsOneWidget);
  });
}
