import 'package:flutter/material.dart';
import '../core/utils/money_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/cart_animation_helper.dart';
import 'package:uuid/uuid.dart';
import '../modules/loyalty/repository/loyalty_repository.dart';

import '../core/providers/app_providers.dart';
import '../core/providers/permission_provider.dart';
import '../core/widgets/permission_guard.dart';
import '../modules/pos/providers/pos_providers.dart';
import '../modules/pos/repository/pos_repository.dart';
import '../modules/pos/screens/checkout_sheet.dart';
import '../core/utils/responsive.dart';
import '../core/providers/session_provider.dart';
import '../core/repositories/core_product_repository.dart';
import '../core/repositories/ban_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/string_utils.dart';

// Màu local
const _kNavy      = Color(0xFF1E1C5E);
const _kNavyLight = Color(0xFF2D2B8A);
const _kOrange    = Color(0xFFE85D20);
const _kInk       = Color(0xFF1A1207);
const _kMuted     = Color(0xFF9E9085);
const _kBg        = Color(0xFFFAF7F2);
const _kRed       = Color(0xFFC62828);
const _kBorder    = Color(0xFFE0D8CC);

/// Provider kiểm tra module Bàn có đang bật không
/// Dùng allModulesProvider — tự refresh khi module config thay đổi
final tableModuleActiveProvider = Provider<bool>((ref) {
  return ref.watch(allModulesProvider).maybeWhen(
    data: (modules) => modules.any((m) => m.id == 'table' && m.isActive),
    orElse: () => false,
  );
});

/// Provider kiểm tra module Bếp có đang bật không (dùng trong POS)
/// Dùng allModulesProvider — tự refresh khi module config thay đổi
final posKitchenModuleActiveProvider = Provider<bool>((ref) {
  return ref.watch(allModulesProvider).maybeWhen(
    data: (modules) => modules.any((m) => m.id == 'kitchen' && m.isActive),
    orElse: () => false,
  );
});

/// Provider kiểm tra module In Hoá Đơn có đang bật không
final billPrinterModuleActiveProvider = Provider<bool>((ref) {
  return ref.watch(allModulesProvider).maybeWhen(
    data: (modules) => modules.any((m) => m.id == 'bill_printer' && m.isActive),
    orElse: () => false,
  );
});

