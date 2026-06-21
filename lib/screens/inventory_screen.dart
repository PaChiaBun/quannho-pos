<<<<<<< HEAD
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/utils/money_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers/app_providers.dart';
import '../modules/kho/providers/kho_providers.dart';
import '../modules/kho/repository/kho_repository.dart';
import '../modules/kho/screens/receive_stock_sheet.dart';
import '../modules/kho/screens/phieu_nhap_hang_screen.dart';
import '../modules/kho/screens/po_detail_screen.dart';
import '../modules/kho/screens/supplier_list_screen.dart';
import '../core/services/product_image_service.dart';
import '../modules/topping/topping_group_repository.dart';
=======
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../core/providers/app_providers.dart';
import '../core/database/app_database.dart';
import '../modules/kho/providers/kho_providers.dart';
import '../modules/kho/repository/kho_repository.dart';
import '../modules/kho/screens/receive_stock_sheet.dart';
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

// ─ Màu local ─────────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E1C5E);
const _kNavyL  = Color(0xFF2D2B8A);
const _kOrange = Color(0xFFE85D20);
const _kInk    = Color(0xFF1A1207);
const _kMuted  = Color(0xFF9E9085);
const _kBg     = Color(0xFFFAF7F2);
const _kGreen  = Color(0xFF2E7D32);
const _kRed    = Color(0xFFC62828);
const _kBorder = Color(0xFFE0D8CC);

// ─────────────────────────────────────────────────────────────────────────────
// INVENTORY SCREEN — Màn hình Kho hàng
// ─────────────────────────────────────────────────────────────────────────────
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
<<<<<<< HEAD
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  int _tabIndex = 0;
  bool _phieuNhapEnabled = false;
  static const _kPrefKey = 'phieu_nhap_enabled';
  static const _kViolet  = Color(0xFF7C3AED);
=======
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  int _tabIndex = 0;
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _buildTabCtrl(2); // Hàng hoá & Menu / Cảnh báo
    _loadPref();
  }

  void _buildTabCtrl(int length) {
    _tabCtrl = TabController(length: length, vsync: this)
=======
    _tabCtrl = TabController(length: 3, vsync: this)
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
      ..addListener(() {
        if (!_tabCtrl.indexIsChanging) return;
        setState(() => _tabIndex = _tabCtrl.index);
      });
  }

<<<<<<< HEAD
  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kPrefKey) ?? false;
    if (enabled != _phieuNhapEnabled) {
      setState(() {
        _phieuNhapEnabled = enabled;
        _tabCtrl.dispose();
        _buildTabCtrl(enabled ? 5 : 2);
      });
    }
  }

  Future<void> _togglePhieuNhap(bool val) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefKey, val);
    setState(() {
      _phieuNhapEnabled = val;
      final wasOnLastTab = _tabIndex >= (val ? 4 : 1);
      _tabCtrl.dispose();
      _buildTabCtrl(val ? 5 : 2);
      if (wasOnLastTab && !val) _tabIndex = 0;
    });
  }

=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(khoStatsProvider);
    final allAsync   = ref.watch(allStockProvider);
    final lowAsync   = ref.watch(lowStockKhoProvider);
    final outAsync   = ref.watch(outOfStockProvider);

    // Tab counts
    final allCount = allAsync.value?.length ?? 0;
    final lowCount = lowAsync.value?.length ?? 0;
    final outCount = outAsync.value?.length ?? 0;

<<<<<<< HEAD
    final mainBody = Stack(
        children: [
          // ── Main Column ─────────────────────────────────────────────
          Column(
            children: [
          _buildHeader(statsAsync),

          // ── Tabs (luôn scroll vì nhiều tab) ──────────────────────
=======
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────
          _buildHeader(statsAsync),

          // ── Tabs ───────────────────────────────────────────────────
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
          Container(
            color: _kNavy,
            child: TabBar(
              controller: _tabCtrl,
              indicatorColor: _kOrange,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
<<<<<<< HEAD
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: [
                // Tất cả chỉ hiện khi bật Phiếu nhập hàng
                if (_phieuNhapEnabled)
                  Tab(text: 'Tất cả ($allCount)'),
                const Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shopping_bag_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('Hàng hoá & Menu'),
                ])),
                // Nguyên liệu chỉ hiện khi bật Phiếu nhập hàng
                if (_phieuNhapEnabled)
                  const Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.egg_alt_rounded, size: 14),
                    SizedBox(width: 4),
                    Text('Nguyên liệu'),
                  ])),
                Tab(child: _TabLabel('Cảnh báo', lowCount + outCount,
                    color: outCount > 0
                        ? const Color(0xFFC62828)
                        : const Color(0xFFFF6F00))),
                if (_phieuNhapEnabled)
                  const Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('Phiếu nhập'),
                    ]),
                  ),
=======
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                Tab(text: 'Tất cả ($allCount)'),
                Tab(child: _TabLabel('Sắp hết', lowCount,
                    color: const Color(0xFFFF6F00))),
                Tab(child: _TabLabel('Hết hàng', outCount,
                    color: const Color(0xFFC62828))),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
              ],
            ),
          ),

<<<<<<< HEAD
          // ── Search bar (ẩn khi tab phiếu nhập) ───────────────────
          // ‼️ FIX: search bar ẩn khi tab Phiếu nhập (index 4 khi enabled, không phải 5)
          // Khi enabled: tabs 0=Tất cả, 1=Hàng hoá, 2=Nguyên liệu, 3=Cảnh báo, 4=Phiếu nhập
          if (!(_phieuNhapEnabled && _tabIndex == 4))
            _buildSearchBar(),
=======
          // ── Search bar ─────────────────────────────────────────────
          _buildSearchBar(),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

          // ── Content ────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
<<<<<<< HEAD
               // Tab 0 (enabled): Tất cả
                if (_phieuNhapEnabled)
                  _StockList(
                    watchItems: (ref) => ref.watch(allStockProvider),
                    filterQuery: _searchCtrl.text,
                    onReceive: _openReceiveSheet,
                    onAdjust: _openAdjustDialog,
                    onHistory: _openHistorySheet,
                    onEdit: _openEditProduct,
                    onTopping: _openToppingSheet,
                    featureCard: _buildFeatureCard(),
                  ),
                // Tab 1 (enabled) / Tab 0 (disabled): Hàng hoá & Menu
                _StockList(
                  watchItems: (ref) => ref.watch(allStockProvider).whenData(
                    (list) => list.where((i) =>
                        i.productType == 'purchased' ||
                        i.productType == 'finished').toList()),
=======
                _StockList(
                  watchItems: (ref) => ref.watch(allStockProvider),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                  filterQuery: _searchCtrl.text,
                  onReceive: _openReceiveSheet,
                  onAdjust: _openAdjustDialog,
                  onHistory: _openHistorySheet,
                  onEdit: _openEditProduct,
<<<<<<< HEAD
                  onTopping: _openToppingSheet, // ✅ thêm nút Topping
                  emptyMsg: 'Chưa có hàng hoá/menu nào',
                  emptyIcon: Icons.shopping_bag_rounded,
                  emptyColor: _kMuted,
                  featureCard: _phieuNhapEnabled ? null : _buildFeatureCard(),
                ),

                // Tab 2: Nguyên liệu — chỉ khi bật Phiếu nhập
                if (_phieuNhapEnabled)
                  _StockList(
                    watchItems: (ref) => ref.watch(allStockProvider).whenData(
                      (list) => list.where((i) =>
                          i.productType == 'ingredient' ||
                          i.productType == 'semi_finished').toList()),
                    filterQuery: _searchCtrl.text,
                    onReceive: _openReceiveSheet,
                    onAdjust: _openAdjustDialog,
                    onHistory: _openHistorySheet,
                    onEdit: _openEditProduct,
                    emptyMsg: 'Chưa có nguyên liệu nào\nThêm SP với danh mục "Nguyên liệu"',
                    emptyIcon: Icons.egg_alt_rounded,
                    emptyColor: _kMuted,
                  ),
                // Tab 3 (enabled) / Tab 2 (disabled): Cảnh báo kho
                _StockList(
                  watchItems: (ref) => ref.watch(allStockProvider).whenData(
                    (list) => list.where((i) =>
                        i.status == StockStatus.low ||
                        i.status == StockStatus.outOfStock).toList()
                      ..sort((a, b) {
                        if (a.status == StockStatus.outOfStock &&
                            b.status != StockStatus.outOfStock) return -1;
                        if (b.status == StockStatus.outOfStock &&
                            a.status != StockStatus.outOfStock) return 1;
                        return a.name.compareTo(b.name);
                      })),
=======
                ),
                _StockList(
                  watchItems: (ref) => ref.watch(lowStockKhoProvider),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                  filterQuery: _searchCtrl.text,
                  onReceive: _openReceiveSheet,
                  onAdjust: _openAdjustDialog,
                  onHistory: _openHistorySheet,
                  onEdit: _openEditProduct,
<<<<<<< HEAD
                  onTopping: _openToppingSheet,
                  emptyMsg: 'Tất cả sản phẩm đang đủ hàng 🎉',
                  emptyIcon: Icons.check_circle_rounded,
                  emptyColor: _kGreen,
                ),
                // Tab 4 (enabled): Phiếu nhập
                if (_phieuNhapEnabled)
                  _PhieuNhapListTab(onCreateNew: _openPhieuNhap),
              ],
            ),
          ),
        ], // end Column children
          ), // end Column

          // ── FAB lịch sử — Stack child, tránh bị mascot che ────────
          Positioned(
            right: 16,
            bottom: 80,
            child: Tooltip(
              message: 'Biến động kho gần đây',
              child: FloatingActionButton(
                heroTag: 'kho_fab_history',
                onPressed: _openRecentMovements,
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                mini: true,
                elevation: 4,
                child: const Icon(Icons.history_rounded, size: 20),
              ),
            ),
          ),
        ], // end Stack children
      );

    return Scaffold(
      backgroundColor: _kBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return Row(children: [
              Expanded(flex: 3, child: mainBody),
              SizedBox(
                width: 280,
                child: _InventoryRightPanel(statsAsync: statsAsync),
              ),
            ]);
          }
          return mainBody;
        },
      ),
    );
  }

  // ── Feature Toggle Card ─────────────────────────────────────────────────────
  Widget _buildFeatureCard() => _FeatureToggleCard(
    enabled: _phieuNhapEnabled,
    onToggle: _togglePhieuNhap,
  );

=======
                  emptyMsg: 'Không có sản phẩm nào sắp hết 🎉',
                  emptyIcon: Icons.check_circle_rounded,
                  emptyColor: _kGreen,
                ),
                _StockList(
                  watchItems: (ref) => ref.watch(outOfStockProvider),
                  filterQuery: _searchCtrl.text,
                  onReceive: _openReceiveSheet,
                  onAdjust: _openAdjustDialog,
                  onHistory: _openHistorySheet,
                  onEdit: _openEditProduct,
                  emptyMsg: 'Không có sản phẩm hết hàng 🎉',
                  emptyIcon: Icons.inventory_rounded,
                  emptyColor: _kGreen,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              heroTag: 'kho_fab_history',
              onPressed: _openRecentMovements,
              icon: const Icon(Icons.history_rounded),
              label: const Text('Lịch sử',
                style: TextStyle(fontWeight: FontWeight.w700)),
              backgroundColor: _kNavy,
              foregroundColor: Colors.white,
              elevation: 4,
            )
          : FloatingActionButton(
              heroTag: 'kho_fab_add',
              onPressed: () {},
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            ),
    );
  }

