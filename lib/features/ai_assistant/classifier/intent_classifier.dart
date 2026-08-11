// lib/features/ai_assistant/classifier/intent_classifier.dart
// ─────────────────────────────────────────────────────────────────────────────
// Intent Classifier V1 — Phân loại ý định bằng Rules & Semantic Pattern Matching
// ─────────────────────────────────────────────────────────────────────────────

enum BumDomain {
  sales,
  inventory,
  finance,
  staff,
  operations,
  help,
  advice,
  memory,
  general,
}

class ClassificationResult {
  final BumDomain domain;
  final String intent;
  final double confidence;
  final Map<String, dynamic> entities;
  final bool requiresLiveData;
  final String? tool;
  final bool needsClarification;

  ClassificationResult({
    required this.domain,
    required this.intent,
    required this.confidence,
    required this.entities,
    required this.requiresLiveData,
    this.tool,
    this.needsClarification = false,
  });

  Map<String, dynamic> toJson() => {
    'domain': domain.name,
    'intent': intent,
    'confidence': double.parse(confidence.toStringAsFixed(2)),
    'entities': entities,
    'requires_live_data': requiresLiveData,
    'tool': tool,
    'needs_clarification': needsClarification,
  };
}

class IntentClassifier {
  static const double kHighConfidenceThreshold = 0.85;
  static const double kMediumConfidenceThreshold = 0.65;