/// FIX: Provider cố định cho customer picker — tránh tạo StreamProvider inline trong build()
final _loyaltyCustomersForPickerProvider =
    StreamProvider.autoDispose<List<LoyaltyCustomerModel>>((ref) {
  return ref.watch(loyaltyRepositoryProvider).watchCustomers();
});

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
  // Hướng 1: lưu tất cả sessionIds của đơn hiện tại — close hết sau checkout
  final List<String> _kitchenSessionIds = [];

  final GlobalKey _cartKey = GlobalKey();
  int _cartPopTrigger = 0;

  Offset _getCartOffset() {
    try {
      final RenderBox? box = _cartKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final position = box.localToGlobal(Offset.zero);
        return Offset(position.dx + box.size.width / 2, position.dy + box.size.height / 2);
      }
    } catch (_) {}
    return Offset(MediaQuery.of(context).size.width - 50, 40);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(posProductsProvider);
    final cart = ref.watch(cartProvider);

    // ── Desktop/Tablet: layout 2 cột ──────────────────────────────
    if (Responsive.isLargeScreen(context)) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Row(
          children: [
            // Bên trái: Menu sản phẩm (~62%)
            Expanded(
              flex: 62,
              child: Column(
                children: [
                  _buildTopBar(),
                  _buildSearchBar(),
                  Expanded(
                    child: _buildProductArea(productsAsync),
                  ),
                ],
              ),
            ),
            // Divider
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE0D8CC)),
            // Bên phải: Giỏ hàng cố định (~38%)
            SizedBox(
              width: Responsive.isDesktop(context) ? 380 : 320,
              child: _CartPanel(isPanel: true),
            ),
          ],
        ),
      );
    }

    // ── Mobile: layout đơn cột ──────────────────────────────
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildTopBar(),
          _buildSearchBar(),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _kNavy)),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (products) {
                final prodList = (products as List).cast<ProductModel>();
                final filtered = prodList.where((p) {
                  final matchSearch = _searchQuery.isEmpty ||
                      p.name.containsSearch(_searchQuery) ||
                      (p.sku?.containsSearch(_searchQuery) ?? false);
                  final matchCat = _selectedCategory == 'Tất cả' ||
                      (p.category ?? '') == _selectedCategory;
                  return matchSearch && matchCat;
                }).toList();

                final categories = ['Tất cả',
                  ...prodList
                      .map((p) => p.category ?? '')
                      .where((c) => c.isNotEmpty)
                      .toSet()
                ];

                return Stack(
                  children: [
                    Column(
                      children: [
                        _buildCategoryRow(categories),
                        Expanded(
                          child: filtered.isEmpty
                              ? _buildEmptyProducts()
                              : _buildProductGrid(filtered),
                        ),
                        if (!cart.isEmpty)
                          const SizedBox(height: 90),
                      ],
                    ),
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

  // Helper dùng cho desktop layout
  Widget _buildProductArea(AsyncValue productsAsync) {
    return productsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _kNavy)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (products) {
        final prodList = (products as List).cast<ProductModel>();
        final filtered = prodList.where((p) {
          final matchSearch = _searchQuery.isEmpty ||
              p.name.containsSearch(_searchQuery) ||
              (p.sku?.containsSearch(_searchQuery) ?? false);
          final matchCat = _selectedCategory == 'Tất cả' ||
              (p.category ?? '') == _selectedCategory;
          return matchSearch && matchCat;
        }).toList();

        final categories = ['Tất cả',
          ...prodList
              .map((p) => p.category ?? '')
              .where((c) => c.isNotEmpty)
              .toSet()
        ];

        return Column(
          children: [
            _buildCategoryRow(categories),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyProducts()
                  : _buildProductGrid(filtered),
            ),
          ],
        );
      },
    );
  }



  // ─────────────────────────────────────────────────────────────────────────
  // TOP BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    final cart  = ref.watch(cartProvider);
    final now   = DateTime.now();
    final timeStr  = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    final dateStr  = '${now.day}/${now.month}/${now.year}';

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
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bán hàng',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timeStr  ·  $dateStr',
                      style: const TextStyle(
                        color: Color(0x80FFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Quick add product (always shown, no Kho module needed) ──
              GestureDetector(
                onTap: () => _openQuickAddProduct(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20), width: 1),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),

              // Cart badge
              GestureDetector(
                key: _cartKey,
                onTap: cart.isEmpty ? null : _openCart,
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cart.isEmpty
                        ? Colors.white.withValues(alpha: 0.10)
                        : _kOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_cart_rounded,
                          color: Colors.white, size: 18),
                      if (cart.itemCount > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${cart.itemCount} mon',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ).animate(
                target: _cartPopTrigger.toDouble(),
              ).scaleXY(begin: 1.0, end: 1.08, duration: 150.ms, curve: Curves.easeOut)
               .then()
               .scaleXY(begin: 1.08, end: 1.0, duration: 100.ms),

              const SizedBox(width: 8),

              // Clear cart
              if (!cart.isEmpty)
                GestureDetector(
                  onTap: _confirmClearCart,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_sweep_rounded,
                        color: Color(0x99FFFFFF), size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEARCH BAR
  Widget _buildSearchBar() {
    final cart = ref.watch(cartProvider);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kNavy, Color(0xFF252380)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search field (white elevated) ──────────────────────────────
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: _kInk, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tim mon, ma SKU...',
                hintStyle: TextStyle(color: _kMuted, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: _kMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: _kMuted, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Action row: Đơn gần đây + Bếp ────────────────────────────
          Row(children: [
            // Nút Đơn gần đây
            GestureDetector(
              onTap: _openRecentOrders,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history_rounded, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text('Đơn gần đây',
                    style: TextStyle(
                      color: Colors.white70, fontSize: 13,
                      fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            const Spacer(),
            // Kitchen send status hint (if module active)
            _PosKitchenSendHint(),
          ]),
        ],
      ),
    );
  }

  void _openRecentOrders() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RecentOrdersSheet(),
    );
  }



  void _openCustomerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerPickerSheet(
        onSelect: (id, name, pts, {double walletReal = 0,
            double walletBonus = 0, int bonusCapPct = 15,
            DateTime? bonusExpiresAt}) {
          ref.read(cartProvider.notifier).setCustomer(
            id, name, pts,
            walletReal: walletReal,
            walletBonus: walletBonus,
            bonusCapPct: bonusCapPct,
            bonusExpiresAt: bonusExpiresAt,
          );
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _openTablePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TablePickerSheet(
        onSelect: (id, name) {
          ref.read(cartProvider.notifier).setTable(id, name);
          Navigator.pop(ctx);
        },
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────────────
  // CATEGORY CHIPS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryRow(List<String> categories) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          final selected = cat == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: 180.ms,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [Color(0xFF1A1860), _kNavyLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: selected ? null : const Color(0xFFF0EEF8),
                borderRadius: BorderRadius.circular(20),
                border: selected ? null : Border.all(
                    color: _kNavy.withValues(alpha: 0.12), width: 1),
              ),
              child: Center(
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
  Widget _buildProductGrid(List<ProductModel> products) {
    return LayoutBuilder(builder: (context, constraints) {
      // Dùng width thực của khu vực (không phải width màn hình tổng)
      final w = constraints.maxWidth;
      final cols = w >= 900 ? 4
                 : w >= 600 ? 3
                 : 2;
      final aspectRatio = cols >= 4 ? 1.1
                        : cols >= 3 ? 1.3
                        : 0.88;
      final delegate = SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: aspectRatio,
      );

    // Khi dang filter 1 category cu the → grid don gian
    if (_selectedCategory != 'Tat ca' && _selectedCategory != 'Tất cả') {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        gridDelegate: delegate,
        itemCount: products.length,
        itemBuilder: (_, i) => _ProductCard(
          product: products[i],
          onTapWithDetails: (details) => _addToCart(products[i], details),
        ).animate(delay: (i * 40).ms).fadeIn(duration: 250.ms),
      );
    }

    // Khi "Tat ca": group theo category voi section headers
    final Map<String, List<ProductModel>> grouped = {};
    final List<String> order = [];
    for (final p in products) {
      final cat = p.category?.isNotEmpty == true ? p.category! : 'Khac';
      if (!grouped.containsKey(cat)) {
        grouped[cat] = [];
        order.add(cat);
      }
      grouped[cat]!.add(p);
    }

    int globalIdx = 0;
    return CustomScrollView(
      slivers: [
        for (final cat in order) ...[
          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 5, height: 22,
                    decoration: BoxDecoration(
                      color: _kOrange,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cat,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${grouped[cat]!.length} mon',
                    style: TextStyle(
                      fontSize: 12,
                      color: _kMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Grid for this category
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final idx = globalIdx;
                  globalIdx++;
                  return _ProductCard(
                    product: grouped[cat]![i],
                    onTapWithDetails: (details) => _addToCart(grouped[cat]![i], details),
                  ).animate(delay: (idx * 30).ms).fadeIn(duration: 220.ms);
                },
                childCount: grouped[cat]!.length,
              ),
              gridDelegate: delegate,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 4)),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
    );
    }); // end LayoutBuilder
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
        onSaved: (name, price, costPrice, category, unit) async {
          try {
            await ref.read(productRepositoryProvider).create(
              name: name,
              sellPrice: price,
              costPrice: costPrice,
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
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kNavy, _kNavyLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: _kNavy.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Count badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kOrange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${cart.itemCount} món',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Gui bep (dim khi module tat)
            _PosKitchenSendBtn(onPressed: () => _openKitchenConfirm(cart)),
            const SizedBox(width: 6),
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
                  fmtVnd(cart.total.toInt()),
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
    final sessionsToClose = List<String>.from(_kitchenSessionIds);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const CheckoutSheet(),
    ).then((_) async {
      // Đóng tất cả ban_sessions Mang đi của đơn này
      for (final sid in sessionsToClose) {
        try {
          await Supabase.instance.client
              .from('ban_sessions')
              .update({'status': 'closed', 'closed_at': DateTime.now().toUtc().toIso8601String()})
              .eq('id', sid)
              .eq('status', 'open');
        } catch (e) {
          debugPrint('[POS] closeSession err: $e');
        }
      }
      if (mounted) _kitchenSessionIds.clear();
    });
  }

  void _openKitchenConfirm(CartState cart) {
    // Chỉ gửi các line CHƯА sent
    final unsentLines = cart.lines
        .where((l) => !cart.isLineSent(l.lineId))
        .toList();
    if (unsentLines.isEmpty) return;

    // Tạo CartState tạm chỉ chứa unsent lines — dùng cho confirm sheet
    final unsentCart = CartState(lines: unsentLines);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KitchenConfirmSheet(
        cart: unsentCart,
        onConfirm: (note, itemNotes) => _sendCartToKitchen(
          unsentLines,
          kitchenNote: note,
          itemNotes: itemNotes,
        ),
      ),
    );
  }

    // ─────────────────────────────────────────────────────────────────────────
  // GỬI BẾP TỪ POS (Hướng 1) — chỉ gửi unsent lines, giữ cart
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _sendCartToKitchen(
    List<CartLine> unsentLines, {
    String? kitchenNote,
    Map<String, String>? itemNotes,
  }) async {
    if (unsentLines.isEmpty) return;
    final sb = Supabase.instance.client;
    const uuid = Uuid();
    final now = DateTime.now().toUtc().toIso8601String();
    final cart = ref.read(cartProvider);
    final tableLabel = cart.tableName ?? 'Mang di';

    // Lấy store_id từ session
    final storeId = ref.read(sessionProvider)?.storeId;
    if (storeId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa chọn quán'), behavior: SnackBarBehavior.floating));
      return;
    }

    try {
      // 1. Đảm bảo zone hệ thống tồn tại (upsert)
      // Dùng UUID cố định (v5-like) — không phải random để luôn upsert đúng record
      const zoneId  = '00000000-0000-0000-0001-000000000001'; // sys-zone-pos
      const tableId = '00000000-0000-0000-0001-000000000002'; // sys-table-takeaway
      debugPrint('[POS→Bếp] 1. upsert ban_zones...');
      await sb.from('ban_zones').upsert({
        'id': zoneId,
        'store_id': storeId,
        'name': 'Bán mang đi',
        'color_value': 0xFFE85D20,
        'sort_order': 99,
        'is_active': true,
      }, onConflict: 'id');
      debugPrint('[POS→Bếp] 1. done ✓');

      // 2. Đảm bảo bàn "Mang đi" tồn tại
      debugPrint('[POS→Bếp] 2. upsert ban_dining_tables...');
      await sb.from('ban_dining_tables').upsert({
        'id': tableId,
        'store_id': storeId,
        'zone_id': zoneId,
        'name': 'Mang đi',
        'label': 'Mang đi',
        'seats': 1,
        'shape': 'rect',
        'is_active': true,
      }, onConflict: 'id');
      debugPrint('[POS→Bếp] 2. done ✓');

      // 3. Tạo session mới
      debugPrint('[POS→Bếp] 3. insert ban_sessions...');
      final sessionId = uuid.v4();
      await sb.from('ban_sessions').insert({
        'id': sessionId,
        'store_id': storeId,
        'table_id': tableId,
        'status': 'open',
        'guest_count': 1,
        'opened_at': now,
      });
      debugPrint('[POS→Bếp] 3. done ✓');

      // 4. Tạo session items cho unsent lines
      debugPrint('[POS→Bếp] 4. insert ${unsentLines.length} ban_session_items...');
      final sessionItemIds = <String>[];
      for (final line in unsentLines) {
        final itemId = uuid.v4();
        sessionItemIds.add(itemId);
        await sb.from('ban_session_items').insert({
          'id': itemId,
          'store_id': storeId,
          'session_id': sessionId,
          'product_id': line.productId,
          'product_name': line.productName,
          'unit_price': line.unitPrice,   // cột gốc NOT NULL
          'price':      line.unitPrice,   // cột thêm
          'quantity':   line.quantity,
          'subtotal':   line.subtotal,
          'kitchen_status': 'da_gui',
          'added_at': now,
        });
      }
      debugPrint('[POS→Bếp] 4. done ✓');

      // 5. Tạo kitchen ticket
      debugPrint('[POS→Bếp] 5. insert kitchen_tickets...');
      final ticketId = uuid.v4();
      await sb.from('kitchen_tickets').insert({
        'id': ticketId,
        'store_id': storeId,
        'session_id': sessionId,
        'table_label': tableLabel,
        'zone_label': 'Mang đi',
        'round': 1,
        'sent_at': now,
        'status': 'cho',          // ← khớp với kitchen_screen filter
      });
      debugPrint('[POS→Bếp] 5. done ✓');

      // 6. Batch query station code + insert ticket items
      debugPrint('[POS→Bếp] 6. batch lookup station codes...');
      final productIds = unsentLines.map((l) => l.productId).toList();
      final productRows = await sb.from('products')
          .select('id, category')
          .inFilter('id', productIds);
      final categoryMap = <String, String>{
        for (final r in productRows) r['id'] as String: r['category'] as String? ?? '',
      };

      debugPrint('[POS→Bếp] 6. insert ${unsentLines.length} kitchen_ticket_items...');
      for (int i = 0; i < unsentLines.length; i++) {
        final line = unsentLines[i];
        // FIX #2: dùng map thay vì query riêng từng item
        final stationCode = (categoryMap[line.productId] == 'Đồ uống') ? 'nuoc' : 'nong';

        final parts = <String>[
          if (itemNotes != null && (itemNotes[line.lineId] ?? '').isNotEmpty) itemNotes[line.lineId]!,
          if (kitchenNote != null && kitchenNote.isNotEmpty) '📋 $kitchenNote',
        ];

        await sb.from('kitchen_ticket_items').insert({
          'id':              uuid.v4(),
          'store_id':        storeId,           // NOT NULL
          'ticket_id':       ticketId,
          'session_item_id': sessionItemIds[i],
          // ‼️ FIX #1: Dùng đúng field names khớp với KitchenTicketItemModel
          'product_name':    line.productName,  // ✅ model đọc 'product_name'
          'quantity':        line.quantity,      // ✅ model đọc 'quantity'
          'station_code':    stationCode,
          'free_note':       parts.isEmpty ? null : parts.join(' | '),
          // ‼️ FIX #5: Explicit done=false thay vì NULL
          'done':            false,
        });
      }
      debugPrint('[POS→Bếp] 6. done ✓ — ALL STEPS COMPLETE');

      // Hướng 1: GIỮ cart, đánh dấu lines đã gửi
      ref.read(cartProvider.notifier).markLinesSent(
        unsentLines.map((l) => l.lineId).toList(),
      );
      _kitchenSessionIds.add(sessionId);

      if (mounted) {
        final sentCount = unsentLines.fold(0, (s, l) => s + l.quantity.toInt());
        final batchNum  = _kitchenSessionIds.length;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Đã gửi bếp đợt $batchNum: $tableLabel — $sentCount món'),
          ]),
          backgroundColor: _kOrange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }

    } catch (e, st) {
      debugPrint('[POS→Bếp] ❌ LỖI: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi gửi bếp: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
        ));
      }
    }
  }

  void _addToCart(ProductModel product, TapDownDetails details) {
    // Block sản phẩm hết hàng — không cho thêm vào giỏ
    if (product.stockQty <= 0 && product.minStock > 0) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.block_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('${product.name} đã hết hàng'),
          ]),
          backgroundColor: _kRed,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 100),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();

    // Kích hoạt hiệu ứng bay mượt mà
    CartAnimationHelper.runFlyAnimation(
      context: context,
      startOffset: details.globalPosition,
      endOffset: _getCartOffset(),
      color: _kOrange,
      onComplete: () {
        setState(() {
          _cartPopTrigger++;
        });
        HapticFeedback.lightImpact();
      },
    );

    ref.read(cartProvider.notifier).addProduct(product);
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

    String _fmt(int v) => fmtMoney(v.toDouble());
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT CARD WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends ConsumerWidget {
  final ProductModel product;
  final Function(TapDownDetails) onTapWithDetails;

  const _ProductCard({required this.product, required this.onTapWithDetails});

  // Category-based icon + accent color
  static const Map<String, ({IconData icon, Color color})> _catStyle = {
    'Đồ uống':    (icon: Icons.local_cafe_rounded,   color: Color(0xFF1565C0)),
    'Đồ ăn':      (icon: Icons.restaurant_rounded,   color: Color(0xFFE65100)),
    'Tráng miệng':(icon: Icons.cake_rounded,          color: Color(0xFF880E4F)),
  };

  Widget _iconFallback(Color accent, IconData icon, double box, double sz) =>
    Container(
      color: accent.withValues(alpha: 0.12),
      child: Center(child: Icon(icon, color: accent, size: sz)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart      = ref.watch(cartProvider);
    final inCartLines = cart.lines.where((l) => l.productId == product.id).toList();
    final inCartQty   = inCartLines.fold<int>(0, (s, l) => s + l.quantity.toInt());
    final isOutOfStock = product.stockQty <= 0 && product.minStock > 0;
    final isLowStock   = !isOutOfStock && product.minStock > 0 &&
        product.stockQty <= product.minStock;

    // Determine visual style based on category
    final cat     = product.category ?? '';
    final style   = _catStyle[cat];
    final accent  = style?.color ?? _kNavy;
    final catIcon = style?.icon ?? Icons.fastfood_rounded;

    final isInCart = inCartQty > 0;

    return Opacity(
      // Mờ 50% khi hết hàng — vẫn hiện để biết món tồn tại nhưng disable
      opacity: isOutOfStock ? 0.45 : 1.0,
      child: GestureDetector(
        onTapDown: isOutOfStock ? null : onTapWithDetails, // disable click khi hết hàng
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _PosAddItemsSheet(),
        );
      },
      child: LayoutBuilder(builder: (ctx2, cs) {
        final w = cs.maxWidth;
        final isCompact = w < 260;
        final isTiny    = w < 160;
        final pad       = isTiny ? 8.0  : isCompact ? 10.0 : 14.0;
        final iconBox   = isTiny ? 32.0 : isCompact ? 40.0 : 52.0;
        final iconSz    = isTiny ? 16.0 : isCompact ? 20.0 : 26.0;
        final nameSize  = isTiny ? 13.0 : isCompact ? 16.0 : 22.0;
        final priceSize = isTiny ? 11.0 : isCompact ? 13.0 : 17.0;
        final radius    = isCompact ? 16.0 : 22.0;
        // Format giá ngắn gọn cho card: 20K, 150K, 1.5Tr
        String fmtCard(int v) {
          if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1)}Tr';
          if (v >= 1000)    return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K';
          return '${v}Đ';
        }

        return AnimatedContainer(
          duration: 150.ms,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isInCart ? accent : _kBorder,
              width: isInCart ? 1.5 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: isInCart
                    ? accent.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: isInCart ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        child: Stack(
          children: [
            // ── Nền: full ảnh (nếu có) hoặc layout icon cũ ──
            if (product.imageUrl != null && product.imageUrl!.isNotEmpty) ...[
              // Full-card image
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Image.network(
                    product.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              ),
              // Gradient overlay — tối phía dưới để đọc chữ
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: DecoratedBox(
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
                ),
              ),
              // Thanh nền mờ + Tên + giá ở dưới
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(radius),
                    bottomRight: Radius.circular(radius),
                  ),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(pad, 8, 44, pad),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: nameSize + 4,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isCompact ? 1 : 2),
                        Row(children: [
                          Expanded(child: Text(
                            fmtVnd(product.sellPrice.toInt()),
                            style: TextStyle(
                              fontSize: priceSize + 3,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFFFD54F),
                              letterSpacing: -0.3,
                            ),
                          )),
                          if (isOutOfStock)
                            _StockBadge('Hết', _kRed, const Color(0xFFFFEBEE))
                          else if (isLowStock)
                            _StockBadge(
                              '${product.stockQty.toInt()}',
                              const Color(0xFFE65100),
                              const Color(0xFFFFF3E0)),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Layout gradient theo danh mục — không có ảnh
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.85),
                          accent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Icon căn giữa phần trên card — trang trí có chủ đích
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(0, -0.25),
                  child: Icon(
                    catIcon,
                    size: isTiny ? 28 : isCompact ? 36 : 44,
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
              ),
              // Tên + giá ở dưới
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(radius),
                    bottomRight: Radius.circular(radius),
                  ),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(pad, 8, 44, pad),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: nameSize + 2,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isCompact ? 1 : 2),
                        Row(children: [
                          Expanded(child: Text(
                            fmtVnd(product.sellPrice.toInt()),
                            style: TextStyle(
                              fontSize: priceSize + 1,
                              fontWeight: FontWeight.w900,
                              color: Colors.white.withValues(alpha: 0.92),
                              letterSpacing: -0.3,
                            ),
                          )),
                          if (isOutOfStock)
                            _StockBadge('Hết', _kRed, const Color(0xFFFFEBEE))
                          else if (isLowStock)
                            _StockBadge(
                              '${product.stockQty.toInt()}',
                              const Color(0xFFE65100),
                              const Color(0xFFFFF3E0)),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // ── Top-right controls: [−] xN  OR  [+] ──
            Positioned(
              right: 6, top: 6,
              child: isInCart
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nut tru
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => ref
                              .read(cartProvider.notifier)
                              .decreaseQtyByProductId(product.id),
                          child: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: accent, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.18),
                                  blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Icon(Icons.remove_rounded,
                                color: accent, size: 20),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Qty badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'x$inCartQty',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                            .animate()
                            .scale(
                              begin: const Offset(0.6, 0.6),
                              duration: 200.ms,
                              curve: Curves.elasticOut,
                            ),
                      ],
                    )
                  : Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kBorder, width: 1),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: _kMuted, size: 14),
                    ),
            ),
          ],
        ),
        ); // AnimatedContainer
      }), // LayoutBuilder
    ), // GestureDetector
  ); // Opacity
  }

    String _fmt(int v) => fmtMoney(v.toDouble());
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
  /// [isPanel] = true khi dùng làm side panel (desktop)
  /// [isPanel] = false khi dùng làm modal bottom sheet (mobile)
  final bool isPanel;
  const _CartPanel({this.isPanel = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isPanel
            ? null // panel: vuông hết
            : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: isPanel
          ? null // panel: full height
          : BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
      child: Column(
        mainAxisSize: isPanel ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // Handle + header
          Padding(
            padding: EdgeInsets.fromLTRB(20, isPanel ? 16 : 12, 16, 4),
            child: Column(
              children: [
                // Drag handle (chỉ hiện khi là sheet, không hiện trong panel)
                if (!isPanel) ...[
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: _kBorder, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 14),
                ],
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
                    // Permission guard: chỉ owner/manager mới được xoá giỏ hàng
                    PermissionGuard(
                      action: 'pos.cancel_bill',
                      behavior: PermissionBehavior.blockWithToast,
                      blockMessage: 'Bạn không có quyền huỷ đơn hàng',
                      child: TextButton(
                        onPressed: () {
                          ref.read(cartProvider.notifier).clearCart();
                          if (!isPanel) Navigator.pop(context);
                        },
                        child: const Text('Xóa hết',
                          style: TextStyle(color: _kRed, fontSize: 13)),
                      ),
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

          // ── Ghi chú đơn hàng ──────────────────────────────────────────
          _OrderNoteRow(cart: cart),

          // ── Chọn khách hàng ──────────────────────────────────────────
          _CustomerPickerRow(cart: cart),

          // Total + checkout
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(
                color: _kInk.withValues(alpha: 0.06),
                blurRadius: 8, offset: const Offset(0, -2))]),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Tổng cộng',
                  style: TextStyle(fontSize: 15, color: _kMuted,
                    fontWeight: FontWeight.w600)),
                Text(fmtVnd(cart.subtotal.toInt()),
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: _kNavy, letterSpacing: -0.5)),
              ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Chỉ pop sheet khi đang nhúc sheet (mobile)
                      // Panel: mở checkout trực tiếp không cần pop
                      if (!isPanel) Navigator.pop(context);
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

// ─────────────────────────────────────────────────────────────────────────────
// ORDER NOTE ROW — Ghi chú cả đơn hàng
// ─────────────────────────────────────────────────────────────────────────────
class _OrderNoteRow extends ConsumerWidget {
  final CartState cart;
  const _OrderNoteRow({required this.cart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = cart.orderNote;
    final notifier = ref.read(cartProvider.notifier);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _OrderNoteSheet(
            initialNote: note ?? '',
            onSave: (v) => notifier.setOrderNote(v.isEmpty ? null : v),
            onClear: () => notifier.setOrderNote(null),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: note != null ? _kOrange.withValues(alpha: 0.07) : _kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: note != null
              ? _kOrange.withValues(alpha: 0.30)
              : _kBorder,
            width: note != null ? 1.2 : 1)),
        child: Row(children: [
          Icon(note != null ? Icons.notes_rounded : Icons.add_comment_outlined,
            size: 16,
            color: note != null ? _kOrange : _kMuted),
          const SizedBox(width: 10),
          Expanded(child: note != null
            ? Text(note,
                style: const TextStyle(fontSize: 13, color: _kOrange,
                  fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis)
            : const Text('Thêm ghi chú đơn hàng',
                style: TextStyle(fontSize: 13, color: _kMuted))),
          if (note != null)
            GestureDetector(
              onTap: () => notifier.setOrderNote(null),
              child: const Icon(Icons.close_rounded, size: 14, color: _kMuted)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ORDER NOTE SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _OrderNoteSheet extends StatefulWidget {
  final String initialNote;
  final ValueChanged<String> onSave;
  final VoidCallback onClear;
  const _OrderNoteSheet({required this.initialNote,
    required this.onSave, required this.onClear});
  @override State<_OrderNoteSheet> createState() => _OrderNoteSheetState();
}

class _OrderNoteSheetState extends State<_OrderNoteSheet> {
  late final TextEditingController _ctrl;

  @override void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNote);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: _kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_long_rounded,
                  color: _kNavy, size: 18)),
              const SizedBox(width: 12),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ghi chú đơn hàng',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                    color: _kInk, letterSpacing: -0.3)),
                Text('Áp dụng cho toàn bộ đơn',
                  style: TextStyle(fontSize: 12, color: _kMuted)),
              ])),
              if (widget.initialNote.isNotEmpty)
                GestureDetector(
                  onTap: () { widget.onClear(); Navigator.pop(context); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Text('Xóa',
                      style: TextStyle(fontSize: 12, color: _kRed,
                        fontWeight: FontWeight.w700)))),
            ]),
          ),
          const SizedBox(height: 14),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl, autofocus: true, maxLines: 3,
              style: const TextStyle(fontSize: 14, color: _kInk),
              decoration: InputDecoration(
                hintText: 'Vd: khách dị ứng hành, giao trước 12h...',
                hintStyle: TextStyle(color: _kMuted.withValues(alpha: 0.7)),
                filled: true, fillColor: _kBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kNavy, width: 1.5)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBorder))),
            ),
          ),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave(_ctrl.text.trim());
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                  elevation: 0),
                child: const Text('Lưu ghi chú',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _CartLineRow extends ConsumerWidget {
  final CartLine line;
  const _CartLineRow({required this.line});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier  = ref.read(cartProvider.notifier);
    final isSent    = ref.watch(cartProvider).isLineSent(line.lineId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Product info + note
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên món
                Row(children: [
                  if (isSent) Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE85D20).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('đã gửi bếp',
                      style: TextStyle(fontSize: 10, color: Color(0xFFE85D20),
                          fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Text(line.productName,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: _kInk)),
                  ),
                ]),
                const SizedBox(height: 2),
                // Giá đơn vị + nút ghi chú (tự động xuống dòng khi màn hình hẹp)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(fmtVnd(line.unitPrice.toInt()),
                      style: const TextStyle(fontSize: 12, color: _kMuted)),
                    // Nút ghi chú — luôn hiển thị, đủ target size
                    GestureDetector(
                      onTap: () => _openItemNoteSheet(context, notifier, line),
                      child: line.note != null && line.note!.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _kOrange.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _kOrange.withValues(alpha: 0.40))),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.edit_note_rounded,
                                size: 13, color: _kOrange),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 80),
                                child: Text(line.note!,
                                  style: const TextStyle(
                                    fontSize: 11, color: _kOrange,
                                    fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                            ]))
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _kBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _kBorder)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.add_rounded, size: 12, color: _kMuted),
                              SizedBox(width: 4),
                              Text('Ghi chú',
                                style: TextStyle(fontSize: 11, color: _kMuted,
                                  fontWeight: FontWeight.w600)),
                            ])),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Qty controls — ẨN -/+ khi đã gửi bếp
          Container(
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (!isSent) _QBtn(
                  icon: line.quantity <= 1
                      ? Icons.delete_outline_rounded
                      : Icons.remove_rounded,
                  color: line.quantity <= 1 ? _kRed : _kMuted,
                  onTap: () => notifier.decreaseQty(line.lineId),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('${line.quantity.toInt()}',
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _kInk)),
                ),
                if (!isSent) _QBtn(
                  icon: Icons.add_rounded,
                  color: _kNavy,
                  onTap: () => notifier.increaseQty(line.lineId),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Subtotal (tổng tiền dòng = đơn giá × số lượng)
          Text(fmtVnd(line.subtotal.toInt()),
            style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: _kNavy)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ITEM NOTE SHEET — Ghi chú per-item (bottom sheet thay AlertDialog)
// ─────────────────────────────────────────────────────────────────────────────
void _openItemNoteSheet(
    BuildContext context, CartNotifier notifier, CartLine line) {
  HapticFeedback.selectionClick();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ItemNoteSheet(
      productName: line.productName,
      initialNote: line.note ?? '',
      onSave: (note) {
        notifier.setItemNote(line.lineId, note.isEmpty ? null : note);
      },
      onClear: () => notifier.setItemNote(line.lineId, null),
    ),
  );
}

