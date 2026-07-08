import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/utils/cart_animation_helper.dart';
import '../core/utils/money_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// topping_group_repository.dart - đã deprecated, được thay bằng product_topping_links
import 'package:uuid/uuid.dart';
import '../core/providers/app_providers.dart';
import '../core/providers/dashboard_providers.dart'; // invalidate sau checkout
import '../modules/finance/providers/finance_providers.dart'; // invalidate financeStats sau checkout
import '../core/providers/session_provider.dart';
import '../core/repositories/ban_repository.dart';
import '../core/repositories/core_product_repository.dart';
import '../modules/kho_chuyen_nghiep/repository/kho_chuyen_nghiep_repository.dart';
import '../modules/kho_chuyen_nghiep/providers/kho_chuyen_nghiep_providers.dart'
    show khoProRepositoryProvider;
import '../core/repositories/kitchen_repository.dart';
import '../core/services/store_auth_service.dart';
import '../core/services/user_auth_service.dart';
import '../core/theme/app_colors.dart';
import '../core/services/thermal_printer_service.dart';
import '../core/services/printer_settings_service.dart';
import '../modules/bill_printer/screens/bill_preview_screen.dart'
    show BillData, BillItem, showBillPreview, BillType, StationPrinterDispatcher;
import '../modules/bill_printer/providers/printer_settings_provider.dart';
import 'kitchen_screen.dart' show kitchenReadyStreamProvider;
import '../core/utils/responsive.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BRAND COLORS
// ─────────────────────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kCream  = Color(0xFFFFF8F0);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kAmber  = Color(0xFFF59E0B);

/// Provider kiểm tra module Bếp có đang bật không
/// Dùng activeModulesProvider — tự refresh khi session có và khi module config thay đổi
final kitchenModuleActiveProvider = Provider<bool>((ref) {
  return ref.watch(activeModulesProvider).maybeWhen(
    data: (modules) => modules.any((m) => m.id == 'kitchen'),
    orElse: () => false,
  );
});

/// Provider kiểm tra module In Hoá Đơn có đang bật không
final banBillPrinterModuleActiveProvider = Provider<bool>((ref) {
  return ref.watch(activeModulesProvider).maybeWhen(
    data: (modules) => modules.any((m) => m.id == 'bill_printer'),
    orElse: () => false,
  );
});


// Màu preset cho zones
const _kZoneColors = [
  Color(0xFF1C2151), // Navy
  Color(0xFFFF6B35), // Orange
  Color(0xFF22C55E), // Green
  Color(0xFF3B82F6), // Blue
  Color(0xFFA855F7), // Purple
  Color(0xFF14B8A6), // Teal
  Color(0xFFF43F5E), // Rose
  Color(0xFF64748B), // Slate
  Color(0xFFD97706), // Amber dark
  Color(0xFF059669), // Emerald
];

// Zone icon options (MaterialIcons codepoints)
const _kZoneIconCodes = <int>[
  0xe318, // home_outlined
  0xe1a7, // deck (outdoor)
  0xe7f4, // star_border
  0xe838, // emoji_events (trophy)
  0xe56c, // restaurant_menu
  0xe555, // local_cafe
  0xe51c, // nightlight_round
  0xe0da, // flag_outlined
  0xe01a, // weekend (sofa)
  0xe206, // local_fire_department
];

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────
final banZonesProvider = StreamProvider.autoDispose<List<BanZoneModel>>((ref) {
  return ref.watch(banRepositoryProvider).watchZones();
});

final banTablesForZoneProvider =
    StreamProvider.autoDispose.family<List<BanTableModel>, String>((ref, zoneId) {
  return ref.watch(banRepositoryProvider).watchTablesForZone(zoneId);
});

final allBanTablesProvider = StreamProvider.autoDispose<List<BanTableModel>>((ref) {
  return ref.watch(banRepositoryProvider).watchAllTables();
});

final activeSessionsProvider =
    StreamProvider.autoDispose<Map<String, BanSessionModel>>((ref) {
  return ref.watch(banRepositoryProvider).watchActiveSessions();
});

final sessionItemsProvider =
    StreamProvider.autoDispose.family<List<BanSessionItemModel>, String>((ref, sessionId) {
  return ref.watch(banRepositoryProvider).watchSessionItems(sessionId);
});




/// Stream modifiers của 1 sản phẩm (query Supabase thật)
final productModifiersProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, productId) async* {
  // Poll mỗi 30s (Supabase realtime không hỗ trợ arbitrary tables dễ)
  while (true) {
    try {
      final rows = await Supabase.instance.client
          .from('product_modifiers')
          .select()
          .eq('product_id', productId)
          .eq('is_active', true)
          .order('group_name')
          .order('sort_order');
      yield List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      yield [];
    }
    await Future.delayed(const Duration(seconds: 30));
  }
});

// ── Topping catalog — lấy từ bảng products có is_topping=true ─────────────
final toppingCatalogProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, storeId) async* {
  while (true) {
    try {
      final rows = await Supabase.instance.client
          .from('products')
          .select('id, name, sell_price, unit, topping_unit')
          .eq('store_id', storeId)
          .eq('is_topping', true)
          .eq('is_deleted', false)
          .order('name');
      yield List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      yield [];
    }
    await Future.delayed(const Duration(seconds: 30));
  }
});