>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  // ─────────────────────────────────────────────────────────────────────────
  // HEADER — Thống kê + title
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(AsyncValue<KhoStats> statsAsync) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kNavy, _kNavyL],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  const Text('Kho hàng',
                    style: TextStyle(
                      color: Colors.white,
<<<<<<< HEAD
                      fontSize: 24, fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
=======
                      fontSize: 20, fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                    )),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded,
                        color: Colors.white, size: 28),
                    onPressed: _openAddProduct,
                    tooltip: 'Thêm sản phẩm',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stat cards
              statsAsync.when(
                loading: () => const SizedBox(height: 72,
                  child: Center(child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Row(
                  children: [
                    _HeaderStat(
                      value: '${stats.totalItems}',
                      label: 'Sản phẩm',
                      icon: Icons.category_rounded,
                    ),
                    _HeaderStat(
                      value: '${stats.lowStockItems}',
                      label: 'Sắp hết',
                      icon: Icons.warning_amber_rounded,
                      highlight: stats.lowStockItems > 0,
                    ),
                    _HeaderStat(
                      value: '${stats.outOfStockItems}',
                      label: 'Hết hàng',
                      icon: Icons.remove_shopping_cart_rounded,
                      highlight: stats.outOfStockItems > 0,
                      highlightColor: _kRed,
                    ),
                    _HeaderStat(
                      value: _fmtShort(stats.totalValue),
                      label: 'Giá trị kho',
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Tìm sản phẩm, SKU...',
          hintStyle: const TextStyle(color: _kMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: _kMuted, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: _kMuted, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: _kBg,
          border: OutlineInputBorder(
<<<<<<< HEAD
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
=======
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
            borderSide: const BorderSide(color: _kNavy, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _openReceiveSheet(StockItem item) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiveStockSheet(product: item),
    );
  }

  void _openAdjustDialog(StockItem item) {
    showDialog(
      context: context,
      builder: (ctx) => _AdjustDialog(item: item),
    );
  }

  void _openHistorySheet(StockItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistorySheet(item: item),
    );
  }

  void _openRecentMovements() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RecentMovementsSheet(),
    );
  }

<<<<<<< HEAD
  void _openPhieuNhap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PhieuNhapHangScreen(),
        fullscreenDialog: true,
      ),
    );
  }

=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  void _openAddProduct() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProductSheet(
        product: null,
<<<<<<< HEAD
        onSaved: (name, price, cost, cat, unit, minStock, {String? imageUrl, bool isTopping = false, String toppingUnit = 'phần'}) async {
          final productType = cat == 'Nguyên liệu' ? 'ingredient' : 'finished';
=======
        onSaved: (name, price, cost, cat, unit, minStock) async {
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
          await ref.read(productRepositoryProvider).create(
            name: name, sellPrice: price, costPrice: cost,
            category: cat.isEmpty ? null : cat,
            unit: unit.isEmpty ? 'phần' : unit,
<<<<<<< HEAD
            productType: productType,
            minStock: minStock, isAvailable: true,
            imageUrl: imageUrl,
            isTopping: isTopping,
            toppingUnit: isTopping ? toppingUnit : null,
=======
            minStock: minStock, isAvailable: true,
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
          );
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
<<<<<<< HEAD
              content: Text('✅ Đã thêm "$name"${isTopping ? ' (Topping)' : ''}'),
=======
              content: Text('✅ Đã thêm "$name"'),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
              behavior: SnackBarBehavior.floating));
          }
        },
      ),
    );
  }

<<<<<<< HEAD
  void _openToppingSheet(StockItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ToppingLinkSheet(product: item),
    );
  }

=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  void _openEditProduct(StockItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProductSheet(
        product: item,
<<<<<<< HEAD
        onSaved: (name, price, cost, cat, unit, minStock, {String? imageUrl, bool isTopping = false, String toppingUnit = 'phần'}) async {
          final productType = cat == 'Nguyên liệu' ? 'ingredient' : 'finished';
          final sellPriceInt = price.isNaN || price.isInfinite ? 0 : price.truncate();
          final costPriceInt  = cost.isNaN  || cost.isInfinite  ? 0 : cost.truncate();
          final minStockInt   = minStock.isNaN ? 0 : minStock.truncate();
          final updateMap = {
            'name': name,
            'sell_price': sellPriceInt,
            'cost_price': costPriceInt,
            'category': cat.isEmpty ? null : cat,
            'unit': unit.isEmpty ? 'phần' : unit,
            'min_stock': minStockInt,
            'product_type': productType,
            'is_topping': isTopping,
            'topping_unit': isTopping ? toppingUnit : null,
            if (imageUrl != null) 'image_url': imageUrl,
          };
          await ref.read(productRepositoryProvider).update(item.id, updateMap);
=======
        onSaved: (name, price, cost, cat, unit, minStock) async {
          await ref.read(productRepositoryProvider).update(
            item.id,
            CoreProductsCompanion(
              name: Value(name),
              sellPrice: Value(price),
              costPrice: Value(cost),
              category: Value(cat.isEmpty ? null : cat),
              unit: Value(unit.isEmpty ? 'phần' : unit),
              minStock: Value(minStock),
            ),
          );
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Text('✅ Cập nhật "$name" thành công'),
              behavior: SnackBarBehavior.floating));
          }
        },
        onDelete: () async {
          await ref.read(productRepositoryProvider).softDelete(item.id);
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
<<<<<<< HEAD
              content: Text('Ẩn "${item.name}" thành công'),
=======
              content: Text('Ýên "${item.name}" đã bị ẩn'),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
              behavior: SnackBarBehavior.floating));
          }
        },
      ),
    );
  }

<<<<<<< HEAD
  String _fmtShort(double v) => fmtMoney(v);
=======
  String _fmtShort(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
}

// ─────────────────────────────────────────────────────────────────────────────
// STOCK LIST — Generic list widget tái sử dụng cho 3 tab
// ─────────────────────────────────────────────────────────────────────────────
class _StockList extends ConsumerWidget {
  final AsyncValue<List<StockItem>> Function(WidgetRef ref) watchItems;
  final String filterQuery;
  final void Function(StockItem) onReceive;
  final void Function(StockItem) onAdjust;
  final void Function(StockItem) onHistory;
  final void Function(StockItem) onEdit;
<<<<<<< HEAD
  final void Function(StockItem)? onTopping; // Sheet cấu hình topping riêng
  final String emptyMsg;
  final IconData emptyIcon;
  final Color emptyColor;
  final Widget? featureCard;  // Optional Feature Toggle Card
=======
  final String emptyMsg;
  final IconData emptyIcon;
  final Color emptyColor;
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

  const _StockList({
    required this.watchItems,
    required this.filterQuery,
    required this.onReceive,
    required this.onAdjust,
    required this.onHistory,
    required this.onEdit,
<<<<<<< HEAD
    this.onTopping,
    this.emptyMsg = 'Không có sản phẩm nào',
    this.emptyIcon = Icons.inventory_2_rounded,
    this.emptyColor = _kMuted,
    this.featureCard,
=======
    this.emptyMsg = 'Không có sản phẩm nào',
    this.emptyIcon = Icons.inventory_2_rounded,
    this.emptyColor = _kMuted,
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = watchItems(ref);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _kNavy)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (items) {
<<<<<<< HEAD
=======
        // Apply search filter
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
        final filtered = filterQuery.isEmpty
            ? items
            : items
                .where((i) =>
                    i.name.toLowerCase().contains(filterQuery.toLowerCase()) ||
                    (i.sku?.toLowerCase()
                            .contains(filterQuery.toLowerCase()) ??
                        false))
                .toList();

<<<<<<< HEAD
        if (filtered.isEmpty && featureCard == null) {
=======
        if (filtered.isEmpty) {
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
          return _buildEmpty(emptyMsg, emptyIcon, emptyColor);
        }

        return ListView.builder(
<<<<<<< HEAD
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: filtered.isEmpty ? 1 : filtered.length + (featureCard != null ? 1 : 0),
          itemBuilder: (_, i) {
            // Nếu list rỗng chỉ hiện feature card
            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: featureCard!,
              );
            }
            // Item cuối → feature card
            if (featureCard != null && i == filtered.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: featureCard!,
              );
            }
            return _StockCard(
              item: filtered[i],
              onReceive: onReceive,
              onAdjust: onAdjust,
              onHistory: onHistory,
              onEdit: onEdit,
              onTopping: onTopping,
            )
                .animate(delay: (i * 40).ms)
                .fadeIn(duration: 200.ms)
                .slideX(begin: 0.05, end: 0, duration: 200.ms);
          },
=======
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _StockCard(
            item: filtered[i],
            onReceive: onReceive,
            onAdjust: onAdjust,
            onHistory: onHistory,
            onEdit: onEdit,
          )
              .animate(delay: (i * 40).ms)
              .fadeIn(duration: 200.ms)
              .slideX(begin: 0.05, end: 0, duration: 200.ms),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
        );
      },
    );
  }

<<<<<<< HEAD

  Widget _buildEmpty(String msg, IconData icon, Color color) {

=======
  Widget _buildEmpty(String msg, IconData icon, Color color) {
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: color.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(msg,
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
<<<<<<< HEAD
// FEATURE TOGGLE CARD — Bật/tắt tính năng Phiếu nhập
// ─────────────────────────────────────────────────────────────────────────────
class _FeatureToggleCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _FeatureToggleCard({required this.enabled, required this.onToggle});

  static const _kViolet   = Color(0xFF5B21B6);
  static const _kVioletL  = Color(0xFF7C3AED);
  static const _kVioletBg = Color(0xFFF5F3FF);
  static const _kInk      = Color(0xFF1A1207);
  static const _kMuted    = Color(0xFF6B7280);
  static const _kBorder   = Color(0xFFE5E7EB);

  // Danh sách tính năng
  static const _features = [
    (icon: Icons.history_edu_rounded,   label: 'Lưu lịch sử nhập hàng từ nhà cung cấp'),
    (icon: Icons.inventory_2_rounded,   label: 'Tự động cập nhật tồn kho sau mỗi lần nhập'),
    (icon: Icons.account_balance_wallet_rounded, label: 'Ghi chi phí nhập vào sổ tài chính'),
    (icon: Icons.manage_search_rounded, label: 'Tra cứu & đối soát phiếu nhập theo ngày'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled
              ? _kVioletL.withValues(alpha: 0.35)
              : _kBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: enabled
                ? _kViolet.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            child: Row(
              children: [
                // Icon box
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: enabled
                        ? const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: enabled ? null : _kVioletBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 22,
                    color: enabled ? Colors.white : _kVioletL,
                  ),
                ),
                const SizedBox(width: 13),

                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Phiếu nhập hàng',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _kInk,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          enabled
                              ? 'Đang hoạt động · Tab Phiếu nhập hiển thị'
                              : 'Tắt · Tính năng quản lý kho nâng cao',
                          key: ValueKey(enabled),
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: enabled ? _kVioletL : _kMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Toggle
                Switch.adaptive(
                  value: enabled,
                  onChanged: onToggle,
                  activeColor: Colors.white,
                  activeTrackColor: _kVioletL,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFD1D5DB),
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                ),
              ],
            ),
          ),

          // ── Phần mô tả (khi tắt) ─────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _buildDescription(),
            crossFadeState: enabled
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 280),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Container(
          height: 1,
          color: const Color(0xFFF3F4F6),
        ),

        // Feature list
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(
            'Tính năng bao gồm',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kMuted,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ..._features.map((f) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _kVioletBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(f.icon, size: 15, color: _kVioletL),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  f.label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: const Color(0xFF374151),
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        )),

        // Tag phù hợp
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Phù hợp cho nhà hàng & quán cần quản lý kho chuyên nghiệp',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: const Color(0xFF15803D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHIẾU NHẬP LIST TAB — Tab 4 khi bật tính năng
// ─────────────────────────────────────────────────────────────────────────────



class _PhieuNhapListTab extends ConsumerStatefulWidget {
  final VoidCallback onCreateNew;
  const _PhieuNhapListTab({required this.onCreateNew});
  @override
  ConsumerState<_PhieuNhapListTab> createState() => _PhieuNhapListTabState();
}

class _PhieuNhapListTabState extends ConsumerState<_PhieuNhapListTab> {
  static const _kViolet = Color(0xFF7C3AED);

  // Filter state
  String _filterPeriod = 'all'; // all | today | week | month | cancelled
  String? _filterSupplier;      // null = tất cả

