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
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabCtrl.indexIsChanging) return;
        setState(() => _tabIndex = _tabCtrl.index);
      });
  }

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

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────
          _buildHeader(statsAsync),

          // ── Tabs ───────────────────────────────────────────────────
          Container(
            color: _kNavy,
            child: TabBar(
              controller: _tabCtrl,
              indicatorColor: _kOrange,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                Tab(text: 'Tất cả ($allCount)'),
                Tab(child: _TabLabel('Sắp hết', lowCount,
                    color: const Color(0xFFFF6F00))),
                Tab(child: _TabLabel('Hết hàng', outCount,
                    color: const Color(0xFFC62828))),
              ],
            ),
          ),

          // ── Search bar ─────────────────────────────────────────────
          _buildSearchBar(),

          // ── Content ────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _StockList(
                  watchItems: (ref) => ref.watch(allStockProvider),
                  filterQuery: _searchCtrl.text,
                  onReceive: _openReceiveSheet,
                  onAdjust: _openAdjustDialog,
                  onHistory: _openHistorySheet,
                  onEdit: _openEditProduct,
                ),
                _StockList(
                  watchItems: (ref) => ref.watch(lowStockKhoProvider),
                  filterQuery: _searchCtrl.text,
                  onReceive: _openReceiveSheet,
                  onAdjust: _openAdjustDialog,
                  onHistory: _openHistorySheet,
                  onEdit: _openEditProduct,
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
                      fontSize: 20, fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
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
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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

  void _openAddProduct() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProductSheet(
        product: null,
        onSaved: (name, price, cost, cat, unit, minStock) async {
          await ref.read(productRepositoryProvider).create(
            name: name, sellPrice: price, costPrice: cost,
            category: cat.isEmpty ? null : cat,
            unit: unit.isEmpty ? 'phần' : unit,
            minStock: minStock, isAvailable: true,
          );
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Text('✅ Đã thêm "$name"'),
              behavior: SnackBarBehavior.floating));
          }
        },
      ),
    );
  }

  void _openEditProduct(StockItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProductSheet(
        product: item,
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
              content: Text('Ýên "${item.name}" đã bị ẩn'),
              behavior: SnackBarBehavior.floating));
          }
        },
      ),
    );
  }

  String _fmtShort(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
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
  final String emptyMsg;
  final IconData emptyIcon;
  final Color emptyColor;

  const _StockList({
    required this.watchItems,
    required this.filterQuery,
    required this.onReceive,
    required this.onAdjust,
    required this.onHistory,
    required this.onEdit,
    this.emptyMsg = 'Không có sản phẩm nào',
    this.emptyIcon = Icons.inventory_2_rounded,
    this.emptyColor = _kMuted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = watchItems(ref);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: _kNavy)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (items) {
        // Apply search filter
        final filtered = filterQuery.isEmpty
            ? items
            : items
                .where((i) =>
                    i.name.toLowerCase().contains(filterQuery.toLowerCase()) ||
                    (i.sku?.toLowerCase()
                            .contains(filterQuery.toLowerCase()) ??
                        false))
                .toList();

        if (filtered.isEmpty) {
          return _buildEmpty(emptyMsg, emptyIcon, emptyColor);
        }

        return ListView.builder(
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
        );
      },
    );
  }

  Widget _buildEmpty(String msg, IconData icon, Color color) {
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
// STOCK CARD — 1 item trong danh sách
// ─────────────────────────────────────────────────────────────────────────────
class _StockCard extends StatelessWidget {
  final StockItem item;
  final void Function(StockItem) onReceive;
  final void Function(StockItem) onAdjust;
  final void Function(StockItem) onHistory;
  final void Function(StockItem) onEdit;

  const _StockCard({
    required this.item,
    required this.onReceive,
    required this.onAdjust,
    required this.onHistory,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: _kInk),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusInfo.badgeBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(statusInfo.label,
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
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
                              fontSize: 13, fontWeight: FontWeight.w800,
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
                              _fmtMoney(item.stockValue.toInt()) + 'đ',
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
      case StockStatus.notTracked:
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

  String _fmtMoney(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
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
        productName: widget.item.name,
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
                        final dt = DateTime.fromMillisecondsSinceEpoch(
                            m.createdAt);

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
                                      m.referenceId ?? (isIn ? 'Nhập hàng' : 'Xuất kho'),
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
                const Text('Biến động gần đây',
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: _kInk)),
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
                        final dt = DateTime.fromMillisecondsSinceEpoch(m.createdAt);
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
  final StockItem? product;          // null = chế độ thêm mới
  final Future<void> Function(
    String name, double price, double cost,
    String cat, String unit, double minStock) onSaved;
  final Future<void> Function()? onDelete;

  const _EditProductSheet({
    required this.product,
    required this.onSaved,
    this.onDelete,
  });

  @override
  State<_EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends State<_EditProductSheet> {
  final _formKey    = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _catCtrl;
  late final TextEditingController _minStockCtrl;
  late String _selectedUnit;
  bool _saving = false;

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
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _priceCtrl.dispose(); _costCtrl.dispose();
    _catCtrl.dispose(); _minStockCtrl.dispose();
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
                      // Tên
                      _PField(ctrl: _nameCtrl, label: 'Tên sản phẩm *',
                        icon: Icons.restaurant_menu_rounded, color: _kNavy,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Vui lòng nhập tên' : null),
                      const SizedBox(height: 12),

                      // Giá bán + giá vốn
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
                      const SizedBox(height: 12),

                      // Tồn kho tối thiểu
                      _PField(ctrl: _minStockCtrl, label: 'Tồn tối thiểu (cảnh báo)',
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFE65100),
                        keyboard: TextInputType.number),
                      const SizedBox(height: 12),

                      // Danh mục chips
                      const Text('Danh mục', style: TextStyle(
                        fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: _cats.map((c) {
                        final sel = _catCtrl.text == c;
                        return GestureDetector(
                          onTap: () => setState(() =>
                              _catCtrl.text = sel ? '' : c),
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
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final price = double.tryParse(_priceCtrl.text.replaceAll(',','')) ?? 0;
    final cost  = double.tryParse(_costCtrl.text.replaceAll(',','')) ?? 0;
    final min   = double.tryParse(_minStockCtrl.text) ?? 0;
    await widget.onSaved(
      _nameCtrl.text.trim(), price, cost,
      _catCtrl.text.trim(), _selectedUnit, min);
    if (mounted) setState(() => _saving = false);
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