// ── Topping products gắn với 1 sản phẩm (flat list, bảng mới) ────────────────
final productToppingLinksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, productId) async {
  final sb = Supabase.instance.client;
  try {
    final links = await sb
        .from('product_topping_links')
        .select('topping_id')
        .eq('product_id', productId);
    if ((links as List).isEmpty) return [];
    // Giữ thứ tự theo danh sách links trả về (inserted_at tự nhiên)
    final orderedIds = links.map((l) => l['topping_id'] as String).toList();
    final products = await sb
        .from('products')
        .select('id, name, sell_price, unit, stock_qty')
        .inFilter('id', orderedIds)
        .eq('is_deleted', false);
    final productList = List<Map<String, dynamic>>.from(products as List);
    // Sort lại theo thứ tự orderedIds (inFilter không đảm bảo thứ tự)
    productList.sort((a, b) {
      final ai = orderedIds.indexOf(a['id'] as String);
      final bi = orderedIds.indexOf(b['id'] as String);
      return ai.compareTo(bi);
    });
    return productList;
  } catch (e) {
    return [];
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class BanScreen extends ConsumerStatefulWidget {
  const BanScreen({super.key});

  @override
  ConsumerState<BanScreen> createState() => _BanScreenState();
}

class _BanScreenState extends ConsumerState<BanScreen> {
  int _selectedZoneIndex = 0;
  List<BanZoneModel> _cachedZones = [];
  String? _syncedStoreId;
  String _statusFilter = 'all'; // 'all' | 'occupied' | 'empty'
  String _tableCardSize = 'vua'; // 'to' | 'vua' | 'nho'

  BanRepository get _banRepo => ref.read(banRepositoryProvider);

  @override
  void dispose() {
    super.dispose();
  }

  /// Gọi khi session có storeId — khởi động sync
  Future<void> _startBanSync(String storeId) async {
    // BanRepository Supabase đã làm realtime sync
    _syncedStoreId = storeId;
  }

  // ── Zone ──
  Future<void> _addZone() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ZoneFormSheet(),
    );
    if (result == null) return;
    try {
      final zones   = await _banRepo.getZones();
      final zoneId  = const Uuid().v4();
      final storeId = await StoreAuthService.getStoreInfo().then((m) => m['store_id'] as String? ?? '');
      if (storeId.isEmpty) throw Exception('Chưa đăng ký quán. Vui lòng đăng xuất và thử lại.');
      await _banRepo.upsertZone(BanZoneModel(
        id: zoneId, storeId: storeId,
        name: result['name'] as String,
        colorValue: int.tryParse(
          ((result['color'] as String? ?? '#1C2151')).replaceAll('#', '0xFF')) ?? 0xFF1C2151,
        iconCode: result['iconCode'] as int,
        sortOrder: zones.length,
        isActive: true,
      ));
      if (mounted) setState(() => _selectedZoneIndex = 0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Lỗi thêm khu: $e', style: GoogleFonts.outfit()),
        backgroundColor: _kRed,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Future<void> _editZone(BanZoneModel zone) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ZoneFormSheet(existing: zone),
    );
    if (result == null) return;
    if (result['delete'] == true) {
      await _banRepo.deactivateZone(zone.id);
      if (mounted) setState(() => _selectedZoneIndex = 0);
    } else {
      await _banRepo.updateZoneName(zone.id, result['name'] as String);
    }
  }

  Future<void> _addTable(String? defaultZoneId) async {
    var zones = await _banRepo.getZones();
    if (zones.isEmpty) {
      await _addZone();
      zones = await _banRepo.getZones();
      if (zones.isEmpty || !mounted) return;
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TableFormSheet(
        zones: zones,
        defaultZoneId: defaultZoneId ?? zones.first.id,
      ),
    );
    if (result == null) return;
    try {
      final batchCount = (result['batchCount'] as int?) ?? 1;
      final zoneId   = result['zoneId'] as String;
      final baseName = result['name'] as String;
      final capacity = result['capacity'] as int;
      final storeInfo = await StoreAuthService.getStoreInfo();
      final storeId = storeInfo['store_id'] as String? ?? '';
      if (storeId.isEmpty) throw Exception('Chưa đăng ký quán. Vui lòng đăng xuất và thử lại.');
      final existing  = zones.where((z) => z.id == zoneId).toList();
      final baseOrder = existing.length;
      for (int i = 0; i < batchCount; i++) {
        final finalName = batchCount == 1 ? baseName : '$baseName ${i + 1}';
        final tableId = const Uuid().v4();
        await _banRepo.upsertTable(BanTableModel(
          id: tableId, zoneId: zoneId, storeId: storeId,
          label: finalName, seats: capacity,
          sortOrder: baseOrder + i, isActive: true,
        ));
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Lỗi thêm bàn: $e', style: GoogleFonts.outfit()),
        backgroundColor: _kRed,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  bool _isOpeningTable = false;

  Future<void> _openTable(BanTableModel table, BanZoneModel zone) async {
    if (_isOpeningTable) return;
    _isOpeningTable = true;
    try {
      final session = await showModalBottomSheet<BanSessionModel>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _OpenTableSheet(
          table: table,
          zone: zone,
          onOpen: (count) => _banRepo.openSession(table.id, guestCount: count),
        ),
      );
      if (session == null) return;
      ref.invalidate(activeSessionsProvider);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        enableDrag: false,
        builder: (_) => _TableSessionSheet(
          table: table,
          session: session,
          zone: zone,
          autoOpenOrder: true,
        ),
      );
    } finally {
      _isOpeningTable = false;
    }
  }

  Future<void> _manageSession(
      BanTableModel table, BanSessionModel session, BanZoneModel zone) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (_) => _TableSessionSheet(
        table: table,
        session: session,
        zone: zone,
      ),
    );
  }

  void _showTableOptions(
      BanTableModel table, BanSessionModel? session, BanZoneModel zone) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TableOptionsSheet(
        table: table,
        session: session,
        onEdit: () async {
          Navigator.pop(context);
          final zones = await _banRepo.getZones();
          if (!mounted) return;
          final result = await showModalBottomSheet<Map<String, dynamic>>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => _TableFormSheet(
              zones: zones,
              defaultZoneId: table.zoneId,
              existing: table,
            ),
          );
          if (result == null) return;
          if (result['delete'] == true) {
            await _banRepo.deactivateTable(table.id);
          } else {
            await _banRepo.upsertTable(BanTableModel(
              id: table.id, zoneId: result['zoneId'] as String,
              storeId: table.storeId, label: result['name'] as String,
              seats: result['capacity'] as int,
              sortOrder: table.sortOrder, isActive: true,
            ));
          }
        },
        onTransfer: session == null ? null : () {
          Navigator.pop(context); // đóng options sheet
          // Mở transfer sheet trực tiếp từ context menu
          final activeSessions = ref.read(activeSessionsProvider).value ?? {};
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _TransferTableSheet(
              currentTableId: table.id,
              currentTableLabel: table.label,
              activeSessions: activeSessions,
              onConfirm: (newTableId) async {
                await _banRepo.transferSession(session!.id, newTableId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Chuyển bàn thành công!',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    backgroundColor: _kGreen,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                }
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(banZonesProvider);
    final allTablesAsync = ref.watch(allBanTablesProvider);
    final activeSessionsAsync = ref.watch(activeSessionsProvider);

    // Khi session load xong (từ null → có storeId) → bắt đầu sync
    ref.listen<SessionData?>(sessionProvider, (previous, next) {
      final storeId = next?.storeId;
      if (storeId != null) {
        _startBanSync(storeId);
      }
    });
    // Cũng check ngay tại build này (trường hợp session đã có sẵn)
    final currentStoreId = ref.read(sessionProvider)?.storeId;
    if (currentStoreId != null) _startBanSync(currentStoreId);

    // ── Thông báo nhân viên khi bếp báo xong món ──
    ref.listen<AsyncValue<String>>(kitchenReadyStreamProvider, (_, next) {
      next.whenData((tableLabel) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$tableLabel: Món ăn đã sẵn sàng!',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      });
    });

    return Scaffold(
      backgroundColor: _kCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Quản lý bàn',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _kNavy,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded, color: _kNavy),
            tooltip: 'Thêm khu vực',
            onPressed: _addZone,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEBE6)),
        ),
      ),
      body: zonesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _kNavy),
        ),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (zones) {
          if (_cachedZones.length != zones.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _cachedZones = zones);
            });
          } else {
            _cachedZones = zones;
          }

          // ── Grid bàn (dùng chung cho cả phone lẫn tablet) ──────────────
          Widget tableGrid = _buildTableGrid(zones);

          // ── Tablet: Two Column ──────────────────────────────────────────
          return LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth > 700) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cột trái: ZoneTabBar + Grid bàn
                  Expanded(flex: 3, child: tableGrid),
                  // Cột phải: Panel tổng quan (fixed 280px)
                  SizedBox(
                    width: 280,
                    child: _BanRightPanel(zones: zones),
                  ),
                ],
              );
            }
            // Phone: layout cũ, không thay đổi gì
            return tableGrid;
          });
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ban_screen_fab',
        onPressed: () {
          final zoneId = _selectedZoneIndex > 0 &&
                  _selectedZoneIndex - 1 < _cachedZones.length
              ? _cachedZones[_selectedZoneIndex - 1].id
              : null;
          _addTable(zoneId);
        },
          backgroundColor: _kNavy,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'Thêm bàn',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
    );
  }

  Widget _buildFilterChip({required String label, required String value, required Color color}) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFEEEBE6),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value == 'occupied') ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : _kRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ] else if (value == 'empty') ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : _kGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF1C2151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeToggleItem(String size, String label) {
    final isSelected = _tableCardSize == size;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _tableCardSize = size);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _kNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : _kNavy.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    if (_tableCardSize == 'nho') {
      return isMobile ? 4 : isTablet ? 5 : 6;
    } else if (_tableCardSize == 'vua') {
      return isMobile ? 3 : isTablet ? 4 : 5;
    } else { // 'to'
      return isMobile ? 2 : isTablet ? 3 : 4;
    }
  }

  double _getAspectRatio(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    if (_tableCardSize == 'nho') {
      return isMobile ? 1.05 : 1.15;
    } else if (_tableCardSize == 'vua') {
      return isMobile ? 1.18 : 1.3;
    } else { // 'to'
      return isMobile ? 1.22 : 1.45;
    }
  }

  // ── Helper: Grid bàn tách ra để dùng lại ─────────────────────────────────
  Widget _buildTableGrid(List<BanZoneModel> zones) {
    final activeSessionsAsync = ref.watch(activeSessionsProvider);
    final allTablesAsync = ref.watch(allBanTablesProvider);

    return Column(children: [
      _ZoneTabBar(
        zones: zones,
        selectedIndex: _selectedZoneIndex,
        onSelect: (i) => setState(() => _selectedZoneIndex = i),
        onLongPress: (zone) => _editZone(zone),
        onAddZone: _addZone,
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        color: Colors.white,
        child: Row(
          children: [
            _buildFilterChip(label: 'Tất cả bàn', value: 'all', color: _kNavy),
            const SizedBox(width: 8),
            _buildFilterChip(label: 'Đang có khách', value: 'occupied', color: _kRed),
            const SizedBox(width: 8),
            _buildFilterChip(label: 'Bàn trống', value: 'empty', color: _kGreen),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300.withValues(alpha: 0.8)),
              ),
              child: Row(
                children: [
                  _buildSizeToggleItem('to', 'To'),
                  _buildSizeToggleItem('vua', 'Vừa'),
                  _buildSizeToggleItem('nho', 'Nhỏ'),
                ],
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1, color: Color(0xFFEEEBE6)),
      Expanded(
        child: activeSessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (activeSessions) {
            return allTablesAsync.when(
              loading: () => const SizedBox(),
              error: (e, _) => const SizedBox(),
              data: (allTables) {
                if (allTables.isEmpty) {
                  return _EmptyState(
                    onAddZone: _addZone,
                    onAddTable: () => _addTable(null),
                  );
                }
                final zoneFiltered = _selectedZoneIndex == 0
                    ? allTables
                    : zones.isNotEmpty &&
                            _selectedZoneIndex - 1 < zones.length
                        ? allTables
                            .where((t) =>
                                t.zoneId ==
                                zones[_selectedZoneIndex - 1].id)
                            .toList()
                        : allTables;

                var filtered = zoneFiltered;
                if (_statusFilter == 'occupied') {
                  filtered = zoneFiltered.where((t) => activeSessions.containsKey(t.id)).toList();
                } else if (_statusFilter == 'empty') {
                  filtered = zoneFiltered.where((t) => !activeSessions.containsKey(t.id)).toList();
                }

                if (filtered.isEmpty) {
                  if (_statusFilter != 'all') {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _statusFilter == 'occupied' ? Icons.people_outline_rounded : Icons.check_circle_outline_rounded,
                              size: 48,
                              color: const Color(0xFF9E9085),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _statusFilter == 'occupied' ? 'Hiện tại không có bàn nào có khách' : 'Không có bàn nào trống',
                              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF9E9085), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return _EmptyState(
                    onAddZone: _addZone,
                    onAddTable: () => _addTable(
                      _selectedZoneIndex > 0 &&
                              _selectedZoneIndex - 1 < zones.length
                          ? zones[_selectedZoneIndex - 1].id
                          : null,
                    ),
                  );
                }

                // "Tất cả" — hiển thị phân nhóm theo khu vực
                if (_selectedZoneIndex == 0) {
                  return CustomScrollView(
                    slivers: zones.map((zone) {
                      final zoneTables = filtered
                          .where((t) => t.zoneId == zone.id)
                          .toList();
                      if (zoneTables.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                      final zoneColor = Color(zone.colorValue);
                      return SliverMainAxisGroup(slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: zoneColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(IconData(zone.iconCode, fontFamily: 'MaterialIcons'),
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text(zone.name,
                                      style: GoogleFonts.outfit(
                                          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                                ]),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${zoneTables.length} bàn  •  '
                                '${zoneTables.where((t) => activeSessions.containsKey(t.id)).length} có khách',
                                style: GoogleFonts.outfit(
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: _kNavy.withValues(alpha: 0.65)),
                              ),
                            ]),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _getCrossAxisCount(context),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: _getAspectRatio(context),
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final table = zoneTables[i];
                                final session = activeSessions[table.id];
                                return _TableCard(
                                  table: table, session: session, zone: zone,
                                  cardSize: _tableCardSize,
                                  onTap: () => session != null
                                      ? _manageSession(table, session, zone)
                                      : _openTable(table, zone),
                                  onLongPress: () => _showTableOptions(table, session, zone),
                                );
                              },
                              childCount: zoneTables.length,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Divider(height: 1, color: _kNavy.withValues(alpha: 0.07)),
                          ),
                        ),
                      ]);
                    }).toList()
                      ..add(const SliverToBoxAdapter(child: SizedBox(height: 80))),
                  );
                }

                // Zone cụ thể
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _getCrossAxisCount(context),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: _getAspectRatio(context),
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final table = filtered[i];
                    final session = activeSessions[table.id];
                    final zone = zones.firstWhere(
                      (z) => z.id == table.zoneId,
                      orElse: () => zones.first,
                    );
                    return _TableCard(
                      table: table, session: session, zone: zone,
                      cardSize: _tableCardSize,
                      onTap: () => session != null
                          ? _manageSession(table, session, zone)
                          : _openTable(table, zone),
                      onLongPress: () => _showTableOptions(table, session, zone),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RIGHT PANEL — Tổng quan bàn (chỉ hiện trên tablet)
// ─────────────────────────────────────────────────────────────────────────────
class _BanRightPanel extends ConsumerWidget {
  final List<BanZoneModel> zones;
  const _BanRightPanel({required this.zones});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTablesAsync      = ref.watch(allBanTablesProvider);
    final activeSessionsAsync = ref.watch(activeSessionsProvider);

    return Container(
      color: const Color(0xFFF5F0EA),
      child: allTablesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => const SizedBox(),
        data: (allTables) => activeSessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (e, _) => const SizedBox(),
          data: (activeSessions) {
            final occupied = allTables
                .where((t) => activeSessions.containsKey(t.id))
                .toList();
            final emptyCount = allTables.length - occupied.length;

            final totalGuests = activeSessions.values
                .fold<int>(0, (s, sess) => s + sess.guestCount);

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
              children: [
                // ── Tổng quan ────────────────────────────────────────────
                _RightCard(
                  title: 'Tổng quan',
                  icon: Icons.dashboard_rounded,
                  child: Column(children: [
                    _StatusRow(
                      label: 'Trống',
                      value: '$emptyCount bàn',
                      color: const Color(0xFF2E7D32),
                    ),
                    const Divider(height: 1),
                    _StatusRow(
                      label: 'Đang phục vụ',
                      value: '${occupied.length} bàn',
                      color: const Color(0xFFE65100),
                    ),
                    const Divider(height: 1),
                    _StatusRow(
                      label: 'Tổng',
                      value: '${allTables.length} bàn',
                      color: _kNavy,
                    ),
                    const Divider(height: 1),
                    _StatusRow(
                      label: 'Số khách',
                      value: '$totalGuests người',
                      color: const Color(0xFF1565C0),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                // ── Bàn đang phục vụ ─────────────────────────────────────
                _RightCard(
                  title: 'Đang phục vụ',
                  icon: Icons.people_rounded,
                  child: occupied.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Chưa có bàn nào có khách',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: const Color(0xFF9E9085)),
                          ),
                        )
                      : Column(
                          children: occupied.map((table) {
                            final session = activeSessions[table.id]!;
                            final zone = zones.firstWhere(
                              (z) => z.id == table.zoneId,
                              orElse: () => zones.first,
                            );
                            return _ActiveTableRow(
                              table: table,
                              session: session,
                              zone: zone,
                            );
                          }).toList(),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Row bàn đang phục vụ — watch sessionItems riêng để lấy số tiền
class _ActiveTableRow extends ConsumerWidget {
  final BanTableModel   table;
  final BanSessionModel session;
  final BanZoneModel    zone;
  const _ActiveTableRow({
    required this.table,
    required this.session,
    required this.zone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(sessionItemsProvider(session.id));
    final activeItems = itemsAsync.value?.where((i) => i.kitchenStatus != 'huy') ?? [];
    final total = activeItems.fold<double>(0, (s, item) => s + item.subtotal);

    final elapsed = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(session.openedAt));
    final minutes = elapsed.inMinutes;
    final timeStr = minutes >= 60
        ? '${elapsed.inHours}h${(minutes % 60).toString().padLeft(2, '0')}p'
        : '${minutes}p';

    final isLong  = minutes > 180; // > 3 tiếng → cảnh báo
    final zoneColor = Color(zone.colorValue);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hàng 1: Dot + Tên bàn + Thời gian + Nút đóng
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: zoneColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                table.label,
                style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy),
              ),
            ),
            if (isLong)
              const Icon(Icons.warning_amber_rounded,
                  size: 13, color: Color(0xFFC62828)),
            const SizedBox(width: 2),
            Text(
              timeStr,
              style: GoogleFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: isLong ? const Color(0xFFC62828) : const Color(0xFF9E9085),
              ),
            ),
            // Nút đóng session — hit area 36x36
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _confirmClose(context, ref, total),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 36, height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: Color(0xFFC62828)),
                ),
              ),
            ),
          ]),
          // Hàng 2: Zone + số khách + số tiền
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2),
            child: Row(children: [
              Text(zone.name,
                style: GoogleFonts.outfit(
                    fontSize: 11, color: const Color(0xFF9E9085))),
              const SizedBox(width: 6),
              // Số khách
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${session.guestCount} khách',
                  style: GoogleFonts.outfit(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: const Color(0xFF1565C0)),
                ),
              ),
              const Spacer(),
              if (total > 0)
                Text(fmtVnd(total),
                  style: GoogleFonts.outfit(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _kNavy)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Divider(height: 1, color: Color(0xFFF0EDE9)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClose(
      BuildContext context, WidgetRef ref, double total) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Đóng session "${table.label}"?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(
          'Session này đang mở ${_elapsedStr()}. Bạn có chắc muốn đóng không?',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Huỷ', style: GoogleFonts.outfit()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Đóng session',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repo = ref.read(banRepositoryProvider);
    await repo.closeSession(session.id, total);
  }

  String _elapsedStr() {
    final elapsed = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(session.openedAt));
    final m = elapsed.inMinutes;
    return m >= 60 ? '${elapsed.inHours}h${m % 60}p' : '${m}p';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RIGHT PANEL HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _RightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _RightCard({required this.title, required this.icon, required this.child});

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

class _StatusRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatusRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 13, color: _kNavy))),
      Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ZONE TAB BAR
// ─────────────────────────────────────────────────────────────────────────────
class _ZoneTabBar extends StatelessWidget {
  final List<BanZoneModel> zones;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<BanZoneModel> onLongPress;
  final VoidCallback onAddZone;

  const _ZoneTabBar({
    required this.zones,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLongPress,
    required this.onAddZone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _ZoneChip(
                  label: 'Tất cả',
                  iconCode: 0xe1b1,
                  color: _kNavy,
                  isSelected: selectedIndex == 0,
                  onTap: () => onSelect(0),
                  onLongPress: null,
                ),
                const SizedBox(width: 8),
                ...zones.asMap().entries.map((e) {
                  final i = e.key + 1;
                  final zone = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ZoneChip(
                      label: zone.name,
                      iconCode: zone.iconCode,
                      color: Color(zone.colorValue),
                      isSelected: selectedIndex == i,
                      onTap: () => onSelect(i),
                      onLongPress: () => onLongPress(zone),
                    ),
                  );
                }),
                _ZoneChip(
                  label: 'Thêm khu',
                  iconCode: 0xe145,
                  color: AppColors.inkFaded,
                  isSelected: false,
                  onTap: onAddZone,
                  onLongPress: null,
                  isDashed: true,
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFEEEBE6)),
        ],
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  final String label;
  final int iconCode;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isDashed;

  const _ZoneChip({
    required this.label,
    required this.iconCode,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDashed
                ? color.withValues(alpha: 0.4)
                : isSelected
                    ? color
                    : color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              IconData(iconCode, fontFamily: 'MaterialIcons'),
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLE CARD (Grid mode)
// ─────────────────────────────────────────────────────────────────────────────
class _TableCard extends ConsumerWidget {
  final BanTableModel table;
  final BanSessionModel? session;
  final BanZoneModel zone;
  final String cardSize; // 'to' | 'vua' | 'nho'
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TableCard({
    required this.table,
    required this.session,
    required this.zone,
    required this.cardSize,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOccupied = session != null;
    final zoneColor = Color(zone.colorValue);

    final itemsAsync = isOccupied
        ? ref.watch(sessionItemsProvider(session!.id))
        : null;

    final activeItems = itemsAsync?.value?.where((i) => i.kitchenStatus != 'huy') ?? [];
    final totalAmount = activeItems.fold<double>(0, (sum, item) => sum + item.subtotal);

    // Kích thước động theo cardSize
    final double paddingVal = cardSize == 'nho' ? 8.0 : cardSize == 'vua' ? 11.0 : 14.0;
    final double iconSizeVal = cardSize == 'nho' ? 16.0 : cardSize == 'vua' ? 20.0 : 24.0;
    final double statusFontSize = cardSize == 'nho' ? 9.0 : cardSize == 'vua' ? 10.0 : 11.0;
    final double labelFontSize = cardSize == 'nho' ? 15.0 : cardSize == 'vua' ? 18.5 : 22.0;
    final double infoFontSize = cardSize == 'nho' ? 10.5 : cardSize == 'vua' ? 11.5 : 13.0;
    final double amountFontSize = cardSize == 'nho' ? 13.0 : cardSize == 'vua' ? 15.5 : 18.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isOccupied ? zoneColor : Colors.white,
          borderRadius: BorderRadius.circular(cardSize == 'nho' ? 12 : 16),
          border: Border.all(
            color: isOccupied
                ? zoneColor
                : zoneColor.withValues(alpha: 0.3),
            width: isOccupied ? 0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isOccupied
                  ? zoneColor.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: isOccupied ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(paddingVal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    IconData(zone.iconCode, fontFamily: 'MaterialIcons'),
                    size: iconSizeVal,
                    color: isOccupied
                        ? Colors.white.withValues(alpha: 0.8)
                        : Color(zone.colorValue),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: cardSize == 'nho' ? 6 : cardSize == 'vua' ? 8 : 10,
                      vertical: cardSize == 'nho' ? 2 : cardSize == 'vua' ? 3 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOccupied
                          ? Colors.white.withValues(alpha: 0.2)
                          : _kGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(cardSize == 'nho' ? 6 : 8),
                    ),
                    child: Text(
                      isOccupied ? '● Có khách' : '○ Trống',
                      style: GoogleFonts.outfit(
                        fontSize: statusFontSize,
                        fontWeight: FontWeight.w600,
                        color: isOccupied ? Colors.white : _kGreen,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    table.label,
                    style: GoogleFonts.outfit(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.w900,
                      color: isOccupied ? Colors.white : _kNavy,
                    ),
                  ),
                  SizedBox(height: cardSize == 'nho' ? 0 : 2),
                  if (isOccupied) ...[
                    Text(
                      '${session!.guestCount} khách',
                      style: GoogleFonts.outfit(
                        fontSize: infoFontSize,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ] else
                    Text(
                      '${table.seats} chỗ',
                      style: GoogleFonts.outfit(
                        fontSize: infoFontSize,
                        fontWeight: FontWeight.w500,
                        color: _kNavy.withValues(alpha: 0.55),
                      ),
                    ),
                  if (isOccupied && totalAmount > 0) ...[
                    SizedBox(height: cardSize == 'nho' ? 2 : 6),
                    Text(
                      fmtVnd(totalAmount),
                      style: GoogleFonts.outfit(
                        fontSize: amountFontSize,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dùng fmtVnd() từ money_formatter.dart
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAddZone;
  final VoidCallback onAddTable;
  const _EmptyState({required this.onAddZone, required this.onAddTable});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🪑', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Bắt đầu thiết lập',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _kNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thêm khu vực (Trong nhà, Ngoài trời...)\nRồi thêm bàn vào từng khu',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                height: 1.6,
                color: _kNavy.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddTable,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'Bắt đầu thiết lập ngay',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700, fontSize: 15),
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
// OPEN TABLE SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _OpenTableSheet extends StatefulWidget {
  final BanTableModel table;
  final BanZoneModel zone;
  final Future<BanSessionModel> Function(int count) onOpen;
  const _OpenTableSheet({required this.table, required this.zone, required this.onOpen});

  @override
  State<_OpenTableSheet> createState() => _OpenTableSheetState();
}

class _OpenTableSheetState extends State<_OpenTableSheet> {
  int _count = 1;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final zoneColor = Color(widget.zone.colorValue);
    return PopScope(
      canPop: !_isLoading,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            decoration: BoxDecoration(
              color: _kCream,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kNavy.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: zoneColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        IconData(widget.zone.iconCode, fontFamily: 'MaterialIcons'),
                        size: 20,
                        color: zoneColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.zone.name} · ${widget.table.label}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: zoneColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Số khách',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: _kNavy.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CounterButton(
                      icon: Icons.remove_rounded,
                      onTap: _isLoading
                          ? () {}
                          : () {
                              if (_count > 1) setState(() => _count--);
                            },
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        '$_count',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: _kNavy,
                        ),
                      ),
                    ),
                    _CounterButton(
                      icon: Icons.add_rounded,
                      onTap: _isLoading
                          ? () {}
                          : () {
                              setState(() => _count++);
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Sức chứa tiêu chuẩn: ${widget.table.seats} người (Có thể thêm ghế)',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: _kNavy.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              try {
                                final session = await widget.onOpen(_count);
                                if (mounted) {
                                  Navigator.pop(context, session);
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _isLoading = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Lỗi mở bàn: $e',
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                      backgroundColor: _kRed,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: zoneColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: zoneColor.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Mở bàn',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Đang mở bàn...',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _kNavy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: _kNavy, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLE SESSION SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _TableSessionSheet extends ConsumerStatefulWidget {
  final BanTableModel table;
  final BanSessionModel session;
  final BanZoneModel zone;
  final bool autoOpenOrder; // A1: tự mở gọi món sau khi mở bàn

  const _TableSessionSheet({
    required this.table,
    required this.session,
    required this.zone,
    this.autoOpenOrder = false,
  });

  @override
  ConsumerState<_TableSessionSheet> createState() =>
      _TableSessionSheetState();
}

class _TableSessionSheetState extends ConsumerState<_TableSessionSheet> {
  bool _isCancelling = false;
  // Map lưu TextEditingController theo item.id — tránh tạo mới mỗi build
  final Map<String, TextEditingController> _noteControllers = {};

  BanRepository get _banRepo => ref.read(banRepositoryProvider);

  @override
  void initState() {
    super.initState();
    // A1: Tự động mở gỌd món sau khi mở bàn lần đầu
    if (widget.autoOpenOrder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addItems();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }


  // Dùng fmtVnd() từ money_formatter.dart

  Future<void> _addItems() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddItemsSheet(sessionId: widget.session.id),
    );
  }

  Future<void> _removeItem(BanSessionItemModel item) async {
    final status = item.kitchenStatus;

    // Món chưa gửi bếp → xoá bình thường
    if (status == 'chua_gui') {
      await _banRepo.removeSessionItem(item.id);
      ref.invalidate(sessionItemsProvider(widget.session.id));
      HapticFeedback.lightImpact();
      return;
    }

    // Món bếp đã xong → không cho xoá
    if (status == 'xong') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Món "${item.productName}" bếp đã xong, không thể xoá.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            backgroundColor: _kAmber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    // Món đã gửi / đang làm → confirm dialog có lý do bắt buộc
    final label = status == 'dang_lam' ? '⚠️ Bếp đang làm món này!' : '📋 Món đã gửi bếp';
    String? selectedReason;
    final confirm = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Huỷ món?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label\nBếp sẽ thấy thông báo huỷ.', style: GoogleFonts.outfit(height: 1.5, fontSize: 14)),
              const SizedBox(height: 14),
              Text('Lý do huỷ *', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              for (final r in ['Khách đổi ý', 'Nhân viên nhập nhầm', 'Hết món', 'Khác'])
                RadioListTile<String>(
                  dense: true, contentPadding: EdgeInsets.zero,
                  title: Text(r, style: GoogleFonts.outfit(fontSize: 13)),
                  value: r, groupValue: selectedReason,
                  onChanged: (v) => setS(() => selectedReason = v),
                  activeColor: _kOrange,
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Không', style: GoogleFonts.outfit(color: _kNavy))),
            TextButton(
              onPressed: selectedReason == null ? null : () => Navigator.pop(ctx, selectedReason),
              child: Text('Huỷ món', style: GoogleFonts.outfit(
                color: selectedReason == null ? Colors.grey : _kRed, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    if (confirm == null) return;

    // Phê duyệt Quản lý khi huỷ món đã gửi bếp
    final approval = await _verifyManagerApproval();
    if (approval == null) return;

    await _executeCancelItem(item, confirm, approvedBy: approval);
  }

  /// Thực thi huỷ món (soft delete) — dùng chung cho _removeItem và _updateItemQty
  /// Không hiện dialog — reason đã được lấy từ dialog gọi trước
  Future<void> _executeCancelItem(
      BanSessionItemModel item, String reason,
      {required Map<String, String> approvedBy}) async {
    final sb = Supabase.instance.client;
    // 1. Soft delete: đánh dấu 'huy' (KHÔNG hard delete để tránh FK violation)
    await sb.from('ban_session_items')
        .update({'kitchen_status': 'huy'})
        .eq('id', item.id);
    // 2. Đánh dấu kitchen_ticket_items done=true
    await sb.from('kitchen_ticket_items')
        .update({'done': true})
        .eq('session_item_id', item.id);
    // 3. Cancel ticket nếu toàn bộ items đều done
    try {
      final ticketRows = await sb.from('kitchen_ticket_items')
          .select('ticket_id').eq('session_item_id', item.id);
      for (final row in ticketRows) {
        final ticketId = row['ticket_id'] as String?;
        if (ticketId == null) continue;
        final remaining = await sb.from('kitchen_ticket_items')
            .select('id').eq('ticket_id', ticketId).eq('done', false);
        if (remaining.isEmpty) {
          await sb.from('kitchen_tickets').update({
            'status': 'huy',
            'done_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', ticketId).inFilter('status', ['cho', 'dang_lam']);
        } else {
          final ticketRow = await sb.from('kitchen_tickets')
              .select('order_note').eq('id', ticketId).maybeSingle();
          await sb.from('kitchen_tickets').update({
            'order_note': ticketRow?['order_note'],
          }).eq('id', ticketId);
        }
      }
    } catch (e) {
      debugPrint('[Ban] _executeCancelItem ticket err: $e');
    }
    // 4. Ghi void log → bếp thấy banner thông báo
    try {
      final storeInfo = await StoreAuthService.getStoreInfo();
      final storeId   = storeInfo['store_id'] as String?;
      final staffName = storeInfo['display_name'] as String?
                     ?? storeInfo['email']        as String?
                     ?? 'Nhân viên';
      if (storeId != null) {
        await sb.from('ban_session_void_logs').insert({
          'store_id':     storeId,
          'session_id':   widget.session.id,
          'table_label':  widget.table.label,
          'product_name': item.productName,
          'action':       'cancel',
          'old_qty':      item.quantity,
          'new_qty':      0,
          'reason':       reason,
          'staff_name':   staffName,
        });
        debugPrint('[Ban] ✅ void log CANCEL inserted');
      }
    } catch (e) {
      debugPrint('[Ban] void log err: $e');
    }

    // 5. Ghi nhận lịch sử kiểm toán huỷ món vào void_audit_logs
    try {
      final session = ref.read(sessionProvider);
      await _banRepo.logVoidEvent(
        voidType: 'void_item',
        referenceId: item.id,
        label: '${widget.table.label} (Món: ${item.productName})',
        requestedByUserId: session?.userId ?? '',
        requestedByName: session?.displayName ?? 'Nhân viên',
        approvedByUserId: approvedBy['id'] ?? '',
        approvedByName: approvedBy['name'] ?? 'Quản lý',
        reason: reason,
        amount: item.subtotal,
        details: [{
          'product_name': item.productName,
          'quantity': item.quantity,
          'subtotal': item.subtotal,
        }],
      );
      debugPrint('[Ban] ✅ void audit log CANCEL_ITEM inserted');
    } catch (e) {
      debugPrint('[Ban] void_audit_logs void_item err: $e');
    }

    HapticFeedback.mediumImpact();
    ref.invalidate(sessionItemsProvider(widget.session.id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Đã huỷ "${item.productName}" — bếp đã được thông báo',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _updateItemQty(BanSessionItemModel item, int newQty) async {
    debugPrint('[BAN-TEST] _updateItemQty: ${item.productName} newQty=$newQty status=${item.kitchenStatus}');
    final sentStatuses = ['da_gui', 'dang_lam', 'xong'];
    final isSent = sentStatuses.contains(item.kitchenStatus);

    // ─── Chưa gửi bếp: sửa tự do ───────────────────────────────────────────
    if (!isSent) {
      if (newQty <= 0) {
        await _removeItem(item);
        return;
      }
      await Supabase.instance.client
          .from('ban_session_items')
          .update({
            'quantity': newQty.toDouble(),
            'subtotal': item.price * newQty,
          })
          .eq('id', item.id);
      ref.invalidate(sessionItemsProvider(widget.session.id));
      HapticFeedback.selectionClick();
      return;
    }

    // ─── Đã gửi bếp: bắt buộc chọn lý do ───────────────────────────────────
    // Xác định hành động: giảm qty hay huỷ cả món
    final isCancel = newQty <= 0;
    String? selectedReason;
    final confirm = await showDialog<String>(
      context: context,
      barrierDismissible: false,
        builder: (_) => StatefulBuilder(
          builder: (ctx, setS) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: _kCream,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isCancel ? _kRed : _kOrange).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCancel ? Icons.cancel_rounded : Icons.edit_rounded,
                        color: isCancel ? _kRed : _kOrange, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(isCancel ? 'Huỷ món?' : 'Giảm số lượng?',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800, fontSize: 18, color: _kNavy)),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kNavy.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isCancel
                          ? '"${item.productName}"\nHuỷ ${item.quantity.toStringAsFixed(0)} phần'
                          : '"${item.productName}"\n${item.quantity.toStringAsFixed(0)} → $newQty phần',
                      style: GoogleFonts.outfit(
                        fontSize: 14, height: 1.5, color: _kNavy, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Lý do *',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700, fontSize: 13, color: _kNavy)),
                  const SizedBox(height: 8),
                  for (final r in ['Khách đổi ý', 'Nhân viên nhập nhầm', 'Hết món', 'Khác'])
                    GestureDetector(
                      onTap: () => setS(() => selectedReason = r),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: selectedReason == r ? _kOrange.withValues(alpha: 0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedReason == r ? _kOrange : _kNavy.withValues(alpha: 0.12),
                            width: selectedReason == r ? 1.5 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedReason == r ? _kOrange : _kNavy.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: selectedReason == r
                                ? Center(child: Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: _kOrange),
                                  ))
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Text(r, style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: selectedReason == r ? FontWeight.w700 : FontWeight.w500,
                            color: selectedReason == r ? _kOrange : _kNavy,
                          )),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kNavy,
                          side: BorderSide(color: _kNavy.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Không', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedReason == null
                            ? null
                            : () => Navigator.pop(ctx, selectedReason),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCancel ? _kRed : _kOrange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _kNavy.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Xác nhận', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
    if (confirm == null) return; // user cancel → không sửa
    final reason = confirm;
    final sb2 = Supabase.instance.client;

    // Huỷ cả món khi qty → 0 — dùng _executeCancelItem (không dialog lần 2)
    if (isCancel) {
      final approval = await _verifyManagerApproval();
      if (approval == null) return;
      await _executeCancelItem(item, reason, approvedBy: approval);
      HapticFeedback.selectionClick();
      return;
    }

    // ─── Giảm qty từng phần ─────────────────────────────────────────────────
    try {
      await sb2.from('ban_session_items')
          .update({'quantity': newQty.toDouble(), 'subtotal': item.price * newQty})
          .eq('id', item.id);

      // ‼️ FIX: Force UI refresh — stream cần invalidate để hiện qty mới
      ref.invalidate(sessionItemsProvider(widget.session.id));

      // Đồng bộ qty sang kitchen_ticket_items để bếp thấy số đúng
      try {
        await sb2.from('kitchen_ticket_items')
            .update({'quantity': newQty.toDouble()})
            .eq('session_item_id', item.id);
        // Touch kitchen_tickets → trigger Realtime cho màn bếp refresh
        final ticketRows = await sb2.from('kitchen_ticket_items')
            .select('ticket_id').eq('session_item_id', item.id);
        for (final row in ticketRows) {
          final ticketId = row['ticket_id'] as String?;
          if (ticketId == null) continue;
          final t = await sb2.from('kitchen_tickets')
              .select('status').eq('id', ticketId).maybeSingle();
          if (t != null) {
            await sb2.from('kitchen_tickets')
                .update({'status': t['status']})
                .eq('id', ticketId);
          }
        }
      } catch (e) {
        debugPrint('[Ban] reduce_qty kitchen sync err: $e');
      }

      // Ghi void log
      try {
        final storeInfo = await StoreAuthService.getStoreInfo();
        final storeId   = storeInfo['store_id'] as String?;
        final staffName = storeInfo['display_name'] as String?
                       ?? storeInfo['email']        as String?
                       ?? 'Nhân viên';
        if (storeId != null) {
          await sb2.from('ban_session_void_logs').insert({
            'store_id':     storeId,
            'session_id':   widget.session.id,
            'table_label':  widget.table.label,
            'product_name': item.productName,
            'action':       'reduce_qty',
            'old_qty':      item.quantity,
            'new_qty':      newQty.toDouble(),
            'reason':       reason,
            'staff_name':   staffName,
          });
        }
      } catch (e) {
        debugPrint('[Ban] reduce_qty void log err: $e');
      }

      HapticFeedback.selectionClick();
      ref.invalidate(sessionItemsProvider(widget.session.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✏️ "${item.productName}": ${item.quantity.toInt()} → $newQty phần',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          backgroundColor: _kOrange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      debugPrint('[Ban] ❌ reduce_qty FAIL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Lỗi: $e',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }

  } // end _updateItemQty

  Future<void> _checkout(
    double total,
    String payMethod,
    List<BanSessionItemModel> items, {
    String? customerId,
    int ptsUsed = 0,
    double discount = 0,
  }) async {
    final banRepoCached = ref.read(banRepositoryProvider);
    final khoProRepoCached = ref.read(khoProRepositoryProvider);
    final productRepoCached = ref.read(productRepositoryProvider);
    final printerSettingsCached = ref.read(printerSettingsProvider);

    try {
      final orderId = const Uuid().v4();
      final now     = DateTime.now().toUtc().toIso8601String();
      final sb      = Supabase.instance.client;

      // 0. Lấy store_id
      final storeInfo = await StoreAuthService.getStoreInfo();
      final storeId = storeInfo['store_id'] as String?;
      if (storeId == null) throw Exception('Không lấy được store_id — vui lòng đăng nhập lại');

      // 0b. Tạo orderNumber sequential (giống POS screen — dùng count từ DB)
      final today = DateTime.now();
      final datePrefix = 'QN-${today.year}${today.month.toString().padLeft(2,'0')}${today.day.toString().padLeft(2,'0')}';
      final startOfDay = DateTime(today.year, today.month, today.day).toUtc().toIso8601String();
      // ‼️ FIX Bug #19: thêm upper bound lt(endOfDay) — trước đây đếm cả đơn ngày hôm qua
      final endOfDay   = DateTime(today.year, today.month, today.day + 1).toUtc().toIso8601String();
      final productIds = items.map((i) => i.productId).toSet().toList();

      // [TỐI ƯU HOÁ TỐC ĐỘ]: Gom 3 truy vấn độc lập chạy song song (Tiết kiệm ~1-2 giây)
      final fetchFutures = await Future.wait(<Future<dynamic>>[
        sb.from('orders').select('id')
            .eq('store_id', storeId)
            .gte('created_at', startOfDay)
            .lt('created_at', endOfDay)
            .count(CountOption.exact),
        if (customerId != null)
          sb.from('app_settings').select('value').eq('store_id', storeId).eq('key', 'loyalty_rate').maybeSingle()
        else
          Future.value(null),
        sb.from('products').select('id, cost_price_latest').inFilter('id', productIds),
      ]);

      final countRes = fetchFutures[0] as PostgrestResponse;
      final rateRes  = fetchFutures[1] as Map<String, dynamic>?;
      final prodRows = fetchFutures[2] as List<dynamic>;

      final orderNumber = '$datePrefix-${((countRes.count) + 1).toString().padLeft(3, '0')}';

      // 1. Core: Tạo order
      // Lấy loyalty_rate trước để tính ptsEarned
      double ptsEarned = 0;
      if (customerId != null) {
        try {
          final rate = double.tryParse((rateRes?['value'] as String?) ?? '10000') ?? 10000;
          ptsEarned = (total / rate).floorToDouble();
        } catch (_) {}
      }
      String? cashierRecordId;
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentUserId = prefs.getString('auth_user_id');
        if (currentUserId != null) {
          final memberRow = await sb
              .from('store_members')
              .select('id, role, user_accounts(display_name, phone)')
              .eq('store_id', storeId)
              .eq('user_id', currentUserId)
              .maybeSingle();
          if (memberRow != null) {
            cashierRecordId = memberRow['id'] as String?;
            final userAcc = memberRow['user_accounts'] as Map<String, dynamic>?;
            final displayName = userAcc?['display_name'] as String? ?? 'Cashier';
            final phone = userAcc?['phone'] as String?;
            final role = memberRow['role'] as String? ?? 'cashier';
            
            if (cashierRecordId != null) {
              await sb.from('staff_members').upsert({
                'id': cashierRecordId,
                'store_id': storeId,
                'name': displayName,
                'role': role,
                'phone': phone,
                'is_active': true,
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              });
            }
          }
        }
      } catch (e) {
        debugPrint('[Checkout] Sync cashier failed: $e');
      }

      await sb.from('orders').insert({
        'id': orderId,
        'store_id': storeId,
        'order_number': orderNumber,
        'customer_id': customerId,
        'subtotal': total + discount,  // subtotal trước giảm
        'discount': discount,
        'tax': 0,
        'total': total,                // total sau giảm
        'total_amount': total,
        'payment_method': payMethod,
        'status': 'completed',
        'source_type': 'ban',
        'source_id': widget.session.id,
        'loyalty_pts_earned': ptsEarned,
        'loyalty_pts_used':   ptsUsed.toDouble(),
        'created_at': now,
        if (cashierRecordId != null) 'staff_id': cashierRecordId,
        if (widget.session.waiterId != null) 'waiter_id': widget.session.waiterId,
      });

      // 2. Core: Tạo order_items
      // ‼️ FIX Bug #18: fetch cost_price thực từ products — trước đây hardcode 0
      Map<String, double> costPriceMap = {};
      try {
        for (final p in prodRows) {
          costPriceMap[p['id'] as String] =
              (p['cost_price_latest'] as num?)?.toDouble() ?? 0;
        }
      } catch (e) { debugPrint('[Checkout] cost_price fetch err: $e'); }

      final List<Map<String, dynamic>> orderItemRows = [];
      final Map<String, BanSessionItemModel> groupedItems = {};
      for (final item in items) {
        final cleanNote = item.note?.trim() ?? '';
        final cleanMods = item.modifiersJson?.trim() ?? '';
        final key = '${item.productId}_${item.price.toStringAsFixed(2)}_${cleanNote}_$cleanMods';
        if (groupedItems.containsKey(key)) {
          final prev = groupedItems[key]!;
          groupedItems[key] = BanSessionItemModel(
            id: prev.id,
            sessionId: prev.sessionId,
            productId: prev.productId,
            productName: prev.productName,
            price: prev.price,
            quantity: prev.quantity + item.quantity,
            note: prev.note,
            modifiersJson: prev.modifiersJson,
            addedAt: prev.addedAt,
            kitchenStatus: prev.kitchenStatus,
          );
        } else {
          groupedItems[key] = item;
        }
      }

      for (final item in groupedItems.values) {
        orderItemRows.add({
          'id': const Uuid().v4(),
          'order_id': orderId,
          'product_id': item.productId,
          'store_id':    storeId,
          'name':        item.productName,
          'product_name': item.productName,
          'qty':         item.quantity.toInt(),
          'unit_price':  item.price,
          'cost_price':  costPriceMap[item.productId] ?? 0, // ✅ FIX: lấy cost thực
          'modifiers_json': item.modifiersJson,             // ✅ R3-02: lưu topping vào order history
          'quantity':    item.quantity,
          'subtotal':    item.subtotal,
        });
      }
      if (orderItemRows.isNotEmpty) {
        await sb.from('order_items').insert(orderItemRows);
      }

      // 3 + 3b + 4 + 5. Cross-module (Trừ kho, Tài chính, Tích điểm) chạy chế độ nền không block UI
      Future<void> runBackgroundSideEffects() async {
        // 3 + 3b. Cross-module: Trừ kho — phân biệt sản phẩm CÓ/KHÔNG có công thức
        final khoProRepo  = khoProRepoCached;
        final productRepo = productRepoCached;
        Map<String, RecipeModel> recipeByPosId = {};
        try {
          final allRecipes = await khoProRepo.fetchRecipes();
          recipeByPosId = {
            for (final r in allRecipes)
              if (r.posProductId != null) r.posProductId!: r,
          };
        } catch (e) { debugPrint('[Checkout] fetchRecipes err: $e'); }

        for (final item in items) {
          final recipe = recipeByPosId[item.productId];
          if (recipe != null && recipe.ingredients.isNotEmpty) {
            // Sản phẩm CÓ công thức → deductIngredients trừ NL + ghi COGS
            try {
              await khoProRepo.deductIngredients(
                recipe:      recipe,
                quantity:    item.quantity,
                reason:      'sale',
                note:        'Bàn "${widget.table.label}" bán "${item.productName}" × ${item.quantity.toStringAsFixed(0)} (Đơn $orderNumber)',
                referenceId: orderId,
              );
            } catch (e) { debugPrint('[Checkout] ❌ deductIngredients err: $e'); }
          } else {
            // Sản phẩm KHÔNG có công thức → trừ stock thô
            try {
              await productRepo.updateStockQty(item.productId, -item.quantity);
              await sb.from('stock_movements').insert({
                'id':         const Uuid().v4(),
                'store_id':   storeId,
                'product_id': item.productId,
                'delta':      double.parse((-item.quantity).toStringAsFixed(3)),
                'reason':     'sale',
                'note':       'Bán bàn $orderNumber',
                'created_at': now,
              });
            } catch (e) { debugPrint('[Checkout] ❌ stock err: $e'); }
          }

          // ── Topping deduction (Option A: qua Kho CN recipe) ──────────────
          if (item.modifiersJson != null) {
            try {
              final extras = jsonDecode(item.modifiersJson!) as List<dynamic>;
              for (final extra in extras) {
                final m = extra as Map<String, dynamic>;
                if (m['type'] != 'topping') continue;
                final toppingId  = m['id'] as String?;
                final toppingQty = ((m['qty'] as num?) ?? 1).toDouble() * item.quantity;
                final toppingName = m['name'] as String? ?? 'Topping';
                if (toppingId == null || toppingQty <= 0) continue;

                final toppingRecipe = recipeByPosId[toppingId];
                if (toppingRecipe != null && toppingRecipe.ingredients.isNotEmpty) {
                  debugPrint('[Checkout] 🧋 Topping "$toppingName" × ${toppingQty.toStringAsFixed(1)} → deduct recipe');
                  try {
                    await khoProRepo.deductIngredients(
                      recipe:      toppingRecipe,
                      quantity:    toppingQty,
                      reason:      'sale',
                      note:        'Topping "$toppingName" × ${toppingQty.toStringAsFixed(1)} (Đơn $orderNumber)',
                      referenceId: orderId,
                    );
                  } catch (e) { debugPrint('[Checkout] ❌ topping recipe deduct err: $e'); }
                } else {
                  debugPrint('[Checkout] 🧋 Topping "$toppingName" × ${toppingQty.toStringAsFixed(1)} → deduct stock thô');
                  try {
                    await productRepo.updateStockQty(toppingId, -toppingQty);
                    await sb.from('stock_movements').insert({
                      'id':         const Uuid().v4(),
                      'store_id':   storeId,
                      'product_id': toppingId,
                      'delta':      double.parse((-toppingQty).toStringAsFixed(3)),
                      'reason':     'sale',
                      'note':       'Topping "$toppingName" (Đơn $orderNumber)',
                      'created_at': now,
                    });
                  } catch (e) { debugPrint('[Checkout] ❌ topping stock err: $e'); }
                }
              }
            } catch (e) { debugPrint('[Checkout] ❌ parse modifiers_json err: $e'); }
          }
        }

        // 4. Cross-module: Finance
        if (storeId != null) {
          try {
            final existIncome = await sb.from('finance_records')
                .select('id')
                .eq('store_id', storeId)
                .eq('reference_id', orderId)
                .eq('type', 'income')
                .eq('is_auto', true)
                .maybeSingle();
            if (existIncome == null) {
              final fundType = (payMethod == 'transfer' || payMethod == 'card') ? 'bank' : 'cash';
              await sb.from('finance_records').insert({
                'id':           const Uuid().v4(),
                'store_id':     storeId,
                'type':         'income',
                'amount':       total,
                'description':  'Doanh thu bàn $orderNumber',
                'reference_id': orderId,
                'is_auto':      true,
                'recorded_at':  now,
                'fund_type':    fundType,
              });
            }
          } catch (e) { debugPrint('[Checkout] finance silent err: $e'); }
        }

        // 5. Cross-module: Loyalty
        if (storeId != null && customerId != null) {
          try {
            final customer = await sb.from('customers')
                .select('loyalty_pts, total_spent, visit_count, stamp_count')
                .eq('id', customerId)
                .maybeSingle();
            if (customer != null) {
              final currentPts    = (customer['loyalty_pts'] as num?)?.toDouble() ?? 0;
              final currentSpent  = (customer['total_spent'] as num?)?.toDouble() ?? 0;
              final currentVisit  = (customer['visit_count'] as num?)?.toInt()    ?? 0;
              final currentStamps = (customer['stamp_count'] as num?)?.toInt()    ?? 0;

              final newPts = (currentPts + ptsEarned - ptsUsed).clamp(0, double.infinity);

              int threshold = 10;
              try {
                final tRes = await sb.from('app_settings')
                    .select('value')
                    .eq('store_id', storeId)
                    .eq('key', 'stamp_threshold')
                    .maybeSingle();
                threshold = int.tryParse(tRes?['value'] as String? ?? '10') ?? 10;
              } catch (_) {}

              final nextStamps = currentStamps + 1;
              final rewardTriggered = nextStamps >= threshold;
              final newStampCount = rewardTriggered ? 0 : nextStamps;
              final newStampTotal  = (customer['stamp_total'] as num?)?.toInt() ?? 0;

              await sb.from('customers').update({
                'loyalty_pts':  newPts,
                'total_spent':  currentSpent + (total + discount),
                'visit_count':  currentVisit + 1,
                'stamp_count':  newStampCount,
                'stamp_total':  newStampTotal + 1,
                'updated_at':   now,
              }).eq('id', customerId);

              if (ptsEarned > 0 || ptsUsed > 0) {
                await sb.from('loyalty_transactions').insert({
                  'id':          const Uuid().v4(),
                  'store_id':    storeId,
                  'customer_id': customerId,
                  'order_id':    orderId,
                  'pts_earned':  ptsEarned,
                  'pts_used':    ptsUsed.toDouble(),
                  'note':        ptsUsed > 0
                      ? 'Ban $orderNumber (dùng $ptsUsed điểm giảm giá)'
                      : 'Ban $orderNumber',
                  'created_at':  now,
                });
              }
            }
          } catch (e) { debugPrint('[Checkout] loyalty silent err: $e'); }
        }
      }

      // Kích hoạt tác vụ nền không đợi
      runBackgroundSideEffects().catchError((e) {
        debugPrint('[Checkout] ❌ Lỗi nền: $e');
      });

      // 6. Đóng session
      await banRepoCached.closeSession(widget.session.id, total);
      
      // Tự động in hóa đơn thu ngân khi thanh toán tại bàn (nếu bật cấu hình)
      try {
        if (printerSettingsCached.autoPrintCheckout && !printerSettingsCached.autoPrintServer) {
          final List<BillItem> billItems = [];
          for (final item in items) {
            billItems.add(BillItem(
              name: item.productName,
              qty: item.quantity.toInt(),
              price: item.price,
              note: item.note,
            ));
          }

          final billData = BillData(
            shopName: storeInfo['name'] ?? 'QUÁN NHỎ POS',
            shopAddress: storeInfo['address'] ?? '',
            shopPhone: storeInfo['phone'] ?? '',
            orderNumber: orderNumber,
            createdAt: DateTime.now(),
            tableName: widget.table.label,
            items: billItems,
            subtotal: total + discount,
            total: total,
            type: BillType.receipt,
            note: '',
          );

          await StationPrinterDispatcher.printBill(billData, printerSettingsCached, onlyReceipt: true);
        }
      } catch (e) {
        debugPrint('[Checkout Print] ❌ Lỗi in hóa đơn thanh toán bàn: $e');
      }

      // Option C: KHÔNG tự đóng kitchen_tickets → bếp tự bấm Xong khi hoàn tất
      // (Trước đây set status='xong' ngay khi thanh toán → bếp mất phiếu đột ngột)

      if (mounted) {
        ref.invalidate(activeSessionsProvider);
        ref.invalidate(todayStatsProvider);
        // Invalidate finance — StreamProvider + FutureProviders cùng refresh
        ref.invalidate(financeRecordsProvider);      // list giao dịch
        ref.invalidate(financeStatsProvider);        // stats header kỳ đang chọn
        ref.invalidate(todayFinanceStatsProvider);
      }

      if (mounted) {
        // Phát âm thanh tiền
        try {
          final player = AudioPlayer();
          player.play(AssetSource('sounds/payment_success.mp3')); // KHÔNG await để UI phản hồi ngay lập tức
        } catch (_) {}
        if (!mounted) return;
        // Hiện dialog thành công trước khi đóng tab
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_rounded,
                        color: _kGreen, size: 44),
                  ),
                  const SizedBox(height: 16),
                  Text('Thanh toán thành công!',
                    style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy)),
                  const SizedBox(height: 8),
                  Text(fmtVnd(total),
                    style: GoogleFonts.outfit(
                      fontSize: 26, fontWeight: FontWeight.w900,
                      color: _kGreen)),
                ],
              ),
            ),
          ),
        );
        // Tự đóng sau 1.5s
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.of(context)
            ..pop() // đóng dialog
            ..pop(); // đóng ban screen
        }
      }
    } catch (e, st) {
      debugPrint('[Checkout] ❌ LỖI: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lỗi thanh toán: $e',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  // A2: Mở checkout sheet — 2-step confirm
  // ‼️ FIX Bug #38: _isCheckingOut guard — ngăn double-tap tạo 2 order, 2 finance record
  bool _isCheckingOut = false;

  Future<void> _openCheckout(double total, List<BanSessionItemModel> items) async {
    if (_isCheckingOut) return; // guard double-tap
    final result = await showModalBottomSheet<Map<String, dynamic?>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CheckoutSheet(
        total: total,
        items: items,
        tableName: widget.table.label,
        zone: widget.zone,
      ),
    );
    if (result == null) return; // user cancel
    if (_isCheckingOut) return; // second guard sau khi sheet đóng
    _isCheckingOut = true;
    try {
      final payMethod  = result['pay']        as String? ?? 'cash';
      final customerId = result['customerId'] as String?;
      final ptsUsed    = (result['ptsUsed']   as int?)   ?? 0;
      final discount   = ((result['discount'] as num?)   ?? 0).toDouble();
      final finalTotal = (total - discount).clamp(0.0, double.infinity) as double;
      await _checkout(
        finalTotal,
        payMethod,
        items,
        customerId: customerId,
        ptsUsed: ptsUsed,
        discount: discount,
      );
    } finally {
      _isCheckingOut = false;
    }
  }

  Future<void> _updateItemNote(
      BanSessionItemModel item, String newNote) async {
    await Supabase.instance.client
        .from('ban_session_items')
        .update({'note': newNote.trim().isEmpty ? null : newNote.trim()})
        .eq('id', item.id);
    ref.invalidate(sessionItemsProvider(widget.session.id));
  }

  // ── Gửi bếp ──────────────────────────────────────────────────────────────
  Future<void> _sendToKitchen(List<BanSessionItemModel> items) async {
    try {
      await _sendToKitchenImpl(items);
    } catch (e, st) {
      debugPrint('[Kitchen] ❌ _sendToKitchen crash: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠️ Gửi bếp thất bại: $e',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _sendToKitchenImpl(List<BanSessionItemModel> items) async {
    final unsent = items.where((i) => i.kitchenStatus == 'chua_gui').toList();
    if (unsent.isEmpty) return;

    final ticketId = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();

    // Đếm đợt hiện tại
    final ticketsResp = await Supabase.instance.client
        .from('kitchen_tickets')
        .select('id')
        .eq('session_id', widget.session.id);
    final round = (ticketsResp as List).length + 1;

    // Lấy store_id — cần cho NOT NULL constraint
    final storeInfo = await StoreAuthService.getStoreInfo();
    final storeId   = storeInfo['store_id'];
    if (storeId == null) throw Exception('storeId null — chưa đăng nhập ?');

    // 1. Tạo KitchenTicket
    await Supabase.instance.client.from('kitchen_tickets').insert({
      'id':          ticketId,
      'store_id':    storeId,
      'session_id':  widget.session.id,
      'table_label': widget.table.label,
      'zone_label':  widget.zone.name,
      'round':       round,
      'status':      'cho',
      'sent_at':     now,
    });

    // ‼️ FIX #2: Batch lookup station code — 1 query thay vì N queries
    final productIds = unsent.map((i) => i.productId).toList();
    final productRows = await Supabase.instance.client
        .from('products').select('id, category, station_code').inFilter('id', productIds);
    final productInfoMap = <String, Map<String, dynamic>>{
      for (final r in productRows) r['id'] as String: r,
    };

    // 2. Tạo KitchenTicketItems + cập nhật kitchenStatus (BATCHED)
    try {
      final List<Map<String, dynamic>> itemRows = [];
      for (final item in unsent) {
        final pInfo = productInfoMap[item.productId];
        final stationCode = pInfo?['station_code'] as String? ?? 'bep_nong';
        itemRows.add({
          'id':              const Uuid().v4(),
          'store_id':        storeId,
          'ticket_id':       ticketId,
          'session_item_id': item.id,
          'product_id':      item.productId,
          'name':            item.productName,            // Hỗ trợ cột 'name' của schema cũ (NOT NULL)
          'product_name':    item.productName,            // Hỗ trợ cột 'product_name' của schema mới
          'qty':             item.quantity.toInt(),       // Hỗ trợ cột 'qty' của schema cũ
          'quantity':        item.quantity,               // Hỗ trợ cột 'quantity' của schema mới
          'free_note':       item.note,
          'kitchen_note':    item.modifiersJson,          // Hỗ trợ cột 'kitchen_note'
          'modifiers_json':  item.modifiersJson,          // Hỗ trợ cột 'modifiers_json'
          'station_code':    stationCode,
          'done':            false,
        });
      }

      if (itemRows.isNotEmpty) {
        await Supabase.instance.client.from('kitchen_ticket_items').insert(itemRows);
      }

      final unsentIds = unsent.map((i) => i.id).toList();
      await Supabase.instance.client
          .from('ban_session_items')
          .update({'kitchen_status': 'da_gui'})
          .inFilter('id', unsentIds);

      // Invalidate stream provider immediately so UI updates to 'da_gui' without waiting for realtime/poll
      ref.invalidate(sessionItemsProvider(widget.session.id));
    } catch (e) {
      debugPrint('[Kitchen] ❌ Lỗi insert items: $e');
      // Rollback: xóa ticket để tránh phiếu rỗng
      await Supabase.instance.client
          .from('kitchen_tickets').delete().eq('id', ticketId);
      final unsentIds = unsent.map((i) => i.id).toList();
      await Supabase.instance.client.from('ban_session_items')
          .update({'kitchen_status': 'chua_gui'}).inFilter('id', unsentIds);
      rethrow; // đẩy lỗi lên wrapper để hiện SnackBar
    }

    // Tự động in bếp bằng StationPrinterDispatcher (hỗ trợ phân chia 4 trạm in mới)
    try {
      final settings = ref.read(printerSettingsProvider);
      if (settings.autoPrintKitchen && !settings.autoPrintServer) {
        final List<BillItem> billItems = [];
        for (final item in unsent) {
          final pInfo = productInfoMap[item.productId];
          final stationCode = pInfo?['station_code'] as String? ?? 'bep_nong';
          billItems.add(BillItem(
            name: item.productName,
            qty: item.quantity.toInt(),
            price: 0, // In bếp không hiển thị giá
            note: item.note,
            stationCode: stationCode,
          ));
        }

        final billData = BillData(
          shopName: storeInfo['name'] ?? 'QUÁN NHỎ POS',
          shopAddress: storeInfo['address'] ?? '',
          shopPhone: storeInfo['phone'] ?? '',
          orderNumber: 'Bep-$round',
          createdAt: DateTime.now(),
          tableName: widget.table.label,
          items: billItems,
          subtotal: 0,
          total: 0,
          type: BillType.kitchen,
          note: '',
        );
        
        await StationPrinterDispatcher.printBill(billData, settings);
      }
    } catch (e) {
      debugPrint('[Kitchen] ❌ Lỗi in bếp qua StationPrinterDispatcher: $e');
    }

    HapticFeedback.heavyImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Đã gửi bếp Đợt $round — ${unsent.length} món',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          backgroundColor: _kOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Auto-print phiếu bếp qua máy in nhiệt Wi-Fi (nếu enabled)
  Future<void> _autoPrintTicket({
    required String tableLabel,
    required String zoneLabel,
    required int round,
    required List<BanSessionItemModel> items,
    required int sentAt,
  }) async {
    try {
      final config = await PrinterSettingsService.load();
      if (!config.enabled || !config.isConfigured) return;

      final ticketItems = items.map((i) {
        // ✅ R3-01: Parse modifiersJson → modifiers list cho máy in nhiệt
        final List<String> modifierLines = [];
        if (i.modifiersJson != null) {
          try {
            final extras = jsonDecode(i.modifiersJson!) as List<dynamic>;
            for (final e in extras) {
              if (e is Map) {
                final name = e['name'] as String? ?? '';
                final qty  = e['qty'];
                final type = e['type'] as String? ?? '';
                if (name.isEmpty) continue;
                modifierLines.add(
                  (type == 'topping' && qty != null && qty != 1) ? '$name x$qty' : name,
                );
              }
            }
          } catch (_) {}
        }
        return TicketItemData(
          name: i.productName, quantity: i.quantity,
          modifiers: modifierLines, note: i.note,
        );
      }).toList();

      final result = await ThermalPrinterService.printKitchenTicket(
        printerIp: config.ip,
        port: config.port,
        tableLabel: tableLabel,
        zoneLabel: zoneLabel,
        round: round,
        items: ticketItems,
        sentAt: sentAt,
      );

      if (!result.ok && mounted) {
        // Hiển thị lỗi nhẹ nhàng — không block workflow
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🖨️ Không in được phiếu bếp: ${result.error}',
              style: GoogleFonts.outfit(fontSize: 12),
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      // Lỗi in không được block workflow gửi bếp
    }
  }

  Future<Map<String, String>?> _verifyManagerApproval() async {
    final session = ref.read(sessionProvider);
    final isManager = session?.isOwner == true ||
        session?.role == 'owner' || session?.role == 'manager';

    if (isManager) {
      return {
        'id': session!.userId,
        'name': session.displayName,
      };
    }

    final storeId = session?.storeId;
    if (storeId == null) return null;

    return showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ManagerPinInputDialog(storeId: storeId),
    );
  }

  Future<String?> _askCancelTableReason() async {
    String? selectedReason;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Lý do huỷ bàn *', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in ['Khách đổi ý', 'Mở nhầm bàn', 'Gộp/Chuyển bàn', 'Khác'])
                RadioListTile<String>(
                  dense: true, contentPadding: EdgeInsets.zero,
                  title: Text(r, style: GoogleFonts.outfit(fontSize: 13)),
                  value: r, groupValue: selectedReason,
                  onChanged: (v) => setS(() => selectedReason = v),
                  activeColor: _kOrange,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: selectedReason == null ? null : () => Navigator.pop(ctx, selectedReason),
              child: Text('Đồng ý', style: GoogleFonts.outfit(
                color: selectedReason == null ? Colors.grey : _kRed, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askWastageReasonAndResponsibilityCommitment(String managerName) async {
    String? selectedReason;
    bool committed = false;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.gavel_rounded, color: _kRed, size: 22),
              const SizedBox(width: 8),
              Text('Cam kết trách nhiệm', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: _kRed)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quản lý: $managerName',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13, color: _kNavy),
              ),
              const SizedBox(height: 8),
              Text(
                'Bàn đã có món đang làm hoặc đã làm xong. Vui lòng chọn lý do hao phí và tích xác nhận chịu trách nhiệm:',
                style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              for (final r in [
                'Khách bỏ trốn / bùng bill',
                'Bếp làm sai món / hỏng đồ',
                'Nhân viên order nhầm đã nấu',
                'Khách đổi ý khi đang nấu',
                'Lý do hao phí khác'
              ])
                RadioListTile<String>(
                  dense: true, contentPadding: EdgeInsets.zero,
                  title: Text(r, style: GoogleFonts.outfit(fontSize: 13)),
                  value: r, groupValue: selectedReason,
                  onChanged: (v) => setS(() => selectedReason = v),
                  activeColor: _kRed,
                ),
              const Divider(height: 24),
              CheckboxListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Tôi xác nhận chịu trách nhiệm cho các món đã chế biến bị huỷ bỏ.',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: _kRed),
                ),
                value: committed,
                onChanged: (v) => setS(() => committed = v ?? false),
                activeColor: _kRed,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('Hủy', style: GoogleFonts.outfit(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: (selectedReason == null || !committed)
                  ? null
                  : () => Navigator.pop(ctx, '[HAO PHÍ - $selectedReason] Đã ký cam kết chịu trách nhiệm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Đồng ý huỷ bàn', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelSession() async {
    final items = ref.read(sessionItemsProvider(widget.session.id)).value ?? [];
    final activeItems = items.where((i) => i.kitchenStatus != 'huy').toList();
    final hasCookingOrDone = activeItems.any((i) => i.kitchenStatus == 'dang_lam' || i.kitchenStatus == 'xong');

    String? reason;
    Map<String, String>? approval;

    if (hasCookingOrDone) {
      // ── CHẾ ĐỘ 2 LỚP BẢO MẬT (Đã nấu hoặc đang nấu) ──────────────────────────
      // Lớp 1: Cảnh báo đỏ nổi bật & Yêu cầu PIN Quản lý khẩn cấp
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _kRed, size: 22),
              const SizedBox(width: 8),
              Text('Huỷ bàn khẩn cấp?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: _kRed)),
            ],
          ),
          content: Text(
            'Cảnh báo cực kỳ quan trọng:\nBàn này đã có món đang chế biến hoặc đã nấu xong! Việc huỷ bàn sẽ gây thất thoát chi phí & hao phí nguyên liệu chế biến.\n\nBạn có thực sự muốn tiếp tục?',
            style: GoogleFonts.outfit(height: 1.4, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Không', style: GoogleFonts.outfit(color: _kNavy)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Tiếp tục', style: GoogleFonts.outfit(color: _kRed, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      // Xác minh mã PIN Quản lý
      approval = await _verifyManagerApproval();
      if (approval == null) return;

      // Lớp 2: Cam kết trách nhiệm & Lý do hao phí bắt buộc
      reason = await _askWastageReasonAndResponsibilityCommitment(approval['name'] ?? 'Quản lý');
      if (reason == null) return;
    } else {
      // ── CHẾ ĐỘ THÔNG THƯỜNG (Chưa nấu) ────────────────────────────────────
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Huỷ bàn?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          content: Text('Tất cả món đã gọi sẽ bị xoá.',
              style: GoogleFonts.outfit()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Không', style: GoogleFonts.outfit(color: _kNavy)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Huỷ bàn',
                  style: GoogleFonts.outfit(
                      color: _kRed, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      // 1. Phê duyệt Quản lý
      approval = await _verifyManagerApproval();
      if (approval == null) return;

      // 2. Hỏi lý do huỷ bàn
      reason = await _askCancelTableReason();
      if (reason == null) return;
    }

    setState(() => _isCancelling = true);
    try {
      final session = ref.read(sessionProvider);
      final activeItemsForLog = items.where((i) => i.kitchenStatus != 'huy').toList();
      final total = activeItemsForLog.fold<double>(0, (s, i) => s + i.subtotal);
      final details = activeItemsForLog.map((i) => {
        'product_name': i.productName,
        'quantity': i.quantity,
        'subtotal': i.subtotal,
      }).toList();

      // Đóng session
      await Supabase.instance.client
          .from('ban_sessions')
          .update({'status': 'cancelled', 'closed_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', widget.session.id);

      // Cập nhật trạng thái tất cả các món ăn của bàn thành 'huy'
      await Supabase.instance.client
          .from('ban_session_items')
          .update({'kitchen_status': 'huy'})
          .eq('session_id', widget.session.id)
          .neq('kitchen_status', 'huy');

      ref.invalidate(activeSessionsProvider);

      // Huỷ tất cả kitchen_tickets của session này
      await Supabase.instance.client
          .from('kitchen_tickets')
          .update({'status': 'huy'})
          .eq('session_id', widget.session.id)
          .inFilter('status', ['cho', 'dang_lam']);

      // Ghi void log từng món đang nấu/gửi bếp để bếp thấy banner thông báo huỷ bàn đỏ nổi bật
      try {
        final storeInfo = await StoreAuthService.getStoreInfo();
        final storeId   = storeInfo['store_id'] as String?;
        if (storeId != null) {
          final List<Map<String, dynamic>> voidLogs = [];
          for (final item in activeItemsForLog) {
            final sentStatuses = ['da_gui', 'dang_lam', 'xong'];
            if (sentStatuses.contains(item.kitchenStatus)) {
              voidLogs.add({
                'store_id':     storeId,
                'session_id':   widget.session.id,
                'table_label':  widget.table.label,
                'product_name': item.productName,
                'action':       'cancel',
                'old_qty':      item.quantity,
                'new_qty':      0,
                'reason':       'Huỷ bàn: $reason',
                'staff_name':   approval['name'] ?? 'Quản lý',
              });
            }
          }
          if (voidLogs.isNotEmpty) {
            await Supabase.instance.client.from('ban_session_void_logs').insert(voidLogs);
            debugPrint('[Ban] ✅ ban_session_void_logs for cancelled table items inserted');
          }
        }
      } catch (e) {
        debugPrint('[Ban] void logs for table cancellation err: $e');
      }

      // Ghi nhận lịch sử kiểm toán huỷ bàn vào void_audit_logs
      await _banRepo.logVoidEvent(
        voidType: 'cancel_table',
        referenceId: widget.session.id,
        label: widget.table.label,
        requestedByUserId: session?.userId ?? '',
        requestedByName: session?.displayName ?? 'Nhân viên',
        approvedByUserId: approval['id'] ?? '',
        approvedByName: approval['name'] ?? 'Quản lý',
        reason: reason,
        amount: total,
        details: details,
      );

      debugPrint('[Ban] ✅ void audit log CANCEL_TABLE inserted with 2-step verification if cooking/done');

    } catch (e) {
      debugPrint('[Ban] cancel kitchen tickets err: $e');
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
        Navigator.pop(context);
      }
    }
  }

  Future<void> _transferTable() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransferTableSheet(
        currentTableId: widget.table.id,
        currentTableLabel: widget.table.label,
        activeSessions: ref.read(activeSessionsProvider).value ?? {},
        onConfirm: (newTableId) async {
          await _banRepo.transferSession(widget.session.id, newTableId);
          ref.invalidate(activeSessionsProvider);
          if (mounted) {
            Navigator.pop(context); // đóng session sheet
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Chuyển bàn thành công!',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              ]),
              backgroundColor: _kGreen,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(sessionItemsProvider(widget.session.id));
    final zoneColor = Color(widget.zone.colorValue);

    return PopScope(
      canPop: !_isCancelling,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: _kCream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _kNavy.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: zoneColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.table.label,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.session.guestCount} khách',
                          style: GoogleFonts.outfit(
                            color: _kNavy.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        // Nút Chuyển bàn
                        GestureDetector(
                          onTap: _transferTable,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _kAmber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _kAmber.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.swap_horiz_rounded, size: 14, color: _kAmber),
                                const SizedBox(width: 4),
                                Text(
                                  'Chuyển',
                                  style: GoogleFonts.outfit(
                                    color: _kAmber,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _cancelSession,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _kRed.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _kRed.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cancel_rounded, size: 14, color: _kRed),
                                const SizedBox(width: 4),
                                Text(
                                  'Huỷ bàn',
                                  style: GoogleFonts.outfit(
                                    color: _kRed,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: _kNavy.withValues(alpha: 0.08)),
                  Expanded(
                    child: itemsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('$e')),
                      data: (items) {
                        if (items.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _kNavy.withValues(alpha: 0.03),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                  border: Border.all(color: _kNavy.withValues(alpha: 0.06)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🍽️', style: TextStyle(fontSize: 54)),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Chưa có món nào được chọn',
                                      style: GoogleFonts.outfit(
                                        color: _kNavy,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Bấm Gọi món bên dưới để thêm món ăn và thức uống thơm ngon cho khách nhé!',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        color: _kNavy.withValues(alpha: 0.45),
                                        fontSize: 12.5,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    ElevatedButton.icon(
                                      onPressed: _addItems,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _kNavy,
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        shadowColor: _kNavy.withValues(alpha: 0.25),
                                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16)),
                                      ),
                                      icon: const Icon(Icons.add_rounded, size: 20),
                                      label: Text('Gọi món ngay',
                                          style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w800, fontSize: 14)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        print('[UI DEBUG] TableSessionSheet received items length: ${items.length}');
                        // ‼️ FIX #R3: Exclude món đã hủy khỏi tổng — tránh tính tiền món đã cancel
                        final rawActiveItems = items.where((i) => i.kitchenStatus != 'huy').toList();
                        final Map<String, BanSessionItemModel> groupedActiveMap = {};
                        for (final item in rawActiveItems) {
                          final cleanNote = item.note?.trim() ?? '';
                          final cleanMods = item.modifiersJson?.trim() ?? '';
                          // Gộp theo key = product_id + price + note + modifiers + kitchenStatus
                          final key = '${item.productId}_${item.price.toStringAsFixed(2)}_${cleanNote}_${cleanMods}_${item.kitchenStatus}';
                          if (groupedActiveMap.containsKey(key)) {
                            final prev = groupedActiveMap[key]!;
                            groupedActiveMap[key] = BanSessionItemModel(
                              id: prev.id,
                              sessionId: prev.sessionId,
                              productId: prev.productId,
                              productName: prev.productName,
                              price: prev.price,
                              quantity: prev.quantity + item.quantity,
                              note: prev.note,
                              modifiersJson: prev.modifiersJson,
                              addedAt: prev.addedAt,
                              kitchenStatus: prev.kitchenStatus,
                            );
                          } else {
                            groupedActiveMap[key] = item;
                          }
                        }
                        final activeItems = groupedActiveMap.values.toList()
                          ..sort((a, b) => a.addedAt.compareTo(b.addedAt));
                        print('[UI DEBUG] TableSessionSheet activeItems length: ${activeItems.length}');
                        final total = activeItems.fold<double>(0, (s, i) => s + i.subtotal);

                        return CustomScrollView(
                          slivers: [
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                                  final item = activeItems[i];
                                  
                                  // Sent items → không Dismissible (tránh gesture conflict với nút bên trong)
                                  // Unsent items → Dismissible swipe-to-delete bình thường
                                  // NUCLEAR FIX: Bỏ Dismissible hoàn toàn, dùng GestureDetector
                                  final _sentSts = ['da_gui', 'dang_lam', 'xong'];
                                  final _isItemSent = _sentSts.contains(item.kitchenStatus);
                                  return Container(
                                    key: ValueKey(item.id),
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _kNavy.withValues(alpha: 0.03),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: _isItemSent
                                            ? _kNavy.withValues(alpha: 0.04)
                                            : _kNavy.withValues(alpha: 0.12),
                                        width: _isItemSent ? 1.0 : 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _KitchenStatusDot(status: item.kitchenStatus),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(item.productName,
                                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: _kNavy, fontSize: 14.5)),
                                                  const SizedBox(height: 2),
                                                  Text(fmtVnd(item.price),
                                                    style: GoogleFonts.outfit(fontSize: 12, color: _kNavy.withValues(alpha: 0.45), fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                            // Vùng hiển thị số lượng và nút chỉnh cho món CHƯA GỬI BẾP
                                            if (!_isItemSent) ...[
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: _kNavy.withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                child: Row(
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () async {
                                                        HapticFeedback.selectionClick();
                                                        if (item.quantity > 1) {
                                                          await _updateItemQty(item, item.quantity.toInt() - 1);
                                                        } else {
                                                          await _removeItem(item);
                                                        }
                                                      },
                                                      child: Container(
                                                        width: 28,
                                                        height: 28,
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Icon(Icons.remove_rounded, size: 14, color: _kNavy),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 30,
                                                      child: Text(
                                                        item.quantity.toStringAsFixed(0),
                                                        textAlign: TextAlign.center,
                                                        style: GoogleFonts.outfit(
                                                          fontWeight: FontWeight.w800,
                                                          color: _kNavy,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () async {
                                                        HapticFeedback.selectionClick();
                                                        await _updateItemQty(item, item.quantity.toInt() + 1);
                                                      },
                                                      child: Container(
                                                        width: 28,
                                                        height: 28,
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Icon(Icons.add_rounded, size: 14, color: _kNavy),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ] else ...[
                                              // Món đã gửi bếp → chỉ hiện Text số lượng
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: _kNavy.withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'x${item.quantity.toStringAsFixed(0)}',
                                                  style: GoogleFonts.outfit(
                                                      fontWeight: FontWeight.w800,
                                                      color: _kNavy,
                                                      fontSize: 13),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 10),
                                            Text(
                                              fmtVnd(item.subtotal),
                                              style: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.w800,
                                                  color: _kNavy,
                                                  fontSize: 14.5),
                                            ),
                                            if (!_isItemSent) ...[
                                              const SizedBox(width: 6),
                                              GestureDetector(
                                                behavior: HitTestBehavior.opaque,
                                                onTap: () => _removeItem(item),
                                                child: Container(
                                                  width: 30, height: 30,
                                                  decoration: BoxDecoration(
                                                    color: _kRed.withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(Icons.delete_outline_rounded, size: 16, color: _kRed),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        // ── Topping & modifiers chips từ modifiersJson ──────
                                        if (item.modifiersJson != null)
                                          Builder(builder: (_) {
                                            try {
                                              final extras = jsonDecode(item.modifiersJson!) as List<dynamic>;
                                              if (extras.isEmpty) return const SizedBox.shrink();
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 10),
                                                child: Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: extras.map((e) {
                                                    final name = e['name'] as String? ?? '';
                                                    final isTopping = e['type'] == 'topping';
                                                    final qty = (e['qty'] as num?)?.toInt() ?? 1;
                                                    
                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: isTopping 
                                                            ? _kOrange.withValues(alpha: 0.06) 
                                                            : _kNavy.withValues(alpha: 0.05),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: isTopping 
                                                              ? _kOrange.withValues(alpha: 0.2) 
                                                              : _kNavy.withValues(alpha: 0.1),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        isTopping
                                                            ? (qty > 1 ? '🥗 $name ×$qty' : '🥗 $name')
                                                            : '✨ $name',
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 11, 
                                                          fontWeight: FontWeight.w700, 
                                                          color: isTopping ? _kOrange : _kNavy.withValues(alpha: 0.75),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              );
                                            } catch (_) { return const SizedBox.shrink(); }
                                          }),
                                        if (item.quantity > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 12),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: _kNavy.withValues(alpha: 0.03),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: TextField(
                                                onChanged: (v) => _updateItemNote(item, v),
                                                controller: _noteControllers.putIfAbsent(
                                                  item.id, () => TextEditingController(text: item.note ?? '')),
                                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: _kNavy),
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  hintText: 'Ghi chú cho nhà bếp (vd: ít rau, không hành...)',
                                                  hintStyle: GoogleFonts.outfit(fontSize: 12, color: _kNavy.withValues(alpha: 0.35)),
                                                  prefixIcon: Icon(Icons.edit_note_rounded, size: 18, color: _kNavy.withValues(alpha: 0.4)),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                  border: InputBorder.none,
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                    borderSide: const BorderSide(color: _kNavy, width: 1.2),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                          childCount: activeItems.length, // ‼️ FIX: chỉ đếm món chưa huỷ
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Divider(color: _kNavy.withValues(alpha: 0.1)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'TỔNG CỘNG',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _kNavy.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  Text(
                                    fmtVnd(total),
                                    style: GoogleFonts.outfit(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: _kNavy,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Action buttons — Thêm món + Gửi bếp
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _addItems,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: _kNavy,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: BorderSide(color: _kNavy.withValues(alpha: 0.15), width: 1.5),
                                        ),
                                      ),
                                      icon: const Icon(Icons.add_rounded, size: 18),
                                      label: Text(
                                        'Thêm món',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                   const SizedBox(width: 10),
                                   _SendKitchenButton(
                                     unsentCount: items
                                         .where((i) =>
                                             i.kitchenStatus == 'chua_gui')
                                         .fold<int>(0, (sum, i) => sum + i.quantity.toInt()),
                                     onPressed: () async => await _sendToKitchen(items),
                                   ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Checkout button — nằm riêng, nổi bật
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: total > 0
                                      ? () => _openCheckout(total, activeItems)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: zoneColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    elevation: total > 0 ? 6 : 0,
                                    shadowColor: total > 0 ? zoneColor.withValues(alpha: 0.45) : null,
                                    disabledBackgroundColor:
                                        _kNavy.withValues(alpha: 0.2),
                                  ),
                                  icon: const Icon(Icons.receipt_long_rounded),
                                  label: Text(
                                    'Xem hoá đơn & Thanh toán',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      if (_isCancelling)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Đang huỷ bàn...',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// CHECKOUT SHEET — A2: 2-step confirm thanh toán
// ─────────────────────────────────────────────────────────────────────────────
class _CheckoutSheet extends StatefulWidget {
  final double total;
  final List<BanSessionItemModel> items;
  final String tableName;
  final BanZoneModel zone;

  const _CheckoutSheet({
    required this.total,
    required this.items,
    required this.tableName,
    required this.zone,
  });

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  String _payMethod = 'cash'; // cash | transfer | card
  // Customer loyalty
  String? _customerId;
  String? _customerName;
  int     _customerPts  = 0;
  int     _stampCount   = 0;   // tem hiện tại trong vòng này
  int     _stampThreshold = 10;// số tem cần để nhận thưởng
  int     _redeemRate   = 1000;// VNĐ mỗi điểm khi đổi (mặc định 1000đ/điểm)
  int     _usePts       = 0;   // điểm muốn dùng giảm giá
  final _phoneCtrl = TextEditingController();
  bool _searchingCustomer = false;

  @override
  void dispose() { _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _lookupCustomer() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 9) return;
    setState(() {
      _searchingCustomer = true; _customerId = null;
      _customerName = null; _usePts = 0;
    });
    try {
      final sb      = Supabase.instance.client;
      final info    = await StoreAuthService.getStoreInfo();
      final storeId = info['store_id'];
      if (storeId == null) return;

      // ── Fetch customer ───────────────────────────────────────────────
      final res = await sb.from('customers')
          .select('id, name, loyalty_pts, stamp_count')
          .eq('store_id', storeId)
          .eq('phone', phone)
          .eq('is_deleted', false)
          .maybeSingle();

      // ── Fetch settings (redeem rate + stamp threshold) ───────────────
      if (storeId != null) {
        try {
          final settings = await sb.from('app_settings')
              .select('key, value')
              .eq('store_id', storeId)
              .inFilter('key', ['loyalty_redeem_rate', 'stamp_threshold']);
          for (final s in settings) {
            if (s['key'] == 'loyalty_redeem_rate') {
              _redeemRate = int.tryParse(s['value'] as String? ?? '1000') ?? 1000;
            } else if (s['key'] == 'stamp_threshold') {
              _stampThreshold = int.tryParse(s['value'] as String? ?? '10') ?? 10;
            }
          }
        } catch (_) {}
      }

      if (res != null && mounted) {
        setState(() {
          _customerId  = res['id'] as String;
          _customerName = res['name'] as String? ?? phone;
          _customerPts  = ((res['loyalty_pts'] as num?)?.toInt()) ?? 0;
          _stampCount   = ((res['stamp_count'] as num?)?.toInt()) ?? 0;
          _usePts = 0; // reset khi tìm khách mới
        });
      } else if (mounted) {
        setState(() {
          _customerId = null; _customerName = null;
          _customerPts = 0; _stampCount = 0; _usePts = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy khách hàng'),
            behavior: SnackBarBehavior.floating));
      }
    } catch (_) {}
    if (mounted) setState(() => _searchingCustomer = false);
  }

  // Dùng fmtVnd() từ money_formatter.dart

  @override
  Widget build(BuildContext context) {
    final zoneColor = Color(widget.zone.colorValue);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kNavy.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: zoneColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Hoá đơn — ${widget.tableName}',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _kNavy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: _kNavy.withValues(alpha: 0.08)),
            // Danh sách món
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  ...(() {
                    final Map<String, BanSessionItemModel> grouped = {};
                    for (final item in widget.items) {
                      final cleanNote = item.note?.trim() ?? '';
                      final cleanMods = item.modifiersJson?.trim() ?? '';
                      // Gộp theo key = product_id + price + note + modifiers
                      final key = '${item.productId}_${item.price.toStringAsFixed(2)}_${cleanNote}_$cleanMods';
                      
                      if (grouped.containsKey(key)) {
                        final prev = grouped[key]!;
                        grouped[key] = BanSessionItemModel(
                          id: prev.id, // giữ lại id của dòng đầu
                          sessionId: prev.sessionId,
                          productId: prev.productId,
                          productName: prev.productName,
                          price: prev.price,
                          quantity: prev.quantity + item.quantity,
                          note: prev.note,
                          modifiersJson: prev.modifiersJson,
                          addedAt: prev.addedAt,
                          kitchenStatus: prev.kitchenStatus,
                        );
                      } else {
                        grouped[key] = item;
                      }
                    }
                    return grouped.values.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.productName,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w500,
                                    color: _kNavy,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.quantity.toInt()} × ${fmtVnd(item.price)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: _kNavy.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                fmtVnd(item.subtotal),
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  color: _kNavy,
                                ),
                              ),
                            ],
                          ),
                        ));
                  })(),
                  const Divider(height: 24),
                  // ── Tổng tiền + giảm giá ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TỔNG CỘNG',
                        style: GoogleFonts.outfit(fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kNavy.withValues(alpha: 0.6))),
                      Text(fmtVnd(widget.total),
                        style: GoogleFonts.outfit(fontSize: 26,
                          fontWeight: FontWeight.w900, color: _kNavy)),
                    ],
                  ),
                  if (_usePts > 0) ...[  
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Dùng $_usePts điểm',
                          style: GoogleFonts.outfit(fontSize: 13,
                            color: const Color(0xFF388E3C))),
                        Text('- ${fmtVnd((_usePts * _redeemRate).toDouble())}',
                          style: GoogleFonts.outfit(fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF388E3C))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('THANH TOÁN',
                          style: GoogleFonts.outfit(fontSize: 13,
                            fontWeight: FontWeight.w800, color: _kNavy)),
                        Text(fmtVnd((widget.total - _usePts * _redeemRate).clamp(0, double.infinity)),
                          style: GoogleFonts.outfit(fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _kOrange)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  // ── Customer loyalty search ──────────────────────────
                  Text('Khách hàng (tích điểm)',
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600,
                      color: _kNavy.withValues(alpha: 0.6))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.outfit(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Số điện thoại...',
                        hintStyle: GoogleFonts.outfit(
                            fontSize: 14, color: _kNavy.withValues(alpha: 0.4)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _kNavy.withValues(alpha: 0.15))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _kNavy.withValues(alpha: 0.15))),
                        prefixIcon: const Icon(Icons.person_search_rounded, size: 18),
                      ),
                      onSubmitted: (_) => _lookupCustomer(),
                    )),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _searchingCustomer ? null : _lookupCustomer,
                      child: Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: _kNavy, borderRadius: BorderRadius.circular(12)),
                        child: _searchingCustomer
                            ? const Padding(padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.search_rounded,
                                color: Colors.white, size: 20),
                      ),
                    ),
                  ]),

                  // ── Khách tìm được: card thông tin ───────────────────
                  if (_customerId != null) ...[  
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.35)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Header: tên + đóng
                        Row(children: [
                          const Icon(Icons.stars_rounded,
                              color: Color(0xFF2E7D32), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_customerName ?? '',
                            style: GoogleFonts.outfit(
                                fontSize: 14, fontWeight: FontWeight.w800,
                                color: const Color(0xFF1B5E20)))),
                          GestureDetector(
                            onTap: () => setState(() {
                              _customerId = null; _customerName = null;
                              _customerPts = 0; _stampCount = 0;
                              _usePts = 0; _phoneCtrl.clear();
                            }),
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: Color(0xFF2E7D32)),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        // ── Stamp Card ──────────────────────────────────
                        Text('Thẻ tích tem  ($_stampCount/$_stampThreshold)',
                          style: GoogleFonts.outfit(fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2E7D32).withValues(alpha: 0.7))),
                        const SizedBox(height: 6),
                        _StampRow(
                          current: _stampCount,
                          threshold: _stampThreshold,
                        ),
                        if (_stampCount + 1 >= _stampThreshold) ...[  
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('🎉 Đơn này hoàn thành thẻ — khách nhận thưởng!',
                              style: GoogleFonts.outfit(fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE65100))),
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: Color(0xFF4CAF50)),
                        const SizedBox(height: 10),
                        // ── Điểm tích lũy + dùng điểm ──────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Điểm hiện có',
                                style: GoogleFonts.outfit(fontSize: 11,
                                  color: const Color(0xFF2E7D32).withValues(alpha: 0.7))),
                              Text('$_customerPts điểm',
                                style: GoogleFonts.outfit(fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1B5E20))),
                              Text('= ${fmtVnd((_customerPts * _redeemRate).toDouble())}',
                                style: GoogleFonts.outfit(fontSize: 11,
                                  color: const Color(0xFF388E3C))),
                            ]),
                            if (_customerPts > 0) Column(children: [
                              Text('Dùng điểm giảm giá',
                                style: GoogleFonts.outfit(fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1B5E20))),
                              const SizedBox(height: 4),
                              Row(children: [
                                // Nút trừ
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _usePts = (_usePts - 1).clamp(0, _customerPts);
                                  }),
                                  child: Container(
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(
                                      color: _usePts > 0
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFF2E7D32).withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.remove_rounded,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('$_usePts',
                                    style: GoogleFonts.outfit(fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF1B5E20))),
                                ),
                                // Nút cộng
                                GestureDetector(
                                  onTap: () {
                                    final maxUsable = (widget.total / _redeemRate).floor();
                                    setState(() {
                                      _usePts = (_usePts + 1)
                                          .clamp(0, _customerPts.clamp(0, maxUsable));
                                    });
                                  },
                                  child: Container(
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32),
                                      borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.add_rounded,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ]),
                              // Nút dùng tất cả
                              TextButton(
                                onPressed: () {
                                  final maxUsable = (widget.total / _redeemRate).floor();
                                  setState(() {
                                    _usePts = _customerPts.clamp(0, maxUsable);
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text('Dùng tất cả',
                                  style: GoogleFonts.outfit(fontSize: 10,
                                    color: const Color(0xFF388E3C),
                                    decoration: TextDecoration.underline)),
                              ),
                            ]),
                          ],
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Payment method picker
                  Text(
                    'Hình thức thanh toán',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kNavy.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _PayMethodTile(
                        icon: Icons.payments_rounded,
                        label: 'Tiền mặt',
                        value: 'cash',
                        selected: _payMethod,
                        color: const Color(0xFF4CAF50),
                        onTap: () => setState(() => _payMethod = 'cash'),
                      ),
                      const SizedBox(width: 10),
                      _PayMethodTile(
                        icon: Icons.qr_code_rounded,
                        label: 'Chuyển khoản',
                        value: 'transfer',
                        selected: _payMethod,
                        color: const Color(0xFF2196F3),
                        onTap: () => setState(() => _payMethod = 'transfer'),
                      ),
                      const SizedBox(width: 10),
                      _PayMethodTile(
                        icon: Icons.credit_card_rounded,
                        label: 'Thẻ',
                        value: 'card',
                        selected: _payMethod,
                        color: const Color(0xFF9C27B0),
                        onTap: () => setState(() => _payMethod = 'card'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // Confirm button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, {
                  'pay':        _payMethod,
                  'customerId': _customerId,
                  'ptsUsed':    _usePts,
                  'discount':   _usePts * _redeemRate,
                }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: zoneColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(
                    'Xác nhận thanh toán ${fmtVnd(widget.total)}',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Payment method tile
class _PayMethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String selected;
  final Color color;
  final VoidCallback onTap;

  const _PayMethodTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSel = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSel ? color : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSel ? color : _kNavy.withValues(alpha: 0.12),
              width: isSel ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSel ? Colors.white : color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSel ? Colors.white : _kNavy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD ITEMS SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _AddItemsSheet extends ConsumerStatefulWidget {
  final String sessionId;
  const _AddItemsSheet({required this.sessionId});

  @override
  ConsumerState<_AddItemsSheet> createState() => _AddItemsSheetState();
}

class _AddItemsSheetState extends ConsumerState<_AddItemsSheet> {
  final Map<String, int> _selected = {};
  final Map<String, String> _notes = {};
  final Map<String, Set<String>> _selectedModifiers = {};
  final Map<String, List<Map<String, dynamic>>> _modifierCache = {};
  // Topping quantities: productId → { toppingId → qty }
  final Map<String, Map<String, int>> _selectedToppings = {};
  // Topping info cache: toppingId → {name, sell_price, unit}
  final Map<String, Map<String, dynamic>> _toppingInfoCache = {};
  String _search = '';
  String _selectedCategory = 'Tất cả';
  bool _isConfirming = false;
  BanRepository get _banRepo => ref.read(banRepositoryProvider);

  late final TextEditingController _searchCtrl;
  final Set<String> _expandedProductIds = {};

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: _search);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  final GlobalKey _bottomBarKey = GlobalKey();
  int _bottomBarPopTrigger = 0;

  Offset _getBottomBarOffset() {
    try {
      final RenderBox? box = _bottomBarKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final position = box.localToGlobal(Offset.zero);
        return Offset(position.dx + box.size.width / 2, position.dy + box.size.height / 2);
      }
    } catch (_) {}
    return Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height - 40);
  }

  static const _kPresets = [
    'Ít cay', 'Không cay', 'Ít đường', 'Không đá',
    'Nhiều hành', 'Không hành', 'Ít mắm', 'Thêm rau',
  ];

  Future<void> _confirm(List<ProductModel> products) async {
    if (_selected.isEmpty) { Navigator.pop(context); return; }
    if (_isConfirming) return;
    setState(() {
      _isConfirming = true;
    });
    try {
      final List<Map<String, dynamic>> itemsList = [];
      for (final entry in _selected.entries) {
        final product = products.firstWhere((p) => p.id == entry.key);
        final qty = entry.value.toDouble();
        final note = _notes[product.id];
        // Modifiers (on/off)
        final selectedModIds = _selectedModifiers[product.id] ?? {};
        final modifiers = _modifierCache[product.id] ?? [];
        final selectedMods = modifiers.where((m) => selectedModIds.contains(m['id'])).toList();
        final modPrice = selectedMods.fold<double>(0, (s, m) => s + ((m['price_adjust'] as num?)?.toDouble() ?? 0));
        // Toppings — đọc từ _toppingInfoCache (populated by picker)
        final toppingQtys = _selectedToppings[product.id] ?? {};
        final toppingEntries = toppingQtys.entries.where((e) => e.value > 0).toList();
        // Option C: counter = tổng phần topping, không phải per-bowl
        double toppingTotalPrice = 0;
        final List<Map<String, dynamic>> toppingItems = [];
        for (final tEntry in toppingEntries) {
          final tc = _toppingInfoCache[tEntry.key];
          if (tc != null) {
            final price = (tc['sell_price'] as num?)?.toDouble() ?? 0;
            toppingTotalPrice += price * tEntry.value;  // total across all bowls
            toppingItems.add({
              'type': 'topping',
              'id': tEntry.key,
              'name': tc['name'] as String? ?? '',
              'price': price,
              'qty': tEntry.value,  // total qty
              'unit': tc['unit'] as String? ?? 'phần',
            });
          }
        }
        // Spread topping cost evenly per bowl: finalPrice = bowlPrice + toppingTotal/bowlQty
        final finalPrice = product.sellPrice + modPrice + (qty > 0 ? toppingTotalPrice / qty : 0);
        // Merge modifiers + toppings vào 1 JSON
        final allExtras = [...selectedMods, ...toppingItems];
        final modifiersJson = allExtras.isEmpty ? null : jsonEncode(allExtras);

        itemsList.add({
          'productId': product.id,
          'productName': product.name,
          'price': finalPrice,
          'quantity': qty,
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
          'modifiersJson': modifiersJson,
        });
      }

      await _banRepo.addSessionItems(
        sessionId: widget.sessionId,
        items: itemsList,
      );

      ref.invalidate(sessionItemsProvider(widget.sessionId));
      HapticFeedback.lightImpact();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isConfirming = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi thêm món: $e',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
        ));
      }
    }
  }

  // Mở sheet chọn topping phẳng (flat list, không dùng nhóm)
  void _openToppingPicker(dynamic product, List<Map<String, dynamic>> toppings) {
    // Populate cache để _confirm() có thể build modifiersJson
    for (final t in toppings) {
      _toppingInfoCache[t['id'] as String] = t;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ToppingPickerSheet(
        product: product,
        toppings: toppings,
        selectedQtys: Map<String, int>.from(_selectedToppings[product.id] ?? {}),
        onChanged: (updated) => setState(() => _selectedToppings[product.id] = updated),
      ),
    );
  }

  // Hiển thị Bottom Sheet xem nhanh các món đã chọn trong giỏ nháp
  void _showDraftCartPreview(List<ProductModel> products) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart_rounded, color: _kNavy, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Chi tiết món đã chọn',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _kNavy,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_selected.values.fold(0, (s, v) => s + v)} món',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kNavy.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 0.5),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final selectedEntries = _selected.entries.where((e) => e.value > 0).toList();
                        if (selectedEntries.isEmpty) {
                          return Center(
                            child: Text(
                              'Chưa có món nào được chọn',
                              style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.w600),
                            ),
                          );
                        }
                        return ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: selectedEntries.length,
                          separatorBuilder: (_, __) => const Divider(height: 24, thickness: 0.5),
                          itemBuilder: (ctx, index) {
                            final entry = selectedEntries[index];
                            final prod = products.firstWhere((p) => p.id == entry.key);
                            final qty = entry.value;
                            final note = _notes[prod.id] ?? '';

                            // Modifiers list
                            final selectedModIds = _selectedModifiers[prod.id] ?? {};
                            final modifiers = _modifierCache[prod.id] ?? [];
                            final selectedMods = modifiers.where((m) => selectedModIds.contains(m['id'])).toList();

                            // Toppings list
                            final toppingQtys = _selectedToppings[prod.id] ?? {};
                            final toppingEntries = toppingQtys.entries.where((e) => e.value > 0).toList();

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _kNavy.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${qty}x',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: _kNavy,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prod.name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: _kNavy,
                                        ),
                                      ),
                                      if (selectedMods.isNotEmpty || toppingEntries.isNotEmpty || note.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: [
                                            ...selectedMods.map((m) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _kOrange.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                m['name'] as String,
                                                style: GoogleFonts.outfit(fontSize: 10.5, color: _kOrange, fontWeight: FontWeight.w600),
                                              ),
                                            )),
                                            ...toppingEntries.map((te) {
                                              final tc = _toppingInfoCache[te.key];
                                              final tName = tc?['name'] as String? ?? 'Topping';
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '+${te.value} $tName',
                                                  style: GoogleFonts.outfit(fontSize: 10.5, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                                                ),
                                              );
                                            }),
                                            if (note.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '📝 $note',
                                                  style: GoogleFonts.outfit(fontSize: 10.5, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, color: _kRed.withValues(alpha: 0.7), size: 20),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.pop(context);
                                    setState(() {
                                      _selected.remove(prod.id);
                                      _selectedModifiers.remove(prod.id);
                                      _selectedToppings.remove(prod.id);
                                      _notes.remove(prod.id);
                                      _expandedProductIds.remove(prod.id);
                                    });
                                    _showDraftCartPreview(products);
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      }
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

  Widget build(BuildContext context) {
    final productsAsync = ref.watch(posProductsProvider);
    final storeId = ref.read(sessionProvider)?.storeId ?? '';

    return PopScope(
      canPop: !_isConfirming,
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC), // Ultra-clean premium slate background
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: _kNavy.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // ── HỘP TÌM KIẾM CAO CẤP ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: _kNavy.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: GoogleFonts.outfit(color: _kNavy, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Tìm sản phẩm, thức uống...',
                    hintStyle:
                        GoogleFonts.outfit(color: _kNavy.withValues(alpha: 0.35), fontWeight: FontWeight.w500),
                    prefixIcon: Icon(Icons.search_rounded, color: _kNavy.withValues(alpha: 0.5), size: 22),
                    suffixIcon: _search.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                            child: Icon(
                              Icons.cancel_rounded,
                              color: _kNavy.withValues(alpha: 0.45),
                              size: 20,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _kNavy.withValues(alpha: 0.05)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _kNavy.withValues(alpha: 0.05)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _kNavy, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── THANH DANH MỤC DI ĐỘNG CAO CẤP ────────────────────────────────
            productsAsync.when(
              data: (products) {
                final cats = <String>{
                  ...products.map((p) => p.category ?? 'Khác')
                }.toList()..sort();
                if (cats.length <= 1) return const SizedBox.shrink();
                final allCats = ['Tất cả', ...cats];
                return SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allCats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = allCats[i];
                      final isActive = cat == _selectedCategory;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedCategory = cat);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive ? _kNavy : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive ? _kNavy : _kNavy.withValues(alpha: 0.08),
                              width: 1,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: _kNavy.withValues(alpha: 0.18),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(cat,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? Colors.white : _kNavy.withValues(alpha: 0.6),
                                )),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            // ── DANH SÁCH MÓN ĂN DẠNG THẺ (CARD LAYOUT) ───────────────────────
            Expanded(
              child: productsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (products) {
                  final filtered = _search.isEmpty && _selectedCategory == 'Tất cả'
                      ? products
                      : products.where((p) {
                          final matchCat = _selectedCategory == 'Tất cả'
                              ? true
                              : (p.category ?? 'Khác') == _selectedCategory;
                          final matchSearch = _search.isEmpty
                              ? true
                              : p.name.toLowerCase().contains(_search.toLowerCase());
                          return matchCat && matchSearch;
                        }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔍', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 10),
                          Text(
                            'Không tìm thấy sản phẩm phù hợp',
                            style: GoogleFonts.outfit(
                              color: _kNavy.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      final qty = _selected[p.id] ?? 0;
                      final isOutOfStock = p.stockQty <= 0 && p.minStock > 0;

                      final modifiersAsync =
                          ref.watch(productModifiersProvider(p.id));
                      final modifiers = modifiersAsync.value ?? [];
                      if (modifiers.isNotEmpty) _modifierCache[p.id] = modifiers;

                      final selectedModIds = _selectedModifiers[p.id] ?? {};
                      final modPrice = modifiers
                          .where((m) => selectedModIds.contains(m['id'] as String))
                          .fold<double>(0, (s, m) => s + ((m['price_adjust'] as num?)?.toDouble() ?? 0));
                      final finalPrice = (p.sellPrice ?? 0) + modPrice;

                      final modGroups = <String, List<Map<String, dynamic>>>{};
                      for (final m in modifiers) {
                        modGroups.putIfAbsent(m['group_name'] as String? ?? 'Mặc định', () => []).add(m);
                      }

                      return Opacity(
                        opacity: isOutOfStock ? 0.55 : 1.0,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: qty > 0
                                ? _kNavy.withValues(alpha: 0.03)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: qty > 0
                                  ? _kNavy.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.04),
                              width: qty > 0 ? 1.8 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: qty > 0
                                    ? _kNavy.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.02),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    // ── Ảnh sản phẩm cao cấp ──
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                            ? Image.network(
                                                p.imageUrl!,
                                                width: 58,
                                                height: 58,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: _kNavy.withValues(alpha: 0.05),
                                                  child: Icon(
                                                    Icons.restaurant_rounded,
                                                    color: _kNavy.withValues(alpha: 0.35),
                                                    size: 26,
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                color: _kNavy.withValues(alpha: 0.05),
                                                child: Icon(
                                                  Icons.restaurant_rounded,
                                                  color: _kNavy.withValues(alpha: 0.35),
                                                  size: 26,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // ── Chi tiết sản phẩm ──
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          if (qty > 0) {
                                            HapticFeedback.selectionClick();
                                            setState(() {
                                              if (_expandedProductIds.contains(p.id)) {
                                                _expandedProductIds.remove(p.id);
                                              } else {
                                                _expandedProductIds.add(p.id);
                                              }
                                            });
                                          }
                                        },
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(p.name,
                                                      style: GoogleFonts.outfit(
                                                        fontWeight: FontWeight.w700,
                                                        color: _kNavy,
                                                        fontSize: 14.5,
                                                      )),
                                                ),
                                                if (isOutOfStock)
                                                  Container(
                                                    margin: const EdgeInsets.only(left: 6),
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFFEBEE),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text('TẠM HẾT',
                                                        style: GoogleFonts.outfit(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.w800,
                                                            color: _kRed,
                                                            letterSpacing: 0.5)),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              modPrice > 0
                                                  ? '${fmtVnd(p.sellPrice ?? 0)} +${fmtVnd(modPrice)} = ${fmtVnd(finalPrice)}'
                                                  : fmtVnd(p.sellPrice ?? 0),
                                              style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                color: modPrice > 0
                                                    ? _kOrange
                                                    : _kNavy.withValues(alpha: 0.55),
                                                fontWeight: modPrice > 0
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // ── Điều khiển số lượng cao cấp ──
                                    Row(
                                      children: [
                                        if (qty > 0) ...[
                                          GestureDetector(
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                if (_expandedProductIds.contains(p.id)) {
                                                  _expandedProductIds.remove(p.id);
                                                } else {
                                                  _expandedProductIds.add(p.id);
                                                }
                                              });
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.only(right: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: _expandedProductIds.contains(p.id)
                                                    ? _kNavy.withValues(alpha: 0.12)
                                                    : _kNavy.withValues(alpha: 0.06),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _expandedProductIds.contains(p.id)
                                                        ? Icons.expand_less_rounded
                                                        : Icons.tune_rounded,
                                                    size: 14,
                                                    color: _kNavy,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _expandedProductIds.contains(p.id) ? 'Thu gọn' : 'Tùy chọn',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: _kNavy,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: _kNavy.withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                            child: Row(
                                              children: [
                                                GestureDetector(
                                                  onTap: () {
                                                    HapticFeedback.selectionClick();
                                                    setState(() {
                                                      if (qty <= 1) {
                                                        _selected.remove(p.id);
                                                        _selectedModifiers.remove(p.id);
                                                        _expandedProductIds.remove(p.id);
                                                      } else {
                                                        _selected[p.id] = qty - 1;
                                                      }
                                                    });
                                                  },
                                                  child: Container(
                                                    width: 28,
                                                    height: 28,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Icon(Icons.remove_rounded, size: 14, color: _kNavy),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 32,
                                                  child: Text(
                                                    '$qty',
                                                    textAlign: TextAlign.center,
                                                    style: GoogleFonts.outfit(
                                                      fontWeight: FontWeight.w800,
                                                      color: _kNavy,
                                                      fontSize: 13.5,
                                                    ),
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTapDown: isOutOfStock ? null : (details) {
                                                    setState(() => _selected[p.id] = qty + 1);
                                                    
                                                    // Kích hoạt hiệu ứng bay mượt mà WOW v3
                                                    CartAnimationHelper.runFlyAnimation(
                                                      context: context,
                                                      startOffset: details.globalPosition,
                                                      endOffset: _getBottomBarOffset(),
                                                      color: _kNavy,
                                                      onComplete: () {
                                                        setState(() {
                                                          _bottomBarPopTrigger++;
                                                        });
                                                        HapticFeedback.lightImpact();
                                                      },
                                                    );
                                                  },
                                                  child: Container(
                                                    width: 28,
                                                    height: 28,
                                                    decoration: BoxDecoration(
                                                      color: _kNavy,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ] else ...[
                                          GestureDetector(
                                            onTapDown: isOutOfStock ? null : (details) {
                                              setState(() => _selected[p.id] = 1);
                                              
                                              // Kích hoạt hiệu ứng bay mượt mà WOW v3
                                              CartAnimationHelper.runFlyAnimation(
                                                context: context,
                                                startOffset: details.globalPosition,
                                                endOffset: _getBottomBarOffset(),
                                                color: _kNavy,
                                                onComplete: () {
                                                  setState(() {
                                                    _bottomBarPopTrigger++;
                                                  });
                                                  HapticFeedback.lightImpact();
                                                },
                                              );
                                            },
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: isOutOfStock
                                                    ? _kNavy.withValues(alpha: 0.25)
                                                    : _kNavy,
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: isOutOfStock
                                                    ? []
                                                    : [
                                                        BoxShadow(
                                                          color: _kNavy.withValues(alpha: 0.15),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 3),
                                                        )
                                                      ],
                                              ),
                                              child: const Icon(Icons.add_rounded,
                                                  size: 20, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // ── PHÂN HỆ TOPPING CAO CẤP CHẠY INLINE ──────────
                              if (qty > 0 && _expandedProductIds.contains(p.id))
                                Builder(builder: (_) {
                                  final toppingsAsync = ref.watch(productToppingLinksProvider(p.id));
                                  final toppings = toppingsAsync.value ?? [];
                                  if (toppings.isEmpty) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: _kNavy.withValues(alpha: 0.05)),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text('🥗 Topping tùy chọn',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: _kNavy.withValues(alpha: 0.45),
                                                )),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          ...toppings.map((t) {
                                            final toppingId = t['id'] as String;
                                            final toppingName = t['name'] as String? ?? '';
                                            final toppingPrice = (t['sell_price'] as num? ?? 0).toDouble();
                                            final toppingUnit = t['unit'] as String? ?? 'phần';
                                            final tQty = _selectedToppings[p.id]?[toppingId] ?? 0;
                                            final isActive = tQty > 0;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(toppingName,
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w700,
                                                            color: isActive ? _kOrange : _kNavy,
                                                          )),
                                                        Text('+${fmtVnd(toppingPrice)}/$toppingUnit',
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 11,
                                                            color: _kOrange.withValues(alpha: 0.85),
                                                            fontWeight: FontWeight.w600,
                                                          )),
                                                      ],
                                                    ),
                                                  ),
                                                  if (isActive) ...[
                                                    GestureDetector(
                                                      onTap: () {
                                                        HapticFeedback.selectionClick();
                                                        setState(() {
                                                          final qtys = Map<String, int>.from(_selectedToppings[p.id] ?? {});
                                                          if (tQty <= 1) qtys.remove(toppingId);
                                                          else qtys[toppingId] = tQty - 1;
                                                          _selectedToppings[p.id] = qtys;
                                                          _toppingInfoCache[toppingId] = t;
                                                        });
                                                      },
                                                      child: Container(
                                                        width: 28,
                                                        height: 28,
                                                        decoration: BoxDecoration(
                                                          color: _kNavy.withValues(alpha: 0.08),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Icon(Icons.remove_rounded, size: 14, color: _kNavy),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text('$tQty',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w800,
                                                        color: _kOrange,
                                                      )),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  GestureDetector(
                                                    onTap: () {
                                                      HapticFeedback.selectionClick();
                                                      setState(() {
                                                        final qtys = Map<String, int>.from(_selectedToppings[p.id] ?? {});
                                                        qtys[toppingId] = tQty + 1;
                                                        _selectedToppings[p.id] = qtys;
                                                        _toppingInfoCache[toppingId] = t;
                                                      });
                                                    },
                                                    child: Container(
                                                      width: 28,
                                                      height: 28,
                                                      decoration: BoxDecoration(
                                                        color: isActive ? _kOrange : _kNavy.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Icon(Icons.add_rounded, size: 14,
                                                        color: isActive ? Colors.white : _kNavy),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ),
                                  );
                                }),

                              // ── HƯƠNG VỊ / MODIFIER CHIPS CAO CẤP ───────────
                              if (qty > 0 && _expandedProductIds.contains(p.id) && modifiers.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF9F6), // Warm light background for flavors
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: _kNavy.withValues(alpha: 0.05)),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '✨ Tùy chọn hương vị',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: _kNavy.withValues(alpha: 0.45),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...modGroups.entries.map((entry) {
                                          final groupName = entry.key;
                                          final groupMods = entry.value;
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (modGroups.length > 1)
                                                Padding(
                                                  padding: const EdgeInsets.only(
                                                      bottom: 4, top: 4),
                                                  child: Text(
                                                    groupName,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: _kNavy.withValues(alpha: 0.4),
                                                    ),
                                                  ),
                                                ),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: groupMods.map((mod) {
                                                  final modId = mod['id'] as String;
                                                  final isSelected =
                                                      selectedModIds.contains(modId);
                                                  return GestureDetector(
                                                    onTap: () {
                                                      HapticFeedback.selectionClick();
                                                      setState(() {
                                                        final mods =
                                                            _selectedModifiers
                                                                .putIfAbsent(
                                                                    p.id, () => {});
                                                        if (isSelected) {
                                                          mods.remove(modId);
                                                        } else {
                                                          mods.add(modId);
                                                        }
                                                      });
                                                    },
                                                    child: AnimatedContainer(
                                                      duration: const Duration(
                                                          milliseconds: 180),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 11,
                                                          vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? _kOrange
                                                            : Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                16),
                                                        border: Border.all(
                                                          color: isSelected
                                                              ? _kOrange
                                                              : _kNavy.withValues(
                                                                  alpha: 0.15),
                                                          width: 1,
                                                        ),
                                                        boxShadow: isSelected
                                                            ? [
                                                                BoxShadow(
                                                                  color: _kOrange.withValues(alpha: 0.2),
                                                                  blurRadius: 6,
                                                                  offset: const Offset(0, 2),
                                                                )
                                                              ]
                                                            : [],
                                                      ),
                                                      child: Text(
                                                        (mod['price_adjust'] as num? ?? 0) > 0
                                                            ? '${mod['name']} +${fmtVnd((mod['price_adjust'] as num).toDouble())}'
                                                            : mod['name'] as String,
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isSelected
                                                              ? Colors.white
                                                              : _kNavy.withValues(alpha: 0.75),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                                ),

                              // ── GHI CHÚ NHANH (QUICK NOTE PRESETS) ───────────
                              if (qty > 0 && _expandedProductIds.contains(p.id))
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: 32,
                                        child: ListView(
                                          scrollDirection: Axis.horizontal,
                                          children: [
                                            ..._kPresets.map((preset) {
                                              final note = _notes[p.id] ?? '';
                                              final isOn = note.contains(preset);
                                              return Padding(
                                                padding: const EdgeInsets.only(right: 6),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    HapticFeedback.selectionClick();
                                                    setState(() {
                                                      var current = _notes[p.id] ?? '';
                                                      if (isOn) {
                                                        current = current
                                                            .replaceAll(', $preset', '')
                                                            .replaceAll(preset, '')
                                                            .trim()
                                                            .replaceAll(RegExp(r'^,\s*|,\s*$'), '');
                                                      } else {
                                                        current = current.isEmpty
                                                            ? preset
                                                            : '$current, $preset';
                                                      }
                                                      _notes[p.id] = current;
                                                    });
                                                  },
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 140),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: isOn ? _kOrange : Colors.white,
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: isOn ? _kOrange : _kNavy.withValues(alpha: 0.15),
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Text(preset,
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: isOn ? Colors.white : _kNavy.withValues(alpha: 0.65),
                                                          )),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                            // ✏️ Ghi chú tự do
                                            GestureDetector(
                                              onTap: () async {
                                                final ctrl = TextEditingController(text: _notes[p.id]);
                                                await showDialog(
                                                  context: context,
                                                  builder: (_) => AlertDialog(
                                                    title: Text('Ghi chú cho ${p.name}',
                                                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
                                                    content: TextField(
                                                      controller: ctrl,
                                                      autofocus: true,
                                                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                                                      decoration: InputDecoration(
                                                        hintText: 'vd: ít rau, không cay...',
                                                        hintStyle: GoogleFonts.outfit(color: _kNavy.withValues(alpha: 0.35)),
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                                        focusedBorder: OutlineInputBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                          borderSide: const BorderSide(color: _kNavy, width: 1.5),
                                                        ),
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.pop(context), child: Text('Huỷ', style: GoogleFonts.outfit(color: _kNavy.withValues(alpha: 0.5), fontWeight: FontWeight.w700))),
                                                      TextButton(
                                                        onPressed: () { setState(() => _notes[p.id] = ctrl.text.trim()); Navigator.pop(context); },
                                                        child: Text('Lưu', style: GoogleFonts.outfit(color: _kNavy, fontWeight: FontWeight.w800)),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: _kNavy.withValues(alpha: 0.15)),
                                                ),
                                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                  Icon(Icons.edit_rounded, size: 12, color: _kNavy.withValues(alpha: 0.5)),
                                                  const SizedBox(width: 4),
                                                  Text('Ghi chú',
                                                      style: GoogleFonts.outfit(
                                                          fontSize: 11, fontWeight: FontWeight.w700, color: _kNavy.withValues(alpha: 0.6))),
                                                ]),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if ((_notes[p.id] ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            '📝 ${_notes[p.id]}',
                                            style: GoogleFonts.outfit(
                                                fontSize: 11.5, color: _kOrange, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // ── THANH TỔNG HỢP & NÚT THÊM MÓN CAO CẤP Ở DƯỚI CÙNG ────────────────
            productsAsync.when(
              data: (products) {
                final count = _selected.values.fold(0, (s, v) => s + v);
                double total = 0;
                for (final entry in _selected.entries) {
                  final prod = products.firstWhere(
                    (p) => p.id == entry.key,
                    orElse: () => products.first,
                  );
                  final selectedMods = _selectedModifiers[entry.key] ?? {};
                  final mods = _modifierCache[entry.key] ?? [];
                  final modPrice = mods
                      .where((m) => selectedMods.contains(m['id']))
                      .fold<double>(0, (s, m) => s + ((m['price_adjust'] as num?)?.toDouble() ?? 0));
                  
                  double toppingTotalPrice = 0;
                  final toppingQtys = _selectedToppings[entry.key] ?? {};
                  for (final tEntry in toppingQtys.entries) {
                    final tc = _toppingInfoCache[tEntry.key];
                    if (tc != null) {
                      toppingTotalPrice += ((tc['sell_price'] as num?)?.toDouble() ?? 0) * tEntry.value;
                    }
                  }
                  total += (prod.sellPrice + modPrice) * entry.value + toppingTotalPrice;
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: _kNavy.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (count > 0) ...[
                          Row(children: [
                            Icon(Icons.receipt_long_rounded, size: 18,
                                color: _kNavy.withValues(alpha: 0.6)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _kNavy,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('$count món',
                                  style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showDraftCartPreview(products),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _kOrange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _kOrange.withValues(alpha: 0.25), width: 0.8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.shopping_cart_rounded, size: 12, color: _kOrange),
                                    const SizedBox(width: 4),
                                    Text('Xem chi tiết',
                                        style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: _kOrange)),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text('Tổng cộng: ',
                                style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _kNavy.withValues(alpha: 0.5))),
                            Text(fmtVnd(total),
                                style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _kNavy)),
                          ]),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          key: _bottomBarKey,
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isConfirming
                                ? null
                                : () => _confirm(products),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: count > 0 ? _kNavy : const Color(0xFFE2E8F0),
                              foregroundColor: count > 0 ? Colors.white : _kNavy.withValues(alpha: 0.4),
                              disabledBackgroundColor: (count > 0 ? _kNavy : const Color(0xFFE2E8F0)).withValues(alpha: 0.6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                              shadowColor: _kNavy.withValues(alpha: 0.25),
                            ),
                            child: _isConfirming
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    count > 0 ? 'Xác nhận • Thêm $count món' : 'Quay lại Bàn',
                                    style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                          ),
                        ).animate(
                          target: _bottomBarPopTrigger.toDouble(),
                        ).scaleXY(begin: 1.0, end: 1.05, duration: 150.ms, curve: Curves.easeOut)
                         .then()
                         .scaleXY(begin: 1.05, end: 1.0, duration: 100.ms),
                      ]),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
      ),
    ),);
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// TOPPING PICKER SHEET — Flat list (bảng đơn giản, không nhóm)
// ─────────────────────────────────────────────────────────────────────────────
class _ToppingPickerSheet extends StatefulWidget {
  final dynamic product;
  final List<Map<String, dynamic>> toppings;
  final Map<String, int> selectedQtys;
  final void Function(Map<String, int>) onChanged;

  const _ToppingPickerSheet({
    required this.product,
    required this.toppings,
    required this.selectedQtys,
    required this.onChanged,
  });

  @override
  State<_ToppingPickerSheet> createState() => _ToppingPickerSheetState();
}

class _ToppingPickerSheetState extends State<_ToppingPickerSheet> {
  late Map<String, int> _qtys;

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kOrange = Color(0xFFE85D20);
  static const _kCream  = Color(0xFFFAF7F2);
  static const _kBorder = Color(0xFFE0D8CC);
  static const _kMuted  = Color(0xFF9E9085);

  @override
  void initState() {
    super.initState();
    _qtys = Map<String, int>.from(widget.selectedQtys);
  }

  double get _totalPrice {
    double total = 0;
    for (final t in widget.toppings) {
      final q = _qtys[t['id'] as String] ?? 0;
      total += (t['sell_price'] as num? ?? 0).toDouble() * q;
    }
    return total;
  }

  int get _totalQty => _qtys.values.fold(0, (s, q) => s + q);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.35,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: _kNavy.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 14),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Icon(Icons.add_circle_outline_rounded, size: 20, color: _kOrange),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Topping cho ${widget.product.name ?? ''}',
                style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: _kNavy),
              )),
              if (_totalQty > 0) Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+${fmtVnd(_totalPrice)}',
                  style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: _kOrange),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          // Topping list
          Expanded(
            child: widget.toppings.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_shopping_cart_outlined, size: 40, color: _kNavy.withValues(alpha: 0.15)),
                    const SizedBox(height: 8),
                    Text('Chưa có topping nào\nVào Kho → sửa món để gắn topping',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 13, color: _kMuted)),
                  ],
                ))
              : ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  itemCount: widget.toppings.length,
                  itemBuilder: (_, i) {
                    final t = widget.toppings[i];
                    final tid = t['id'] as String;
                    final qty = _qtys[tid] ?? 0;
                    final price = (t['sell_price'] as num? ?? 0).toDouble();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: qty > 0
                          ? _kOrange.withValues(alpha: 0.06)
                          : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: qty > 0 ? _kOrange : _kBorder,
                          width: qty > 0 ? 1.5 : 1),
                      ),
                      child: Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['name'] as String? ?? '',
                              style: GoogleFonts.outfit(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: _kNavy)),
                            if (price > 0)
                              Text('+${fmtVnd(price)}/${t['unit'] ?? 'phần'}',
                                style: GoogleFonts.outfit(
                                  fontSize: 12, color: _kOrange,
                                  fontWeight: FontWeight.w600)),
                          ],
                        )),
                        // Increment/Decrement
                        Row(children: [
                          if (qty > 0) ...[
                            GestureDetector(
                              onTap: () => setState(() {
                                _qtys[tid] = qty - 1;
                                if (_qtys[tid] == 0) _qtys.remove(tid);
                                widget.onChanged(Map<String, int>.from(_qtys));
                              }),
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: _kNavy.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8)),
                                child: Icon(Icons.remove_rounded, size: 16,
                                  color: _kNavy.withValues(alpha: 0.6)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('$qty', style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.w800,
                              color: _kNavy)),
                            const SizedBox(width: 8),
                          ],
                          GestureDetector(
                            onTap: () => setState(() {
                              _qtys[tid] = qty + 1;
                              widget.onChanged(Map<String, int>.from(_qtys));
                            }),
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: qty > 0 ? _kOrange : _kNavy,
                                borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.add_rounded,
                                size: 16, color: Colors.white),
                            ),
                          ),
                        ]),
                      ]),
                    );
                  },
                ),
          ),
          // Footer confirm
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
                  child: Text(
                    _totalQty > 0
                      ? 'Xong · +${fmtVnd(_totalPrice)}'
                      : 'Không thêm topping',
                    style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: Colors.white)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// _ToppingGroupPickerSheet — DEPRECATED. Thay bằng _ToppingPickerSheet (flat list).


// ─────────────────────────────────────────────────────────────────────────────
// MODIFIER MANAGER SHEET — Quản lý tùy chọn cho từng sản phẩm
// ─────────────────────────────────────────────────────────────────────────────
class ModifierManagerSheet extends StatefulWidget {
  final ProductModel product;
  const ModifierManagerSheet({required this.product});
  @override
  State<ModifierManagerSheet> createState() => _ModifierManagerSheetState();
}

class _ModifierManagerSheetState extends State<ModifierManagerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  // Tab 0: Tùy chọn
  final _nameCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();
  String _group   = 'Mặc định';
  bool _saving    = false;
  List<Map<String, dynamic>> _modifiers = [];
  // Tab 1: Topping
  final _tNameCtrl  = TextEditingController();
  final _tPriceCtrl = TextEditingController();
  final _tUnitCtrl  = TextEditingController();
  String _tGroup    = 'Topping';
  bool _tSaving     = false;
  List<Map<String, dynamic>> _catalog    = [];   // tất cả topping của quán
  List<String>               _linkedIds  = [];   // đang gắn cho món này
  String? _storeId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tUnitCtrl.text = 'phần';
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nameCtrl.dispose(); _priceCtrl.dispose();
    _tNameCtrl.dispose(); _tPriceCtrl.dispose(); _tUnitCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadModifiers();
    await _loadToppingData();
  }

  Future<void> _loadModifiers() async {
    final resp = await Supabase.instance.client
        .from('product_modifiers').select()
        .eq('product_id', widget.product.id)
        .order('group_name').order('sort_order');
    if (mounted) setState(() => _modifiers = List<Map<String,dynamic>>.from(resp as List));
  }

  Future<void> _loadToppingData() async {
    // Lấy store_id
    final info = await StoreAuthService.getStoreInfo();
    _storeId = info['store_id'];
    if (_storeId == null) return;
    // Catalog toàn quán
    final cat = await Supabase.instance.client
        .from('topping_catalog').select()
        .eq('store_id', _storeId!).eq('is_active', true)
        .order('group_name').order('sort_order');
    // Links của món này
    final links = await Supabase.instance.client
        .from('product_topping_links').select('topping_catalog_id')
        .eq('product_id', widget.product.id);
    if (mounted) setState(() {
      _catalog   = List<Map<String,dynamic>>.from(cat as List);
      _linkedIds = (links as List).map((r) => r['topping_catalog_id'] as String).toList();
    });
  }

  Future<void> _addModifier() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final price = double.tryParse(_priceCtrl.text.replaceAll(',','').replaceAll('.','')) ?? 0;
    setState(() => _saving = true);
    await Supabase.instance.client.from('product_modifiers').insert({
      'id': const Uuid().v4(), 'product_id': widget.product.id,
      'group_name': _group.trim().isEmpty ? 'Mặc định' : _group.trim(),
      'name': name, 'price_adjust': price, 'sort_order': 0, 'is_active': true,
    });
    _nameCtrl.clear(); _priceCtrl.clear();
    setState(() => _saving = false);
    await _loadModifiers();
    HapticFeedback.lightImpact();
  }

  Future<void> _deleteModifier(Map<String,dynamic> mod) async {
    await Supabase.instance.client.from('product_modifiers').delete().eq('id', mod['id'] as String);
    await _loadModifiers(); HapticFeedback.mediumImpact();
  }

  Future<void> _toggleModifier(Map<String,dynamic> mod) async {
    await Supabase.instance.client.from('product_modifiers')
        .update({'is_active': !(mod['is_active'] as bool? ?? true)}).eq('id', mod['id'] as String);
    await _loadModifiers();
  }

  Future<void> _addToppingToCatalog() async {
    final name = _tNameCtrl.text.trim();
    if (name.isEmpty || _storeId == null) return;
    final price = double.tryParse(_tPriceCtrl.text.replaceAll(',','').replaceAll('.','')) ?? 0;
    final unit  = _tUnitCtrl.text.trim().isEmpty ? 'phần' : _tUnitCtrl.text.trim();
    setState(() => _tSaving = true);
    final id = const Uuid().v4();
    await Supabase.instance.client.from('topping_catalog').insert({
      'id': id, 'store_id': _storeId!, 'group_name': _tGroup.trim().isEmpty ? 'Topping' : _tGroup.trim(),
      'name': name, 'price': price, 'unit': unit, 'sort_order': 0, 'is_active': true,
    });
    // Tự động gắn cho món hiện tại
    await Supabase.instance.client.from('product_topping_links').insert(
        {'product_id': widget.product.id, 'topping_catalog_id': id});
    _tNameCtrl.clear(); _tPriceCtrl.clear();
    setState(() => _tSaving = false);
    await _loadToppingData();
    HapticFeedback.lightImpact();
  }

  Future<void> _toggleToppingLink(String toppingId) async {
    if (_linkedIds.contains(toppingId)) {
      await Supabase.instance.client.from('product_topping_links')
          .delete().eq('product_id', widget.product.id).eq('topping_catalog_id', toppingId);
    } else {
      await Supabase.instance.client.from('product_topping_links')
          .insert({'product_id': widget.product.id, 'topping_catalog_id': toppingId});
    }
    await _loadToppingData();
    HapticFeedback.selectionClick();
  }

  Future<void> _deleteToppingFromCatalog(String toppingId) async {
    await Supabase.instance.client.from('topping_catalog').delete().eq('id', toppingId);
    await _loadToppingData();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cài đặt món', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy)),
              Text(widget.product.name, style: GoogleFonts.outfit(fontSize: 13, color: _kOrange, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 10),
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _kNavy.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500),
              labelColor: Colors.white,
              unselectedLabelColor: _kNavy.withValues(alpha: 0.55),
              indicator: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: '⚙️  Tùy chọn'), Tab(text: '  Topping')],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(controller: _tabCtrl, children: [
              // ─── Tab 0: Tùy chọn (existing) ───────────────────────────────
              Column(children: [
                Expanded(child: _modifiers.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.tune_rounded, size: 40, color: _kNavy.withValues(alpha: 0.15)),
                      const SizedBox(height: 8),
                      Text('Chưa có tùy chọn', style: GoogleFonts.outfit(fontSize: 14, color: _kNavy.withValues(alpha: 0.35))),
                    ]))
                  : ListView(controller: scrollCtrl, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: (() {
                        final groups = <String, List<Map<String,dynamic>>>{};
                        for (final m in _modifiers) groups.putIfAbsent(m['group_name'] as String? ?? 'Mặc định', () => []).add(m);
                        return groups.entries.map((e) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(padding: const EdgeInsets.only(top: 8, bottom: 6),
                            child: Text(e.key, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: _kNavy.withValues(alpha: 0.45)))),
                          ...e.value.map((mod) {
                            final isActive = mod['is_active'] as bool? ?? true;
                            final priceAdj = (mod['price_adjust'] as num?)?.toDouble() ?? 0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _kNavy.withValues(alpha: isActive ? 0.1 : 0.05)),
                              ),
                              child: Row(children: [
                                GestureDetector(onTap: () => _toggleModifier(mod),
                                  child: Container(width: 22, height: 22,
                                    decoration: BoxDecoration(color: isActive ? _kNavy : _kNavy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                    child: isActive ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null)),
                                const SizedBox(width: 10),
                                Expanded(child: Text(
                                  priceAdj > 0 ? '${mod['name']}  +${fmtVnd(priceAdj)}' : mod['name'] as String,
                                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600,
                                    color: isActive ? _kNavy : _kNavy.withValues(alpha: 0.35),
                                    decoration: isActive ? null : TextDecoration.lineThrough))),
                                GestureDetector(onTap: () => _deleteModifier(mod),
                                  child: Icon(Icons.delete_outline_rounded, size: 18, color: _kRed.withValues(alpha: 0.5))),
                              ]),
                            );
                          }),
                        ])).toList();
                      })(),
                ),
                ),
                // Form thêm modifier
                Container(
                  padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
                  decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _kNavy.withValues(alpha: 0.08)))),
                  child: Row(children: [
                    SizedBox(width: 80, child: TextField(onChanged: (v) => setState(() => _group = v),
                      style: GoogleFonts.outfit(fontSize: 12),
                      decoration: InputDecoration(isDense: true, hintText: 'Nhóm',
                        hintStyle: GoogleFonts.outfit(fontSize: 12, color: _kNavy.withValues(alpha: 0.35)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kNavy.withValues(alpha: 0.2))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy))))),
                    const SizedBox(width: 6),
                    Expanded(child: TextField(controller: _nameCtrl, style: GoogleFonts.outfit(fontSize: 13),
                      decoration: InputDecoration(isDense: true, hintText: 'Tên tùy chọn',
                        hintStyle: GoogleFonts.outfit(fontSize: 12, color: _kNavy.withValues(alpha: 0.35)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kNavy.withValues(alpha: 0.2))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy))))),
                    const SizedBox(width: 6),
                    SizedBox(width: 70, child: TextField(controller: _priceCtrl, keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(fontSize: 12),
                      decoration: InputDecoration(isDense: true, hintText: '+Giá',
                        hintStyle: GoogleFonts.outfit(fontSize: 12, color: _kNavy.withValues(alpha: 0.35)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kNavy.withValues(alpha: 0.2))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kNavy))))),
                    const SizedBox(width: 6),
                    GestureDetector(onTap: _saving ? null : _addModifier,
                      child: Container(width: 36, height: 36,
                        decoration: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(10)),
                        child: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add_rounded, color: Colors.white, size: 18))),
                  ]),
                ),
              ]),

              // ─── Tab 1: Topping → Hướng dẫn dùng hệ thống mới ─────────────
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _kOrange.withValues(alpha: 0.08),
                        shape: BoxShape.circle),
                      child: const Icon(Icons.restaurant_menu_rounded, size: 40, color: _kOrange),
                    ),
                    const SizedBox(height: 16),
                    Text('Cấu hình Topping đã được nâng cấp',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: _kNavy)),
                    const SizedBox(height: 8),
                    Text(
                      'Vào Kho → tìm sản phẩm chính → nhấn nút "Topping" trên card để gắn topping.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 13, color: _kNavy.withValues(alpha: 0.55))),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _kOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kOrange.withValues(alpha: 0.3))),
                      child: Text('Hệ thống topping mới dùng bảng product_topping_links — mỗi sản phẩm có thể gắn nhiều topping trực tiếp.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 11, color: _kOrange, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ),

            ]),
          ),
        ]),
      ),
    );
  }
}