  List<PurchaseOrderModel> _applyFilter(List<PurchaseOrderModel> orders) {
    // Nếu filter = 'cancelled' → chỉ hiện phiếu đã huỷ
    if (_filterPeriod == 'cancelled') {
      return orders.where((o) => o.status == 'cancelled').toList();
    }

    // Các filter khác: ẩn phiếu đã huỷ
    return orders.where((o) {
      if (o.status == 'cancelled') return false;

      // Lọc NCC
      if (_filterSupplier != null && _filterSupplier!.isNotEmpty) {
        if ((o.supplierName ?? '') != _filterSupplier) return false;
      }
      // Lọc kỳ
      if (_filterPeriod == 'all') return true;
      final dt = DateTime.tryParse(o.createdAt)?.toLocal();
      if (dt == null) return false;
      final now = DateTime.now();
      if (_filterPeriod == 'today') {
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      }
      if (_filterPeriod == 'week') {
        return now.difference(dt).inDays <= 7;
      }
      if (_filterPeriod == 'month') {
        return dt.year == now.year && dt.month == now.month;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final posAsync = ref.watch(purchaseOrdersProvider);

    return posAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kNavy)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (allOrders) {
        // Lấy danh sách NCC duy nhất
        final suppliers = allOrders
            .where((o) => o.supplierName?.isNotEmpty == true)
            .map((o) => o.supplierName!)
            .toSet()
            .toList();
        final filtered = _applyFilter(allOrders);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Column(children: [

                  // ── Header row ───────────────────────────────────────────
                  Row(children: [
                    Text('Lịch sử nhập hàng',
                        style: GoogleFonts.outfit(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1207))),
                    const Spacer(),
                    // Badge đã huỷ
                    GestureDetector(
                      onTap: () => setState(() =>
                          _filterPeriod = _filterPeriod == 'cancelled' ? 'all' : 'cancelled'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _filterPeriod == 'cancelled'
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.cancel_outlined, size: 12,
                              color: _filterPeriod == 'cancelled'
                                  ? Colors.white : const Color(0xFFDC2626)),
                          const SizedBox(width: 4),
                          Text('Đã huỷ',
                              style: GoogleFonts.outfit(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: _filterPeriod == 'cancelled'
                                      ? Colors.white : const Color(0xFFDC2626))),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: widget.onCreateNew,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text('Tạo phiếu',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kViolet,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  // ── Date filter card (luôn hiện, dim khi xem Đã huỷ) ────
                  Opacity(
                    opacity: _filterPeriod == 'cancelled' ? 0.4 : 1.0,
                    child: IgnorePointer(
                      ignoring: _filterPeriod == 'cancelled',
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F0FA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          _segmentChip('Tất cả',   'all'),
                          _segmentChip('Hôm nay',  'today'),
                          _segmentChip('Tuần này', 'week'),
                          _segmentChip('Tháng',    'month'),
                          if (suppliers.isNotEmpty) ...[
                            Container(width: 1, height: 18, color: const Color(0xFFD8D3EE),
                                margin: const EdgeInsets.symmetric(horizontal: 2)),
                            _supplierDropdown(suppliers),
                          ],
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Quản lý NCC ──────────────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SupplierListScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E0F5)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: _kViolet.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.store_rounded, size: 14, color: _kViolet),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Quản lý nhà cung cấp',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A1207)))),
                        const Icon(Icons.chevron_right_rounded, size: 16,
                            color: Color(0xFF9E9085)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),

            if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      _filterPeriod == 'cancelled'
                          ? Icons.cancel_outlined
                          : Icons.receipt_long_outlined,
                      size: 64,
                      color: const Color(0xFF9E9085).withOpacity(0.4)),
                    const SizedBox(height: 16),
                    Text(
                      _filterPeriod == 'cancelled'
                          ? 'Chưa có phiếu nào bị huỷ'
                          : allOrders.isEmpty
                              ? 'Chưa có phiếu nhập nào'
                              : 'Không có phiếu trong kỳ này',
                      style: GoogleFonts.outfit(fontSize: 15,
                          color: const Color(0xFF9E9085),
                          fontWeight: FontWeight.w600)),
                    if (_filterPeriod != 'cancelled' && allOrders.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Nhấn "Tạo phiếu" để bắt đầu',
                          style: GoogleFonts.outfit(fontSize: 13,
                              color: const Color(0xFF9E9085))),
                    ],
                  ]),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _PoCard(order: filtered[i])
                        .animate(delay: (i * 50).ms)
                        .fadeIn(duration: 250.ms)
                        .slideY(begin: 0.05, end: 0),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Chip dạng segmented control (dùng trong date filter card)
  Widget _segmentChip(String label, String value) {
    final active = _filterPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filterPeriod = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active ? [
              BoxShadow(color: Colors.black.withOpacity(0.08),
                  blurRadius: 6, offset: const Offset(0, 2)),
            ] : [],
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? _kViolet : const Color(0xFF8B80A8))),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value,
      {Color? activeColor}) {
    final active = _filterPeriod == value;
    final color  = activeColor ?? _kViolet;
    return GestureDetector(
      onTap: () => setState(() => _filterPeriod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? color : const Color(0xFFE5E0F5)),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: active ? Colors.white : const Color(0xFF6B7280))),
      ),
    );
  }

  Widget _supplierDropdown(List<String> suppliers) {
    final active = _filterSupplier != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? _kViolet.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _filterSupplier,
          isDense: true,
          icon: Icon(Icons.expand_more_rounded, size: 14,
              color: active ? _kViolet : const Color(0xFF8B80A8)),
          hint: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.store_rounded, size: 11,
                color: const Color(0xFF8B80A8)),
            const SizedBox(width: 3),
            Text('NCC', style: GoogleFonts.outfit(
                fontSize: 11.5, color: const Color(0xFF8B80A8),
                fontWeight: FontWeight.w500)),
          ]),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('Tất cả NCC',
                  style: GoogleFonts.outfit(fontSize: 12)),
            ),
            ...suppliers.map((s) => DropdownMenuItem<String?>(
              value: s,
              child: Text(s, style: GoogleFonts.outfit(fontSize: 12)),
            )),
          ],
          onChanged: (v) => setState(() => _filterSupplier = v),
          selectedItemBuilder: (_) => [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.store_rounded, size: 11, color: _kViolet),
              const SizedBox(width: 3),
              Text('NCC', style: GoogleFonts.outfit(
                  fontSize: 11.5, color: _kViolet,
                  fontWeight: FontWeight.w700)),
            ]),
            ...suppliers.map((s) => Text(s,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 11, color: _kViolet,
                    fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PO CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PoCard extends StatelessWidget {
  final PurchaseOrderModel order;
  const _PoCard({required this.order});

  static const _kViolet = Color(0xFF7C3AED);
  static const _kNavy   = Color(0xFF1C2151);
  static const _kGreen  = Color(0xFF059669);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kRed    = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(order.createdAt)?.toLocal();
    final dateStr = date != null
        ? '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}  ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}'
        : '—';

    final hasSupplier = order.supplierName?.isNotEmpty == true;
    final itemCount   = order.items.length;
    final isCancelled = order.status == 'cancelled';

    final itemSummary = order.items.take(3).map((i) {
      final qty = i.quantity % 1 == 0
          ? i.quantity.toInt().toString()
          : i.quantity.toStringAsFixed(1);
      return '${i.productName} ×$qty';
    }).join(' · ');
    final hasMore = order.items.length > 3;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PoDetailScreen(po: order)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isCancelled ? const Color(0xFFF9F9F9) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isCancelled
                  ? const Color(0xFFE5E5E5)
                  : const Color(0xFFEDE7FE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(children: [
          // Top row
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: isCancelled
                  ? const Color(0xFFF5F5F5)
                  : const Color(0xFFF9F7FF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isCancelled
                      ? Colors.grey.withOpacity(0.15)
                      : _kViolet.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long_rounded,
                    color: isCancelled ? Colors.grey : _kViolet, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dateStr, style: GoogleFonts.outfit(
                    fontSize: 12, color: _kMuted, fontWeight: FontWeight.w500)),
                Text('$itemCount sản phẩm nhập',
                    style: GoogleFonts.outfit(fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isCancelled ? Colors.grey : _kNavy)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmtMoney(order.totalAmount),
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w900,
                        color: isCancelled ? Colors.grey : _kViolet,
                        decoration: isCancelled
                            ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? Colors.grey.shade200
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(isCancelled ? 'Đã huỷ' : 'Đã nhập',
                      style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          color: isCancelled ? Colors.grey.shade600 : _kGreen,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),

          // Bottom: supplier + items
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.store_rounded, size: 13,
                    color: hasSupplier ? _kViolet : _kMuted),
                const SizedBox(width: 6),
                Text(
                  hasSupplier ? order.supplierName! : 'Không có nhà cung cấp',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: hasSupplier ? FontWeight.w700 : FontWeight.w500,
                    color: hasSupplier ? _kNavy : _kMuted,
                  ),
                ),
              ]),
              if (itemSummary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.inventory_2_rounded, size: 13, color: _kMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    hasMore ? '$itemSummary  +${order.items.length - 3} thêm' : itemSummary,
                    style: GoogleFonts.outfit(fontSize: 12, color: _kMuted,
                        fontWeight: FontWeight.w500),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  )),
                ]),
              ],
              if (order.note?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.notes_rounded, size: 13, color: _kMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(order.note!,
                      style: GoogleFonts.outfit(fontSize: 12, color: _kMuted,
                          fontStyle: FontStyle.italic),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ],
              // Tap hint
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('Xem chi tiết',
                    style: GoogleFonts.outfit(fontSize: 11, color: _kViolet,
                        fontWeight: FontWeight.w600)),
                const Icon(Icons.chevron_right_rounded, size: 14, color: _kViolet),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
// STOCK CARD — 1 item trong danh sách
// ─────────────────────────────────────────────────────────────────────────────
class _StockCard extends StatelessWidget {
  final StockItem item;
  final void Function(StockItem) onReceive;
  final void Function(StockItem) onAdjust;
  final void Function(StockItem) onHistory;
  final void Function(StockItem) onEdit;
<<<<<<< HEAD
  final void Function(StockItem)? onTopping;
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

  const _StockCard({
    required this.item,
    required this.onReceive,
    required this.onAdjust,
    required this.onHistory,
    required this.onEdit,
<<<<<<< HEAD
    this.onTopping,
  });

  // Map danh mục → icon + màu (đồng bộ với Modules Bán hàng)
  static const Map<String, ({IconData icon, Color color})> _catStyle = {
    'Đồ uống':    (icon: Icons.local_cafe_rounded,  color: Color(0xFF1565C0)),
    'Đồ ăn':      (icon: Icons.restaurant_rounded,  color: Color(0xFFE65100)),
    'Tráng miệng':(icon: Icons.cake_rounded,         color: Color(0xFF880E4F)),
  };

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(item.status);
    // Chọn icon + màu theo danh mục, fallback fastfood
    final style    = _catStyle[item.category ?? ''];
    final catIcon  = style?.icon  ?? Icons.fastfood_rounded;
    final catColor = style?.color ?? _kNavy;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
=======
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
        border: Border.all(
          color: statusInfo.borderColor,
          width: item.status == StockStatus.ok ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main row
          Padding(
<<<<<<< HEAD
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                // Ảnh hoặc icon danh mục
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 52, height: 52,
                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? Image.network(item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: catColor.withValues(alpha: 0.10),
                            child: Icon(catIcon, color: catColor, size: 26)))
                      : Container(
                          color: catColor.withValues(alpha: 0.10),
                          child: Icon(catIcon, color: catColor, size: 26)),
                  ),
=======
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: statusInfo.iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.fastfood_rounded,
                    color: statusInfo.iconColor, size: 22),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item.name,
                              style: const TextStyle(
<<<<<<< HEAD
                                fontSize: 16, fontWeight: FontWeight.w700,
=======
                                fontSize: 14, fontWeight: FontWeight.w700,
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                                color: _kInk),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
<<<<<<< HEAD
                                horizontal: 10, vertical: 5),
