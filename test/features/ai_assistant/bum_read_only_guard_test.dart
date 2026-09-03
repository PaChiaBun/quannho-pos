import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI Bum business data gateway remains strictly read-only', () {
    final source = File(
      'lib/features/ai_assistant/services/bum_read_only_data_service.dart',
    ).readAsStringSync();

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
        reason: 'AI Bum must not expose $forbiddenCall',
      );
    }
  });
}
