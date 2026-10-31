import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/boom_xung_ho.dart';
import 'package:quannho_pos/features/ai_assistant/providers/boom_chat_provider.dart';

// Xưng hô tuỳ chọn (26/10): danh sách cố định, câu nhắn tự nhiên.
void main() {
  test('nhận câu đổi cách gọi tự nhiên', () {
    const cases = {
      'Gọi chế xưng bé': 'che',
      'Gọi tôi là Anh': 'anh',
      'gọi tôi là chị': 'chi',
      'Boom ơi, từ giờ gọi tôi là cô nhé': 'co',
      'kêu tui là chú đi': 'chu',
      'gọi em là cô Lan nha': 'co',
      'Bé Boom ơi gọi mình là bác': 'bac',
      'gọi tôi là thầy': 'thay',
      'gọi tôi bằng em': 'em',
      'gọi chế, xưng bé nhé': 'che',
    };
    cases.forEach((q, code) => expect(parseXungHoCommand(q), code, reason: q));
  });

  test('câu hỏi bình thường có chữ "gọi" không bị nhận nhầm', () {
    for (final q in [
      'gọi món cho bàn 3 thế nào',
      'khách gọi món qua QR ở đâu',
      'gọi anh quản lý vào ca',
      'gọi tôi là gì cũng được',
      'gọi tôi là bạn',
      'gọi anh Giang ơi doanh thu hôm nay',
      'làm sao gọi tôi là anh trong hoá đơn',
      // QC 26/10: gọi NGƯỜI KHÁC, không phải đổi cách gọi
      'gọi anh Tuấn',
      'gọi anh ấy',
      'gọi anh tới',
      'gọi anh lên',
      'gọi chị bếp',
      'gọi chị dậy',
      'gọi bà chủ',
      'gọi bà ngoại',
      'gọi ông chủ',
      'kêu anh shipper',
      'gọi anh shipper đi',
      'kêu em ơi',
      'gọi em ra',
      'gọi em đi',
      'gọi nhân viên',
      'khách gọi thêm',
      'gọi bếp',
      'gọi chị thu ngân',
      'gọi em phục vụ',
      'gọi tôi là sếp',
    ]) {
      expect(parseXungHoCommand(q), isNull, reason: q);
    }
  });

  test('cách gọi hiện đúng chữ; mã lạ → Anh/Chị', () {
    expect(boomGoiNguoiDung('che', 'Nguyễn Thị Giang'), 'Chế Giang');
    expect(boomGoiNguoiDung('co', 'Lan'), 'Cô Lan');
    expect(boomGoiNguoiDung('xyz', 'An'), 'Anh/Chị An');
    expect(kBoomDanhXung.length, 11);
  });
}