=======
                                horizontal: 8, vertical: 3),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                            decoration: BoxDecoration(
                              color: statusInfo.badgeBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(statusInfo.label,
                              style: TextStyle(
<<<<<<< HEAD
                                fontSize: 13, fontWeight: FontWeight.w700,
=======
                                fontSize: 11, fontWeight: FontWeight.w700,
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                                color: statusInfo.badgeColor,
                              )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Tồn: ',
                            style: const TextStyle(
                              fontSize: 12, color: _kMuted),
                          ),
                          Text(
                            '${item.stockQty.toStringAsFixed(0)} ${item.unit}',
                            style: TextStyle(
<<<<<<< HEAD
                              fontSize: 15, fontWeight: FontWeight.w800,
=======
                              fontSize: 13, fontWeight: FontWeight.w800,
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                              color: statusInfo.stockColor,
                            ),
                          ),
                          if (item.minStock > 0) ...[
                            const Text(' / ',
                              style: TextStyle(fontSize: 12, color: _kMuted)),
                            Text(
                              'min ${item.minStock.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12, color: _kMuted),
                            ),
                          ],
                          const Spacer(),
                          if (item.costPrice > 0)
                            Text(
<<<<<<< HEAD
                              _fmtMoney(item.stockValue.toInt()),
=======
                              _fmtMoney(item.stockValue.toInt()) + 'đ',
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                              style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: _kNavy),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action row
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _kBorder, width: 0.5)),
            ),
            child: Row(
              children: [
                _ActionBtn(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Nhập',
                  color: _kGreen,
                  onTap: () => onReceive(item),
                ),
                Container(width: 0.5, height: 36, color: _kBorder),
                _ActionBtn(
                  icon: Icons.tune_rounded,
                  label: 'Điều chỉnh',
                  color: _kNavy,
                  onTap: () => onAdjust(item),
                ),
                Container(width: 0.5, height: 36, color: _kBorder),
                _ActionBtn(
                  icon: Icons.history_rounded,
                  label: 'Lịch sử',
                  color: _kMuted,
                  onTap: () => onHistory(item),
                ),
                Container(width: 0.5, height: 36, color: _kBorder),
<<<<<<< HEAD
                // Nút Topping — chỉ hiện cho món chính (không phải topping)
                if (onTopping != null && !item.isTopping) ...[
                  _ActionBtn(
                    icon: Icons.bubble_chart_rounded,
                    label: 'Topping',
                    color: const Color(0xFFE85D20),
                    onTap: () => onTopping!(item),
                  ),
                  Container(width: 0.5, height: 36, color: _kBorder),
                ],
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                _ActionBtn(
                  icon: Icons.edit_rounded,
                  label: 'Sửa',
                  color: _kOrange,
                  onTap: () => onEdit(item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _statusInfo(StockStatus status) {
    switch (status) {
      case StockStatus.outOfStock:
        return _StatusInfo(
          label: 'Hết hàng',
          badgeBg: const Color(0xFFFFEBEE),
          badgeColor: _kRed,
          borderColor: const Color(0xFFEF9A9A),
          iconBg: const Color(0xFFFFEBEE),
          iconColor: _kRed,
          stockColor: _kRed,
        );
      case StockStatus.low:
        return _StatusInfo(
          label: 'Sắp hết',
          badgeBg: const Color(0xFFFFF3E0),
          badgeColor: const Color(0xFFE65100),
          borderColor: const Color(0xFFFFCC80),
          iconBg: const Color(0xFFFFF3E0),
          iconColor: const Color(0xFFE65100),
          stockColor: const Color(0xFFE65100),
        );
<<<<<<< HEAD
      case StockStatus.ok:
        return _StatusInfo(
          label: 'Còn hàng',
          badgeBg: const Color(0xFFE8F5E9),
          badgeColor: _kGreen,
          borderColor: _kBorder,
          iconBg: _kBg,
          iconColor: _kNavy,
          stockColor: _kGreen,
        );
      case StockStatus.untracked:
=======
      case StockStatus.notTracked:
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
        return _StatusInfo(
          label: 'Không theo dõi',
          badgeBg: const Color(0xFFF5F5F5),
          badgeColor: _kMuted,
          borderColor: _kBorder,
          iconBg: _kBg,
          iconColor: _kMuted,
          stockColor: _kMuted,
        );
      default:
        return _StatusInfo(
          label: 'Còn hàng',
          badgeBg: const Color(0xFFE8F5E9),
          badgeColor: _kGreen,
          borderColor: _kBorder,
          iconBg: _kBg,
          iconColor: _kNavy,
          stockColor: _kGreen,
        );
    }
  }

<<<<<<< HEAD
  String _fmtMoney(int v) => fmtMoney(v.toDouble());
=======
  String _fmtMoney(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
}

class _StatusInfo {
  final String label;
  final Color badgeBg, badgeColor, borderColor, iconBg, iconColor, stockColor;
  const _StatusInfo({
    required this.label,
    required this.badgeBg,
    required this.badgeColor,
    required this.borderColor,
    required this.iconBg,
    required this.iconColor,
    required this.stockColor,
  });
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
<<<<<<< HEAD
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: color)),
=======
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ADJUST DIALOG — Điều chỉnh tồn kho
// ─────────────────────────────────────────────────────────────────────────────
class _AdjustDialog extends ConsumerStatefulWidget {
  final StockItem item;
  const _AdjustDialog({required this.item});

  @override
  ConsumerState<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends ConsumerState<_AdjustDialog> {
  final _qtyCtrl = TextEditingController();
  String _reason = 'adjustment';
  bool _isNegative = true;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Điều chỉnh tồn kho',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          Text(widget.item.name,
            style: const TextStyle(fontSize: 13, color: _kMuted,
              fontWeight: FontWeight.w400)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // +/- toggle
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isNegative = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isNegative ? _kRed : _kBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isNegative ? _kRed : _kBorder),
                    ),
                    child: Center(
                      child: Text('− Xuất kho',
                        style: TextStyle(
                          color: _isNegative ? Colors.white : _kMuted,
                          fontWeight: FontWeight.w700, fontSize: 13,
                        )),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isNegative = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_isNegative ? _kGreen : _kBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !_isNegative ? _kGreen : _kBorder),
                    ),
                    child: Center(
                      child: Text('+ Thêm vào',
                        style: TextStyle(
                          color: !_isNegative ? Colors.white : _kMuted,
                          fontWeight: FontWeight.w700, fontSize: 13,
                        )),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Số lượng (${widget.item.unit})',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _reason,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(
                value: 'adjustment', child: Text('Điều chỉnh tồn kho')),
              DropdownMenuItem(value: 'waste', child: Text('Hao hụt')),
              DropdownMenuItem(value: 'damaged', child: Text('Hư hỏng')),
              DropdownMenuItem(value: 'transfer', child: Text('Chuyển kho')),
            ],
            onChanged: (v) => setState(() => _reason = v!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kNavy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
              : const Text('Xác nhận'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) return;

    setState(() => _loading = true);
    try {
      await ref.read(khoRepositoryProvider).adjustStock(
        productId: widget.item.id,
<<<<<<< HEAD
=======
        productName: widget.item.name,
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
        quantity: _isNegative ? -qty : qty,
        reason: _reason,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY SHEET — Lịch sử biến động 1 sản phẩm
// ─────────────────────────────────────────────────────────────────────────────
class _HistorySheet extends ConsumerWidget {
  final StockItem item;
  const _HistorySheet({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(productMovementsProvider(item.id));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Column(
              children: [
                Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lịch sử biến động',
                          style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: _kInk)),
                        Text(item.name,
                          style: const TextStyle(fontSize: 13, color: _kMuted)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: _kMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: movementsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _kNavy)),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (movements) => movements.isEmpty
                  ? const Center(
                      child: Text('Chưa có biến động nào',
                        style: TextStyle(color: _kMuted, fontSize: 14)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: movements.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: _kBorder),
                      itemBuilder: (_, i) {
                        final m = movements[i];
                        final isIn = m.delta > 0;
<<<<<<< HEAD
                        final dt = DateTime.parse(
                            m.createdAt.isEmpty ? DateTime.now().toIso8601String() : m.createdAt);
=======
                        final dt = DateTime.fromMillisecondsSinceEpoch(
                            m.createdAt);
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  color: isIn
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isIn
                                    ? Icons.add_circle_rounded
                                    : Icons.remove_circle_rounded,
                                  size: 20,
                                  color: isIn ? _kGreen : _kRed,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${isIn ? '+' : '-'}${m.delta.abs().toStringAsFixed(0)} ${item.unit}',
                                      style: TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w800,
                                        color: isIn ? _kGreen : _kRed,
                                      ),
                                    ),
                                    Text(
<<<<<<< HEAD
                                      m.note ?? (isIn ? 'Nhập hàng' : 'Xuất kho'),
=======
                                      m.referenceId ?? (isIn ? 'Nhập hàng' : 'Xuất kho'),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                                      style: const TextStyle(
                                        fontSize: 12, color: _kMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                                    style: const TextStyle(
                                      fontSize: 11, color: _kMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT MOVEMENTS SHEET — Tất cả biến động gần đây
// ─────────────────────────────────────────────────────────────────────────────
class _RecentMovementsSheet extends ConsumerWidget {
  const _RecentMovementsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movAsync = ref.watch(recentMovementsProvider);
<<<<<<< HEAD
    final stockAsync = ref.watch(allStockProvider);

    // Build lookup map: productId → name
    final nameMap = <String, String>{};
    stockAsync.whenData((list) {
      for (final s in list) nameMap[s.id] = s.name;
    });
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
<<<<<<< HEAD
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kNavy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.history_rounded,
                      size: 18, color: _kNavy),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Biến động kho',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: _kInk)),
                    Text('Lịch sử nhập / xuất gần nhất',
                      style: TextStyle(fontSize: 11, color: _kMuted)),
                  ],
                ),
=======
                const Text('Biến động gần đây',
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: _kInk)),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: _kMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: movAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _kNavy)),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (movements) => movements.isEmpty
                  ? const Center(child: Text('Chưa có biến động nào',
                    style: TextStyle(color: _kMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: movements.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: _kBorder),
                      itemBuilder: (_, i) {
                        final m = movements[i];
                        final isIn = m.delta > 0;
<<<<<<< HEAD
                        final dt = DateTime.parse(m.createdAt.isEmpty
                            ? DateTime.now().toIso8601String() : m.createdAt);
                        // Lấy tên SP từ map, fallback 'Không rõ'
                        final productName =
                            nameMap[m.productId] ?? 'Không rõ';
                        final reasonLabel = _reasonLabel(m.reason);
=======
                        final dt = DateTime.fromMillisecondsSinceEpoch(m.createdAt);
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                isIn ? Icons.add_circle_rounded
                                     : Icons.remove_circle_rounded,
                                color: isIn ? _kGreen : _kRed,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
<<<<<<< HEAD
                                    Text(productName,
                                      style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w700,
                                        color: _kInk)),
                                    Row(children: [
                                      if (reasonLabel.isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isIn
                                                ? _kGreen.withValues(alpha: 0.1)
                                                : _kRed.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6)),
                                          child: Text(reasonLabel,
                                            style: TextStyle(
                                              fontSize: 10, fontWeight: FontWeight.w600,
                                              color: isIn ? _kGreen : _kRed)),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                                        style: const TextStyle(
                                          fontSize: 11, color: _kMuted)),
                                    ]),
                                  ],
                                ),
                              ),
                              Text(
                                '${isIn ? '+' : ''}${m.delta.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800,
                                  color: isIn ? _kGreen : _kRed)),
=======
                                    Text(m.productId,
                                      style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w700,
                                        color: _kInk)),
                                    Text(
                                      '${isIn ? '+' : '-'}${m.delta.abs().toStringAsFixed(0)}  •  ${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                                      style: const TextStyle(
                                        fontSize: 12, color: _kMuted)),
                                  ],
                                ),
                              ),
                              if (m.delta.abs() > 0)
                                Text('${m.delta.abs().toStringAsFixed(0)} đv',
                                  style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                    color: _kNavy)),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

<<<<<<< HEAD
  String _reasonLabel(String reason) {
    switch (reason) {
      case 'receive':     return 'Nhập kho';
      case 'adjust':      return 'Hiệu chỉnh';
      case 'sale':        return 'Bán hàng';
      case 'production':  return 'Sản xuất';
      case 'return':      return 'Hoàn trả';
      case 'waste':       return 'Hư hỏng';
      default:            return reason;
    }
  }

=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  String _fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _TabLabel extends StatelessWidget {
  final String text;
  final int count;
  final Color color;
  const _TabLabel(this.text, this.count, {required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(text),
      if (count > 0) ...[
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
            style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: Colors.white)),
        ),
      ],
    ],
  );
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool highlight;
  final Color highlightColor;

  const _HeaderStat({
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
    this.highlightColor = const Color(0xFFFF6F00),
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: highlight
            ? highlightColor.withValues(alpha: 0.15)
            : const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: highlight
            ? Border.all(color: highlightColor.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16,
            color: highlight ? highlightColor : Colors.white54),
          const SizedBox(height: 4),
          Text(value,
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900,
              color: highlight ? highlightColor : Colors.white,
              letterSpacing: -0.5,
            )),
          Text(label,
            style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w500,
              color: highlight
                  ? highlightColor.withValues(alpha: 0.8)
                  : Colors.white54,
            )),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT / ADD PRODUCT SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _EditProductSheet extends StatefulWidget {
<<<<<<< HEAD
  final StockItem? product;
  final Future<void> Function(
    String name, double price, double cost,
    String cat, String unit, double minStock,
    {String? imageUrl, bool isTopping, String toppingUnit}) onSaved;
=======
  final StockItem? product;          // null = chế độ thêm mới
  final Future<void> Function(
    String name, double price, double cost,
    String cat, String unit, double minStock) onSaved;
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  final Future<void> Function()? onDelete;

  const _EditProductSheet({
    required this.product,
    required this.onSaved,
    this.onDelete,
  });

  @override
  State<_EditProductSheet> createState() => _EditProductSheetState();
}