class _ItemNoteSheet extends StatefulWidget {
  final String productName, initialNote;
  final ValueChanged<String> onSave;
  final VoidCallback onClear;
  const _ItemNoteSheet({required this.productName, required this.initialNote,
    required this.onSave, required this.onClear});
  @override State<_ItemNoteSheet> createState() => _ItemNoteSheetState();
}

class _ItemNoteSheetState extends State<_ItemNoteSheet> {
  late final TextEditingController _ctrl;
  static const _suggestions = [
    'Không hành', 'Ít đường', 'Ít đá', 'Không đá',
    'Thêm sauce', 'Chín kỹ', 'Không cay', 'Thêm phần',
  ];

  @override void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNote);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          const SizedBox(height: 10),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: _kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),

          // Header
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.notes_rounded,
                  color: _kOrange, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Ghi chú món',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                    color: _kInk, letterSpacing: -0.3)),
                Text(widget.productName,
                  style: const TextStyle(fontSize: 12, color: _kMuted)),
              ])),
              if (widget.initialNote.isNotEmpty)
                GestureDetector(
                  onTap: () { widget.onClear(); Navigator.pop(context); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10)),
                    child: const Text('Xóa',
                      style: TextStyle(fontSize: 12, color: _kRed,
                        fontWeight: FontWeight.w700)))),
            ]),
          ),
          const SizedBox(height: 14),

          // Quick suggest chips
          SizedBox(height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                return GestureDetector(
                  onTap: () {
                    final cur = _ctrl.text;
                    _ctrl.text = cur.isEmpty ? s : '$cur, $s';
                    _ctrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: _ctrl.text.length));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kBorder)),
                    child: Text(s,
                      style: const TextStyle(fontSize: 12, color: _kInk,
                        fontWeight: FontWeight.w600))),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Input field
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 2,
              style: const TextStyle(fontSize: 14, color: _kInk),
              decoration: InputDecoration(
                hintText: 'Vd: không hành, thêm sauce...',
                hintStyle: TextStyle(color: _kMuted.withValues(alpha: 0.7)),
                filled: true,
                fillColor: _kBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kNavy, width: 1.5)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _kBorder))),
            ),
          ),
          const SizedBox(height: 12),

          // Save button
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave(_ctrl.text.trim());
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                  elevation: 0),
                child: const Text('Lưu ghi chú',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
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

String _fmtStatic(int v) => fmtMoney(v.toDouble());

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOMER PICKER ROW — Tìm khách hàng trong giỏ hàng POS
// ─────────────────────────────────────────────────────────────────────────────
class _CustomerPickerRow extends ConsumerStatefulWidget {
  final CartState cart;
  const _CustomerPickerRow({required this.cart});

  @override
  ConsumerState<_CustomerPickerRow> createState() => _CustomerPickerRowState();
}

class _CustomerPickerRowState extends ConsumerState<_CustomerPickerRow> {
  final _phoneCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 9) return;
    setState(() => _searching = true);
    try {
      final sb = Supabase.instance.client;
      final session = ref.read(sessionProvider);
      final storeId = session?.storeId;
      if (storeId == null) return;

      final res = await sb
          .from('customers')
          .select('id, name, loyalty_pts, real_balance, bonus_balance, bonus_cap_pct, bonus_expires_at')
          .eq('store_id', storeId)
          .eq('phone', phone)
          .eq('is_deleted', false)
          .maybeSingle();

      if (res != null && mounted) {
        final expiresAt = res['bonus_expires_at'] != null
            ? DateTime.tryParse(res['bonus_expires_at'] as String)
            : null;
        ref.read(cartProvider.notifier).setCustomer(
          res['id'] as String,
          res['name'] as String? ?? phone,
          (res['loyalty_pts'] as num?)?.toDouble() ?? 0,
          walletReal:     (res['real_balance'] as num?)?.toDouble() ?? 0,
          walletBonus:    (res['bonus_balance'] as num?)?.toDouble() ?? 0,
          bonusCapPct:    (res['bonus_cap_pct'] as num?)?.toInt() ?? 15,
          bonusExpiresAt: expiresAt,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy khách hàng'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    final hasCustomer = cart.customerId != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: hasCustomer
          ? _buildCustomerCard(cart)
          : _buildSearchRow(),
    );
  }

  Widget _buildSearchRow() => Row(children: [
    Expanded(child: SizedBox(
      height: 42,
      child: TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        style: const TextStyle(fontSize: 13, color: _kInk),
        onSubmitted: (_) => _lookup(),
        decoration: InputDecoration(
          hintText: 'SĐT khách hàng (tích điểm)...',
          hintStyle: const TextStyle(fontSize: 12, color: _kMuted),
          prefixIcon: const Icon(Icons.person_search_rounded, size: 16, color: _kMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: _kBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kNavy, width: 1.5)),
        ),
      ),
    )),
    const SizedBox(width: 8),
    GestureDetector(
      onTap: _searching ? null : _lookup,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: _kNavy,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _searching
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.search_rounded, color: Colors.white, size: 20),
      ),
    ),
  ]);

  Widget _buildCustomerCard(CartState cart) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.40)),
    ),
    child: Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.stars_rounded, color: Color(0xFF2E7D32), size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(cart.customerName ?? '',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
            color: Color(0xFF1B5E20))),
        Row(children: [
          Text('${cart.loyaltyPtsAvailable.toInt()} điểm',
            style: const TextStyle(fontSize: 11, color: Color(0xFF388E3C),
              fontWeight: FontWeight.w600)),
          if (cart.hasWallet) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6)),
              child: Text('Ví: ${fmtVnd(cart.walletTotal.toInt())}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32))),
            ),
          ],
        ]),
      ])),
      GestureDetector(
        onTap: () {
          ref.read(cartProvider.notifier).clearCustomer();
          _phoneCtrl.clear();
        },
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF2E7D32)),
        ),
      ),
    ]),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// QUICK ADD PRODUCT SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _QuickAddProductSheet extends StatefulWidget {
  final String prefillName;
  final Future<void> Function(
      String name, double price, double costPrice,
      String category, String unit) onSaved;

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
                            '${_fmtPrice(_previewPrice)}',
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
    final price     = double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;
    final costPrice = double.tryParse(_costCtrl.text.replaceAll(',', '')) ?? 0;
    await widget.onSaved(
      _nameCtrl.text.trim(),
      price,
      costPrice,
      _catCtrl.text.trim(),
      _unitCtrl.text.trim(),
    );
    if (mounted) setState(() => _saving = false);
  }

    String _fmtPrice(double v) => fmtMoney(v);
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

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOMER PICKER SHEET — Chọn khách hàng cho đơn POS
// ─────────────────────────────────────────────────────────────────────────────
class _CustomerPickerSheet extends ConsumerStatefulWidget {
  final void Function(
    String id,
    String name,
    double pts, {
    double walletReal,
    double walletBonus,
    int bonusCapPct,
    DateTime? bonusExpiresAt,
  }) onSelect;

