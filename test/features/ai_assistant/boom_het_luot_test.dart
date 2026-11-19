// Máy chủ trả 429 (hết lượt) → app nói rõ lý do, không báo "chưa đọc được số liệu" (lỗi thật 09/11).
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/services/boom_ai_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('nhận mã hết lượt từ lỗi 429', () {
    expect(
      BoomAiService.limitOf(
        const FunctionException(
          status: 429,
          details: {'error': 'RATE_LIMITED'},
        ),
      ),
      'RATE_LIMITED',
    );
    expect(
      BoomAiService.limitOf(
        const FunctionException(
          status: 429,
          details: {'error': 'BUDGET_EXCEEDED'},
        ),
      ),
      'BUDGET_EXCEEDED',
    );
    expect(
      BoomAiService.limitOf(const FunctionException(status: 429, details: 'x')),
      'RATE_LIMITED',
    );
    // máy chủ nói rõ trần bị chạm: tháng của quán / của cả hệ thống → "tháng sau"; trần ngày → như cũ
    for (final (scope, ma) in [
      ('month', 'BUDGET_MONTH'),
      ('system', 'BUDGET_MONTH'),
      ('day', 'BUDGET_EXCEEDED'),
    ]) {
      expect(
        BoomAiService.limitOf(
          FunctionException(
            status: 429,
            details: {'error': 'BUDGET_EXCEEDED', 'scope': scope},
          ),
        ),
        ma,
      );
    }
    expect(
      BoomAiService.limitOf(
        const FunctionException(status: 503, details: {'error': 'AI_DISABLED'}),
      ),
      isNull,
    );
    expect(BoomAiService.limitOf(Exception('mạng')), isNull);
  });

  test('câu báo hết lượt', () {
    expect(
      boomLimitText('RATE_LIMITED', 'Anh An'),
      contains('hỏi lại sau ít phút'),
    );
    expect(boomLimitText('BUDGET_EXCEEDED', 'Anh An'), contains('ngày mai'));
    expect(
      boomLimitText('BUDGET_MONTH', 'Anh An'),
      allOf(contains('Tháng này'), contains('đầu tháng sau')),
    );
    expect(boomLimitText(null, 'Anh An'), isNull);
  });
}