<<<<<<< HEAD
class _EditProductSheetState extends State<_EditProductSheet>
    with SingleTickerProviderStateMixin {
=======
class _EditProductSheetState extends State<_EditProductSheet> {
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  final _formKey    = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _catCtrl;
  late final TextEditingController _minStockCtrl;
  late String _selectedUnit;
<<<<<<< HEAD
  List<String> _customCats = [];
  bool _saving = false;

  // ── Image state ────────────────────────────────────────────────────
  String? _existingImageUrl;
  Uint8List? _previewBytes;
  XFile? _pickedFile;
  bool _aiLoading = false;
  String? _imageError;
  final _imgSvc = ProductImageService();

  // ── Topping state ──────────────────────────────────────────────────
  bool _isTopping = false;
  String _toppingUnit = 'viên';
  TabController? _tabCtrl;
  // Khi sản phẩm là món chính → list toppings có thể chọn
  List<Map<String, dynamic>> _linkedToppings = [];
  List<Map<String, dynamic>> _allToppings = [];
  // Khi sản phẩm là topping → list món chính có thể gắn vào
  List<String> _linkedProductIds = [];
  List<Map<String, dynamic>> _allMainProducts = [];
  bool _loadingToppings = false;

=======
  bool _saving = false;

>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kNavyL  = Color(0xFF2D2B8A);
  static const _kOrange = Color(0xFFE85D20);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);
  static const _kRed    = Color(0xFFC62828);
  static const _kGreen  = Color(0xFF2E7D32);

  static const _cats  = ['Đồ ăn','Đồ uống','Tráng miệng','Combo','Nguyên liệu','Khác'];
  static const _units = ['phần','ly','tô','cái','hộp','kg','g','lít'];
<<<<<<< HEAD
  static const _toppingUnits = ['viên','phần','ml','g','muỗng','thìa'];
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl      = TextEditingController(text: p?.name ?? '');
    _priceCtrl     = TextEditingController(
        text: p != null && p.sellPrice > 0
            ? p.sellPrice.toStringAsFixed(0) : '');
    _costCtrl      = TextEditingController(
        text: p != null && p.costPrice > 0
            ? p.costPrice.toStringAsFixed(0) : '');
    _catCtrl       = TextEditingController(text: p?.category ?? '');
    _minStockCtrl  = TextEditingController(
        text: p != null && p.minStock > 0
            ? p.minStock.toStringAsFixed(0) : '');
    _selectedUnit  = p?.unit ?? 'phần';
<<<<<<< HEAD
    _isTopping     = p?.isTopping ?? false;
    _toppingUnit   = p?.toppingUnit ?? 'viên';
    final existingCat = p?.category ?? '';
    if (existingCat.isNotEmpty &&
        !const ['Đồ ăn','Đồ uống','Tráng miệng','Combo','Nguyên liệu','Topping'].contains(existingCat)) {
      _customCats = [existingCat];
    }
    _existingImageUrl = p?.imageUrl;
    if (_isEdit && !(p?.isTopping ?? false)) {
      _tabCtrl = TabController(length: 2, vsync: this);
      _loadToppingData();
    }
    // Nếu sản phẩm là topping → load danh sách món chính để gắn
    if (_isEdit && (p?.isTopping ?? false)) {
      _loadMainProductsForTopping();
    }
  }

  Future<void> _loadToppingData() async {
    if (!mounted) return;
    setState(() => _loadingToppings = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storeId = prefs.getString('auth_store_id') ?? '';
      if (storeId.isEmpty) return;
      final allRows = await Supabase.instance.client
          .from('products')
          .select('id, name, sell_price, unit, topping_unit')
          .eq('store_id', storeId)
          .eq('is_topping', true)
          .eq('is_deleted', false)
          .order('name');
      _allToppings = List<Map<String, dynamic>>.from(allRows as List);
      if (_isEdit && widget.product != null) {
        final linkRows = await Supabase.instance.client
            .from('product_topping_links')
            .select('topping_id')
            .eq('product_id', widget.product!.id);
        final linkedIds = (linkRows as List)
            .map((r) => r['topping_id'] as String)
            .toSet();
        _linkedToppings = _allToppings
            .where((t) => linkedIds.contains(t['id'] as String))
            .toList();
      }
    } catch (e) {
      debugPrint('[EditProduct] _loadToppingData error: $e');
    } finally {
      if (mounted) setState(() => _loadingToppings = false);
    }
  }

  // Load danh sách món chính + linked ids (khi sản phẩm là topping)
  Future<void> _loadMainProductsForTopping() async {
    if (!mounted) return;
    setState(() => _loadingToppings = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storeId = prefs.getString('auth_store_id') ?? '';
      if (storeId.isEmpty) return;
      // Tất cả sản phẩm chính (không phải topping)
      final allRows = await Supabase.instance.client
          .from('products')
          .select('id, name, category')
          .eq('store_id', storeId)
          .eq('is_topping', false)
          .eq('is_deleted', false)
          .neq('category', 'Nguyên liệu')
          .order('name');
      _allMainProducts = List<Map<String, dynamic>>.from(allRows as List);
      // Đã link vào những món nào
      if (_isEdit && widget.product != null) {
        final linkRows = await Supabase.instance.client
            .from('product_topping_links')
            .select('product_id')
            .eq('topping_id', widget.product!.id);
        _linkedProductIds = (linkRows as List)
            .map((r) => r['product_id'] as String).toList();
      }
    } catch (e) {
      debugPrint('[EditProduct] _loadMainProductsForTopping error: $e');
    } finally {
      if (mounted) setState(() => _loadingToppings = false);
    }
  }

  // Toggle gắn/bỏ gắn topping vào 1 món chính (từ phía topping)
  Future<void> _toggleProductLink(String productId) async {
    if (widget.product == null) return;
    final toppingId = widget.product!.id;
    final isLinked = _linkedProductIds.contains(productId);
    try {
      if (isLinked) {
        await Supabase.instance.client
            .from('product_topping_links')
            .delete()
            .eq('product_id', productId)
            .eq('topping_id', toppingId);
        if (mounted) setState(() => _linkedProductIds.remove(productId));
      } else {
        await Supabase.instance.client
            .from('product_topping_links')
            .upsert(
              {'product_id': productId, 'topping_id': toppingId},
              onConflict: 'product_id,topping_id',
            );
        if (mounted) setState(() => _linkedProductIds.add(productId));
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('[EditProduct] _toggleProductLink error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi gắn topping: $e',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  Future<void> _toggleToppingLink(Map<String, dynamic> topping) async {
    final toppingId = topping['id'] as String;
    final productId = widget.product!.id;
    final isLinked = _linkedToppings.any((t) => t['id'] == toppingId);
    try {
      if (isLinked) {
        await Supabase.instance.client
            .from('product_topping_links')
            .delete()
            .eq('product_id', productId)
            .eq('topping_id', toppingId);
        setState(() => _linkedToppings.removeWhere((t) => t['id'] == toppingId));
      } else {
        await Supabase.instance.client
            .from('product_topping_links')
            .upsert(
              {'product_id': productId, 'topping_id': toppingId},
              onConflict: 'product_id,topping_id',
            );
        setState(() => _linkedToppings.add(topping));
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('[EditProduct] _toggleToppingLink error: $e');
    }
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _priceCtrl.dispose(); _costCtrl.dispose();
    _catCtrl.dispose(); _minStockCtrl.dispose();
<<<<<<< HEAD
    _tabCtrl?.dispose();
    super.dispose();
  }


  // ── Image helpers ──────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final file = source == ImageSource.gallery
        ? await _imgSvc.pickFromGallery()
        : await _imgSvc.pickFromCamera();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() { _pickedFile = file; _previewBytes = bytes; _imageError = null; });
  }

  Future<void> _generateWithAI() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _imageError = 'Nhập tên sản phẩm trước');
      return;
    }
    setState(() { _aiLoading = true; _imageError = null; });
    try {
      // Tìm ảnh từ Cook.ai library
      final uri = Uri.parse(
        'https://cook.ai.vn/api/recipes/?action=search&q=${Uri.encodeComponent(name)}&limit=9');
      final res = await http.get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('Không kết nối được Cook.ai');

      final List<dynamic> data = jsonDecode(res.body);
      if (data.isEmpty) {
        setState(() => _imageError = 'Không tìm thấy ảnh phù hợp trong thư viện');
        return;
      }
      setState(() => _aiLoading = false);

      // Hiện bottom sheet chọn ảnh
      if (!mounted) return;
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CookAiPickerSheet(recipes: data),
      );
      if (picked == null) return;

      // Download ảnh đã chọn
      final imageUrl = picked['imageUrl'] as String;
      final imgRes = await http.get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 15));
      if (imgRes.statusCode == 200) {
        setState(() { _previewBytes = imgRes.bodyBytes; _pickedFile = null; });
      } else {
        setState(() => _imageError = 'Không tải được ảnh');
      }
    } catch (e) {
      setState(() => _imageError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  void _clearImage() => setState(() {
    _previewBytes = null; _pickedFile = null; _existingImageUrl = null;
  });

  @override
  Widget build(BuildContext context) {
    final mainContent = Padding(
=======
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
            // ── Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kNavy, _kNavyL],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28)),
              ),
              child: Column(children: [
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 14),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(
                      _isEdit
                          ? Icons.edit_rounded
                          : Icons.add_box_rounded,
                      color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isEdit
                        ? 'Sửa sản phẩm'
                        : 'Thêm sản phẩm mới',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 17,
                      fontWeight: FontWeight.w800)),
                  if (_isEdit) ...[ const Spacer(),
                    Text(widget.product!.name,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12)),
                  ],
                ]),
              ]),
            ),

            // ── Form ────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
<<<<<<< HEAD
                      // ── Ảnh sản phẩm ───────────────────────
                      _ProductImageSection(
                        previewBytes: _previewBytes,
                        existingUrl: _existingImageUrl,
                        aiLoading: _aiLoading,
                        error: _imageError,
                        onPickGallery: () => _pickImage(ImageSource.gallery),
                        onPickCamera: () => _pickImage(ImageSource.camera),
                        onAiGenerate: _generateWithAI,
                        onClear: _clearImage,
                      ),
                      const SizedBox(height: 12),

=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                      // Tên
                      _PField(ctrl: _nameCtrl, label: 'Tên sản phẩm *',
                        icon: Icons.restaurant_menu_rounded, color: _kNavy,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Vui lòng nhập tên' : null),
                      const SizedBox(height: 12),

                      // Giá bán + giá vốn
<<<<<<< HEAD
                      // Nguyên liệu không cần giá bán (dùng nội bộ)
                      Builder(builder: (ctx) {
                        final isIngredient = _catCtrl.text == 'Nguyên liệu';
                        return Row(children: [
                          Expanded(child: _PField(
                            ctrl: _priceCtrl,
                            label: isIngredient ? 'Giá bán (đ) — không bắt buộc' : 'Giá bán (đ) *',
                            icon: Icons.sell_rounded,
                            color: isIngredient ? _kMuted : _kOrange,
                            keyboard: TextInputType.number,
                            validator: isIngredient
                                ? null  // Nguyên liệu: không validate giá bán
                                : (v) {
                                    final n = double.tryParse((v ?? '').replaceAll(',',''));
                                    return (n == null || n <= 0) ? 'Giá > 0' : null;
                                  })),
                          const SizedBox(width: 10),
                          Expanded(child: _PField(
                            ctrl: _costCtrl, label: 'Giá vốn (đ)',
                            icon: Icons.shopping_basket_rounded, color: _kMuted,
                            keyboard: TextInputType.number)),
                        ]);
                      }),
=======
                      Row(children: [
                        Expanded(child: _PField(
                          ctrl: _priceCtrl, label: 'Giá bán (đ) *',
                          icon: Icons.sell_rounded, color: _kOrange,
                          keyboard: TextInputType.number,
                          validator: (v) {
                            final n = double.tryParse((v ?? '').replaceAll(',',''));
                            return (n == null || n <= 0) ? 'Giá > 0' : null;
                          })),
                        const SizedBox(width: 10),
                        Expanded(child: _PField(
                          ctrl: _costCtrl, label: 'Giá vốn (đ)',
                          icon: Icons.shopping_basket_rounded, color: _kMuted,
                          keyboard: TextInputType.number)),
                      ]),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                      const SizedBox(height: 12),

                      // Tồn kho tối thiểu
                      _PField(ctrl: _minStockCtrl, label: 'Tồn tối thiểu (cảnh báo)',
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFE65100),
                        keyboard: TextInputType.number),
                      const SizedBox(height: 12),

