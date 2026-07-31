import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../repository/qr_order_repository.dart';

class CustomerQrOrderScreen extends StatefulWidget {
  final String channelCode;

  const CustomerQrOrderScreen({
    super.key,
    required this.channelCode,
  });

  @override
  State<CustomerQrOrderScreen> createState() => _CustomerQrOrderScreenState();
}

class _CustomerQrOrderScreenState extends State<CustomerQrOrderScreen> {
  final QrOrderRepository _repo = QrOrderRepository();
  final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  bool _loading = true;
  String _errorMessage = '';

  String _storeName = 'Quán Nhỏ';
  String _channelType = 'table';
  String _tableName = 'Bàn QR';

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _toppings = [];
  List<Map<String, dynamic>> _toppingLinks = [];
  List<String> _categories = ['Tất cả'];
  String _selectedCategory = 'Tất cả';

  // Cart: item_key -> {product_id, product_name, unit_price, quantity, note, toppings: [{topping_id, name, sell_price}]}
  final Map<String, Map<String, dynamic>> _cart = {};

  // Status tracking
  String? _trackingToken;
  String? _pickupCode;
  String _activeRequestStatus = '';
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    final res = await _repo.fetchQrMenu(widget.channelCode);
    if (!mounted) return;

    if (res['success'] == true) {
      final rawProds = (res['products'] as List<dynamic>? ?? []);
      final prods = rawProds.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final rawToppings = (res['toppings'] as List<dynamic>? ?? []);
      final toppings = rawToppings.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final rawLinks = (res['topping_links'] as List<dynamic>? ?? []);
      final links = rawLinks.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final cats = <String>{'Tất cả'};
      for (final p in prods) {
        final cat = p['category'] as String?;
        if (cat != null && cat.trim().isNotEmpty) {
          cats.add(cat.trim());
        }
      }

      setState(() {
        _storeName = res['store_name'] as String? ?? 'Quán Nhỏ';
        _channelType = res['channel_type'] as String? ?? 'table';
        _tableName = res['table_name'] as String? ?? 'Bàn QR';
        _products = prods;
        _toppings = toppings;
        _toppingLinks = links;
        _categories = cats.toList();
        _loading = false;
      });
    } else {
      setState(() {
        _errorMessage = res['message'] as String? ?? 'Không thể tải menu.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getToppingsForProduct(String productId) {
    final linkedToppingIds = _toppingLinks
        .where((l) => l['product_id'] == productId)
        .map((l) => l['topping_id'] as String)
        .toSet();
    return _toppings.where((t) => linkedToppingIds.contains(t['id'])).toList();
  }

  void _openProductCustomizeSheet(Map<String, dynamic> product) {
    final productId = product['id'] as String;
    final availableToppings = _getToppingsForProduct(productId);

    int quantity = 1;
    final Set<String> selectedToppingIds = {};
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            double basePrice = (product['sell_price'] as num?)?.toDouble() ?? 0.0;
            double toppingTotal = 0;
            for (final tid in selectedToppingIds) {
              final top = _toppings.firstWhere((t) => t['id'] == tid, orElse: () => {});
              toppingTotal += (top['sell_price'] as num?)?.toDouble() ?? 0.0;
            }
            final unitPrice = basePrice + toppingTotal;

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product['name'] as String? ?? '',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Text(
                    currencyFmt.format(basePrice),
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF8B5CF6)),
                  ),
                  const Divider(height: 24),
                  if (availableToppings.isNotEmpty) ...[
                    Text(
                      'Chọn Topping:',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableToppings.map((top) {
                        final topId = top['id'] as String;
                        final isSelected = selectedToppingIds.contains(topId);
                        final topPrice = (top['sell_price'] as num?)?.toDouble() ?? 0.0;

                        return FilterChip(
                          selected: isSelected,
                          label: Text('${top['name']} (+${currencyFmt.format(topPrice)})'),
                          selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF8B5CF6),
                          labelStyle: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xFF8B5CF6) : Colors.black87,
                          ),
                          onSelected: (selected) {
                            setSheetState(() {
                              if (selected) {
                                selectedToppingIds.add(topId);
                              } else {
                                selectedToppingIds.remove(topId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Ghi chú cho bếp (tuỳ chọn):',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: 'VD: Ít đá, không hành...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 28),
                            onPressed: () {
                              if (quantity > 1) {
                                setSheetState(() => quantity--);
                              }
                            },
                          ),
                          Text(
                            '$quantity',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green, size: 28),
                            onPressed: () {
                              if (quantity < 99) {
                                setSheetState(() => quantity++);
                              }
                            },
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: Text(
                          'THÊM • ${currencyFmt.format(unitPrice * quantity)}',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          final toppingObjects = selectedToppingIds.map((tid) => {'topping_id': tid}).toList();
                          final itemKey = '$productId-${selectedToppingIds.join(",")}-${noteCtrl.text.trim()}';

                          setState(() {
                            if (_cart.containsKey(itemKey)) {
                              _cart[itemKey]!['quantity'] = (_cart[itemKey]!['quantity'] as int) + quantity;
                            } else {
                              _cart[itemKey] = {
                                'product_id': productId,
                                'product_name': product['name'],
                                'unit_price': unitPrice,
                                'quantity': quantity,
                                'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                                'toppings': toppingObjects,
                              };
                            }
                          });

                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _updateCartQty(String itemKey, int delta) {
    setState(() {
      if (_cart.containsKey(itemKey)) {
        final cur = _cart[itemKey]!['quantity'] as int;
        final next = cur + delta;
        if (next <= 0) {
          _cart.remove(itemKey);
        } else {
          _cart[itemKey]!['quantity'] = next;
        }
      }
    });
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
    if (_cart.isEmpty) return;

    final items = _cart.values.map((it) => {
      'product_id': it['product_id'],
      'quantity': it['quantity'],
      'toppings': it['toppings'],
      'note': it['note'],
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await _repo.submitQrOrder(
      channelCode: widget.channelCode,
      items: items,
    );

    if (mounted) Navigator.pop(context); // Dismiss spinner

    if (res['success'] == true) {
      final token = res['tracking_token'] as String?;
      final code = res['pickup_code'] as String?;
      setState(() {
        _trackingToken = token;
        _pickupCode = code;
        _activeRequestStatus = 'pending_staff';
        _cart.clear();
      });
      if (token != null) _startStatusPolling(token);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Không thể gửi đơn hàng. Vui lòng thử lại!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startStatusPolling(String token) {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final statusData = await _repo.checkRequestStatus(token);
      if (statusData['success'] == true && mounted) {
        setState(() {
          _activeRequestStatus = statusData['status'] as String? ?? 'pending_staff';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_trackingToken != null) {
      return _buildOrderStatusScreen();
    }

    final filteredProducts = _selectedCategory == 'Tất cả'
        ? _products
        : _products.where((p) => p['category'] == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCategoryBar(),
            Expanded(
              child: filteredProducts.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có món nào trong danh mục này',
                        style: GoogleFonts.outfit(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return _buildProductCard(product);
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomSheet: _cart.isNotEmpty ? _buildCartBottomBar() : null,
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF8B5CF6),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _channelType == 'table' ? Icons.table_restaurant_rounded : Icons.storefront_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _storeName,
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  _channelType == 'table' ? _tableName : 'GỌI MÓN TẠI QUẦY',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Category Bar ───────────────────────────────────────────────────────────
  Widget _buildCategoryBar() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = cat == _selectedCategory;

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF8B5CF6) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  cat,
                  style: GoogleFonts.outfit(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Product Card ───────────────────────────────────────────────────────────
  Widget _buildProductCard(Map<String, dynamic> product) {
    final id = product['id'] as String;
    final name = product['name'] as String? ?? '';
    final price = (product['sell_price'] as num?)?.toDouble() ?? 0.0;
    final isAvailable = product['is_available'] as bool? ?? true;
    final stockQty = (product['stock_qty'] as num?)?.toInt() ?? 999;
    final isOutOfStock = !isAvailable || stockQty <= 0;

    int inCartQty = 0;
    for (final item in _cart.values) {
      if (item['product_id'] == id) {
        inCartQty += (item['quantity'] as int);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOutOfStock ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.restaurant_menu_rounded,
              color: isOutOfStock ? Colors.grey : const Color(0xFF8B5CF6),
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isOutOfStock ? Colors.grey : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFmt.format(price),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: isOutOfStock ? Colors.grey : const Color(0xFF8B5CF6),
                  ),
                ),
                if (isOutOfStock)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'TẠM HẾT HÀNG',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!isOutOfStock) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(inCartQty > 0 ? 'Thêm ($inCartQty)' : 'Chọn món'),
              onPressed: () => _openProductCustomizeSheet(product),
            ),
          ],
        ],
      ),
    );
  }

  // ── Cart Bottom Bar ────────────────────────────────────────────────────────
  Widget _buildCartBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_cartItemCount món đã chọn',
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  currencyFmt.format(_cartTotal),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.send_rounded),
              label: Text(
                'GỬI ĐƠN HÀNG',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _submitOrder,
            ),
          ],
        ),
      ),
    );
  }

  // ── Order Status Screen ────────────────────────────────────────────────────
  Widget _buildOrderStatusScreen() {
    final isKitchen = _activeRequestStatus == 'sent_kitchen' || _activeRequestStatus == 'approved';
    final isRejected = _activeRequestStatus == 'rejected';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Trạng Thái Đơn Hàng',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isRejected
                      ? Colors.red.shade50
                      : (isKitchen ? Colors.green.shade50 : Colors.amber.shade50),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRejected
                      ? Icons.cancel_rounded
                      : (isKitchen ? Icons.check_circle_rounded : Icons.hourglass_top_rounded),
                  size: 64,
                  color: isRejected
                      ? Colors.red
                      : (isKitchen ? Colors.green : Colors.amber.shade800),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isRejected
                    ? 'ĐƠN HÀNG BỊ TỪ CHỐI'
                    : (isKitchen ? 'ĐÃ XÁC NHẬN & ĐANG CHẾ BIẾN!' : 'ĐÃ GỬI ĐƠN — CHỜ NHÂN VIÊN XÁC NHẬN'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: isRejected
                      ? Colors.red.shade900
                      : (isKitchen ? Colors.green.shade900 : Colors.amber.shade900),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _channelType == 'table'
                    ? 'Đơn hàng của bàn $_tableName đã được ghi nhận.'
                    : 'Mã Lấy Món Của Bạn: ${_pickupCode ?? "#Q01"}',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 30),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Gọi Thêm Món'),
                onPressed: () {
                  setState(() {
                    _trackingToken = null;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