class _ZoneFormSheet extends StatefulWidget {
  final BanZoneModel? existing;
  const _ZoneFormSheet({this.existing});

  @override
  State<_ZoneFormSheet> createState() => _ZoneFormSheetState();
}

class _ZoneFormSheetState extends State<_ZoneFormSheet> {
  late TextEditingController _nameCtrl;
  late Color _selectedColor;
  late int _selectedIconCode;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _selectedColor = widget.existing != null
        ? Color(widget.existing!.colorValue)
        : _kNavy;
    _selectedIconCode = widget.existing?.iconCode ?? 0xe318;
  }

  String _colorToHex(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        decoration: BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kNavy.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEdit ? 'Sửa khu vực' : 'Thêm khu vực',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kNavy,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _nameCtrl,
                style: GoogleFonts.outfit(color: _kNavy),
                decoration: InputDecoration(
                  labelText: 'Tên khu vực',
                  labelStyle: GoogleFonts.outfit(
                      color: _kNavy.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _kNavy.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _kNavy.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kNavy),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Icon picker
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Biểu tượng',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: _kNavy.withValues(alpha: 0.6),
                      )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _kZoneIconCodes.map((iconCp) {
                      final isSel = _selectedIconCode == iconCp;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedIconCode = iconCp),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSel
                                ? _selectedColor.withValues(alpha: 0.15)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel
                                  ? _selectedColor
                                  : _kNavy.withValues(alpha: 0.1),
                              width: isSel ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              IconData(iconCp, fontFamily: 'MaterialIcons'),
                              size: 22,
                              color: isSel ? _selectedColor : _kNavy,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Color picker
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Màu sắc',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: _kNavy.withValues(alpha: 0.6),
                      )),
                  const SizedBox(height: 8),
                  Row(
                    children: _kZoneColors.map((color) {
                      final isSel = _selectedColor.value == color.value;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedColor = color),
                          child: Container(
                            margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              border: isSel
                                  ? Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    )
                                  : null,
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color:
                                            color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: isSel
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (isEdit)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(context, {'delete': true}),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _kRed),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Xoá khu',
                            style: GoogleFonts.outfit(
                              color: _kRed,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                  if (isEdit) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_nameCtrl.text.trim().isEmpty) return;
                        Navigator.pop(context, {
                          'name': _nameCtrl.text.trim(),
                          'color': _colorToHex(_selectedColor),
                          'iconCode': _selectedIconCode,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedColor,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(isEdit ? 'Lưu' : 'Thêm khu vực',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// B4: TABLE FORM SHEET — Thêm / Sửa bàn
// ─────────────────────────────────────────────────────────────────────────────
class _TableFormSheet extends StatefulWidget {
  final List<BanZoneModel> zones;
  final String? defaultZoneId;
  final BanTableModel? existing;

  const _TableFormSheet({
    required this.zones,
    this.defaultZoneId,
    this.existing,
  });

  @override
  State<_TableFormSheet> createState() => _TableFormSheetState();
}

class _TableFormSheetState extends State<_TableFormSheet> {
  late TextEditingController _nameCtrl;
  late String _selectedZoneId;
  late int _capacity;
  int _batchCount = 1; // Số lượng bàn thêm cùng lúc (chỉ dùng khi thêm mới)

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.label ?? '');
    _selectedZoneId = widget.existing?.zoneId ??
        widget.defaultZoneId ??
        (widget.zones.isNotEmpty ? widget.zones.first.id : '');
    _capacity = widget.existing?.seats ?? 4;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        decoration: BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kNavy.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEdit ? 'Sửa bàn' : 'Thêm bàn',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kNavy,
              ),
            ),
            const SizedBox(height: 16),
            // Tên bàn
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _nameCtrl,
                style: GoogleFonts.outfit(color: _kNavy),
                decoration: InputDecoration(
                  labelText: 'Tên bàn (vd: Bàn 1, Bàn VIP)',
                  labelStyle: GoogleFonts.outfit(
                      color: _kNavy.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _kNavy.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: _kNavy.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kNavy),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Chọn khu vực
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Khu vực',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: _kNavy.withValues(alpha: 0.6),
                      )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.zones.map((zone) {
                      final isSel = _selectedZoneId == zone.id;
                      Color zoneColor;
                      try {
                        zoneColor = Color(zone.colorValue);
                      } catch (_) {
                        zoneColor = _kNavy;
                      }
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedZoneId = zone.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? zoneColor
                                : zoneColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                IconData(zone.iconCode,
                                    fontFamily: 'MaterialIcons'),
                                size: 14,
                                color: isSel ? Colors.white : zoneColor,
                              ),
                              const SizedBox(width: 6),
                              Text(zone.name,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isSel ? Colors.white : zoneColor,
                                    fontSize: 13,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Số lượng bàn (chỉ hiện khi thêm mới)
            if (!isEdit) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Số lượng bàn',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kNavy.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Tiết kiệm thời gian!',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _kOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _batchCount == 1
                        ? 'Têm bàn sẽ được dùng nguyên vd: "Bàn 5"'
                        : 'Sẽ tạo: ${List.generate(_batchCount, (i) => '"${_nameCtrl.text.trim().isEmpty ? "Bàn" : _nameCtrl.text.trim()} ${i + 1}"').join(", ")}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: _kNavy.withValues(alpha: 0.4),
                      fontStyle: _batchCount > 1 ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _CounterButton(
                        icon: Icons.remove_rounded,
                        onTap: () {
                          if (_batchCount > 1) setState(() => _batchCount--);
                        },
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$_batchCount',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: _kNavy,
                              ),
                            ),
                            Text(
                              'bàn',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: _kNavy.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CounterButton(
                        icon: Icons.add_rounded,
                        onTap: () {
                          if (_batchCount < 10) setState(() => _batchCount++);
                        },
                      ),
                    ],
                  ),
                  // Quick select chips
                  const SizedBox(height: 10),
                  Row(
                    children: [1, 2, 3, 4, 5, 6, 8, 10].map((n) {
                      final isSel = _batchCount == n;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _batchCount = n),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel ? _kNavy : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSel ? _kNavy : _kNavy.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              '$n',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSel ? Colors.white : _kNavy,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Số chỗ ngồi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Số chỗ ngồi',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: _kNavy.withValues(alpha: 0.6),
                      )),
                  Row(
                    children: [
                      _CounterButton(
                        icon: Icons.remove_rounded,
                        onTap: () {
                          if (_capacity > 1) setState(() => _capacity--);
                        },
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '$_capacity',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _kNavy,
                          ),
                        ),
                      ),
                      _CounterButton(
                        icon: Icons.add_rounded,
                        onTap: () => setState(() => _capacity++),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (isEdit)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.pop(context, {'delete': true}),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _kRed),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Xoá bàn',
                            style: GoogleFonts.outfit(
                              color: _kRed,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                  if (isEdit) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_selectedZoneId.isEmpty) return;
                        // Cho phép tên trống, dùng "Bàn" làm mặc định
                        final name = _nameCtrl.text.trim().isEmpty
                            ? 'Bàn'
                            : _nameCtrl.text.trim();
                        Navigator.pop(context, {
                          'name': name,
                          'zoneId': _selectedZoneId,
                          'capacity': _capacity,
                          'shape': 'rect',
                          'batchCount': _batchCount,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kNavy,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(isEdit ? 'Lưu' : 'Thêm bàn',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KITCHEN STATUS DOT — Chấm màu trạng thái bếp cho từng món
// ─────────────────────────────────────────────────────────────────────────────
class _KitchenStatusDot extends StatelessWidget {
  final String status;
  const _KitchenStatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bg;
    String label;
    IconData icon;
    switch (status) {
      case 'da_gui':
        color = const Color(0xFF3B82F6);
        bg = const Color(0xFF3B82F6).withValues(alpha: 0.08);
        label = 'Đã gửi';
        icon = Icons.send_rounded;
        break;
      case 'dang_lam':
        color = const Color(0xFFF59E0B);
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.08);
        label = 'Đang làm';
        icon = Icons.local_fire_department_rounded;
        break;
      case 'xong':
        color = const Color(0xFF22C55E);
        bg = const Color(0xFF22C55E).withValues(alpha: 0.08);
        label = 'Bếp xong';
        icon = Icons.check_circle_rounded;
        break;
      case 'huy':
        color = const Color(0xFFEF4444);
        bg = const Color(0xFFEF4444).withValues(alpha: 0.08);
        label = 'Đã huỷ';
        icon = Icons.cancel_rounded;
        break;
      default:
        color = const Color(0xFF64748B);
        bg = const Color(0xFF64748B).withValues(alpha: 0.08);
        label = 'Chưa gửi';
        icon = Icons.schedule_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEND KITCHEN BUTTON — Mờ + Tooltip khi module Bếp chưa active
// ─────────────────────────────────────────────────────────────────────────────
class _SendKitchenButton extends ConsumerStatefulWidget {
  final int unsentCount;
  final Future<void> Function() onPressed; // ‼️ async callback
  const _SendKitchenButton({required this.unsentCount, required this.onPressed});

  @override
  ConsumerState<_SendKitchenButton> createState() => _SendKitchenButtonState();
}

class _SendKitchenButtonState extends ConsumerState<_SendKitchenButton> {
  bool _isSending = false;

  Future<void> _handlePress() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await widget.onPressed(); // await đúng cách, bắt lỗi rõ ràng
    } catch (e) {
      debugPrint('[SendKitchenButton] unhandled: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKitchenActive = ref.watch(kitchenModuleActiveProvider);
    final hasUnsent = widget.unsentCount > 0;
    final isActive = hasUnsent && isKitchenActive && !_isSending;

    final buttonChild = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: !isKitchenActive
            ? _kNavy.withValues(alpha: 0.06)
            : _isSending
                ? _kOrange.withValues(alpha: 0.6)
                : hasUnsent
                    ? _kOrange
                    : _kNavy.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: !isKitchenActive
            ? Border.all(color: _kNavy.withValues(alpha: 0.15), width: 1)
            : null,
      ),
      child: Opacity(
        opacity: isKitchenActive ? 1.0 : 0.38,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSending)
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                Icons.local_fire_department_rounded,
                color: hasUnsent && isKitchenActive
                    ? Colors.white
                    : _kNavy.withValues(alpha: 0.35),
                size: 20,
              ),
            const SizedBox(width: 6),
            Text(
              _isSending
                  ? 'Đang gửi...'
                  : hasUnsent
                      ? 'Gửi bếp (${widget.unsentCount})'
                      : 'Đã gửi hết',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: hasUnsent && isKitchenActive
                    ? Colors.white
                    : _kNavy.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );

    // Khi module Bếp chưa bật: hiện tooltip hướng dẫn, không cho tap
    if (!isKitchenActive) {
      return Tooltip(
        message: 'Cần bật Module Bếp trong Modules trước',
        preferBelow: false,
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 4),
        child: buttonChild,
      );
    }

    return GestureDetector(
      onTap: isActive ? _handlePress : null,
      child: buttonChild,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHAPE TILE — selector bàn dài / vuông / tròn
// ─────────────────────────────────────────────────────────────────────────────
class _ShapeTile extends StatelessWidget {
  final String shape;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShapeTile({
    required this.shape,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _kNavy : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _kNavy : _kNavy.withValues(alpha: 0.15),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size(36, 24),
                painter: _TableShapePainter(
                  shape: shape,
                  color: isSelected ? Colors.white : _kNavy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : _kNavy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableShapePainter extends CustomPainter {
  final String shape;
  final Color color;
  const _TableShapePainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    if (shape == 'round') {
      final r = size.height / 2 - 1;
      canvas.drawCircle(Offset(cx, cy), r, fill);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    } else if (shape == 'square') {
      final s = size.height - 2;
      final rect =
          Rect.fromCenter(center: Offset(cx, cy), width: s, height: s);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)), fill);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
    } else {
      // rect (dài)
      final rect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width - 2,
          height: size.height - 4);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)), fill);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
    }
  }

  @override
  bool shouldRepaint(_TableShapePainter old) =>
      old.shape != shape || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLE OPTIONS SHEET — Long press vào bàn
// ─────────────────────────────────────────────────────────────────────────────
class _TableOptionsSheet extends StatelessWidget {
  final BanTableModel table;
  final BanSessionModel? session;
  final VoidCallback onEdit;
  final VoidCallback? onTransfer;

  const _TableOptionsSheet({
    required this.table,
    required this.session,
    required this.onEdit,
    this.onTransfer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kNavy.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            table.label,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _kNavy,
            ),
          ),
          const SizedBox(height: 16),
          if (session == null)
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: _kNavy),
              title: Text('Sửa thông tin bàn',
                  style: GoogleFonts.outfit(color: _kNavy)),
              onTap: onEdit,
            ),
          if (session != null)
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded, color: _kNavy),
              title: Text('Chuyển bàn',
                  style: GoogleFonts.outfit(color: _kNavy)),
              onTap: () {
                Navigator.pop(context);
                onTransfer?.call();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────────
// _TRANSFER TABLE SHEET — Chọn bàn đích để chuyển
// ───────────────────────────────────────────────────────────────────────────────
class _TransferTableSheet extends ConsumerStatefulWidget {
  final String currentTableId;
  final String currentTableLabel;
  final Map<String, BanSessionModel> activeSessions;
  final Future<void> Function(String newTableId) onConfirm;

  const _TransferTableSheet({
    required this.currentTableId,
    required this.currentTableLabel,
    required this.activeSessions,
    required this.onConfirm,
  });

  @override
  ConsumerState<_TransferTableSheet> createState() =>
      _TransferTableSheetState();
}

class _TransferTableSheetState
    extends ConsumerState<_TransferTableSheet> {
  String? _selectedTableId;
  String? _selectedTableLabel;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_loading,
      child: FutureBuilder<List<BanTableModel>>(
        future: ref.read(banRepositoryProvider).getAllTables(),
        builder: (ctx, snap) {
          // Lọc ra các bàn có thể chuyển:
          // - Không phải bàn hiện tại
          // - Chưa có session đang mở
          final tables = (snap.data ?? [])
              .where((t) =>
                  t.id != widget.currentTableId &&
                  !widget.activeSessions.containsKey(t.id))
              .toList()
            ..sort((a, b) => a.label.compareTo(b.label));

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: _kCream,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: _kNavy.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            const Icon(Icons.swap_horiz_rounded,
                                color: _kAmber, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Chuyển bàn',
                                      style: GoogleFonts.outfit(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: _kNavy)),
                                  Text(
                                      'Từ: ${widget.currentTableLabel}',
                                      style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: _kNavy.withValues(alpha: 0.5))),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: _kNavy),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 20, color: Color(0xFFE8E0D4)),

                      if (snap.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        )
                      else if (tables.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(Icons.table_restaurant_rounded,
                                  size: 48, color: _kNavy),
                              const SizedBox(height: 12),
                              Text(
                                'Không có bàn trống nào',
                                style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    color: _kNavy.withValues(alpha: 0.5)),
                              ),
                              Text(
                                'Tất cả bàn khác đều đang có khách',
                                style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: _kNavy.withValues(alpha: 0.35)),
                              ),
                            ],
                          ),
                        )
                      else
                        // Grid chọn bàn
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: tables.map((t) {
                              final isSelected = _selectedTableId == t.id;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedTableId = t.id;
                                  _selectedTableLabel = t.label;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 80, height: 56,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _kAmber
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? _kAmber
                                          : const Color(0xFFDDD5C8),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: _kAmber.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: Center(
                                    child: Text(
                                      t.label,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? Colors.white
                                            : _kNavy,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // Xác nhận
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            20, 12, 20,
                            MediaQuery.of(context).padding.bottom + 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _selectedTableId != null && !_loading
                                ? _confirm
                                : null,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                : const Icon(Icons.check_rounded),
                            label: Text(
                              _selectedTableId != null
                                  ? 'Chuyển sang $_selectedTableLabel'
                                  : 'Chọn bàn đích',
                              style: GoogleFonts.outfit(
                                  fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedTableId != null
                                  ? _kAmber
                                  : const Color(0xFFCCC4B8),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Đang chuyển bàn...',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirm() async {
    if (_selectedTableId == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      await widget.onConfirm(_selectedTableId!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: _kRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAMP ROW — Hiển thị hàng tem tích lũy dạng ●●●○○○○○○○
// ─────────────────────────────────────────────────────────────────────────────
class _StampRow extends StatelessWidget {
  final int current;
  final int threshold;
  const _StampRow({required this.current, required this.threshold});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(threshold, (i) {
        final filled = i < current;
        final nextFill = i == current; // tem sẽ được cộng đơn này
        return Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: filled
                ? const Color(0xFF2E7D32)
                : nextFill
                    ? const Color(0xFF81C784)
                    : const Color(0xFF4CAF50).withAlpha(30),
            shape: BoxShape.circle,
            border: Border.all(
              color: filled || nextFill
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF4CAF50).withAlpha(80),
              width: 1.5,
            ),
          ),
          child: filled
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
              : nextFill
                  ? const Icon(Icons.add_rounded,
                      color: Colors.white, size: 12)
                  : null,
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MANAGER PIN INPUT DIALOG — Duyệt nhanh huỷ món, huỷ bàn tại chỗ
// ─────────────────────────────────────────────────────────────────────────────
class _ManagerPinInputDialog extends StatefulWidget {
  final String storeId;
  const _ManagerPinInputDialog({required this.storeId});

  @override
  State<_ManagerPinInputDialog> createState() => _ManagerPinInputDialogState();
}

class _ManagerPinInputDialogState extends State<_ManagerPinInputDialog>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _loading = false;
  
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_pin.length >= 4 || _loading) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _verify);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty || _loading) return;
    HapticFeedback.lightImpact();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _loading = true);
    try {
      final manager = await UserAuthService.verifyManagerQuickPin(widget.storeId, _pin);
      if (manager != null) {
        HapticFeedback.heavyImpact();
        if (mounted) Navigator.pop(context, manager);
      } else {
        HapticFeedback.vibrate();
        _shakeCtrl.forward(from: 0);
        setState(() {
          _pin = '';
          _error = 'Mã PIN Quản lý không đúng';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Lỗi kết nối: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const _kNavy = Color(0xFF1C2151);
    const _kOrange = Color(0xFFFF6B35);
    const _kDot = Color(0xFFE0D8CC);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.shield_rounded, color: _kOrange, size: 22),
              const SizedBox(width: 8),
              Text(
                'Quản lý phê duyệt',
                style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.w900, color: _kNavy),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'Vui lòng gọi Quản lý nhập mã PIN 4 số duyệt thao tác nhạy cảm này.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12.5, color: _kNavy.withValues(alpha: 0.55), height: 1.4),
            ),
            const SizedBox(height: 20),

            // PIN Dots with shake animation
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(
                  _shakeAnim.value * 12 * (1 - 2 * (_shakeAnim.value.floor() % 2)),
                  0),
                child: child,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _pin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: filled ? 18 : 14,
                    height: filled ? 18 : 14,
                    decoration: BoxDecoration(
                      color: filled ? _kOrange : _kDot,
                      shape: BoxShape.circle,
                      boxShadow: filled ? [
                        BoxShadow(
                          color: _kOrange.withValues(alpha: 0.4),
                          blurRadius: 8),
                      ] : [],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),

            if (_error != null)
              Text(
                _error!,
                style: GoogleFonts.outfit(
                  fontSize: 12, color: Colors.red, fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 20),

            // Visual Numpad
            Column(
              children: [
                for (final row in [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                  ['', '0', '⌫'],
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: row.map((key) {
                        if (key.isEmpty) return const SizedBox(width: 58);
                        return GestureDetector(
                          onTap: key == '⌫' ? _onDelete : () => _onDigit(key),
                          child: Container(
                            width: 58, height: 58,
                            decoration: BoxDecoration(
                              color: key == '⌫' ? Colors.transparent : const Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: key == '⌫'
                                  ? const Icon(Icons.backspace_rounded, color: _kNavy, size: 18)
                                  : Text(
                                      key,
                                      style: GoogleFonts.outfit(
                                        fontSize: 22, fontWeight: FontWeight.w700, color: _kNavy),
                                    ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Cancel button
            TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context, null),
              child: Text(
                'Huỷ bỏ',
                style: GoogleFonts.outfit(
                  color: _kNavy.withValues(alpha: 0.5), fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

