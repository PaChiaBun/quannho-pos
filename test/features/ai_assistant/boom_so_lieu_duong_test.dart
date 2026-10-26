import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/classifier/intent_classifier.dart';
import 'package:quannho_pos/features/ai_assistant/providers/boom_chat_provider.dart';
import 'package:quannho_pos/features/ai_assistant/services/boom_module_data_service.dart'
    show BoomModule;

// Chọn đường câu số liệu (bộ câu số liệu độc lập + QC 26/10): câu xin số → đọc số; câu hỏi cách làm / luật / kiến
// thức có cùng chữ → không đọc số.
void main() {
  String intent(String q) => IntentClassifier.classify(q).intent;

  test('Câu xin số viết tắt / không dấu / đời thường → loại số liệu', () {
    for (final q in [
      'dt hom nay',
      'dt thang 9',
      'tuần này được mấy đơn giao hàng',
      'hôm qua bao nhiêu bill',
      'tháng trước quán thu được tổng cộng bao nhiêu tiền',
    ]) {
      expect(intent(q), 'revenue_summary', reason: q);
    }
    expect(intent('tháng rồi món gì ra nhiều nhất vậy'), 'top_products');
    expect(
      intent('liệt kê mấy món cả tháng nay không ai gọi'),
      'slow_products',
    );
  });

  test('Cùng chữ nhưng không xin số → không phải doanh thu', () {
    for (final q in [
      'dt là gì',
      'xem đt khách ở đâu',
      'số bill bị nhảy cóc',
      'xem lai may don vua ban gan day',
      'đổi số đơn vị của nguyên liệu',
    ]) {
      expect(intent(q), isNot('revenue_summary'), reason: q);
    }
  });

  test(
    '"đề xuất" không phải "xuất file"; xin phân tích dựa trên số → tư vấn kèm số',
    () {
      expect(boomAsksHowTo('dựa vào số bán hãy đề xuất combo'), isFalse);
      expect(boomAsksHowTo('xuất báo cáo excel sao'), isTrue);
      expect(boomWantsDataAdvice('dựa vào số bán hãy đề xuất combo'), isTrue);
      expect(boomWantsDataAdvice('dua tren so ban de xuat combo'), isTrue);
      // "xem số" trần là xin số, không phải xin phân tích
      expect(boomWantsDataAdvice('coi số bán tuần này'), isFalse);
    },
  );

  test(
    'Số theo mục: xin số → đúng mục; cách tính / luật / ngưỡng → không đọc số',
    () {
      expect(
        boomModuleTopics('hôm nay ai vào ca rồi'),
        contains(BoomModule.nhanSu),
      );
      expect(
        boomModuleTopics('tuần này lời không'),
        contains(BoomModule.finance),
      );
      expect(
        boomModuleTopics('trân châu còn nhiêu hông'),
        contains(BoomModule.kho),
      );
      for (final q in [
        'lãi lỗ tính như thế nào',
        'lương nhân viên tháng 13 có bắt buộc không',
        'vào ca lúc nào thì tính đi trễ',
        'ca tối có mấy người là đủ',
        'con nhieu ngay nua het han goi',
        'nên trả lương nhân viên bao nhiêu',
        'khách ghé nhiều thì tặng gì cho họ quay lại',
      ]) {
        expect(boomModuleTopics(q), isEmpty, reason: q);
      }
    },
  );
}
