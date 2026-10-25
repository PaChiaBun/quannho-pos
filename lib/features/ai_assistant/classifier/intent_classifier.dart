import '../help/help_search.dart' show foldVietnamese;

// lib/features/ai_assistant/classifier/intent_classifier.dart
// ─────────────────────────────────────────────────────────────────────────────
// Intent Classifier V1 — Phân loại ý định bằng Rules & Semantic Pattern Matching
// ─────────────────────────────────────────────────────────────────────────────

enum BoomDomain {
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
  final BoomDomain domain;
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
      'hơn tháng trước',
      'kém tháng trước',
      'hơn tuần trước',
      'kém tuần trước',
      '2 ngày',
    ])) {
      final timeRange = _comparisonRange(lower);
      return ClassificationResult(
        domain: BoomDomain.sales,
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
        domain: BoomDomain.sales,
        intent: 'top_products',
        confidence: 0.95,
        entities: {'limit': 5, 'time_range': _extractTimeRange(lower)},
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
        domain: BoomDomain.sales,
        intent: 'slow_products',
        confidence: 0.94,
        entities: {'limit': 10, 'time_range': _extractTimeRange(lower)},
        requiresLiveData: true,
        tool: 'get_slow_products',
      );
    }

    // 4. Intent: revenue_summary
    if (_matchesKeywords(lower, [
      'doanh thu',
      'doanh số',
      'bán được bao nhiêu',
      'thu được bao nhiêu',
      'thu bao nhiêu',
      'bán dc bao nhiêu',
      'tiền bán',
      'tổng tiền bán',
      'hôm nay bán sao',
      'doanh so hom nay',
      'tiền hôm nay',
      'bán hàng hôm nay',
    ])) {
      final timeRange = _extractTimeRange(lower);
      return ClassificationResult(
        domain: BoomDomain.sales,
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
        domain: BoomDomain.inventory,
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
        domain: BoomDomain.inventory,
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
        domain: BoomDomain.finance,
        intent: 'finance_summary',
        confidence: 0.92,
        entities: {'month': DateTime.now().month, 'year': DateTime.now().year},
        requiresLiveData: true,
        tool: 'get_finance_summary',
      );
    }

    // 8. Intent: staff_on_shift
    if (_matchesKeywords(lower, [
      // Không dùng "nhân viên" / "ca làm" trần — "nhân viên đánh bài trong giờ làm xử lý sao" là xin tư vấn
      'ai đang làm',
      'ai đi ca',
      'danh sách ca',
      'ai trực',
      'ai làm ca',
      'đi ca',
      'nhân viên nào đang',
      'nhân viên đang làm',
      'đang trong ca',
      'ai trong ca',
    ])) {
      return ClassificationResult(
        domain: BoomDomain.staff,
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
        domain: BoomDomain.operations,
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
        domain: BoomDomain.help,
        intent: 'app_help',
        confidence: 0.90,
        entities: {},
        requiresLiveData: false,
        tool: null,
      );
    }

    // 11. Intent: smalltalk — so khớp NGUYÊN TỪ ("hi" không được khớp vào "chi", "ghi", "phiếu")
    if (_matchesWords(lower, [
      'chào',
      'hello',
      'hi',
      'bạn là ai',
      'boom là ai',
      'boom là ai',
      'bạn tên gì',
      'cảm ơn',
      'tkx',
      'thank',
    ])) {
      return ClassificationResult(
        domain: BoomDomain.general,
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
        domain: BoomDomain.sales,
        intent: 'revenue_summary',
        confidence: 0.70,
        entities: {'time_range': _extractTimeRange(lower)},
        requiresLiveData: true,
        tool: 'get_today_sales_summary',
        needsClarification: true,
      );
    }

    return _unknownResult();
  }

  static bool _matchesWords(String text, List<String> phrases) {
    final padded =
        ' ${text.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim()} ';
    return phrases.any((p) => padded.contains(' $p '));
  }

  static final _viMark = RegExp(
    r'[àáảãạăắằẳẵặâấầẩẫậèéẻẽẹêếềểễệìíỉĩịòóỏõọôốồổỗộơớờởỡợùúủũụưứừửữựỳýỷỹỵđ]',
  );

  /// Từ khoá chỉ khớp khi gõ CÓ DẤU — bỏ dấu trùng chữ thường gặp khác ("dat hang" = "đặt hàng", "tien loi" =
  /// "tiện lợi", "tien ban" = "tiền bàn").
  static const _accentOnly = {
    'đắt hàng',
    'tiền lời',
    'tiền lỗ',
    'tiền bán',
    'bán ế',
    'món ế',
    'ế nhất',
    'ế ẩm',
    'gần hết',
  };

  /// Khớp cả khi gõ KHÔNG DẤU ("mon nao ban chay nhat" = "món nào bán chạy nhất"), so NGUYÊN TỪ và chỉ trên các từ
  /// gõ không dấu (từ có dấu giữ nghĩa riêng: "đặt hàng" không thành "đắt hàng", "rẻ nhất" không chứa "ẻ nhất").
  static bool _matchesKeywords(String text, List<String> keywords) {
    final folded = text
        .split(RegExp(r'\s+'))
        .map((w) => _viMark.hasMatch(w) ? 'qqq' : w)
        .join(' ');
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
      if (_accentOnly.contains(kw)) continue;
      final k = foldVietnamese(kw);
      if (k.isNotEmpty && _matchesWords(folded, [k])) return true;
    }
    return false;
  }

  /// Khoảng thời gian trong câu (so NGUYÊN CỤM, có dấu hoặc không dấu): "hôm qua", "tuần này / trước",
  /// "tháng này / trước"; không có → hôm nay. (Trước đây chữ "qua" bất kỳ — "quay", "quà" — bị hiểu là hôm qua.)
  /// Khoảng thời gian trong câu; không nhắc thời gian → hôm nay. Nguyên tắc (QC 3 vòng 24/10): chỉ trả số khi CHẮC kỳ
  /// nào; câu có nhắc thời gian mà Boom chưa đọc được ("ngày 20/10", "năm 2025", "cuối tuần", "buổi sáng", "tháng 5",
  /// "tuần trước nữa"…) → 'unsupported' (Boom nói chưa xem được) — không lặng lẽ trả số hôm nay.
  /// Kỳ nhắc trong câu (null = không nhắc) — Boom dùng cho câu so sánh chi nhánh (mặc định tháng này).
  static String? timeRangeIn(String text, {DateTime? now}) =>
      _findTimeRange(text.toLowerCase(), now: now);

  static String _extractTimeRange(String text, {DateTime? now}) =>
      _findTimeRange(text, now: now) ?? 'today';

  // Các kỳ Boom đọc được (so trên chữ BỎ DẤU, nguyên cụm). Thứ tự: kỳ hiện tại trước kỳ trước
  // ("hôm nay so với hôm qua" = hôm nay).
  static final _periods = <(String, RegExp)>[
    (
      'today',
      RegExp(
        r'\b(?:(?:ngay )?hom nay|hnay|bua nay|sang nay|trua nay|chieu nay|toi nay)\b',
      ),
    ),
    (
      'this_month',
      RegExp(
        r'\b(?:(?:thang|thg) nay|(?:trong|ca|tu dau) (?:thang|thg)(?! (?:truoc|roi|qua|nua|\d)))\b',
      ),
    ),
    (
      'this_week',
      RegExp(r'\b(?:tuan nay|(?:trong|ca) tuan(?! (?:truoc|roi|qua|nua)))\b'),
    ),
    (
      'yesterday',
      RegExp(
        r'\b(?:(?:ngay )?hom qua|hqua|hum qua|hom wa|bua qua|toi qua|dem qua|sang qua|trua qua|chieu qua)\b',
      ),
    ),
    ('last_month', RegExp(r'\b(?:thang|thg) (?:truoc|roi|qua)\b(?! nua)')),
    ('last_week', RegExp(r'\btuan (?:truoc|roi|qua)\b(?! nua)')),
  ];
  // Từ chỉ thời gian CÓ DẤU còn sót (kỳ khác / chi tiết hơn): một từ, hoặc từ + từ sau.
  static const _hintWords = {
    'ngày',
    'tuần',
    'tháng',
    'thg',
    'hôm',
    'bữa',
    'đêm',
    'chiều',
    'trưa',
    'sáng', //
    'quý', 'dạo', 'đầu', 'cuối', 'hqua', 'hnay',
  };
  static const _hintPairs = {
    'năm': {'nay', 'ngoái', 'trước', 'rồi', 'qua', 'kia'},
    'thứ': {'hai', 'ba', 'tư', 'năm', 'sáu', 'bảy'},
    'chủ': {'nhật'},
    'tối': {'qua', 'nay', 'hôm', 'thứ', 'chủ', 'mai'},
  };

  /// null = câu không nhắc thời gian.
  static String? _findTimeRange(String text, {DateTime? now}) {
    final n = now ?? DateTime.now();
    // Ngày / năm cụ thể ("20/10", "10/2025", "năm 2025", "ngày 20") → chưa đọc được
    if (RegExp(r'\d+\s*/\s*\d+|\b(?:19|20)\d{2}\b').hasMatch(text)) {
      return 'unsupported';
    }
    final raw = text
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((w) => w.isNotEmpty)
        .toList();
    final folded = [for (final w in raw) foldVietnamese(w)];
    final f = folded.join(' ');
    // "ngày 20", "T10", "1 tuần qua", "7 ngày", "mấy hôm nay", "thứ 7" → chưa đọc được
    if (RegExp(
      r'\bngay \d|\bt\d{1,2}\b|\b\d+ (?:ngay|tuan|thang|hom|bua)\b|\bmay (?:hom|bua|ngay|tuan)\b|\bthu \d',
    ).hasMatch(f)) {
      return 'unsupported';
    }
    final month = RegExp(r'\b(?:thang|thg)\s*(\d{1,2})\b').firstMatch(f);
    if (month != null) {
      if (RegExp(r'\bnam\b(?! nay)').hasMatch(f)) return 'unsupported';
      final m = int.parse(month.group(1)!);
      final last = n.month == 1 ? 12 : n.month - 1;
      if (m == n.month) return 'this_month';
      if (m == last) return 'last_month';
      return 'unsupported';
    }
    // Đánh dấu các từ thuộc kỳ đã nhận ra
    final starts = <int>[];
    var pos = 0;
    for (final w in folded) {
      starts.add(pos);
      pos += w.length + 1;
    }
    final used = List<bool>.filled(raw.length, false);
    String? found;
    for (final (name, rx) in _periods) {
      for (final m in rx.allMatches(f)) {
        found ??= name;
        for (var i = 0; i < raw.length; i++) {
          if (starts[i] >= m.start && starts[i] < m.end) used[i] = true;
        }
      }
    }
    // Còn từ chỉ thời gian khác → chưa đọc được (không trả nhầm kỳ)
    for (var i = 0; i < raw.length; i++) {
      if (used[i]) continue;
      final w = raw[i];
      final next = i + 1 < raw.length ? raw[i + 1] : '';
      if (_hintWords.contains(w) ||
          (_hintPairs[w]?.contains(next) ?? false) ||
          const {'tuan', 'thang', 'thg', 'hqua', 'hnay'}.contains(folded[i])) {
        return 'unsupported';
      }
    }
    return found;
  }

  /// Câu so sánh: kỳ đứng TRƯỚC "so với / hơn / kém" là kỳ được hỏi; chỉ nói kỳ trước ("doanh thu so với hôm qua")
  /// → hỏi kỳ hiện tại so với kỳ đó.
  static String _comparisonRange(String text) {
    final cut = RegExp(
      r'\b(so với|so voi|hơn|hon|kém|kem)\b',
      unicode: true,
    ).firstMatch(text);
    final before = cut == null ? text : text.substring(0, cut.start);
    final asked = _findTimeRange(before);
    if (asked != null) return asked;
    return switch (_findTimeRange(text)) {
      'yesterday' || null => 'today',
      'last_week' => 'this_week',
      'last_month' => 'this_month',
      final other => other,
    };
  }

  static ClassificationResult _unknownResult() {
    return ClassificationResult(
      domain: BoomDomain.general,
      intent: 'unknown',
      confidence: 0.40,
      entities: {},
      requiresLiveData: false,
      tool: null,
    );
  }
}