  static ClassificationResult classify(String text) {
    final rawText = text.trim();
    if (rawText.isEmpty) {
      return _unknownResult();
    }

    final lower = rawText.toLowerCase();

    // 1. Intent: sales_comparison (Ưu tiên check trước revenue_summary để không bị nuốt câu)
    if (_matchesKeywords(lower, [
      'so sánh',
      'so với',
      'tăng hay giảm',
      'tăng giảm',
      'hơn hôm qua',
      'kém hôm qua',
      'so sánh doanh',
      'hơn hay kém',
      'tốt hơn hôm qua',
      '2 ngày',
    ])) {
      final timeRange = _extractTimeRange(lower);
      return ClassificationResult(
        domain: BumDomain.sales,
        intent: 'sales_comparison',
        confidence: 0.94,
        entities: {'time_range': timeRange, 'compare_to': 'yesterday'},
        requiresLiveData: true,
        tool: 'compare_sales_periods',
      );
    }

    // 2. Intent: top_products
    if (_matchesKeywords(lower, [
      'chạy nhất',
      'bán chạy',
      'món hot',
      'đắt khách',
      'bán nhiều nhất',
      'top món',
      'đắt hàng',
      'danh sách món bán chạy',
    ])) {
      return ClassificationResult(
        domain: BumDomain.sales,
        intent: 'top_products',
        confidence: 0.95,
        entities: {'limit': 5, 'time_range': 'today'},
        requiresLiveData: true,
        tool: 'get_top_products',
      );
    }

    // 3. Intent: slow_products
    if (_matchesKeywords(lower, [
      'bán ế',
      'bán chậm',
      'ít người mua',
      'ế nhất',
      'chậm nhất',
      'món ế',
      'không ai mua',
      'ế ẩm',
      'bán ít nhất',
    ])) {
      return ClassificationResult(
        domain: BumDomain.sales,
        intent: 'slow_products',
        confidence: 0.94,
        entities: {'limit': 10, 'time_range': '7_days'},
        requiresLiveData: true,
        tool: 'get_slow_products',
      );
    }

    // 4. Intent: revenue_summary
    if (_matchesKeywords(lower, [
      'doanh thu',
      'doanh số',
      'bán được bao nhiêu',
      'bán dc bao nhiêu',
      'tiền bán',
      'tổng tiền bán',
      'hôm nay bán sao',
      'doanh so hom nay',
      'bao nhiêu tiền',
      'tiền hôm nay',
      'bán hàng hôm nay',
    ])) {
      final timeRange = _extractTimeRange(lower);
      return ClassificationResult(
        domain: BumDomain.sales,
        intent: 'revenue_summary',
        confidence: 0.95,
        entities: {'time_range': timeRange},
        requiresLiveData: true,
        tool: 'get_today_sales_summary',
      );
    }

    // 5. Intent: low_stock
    if (_matchesKeywords(lower, [
      'sắp hết',
      'kho hết',
      'hết hàng',
      'cảnh báo kho',
      'tồn kho thấp',
      'thiếu nguyên liệu',
      'gần hết',
      'tồn kho',
    ])) {
      return ClassificationResult(
        domain: BumDomain.inventory,
        intent: 'low_stock',
        confidence: 0.93,
        entities: {},
        requiresLiveData: true,
        tool: 'get_low_stock_items',
      );
    }

    // 6. Intent: purchase_forecast
    if (_matchesKeywords(lower, [
      'dự báo kho',
      'nhập thêm',
      'cần mua thêm',
      'dự trù nguyên liệu',
      'dự báo mua hàng',
    ])) {
      return ClassificationResult(
        domain: BumDomain.inventory,
        intent: 'purchase_forecast',
        confidence: 0.91,
        entities: {'days': 7},
        requiresLiveData: true,
        tool: 'get_stock_forecast_inputs',
      );
    }

    // 7. Intent: finance_summary
    if (_matchesKeywords(lower, [
      'thu chi',
      'lợi nhuận',
      'tiền lời',
      'tiền lỗ',
      'tổng chi',
      'tổng thu',
      'lời bao nhiêu',
    ])) {
      return ClassificationResult(
        domain: BumDomain.finance,
        intent: 'finance_summary',
        confidence: 0.92,
        entities: {'month': DateTime.now().month, 'year': DateTime.now().year},
        requiresLiveData: true,
        tool: 'get_finance_summary',
      );
    }

    // 8. Intent: staff_on_shift
    if (_matchesKeywords(lower, [
      'ai đang làm',
      'ai đi ca',
      'nhân viên',
      'danh sách ca',
      'ai trực',
      'ai làm ca',
      'ca làm',
      'đi ca',
      'đi làm',
    ])) {
      return ClassificationResult(
        domain: BumDomain.staff,
        intent: 'staff_on_shift',
        confidence: 0.94,
        entities: {'time_range': 'current_shift'},
        requiresLiveData: true,
        tool: 'get_staff_on_shift',
      );
    }

    // 9. Intent: pending_tasks
    if (_matchesKeywords(lower, [
      'hủy món',
      'hủy đơn',
      'cảnh báo vận hành',
      'vi phạm',
      'bất thường',
    ])) {
      return ClassificationResult(
        domain: BumDomain.operations,
        intent: 'pending_tasks',
        confidence: 0.89,
        entities: {},
        requiresLiveData: true,
        tool: 'get_pending_operations_tasks',
      );
    }

    // 10. Intent: app_help
    if (_matchesKeywords(lower, [
      'hướng dẫn',
      'dùng thế nào',
      'cách làm',
      'làm sao để',
      'chỉ tớ cách',
      'giúp tớ với',
    ])) {
      return ClassificationResult(
        domain: BumDomain.help,
        intent: 'app_help',
        confidence: 0.90,
        entities: {},
        requiresLiveData: false,
        tool: null,
      );
    }

    // 11. Intent: smalltalk
    if (_matchesKeywords(lower, [
      'chào',
      'hello',
      'hi',
      'bạn là ai',
      'bum là ai',
      'bạn tên gì',
      'cảm ơn',
      'tkx',
      'thank',
    ])) {
      return ClassificationResult(
        domain: BumDomain.general,
        intent: 'smalltalk',
        confidence: 0.97,
        entities: {},
        requiresLiveData: false,
        tool: null,
      );
    }

    // Secondary Fuzzy Matcher
    if (lower.contains('doanh') || lower.contains('bán')) {
      return ClassificationResult(
        domain: BumDomain.sales,
        intent: 'revenue_summary',
        confidence: 0.70,
        entities: {'time_range': 'today'},
        requiresLiveData: true,
        tool: 'get_today_sales_summary',
        needsClarification: true,
      );
    }

    return _unknownResult();
  }

  static bool _matchesKeywords(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  static String _extractTimeRange(String text) {
    if (text.contains('hôm qua') || text.contains('qua')) return 'yesterday';
    if (text.contains('tháng này')) return 'this_month';
    if (text.contains('tháng trước')) return 'last_month';
    if (text.contains('tuần này')) return 'this_week';
    return 'today';
  }

  static ClassificationResult _unknownResult() {
    return ClassificationResult(
      domain: BumDomain.general,
      intent: 'unknown',
      confidence: 0.40,
      entities: {},
      requiresLiveData: false,
      tool: null,
    );
  }
}
