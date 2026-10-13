import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/qr_order_model.dart';
import '../repository/qr_order_repository.dart';

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
        backgroundColor: const Color(0xFF6D28D9),
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
              Icon(Icons.qr_code_2_rounded, size: 56, color: Colors.grey.shade400),
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
      final mods = ((item['modifiers_json'] as List?) ?? [])
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
    if (m != null && m.isNotEmpty && m.length <= 160 && !m.contains('Exception')) {
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
                          color: Colors.purple.shade900,
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
                                      ChoiceChip(
                                        label: Text(
                                          t['name']!,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: t['id'] == _selectedTableId
                                                ? Colors.white
                                                : Colors.grey.shade900,
                                          ),
                                        ),
                                        selected: t['id'] == _selectedTableId,
                                        selectedColor: const Color(0xFF6D28D9),
                                        backgroundColor: Colors.grey.shade100,
                                        onSelected: (_) =>
                                            Navigator.pop(ctx, t),
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
                        color: Colors.purple.shade700,
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
                                  ? Colors.purple.shade300
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
                                        color: Colors.purple.shade700,
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
                                      color: Colors.purple.shade700,
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
                              backgroundColor: Colors.purple.shade700,
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
                          color: Colors.purple.shade900,
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
                          color: needTable
                              ? Colors.orange.shade50
                              : Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: needTable
                                ? Colors.orange.shade300
                                : Colors.purple.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.table_restaurant_rounded,
                              color: Colors.purple.shade800,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                needTable
                                    ? 'Chưa chọn bàn — bấm để chọn bàn của bạn'
                                    : 'Bàn: $_selectedTableName',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Colors.purple.shade900,
                                ),
                              ),
                            ),
                            if (!needTable)
                              Text(
                                'Đổi',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.purple.shade700,
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
                                            color: Colors.purple.shade700,
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
                                          color: Colors.purple.shade900,
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
                                        setState(() => item['quantity'] = qty + 1);
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
                          color: Colors.purple.shade900,
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
                        backgroundColor: Colors.purple.shade700,
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _storeName,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Text(
              _isCounter
                  ? 'Gọi món mang đi tại quầy'
                  : 'Gọi món dùng chung tại bàn',
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6D28D9),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadMenu,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                if (!_isCounter) _buildTableBar(),
                if (_submitUnknown && _cart.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: _buildUnknownBanner(),
                  ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm món ăn, thức uống...',
                          hintStyle: GoogleFonts.outfit(fontSize: 13),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
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
                        onChanged: (val) {
                          setState(
                            () => _searchQuery = val.trim().toLowerCase(),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((cat) {
                            final isSel = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  cat,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: isSel
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSel
                                        ? Colors.white
                                        : Colors.grey.shade800,
                                  ),
                                ),
                                selected: isSel,
                                selectedColor: const Color(0xFF6D28D9),
                                backgroundColor: Colors.grey.shade100,
                                onSelected: (_) {
                                  setState(() => _selectedCategory = cat);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildProductList()),
              ],
            ),
      bottomNavigationBar: _cart.isEmpty || _loading
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D28D9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _openCartBottomSheet,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$_cartItemCount',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isCounter || _selectedTableName == null
                                  ? 'Xem giỏ hàng'
                                  : 'Giỏ hàng • $_selectedTableName',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          currencyFmt.format(_cartTotal),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildTableBar() {
    final has = _selectedTableId != null;
    return Material(
      color: has ? Colors.purple.shade50 : Colors.orange.shade50,
      child: InkWell(
        onTap: _tables.isEmpty ? null : _pickTable,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.table_restaurant_rounded,
                size: 20,
                color: has ? Colors.purple.shade800 : Colors.orange.shade900,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _tables.isEmpty
                      ? 'Quán chưa có danh sách bàn. Vui lòng gọi nhân viên.'
                      : has
                      ? 'Bàn của bạn: $_selectedTableName'
                      : 'Chọn bàn của bạn để bắt đầu gọi món',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: has
                        ? Colors.purple.shade900
                        : Colors.orange.shade900,
                  ),
                ),
              ),
              if (_tables.isNotEmpty)
                Text(
                  has ? 'Đổi bàn' : 'Chọn bàn',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.purple.shade700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

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
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'Không tìm thấy món phù hợp',
              style: GoogleFonts.outfit(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: filtered.length,
      itemBuilder: (context, idx) {
        final prod = filtered[idx];
        final price = (prod['sell_price'] as num).toDouble();
        final imgUrl = prod['image_url'] as String?;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openProductCustomizerSheet(prod),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 70,
                      height: 70,
                      color: Colors.purple.shade50,
                      child: imgUrl != null && imgUrl.isNotEmpty
                          ? Image.network(
                              imgUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.restaurant_menu_rounded,
                                    color: Colors.purple.shade300,
                                  ),
                            )
                          : Icon(
                              Icons.restaurant_menu_rounded,
                              color: Colors.purple.shade300,
                              size: 32,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prod['name'] as String,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFmt.format(price),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            color: Colors.purple.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade50,
                      foregroundColor: Colors.purple.shade700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.purple.shade200),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => _openProductCustomizerSheet(prod),
                    child: Text(
                      '+ Chọn',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
        backgroundColor: const Color(0xFF6D28D9),
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
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.shade100),
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
                        color: Colors.purple.shade900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pickup,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 56,
                        color: Colors.purple.shade800,
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

  Widget _infoRow(String label, String value, {bool bold = false, bool big = false}) {
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
              color: big ? Colors.purple.shade900 : null,
            ),
          ),
        ),
      ],
    );
  }
}
