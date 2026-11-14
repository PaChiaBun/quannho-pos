import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/classifier/intent_classifier.dart';

// ĐO KỲ (tạm, không commit): kỳ Boom hiểu so với kỳ người viết bộ câu ghi.
void main() {
  test('đo kỳ', () async {
    final now = DateTime(2026, 10, 27, 15);
    final out = File(Platform.environment['KET_QUA']!).openWrite();
    final cases = (jsonDecode(File(Platform.environment['BO_CAU']!).readAsStringSync()) as Map)['cases'] as List;
    for (final c in cases) {
      final q = c['q'] as String;
      out.writeln(jsonEncode({'q': q, 'loai': c['loai'], 'ky': c['ky'], 'boom': IntentClassifier.timeRangeIn(q, now: now)}));
    }
    await out.close();
  });
}