<<<<<<< HEAD
                      // Danh mục chips (chuẩn + tùy chỉnh + nút Thêm)
                      const Text('Danh mục', style: TextStyle(
                        fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        // Chips chuẩn (không có "Khác")
                        ...['Đồ ăn','Đồ uống','Tráng miệng','Combo','Nguyên liệu'].map((c) {
                          final sel = _catCtrl.text == c;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _catCtrl.text = sel ? '' : c;
                              // Bỏ is_topping nếu chọn danh mục khác
                              if (!sel) _isTopping = false;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel ? _kNavy : _kNavy.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sel ? _kNavy : _kBorder)),
                              child: Text(c, style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : _kMuted)),
                            ),
                          );
                        }),
                        // Chip Topping — màu cam, tự bật is_topping
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              final sel = _isTopping;
                              _isTopping = !sel;
                              if (!sel) {
                                _catCtrl.text = 'Topping';
                                // Load danh sách món chính nếu chưa load
                                if (_allMainProducts.isEmpty) {
                                  _loadMainProductsForTopping();
                                }
                              } else {
                                if (_catCtrl.text == 'Topping') _catCtrl.text = '';
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isTopping ? _kOrange : _kOrange.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isTopping ? _kOrange : _kBorder,
                                width: _isTopping ? 1.5 : 1)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.add_circle_outline_rounded, size: 14, color: _kOrange),
                              const SizedBox(width: 4),
                              Text('Topping', style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: _isTopping ? Colors.white : _kMuted)),
                            ]),
                          ),
                        ),
                        // Chips tùy chỉnh (có nút xóa)
                        ..._customCats.map((c) {
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
                                    ? const Color(0xFF7C3AED)
                                    : const Color(0xFF7C3AED).withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sel
                                      ? const Color(0xFF7C3AED)
                                      : _kBorder)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(c, style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : _kMuted)),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _customCats.remove(c);
                                    if (_catCtrl.text == c) _catCtrl.text = '';
                                  }),
                                  child: Icon(Icons.close_rounded,
                                      size: 14,
                                      color: sel
                                          ? Colors.white70
                                          : _kMuted),
                                ),
                              ]),
                            ),
                          );
                        }),
                        // Nút "+ Thêm danh mục"
                        GestureDetector(
                          onTap: _addCustomCategory,
=======
                      // Danh mục chips
                      const Text('Danh mục', style: TextStyle(
                        fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: _cats.map((c) {
                        final sel = _catCtrl.text == c;
                        return GestureDetector(
                          onTap: () => setState(() =>
                              _catCtrl.text = sel ? '' : c),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
<<<<<<< HEAD
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _kBorder,
                                style: BorderStyle.solid)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.add_rounded, size: 14, color: _kMuted),
                              const SizedBox(width: 4),
                              Text('Thêm', style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: _kMuted)),
                            ]),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),

                      // Đơn vị — tự đổi chips khi là Topping
                      Text(
                        _isTopping ? 'Đơn vị topping' : 'Đơn vị',
                        style: const TextStyle(
                          fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8,
                        children: (_isTopping ? _toppingUnits : _units).map((u) {
                          // Khi topping: so sánh với _toppingUnit; bình thường: _selectedUnit
                          final sel = _isTopping ? _toppingUnit == u : _selectedUnit == u;
                          return GestureDetector(
                            onTap: () => setState(() {
                              if (_isTopping) {
                                _toppingUnit = u;
                                _selectedUnit = u; // sync cả unit bình thường
                              } else {
                                _selectedUnit = u;
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: sel ? _kOrange : _kOrange.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: sel ? _kOrange : _kBorder)),
                              child: Text(u, style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : _kMuted)),
                            ),
                          );
                        }).toList()),
                      const SizedBox(height: 20),

                      // ── Gắn vào món (chỉ hiện khi là Topping) ──────────────
                      if (_isTopping && _isEdit) ...[ 
                        const Text('🍜 Gắn vào món', style: TextStyle(
                          fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        if (_loadingToppings)
                          const Center(child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2)))
                        else if (_allMainProducts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _kNavy.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _kBorder)),
                            child: const Text('Chưa có món chính nào trong kho',
                              style: TextStyle(fontSize: 12, color: _kMuted)),
                          )
                        else
                          Wrap(spacing: 8, runSpacing: 8,
                            children: _allMainProducts.map((p) {
                              final pid = p['id'] as String;
                              final sel = _linkedProductIds.contains(pid);
                              return GestureDetector(
                                onTap: () => _toggleProductLink(pid),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: sel ? _kNavy : _kNavy.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: sel ? _kNavy : _kBorder,
                                      width: sel ? 1.5 : 1)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    if (sel) const Icon(Icons.check_rounded,
                                      size: 12, color: Colors.white),
                                    if (sel) const SizedBox(width: 4),
                                    Text(p['name'] as String? ?? '',
                                      style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w600,
                                        color: sel ? Colors.white : _kMuted)),
                                  ]),
                                ),
                              );
                            }).toList()),
                        const SizedBox(height: 8),
                      ],

                      // Hint tab Topping (chỉ hiện khi edit món chính)
                      if (_isEdit && !_isTopping && _tabCtrl != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F0FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3))),
                          child: Row(children: [
                            Icon(Icons.bubble_chart_rounded, size: 18,
                              color: const Color(0xFF7C3AED)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              '${_linkedToppings.length} topping đang gắn — Nhấn nút Topping trên thẻ để chỉnh',
                              style: TextStyle(
                                fontSize: 12, color: const Color(0xFF7C3AED),
                                fontWeight: FontWeight.w600))),
                          ]),
                        ),
                      ],
=======
                              color: sel ? _kNavy : _kNavy.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel ? _kNavy : _kBorder)),
                            child: Text(c, style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : _kMuted)),
                          ),
                        );
                      }).toList()),
                      const SizedBox(height: 12),

                      // Đơn vị chips
                      const Text('Đơn vị', style: TextStyle(
                        fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: _units.map((u) {
                        final sel = _selectedUnit == u;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedUnit = u),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: sel ? _kOrange : _kOrange.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel ? _kOrange : _kBorder)),
                            child: Text(u, style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : _kMuted)),
                          ),
                        );
                      }).toList()),
                      const SizedBox(height: 20),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

                      // Buttons
                      Row(children: [
                        if (_isEdit && widget.onDelete != null) ...[
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _confirmDelete,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _kRed,
                              side: const BorderSide(color: _kRed),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12)),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: const Text('Xoá',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isEdit ? _kNavy : _kGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                            icon: _saving
                                ? const SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                                : Icon(_isEdit
                                    ? Icons.save_rounded
                                    : Icons.add_circle_rounded),
                            label: Text(
                              _saving
                                  ? 'Đang lưu...'
                                  : (_isEdit ? 'Lưu thay đổi' : 'Thêm sản phẩm'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                        )),
                      ]),
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
<<<<<<< HEAD
    return mainContent;
  }

  Widget _buildToppingTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          const Icon(Icons.restaurant_menu_rounded, size: 18, color: _kOrange),
          const SizedBox(width: 8),
          Text('Topping gắn với món này',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kNavy)),
        ]),
      ),
      if (_loadingToppings)
        const Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: _kOrange))
      else if (_allToppings.isEmpty)
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.restaurant_menu_rounded, size: 40, color: _kNavy.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text('Chưa có topping nào trong kho',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: _kMuted)),
            const SizedBox(height: 8),
            Text('Vào Kho → Thêm sản phẩm → bật "Là Topping"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _kMuted)),
          ]),
        )
      else
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _allToppings.length,
            itemBuilder: (_, i) {
              final t = _allToppings[i];
              final tId = t['id'] as String;
              final isLinked = _linkedToppings.any((lt) => lt['id'] == tId);
              final price = (t['sell_price'] as num?)?.toDouble() ?? 0;
              return GestureDetector(
                onTap: () => _toggleToppingLink(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isLinked ? const Color(0xFFFFF3E0) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLinked ? _kOrange : _kBorder,
                      width: isLinked ? 1.5 : 1)),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: isLinked ? _kOrange : _kBorder.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6)),
                      child: isLinked
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                          : null),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['name'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: isLinked ? _kOrange : _kNavy)),
                        Text(price > 0 ? '+${price.round()}đ / ${t['topping_unit'] ?? 'phần'}' : 'Miễn phí',
                          style: TextStyle(fontSize: 11, color: _kMuted)),
                      ],
                    )),
                    if (isLinked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kOrange,
                          borderRadius: BorderRadius.circular(8)),
                        child: const Text('Đã gắn',
                          style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700))),
                  ]),
                ),
              );
            },
          ),
        ),
      const SizedBox(height: 16),
    ]);
  }

  Future<void> _addCustomCategory() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Thêm danh mục mới',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Ví dụ: Hải sản, Bia ruợu...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _kNavy, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kNavy),
            child: const Text('Thêm', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      final newCat = ctrl.text.trim();
      setState(() {
        if (!_customCats.contains(newCat)) _customCats.add(newCat);
        _catCtrl.text = newCat; // auto-select
      });
    }
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
<<<<<<< HEAD
    String? imageUrl = _existingImageUrl;

    // Bước 1: Upload ảnh mới nếu có — tách riêng để hiện đúng message khi lỗi
    if (_previewBytes != null) {
      try {
        if (_pickedFile != null) {
          imageUrl = await _imgSvc.uploadFile(_pickedFile!);
        } else {
          // bytes từ AI
          imageUrl = await _imgSvc.uploadBytes(_previewBytes!);
        }
      } catch (e) {
        setState(() { _saving = false; _imageError = 'Upload ảnh lỗi: $e'; });
        return;
      }
    } else if (_existingImageUrl == null && widget.product?.imageUrl != null) {
      // Xóa ảnh cũ khỏi Supabase (silent fail)
      try { await _imgSvc.deleteByUrl(widget.product!.imageUrl!); } catch (_) {}
    }

    // Bước 2: Lưu sản phẩm
    try {
      final price = double.tryParse(_priceCtrl.text.replaceAll(',','')) ?? 0;
      final cost  = double.tryParse(_costCtrl.text.replaceAll(',','')) ?? 0;
      final min   = double.tryParse(_minStockCtrl.text) ?? 0;
      await widget.onSaved(
        _nameCtrl.text.trim(), price, cost,
        _catCtrl.text.trim(), _selectedUnit, min,
        imageUrl: imageUrl,
        isTopping: _isTopping,
        toppingUnit: _toppingUnit);
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      setState(() { _saving = false; _imageError = 'Lỗi lưu: $e'; }); // FIX: message rõ ràng hơn
    }
=======
    final price = double.tryParse(_priceCtrl.text.replaceAll(',','')) ?? 0;
    final cost  = double.tryParse(_costCtrl.text.replaceAll(',','')) ?? 0;
    final min   = double.tryParse(_minStockCtrl.text) ?? 0;
    await widget.onSaved(
      _nameCtrl.text.trim(), price, cost,
      _catCtrl.text.trim(), _selectedUnit, min);
    if (mounted) setState(() => _saving = false);
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xoá sản phẩm?',
          style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '"${widget.product?.name}" sẽ bị ẩn khỏi danh sách. Lịch sử tồn kho vẫn được lưu.',
          style: const TextStyle(color: _kMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.onDelete?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }
}

