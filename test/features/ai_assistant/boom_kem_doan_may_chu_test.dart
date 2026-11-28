// Web 04/11/2026: đường hỏi máy chủ không kèm đoạn hướng dẫn nên câu cách dùng app bị đoán ("thường vẫn bán được khi mất mạng").
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/help/help_search.dart';
import 'package:quannho_pos/features/ai_assistant/help/huong_dan_parser.dart';
import 'package:quannho_pos/features/ai_assistant/providers/boom_chat_provider.dart';

void main() {
  final d = jsonDecode(File('assets/boom_help/huong_dan.json').readAsStringSync()) as Map;
  final index = HelpIndex([
    for (final c in d['chunks'] as List) HelpChunk.fromJson(c as Map<String, dynamic>),
  ]);
  List<String> doan(String q) {
    final r = decideHelp(index, q);
    return boomHelpChoMayChu(r, q, sure: r.decision == HelpDecision.answer).map((c) => c.id).toList();
  }

  test('câu cách dùng app được kèm đúng đoạn', () {
    expect(doan('không có mạng thì bán được không').join(' '), contains('mat-mang'));
    expect(doan('app này có mất phí không').join(' '), contains('mat-phi'));
    // bộ lọc kiến thức chung không được chặn câu bộ tìm đã chắc
    expect(doan('dùng thử được bao lâu, hết hạn thì sao').join(' '), contains('mat-phi'));
  });

  test('từ giống kiến thức chung nhưng đang hỏi về app thì không bị chặn', () {
    expect(boomGeneralKnowledge('xài thử hết hạn rồi giờ sao'), isFalse);
    expect(boomGeneralKnowledge('nhập mã KM cho khách mà nó báo hết hạn'), isFalse);
    expect(boomGeneralKnowledge('muốn giao việc lau máy pha cho ca tối'), isFalse);
    expect(boomGeneralKnowledge('app có đổi sang tiếng anh được không'), isFalse);
    // câu kiến thức chung thật vẫn giữ nguyên
    expect(boomGeneralKnowledge('sữa tươi hết hạn còn dùng được không'), isTrue);
    expect(boomGeneralKnowledge('nên mua máy pha loại nào'), isTrue);
    expect(boomGeneralKnowledge('dịch câu này sang tiếng anh giúp mình'), isTrue);
  });

  test('câu ngắn nối tiếp lượt trước', () {
    const truoc = 'tạo mã giảm giá ở đâu';
    expect(boomIsFollowUp('rồi khách dùng thế nào', previous: truoc), isTrue);
    expect(boomIsFollowUp('còn ảnh món thì sao', previous: 'thêm món vào menu bấm vào đâu'), isTrue);
    // chỗ mới, câu đầu phiên vẫn là câu mới
    expect(boomIsFollowUp('còn cái nút in tạm tính nằm đâu', previous: truoc), isFalse);
    expect(boomIsFollowUp('rồi khách dùng thế nào'), isFalse);
  });

  test('câu nối tiếp gửi máy chủ: tự tìm được thì dùng, không thì ghép câu trước', () {
    final rieng = decideHelp(index, 'app lỗi rồi');
    expect(rieng.decision, isNot(HelpDecision.none));
    expect(boomHelpNoiTiep(rieng, () => fail('không được ghép')), same(rieng));
    const khong = HelpResult(HelpDecision.none, []);
    expect(boomHelpNoiTiep(khong, () => rieng), same(rieng));
  });

  test('tên tài khoản là tên quán thì không gọi theo tên', () {
    expect(boomGoiNguoiDung(null, 'Quán Nhỏ POS'), 'Anh/Chị');
    expect(boomGoiNguoiDung('anh', 'Trần Quân'), 'Anh Quân');
  });

  test('không có kết quả tìm thì không kèm', () {
    expect(boomHelpChoMayChu(null, 'x', sure: false), isEmpty);
  });
}
