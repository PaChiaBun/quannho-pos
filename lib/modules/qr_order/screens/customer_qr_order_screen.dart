import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/cart_animation_helper.dart';
import '../models/qr_order_model.dart';
import '../repository/qr_order_repository.dart';

// Bảng màu dùng chung với màn Bán hàng của POS.
const _kNavy = Color(0xFF1E1C5E);
const _kNavyLight = Color(0xFF2D2B8A);
const _kOrange = Color(0xFFE85D20);
const _kInk = Color(0xFF1A1207);
const _kMuted = Color(0xFF9E9085);
const _kCream = Color(0xFFFAF7F2);
const _kBorder = Color(0xFFE0D8CC);
const _kNavyTint = Color(0xFFF0EEF8);
const _kNavyLine = Color(0xFFD9D6EE);

/// Trang lỗi thân thiện cho khách khi link gọi món thiếu/sai mã.
class CustomerQrInvalidLinkScreen extends StatelessWidget {
  const CustomerQrInvalidLinkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Quán Nhỏ',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
        ),
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_2_rounded,
                size: 56,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 14),
              Text(
                'Liên kết gọi món không hợp lệ',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vui lòng quét lại mã QR trên bàn hoặc tại quầy, '
                'hoặc hỏi nhân viên để được hỗ trợ.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Màn hình Khách Hàng tự gọi món qua QR (Web / Mobile-first).
/// TABLE_SHARED: khách chọn bàn từ danh sách của quán. COUNTER_TAKEAWAY: nhận mã lấy món.
/// Sau khi gửi, màn chuyển sang theo dõi trạng thái (polling) và lưu mã theo dõi để reload không mất đơn.
class CustomerQrOrderScreen extends StatefulWidget {
  final String channelCode;

  const CustomerQrOrderScreen({super.key, required this.channelCode});

  /// Hash ổn định: không phụ thuộc thứ tự món/topping trong giỏ.
  static String computeCanonicalPayloadHash({
    required String channelCode,
    String? tableId,
    required List<Map<String, dynamic>> items,
  }) {
    final itemStrs = <String>[];
    for (final item in items) {
      final mods =
          ((item['modifiers_json'] as List?) ?? [])
              .whereType<Map>()
              .map((m) => '${m['id']}:${m['quantity']}')
              .toList()
            ..sort();
      itemStrs.add(
        '[p:${item['product_id']};q:${item['quantity']};n:${item['note'] ?? ""};m:${mods.join(",")}]',
      );
    }
    itemStrs.sort();
    final raw = 'ch:$channelCode|tbl:${tableId ?? ""}|items:${itemStrs.join()}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  @override
  State<CustomerQrOrderScreen> createState() => _CustomerQrOrderScreenState();
}

class _CustomerQrOrderScreenState extends State<CustomerQrOrderScreen> {
  static const _kCounter = 'COUNTER_TAKEAWAY';
  static const _kTable = 'TABLE_SHARED';
  static const _pollInterval = Duration(seconds: 4);
  static const _maxPollFailures = 3;

  final QrOrderRepository _repo = QrOrderRepository();
  final currencyFmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  bool _loading = true;
  String _errorMessage = '';

  String _storeName = 'Quán Nhỏ';
  String _channelType = _kTable;

  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _toppings = [];
  List<Map<String, dynamic>> _toppingLinks = [];
  List<String> _categories = ['Tất cả'];
  String _selectedCategory = 'Tất cả';
  String _searchQuery = '';

  // Bàn (TABLE_SHARED)
  List<Map<String, String>> _tables = []; // {id, name, zone}
  String? _selectedTableId;
  String? _selectedTableName;
  bool _tablePromptShown = false;

  // Cart: item_key -> {product_id, product_name, unit_price, quantity, note, modifiers_json}
  final Map<String, Map<String, dynamic>> _cart = {};

  // Idempotency: gắn với giỏ + bàn đã gửi (chữ ký = payload hash)
  String? _attemptKey;
  String? _attemptSig;
  bool _isSubmitting = false;
  bool _submitUnknown = false; // lỗi mạng: chưa rõ đã gửi hay chưa

  // Theo dõi đơn đã gửi
  String? _trackingToken;
  QrRequestModel? _req;
  double _submittedTotal = 0.0;
  String? _submittedTableName;
  String? _submittedPickupCode;
  Timer? _pollTimer;
  bool _polling = false;
  int _pollFailures = 0;
  bool _connectionLost = false;

  final GlobalKey _cartBarKey = GlobalKey();
  bool _cartPop = false;

  bool get _isCounter => _channelType == _kCounter;

  String get _kToken => 'qr_cust_token_${widget.channelCode}';
  String get _kTableKey => 'qr_cust_table_${widget.channelCode}';

  @override
  void initState() {
    super.initState();
    _restoreSession();
    _loadMenu();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Lưu trữ cục bộ (bọc try/catch: có thể bị chặn ở chế độ riêng tư) ─────────
  Future<String?> _prefGet(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _prefSet(String key, String? value) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (value == null) {
        await p.remove(key);
      } else {
        await p.setString(key, value);
      }
    } catch (_) {}
  }

  Future<void> _restoreSession() async {
    final token = await _prefGet(_kToken);
    if (!mounted || token == null || token.isEmpty || _trackingToken != null) {
      return;
    }
    setState(() => _trackingToken = token);
    _startPolling();
  }

  // ── Lỗi thân thiện ──────────────────────────────────────────────────────────
  String _errText(QrRpcResponse<dynamic> r, String fallback) {
    switch (r.errorCode) {
      case QrErrorCode.networkError:
      case QrErrorCode.rpcError:
        return fallback;
      case 'RATE_LIMITED':
        return 'Bạn thao tác quá nhanh. Vui lòng đợi một lát rồi thử lại.';
      case 'TABLE_REQUIRED':
        return 'Vui lòng chọn bàn trước khi gửi đơn.';
      case 'TABLE_NOT_FOUND':
        return 'Bàn đã chọn không còn hợp lệ. Vui lòng chọn lại bàn.';
      case QrErrorCode.channelDisabled:
        return 'Quán tạm ngưng nhận đơn qua QR. Vui lòng gọi nhân viên.';
      case QrErrorCode.productNotAvailable:
        return 'Có món đã hết hoặc ngừng bán. Vui lòng kiểm tra lại giỏ hàng.';
    }
    final m = r.message?.trim();
    if (m != null &&
        m.isNotEmpty &&
        m.length <= 160 &&
        !m.contains('Exception')) {
      return m;
    }
    return fallback;
  }

  bool _isNetworkFail(QrRpcResponse<dynamic> r) =>
      r.errorCode == QrErrorCode.networkError ||
      r.errorCode == QrErrorCode.rpcError;

  // ── Tải thực đơn ────────────────────────────────────────────────────────────
  static String? _str(dynamic v) {
    if (v is String && v.trim().isNotEmpty) return v;
    return null;
  }

  Future<void> _loadMenu() async {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });
    final res = await _repo.fetchQrMenu(widget.channelCode);
    if (!mounted) return;

    if (res.isSuccess && res.data != null) {
      final data = res.data!;

      // Món lỗi (thiếu id/tên/giá) bị bỏ qua
      final prods = <Map<String, dynamic>>[];
      for (final p in (data['products'] as List?) ?? const []) {
        if (p is! Map) continue;
        if (_str(p['id']) == null ||
            _str(p['name']) == null ||
            p['sell_price'] is! num) {
          continue;
        }
        prods.add(Map<String, dynamic>.from(p));
      }
      final toppings = <Map<String, dynamic>>[];
      for (final t in (data['toppings'] as List?) ?? const []) {
        if (t is! Map) continue;
        if (_str(t['id']) == null ||
            _str(t['name']) == null ||
            t['sell_price'] is! num) {
          continue;
        }
        toppings.add(Map<String, dynamic>.from(t));
      }
      final links = <Map<String, dynamic>>[];
      for (final l in (data['topping_links'] as List?) ?? const []) {
        if (l is! Map) continue;
        if (_str(l['product_id']) == null || _str(l['topping_id']) == null) {
          continue;
        }
        links.add(Map<String, dynamic>.from(l));
      }

      final cats = <String>{'Tất cả'};
      for (final p in prods) {
        final cat = p['category'];
        if (cat is String && cat.trim().isNotEmpty) cats.add(cat.trim());
      }

      final tables = <Map<String, String>>[];
      for (final t in (data['tables'] as List?) ?? const []) {
        if (t is! Map) continue;
        final id = t['id']?.toString();
        final name = _str(t['name']);
        if (id == null || id.isEmpty || name == null) continue;
        final zone = _str(t['zone_name']) ?? 'Khác';
        tables.add({'id': id, 'name': name, 'zone': zone});
      }

      final type = data['channel_type'] as String? ?? _kTable;
      final savedTable = type == _kCounter ? null : await _prefGet(_kTableKey);
      if (!mounted) return;

      setState(() {
        _storeName = _str(data['store_name']) ?? 'Quán Nhỏ';
        _channelType = type == _kCounter ? _kCounter : _kTable;
        _products = prods;
        _toppings = toppings;
        _toppingLinks = links;
        _categories = cats.toList();
        _tables = tables;
        if (_selectedTableId == null && savedTable != null) {
          for (final t in tables) {
            if (t['id'] == savedTable) {
              _selectedTableId = t['id'];
              _selectedTableName = t['name'];
            }
          }
        }
        _loading = false;
      });

      // Bắt buộc chọn bàn: mở sẵn danh sách lần đầu nếu chưa có bàn
      if (!_isCounter &&
          _selectedTableId == null &&
          _tables.isNotEmpty &&
          _trackingToken == null &&
          !_tablePromptShown) {
        _tablePromptShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedTableId == null && _trackingToken == null) {
            _pickTable();
          }
        });
      }
    } else {
      setState(() {
        _errorMessage = _errText(
          res,
          'Không thể tải thực đơn. Vui lòng kiểm tra kết nối và thử lại.',
        );
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getToppingsForProduct(String productId) {
    if (_toppingLinks.isEmpty) return [];
    final linkedIds = _toppingLinks
        .where((l) => l['product_id'] == productId)
        .map((l) => l['topping_id'] as String)
        .toSet();
    if (linkedIds.isEmpty) return [];
    return _toppings.where((t) => linkedIds.contains(t['id'])).toList();
  }

  // ── Chọn bàn ────────────────────────────────────────────────────────────────
  Future<bool> _pickTable() async {
    if (_tables.isEmpty) return false;
    final searchCtrl = TextEditingController();
    String q = '';
    final picked = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final filtered = _tables
                .where((t) => q.isEmpty || t['name']!.toLowerCase().contains(q))
                .toList();
            final zones = <String, List<Map<String, String>>>{};
            for (final t in filtered) {
              zones.putIfAbsent(t['zone']!, () => []).add(t);
            }
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BẠN ĐANG NGỒI BÀN NÀO?',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: _kNavy,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Tìm bàn...',
                      hintStyle: GoogleFonts.outfit(fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) =>
                        setSheet(() => q = v.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Không tìm thấy bàn phù hợp',
                              style: GoogleFonts.outfit(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          )
                        : ListView(
                            children: [
                              for (final e in zones.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 10,
                                    bottom: 6,
                                  ),
                                  child: Text(
                                    e.key.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final t in e.value)
                                      GestureDetector(
                                        onTap: () => Navigator.pop(ctx, t),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 11,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient:
                                                t['id'] == _selectedTableId
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFF1A1860),
                                                      _kNavyLight,
                                                    ],
                                                  )
                                                : null,
                                            color: t['id'] == _selectedTableId
                                                ? null
                                                : _kNavyTint,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: t['id'] == _selectedTableId
                                                ? null
                                                : Border.all(color: _kNavyLine),
                                          ),
                                          child: Text(
                                            t['name']!,
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: t['id'] == _selectedTableId
                                                  ? Colors.white
                                                  : _kInk,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    searchCtrl.dispose();
    if (!mounted || picked == null) return false;
    setState(() {
      _selectedTableId = picked['id'];
      _selectedTableName = picked['name'];
    });
    _prefSet(_kTableKey, picked['id']);
    return true;
  }

  // ── Hiệu ứng bay vào giỏ (dùng chung với màn Bán hàng POS) ───────────────────
  Offset _cartTarget() {
    final box = _cartBarKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.attached) {
      final topLeft = box.localToGlobal(Offset.zero);
      return topLeft + Offset(48, box.size.height / 2);
    }
    final size = MediaQuery.of(context).size;
    return Offset(size.width * 0.2, size.height - 48);
  }

  void _flyToCart(Offset start) {
    HapticFeedback.selectionClick();
    CartAnimationHelper.runFlyAnimation(
      context: context,
      startOffset: start,
      endOffset: _cartTarget(),
      color: _kOrange,
      onComplete: () {
        if (!mounted) return;
        HapticFeedback.lightImpact();
        setState(() => _cartPop = true);
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted) setState(() => _cartPop = false);
        });
      },
    );
  }

  String _plainKey(String pId) => jsonEncode([pId, <dynamic>[], '']);

  /// Món không có topping: bấm là vào giỏ ngay (1 chạm), kèm hiệu ứng bay.
  void _quickAdd(Map<String, dynamic> prod, Offset start) {
    final pId = prod['id'] as String;
    final key = _plainKey(pId);
    setState(() {
      final existing = _cart[key];
      if (existing != null) {
        existing['quantity'] = (existing['quantity'] as int) + 1;
      } else {
        _cart[key] = {
          'product_id': pId,
          'product_name': prod['name'] as String,
          'unit_price': (prod['sell_price'] as num).toDouble(),
          'quantity': 1,
          'note': null,
          'modifiers_json': <Map<String, dynamic>>[],
        };
      }
    });
    _flyToCart(start);
  }

  void _quickRemove(String pId) {
    final key = _plainKey(pId);
    final existing = _cart[key];
    if (existing == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      final q = (existing['quantity'] as int) - 1;
      if (q <= 0) {
        _cart.remove(key);
      } else {
        existing['quantity'] = q;
      }
    });
  }

  // ── Thêm món và chọn Topping ────────────────────────────────────────────────
  void _openProductCustomizerSheet(Map<String, dynamic> prod) {
    final pId = prod['id'] as String;
    final pName = prod['name'] as String;
    final pBasePrice = (prod['sell_price'] as num).toDouble();
    final availableToppings = _getToppingsForProduct(pId);
    int qty = 1;
    final noteCtrl = TextEditingController();
    final Map<String, int> selectedToppings = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            double toppingsTotal = 0;
            for (final t in availableToppings) {
              final tCount = selectedToppings[t['id'] as String] ?? 0;
              toppingsTotal += (t['sell_price'] as num).toDouble() * tCount;
            }
            final singleItemPrice = pBasePrice + toppingsTotal;
            final totalPrice = singleItemPrice * qty;

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            pName,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Text(
                      currencyFmt.format(pBasePrice),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        color: _kNavy,
                        fontSize: 16,
                      ),
                    ),
                    const Divider(height: 24),

                    if (availableToppings.isNotEmpty) ...[
                      Text(
                        'CHỌN TOPPING THÊM',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...availableToppings.map((t) {
                        final tId = t['id'] as String;
                        final tName = t['name'] as String;
                        final tPrice = (t['sell_price'] as num).toDouble();
                        final count = selectedToppings[tId] ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: count > 0
                                  ? _kOrange
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tName,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '+${currencyFmt.format(tPrice)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: _kNavy,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  if (count > 0) ...[
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 22,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setSheetState(() {
                                          if (count > 1) {
                                            selectedToppings[tId] = count - 1;
                                          } else {
                                            selectedToppings.remove(tId);
                                          }
                                        });
                                      },
                                    ),
                                    Text(
                                      '$count',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                  IconButton(
                                    icon: Icon(
                                      Icons.add_circle,
                                      size: 24,
                                      color: _kNavy,
                                    ),
                                    onPressed: () {
                                      setSheetState(() {
                                        selectedToppings[tId] = count + 1;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      controller: noteCtrl,
                      maxLength: 300,
                      decoration: InputDecoration(
                        labelText:
                            'Ghi chú cho món này (VD: ít đá, không đường...)',
                        labelStyle: GoogleFonts.outfit(fontSize: 13),
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                              ),
                              onPressed: () {
                                if (qty > 1) setSheetState(() => qty--);
                              },
                            ),
                            Text(
                              '$qty',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                              ),
                              onPressed: () => setSheetState(() => qty++),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              final modifiersList = <Map<String, dynamic>>[];
                              for (final t in availableToppings) {
                                final tId = t['id'] as String;
                                final tCount = selectedToppings[tId] ?? 0;
                                if (tCount > 0) {
                                  modifiersList.add({
                                    'id': tId,
                                    'type': 'topping',
                                    'name': t['name'],
                                    'price': t['sell_price'],
                                    'quantity': tCount,
                                  });
                                }
                              }
                              final note = noteCtrl.text.trim();
                              // Khóa dòng giỏ: JSON để ký tự lạ trong ghi chú không va chạm
                              final itemKey = jsonEncode([
                                pId,
                                modifiersList
                                    .map((m) => [m['id'], m['quantity']])
                                    .toList(),
                                note,
                              ]);

                              setState(() {
                                final existing = _cart[itemKey];
                                if (existing != null) {
                                  existing['quantity'] =
                                      (existing['quantity'] as int) + qty;
                                } else {
                                  _cart[itemKey] = {
                                    'product_id': pId,
                                    'product_name': pName,
                                    'unit_price': singleItemPrice,
                                    'quantity': qty,
                                    'note': note.isEmpty ? null : note,
                                    'modifiers_json': modifiersList,
                                  };
                                }
                              });

                              Navigator.pop(ctx);
                              final sz = MediaQuery.of(context).size;
                              _flyToCart(
                                Offset(sz.width * 0.65, sz.height - 70),
                              );
                            },
                            child: Text(
                              'Thêm vào giỏ • ${currencyFmt.format(totalPrice)}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(noteCtrl.dispose);
  }

  // ── Giỏ hàng ────────────────────────────────────────────────────────────────
  void _openCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setCartState) {
            final needTable = !_isCounter && _selectedTableId == null;
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GIỎ HÀNG GỌI MÓN',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: _kNavy,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (!_isCounter) ...[
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await _pickTable();
                        setCartState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: needTable ? Colors.orange.shade50 : _kNavyTint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: needTable
                                ? Colors.orange.shade300
                                : _kNavyLine,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.table_restaurant_rounded, color: _kNavy),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                needTable
                                    ? 'Chưa chọn bàn — bấm để chọn bàn của bạn'
                                    : 'Bàn: $_selectedTableName',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _kNavy,
                                ),
                              ),
                            ),
                            if (!needTable)
                              Text(
                                'Đổi',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _kNavy,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_submitUnknown) ...[
                    _buildUnknownBanner(),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Các món đã chọn ($_cartItemCount):',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _cart.length,
                      itemBuilder: (context, idx) {
                        final key = _cart.keys.elementAt(idx);
                        final item = _cart[key]!;
                        final qty = item['quantity'] as int;
                        final price = (item['unit_price'] as double) * qty;
                        final mods = (item['modifiers_json'] as List?) ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: Colors.grey.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['product_name'] as String,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (mods.isNotEmpty)
                                        Text(
                                          '+ ${mods.map((m) => "${m['name']} (x${m['quantity']})").join(", ")}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: _kNavy,
                                          ),
                                        ),
                                      if (item['note'] != null)
                                        Text(
                                          'Ghi chú: ${item['note']}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      Text(
                                        currencyFmt.format(price),
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          color: _kNavy,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline_rounded,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (qty > 1) {
                                            item['quantity'] = qty - 1;
                                          } else {
                                            _cart.remove(key);
                                          }
                                        });
                                        setCartState(() {});
                                        if (_cart.isEmpty) Navigator.pop(ctx);
                                      },
                                    ),
                                    Text(
                                      '$qty',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(
                                          () => item['quantity'] = qty + 1,
                                        );
                                        setCartState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tổng cộng:',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        currencyFmt.format(_cartTotal),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: _kNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        needTable
                            ? Icons.table_restaurant_rounded
                            : Icons.send_rounded,
                      ),
                      label: Text(
                        needTable
                            ? 'CHỌN BÀN ĐỂ GỬI ĐƠN'
                            : (_submitUnknown
                                  ? 'GỬI LẠI ĐƠN HÀNG'
                                  : 'XÁC NHẬN & GỬI ĐƠN HÀNG'),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () async {
                        if (needTable) {
                          await _pickTable();
                          setCartState(() {});
                          return;
                        }
                        Navigator.pop(ctx);
                        _submitOrder();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUnknownBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.orange.shade900, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Chưa rõ đơn đã được gửi hay chưa do mất kết nối. '
              'Bạn có thể bấm gửi lại — hệ thống sẽ không tạo đơn trùng.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _cartTotal {
    double total = 0;
    for (final item in _cart.values) {
      total += (item['unit_price'] as double) * (item['quantity'] as int);
    }
    return total;
  }

  int get _cartItemCount {
    int count = 0;
    for (final item in _cart.values) {
      count += (item['quantity'] as int);
    }
    return count;
  }

  // ── Gửi đơn ─────────────────────────────────────────────────────────────────
  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green.shade700,
      ),
    );
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty || _isSubmitting) return;
    if (!_isCounter && _selectedTableId == null) {
      _snack('Vui lòng chọn bàn trước khi gửi đơn.');
      return;
    }

    final tableId = _isCounter ? null : _selectedTableId;
    final items = _cart.values
        .map(
          (it) => {
            'product_id': it['product_id'],
            'quantity': it['quantity'],
            'modifiers_json': it['modifiers_json'],
            'note': it['note'],
          },
        )
        .toList();

    final payloadHash = CustomerQrOrderScreen.computeCanonicalPayloadHash(
      channelCode: widget.channelCode,
      tableId: tableId,
      items: items,
    );

    // Giữ key khi giỏ+bàn không đổi (kể cả sau lỗi); đổi nội dung → key mới
    if (_attemptKey == null || _attemptSig != payloadHash) {
      _attemptKey = const Uuid().v4();
      _attemptSig = payloadHash;
    }

    setState(() => _isSubmitting = true);

    QrRpcResponse<Map<String, dynamic>> res;
    try {
      res = await _repo.submitQrOrder(
        channelCode: widget.channelCode,
        items: items,
        tableId: tableId,
        idempotencyKey: _attemptKey,
        payloadHash: payloadHash,
      );
    } catch (_) {
      res = QrRpcResponse.error(QrErrorCode.networkError, '');
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final data = res.data;
    if (res.isSuccess && data != null) {
      final token = data['tracking_token'];
      if (token is! String || token.isEmpty) {
        // Server báo thành công nhưng không có mã theo dõi: coi như chưa rõ, thử lại cùng key
        setState(() => _submitUnknown = true);
        _snack(
          'Chưa nhận được xác nhận từ quán. Vui lòng bấm gửi lại hoặc gọi nhân viên.',
        );
        return;
      }
      final total = (data['total_amount'] as num?)?.toDouble() ?? _cartTotal;
      final pickup = _str(data['pickup_code']);
      final tableName = _str(data['table_name']) ?? _selectedTableName;

      setState(() {
        _trackingToken = token;
        _req = null;
        _submittedPickupCode = pickup;
        _submittedTableName = _isCounter ? null : tableName;
        _submittedTotal = total;
        _cart.clear();
        _attemptKey = null;
        _attemptSig = null;
        _submitUnknown = false;
        _connectionLost = false;
      });
      _prefSet(_kToken, token);
      _startPolling();
      return;
    }

    if (_isNetworkFail(res)) {
      // Giữ nguyên key/giỏ để gửi lại không tạo đơn trùng
      setState(() => _submitUnknown = true);
      _snack(
        'Mất kết nối khi gửi đơn. Chưa rõ đơn đã gửi hay chưa — bấm gửi lại để chắc chắn.',
      );
    } else {
      setState(() => _submitUnknown = false);
      _snack(_errText(res, 'Không thể gửi đơn hàng. Vui lòng thử lại!'));
      if (res.errorCode == 'TABLE_REQUIRED' ||
          res.errorCode == 'TABLE_NOT_FOUND') {
        setState(() {
          _selectedTableId = null;
          _selectedTableName = null;
        });
        _prefSet(_kTableKey, null);
      }
    }
  }

  // ── Polling trạng thái ──────────────────────────────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollFailures = 0;
    _connectionLost = false;
    _pollOnce();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  bool _isTerminal(QrRequestModel r) {
    final s = r.status;
    if (s == 'rejected' || s == 'cancelled' || s == 'expired') return true;
    if (s == 'sent_kitchen') {
      return !_orderIsCounter(r) || r.paymentStatus == 'paid';
    }
    return false;
  }

  bool _orderIsCounter(QrRequestModel? r) =>
      _isCounter || (_str(r?.pickupCode) != null);

  Future<void> _pollOnce() async {
    final token = _trackingToken;
    if (token == null || _polling || !mounted) return;
    _polling = true;
    try {
      final res = await _repo.checkRequestStatus(token);
      if (!mounted || token != _trackingToken) return;

      final req = res.data;
      if (res.isSuccess && req != null) {
        setState(() {
          _req = req;
          _pollFailures = 0;
          _connectionLost = false;
          if (req.totalAmount > 0) _submittedTotal = req.totalAmount;
          _submittedTableName = _str(req.tableName) ?? _submittedTableName;
          _submittedPickupCode = _str(req.pickupCode) ?? _submittedPickupCode;
        });
        if (_isTerminal(req)) {
          _stopPolling();
          _prefSet(_kToken, null);
        }
      } else if (res.errorCode == QrErrorCode.invalidState ||
          res.errorCode == QrErrorCode.invalidQr) {
        // Mã theo dõi không còn tồn tại: quay lại menu
        _resetOrder();
        _snack('Không tìm thấy đơn đã gửi trước đó. Bạn có thể đặt đơn mới.');
      } else {
        _registerPollFailure();
      }
    } catch (_) {
      if (mounted) _registerPollFailure();
    } finally {
      _polling = false;
    }
  }

  void _registerPollFailure() {
    _pollFailures++;
    if (_pollFailures >= _maxPollFailures && !_connectionLost) {
      setState(() => _connectionLost = true);
    }
  }

  void _resetOrder() {
    _stopPolling();
    _prefSet(_kToken, null);
    setState(() {
      _trackingToken = null;
      _req = null;
      _submittedPickupCode = null;
      _submittedTableName = null;
      _submittedTotal = 0;
      _pollFailures = 0;
      _connectionLost = false;
      _attemptKey = null;
      _attemptSig = null;
      _submitUnknown = false;
      _cart.clear();
    });
  }

  Future<void> _onNewOrderPressed() async {
    final r = _req;
    final active = r == null || !_isTerminal(r);
    if (active) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Đặt đơn mới?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Đơn hiện tại vẫn đang được quán xử lý. Nếu tiếp tục, bạn sẽ không '
            'theo dõi được đơn này nữa trên trang này.',
            style: GoogleFonts.outfit(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Quay lại'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đặt đơn mới'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    _resetOrder();
  }

  // ── Giao diện chính ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_trackingToken != null) {
      return _buildOrderStatusScreen();
    }

    final body = Scaffold(
      backgroundColor: _kCream,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kOrange),
                  )
                : _errorMessage.isNotEmpty
                ? _buildErrorState()
                : Column(
                    children: [
                      if (!_isCounter) _buildTableBar(),
                      if (_submitUnknown && _cart.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                          child: _buildUnknownBanner(),
                        ),
                      _buildCategoryRow(),
                      Expanded(child: _buildProductList()),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _cart.isEmpty || _loading ? null : _buildCartBar(),
    );

    // Lớp phủ chờ khi đang gửi (thay cho showDialog + Navigator.pop)
    return Stack(
      children: [
        body,
        if (_isSubmitting)
          const Positioned.fill(
            child: ModalBarrier(color: Colors.black38, dismissible: false),
          ),
        if (_isSubmitting)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator(color: _kOrange)),
          ),
      ],
    );
  }

  Widget _buildErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: _kMuted),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _kOrange,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _loadMenu,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );

  // ── Đầu trang: nền navy chuyển sắc như màn Bán hàng, kèm ô tìm kiếm ─────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1860), _kNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _kOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isCounter
                              ? Icons.takeout_dining_rounded
                              : Icons.table_restaurant_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isCounter ? 'Mang đi' : 'Tại bàn',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _isCounter
                    ? 'Chọn món, quán sẽ chuẩn bị khi bạn thanh toán tại quầy'
                    : 'Chọn món dùng chung cho cả bàn',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                style: GoogleFonts.outfit(fontSize: 15, color: _kInk),
                decoration: InputDecoration(
                  hintText: 'Tìm món, thức uống...',
                  hintStyle: GoogleFonts.outfit(fontSize: 15, color: _kMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: _kMuted),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: _kMuted,
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) =>
                    setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Chọn bàn ────────────────────────────────────────────────────────────────
  Widget _buildTableBar() {
    final has = _selectedTableId != null;
    final noList = _tables.isEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: has ? Colors.white : const Color(0xFFFFF1E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: has ? _kBorder : const Color(0xFFF5C9B0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: noList ? null : _pickTable,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: has ? _kNavyTint : _kOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.table_restaurant_rounded,
                    size: 20,
                    color: has ? _kNavy : Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        noList
                            ? 'Quán chưa có danh sách bàn'
                            : has
                            ? _selectedTableName ?? ''
                            : 'Bạn đang ngồi bàn nào?',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _kInk,
                        ),
                      ),
                      Text(
                        noList
                            ? 'Vui lòng gọi nhân viên'
                            : has
                            ? 'Món sẽ được mang tới bàn này'
                            : 'Chọn bàn để bắt đầu gọi món',
                        style: GoogleFonts.outfit(fontSize: 12, color: _kMuted),
                      ),
                    ],
                  ),
                ),
                if (!noList)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: has ? _kNavyTint : _kOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      has ? 'Đổi bàn' : 'Chọn bàn',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: has ? _kNavy : Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Danh mục: viên thuốc như màn Bán hàng ───────────────────────────────────
  Widget _buildCategoryRow() {
    if (_categories.length <= 1) return const SizedBox(height: 4);
    return Container(
      height: 58,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final sel = cat == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: sel
                    ? const LinearGradient(
                        colors: [Color(0xFF1A1860), _kNavyLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: sel ? null : _kNavyTint,
                borderRadius: BorderRadius.circular(20),
                border: sel
                    ? null
                    : Border.all(color: _kNavy.withValues(alpha: 0.12)),
              ),
              child: Center(
                child: Text(
                  cat,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                    color: sel ? Colors.white : _kInk,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  int _qtyInCart(String productId) {
    var n = 0;
    for (final it in _cart.values) {
      if (it['product_id'] == productId) n += it['quantity'] as int;
    }
    return n;
  }

  // Màu & biểu tượng theo danh mục — giống thẻ món ở màn Bán hàng POS.
  ({IconData icon, Color color}) _catStyle(String? cat) {
    final c = (cat ?? '').toLowerCase();
    if (c.contains('uống') || c.contains('trà') || c.contains('cà phê')) {
      return (icon: Icons.local_cafe_rounded, color: const Color(0xFF1565C0));
    }
    if (c.contains('ăn')) {
      return (icon: Icons.restaurant_rounded, color: const Color(0xFFE65100));
    }
    if (c.contains('tráng') || c.contains('bánh')) {
      return (icon: Icons.cake_rounded, color: const Color(0xFF880E4F));
    }
    if (c.contains('ép') || c.contains('sinh tố') || c.contains('nước')) {
      return (icon: Icons.local_drink_rounded, color: const Color(0xFF00695C));
    }
    return (icon: Icons.fastfood_rounded, color: _kNavy);
  }

  // ── Danh sách món: lưới 2 cột, tiêu đề nhóm có vạch cam ─────────────────────
  Widget _buildProductList() {
    final filtered = _products.where((p) {
      final matchesCat =
          _selectedCategory == 'Tất cả' || p['category'] == _selectedCategory;
      final matchesSearch =
          _searchQuery.isEmpty ||
          (p['name'] as String).toLowerCase().contains(_searchQuery);
      return matchesCat && matchesSearch;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: _kBorder),
            const SizedBox(height: 12),
            Text(
              'Không tìm thấy món phù hợp',
              style: GoogleFonts.outfit(color: _kMuted),
            ),
          ],
        ),
      );
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    final order = <String>[];
    final showHeaders = _selectedCategory == 'Tất cả' && _searchQuery.isEmpty;
    for (final p in filtered) {
      final cat = showHeaders
          ? ((p['category'] as String?)?.isNotEmpty == true
                ? p['category'] as String
                : 'Khác')
          : '';
      if (!grouped.containsKey(cat)) {
        grouped[cat] = [];
        order.add(cat);
      }
      grouped[cat]!.add(p);
    }

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900
            ? 4
            : c.maxWidth >= 600
            ? 3
            : 2;
        final delegate = SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: cols >= 3 ? 1.05 : 0.9,
        );
        return CustomScrollView(
          slivers: [
            for (final cat in order) ...[
              if (showHeaders)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _kOrange,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cat,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _kInk,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${grouped[cat]!.length} món',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: _kMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate: delegate,
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildProductCard(grouped[cat]![i]),
                    childCount: grouped[cat]!.length,
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> prod) {
    final pId = prod['id'] as String;
    final price = (prod['sell_price'] as num).toDouble();
    final imgUrl = prod['image_url'] as String?;
    final style = _catStyle(prod['category'] as String?);
    final accent = style.color;
    final qty = _qtyInCart(pId);
    final inCart = qty > 0;
    final hasImg = imgUrl != null && imgUrl.isNotEmpty;
    final hasToppings = _getToppingsForProduct(pId).isNotEmpty;
    const radius = 22.0;
    Offset tapPos = Offset.zero;

    void onAdd() {
      if (hasToppings) {
        _openProductCustomizerSheet(prod);
      } else {
        _quickAdd(prod, tapPos);
      }
    }

    Widget circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => tapPos = d.globalPosition,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: accent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: accent, size: 20),
      ),
    );

    return GestureDetector(
      onTapDown: (d) => tapPos = d.globalPosition,
      onTap: onAdd,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _openProductCustomizerSheet(prod);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: inCart ? accent : _kBorder,
            width: inCart ? 1.5 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: inCart
                  ? accent.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: inCart ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 1),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImg) ...[
                Image.network(
                  imgUrl,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) =>
                      _cardGradient(accent, style.icon),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                      stops: const [0.35, 1.0],
                    ),
                  ),
                ),
              ] else
                _cardGradient(accent, style.icon),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  color: Colors.black.withValues(alpha: hasImg ? 0.42 : 0.18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        prod['name'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currencyFmt.format(price),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: hasImg
                              ? const Color(0xFFFFD54F)
                              : Colors.white.withValues(alpha: 0.92),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: inCart
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!hasToppings)
                            circleBtn(
                              Icons.remove_rounded,
                              () => _quickRemove(pId),
                            ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              'x$qty',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          circleBtn(Icons.add_rounded, onAdd),
                        ],
                      )
                    : circleBtn(Icons.add_rounded, onAdd),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardGradient(Color accent, IconData icon) => Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: 0.85), accent],
          ),
        ),
      ),
      Align(
        alignment: const Alignment(0, -0.25),
        child: Icon(
          icon,
          size: 44,
          color: Colors.white.withValues(alpha: 0.28),
        ),
      ),
    ],
  );

  // ── Thanh giỏ hàng nổi: navy chuyển sắc + nút cam như màn Bán hàng ──────────
  Widget _buildCartBar() {
    return Container(
      color: _kCream,
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: _openCartBottomSheet,
          child: AnimatedScale(
            key: _cartBarKey,
            scale: _cartPop ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kNavy, _kNavyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: _kNavy.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _kOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_cartItemCount món',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isCounter || _selectedTableName == null
                          ? 'Xem giỏ hàng'
                          : 'Giỏ hàng • $_selectedTableName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: const Color(0xD9FFFFFF),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _kOrange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      currencyFmt.format(_cartTotal),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Màn trạng thái đơn ──────────────────────────────────────────────────────
  // Nhóm trạng thái hiển thị: wait | review | kitchen | rejected | expired | unknown
  String get _phase {
    final r = _req;
    if (r == null) return 'wait';
    switch (r.status) {
      case 'submitted':
        return 'wait';
      case 'claimed':
        return 'review';
      case 'sent_kitchen':
        // COUNTER chưa paid thì chưa coi là xong
        if (_orderIsCounter(r) && r.paymentStatus != 'paid') return 'review';
        return 'kitchen';
      case 'rejected':
      case 'cancelled':
        return 'rejected';
      case 'expired':
        return 'expired';
      default:
        return 'unknown';
    }
  }

  MaterialColor get _phaseColor {
    switch (_phase) {
      case 'wait':
        return Colors.orange;
      case 'review':
        return Colors.blue;
      case 'kitchen':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData get _phaseIcon {
    switch (_phase) {
      case 'wait':
        return Icons.hourglass_top_rounded;
      case 'review':
        return Icons.assignment_turned_in_rounded;
      case 'kitchen':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'expired':
        return Icons.timer_off_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String get _phaseTitle {
    switch (_phase) {
      case 'wait':
        return 'Đã gửi, chờ quán xác nhận';
      case 'review':
        return 'Quán đã nhận và đang kiểm tra đơn';
      case 'kitchen':
        return _isCounter || _orderIsCounter(_req)
            ? 'Đơn đã vào bếp'
            : 'Quán đang chuẩn bị món cho bạn';
      case 'rejected':
        return 'Quán từ chối đơn';
      case 'expired':
        return 'Đơn đã hết hạn';
      default:
        return 'Đang xử lý đơn hàng';
    }
  }

  String get _phaseSubtitle {
    switch (_phase) {
      case 'wait':
        return 'Vui lòng giữ trang này mở, trạng thái sẽ tự cập nhật.';
      case 'review':
        return _orderIsCounter(_req)
            ? 'Quán đang xác nhận đơn và thu tiền tại quầy.'
            : 'Nhân viên đang kiểm tra món của bạn.';
      case 'kitchen':
        return 'Xin chúc ngon miệng!';
      case 'rejected':
        final reason = _str(_req?.rejectReason);
        return reason != null
            ? 'Lý do: $reason'
            : 'Vui lòng liên hệ nhân viên để được hỗ trợ.';
      case 'expired':
        return 'Quán chưa xác nhận kịp. Bạn có thể đặt đơn mới.';
      default:
        return '';
    }
  }

  String _fmtDateTime(DateTime d) =>
      DateFormat('HH:mm dd/MM').format(d.toLocal());

  Widget _buildOrderStatusScreen() {
    final color = _phaseColor;
    final r = _req;
    final isCounter = _orderIsCounter(r);
    final unpaid = isCounter && (r?.paymentStatus != 'paid');
    final phase = _phase;
    final showPayHint =
        isCounter && unpaid && (phase == 'wait' || phase == 'review');
    final pickup = _submittedPickupCode;
    final expiresAt = r?.expiresAt;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Theo dõi đơn gọi món',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_connectionLost) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mất kết nối. Đang thử kết nối lại, trạng thái có thể chưa mới nhất.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.shade200),
              ),
              child: Row(
                children: [
                  Icon(_phaseIcon, color: color.shade900),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _phaseTitle,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: color.shade900,
                          ),
                        ),
                        if (_phaseSubtitle.isNotEmpty)
                          Text(
                            _phaseSubtitle,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: color.shade900.withValues(alpha: 0.8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // COUNTER: mã lấy món lớn + nhắc ra quầy thanh toán
            if (isCounter && pickup != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kNavyLine),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'MÃ LẤY MÓN CỦA BẠN',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _kNavy,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pickup,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 56,
                        color: _kNavy,
                      ),
                    ),
                    if (showPayHint) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Vui lòng ra quầy thanh toán',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (showPayHint) ...[
              Text(
                'Vui lòng ra quầy thanh toán',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.orange.shade900,
                ),
              ),
              const SizedBox(height: 16),
            ],

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  if (!isCounter && _str(_submittedTableName) != null) ...[
                    _infoRow('Bàn:', _submittedTableName!, bold: true),
                    const Divider(height: 16),
                  ],
                  if (phase == 'wait' && expiresAt != null) ...[
                    _infoRow('Đơn giữ đến:', _fmtDateTime(expiresAt)),
                    const Divider(height: 16),
                  ],
                  _infoRow(
                    'Tổng tiền đơn hàng:',
                    currencyFmt.format(_submittedTotal),
                    bold: true,
                    big: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _onNewOrderPressed,
                child: Text(
                  'ĐẶT ĐƠN MỚI',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    bool bold = false,
    bool big = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade700),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              fontSize: big ? 16 : 14,
              color: big ? _kNavy : null,
            ),
          ),
        ),
      ],
    );
  }
}
