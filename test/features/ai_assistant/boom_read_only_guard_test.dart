import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Boom business data gateway remains strictly read-only', () {
    // Cả cổng số liệu bán hàng lẫn cổng số các module (thu chi, kho, nhân sự, khách, khuyến mãi — 25/10)
    final source = [
      'lib/features/ai_assistant/services/boom_read_only_data_service.dart',
      'lib/features/ai_assistant/services/boom_module_data_service.dart',
    ].map((f) => File(f).readAsStringSync()).join('\n');

    expect(source, contains('.select('));
    for (final forbiddenCall in const [
      '.insert(',
      '.update(',
      '.delete(',
      '.upsert(',
      '.rpc(',
      '.storage.',
    ]) {
      expect(
        source,
        isNot(contains(forbiddenCall)),
        reason: 'AI Boom must not expose $forbiddenCall',
      );
    }
  });
}
