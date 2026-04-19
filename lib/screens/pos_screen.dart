import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_providers.dart';
import '../core/database/app_database.dart';
import '../modules/pos/providers/pos_providers.dart';
import '../modules/pos/repository/pos_repository.dart';
import '../modules/pos/screens/checkout_sheet.dart';

// Màu local
const _kNavy      = Color(0xFF1E1C5E);
const _kNavyLight = Color(0xFF2D2B8A);
const _kOrange    = Color(0xFFE85D20);
const _kInk       = Color(0xFF1A1207);
const _kMuted     = Color(0xFF9E9085);
const _kBg        = Color(0xFFFAF7F2);
const _kRed       = Color(0xFFC62828);
const _kBorder    = Color(0xFFE0D8CC);

// ─────────────────────────────────────────────────────────────────────────────
// POS SCREEN — Màn hình bán hàng chính
// ─────────────────────────────────────────────────────────────────────────────
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Tất cả';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(posProductsProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── App bar ──────────────────────────────────────────────────
          _buildTopBar(),

          // ── Search + category ─────────────────────────────────────────
          _buildSearchBar(),

          // ── Product grid + cart ───────────────────────────────────────
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _kNavy)),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (products) {
                // Lọc theo search + category
                final filtered = products.where((p) {
                  final matchSearch = _searchQuery.isEmpty ||
                      p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      (p.sku?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                          false);
                  final matchCat = _selectedCategory == 'Tất cả' ||
                      (p.category ?? '') == _selectedCategory;
                  return matchSearch && matchCat;
                }).toList();

                // Danh mục duy nhất
                final categories = ['Tất cả',
                  ...products
                      .map((p) => p.category ?? '')
                      .where((c) => c.isNotEmpty)
                      .toSet()
                ];

                return Stack(
                  children: [
                    Column(
                      children: [
                        // Category chips
                        _buildCategoryRow(categories),
                        // Product grid
                        Expanded(
                          child: filtered.isEmpty
                              ? _buildEmptyProducts()
                              : _buildProductGrid(filtered),
                        ),
                        // Spacer for cart panel
                        if (!cart.isEmpty)
                          const SizedBox(height: 90),
                      ],
                    ),
                    // ── Floating cart panel ──────────────────────────
                    if (!cart.isEmpty)
                      Positioned(
                        left: 0, right: 0, bottom: 0,
                        child: _buildCartBar(cart),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOP BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    final cart = ref.watch(cartProvider);
    return Container(
      color: _kNavy,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
          child: Row(
            children: [
              const Text(
                'Bán hàng',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              // Giỏ hàng badge
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_rounded,
                        color: Colors.white, size: 26),
                    onPressed: cart.isEmpty ? null : _openCart,
                  ),
                  if (cart.itemCount > 0)
                    Positioned(
                      right: 4, top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: _kOrange,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${cart.itemCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Clear cart
              if (!cart.isEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded,
                      color: Color(0x80FFFFFF), size: 22),
                  onPressed: _confirmClearCart,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEARCH BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: _kNavy,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Tìm món, mã SKU...',
            hintStyle: const TextStyle(color: Color(0x80FFFFFF), fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Color(0x80FFFFFF), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0x80FFFFFF), size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CATEGORY CHIPS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryRow(List<String> categories) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          final selected = cat == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: 180.ms,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? _kNavy : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? _kNavy : _kBorder,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : _kInk,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRODUCT GRID
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProductGrid(List<CoreProduct> products) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) {
        return _ProductCard(
          product: products[i],
          onTap: () => _addToCart(products[i]),
        )
            .animate(delay: (i * 40).ms)
            .fadeIn(duration: 250.ms)
            .slideY(begin: 0.1, end: 0, duration: 200.ms);
      },
    );
  }

  Widget _buildEmptyProducts() {
    final hasSearch = _searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _kNavy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                hasSearch
                    ? Icons.search_off_rounded
                    : Icons.inventory_2_rounded,
                size: 40, color: _kMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Không tìm thấy "$_searchQuery"'
                  : 'Chưa có sản phẩm nào',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16, color: _kMuted,
                fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Thêm sản phẩm mới với tên này?'
                  : 'Bấm nút bên dưới để thêm sản phẩm đầu tiên',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _kMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openQuickAddProduct(_searchQuery),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                hasSearch
                    ? 'Thêm "$_searchQuery"'
                    : 'Thêm sản phẩm mới',
                style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  void _openQuickAddProduct([String prefillName = '']) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickAddProductSheet(
        prefillName: prefillName,
        onSaved: (name, price, category, unit) async {
          try {
            await ref.read(productRepositoryProvider).create(
              name: name,
              sellPrice: price,
              category: category.isEmpty ? null : category,
              unit: unit.isEmpty ? 'phần' : unit,
              isAvailable: true,
            );
            if (ctx.mounted) {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text('✅ Đã thêm "$name" vào thực đơn'),
                behavior: SnackBarBehavior.floating,
              ));
            }
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text('Lỗi: $e'),
                behavior: SnackBarBehavior.floating,
              ));
            }
          }
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CART BAR — Thanh giỏ hàng nổi ở cuối màn hình
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCartBar(CartState cart) {
    return GestureDetector(
      onTap: _openCart,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kNavy, _kNavyLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _kNavy.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kOrange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${cart.itemCount} món',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cart.lines.length == 1
                    ? cart.lines.first.productName
                    : '${cart.lines.length} loại món',
                style: const TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Total + checkout
            GestureDetector(
              onTap: _openCheckout,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _kOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_fmt(cart.total.toInt())}đ',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      )
          .animate()
          .slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic)
          .fadeIn(duration: 250.ms),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CART PANEL — Bottom sheet chi tiết giỏ hàng
  // ─────────────────────────────────────────────────────────────────────────
  void _openCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartPanel(),
    );
  }

  void _openCheckout() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const CheckoutSheet(),
    );
  }

  void _addToCart(CoreProduct product) {
    HapticFeedback.selectionClick();
    ref.read(cartProvider.notifier).addProduct(product);

    // Cảnh báo nếu hết hàng
    if (product.stockQty <= 0 && product.minStock > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ${product.name} đã hết hàng — vẫn thêm vào giỏ'),
          backgroundColor: const Color(0xFFE65100),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _confirmClearCart() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa giỏ hàng?',
          style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Tất cả món trong giỏ sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(ctx);
            },
            child: const Text('Xóa', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
  }

  String _fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT CARD WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends ConsumerWidget {
  final CoreProduct product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final inCartLine = cart.lines
        .where((l) => l.productId == product.id)
        .toList();
    final inCartQty = inCartLine.isEmpty ? 0 : inCartLine.first.quantity.toInt();
    final isLowStock = product.minStock > 0 && product.stockQty <= product.minStock;
    final isOutOfStock = product.stockQty <= 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: inCartQty > 0 ? _kNavy : _kBorder,
            width: inCartQty > 0 ? 2 : 1,
          ),
          boxShadow: inCartQty > 0
              ? [
                  BoxShadow(
                    color: _kNavy.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon / Emoji area
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.fastfood_rounded,
                          color: _kMuted, size: 22),
                    ),
                  ),
                  const Spacer(),
                  // Name
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Price + stock
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_fmt(product.sellPrice.toInt())}đ',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _kOrange,
                          ),
                        ),
                      ),
                      if (isOutOfStock)
                        _StockBadge('Hết', _kRed, const Color(0xFFFFEBEE))
                      else if (isLowStock)
                        _StockBadge(
                          '${product.stockQty.toInt()}',
                          const Color(0xFFE65100),
                          const Color(0xFFFFF3E0),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // In-cart qty badge (top-right)
            if (inCartQty > 0)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kNavy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$inCartQty',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      duration: 200.ms,
                      curve: Curves.elasticOut,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _StockBadge extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color bgColor;
  const _StockBadge(this.text, this.textColor, this.bgColor);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// CART PANEL — Bottom sheet giỏ hàng đầy đủ
// ─────────────────────────────────────────────────────────────────────────────
class _CartPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
            child: Column(
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _kBorder, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Giỏ hàng',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: _kInk, letterSpacing: -0.3,
                      )),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${cart.itemCount} món',
                        style: const TextStyle(
                          color: _kOrange, fontSize: 12,
                          fontWeight: FontWeight.w700,
                        )),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        ref.read(cartProvider.notifier).clearCart();
                        Navigator.pop(context);
                      },
                      child: const Text('Xóa hết',
                        style: TextStyle(color: _kRed, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),

          // Cart lines
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: cart.lines.length,
              itemBuilder: (_, i) {
                final line = cart.lines[i];
                return _CartLineRow(line: line);
              },
            ),
          ),

          // Total + checkout
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: _kInk.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng cộng',
                      style: TextStyle(fontSize: 15, color: _kMuted,
                        fontWeight: FontWeight.w600)),
                    Text(
                      '${_fmtStatic(cart.subtotal.toInt())}đ',
                      style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900,
                        color: _kNavy, letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        isDismissible: false,
                        enableDrag: false,
                        builder: (_) => const CheckoutSheet(),
                      );
                    },
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('Thanh toán',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartLineRow extends ConsumerWidget {
  final CartLine line;
  const _CartLineRow({required this.line});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.productName,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _kInk)),
                Text('${_fmtStatic(line.unitPrice.toInt())}đ / 1',
                  style: const TextStyle(fontSize: 12, color: _kMuted)),
              ],
            ),
          ),
          // Qty controls
          Container(
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _QBtn(
                  icon: line.quantity <= 1
                      ? Icons.delete_outline_rounded
                      : Icons.remove_rounded,
                  color: line.quantity <= 1 ? _kRed : _kMuted,
                  onTap: () => notifier.decreaseQty(line.productId),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('${line.quantity.toInt()}',
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _kInk)),
                ),
                _QBtn(
                  icon: Icons.add_rounded,
                  color: _kNavy,
                  onTap: () => notifier.increaseQty(line.productId),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Subtotal
          Text('${_fmtStatic(line.subtotal.toInt())}đ',
            style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: _kNavy)),
        ],
      ),
    );
  }
}