// Helper field widget
class _PField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final Color color;
  final String? Function(String?)? validator;
  final TextInputType? keyboard;

  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);

  const _PField({
    required this.ctrl, required this.label,
    required this.icon, required this.color,
    this.validator, this.keyboard,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, validator: validator,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _kMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: color, size: 18),
      filled: true, fillColor: _kBg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
<<<<<<< HEAD

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT IMAGE SECTION — Upload gallery/camera hoặc AI tạo ảnh
// ─────────────────────────────────────────────────────────────────────────────
class _ProductImageSection extends StatelessWidget {
  final Uint8List? previewBytes;
  final String? existingUrl;
  final bool aiLoading;
  final String? error;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onAiGenerate;
  final VoidCallback onClear;

  const _ProductImageSection({
    required this.previewBytes, required this.existingUrl,
    required this.aiLoading, this.error,
    required this.onPickGallery, required this.onPickCamera,
    required this.onAiGenerate, required this.onClear,
  });

  bool get _hasImage => previewBytes != null || existingUrl != null;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Ảnh sản phẩm', style: TextStyle(
        fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),

      Row(children: [
        // Preview box
        GestureDetector(
          onTap: _hasImage ? null : onPickGallery,
          child: Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder, width: 1.5)),
            clipBehavior: Clip.antiAlias,
            child: _buildPreview(),
          ),
        ),
        const SizedBox(width: 12),

        // Action buttons
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Gallery + Camera
            Row(children: [
              Expanded(child: _ImgBtn(
                icon: Icons.photo_library_outlined,
                label: 'Thư viện',
                onTap: onPickGallery,
                color: _kNavy,
              )),
              const SizedBox(width: 8),
              Expanded(child: _ImgBtn(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: onPickCamera,
                color: _kNavy,
              )),
            ]),
            const SizedBox(height: 8),
            // Row 2: Cook.ai Search
            aiLoading
              ? Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.3))),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFFF6B35))),
                      SizedBox(width: 8),
                      Text('Đang tìm...',
                        style: TextStyle(fontSize: 11, color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.w600)),
                    ]))
              : _ImgBtn(
                  icon: Icons.image_search_rounded,
                  label: 'Tìm ảnh từ Cook.ai.vn',
                  onTap: onAiGenerate,
                  color: const Color(0xFFFF6B35),
                ),
            if (_hasImage) ...[ 
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onClear,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded, size: 12, color: _kMuted),
                    SizedBox(width: 4),
                    Text('Xoá ảnh', style: TextStyle(
                      fontSize: 11, color: _kMuted)),
                  ]),
              ),
            ],
          ],
        )),
      ]),

      if (error != null) ...[
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.error_outline_rounded, size: 13, color: _kRed),
          const SizedBox(width: 4),
          Expanded(child: Text(error!,
            style: const TextStyle(fontSize: 11, color: _kRed))),
        ]),
      ],
    ]);
  }

  Widget _buildPreview() {
    if (previewBytes != null) {
      return Image.memory(previewBytes!, fit: BoxFit.cover);
    }
    if (existingUrl != null) {
      return Image.network(existingUrl!, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image_outlined, color: _kMuted));
    }
    return const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.add_photo_alternate_outlined, size: 28, color: _kMuted),
      SizedBox(height: 4),
      Text('Thêm ảnh', style: TextStyle(fontSize: 10, color: _kMuted)),
    ]);
  }
}

class _ImgBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ImgBtn({required this.icon, required this.label,
    required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
          fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      ])),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TOPPING LINK SHEET — Sheet riêng để cấu hình topping cho từng món chính
// Mở khi bấm nút "🧋 Topping" trên card sản phẩm
// ─────────────────────────────────────────────────────────────────────────────
class _ToppingLinkSheet extends StatefulWidget {
  final StockItem product;
  const _ToppingLinkSheet({required this.product});

  @override
  State<_ToppingLinkSheet> createState() => _ToppingLinkSheetState();
}

class _ToppingLinkSheetState extends State<_ToppingLinkSheet> {
  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kOrange = Color(0xFFE85D20);
  static const _kBg     = Color(0xFFFAF7F2);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);

  bool _loading = true;
  List<Map<String, dynamic>> _allToppings = [];   // tất cả sản phẩm is_topping=true
  Set<String> _linkedIds = {};                     // topping_id đã link

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final sb = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final storeId = prefs.getString('auth_store_id') ?? '';
      if (storeId.isEmpty) return;

      // 1. Tất cả sản phẩm topping của quán
      final allRows = await sb
          .from('products')
          .select('id, name, sell_price, topping_unit, unit')
          .eq('store_id', storeId)
          .eq('is_topping', true)
          .eq('is_deleted', false)
          .order('name');

      // 2. Links hiện tại của sản phẩm này
      final linkRows = await sb
          .from('product_topping_links')
          .select('topping_id')
          .eq('product_id', widget.product.id);

      if (mounted) {
        setState(() {
          _allToppings = List<Map<String, dynamic>>.from(allRows as List);
          _linkedIds = (linkRows as List)
              .map((r) => r['topping_id'] as String)
              .toSet();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[ToppingLinkSheet] _loadData error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLink(String toppingId) async {
    final sb = Supabase.instance.client;
    final productId = widget.product.id;
    final isLinked = _linkedIds.contains(toppingId);
    try {
      if (isLinked) {
        await sb.from('product_topping_links').delete()
            .eq('product_id', productId)
            .eq('topping_id', toppingId);
        setState(() => _linkedIds.remove(toppingId));
      } else {
        await sb.from('product_topping_links').upsert(
          {'product_id': productId, 'topping_id': toppingId},
          onConflict: 'product_id,topping_id',
        );
        setState(() => _linkedIds.add(toppingId));
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('[ToppingLinkSheet] _toggleLink error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kNavy, Color(0xFF2D2B8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 14),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.restaurant_menu_rounded, size: 18, color: _kOrange),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cấu hình Topping',
                      style: TextStyle(
                        color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.w800)),
                    Text(widget.product.name,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
                // Badge số topping đã chọn
                if (_linkedIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kOrange,
                      borderRadius: BorderRadius.circular(20)),
                    child: Text('${_linkedIds.length} đã chọn',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w700)),
                  ),
              ]),
            ]),
          ),

          // ── Content ───────────────────────────────────────────────────
          Flexible(
            child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: _kOrange)))
              : _allToppings.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.restaurant_menu_rounded, size: 48, color: _kNavy.withValues(alpha: 0.12)),
                        const SizedBox(height: 12),
                        const Text('Chưa có sản phẩm topping nào',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                            color: Color(0xFF1E1C5E))),
                        const SizedBox(height: 6),
                        Text('Vào Kho → Thêm SP → bật chip "Topping"',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: _kMuted)),
                      ]),
                    ))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: _allToppings.length,
                    itemBuilder: (_, i) {
                      final t = _allToppings[i];
                      final tId = t['id'] as String;
                      final isLinked = _linkedIds.contains(tId);
                      final price = (t['sell_price'] as num?)?.toDouble() ?? 0;
                      final unit = t['topping_unit'] as String? ??
                          t['unit'] as String? ?? 'phần';

                      return GestureDetector(
                        onTap: () => _toggleLink(tId),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isLinked
                                ? const Color(0xFFFFF3E0)
                                : _kBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isLinked ? _kOrange : _kBorder,
                              width: isLinked ? 1.5 : 1)),
                          child: Row(children: [
                            // Checkbox
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: isLinked ? _kOrange : Colors.white,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: isLinked ? _kOrange : _kBorder,
                                  width: 1.5)),
                              child: isLinked
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16)
                                : null),
                            const SizedBox(width: 12),
                            // Info
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t['name'] as String? ?? '',
                                  style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: isLinked ? _kOrange : _kNavy)),
                                const SizedBox(height: 2),
                                Text(
                                  price > 0
                                    ? '+${price.round()}đ / $unit'
                                    : 'Miễn phí / $unit',
                                  style: TextStyle(
                                    fontSize: 12, color: _kMuted)),
                              ])),
                            // Badge
                            if (isLinked)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _kOrange,
                                  borderRadius: BorderRadius.circular(8)),
                                child: const Text('Đã gắn',
                                  style: TextStyle(
                                    fontSize: 11, color: Colors.white,
                                    fontWeight: FontWeight.w700))),
                          ]),
                        ),
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
// COOK.AI IMAGE PICKER SHEET
// Hiển thị grid ảnh từ Cook.ai library để chọn
// ─────────────────────────────────────────────────────────────────────────────
class _CookAiPickerSheet extends StatelessWidget {
  final List<dynamic> recipes;
  const _CookAiPickerSheet({required this.recipes});

  String _imageUrl(dynamic r) {
    final img = (r['image'] ?? '') as String;
    if (img.startsWith('http')) return img;
    return 'https://cook.ai.vn$img';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 12),
              const Row(children: [
                Text('🍜', style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Text('Chọn ảnh từ Cook.ai',
                  style: TextStyle(color: Colors.white,
                    fontSize: 16, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 2),
              Text('${recipes.length} kết quả phù hợp',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12)),
            ]),
          ),

          // Grid
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: recipes.length,
              itemBuilder: (ctx, i) {
                final r = recipes[i];
                final imgUrl = _imageUrl(r);
                final name = (r['name'] ?? '') as String;
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, {'imageUrl': imgUrl, 'name': name}),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF5F5F5),
                              child: const Icon(Icons.broken_image_outlined,
                                color: Color(0xFFBBBBBB))),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: Color(0xFF333333)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOPPING GROUP TAB — Quản lý Nhóm Topping (Phương án B)
// ─────────────────────────────────────────────────────────────────────────────
// Provider để load tất cả groups
final _allToppingGroupsProvider = FutureProvider.autoDispose<List<ToppingGroupModel>>((ref) async {
  return ToppingGroupRepository().fetchAll();
});

class _ToppingGroupTab extends ConsumerStatefulWidget {
  const _ToppingGroupTab();

  @override
  ConsumerState<_ToppingGroupTab> createState() => _ToppingGroupTabState();
}

class _ToppingGroupTabState extends ConsumerState<_ToppingGroupTab> {
  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kNavyL  = Color(0xFF2D2B8A);
  static const _kOrange = Color(0xFFE85D20);
  static const _kBg     = Color(0xFFFAF7F2);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(_allToppingGroupsProvider);
    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'topping_group_fab',
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo nhóm', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _openEditGroupSheet(context, null),
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.restaurant_menu_rounded, size: 56, color: _kNavy.withValues(alpha: 0.12)),
                const SizedBox(height: 16),
                Text('Chưa có nhóm topping nào',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: _kNavy)),
                const SizedBox(height: 8),
                Text('Tạo nhóm để gắn vào nhiều món cùng lúc',
                  style: GoogleFonts.outfit(fontSize: 13, color: _kMuted)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _openEditGroupSheet(context, null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                  icon: const Icon(Icons.add_rounded),
                  label: Text('Tạo nhóm đầu tiên',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                ),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final g = groups[i];
              return _ToppingGroupCard(
                group: g,
                onEdit: () => _openEditGroupSheet(context, g),
              );
            },
          );
        },
      ),
    );
  }

  void _openEditGroupSheet(BuildContext context, ToppingGroupModel? group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditToppingGroupSheet(
        group: group,
        onSaved: () => ref.invalidate(_allToppingGroupsProvider),
      ),
    );
  }
}

// ── Group Card ────────────────────────────────────────────────────────────────
class _ToppingGroupCard extends StatelessWidget {
  final ToppingGroupModel group;
  final VoidCallback onEdit;

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kOrange = Color(0xFFE85D20);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);

  const _ToppingGroupCard({required this.group, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.restaurant_menu_rounded, size: 16, color: _kOrange),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group.name, style: GoogleFonts.outfit(
                fontSize: 15, fontWeight: FontWeight.w800, color: _kNavy)),
              if (group.description?.isNotEmpty == true)
                Text(group.description!, style: GoogleFonts.outfit(fontSize: 12, color: _kMuted)),
            ])),
            Icon(Icons.chevron_right_rounded, color: _kMuted),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _InfoChip(
              icon: Icons.bubble_chart_rounded,
              label: '${group.items.length} topping',
              color: _kNavy,
            ),
            _InfoChip(
              icon: Icons.tune_rounded,
              label: group.minSelect == 0
                  ? 'Tùy chọn'
                  : 'Min ${group.minSelect}',
              color: group.minSelect > 0 ? _kOrange : _kMuted,
            ),
            if (group.maxSelect < 10)
              _InfoChip(
                icon: Icons.numbers_rounded,
                label: 'Max ${group.maxSelect}',
                color: _kNavy,
              ),
          ]),
          if (group.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 4,
              children: group.items.take(5).map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kOrange.withValues(alpha: 0.3))),
                child: Text(
                  item.sellPrice > 0
                      ? '${item.productName} +${(item.sellPrice/1000).toStringAsFixed(0)}k'
                      : item.productName,
                  style: GoogleFonts.outfit(fontSize: 11, color: _kOrange, fontWeight: FontWeight.w600)),
              )).toList()
              ..addAll(group.items.length > 5 ? [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kBorder, borderRadius: BorderRadius.circular(20)),
                  child: Text('+${group.items.length - 5} nữa',
                    style: GoogleFonts.outfit(fontSize: 11, color: _kMuted)),
                )
              ] : []),
            ),
          ],
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: color),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  ]);
}

