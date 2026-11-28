import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/classifier/intent_classifier.dart';
import 'package:quannho_pos/features/ai_assistant/help/help_search.dart';
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
    'Hỏi số + mốc thời gian (từ khoá chưa nhận ra) → đọc số; hỏi cách làm / luật → không',
    () {
      for (final q in [
        'tối qua có bao nhiêu bill mang về',
        'năm nay tới giờ bán được tổng cộng nhiêu rồi',
      ]) {
        expect(boomAsksShopNumber(q), isTrue, reason: q);
      }
      for (final q in [
        'sao doanh thu hôm nay bằng 0',
        'xem báo cáo tháng trước ở đâu',
        'mỗi tháng nên chi bao nhiêu cho quảng cáo',
        'tháng 4 nghỉ lễ mấy ngày',
        'in lại bill hôm qua sao',
        // QC 26/10: có từ hỏi số + mốc thời gian nhưng không hỏi số bán
        'hôm nay ngày mấy',
        'chiều nay mấy giờ quán đóng cửa',
        'quý 4 nộp thuế bao nhiêu phần trăm',
        'sáng nay wifi chậm, mấy máy order không gửi được bếp',
        'cam on em hom nay giup nhieu',
      ]) {
        expect(boomAsksShopNumber(q), isFalse, reason: q);
      }
    },
  );

  test(
    'Bộ F, G 27/10: động từ là thứ được đếm → xin số; "sữa", "chuyển khoản" không phải thao tác',
    () {
      for (final q in [
        'hôm nay huỷ mấy đơn rồi',
        'tháng trước có bao nhiêu đơn bị huỷ',
        'hôm qua xoá món bao nhiêu lần',
        'hôm nay ai huỷ đơn nhiều nhất',
      ]) {
        expect(boomAsksShopNumber(q), isTrue, reason: q);
      }
      for (final q in [
        'hôm nay huỷ đơn sao',
        'hôm qua in lại mấy bill bị lỗi',
        'tuần trước huỷ mấy đơn thì xem ở đâu',
        // QC 27/10: "mấy" = "vài"; hỏi giới hạn
        'hôm qua lỡ huỷ mấy đơn giờ khôi phục lại',
        '1 ngày khách được nhập mã km mấy lần',
      ]) {
        expect(boomAsksShopNumber(q), isFalse, reason: q);
      }
      expect(
        hasHelpActionWord('2 tuần nay bán đc bao nhiêu ly trà sữa'),
        isFalse,
      );
      expect(hasHelpActionWord('tiền mặt với chuyển khoản hôm nay'), isFalse);
      expect(hasHelpActionWord('sửa giá món'), isTrue);
      expect(hasHelpActionWord('chuyển bàn cho khách'), isTrue);
    },
  );

  test(
    'Đợt 12: xin phân tích trên số của quán → tư vấn kèm số; hỏi cách làm / báo lỗi / lạc đề → không',
    () {
      for (final q in [
        'nhìn doanh thu theo giờ thì ca tối có cần thêm người ko',
        'chi phí tháng này cao bất thường chỗ nào, xem giùm',
        'lương đang chiếm mấy phần trăm doanh thu, vậy ổn ko',
        'tỉ lệ huỷ đơn của quán có cao không, làm sao giảm',
        'quý 3 vs quý 2 lời hơn hay lỗ hơn, nguyên nhân do đâu',
      ]) {
        expect(boomWantsDataAdvice(q), isTrue, reason: q);
      }
      for (final q in [
        'tại sao đơn bị huỷ mà không báo',
        'vì sao nhân viên không đăng nhập được',
        'cần thêm khách vào danh sách thành viên',
        'có nên bật in bill tự động không',
        'bill in ra cao quá phải chỉnh khổ giấy',
        'làm sao giảm giá món cho khách',
      ]) {
        expect(boomWantsDataAdvice(q), isFalse, reason: q);
      }
      for (final q in [
        'hôm nay sài gòn mưa không',
        'con bị sốt 39 độ uống thuốc gì',
      ]) {
        expect(boomGeneralKnowledge(q), isTrue, reason: q);
      }
      for (final q in [
        'gà sốt 3 phần hôm nay bán mấy đơn',
        'phí dịch vụ hôm nay thu bao nhiêu',
        'trà đá mấy giờ bán chạy nhất',
      ]) {
        expect(boomGeneralKnowledge(q), isFalse, reason: q);
      }
    },
  );

  test('Giai đoạn 1 (lần 6–15): hiểu đúng câu hỏi', () {
    // lần 6
    expect(
      boomAsksHowTo('lương bé Thảo tháng rồi ít bất thường, lỗi gì vậy'),
      isTrue,
    );
    expect(
      boomAsksPeriodMetric('báo cáo hôm nay chưa có giao dịch nào'),
      isFalse,
    );
    // lần 7
    expect(
      boomAsksPeriodMetric('nhìn số năm nay quán có đang đi lên không'),
      isTrue,
    );
    // lần 8
    expect(
      boomRewriteFollowUp(
        'khung tối thì sao',
        'tuần rồi khung trưa bán ổn không',
      ),
      'tuần rồi khung tối bán ổn không',
    );
    expect(
      boomRewriteFollowUp('còn chi nhánh 2', 'doanh thu hôm nay chi nhánh 1'),
      'doanh thu hôm nay chi nhánh 2',
    );
    expect(boomNormalizeTeen('doanh thu hnay cn 1'), contains('chi nhanh 1'));
    // lần 9
    expect(
      boomWantsDataAdvice('doanh thu sao giảm so với tuần trước vậy'),
      isTrue,
    );
    // lần 10, 11
    expect(
      boomShortFollowUp(
        'giảm kiểu gì',
        previous: 'food cost tháng 9 có cao không',
      ),
      isTrue,
    );
    expect(
      boomIsFollowUp('nói lại ngắn gọn thôi', previous: 'doanh thu tháng 9'),
      isTrue,
    );
    // lần 12, 13
    expect(boomHelpFollowUp('vậy hôm qua ai đi trễ'), isFalse);
    for (final q in [
      'tối nay MU đá mấy giờ',
      'thoi tiet mai sao',
      'app nào quản lý quán tốt hơn',
    ]) {
      expect(boomGeneralKnowledge(q), isTrue, reason: q);
    }
    expect(boomGeneralKnowledge('bun bo hue ban chay khong'), isFalse);
  });

  test(
    'Đợt 16: kỳ + con số + từ hỏi → tư vấn kèm số; đếm "hết bao nhiêu tiền"',
    () {
      for (final q in [
        'tháng này lỗ hay lời',
        '7 ngày qua bán sao',
        'thang 9 food cost co cao khong',
        'khung giờ nào hôm nay đông nhất',
      ]) {
        expect(boomAsksPeriodMetric(q), isTrue, reason: q);
      }
      for (final q in [
        'cách xem doanh thu tháng này ở đâu',
        'tháng này lỗi máy in hoài',
        'nên trả lương nhân viên bao nhiêu',
      ]) {
        expect(boomAsksPeriodMetric(q), isFalse, reason: q);
      }
      expect(
        boomCountsShopAction('tuần này nhập hàng hết bao nhiêu tiền'),
        isTrue,
      );
      expect(boomCountsShopAction('nay có mấy đơn bị hủy vậy'), isTrue);
    },
  );

  test('Đợt 15: nói tiếp sau lượt số liệu / hướng dẫn', () {
    // câu xin phân tích dài, xếp hạng, chữ thao tác đã có ở câu trước, xin tư vấn tăng chỉ số → nói tiếp
    for (final (q, prev) in [
      (
        'sao lãi mỏng dữ, hụt ở khúc nào chỉ tôi coi',
        'tháng 9 lãi được bao nhiêu',
      ),
      (
        'nhiều thế có bất thường không, nên cắt bớt chỗ nào',
        'tháng 8 tiền điện nước hết bao nhiêu',
      ),
      ('ai hủy nhiều nhất', 'nay có mấy đơn bị hủy'),
      ('tiền hủy tổng cộng là nhiêu', 'tuần trước hủy bao nhiêu món'),
      ('cà phê sữa đá thì sao', '30 ngày qua bán được bao nhiêu ly trà sữa'),
      (
        'có cách nào nâng giá trị đơn lên không',
        'trung bình mỗi đơn hôm nay bao nhiêu',
      ),
    ]) {
      expect(boomShortFollowUp(q, previous: prev), isTrue, reason: q);
    }
    // câu mới / hỏi chỗ trong app / kiến thức chung → không
    for (final q in [
      'tháng 9 lương nhân viên tổng bao nhiêu',
      'kinh nghiệm giữ chân nv part time là gì',
      'nút in tạm tính ở đâu',
      'cách thêm món mới',
    ]) {
      expect(
        boomShortFollowUp(q, previous: 'doanh thu hôm nay'),
        isFalse,
        reason: q,
      );
    }
    expect(
      boomModuleTopics('tháng 9 lương nhân viên tổng bao nhiêu'),
      contains(BoomModule.nhanSu),
    );
    expect(
      boomIsFollowUp(
        'chiếm mấy % doanh thu tháng đó',
        previous: 'tháng 7 lương nv tổng hết nhiêu',
      ),
      isTrue,
    );
    expect(hasHelpActionWord('cà phê sữa đá bán mấy ly'), isFalse);
    // hỏi cách làm về đúng thứ vừa nói / câu nối ý sau bài hướng dẫn
    expect(boomHelpAboutPrevious('nó bị âm thì chỉnh lại kiểu gì'), isTrue);
    expect(boomHelpAboutPrevious('xem cái này trong app ở đâu'), isTrue);
    expect(boomHelpAboutPrevious('món đó tháng trước thì sao'), isFalse);
    expect(boomHelpFollowUp('lỡ gộp nhầm thì tách lại được không'), isTrue);
    expect(boomHelpFollowUp('doanh thu hôm nay bao nhiêu'), isFalse);
    expect(boomHelpFollowUp('cảm ơn nha'), isFalse);
  });

  test('Đợt 14: câu nói tiếp ngắn → câu đầy đủ; dấu hiệu nói tiếp rõ', () {
    for (final (q, prev, want) in [
      (
        'còn hôm qua?',
        'doanh thu hôm nay bao nhiêu',
        'doanh thu bao nhiêu hôm qua',
      ),
      (
        'tuần trước thì sao',
        'doanh thu tuần này được nhiêu rồi',
        'doanh thu được nhiêu rồi tuần trước',
      ),
      (
        'còn món bán ế nhất?',
        'món nào bán chạy nhất tuần này',
        'món bán ế nhất tuần này',
      ),
      (
        'con thang truoc',
        'thang nay ban duoc bao nhieu',
        'ban duoc bao nhieu thang truoc',
      ),
    ]) {
      expect(boomRewriteFollowUp(q, prev), want, reason: q);
    }
    // câu mới tự đủ nghĩa / hỏi chỗ mới → không viết lại
    expect(
      boomRewriteFollowUp(
        'còn cái nút in tạm tính nằm đâu',
        'doanh thu hôm nay',
      ),
      isNull,
    );
    expect(boomRewriteFollowUp('cảm ơn nha', 'doanh thu hôm nay'), isNull);
    // QC đợt 14: "còn" là động từ; lời đệm đầu câu mới; câu nói tiếp rõ; "nữa"; câu trước có hai kỳ
    for (final (q, prev) in [
      ('còn mấy ly trà sữa', 'doanh thu hôm nay'),
      ('còn hàng không', 'doanh thu hôm nay'),
      ('ok in lại bill sao', 'doanh thu hôm nay'),
      ('vậy thôi cảm ơn', 'doanh thu hôm nay'),
      ('vậy sao giảm vậy', 'doanh thu hôm nay'),
      ('còn tuần trước nữa', 'doanh thu tuần trước'),
      ('còn tuần này', 'doanh thu hôm nay so với hôm qua'),
    ]) {
      final r = boomRewriteFollowUp(q, prev);
      expect(r == null || !r.endsWith('tuần trước'), isTrue, reason: '$q → $r');
      if (!q.contains('nữa')) expect(r, isNull, reason: q);
    }
    expect(
      boomRewriteFollowUp('còn hôm qua thì sao nhỉ', 'doanh thu hôm nay'),
      'doanh thu hôm qua',
    );
    for (final q in [
      'làm rồi mà vẫn không in được',
      'nếu không có quyền thì sao',
      'bước tiếp theo là gì',
      'món đó tháng trước thì sao',
      'có đáng lo không',
      'chi tiết từng ngày đi',
    ]) {
      // "lương nhân viên chiếm bao nhiêu % doanh thu" cần cả số bán → tư vấn kèm số như cũ
      expect(
        boomModuleTopics(
          'Lương nhân viên đang chiếm bao nhiêu phần doanh thu, vậy có cao quá không?',
        ),
        isEmpty,
      );
      expect(boomIsFollowUp(q, previous: 'câu trước'), isTrue, reason: q);
    }
    expect(
      boomIsFollowUp('còn cái nút in tạm tính nằm đâu', previous: 'x'),
      isFalse,
    );
    for (final q in [
      'cách in hoá đơn chi tiết',
      'xem chi tiết đơn hàng thế nào',
      'bật lại món đã tắt bán',
      'nếu không có internet thì bán được không',
      'ngày kia mở cửa mấy giờ',
    ]) {
      expect(
        boomIsFollowUp(q, previous: 'doanh thu hôm nay'),
        isFalse,
        reason: q,
      );
    }
  });

  test('Đợt 13: chuẩn hoá teencode / viết tắt trước khi chọn đường', () {
    for (final (q, want) in [
      ('hnay ban dc bn', 'hom nay ban duoc bao nhieu'),
      ('lm s để in lại bill z', 'làm sao để in lại bill vậy'),
      ('tuần trc có bn đơn', 'tuần trước có bao nhiêu đơn'),
      ('giá 25 k ko đổi', 'giá 25 k không đổi'),
      ('k in đc bill', 'khong in duoc bill'),
      ('bn ơi giúp mình', 'bn ơi giúp mình'),
      // QC đợt 13
      ('cho bn hỏi cách in lại bill', 'cho bn hỏi cách in lại bill'),
      ('ly size R còn mấy cái', 'ly size R còn mấy cái'),
      ('hôm nay vắng wa', 'hôm nay vắng quá'),
      ('hôm wa bán được nhiêu', 'hôm qua bán được nhiêu'),
      ('giảm ck 10% cho khách', 'giảm ck 10% cho khách'),
      ('dt hom nay bn 😅', 'dt hom nay bao nhieu 😅'),
      ('mấy trăm k một ly', 'mấy trăm k một ly'),
      ('hum qua nv nào nghỉ v', 'hôm qua nv nào nghỉ vậy'),
      (
        'ck với tm hnay mỗi loại nhiu',
        'chuyển khoản với tm hôm nay mỗi loại nhiêu',
      ),
    ]) {
      expect(boomNormalizeTeen(q), want, reason: q);
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
      expect(
        boomModuleTopics('Bé Lan tháng này làm tổng bao nhiêu giờ rồi'),
        contains(BoomModule.nhanSu),
      );
      // bộ F, G 27/10
      for (final (q, m) in [
        ('trân châu đen còn bao nhiêu', BoomModule.kho),
        ('còn mấy chai siro đào', BoomModule.kho),
        ('trân châu còn bao nhiêu vậy', BoomModule.kho),
        ('giờ ai đang vào ca vậy', BoomModule.nhanSu),
        ('tháng 9 trả lương cho Tuấn bao nhiêu', BoomModule.nhanSu),
        ('tháng này bé Hân làm được bao nhiêu giờ', BoomModule.nhanSu),
        ('tháng này chi những khoản gì, tổng bao nhiêu', BoomModule.finance),
        ('lợi nhuận 30 ngày qua', BoomModule.finance),
      ]) {
        expect(boomModuleTopics(q), contains(m), reason: q);
      }
      for (final q in [
        'sao lợi nhuận bên báo cáo với bên sổ thu chi nó lệch nhau hoài vậy',
        'tiền điện tháng 10 hết 2 triệu 3, ghi vô đâu',
        'gói còn bao nhiêu',
        'hạn mức boom còn bao nhiêu',
        'lãi lỗ tính như thế nào',
        'lương nhân viên tháng 13 có bắt buộc không',
        'vào ca lúc nào thì tính đi trễ',
        'ca tối có mấy người là đủ',
        'con nhieu ngay nua het han goi',
        'nên trả lương nhân viên bao nhiêu',
        'khách ghé nhiều thì tặng gì cho họ quay lại',
        'ca sáng nên có mấy người phục vụ',
        'tuần trước quên chấm công mấy ngày thì sửa sao',
      ]) {
        expect(boomModuleTopics(q), isEmpty, reason: q);
      }
    },
  );
}