  const _CustomerPickerSheet({required this.onSelect});

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState
    extends ConsumerState<_CustomerPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kGold   = Color(0xFFF9A825);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kBg     = Color(0xFFFAF7F2);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dùng provider cố định (không tạo inline) để tránh rebuild vô hạn
    final customersAsync = ref.watch(_loyaltyCustomersForPickerProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: const BoxDecoration(
              color: _kNavy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.person_search_rounded,
                  color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Text('Chọn khách hàng',
                  style: TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              const SizedBox(height: 12),
              // Search
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Tìm tên, số điện thoại...',
                    hintStyle: const TextStyle(
                      color: Colors.white54, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                      color: Colors.white54, size: 18),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ]),
          ),

          // Customer list
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                child: Text('Không thể tải danh sách')),
              data: (customers) {
                final filtered = _query.isEmpty
                    ? customers
                    : customers.where((c) {
                        final q = _query.toLowerCase();
                        return c.name.toLowerCase().contains(q) ||
                            (c.phone ?? '').contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off_rounded,
                          size: 48, color: _kMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text('Không tìm thấy khách hàng',
                          style: TextStyle(color: _kMuted, fontSize: 14)),
                      ],
                    ),
                  );
                }

                 return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: _kBorder),
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    final pts = c.loyaltyPts;
                    final hasWallet = c.realBalance > 0 || c.bonusBalance > 0;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: _kNavy.withValues(alpha: 0.1),
                        child: Text(
                          c.name.isNotEmpty
                              ? c.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: _kNavy,
                            fontWeight: FontWeight.w800)),
                      ),
                      title: Text(c.name,
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: _kNavy)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.phone ?? 'Chưa có SĐT',
                            style: const TextStyle(fontSize: 12, color: _kMuted)),
                          if (hasWallet)
                            Text('💳 Ví: ${c.realBalance.toInt()} + ${c.bonusBalance.toInt()} bonus',
                              style: const TextStyle(fontSize: 11,
                                color: Color(0xFF1E1C5E), fontWeight: FontWeight.w600)),
                        ],
                      ),
                      trailing: pts > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _kGold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.stars_rounded,
                                    color: _kGold, size: 14),
                                  const SizedBox(width: 4),
                                  Text('${pts.toInt()}đ',
                                    style: const TextStyle(
                                      color: _kGold, fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                                ],
                              ),
                            )
                          : null,
                      onTap: () => widget.onSelect(
                        c.id, c.name, pts,
                        walletReal: c.realBalance,
                        walletBonus: c.bonusBalance,
                        bonusCapPct: c.bonusCapPct,
                        bonusExpiresAt: c.bonusExpiresAt,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLE CHIP — Dim + tooltip khi module Bàn chưa bật
// ─────────────────────────────────────────────────────────────────────────────
class _TableChip extends ConsumerWidget {
  final String? tableName;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _TableChip({required this.tableName, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTableActive = ref.watch(tableModuleActiveProvider);
    final hasTable = tableName != null;

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: !isTableActive
            ? Colors.white.withValues(alpha: 0.05)
            : hasTable
                ? const Color(0xFF3B82F6).withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: !isTableActive
              ? Colors.white.withValues(alpha: 0.12)
              : hasTable ? const Color(0xFF60A5FA) : Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Opacity(
        opacity: isTableActive ? 1.0 : 0.38,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasTable ? Icons.table_restaurant_rounded : Icons.table_restaurant_outlined,
              color: hasTable && isTableActive ? const Color(0xFF60A5FA) : Colors.white60,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              hasTable ? tableName! : 'Chọn bàn',
              style: TextStyle(
                color: hasTable && isTableActive ? const Color(0xFF60A5FA) : Colors.white60,
                fontSize: 12, fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    if (!isTableActive) {
      return Tooltip(
        message: 'Cần bật Module Bàn trong Modules trước',
        preferBelow: true,
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 4),
        child: chip,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(onTap: onTap, child: chip),
        if (hasTable) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10), shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, color: Colors.white54, size: 13),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLE PICKER SHEET — Chọn bàn từ danh sách DB
// ─────────────────────────────────────────────────────────────────────────────
class _TablePickerSheet extends ConsumerWidget {
  final void Function(String id, String name) onSelect;
  const _TablePickerSheet({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(StreamProvider((ref) =>
      ref.watch(banRepositoryProvider).watchAllTables()));
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Chọn bàn',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: tablesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (tables) {
                final activeTables = tables.where((t) => t.isActive).toList();
                if (activeTables.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.table_restaurant_rounded, size: 48, color: Colors.black26),
                      const SizedBox(height: 12),
                      Text('Chưa có bàn nào', style: TextStyle(color: Colors.grey.shade500)),
                    ]),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: activeTables.length,
                  itemBuilder: (_, i) {
                    final t = activeTables[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _kNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.table_restaurant_rounded, color: _kNavy, size: 20),
                      ),
                      title: Text(t.label,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _kNavy)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () => onSelect(t.id, t.label),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POS KITCHEN SEND BUTTON — Dim + tooltip khi module Bep chua bat
// ─────────────────────────────────────────────────────────────────────────────
class _PosKitchenSendBtn extends ConsumerWidget {
  final VoidCallback onPressed;
  const _PosKitchenSendBtn({required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isKitchenActive = ref.watch(posKitchenModuleActiveProvider);
    final cart = ref.watch(cartProvider);

    // Đếm số món CHƯA gửi bếp
    final unsentCount = cart.lines
        .where((l) => !cart.isLineSent(l.lineId))
        .fold(0, (s, l) => s + l.quantity.toInt());
    final allSent = cart.lines.isNotEmpty && unsentCount == 0;

    final btn = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isKitchenActive && !allSent
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isKitchenActive && !allSent
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Opacity(
        opacity: (isKitchenActive && !allSent) ? 1.0 : 0.35,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              allSent ? 'Đã gửi hết' : 'Bếp${unsentCount > 0 ? ' ($unsentCount)' : ''}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    if (!isKitchenActive) {
      return Tooltip(
        message: 'Can bat Module Bep trong Modules truoc',
        preferBelow: false,
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 4),
        child: btn,
      );
    }

    // Disable khi tất cả đã gửi hết
    if (allSent) return btn;

    return GestureDetector(onTap: onPressed, child: btn);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCATION SELECTOR — "Phuc vu tai:" row ro rang hon chip don gian
// Hien thi: [📦 Mang di] hoac [🪑 Ban X  x]
// Neu module Ban tat: chi hien Mang di, an nut chon ban
// ─────────────────────────────────────────────────────────────────────────────
class _LocationSelector extends ConsumerWidget {
  final String? tableName;
  final VoidCallback onPickTable;
  final VoidCallback onClearTable;

  const _LocationSelector({
    required this.tableName,
    required this.onPickTable,
    required this.onClearTable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTableActive = ref.watch(tableModuleActiveProvider);
    final hasTable = tableName != null;

    return Row(
      children: [
        // Label
        const Text(
          'Phuc vu tai:',
          style: TextStyle(
            color: Color(0x99FFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 8),

        // [Ban X] pill khi da chon ban
        if (hasTable) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF60A5FA)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.table_restaurant_rounded,
                    color: Color(0xFF93C5FD), size: 13),
                const SizedBox(width: 5),
                Text(
                  tableName!,
                  style: const TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClearTable,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white54, size: 13),
            ),
          ),
        ] else ...[
          // [Mang di] default pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_bag_outlined,
                    color: Colors.white70, size: 13),
                SizedBox(width: 5),
                Text(
                  'Mang di',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Nut "+ Them ban" (chi hien khi module Ban bat)
        if (isTableActive && !hasTable) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onPickTable,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                    style: BorderStyle.solid),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white54, size: 13),
                  SizedBox(width: 4),
                  Text(
                    'Phuc vu tai ban',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE LOCATION CHIP — Compact version nằm trong info row
// Chi hien khi module Ban dang bat
// ─────────────────────────────────────────────────────────────────────────────
class _InlineLocationChip extends ConsumerWidget {
  final String? tableName;
  final VoidCallback onPickTable;
  final VoidCallback onClearTable;

  const _InlineLocationChip({
    required this.tableName,
    required this.onPickTable,
    required this.onClearTable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTableActive = ref.watch(tableModuleActiveProvider);
    if (!isTableActive) return const SizedBox.shrink();

    final hasTable = tableName != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 6),
        GestureDetector(
          onTap: hasTable ? null : onPickTable,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: hasTable
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasTable
                    ? const Color(0xFF60A5FA).withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasTable
                      ? Icons.table_restaurant_rounded
                      : Icons.add_location_alt_rounded,
                  color: hasTable
                      ? const Color(0xFF93C5FD)
                      : Colors.white54,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  hasTable ? tableName! : 'Chon ban',
                  style: TextStyle(
                    color: hasTable
                        ? const Color(0xFF93C5FD)
                        : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasTable) ...[
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onClearTable,
            child: const Icon(Icons.close_rounded,
                color: Colors.white38, size: 13),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POS KITCHEN SEND HINT — Inline hint o info row khi module Bep dang bat
// ─────────────────────────────────────────────────────────────────────────────
class _PosKitchenSendHint extends ConsumerWidget {
  const _PosKitchenSendHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(posKitchenModuleActiveProvider);
    if (!isActive) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE85D20).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFE85D20).withValues(alpha: 0.35), width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded,
              color: Color(0xFFE85D20), size: 12),
          SizedBox(width: 4),
          Text(
            'Bep san sang',
            style: TextStyle(
              color: Color(0xFFE85D20),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK NOTE SHEET — Long press sản phẩm → thêm kèm ghi chú
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// POS ADD ITEMS SHEET — Long press → thêm mon + ghi chu (giống Modules Bàn)
// ─────────────────────────────────────────────────────────────────────────────
class _PosAddItemsSheet extends ConsumerStatefulWidget {
  final String? focusProductId; // scroll tới món này khi mở (từ long press)
  const _PosAddItemsSheet({this.focusProductId});

  @override
  ConsumerState<_PosAddItemsSheet> createState() => _PosAddItemsSheetState();
}

class _PosAddItemsSheetState extends ConsumerState<_PosAddItemsSheet> {
  final Map<String, int> _selected = {};
  final Map<String, TextEditingController> _noteCtrls = {};
  String _search = '';

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kOrange = Color(0xFFE85D20);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);

  @override
  void dispose() {
    for (final c in _noteCtrls.values) c.dispose();
    super.dispose();
  }

  String _fmt(double amount) => _fmtStatic(amount.toInt());

  void _confirm(List<ProductModel> products) {
    if (_selected.isEmpty) { Navigator.pop(context); return; }
    final notifier = ref.read(cartProvider.notifier);
    for (final entry in _selected.entries) {
      final product = products.firstWhere((p) => p.id == entry.key);
      final qty = entry.value.toDouble();
      final note = _noteCtrls[entry.key]?.text.trim();
      if (note != null && note.isNotEmpty) {
        notifier.addProductWithNote(product, qty: qty, note: note);
      } else {
        notifier.addProduct(product, qty: qty);
      }
    }
    HapticFeedback.lightImpact();
    final total = _selected.values.fold(0, (s, v) => s + v);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text('Đã thêm $total món vào giỏ'),
      ]),
      backgroundColor: _kNavy,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(posProductsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _kNavy.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 12),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(color: _kNavy, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tìm sản phẩm...',
                  hintStyle: TextStyle(color: _kNavy.withValues(alpha: 0.4), fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: _kNavy),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _kNavy.withValues(alpha: 0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _kNavy.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _kNavy),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Product list
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (products) {
                  final prodList = (products as List).cast<ProductModel>();
                  final filtered = _search.isEmpty
                      ? prodList
                      : prodList.where((p) =>
                          p.name.containsSearch(_search)).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text('Không tìm thấy sản phẩm',
                        style: TextStyle(color: _kNavy.withValues(alpha: 0.5))),
                    );
                  }

                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      final qty = _selected[p.id] ?? 0;
                      _noteCtrls.putIfAbsent(p.id, () => TextEditingController());

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: qty > 0
                              ? _kNavy.withValues(alpha: 0.06)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: qty > 0
                                ? _kNavy.withValues(alpha: 0.2)
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: _kNavy, fontSize: 14)),
                                        Text(_fmt(p.sellPrice),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _kNavy.withValues(alpha: 0.6))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Qty stepper
                                  Row(
                                    children: [
                                      if (qty > 0)
                                        GestureDetector(
                                          onTap: () => setState(() {
                                            if (qty <= 1) _selected.remove(p.id);
                                            else _selected[p.id] = qty - 1;
                                          }),
                                          child: Container(
                                            width: 32, height: 32,
                                            decoration: BoxDecoration(
                                              color: _kNavy.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8)),
                                            child: const Icon(Icons.remove_rounded,
                                                size: 16, color: _kNavy),
                                          ),
                                        ),
                                      if (qty > 0)
                                        SizedBox(
                                          width: 36,
                                          child: Text('$qty',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16, color: _kNavy)),
                                        ),
                                      GestureDetector(
                                        onTap: () => setState(
                                            () => _selected[p.id] = qty + 1),
                                        child: Container(
                                          width: 36, height: 36,
                                          decoration: BoxDecoration(
                                            color: _kNavy,
                                            borderRadius: BorderRadius.circular(10)),
                                          child: const Icon(Icons.add_rounded,
                                              size: 18, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Note field — chỉ hiện khi qty > 0
                            if (qty > 0)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                                child: TextField(
                                  controller: _noteCtrls[p.id],
                                  style: const TextStyle(fontSize: 12, color: _kNavy),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Ghi chú bếp (vd: ít rau, không cay)',
                                    hintStyle: TextStyle(
                                      fontSize: 12,
                                      color: _kNavy.withValues(alpha: 0.4)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: _kNavy.withValues(alpha: 0.2)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: _kNavy),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Confirm button
            productsAsync.when(
              data: (products) {
                final count = _selected.values.fold(0, (s, v) => s + v);
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  color: Colors.white,
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity, height: 54,
                      child: ElevatedButton(
                        onPressed: () => _confirm(products),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: count > 0 ? _kNavy : _kMuted,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          count > 0 ? 'Thêm $count món vào giỏ' : 'Chọn món',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(height: 80),
              error: (_, __) => const SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }
}

class _KitchenConfirmSheet extends StatefulWidget {
  final CartState cart;
  final Future<void> Function(String? kitchenNote, Map<String, String> itemNotes) onConfirm;
  const _KitchenConfirmSheet({required this.cart, required this.onConfirm});

  @override
  State<_KitchenConfirmSheet> createState() => _KitchenConfirmSheetState();
}

class _KitchenConfirmSheetState extends State<_KitchenConfirmSheet> {
  // Ghi chú chung cho toàn bộ order
  final _kitchenNoteCtrl = TextEditingController();
  // Ghi chú per-item: key = lineId
  final Map<String, TextEditingController> _itemNoteCtrls = {};
  bool _sending = false;

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kOrange = Color(0xFFE85D20);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);
  static const _kInk    = Color(0xFF1A1714);

  @override
  void initState() {
    super.initState();
    // Tạo controller cho từng dòng trong giỏ
    for (final line in widget.cart.lines) {
      _itemNoteCtrls[line.lineId] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _kitchenNoteCtrl.dispose();
    for (final c in _itemNoteCtrls.values) c.dispose();
    super.dispose();
  }

    String _fmt(int v) => fmtMoney(v.toDouble());

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle + Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [_kNavy, Color(0xFF2D2B8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
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
                          color: _kOrange.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.local_fire_department_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Xác nhận gửi bếp',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                            Text('Thêm ghi chú nếu cần rồi bấm gửi',
                              style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Danh sách món — scrollable ───────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                itemCount: widget.cart.lines.length,
                itemBuilder: (_, i) {
                  final line = widget.cart.lines[i];
                  final ctrl = _itemNoteCtrls[line.lineId]!;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _kNavy.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tên + qty + giá
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(line.productName,
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w700,
                                      color: _kInk)),
                              ),
                              Text('×${line.quantity.toInt()}',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: _kNavy.withValues(alpha: 0.5))),
                              const SizedBox(width: 8),
                              Text('${_fmt(line.subtotal.toInt())}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w800,
                                    color: _kNavy)),
                            ],
                          ),
                        ),
                        // Ô ghi chú per-item (luôn hiện — giống Bàn)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                          child: TextField(
                            controller: ctrl,
                            style: const TextStyle(fontSize: 12, color: _kInk),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Ghi chú bếp (vd: ít rau, không cay)',
                              hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: _kNavy.withValues(alpha: 0.4)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: _kNavy.withValues(alpha: 0.2)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: _kNavy.withValues(alpha: 0.2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _kNavy),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Ghi chú chung + nút gửi ─────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Ghi chú chung cho bếp (tuỳ chọn)',
                      style: TextStyle(fontSize: 12, color: _kMuted,
                          fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _kitchenNoteCtrl,
                      maxLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Vd: bàn vội, khách dị ứng hành...',
                        hintStyle: const TextStyle(color: _kMuted, fontSize: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _kBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _kBorder)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _kNavy, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: _kBg,
                        prefixIcon: const Icon(Icons.speaker_notes_outlined,
                            color: _kMuted, size: 16),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : () async {
                          setState(() => _sending = true);
                          // Thu thập ghi chú từng món
                          final itemNotes = <String, String>{};
                          for (final line in widget.cart.lines) {
                            final note = _itemNoteCtrls[line.lineId]?.text.trim() ?? '';
                            if (note.isNotEmpty) itemNotes[line.lineId] = note;
                          }
                          final kitchenNote = _kitchenNoteCtrl.text.trim().isEmpty
                              ? null : _kitchenNoteCtrl.text.trim();
                          Navigator.pop(context);
                          await widget.onConfirm(kitchenNote, itemNotes);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: _sending
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.local_fire_department_rounded, size: 18),
                        label: Text(
                          _sending ? 'Đang gửi...' : 'Gửi bếp ngay',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT ORDERS SHEET — Đơn hàng gần đây
// ─────────────────────────────────────────────────────────────────────────────
class _RecentOrdersSheet extends ConsumerStatefulWidget {
  const _RecentOrdersSheet();
  @override ConsumerState<_RecentOrdersSheet> createState() => _RecentOrdersSheetState();
}

class _RecentOrdersSheetState extends ConsumerState<_RecentOrdersSheet> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isOwner = session?.isOwner == true ||
        session?.role == 'owner' || session?.role == 'manager';
    final posRepo = ref.watch(posRepositoryProvider);
    final ordersStream = posRepo.watchTodayOrders();

    return Container(
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82),
      child: StreamBuilder<List<OrderModel>>(
        stream: ordersStream,
        builder: (_, snap) {
          final orders = snap.data ?? [];
          return Column(children: [
            // Handle + Header
            Padding(padding: const EdgeInsets.fromLTRB(20, 12, 16, 10),
              child: Column(children: [
                Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _kBorder, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                Row(children: [
                  const Icon(Icons.history_rounded, color: _kNavy, size: 20),
                  const SizedBox(width: 8),
                  const Text('Đơn gần đây',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                      color: _kInk, letterSpacing: -0.3)),
                  const SizedBox(width: 8),
                  if (orders.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20)),
                      child: Text('${orders.length} đơn',
                        style: const TextStyle(color: _kOrange, fontSize: 12,
                          fontWeight: FontWeight.w700))),
                  const Spacer(),
                  if (isOwner && orders.isNotEmpty)
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(
                        _fmtV(orders.fold(0.0, (s, o) => s + o.totalAmount).toInt()),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                          color: _kNavy, letterSpacing: -0.5)),
                      const Text('tổng hôm nay',
                        style: TextStyle(fontSize: 9, color: _kMuted)),
                    ]),
                ]),
              ]),
            ),
            const Divider(height: 1, color: _kBorder),

            Expanded(
              child: orders.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long_rounded,
                      size: 64, color: _kMuted.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    const Text('Chưa có đơn nào hôm nay',
                      style: TextStyle(fontSize: 15, color: _kMuted,
                        fontWeight: FontWeight.w600)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: orders.length,
                    itemBuilder: (ctx, i) {
                      final o = orders[i];
                      final expanded = _expandedId == o.id;
                      return _PosOrderCard(
                        order: o, isOwner: isOwner,
                        isExpanded: expanded,
                        onTap: () => setState(() =>
                          _expandedId = expanded ? null : o.id),
                      );
                    },
                  ),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Order Card ───────────────────────────────────────────────────────────────
class _PosOrderCard extends ConsumerWidget {
  final OrderModel order;
  final bool isOwner, isExpanded;
  final VoidCallback onTap;
  const _PosOrderCard({required this.order, required this.isOwner,
    required this.isExpanded, required this.onTap});

  String _payLabel(String m) => switch(m) {
    'cash' => '💵 Tiền mặt', 'transfer' => '🏦 Chuyển khoản',
    'card'  => '💳 Thẻ', _ => m,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dt = DateTime.tryParse(order.createdAt) ?? DateTime.now();
    final t = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpanded ? _kNavy.withValues(alpha: 0.35) : _kBorder,
            width: isExpanded ? 1.5 : 1),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))]),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              Container(width: 8, height: 8,
                decoration: BoxDecoration(
                  color: order.status == 'completed'
                    ? const Color(0xFF4CAF50) : const Color(0xFFC62828),
                  shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.orderNumber,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: _kInk, letterSpacing: 0.2)),
                const SizedBox(height: 2),
                Wrap(spacing: 8, children: [
                  Text(t, style: const TextStyle(fontSize: 11, color: _kMuted)),
                  Text(_payLabel(order.paymentMethod),
                    style: const TextStyle(fontSize: 11, color: _kMuted)),
                  if (order.customerName != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.person_outline_rounded, size: 11, color: _kMuted),
                      const SizedBox(width: 2),
                      Text(order.customerName!,
                        style: const TextStyle(fontSize: 11, color: _kMuted)),
                    ]),
                ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_fmtV(order.totalAmount.toInt()),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                    color: _kNavy, letterSpacing: -0.5)),
                const SizedBox(height: 2),
                Icon(isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  size: 16, color: _kMuted),
              ]),
            ]),
          ),

          // Expanded detail
          if (isExpanded)
            FutureBuilder<List<OrderItemModel>>(
              future: ref.read(posRepositoryProvider).getOrderItems(order.id),
              builder: (_, snap) {
                final items = snap.data ?? [];
                return Column(children: [
                  const Divider(height: 1, color: _kBorder),
                  Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(children: [
                      ...items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: _kNavy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6)),
                            child: Center(child: Text(
                              '${item.quantity.toInt()}',
                              style: const TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w800, color: _kNavy)))),
                          const SizedBox(width: 10),
                          Expanded(child: Text(item.productName,
                            style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600, color: _kInk))),
                          Text(_fmtV(item.subtotal.toInt()),
                            style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w700, color: _kInk)),
                        ]),
                      )),
                      if (order.note != null && order.note!.isNotEmpty) ...[
                        const Divider(height: 16, color: _kBorder),
                        Row(children: [
                          const Icon(Icons.notes_rounded, size: 13, color: _kOrange),
                          const SizedBox(width: 6),
                          Expanded(child: Text(order.note!,
                            style: const TextStyle(fontSize: 12, color: _kOrange,
                              fontStyle: FontStyle.italic))),
                        ]),
                      ],
                    ]),
                  ),
                ]);
              },
            ),
        ]),
      ),
    );
  }
}


String _fmtV(int v) {
  if (v < 0) return '-${_fmtV(-v)}';
  return '${v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} đ';
}

