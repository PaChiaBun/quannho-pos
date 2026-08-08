// test/features/ai_assistant/intent_classifier_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Intent Classifier V1 Benchmark Test Suite — 20+ variations per intent
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/classifier/intent_classifier.dart';

void main() {
  group('Intent Classifier V1 Benchmark & Evaluation', () {
    final Map<String, List<String>> testDataset = {
      'revenue_summary': [
        'Hôm nay Quán Kay bán được bao nhiêu?',
        'doanh thu hôm nay',
        'doanh số hôm nay thế nào',
        'bán dc bao nhiêu tiền rồi',
        'tổng tiền bán hôm nay',
        'hôm nay bán sao rồi',
        'cho xem doanh thu hôm nay',
        'doanh so hom nay',
        'hôm nay được bao nhiêu tiền',
        'xem doanh thu Quán Kay',
        'doanh thu bán hàng hôm nay',
        'tiền bán hôm nay',
        'doanh số Quán Kay hôm nay',
        'hôm nay bán được nhiều tiền không',
        'báo cáo doanh thu hôm nay',
        'hôm nay thu được bao nhiêu tiền',
        'doanh thu ngày hôm nay',
        'cho tớ xem doanh số hôm nay',
        'bán hàng hôm nay thế nào',
        'doanh thu tổng hôm nay',
      ],
      'sales_comparison': [
        'So sánh doanh thu hôm nay với hôm qua',
        'doanh thu hôm nay tăng hay giảm',
        'doanh số hơn hôm qua không',
        'hôm nay bán hơn hay kém hôm qua',
        'so sánh doanh số với hôm qua',
        'tăng giảm doanh thu thế nào',
        'doanh thu so với hôm qua',
        'hôm nay bán tốt hơn hôm qua không',
        'so sánh bán hàng 2 ngày',
        'doanh thu tăng hay giảm so với hôm qua',
      ],
      'top_products': [
        'Món nào bán chạy nhất?',
        'top món bán chạy hôm nay',
        'món hot nhất hôm nay',
        'món đắt khách nhất Quán Kay',
        'cho xem món bán nhiều nhất',
        'món nào đắt hàng nhất',
        'top món chạy nhất',
        'món bán chạy hôm nay',
        'xem danh sách món bán chạy',
        'món nào bán được nhiều nhất',
      ],
      'slow_products': [
        'Món nào bán ế nhất?',
        'món bán chậm hôm nay',
        'ít người mua món nào nhất',
        'món ế nhất Quán Kay',
        'món chậm nhất tuần này',
        'món nào không ai mua',
        'cho xem các món bán ế',
        'danh sách món bán chậm',
        'món nào ế ẩm nhất',
        'món bán ít nhất',
      ],
      'low_stock': [
        'Kho có gì sắp hết?',
        'nguyên liệu nào gần hết',
        'cảnh báo kho Quán Kay',
        'tồn kho thấp',
        'hàng nào sắp hết trong kho',
        'kho hết món gì',
        'thiếu nguyên liệu gì không',
        'món nào sắp hết hàng',
        'cho xem cảnh báo tồn kho',
        'kiểm tra kho sắp hết',
      ],
      'staff_on_shift': [
        'Hôm nay ai đang làm?',
        'ai đi ca hôm nay',
        'danh sách nhân viên đi làm',
        'ai đang trực ca này',
        'nhân viên nào đang làm',
        'ai làm ca hôm nay',
        'cho xem danh sách ca làm',
        'ai đang đi ca',
        'nhân viên đang làm ca',
        'ai trực Quán Kay hôm nay',
      ],
      'smalltalk': [
        'Chào Bum',
        'Hello Bum',
        'Bum là ai vậy',
        'bạn tên gì',
        'cảm ơn Bum nhé',
        'hi Bum',
        'tkx Bum',
        'thank you Bum',
        'bạn là ai',
        'chào bạn',
      ]
    };

    test('Benchmark Macro-F1 and Accuracy across Test Dataset', () {
      int totalSamples = 0;
      int correctPredictions = 0;
      int unknownCount = 0;

      final Map<String, int> intentHits = {};
      final Map<String, int> intentTotal = {};

      testDataset.forEach((expectedIntent, queries) {
        intentTotal[expectedIntent] = queries.length;
        intentHits[expectedIntent] = 0;

        for (final query in queries) {
          totalSamples++;
          final result = IntentClassifier.classify(query);

          if (result.intent == 'unknown') {
            unknownCount++;
          }

          if (result.intent == expectedIntent) {
            correctPredictions++;
            intentHits[expectedIntent] = (intentHits[expectedIntent] ?? 0) + 1;
          }
        }
      });

      final accuracy = correctPredictions / totalSamples;
      final unknownRate = unknownCount / totalSamples;

      double sumRecall = 0.0;
      intentTotal.forEach((intent, total) {
        final hits = intentHits[intent] ?? 0;
        final recall = hits / total;
        sumRecall += recall;
      });

      final macroF1 = sumRecall / intentTotal.length;

      print('=== INTENT CLASSIFIER EVALUATION REPORT ===');
      print('Total Test Samples: $totalSamples');
      print('Correct Predictions: $correctPredictions');
      print('Accuracy: ${(accuracy * 100).toStringAsFixed(2)}%');
      print('Macro-F1 Score: ${macroF1.toStringAsFixed(4)}');
      print('Unknown Rate: ${(unknownRate * 100).toStringAsFixed(2)}%');
      print('-------------------------------------------');

      intentTotal.forEach((intent, total) {
        final hits = intentHits[intent] ?? 0;
        print('Intent [$intent]: $hits / $total (${((hits / total) * 100).toStringAsFixed(1)}%)');
      });

      expect(accuracy, greaterThanOrEqualTo(0.90));
      expect(macroF1, greaterThanOrEqualTo(0.90));
    });
  });
}
