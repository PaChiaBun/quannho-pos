import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../repository/qr_order_repository.dart';

/// Màn hình Khách Hàng tự gọi món qua QR (Web / Mobile-first)
/// Tích hợp QR bàn giao động thật, chọn Topping, và Idempotency Key bảo đảm an toàn.
class CustomerQrOrderScreen extends StatefulWidget {
  final String channelCode;

  const CustomerQrOrderScreen({super.key, required this.channelCode});

  static String computeCanonicalPayloadHash({
    required String channelCode,
    String? tableHint,
    required List<Map<String, dynamic>> items,
  }) {
    final sortedItems = List<Map<String, dynamic>>.from(items)
      ..sort(
        (a, b) => ((a['product_id'] as String?) ?? '').compareTo(
          (b['product_id'] as String?) ?? '',
        ),
      );

    final buffer = StringBuffer();
    buffer.write('ch:$channelCode|tbl:${tableHint ?? ""}|items:');
    for (final item in sortedItems) {
      buffer.write(
        '[p:${item['product_id']};q:${item['quantity']};n:${item['note'] ?? ""};m:',
      );
      final mods = (item['modifiers_json'] as List?) ?? [];
      final sortedMods = List<Map<String, dynamic>>.from(mods)
        ..sort(
          (a, b) => ((a['id'] as String?) ?? '').compareTo(
            (b['id'] as String?) ?? '',
          ),
        );
      for (final m in sortedMods) {
        buffer.write('${m['id']}:${m['quantity']},');
      }
      buffer.write(']');
    }
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  @override
  State<CustomerQrOrderScreen> createState() => _CustomerQrOrderScreenState();
}

class _CustomerQrOrderScreenState extends State<CustomerQrOrderScreen> {
  final QrOrderRepository _repo = QrOrderRepository();
  final currencyFmt = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  bool _loading = true;
  String _errorMessage = '';

  String _storeName = 'Quán Nhỏ';
  String _channelType = 'TABLE_SHARED'; // 'TABLE_SHARED' | 'COUNTER_TAKEAWAY'

  // Table Hint cho khách ngồi tại bàn
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _toppings = [];
  List<Map<String, dynamic>> _toppingLinks = [];
  List<String> _categories = ['Tất cả'];
  String _selectedCategory = 'Tất cả';
  String _searchQuery = '';

  // Cart: item_key -> {product_id, product_name, unit_price, quantity, note, modifiers_json}
  final Map<String, Map<String, dynamic>> _cart = {};

  // Idempotency key ổn định cho lần checkout hiện tại
  String? _checkoutIdempotencyKey;
  bool _isSubmitting = false;

  // Trạng thái sau khi Submit
  String? _trackingToken;
  String? _rawHandoffToken;
  String? _pickupCode;
  String? _submittedTableHint;
  double _submittedTotal = 0.0;
  String _activeRequestStatus = '';
  String? _rejectReason;
  Timer? _statusTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 1800; // 30 phút

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _countdownTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    setState(() => _loading = true);
    final res = await _repo.fetchQrMenu(widget.channelCode);

    if (!mounted) return;