class _QBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      );
}

String _fmtStatic(int v) => v.toString().replaceAllMapped(
  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ADD PRODUCT SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _QuickAddProductSheet extends StatefulWidget {
  final String prefillName;
  final Future<void> Function(
      String name, double price, String category, String unit) onSaved;

  const _QuickAddProductSheet({
    required this.prefillName,
    required this.onSaved,
  });

  @override
  State<_QuickAddProductSheet> createState() => _QuickAddProductSheetState();
}

class _QuickAddProductSheetState extends State<_QuickAddProductSheet> {
  final _formKey    = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  final _priceCtrl  = TextEditingController();
  final _costCtrl   = TextEditingController();
  final _catCtrl    = TextEditingController();
  final _unitCtrl   = TextEditingController(text: 'phần');
  bool _saving      = false;
  double _previewPrice = 0;

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kNavyL  = Color(0xFF2D2B8A);
  static const _kOrange = Color(0xFFE85D20);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);

  // Common categories để gợi ý
  static const _cats = ['Đồ ăn', 'Đồ uống', 'Tráng miệng', 'Combo', 'Khác'];
  static const _units = ['phần', 'ly', 'tô', 'cái', 'hộp', 'kg', 'g'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.prefillName);
    _priceCtrl.addListener(() {
      final val = double.tryParse(
          _priceCtrl.text.replaceAll(',', '')) ?? 0;
      setState(() => _previewPrice = val);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _priceCtrl.dispose();
    _costCtrl.dispose(); _catCtrl.dispose(); _unitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header gradient ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kNavy, _kNavyL],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2)),
                  )),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.add_box_rounded,
                          color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Thêm sản phẩm mới',
                          style: TextStyle(
                            color: Colors.white, fontSize: 17,
                            fontWeight: FontWeight.w800)),
                      ),
                      // Live price preview
                      if (_previewPrice > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kOrange,
                            borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            '${_fmtPrice(_previewPrice)}đ',
                            style: const TextStyle(
                              color: Colors.white, fontSize: 13,
                              fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Form ─────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên sản phẩm
                      _FormField(
                        ctrl: _nameCtrl,
                        label: 'Tên sản phẩm *',
                        icon: Icons.restaurant_menu_rounded,
                        color: _kNavy,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Vui lòng nhập tên' : null,
                      ),
                      const SizedBox(height: 12),

                      // Giá bán + giá vốn side by side
                      Row(
                        children: [
                          Expanded(child: _FormField(
                            ctrl: _priceCtrl,
                            label: 'Giá bán (đ)',
                            icon: Icons.sell_rounded,
                            color: _kOrange,
                            keyboard: TextInputType.number,
                            validator: (v) {
                              final val = double.tryParse(
                                  (v ?? '').replaceAll(',', ''));
                              if (val == null || val <= 0) {
                                return 'Nhập giá > 0';
                              }
                              return null;
                            },
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: _FormField(
                            ctrl: _costCtrl,
                            label: 'Giá vốn (đ)',
                            icon: Icons.shopping_basket_rounded,
                            color: _kMuted,
                            keyboard: TextInputType.number,
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Danh mục — quick chips
                      const Text('Danh mục',
                        style: TextStyle(
                          fontSize: 12, color: _kMuted,
                          fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _cats.map((c) {
                          final sel = _catCtrl.text == c;
                          return GestureDetector(
                            onTap: () => setState(() =>
                                _catCtrl.text = sel ? '' : c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel
                                    ? _kNavy
                                    : _kNavy.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sel
                                      ? _kNavy
                                      : _kBorder),
                              ),
                              child: Text(c,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : _kMuted)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Đơn vị — quick chips
                      const Text('Đơn vị',
                        style: TextStyle(
                          fontSize: 12, color: _kMuted,
                          fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _units.map((u) {
                          final sel = _unitCtrl.text == u;
                          return GestureDetector(
                            onTap: () => setState(() => _unitCtrl.text = u),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: sel
                                    ? _kOrange
                                    : _kOrange.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sel
                                      ? _kOrange
                                      : _kBorder),
                              ),
                              child: Text(u,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : _kMuted)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Save button
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kNavy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.add_circle_rounded),
                          label: Text(
                            _saving ? 'Đang thêm...' : 'Thêm vào thực đơn',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final price = double.tryParse(
        _priceCtrl.text.replaceAll(',', '')) ?? 0;
    await widget.onSaved(
      _nameCtrl.text.trim(),
      price,
      _catCtrl.text.trim(),
      _unitCtrl.text.trim(),
    );
    if (mounted) setState(() => _saving = false);
  }

  String _fmtPrice(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORM FIELD HELPER (dùng trong _QuickAddProductSheet)
// ─────────────────────────────────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final Color color;
  final String? Function(String?)? validator;
  final TextInputType? keyboard;

  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);

  const _FormField({
    required this.ctrl, required this.label,
    required this.icon, required this.color,
    this.validator, this.keyboard,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    validator: validator,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _kMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: color, size: 18),
      filled: true, fillColor: _kBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 2)),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 12),
    ),
  );
}