// ── Edit Topping Group Sheet ───────────────────────────────────────────────
class _EditToppingGroupSheet extends ConsumerStatefulWidget {
  final ToppingGroupModel? group;
  final VoidCallback onSaved;
  const _EditToppingGroupSheet({this.group, required this.onSaved});
  @override
  ConsumerState<_EditToppingGroupSheet> createState() => _EditToppingGroupSheetState();
}

class _EditToppingGroupSheetState extends ConsumerState<_EditToppingGroupSheet>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _minSelect = 0;
  int _maxSelect = 10;
  bool _saving = false;
  TabController? _innerTab;

  // Topping products available in kho
  List<Map<String, dynamic>> _allToppingProducts = [];
  // Items currently in this group (productId set)
  Set<String> _selectedItemIds = {};
  // Products linked to this group
  List<Map<String, dynamic>> _allMenuProducts = [];
  Set<String> _linkedProductIds = {};
  bool _loadingData = false;

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kNavyL  = Color(0xFF2D2B8A);
  static const _kOrange = Color(0xFFE85D20);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);
  static const _kGreen  = Color(0xFF2E7D32);
  static const _kRed    = Color(0xFFC62828);

  bool get _isEdit => widget.group != null;

  @override
  void initState() {
    super.initState();
    _innerTab = TabController(length: 2, vsync: this);
    final g = widget.group;
    if (g != null) {
      _nameCtrl.text = g.name;
      _descCtrl.text = g.description ?? '';
      _minSelect = g.minSelect;
      _maxSelect = g.maxSelect;
      _selectedItemIds = g.items.map((i) => i.productId).toSet();
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storeId = prefs.getString('auth_store_id') ?? '';
      if (storeId.isEmpty) return;
      // Load all topping products
      final tRows = await Supabase.instance.client
          .from('products')
          .select('id, name, sell_price, unit, topping_unit')
          .eq('store_id', storeId)
          .eq('is_topping', true)
          .eq('is_deleted', false)
          .order('name');
      _allToppingProducts = List<Map<String, dynamic>>.from(tRows as List);
      // Load all menu products (non-topping)
      final mRows = await Supabase.instance.client
          .from('products')
          .select('id, name, category')
          .eq('store_id', storeId)
          .eq('is_topping', false)
          .eq('is_deleted', false)
          .order('name');
      _allMenuProducts = List<Map<String, dynamic>>.from(mRows as List);
      // Load linked products if editing
      if (_isEdit && widget.group != null) {
        final linkedIds = await ToppingGroupRepository().fetchLinkedProductIds(widget.group!.id);
        _linkedProductIds = linkedIds.toSet();
      }
    } catch (e) {
      debugPrint('[EditToppingGroupSheet] _loadData error: $e');
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ToppingGroupRepository();
      String groupId;
      if (_isEdit) {
        groupId = widget.group!.id;
        await repo.updateGroup(groupId,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          minSelect: _minSelect,
          maxSelect: _maxSelect,
        );
      } else {
        final id = await repo.createGroup(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          minSelect: _minSelect,
          maxSelect: _maxSelect,
        );
        if (id == null) throw Exception('Tạo nhóm thất bại');
        groupId = id;
      }
      // Sync items
      await repo.syncGroupItems(groupId, _selectedItemIds.toList());
      // Sync linked products
      await repo.syncGroupProducts(groupId, _linkedProductIds.toList());
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Lỗi: $e'), backgroundColor: _kRed));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa nhóm topping?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Nhóm "${widget.group?.name}" sẽ bị xóa và tách khỏi tất cả sản phẩm.',
          style: const TextStyle(color: _kMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kRed),
            child: const Text('Xóa', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirmed == true) {
      await ToppingGroupRepository().deleteGroup(widget.group!.id);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _innerTab?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          // ── Handle ──
          const SizedBox(height: 10),
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)))),
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1E1C5E), Color(0xFF2D2B8A)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.restaurant_menu_rounded, size: 18, color: _kOrange)),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  _isEdit ? 'Sửa nhóm topping' : 'Tạo nhóm topping mới',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54)),
              ]),
              const SizedBox(height: 10),
              TabBar(
                controller: _innerTab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: _kOrange,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: '⚙️  Cấu hình'),
                  Tab(text: '🍜  Áp dụng cho món'),
                ],
              ),
            ]),
          ),
          // ── Content ──
          Expanded(
            child: TabBarView(controller: _innerTab, children: [
              // ─ Tab 0: Cấu hình ─
              _loadingData
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Tên nhóm
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tên nhóm *',
                        hintText: 'VD: Topping Trà Sữa, Size Ly, Mức Đường Đá',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _kNavy, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descCtrl,
                      decoration: InputDecoration(
                        labelText: 'Mô tả (tuỳ chọn)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _kNavy, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Min/Max select
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Chọn tối thiểu', style: GoogleFonts.outfit(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(children: [
                          GestureDetector(
                            onTap: () => setState(() { if (_minSelect > 0) _minSelect--; }),
                            child: Container(width: 34, height: 34,
                              decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.remove_rounded, size: 16, color: _kNavy))),
                          SizedBox(width: 40, child: Text('$_minSelect',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy))),
                          GestureDetector(
                            onTap: () => setState(() { if (_minSelect < _maxSelect) _minSelect++; }),
                            child: Container(width: 34, height: 34,
                              decoration: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.add_rounded, size: 16, color: Colors.white))),
                        ]),
                      ])),
                      const SizedBox(width: 20),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Chọn tối đa', style: GoogleFonts.outfit(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(children: [
                          GestureDetector(
                            onTap: () => setState(() { if (_maxSelect > _minSelect && _maxSelect > 1) _maxSelect--; }),
                            child: Container(width: 34, height: 34,
                              decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.remove_rounded, size: 16, color: _kNavy))),
                          SizedBox(width: 40, child: Text(_maxSelect >= 10 ? '∞' : '$_maxSelect',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy))),
                          GestureDetector(
                            onTap: () => setState(() { if (_maxSelect < 20) _maxSelect++; }),
                            child: Container(width: 34, height: 34,
                              decoration: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.add_rounded, size: 16, color: Colors.white))),
                        ]),
                      ])),
                    ]),
                    const SizedBox(height: 20),
                    // Topping items trong nhóm
                    Row(children: [
                      Text('Topping trong nhóm',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: _kNavy)),
                      const Spacer(),
                      Text('${_selectedItemIds.length} đã chọn',
                        style: GoogleFonts.outfit(fontSize: 12, color: _kMuted)),
                    ]),
                    const SizedBox(height: 10),
                    if (_allToppingProducts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _kBorder.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Text('⚠️', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            'Chưa có topping nào trong kho.\nVào tab "Hàng hoá" → bật "Là Topping".',
                            style: GoogleFonts.outfit(fontSize: 12, color: _kMuted))),
                        ]),
                      )
                    else
                      ...(_allToppingProducts.map((t) {
                        final tId = t['id'] as String;
                        final isSelected = _selectedItemIds.contains(tId);
                        final price = (t['sell_price'] as num?)?.toDouble() ?? 0;
                        final unit = t['topping_unit'] as String? ?? t['unit'] as String? ?? 'phần';
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (isSelected) _selectedItemIds.remove(tId);
                            else _selectedItemIds.add(tId);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? _kOrange.withValues(alpha: 0.07) : _kBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? _kOrange : _kBorder,
                                width: isSelected ? 1.5 : 1)),
                            child: Row(children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: isSelected ? _kOrange : _kBorder.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(6)),
                                child: isSelected
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                    : null),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(t['name'] as String? ?? '',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                    color: isSelected ? _kOrange : _kNavy)),
                                if (price > 0)
                                  Text('+${(price/1000).toStringAsFixed(0)}k/$unit',
                                    style: GoogleFonts.outfit(fontSize: 11, color: _kMuted)),
                              ])),
                            ]),
                          ),
                        );
                      })),
                    const SizedBox(height: 80),
                  ]),
                ),
              // ─ Tab 1: Áp dụng cho món ─
              _loadingData
                ? const Center(child: CircularProgressIndicator())
                : Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F0FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kNavy.withValues(alpha: 0.15))),
                        child: Row(children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: _kNavyL),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'Tick các món sẽ hiện nhóm topping này khi gọi món',
                            style: GoogleFonts.outfit(fontSize: 12, color: _kNavyL))),
                        ]),
                      ),
                    ),
                    Expanded(
                      child: _allMenuProducts.isEmpty
                        ? Center(child: Text('Chưa có sản phẩm nào',
                            style: GoogleFonts.outfit(color: _kMuted)))
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _allMenuProducts.length,
                          itemBuilder: (_, i) {
                            final p = _allMenuProducts[i];
                            final pId = p['id'] as String;
                            final isLinked = _linkedProductIds.contains(pId);
                            return GestureDetector(
                              onTap: () => setState(() {
                                HapticFeedback.lightImpact();
                                if (isLinked) _linkedProductIds.remove(pId);
                                else _linkedProductIds.add(pId);
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isLinked ? _kNavy.withValues(alpha: 0.05) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isLinked ? _kNavy : _kBorder,
                                    width: isLinked ? 1.5 : 1)),
                                child: Row(children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 22, height: 22,
                                    decoration: BoxDecoration(
                                      color: isLinked ? _kNavy : _kBorder.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(6)),
                                    child: isLinked
                                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                        : null),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(p['name'] as String? ?? '',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13, fontWeight: FontWeight.w700,
                                        color: isLinked ? _kNavy : _kNavy)),
                                    if ((p['category'] as String?)?.isNotEmpty == true)
                                      Text(p['category'] as String,
                                        style: GoogleFonts.outfit(fontSize: 11, color: _kMuted)),
                                  ])),
                                  if (isLinked)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _kNavy, borderRadius: BorderRadius.circular(8)),
                                      child: Text('Đã gắn',
                                        style: GoogleFonts.outfit(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700))),
                                ]),
                              ),
                            );
                          },
                        ),
                    ),
                  ]),
            ]),
          ),
          // ── Bottom Buttons ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _kBorder))),
            child: Row(children: [
              if (_isEdit) ...[
                OutlinedButton.icon(
                  onPressed: _saving ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kRed, side: BorderSide(color: _kRed),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEdit ? _kNavy : _kGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_isEdit ? Icons.save_rounded : Icons.add_circle_rounded),
                  label: Text(
                    _saving ? 'Đang lưu...' : (_isEdit ? 'Lưu thay đổi' : 'Tạo nhóm'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET RIGHT PANEL — Kho Stats Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _InventoryRightPanel extends StatelessWidget {
  final AsyncValue<KhoStats> statsAsync;
  const _InventoryRightPanel({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    final stats = statsAsync.value;

    return Container(
      color: const Color(0xFFF5F0EA),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
        children: [
          _IRCard(
            title: 'Tổng quan kho',
            icon: Icons.inventory_2_rounded,
            child: Column(children: [
              _IRRow(label: 'Sản phẩm', value: '${stats?.totalItems ?? 0}', color: _kNavy),
              const Divider(height: 1),
              _IRRow(label: 'Sắp hết', value: '${stats?.lowStockItems ?? 0}',
                color: (stats?.lowStockItems ?? 0) > 0 ? _kOrange : _kGreen),
              const Divider(height: 1),
              _IRRow(label: 'Hết hàng', value: '${stats?.outOfStockItems ?? 0}',
                color: (stats?.outOfStockItems ?? 0) > 0 ? _kRed : _kGreen),
              const Divider(height: 1),
              _IRRow(label: 'Giá trị kho', value: fmtMoney(stats?.totalValue ?? 0), color: _kNavy),
            ]),
          ),
        ],
      ),
    );
  }
}

class _IRCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _IRCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
        color: _kNavy.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Row(children: [
          Icon(icon, size: 16, color: _kNavy),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.outfit(
            fontSize: 13, fontWeight: FontWeight.w800, color: _kNavy)),
        ]),
      ),
      const Divider(height: 1),
      Padding(padding: const EdgeInsets.all(14), child: child),
    ]),
  );
}

class _IRRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _IRRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 13, color: _kInk))),
      Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