    if (res.isSuccess && res.data != null) {
      final data = res.data!;
      final prods = List<Map<String, dynamic>>.from(data['products'] ?? []);
      final toppings = List<Map<String, dynamic>>.from(data['toppings'] ?? []);
      final links = List<Map<String, dynamic>>.from(
        data['topping_links'] ?? [],
      );

      final cats = <String>{'Tất cả'};
      for (final p in prods) {
        final cat = p['category'] as String?;
        if (cat != null && cat.trim().isNotEmpty) {
          cats.add(cat.trim());
        }
      }

      setState(() {
        _storeName = data['store_name'] as String? ?? 'Quán Nhỏ';
        _channelType = data['channel_type'] as String? ?? 'TABLE_SHARED';
        _products = prods;
        _toppings = toppings;
        _toppingLinks = links;
        _categories = cats.toList();
        _loading = false;
      });
    } else {
      setState(() {
        _errorMessage = res.message ?? 'Không thể tải thực đơn';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getToppingsForProduct(String productId) {
    if (_toppingLinks.isEmpty) {
      return []; // Fail-closed: không có mapping thì không có topping
    }
    final linkedToppingIds = _toppingLinks
        .where((l) => l['product_id'] == productId)
        .map((l) => l['topping_id'] as String)
        .toSet();
    if (linkedToppingIds.isEmpty) {
      return []; // Fail-closed: món không liên kết topping thì không có topping
    }
    return _toppings.where((t) => linkedToppingIds.contains(t['id'])).toList();
  }

  void _startStatusPolling(String trackingToken) {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      final res = await _repo.checkRequestStatus(trackingToken);
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (res.isSuccess && res.data != null) {
        final req = res.data!;
        setState(() {
          _activeRequestStatus = req.status;
          _submittedTotal = req.totalAmount;
          if (req.assignedTableName != null) {
            _submittedTableHint = req.assignedTableName;
          }
        });

        // Dừng polling khi đơn hoàn tất hoặc bị hủy
        if (req.isSentKitchen || req.isCancelled || req.isExpired) {
          timer.cancel();
        }
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
              final tId = t['id'] as String;
              final tCount = selectedToppings[tId] ?? 0;
              final tPrice = (t['sell_price'] as num).toDouble();
              toppingsTotal += tPrice * tCount;
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

                    // Topping Selection
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
                      ..._toppings.map((t) {
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

                    // Note Input
                    TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                        labelText:
                            'Ghi chú cho món này (VD: ít đá, không đường...)',
                        labelStyle: GoogleFonts.outfit(fontSize: 13),
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

                    // Quantity Counter & Confirm
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
                              for (final t in _toppings) {
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

                              final itemKey =
                                  '${pId}_${modifiersList.map((m) => "${m['id']}:${m['quantity']}").join("_")}_${noteCtrl.text.trim()}';

                              setState(() {
                                _checkoutIdempotencyKey =
                                    null; // Tạo attempt mới khi giỏ thay đổi
                                if (_cart.containsKey(itemKey)) {
                                  _cart[itemKey]!['quantity'] =
                                      (_cart[itemKey]!['quantity'] as int) +
                                      qty;
                                } else {
                                  _cart[itemKey] = {
                                    'product_id': pId,
                                    'product_name': pName,
                                    'unit_price': singleItemPrice,
                                    'quantity': qty,
                                    'note': noteCtrl.text.trim().isEmpty
                                        ? null
                                        : noteCtrl.text.trim(),
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
    );
  }

  void _openCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setCartState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.7,
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
                  if (_channelType == 'TABLE_SHARED') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            color: Colors.purple.shade800,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sau khi xác nhận, hãy đưa QR bàn giao cho nhân viên. Nhân viên sẽ kiểm tra món và nhập số bàn.',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.purple.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                        setCartState(() {
                                          setState(() {
                                            _checkoutIdempotencyKey = null;
                                            if (qty > 1) {
                                              item['quantity'] = qty - 1;
                                            } else {
                                              _cart.remove(key);
                                            }
                                          });
                                        });
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
                                        setCartState(() {
                                          setState(() {
                                            _checkoutIdempotencyKey = null;
                                            item['quantity'] = qty + 1;
                                          });
                                        });
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
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        'XÁC NHẬN & GỬI ĐƠN HÀNG',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () {
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

  Future<void> _submitOrder() async {
    if (_cart.isEmpty || _isSubmitting) return;

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

    setState(() => _isSubmitting = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Sử dụng stable idempotency key cho lần gửi này
    _checkoutIdempotencyKey ??= const Uuid().v4();

    // Tính canonical SHA-256 payload hash (sắp xếp ổn định theo product_id & topping)
    final payloadHash = CustomerQrOrderScreen.computeCanonicalPayloadHash(
      channelCode: widget.channelCode,
      tableHint: null,
      items: items,
    );

    final res = await _repo.submitQrOrder(
      channelCode: widget.channelCode,
      items: items,
      tableHint: null,
      idempotencyKey: _checkoutIdempotencyKey,
      payloadHash: payloadHash,
    );

    if (mounted) Navigator.pop(context); // Dismiss spinner
    setState(() => _isSubmitting = false);

    if (res.isSuccess && res.data != null) {
      final data = res.data!;
      final token = data['tracking_token'] as String?;
      final rawHandoff = data['raw_handoff_token'] as String?;
      final code = data['pickup_code'] as String?;
      final total = (data['total_amount'] as num?)?.toDouble() ?? _cartTotal;

      setState(() {
        _trackingToken = token;
        _rawHandoffToken = rawHandoff;
        _pickupCode = code;
        _submittedTableHint = null;
        _submittedTotal = total;
        _activeRequestStatus = 'customer_submitted';
        _secondsLeft = 1800;
        _cart.clear();
        _checkoutIdempotencyKey =
            null; // Reset idempotency sau khi tạo thành công
      });

      if (token != null) {
        _startStatusPolling(token);
        _startCountdown();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.message ?? 'Không thể gửi đơn hàng. Vui lòng thử lại!',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_rawHandoffToken != null) {
      return _buildOrderStatusAndHandoffScreen();
    }

    return Scaffold(
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
              _channelType == 'TABLE_SHARED'
                  ? 'Gọi món dùng chung tại bàn'
                  : 'Gọi món mang đi tại quầy',
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
                // Search Bar & Category Filter
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

                // Products Grid
                Expanded(child: _buildProductList()),
              ],
            ),
      bottomNavigationBar: _cart.isEmpty
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
                              'Xem giỏ hàng',
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

  // ── Màn hình hiển thị QR Bàn Giao Thật và Trạng Thái ────────────────────────
  Widget _buildOrderStatusAndHandoffScreen() {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    final timeFormatted =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final isSubmitted =
        _activeRequestStatus == 'customer_submitted' ||
        _activeRequestStatus == 'pending_staff';
    final isKitchen =
        _activeRequestStatus == 'sent_kitchen' ||
        _activeRequestStatus == 'ready_for_kitchen';
    final isCancelled =
        _activeRequestStatus == 'cancelled' ||
        _activeRequestStatus == 'rejected';
    final isExpired = _activeRequestStatus == 'expired' || _secondsLeft <= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Phiếu Gọi Món QR',
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
            // Status Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusBgColor(),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _getStatusBorderColor()),
              ),
              child: Row(
                children: [
                  Icon(_getStatusIcon(), color: _getStatusTextColor()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getStatusTitle(),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _getStatusTextColor(),
                          ),
                        ),
                        Text(
                          _getStatusSubtitle(),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: _getStatusTextColor().withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dynamic Handoff QR Card (QR THẬT DÙNG QR_FLUTTER)
            if (isSubmitted && !isExpired && _rawHandoffToken != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.purple.shade100),
                ),
                child: Column(
                  children: [
                    Text(
                      'MÃ QR BÀN GIAO ĐỘNG',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.purple.shade900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Đưa mã QR này cho nhân viên Quán Nhỏ quét để tiếp nhận đơn',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // REAL SCANNABLE QR CODE WIDGET
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: _rawHandoffToken!,
                            version: QrVersions.auto,
                            size: 190.0,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF6D28D9),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _rawHandoffToken!,
                            style: GoogleFonts.sourceCodePro(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.purple.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Countdown Timer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Mã QR có hiệu lực trong: $timeFormatted',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Request Info Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  if (_pickupCode != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mã nhận món (Pickup Code):',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          _pickupCode!,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.purple.shade900,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                  ],
                  if (_submittedTableHint != null &&
                      _submittedTableHint!.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bàn phục vụ:',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          _submittedTableHint!,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tổng tiền đơn hàng:',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        currencyFmt.format(_submittedTotal),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.purple.shade900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (isExpired && !isKitchen && !isCancelled) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    'TẠO LẠI MÃ QR MỚI',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () async {
                    if (_trackingToken == null) return;
                    final res = await _repo.regenerateHandoffToken(
                      _trackingToken!,
                    );
                    if (res.isSuccess && res.data != null) {
                      setState(() {
                        _rawHandoffToken =
                            res.data!['raw_handoff_token'] as String?;
                        _secondsLeft = 1800;
                      });
                      _startCountdown();
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _rawHandoffToken = null;
                    _trackingToken = null;
                    _activeRequestStatus = '';
                    _cart.clear();
                  });
                },
                child: Text(
                  'GỌI THÊM MÓN MỚI',
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

  Color _getStatusBgColor() {
    switch (_activeRequestStatus) {
      case 'customer_submitted':
      case 'pending_staff':
        return Colors.orange.shade50;
      case 'claimed':
      case 'staff_review':
        return Colors.blue.shade50;
      case 'ready_for_kitchen':
      case 'sent_kitchen':
        return Colors.green.shade50;
      case 'cancelled':
      case 'rejected':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getStatusBorderColor() {
    switch (_activeRequestStatus) {
      case 'customer_submitted':
      case 'pending_staff':
        return Colors.orange.shade200;
      case 'claimed':
      case 'staff_review':
        return Colors.blue.shade200;
      case 'ready_for_kitchen':
      case 'sent_kitchen':
        return Colors.green.shade200;
      case 'cancelled':
      case 'rejected':
        return Colors.red.shade200;
      default:
        return Colors.grey.shade300;
    }
  }

  Color _getStatusTextColor() {
    switch (_activeRequestStatus) {
      case 'customer_submitted':
      case 'pending_staff':
        return Colors.orange.shade900;
      case 'claimed':
      case 'staff_review':
        return Colors.blue.shade900;
      case 'ready_for_kitchen':
      case 'sent_kitchen':
        return Colors.green.shade900;
      case 'cancelled':
      case 'rejected':
        return Colors.red.shade900;
      default:
        return Colors.grey.shade800;
    }
  }

  IconData _getStatusIcon() {
    switch (_activeRequestStatus) {
      case 'customer_submitted':
      case 'pending_staff':
        return Icons.hourglass_top_rounded;
      case 'claimed':
      case 'staff_review':
        return Icons.assignment_turned_in_rounded;
      case 'ready_for_kitchen':
      case 'sent_kitchen':
        return Icons.check_circle_rounded;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _getStatusTitle() {
    switch (_activeRequestStatus) {
      case 'customer_submitted':
      case 'pending_staff':
        return 'Đang chờ nhân viên tiếp nhận';
      case 'claimed':
        return 'Nhân viên đã tiếp nhận đơn';
      case 'staff_review':
        return 'Đang kiểm tra và chuẩn bị chuyển bếp';
      case 'ready_for_kitchen':
      case 'sent_kitchen':
        return 'Đã gửi bếp thành công!';
      case 'cancelled':
      case 'rejected':
        return 'Đơn hàng đã bị hủy';
      default:
        return 'Đang xử lý đơn hàng';
    }
  }

  String _getStatusSubtitle() {
    switch (_activeRequestStatus) {
      case 'customer_submitted':
      case 'pending_staff':
        return 'Vui lòng giữ màn hình QR và đưa cho nhân viên quét.';
      case 'claimed':
      case 'staff_review':
        return 'Nhân viên đang kiểm tra món và chọn bàn phục vụ.';
      case 'ready_for_kitchen':
      case 'sent_kitchen':
        return 'Bếp đang chuẩn bị món ăn cho bạn. Xin chúc ngon miệng!';
      case 'cancelled':
      case 'rejected':
        return _rejectReason ?? 'Vui lòng liên hệ nhân viên để được hỗ trợ.';
      default:
        return '';
    }
  }
}
