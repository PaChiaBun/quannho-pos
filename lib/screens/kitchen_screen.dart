import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/providers/app_providers.dart';
import '../core/repositories/kitchen_repository.dart';
import '../core/services/thermal_printer_service.dart';
import '../core/services/printer_settings_service.dart';
import '../core/utils/responsive.dart';
import '../modules/bill_printer/screens/bill_preview_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BRAND COLORS
// ─────────────────────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kAmber  = Color(0xFFF59E0B);
const _kBg     = Color(0xFF0D1117);
const _kCard   = Color(0xFF1A2233);
const _kCardBorder = Color(0xFF2D3748);

// Alias cho backward compat với code cũ còn dùng _TicketWithItems
typedef _TicketWithItems = TicketWithItems;

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────
final kitchenTicketsProvider = StreamProvider<List<TicketWithItems>>((ref) {
  return ref.watch(kitchenRepositoryProvider).watchActiveTickets();
});


/// Filter trạm bếp: 'all' | 'nong' | 'nuoc'
class _StationNotifier extends Notifier<String> {
  @override
  String build() => 'all';
  void setStation(String code) => state = code;
}
final stationFilterProvider =
    NotifierProvider<_StationNotifier, String>(_StationNotifier.new);

/// Stats cuối ngày — tính từ tickets hôm nay, tự refresh khi ticket thay đổi
final kitchenStatsProvider = FutureProvider<_KitchenStats>((ref) async {
  // Watch → tự động chạy lại khi có phiếu mới hoặc cập nhật
  ref.watch(kitchenTicketsProvider);
  final repo = ref.watch(kitchenRepositoryProvider);
  final tickets = await repo.watchAllTodayTickets().first;
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
  final todayAll = tickets.where((t) => t.sentAt >= startOfDay).toList();
  final todayDone = todayAll.where((t) => t.status == 'xong').toList();
  final todayCancelled = todayAll.where((t) => t.status == 'huy').toList();
  final todayActive = todayAll.where((t) => t.status == 'cho' || t.status == 'dang_lam').toList();

  final waitTimes = todayDone
      .where((t) => t.doneAt != null && t.startedAt != null)
      .map((t) => (t.doneAt! - t.sentAt) / 60000.0)
      .toList();
  final avgWait = waitTimes.isEmpty ? 0.0 : waitTimes.reduce((a, b) => a + b) / waitTimes.length;
  return _KitchenStats(
    totalDone: todayDone.length,
    totalToday: todayAll.length,
    totalCancelled: todayCancelled.length,
    totalActive: todayActive.length,
    avgWaitMin: avgWait,
    fastestMin: waitTimes.isEmpty ? 0 : waitTimes.reduce((a, b) => a < b ? a : b),
    slowestMin: waitTimes.isEmpty ? 0 : waitTimes.reduce((a, b) => a > b ? a : b),
  );
});

/// Stream thông báo khi phiếu bếp mới chuyển thành 'xong'
// ‼️ FIX #R2: Dùng kitchenTicketsProvider.stream thay Stream.value (single-emit)
// Stream.value chỉ emit 1 lần rồi close → provider không nhận realtime update
final kitchenReadyStreamProvider = StreamProvider<String>((ref) async* {
  final Set<String> knownDoneIds = {};
  // Theo dõi trực tiếp từ provider stream — tự rebuild khi kitchenTicketsProvider thay đổi
  await for (final ticketsAsync in Stream.periodic(const Duration(seconds: 3))
      .asyncMap((_) async => ref.read(kitchenTicketsProvider).value ?? [])
      .distinct()) {
    for (final tw in ticketsAsync) {
      final t = tw.ticket;
      if (t.status == 'xong' && !knownDoneIds.contains(t.id)) {
        knownDoneIds.add(t.id);
        if (t.doneAt != null) {
          final secAgo = (DateTime.now().millisecondsSinceEpoch - t.doneAt!) / 1000;
          if (secAgo < 90) yield t.tableLabel ?? 'Phíiếu bếp';
        }
      }
      // ‼️ FIX #L3b: Remove 'xong' tickets khỏi knownDoneIds khi các ticket biến mất
      // (chú ý: không remove để tránh notify lại — chỉ reset khi reopen tích cực)
    }
  }
});

/// Stream thông báo hủy/sửa món từ Ban screen — KDS hiện Cancel Notice Card
final voidNoticesProvider = StreamProvider<List<VoidNoticeModel>>((ref) async* {
  // Dùng SharedPreferences vì app dùng custom phone auth (không phải Supabase Auth)
  final prefs = await SharedPreferences.getInstance();
  final storeId = prefs.getString('auth_store_id');
  if (storeId == null || storeId.isEmpty) { yield []; return; }
  yield* watchVoidNotices(storeId);
});

/// Printer config provider
final printerConfigProvider =
    NotifierProvider<_PrinterConfigNotifier, PrinterConfig>(
  _PrinterConfigNotifier.new,
);

class _PrinterConfigNotifier extends Notifier<PrinterConfig> {
  @override
  PrinterConfig build() {
    _load();
    return const PrinterConfig(ip: '', port: 9100, enabled: false);
  }

  Future<void> _load() async {
    state = await PrinterSettingsService.load();
  }

  Future<void> update(PrinterConfig config) async {
    await PrinterSettingsService.save(config);
    state = config;
  }
}

class _KitchenStats {
  final int totalDone;
  final int totalToday;
  final int totalCancelled;
  final int totalActive;
  final double avgWaitMin;
  final double fastestMin;
  final double slowestMin;

  const _KitchenStats({
    required this.totalDone,
    required this.totalToday,
    required this.totalCancelled,
    required this.totalActive,
    required this.avgWaitMin,
    required this.fastestMin,
    required this.slowestMin,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SOUND SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class _KitchenSoundService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _muted = false;

  static bool get muted => _muted;
  static void toggleMute() => _muted = !_muted;

  static Future<void> playBell() async {
    if (_muted) return;
    try {
      // ‼️ FIX #L9: stop() trước play() — tránh âm thanh chồng giờ cao điểm
      await _player.stop();
      await _player.play(AssetSource('sounds/kitchen_bell.wav'), volume: 0.85);
    } catch (_) {
      await HapticFeedback.heavyImpact();
    }
  }

  static Future<void> playDone() async {
    if (_muted) return;
    try {
      // Double-beep ngắn gọn — phân biệt với chuông phiếu mới (1 tiếng to)
      await _player.play(AssetSource('sounds/kitchen_bell.wav'), volume: 0.6);
      await Future.delayed(const Duration(milliseconds: 350));
      await _player.play(AssetSource('sounds/kitchen_bell.wav'), volume: 0.6);
      await HapticFeedback.lightImpact();
    } catch (_) {
      await HapticFeedback.lightImpact();
    }
  }

  // Báo động 30 phút — luôn phát kể cả khi mute (khẩn cấp)
  static final AudioPlayer _alarmPlayer = AudioPlayer();
  static Future<void> playAlarm() async {
    try {
      await _alarmPlayer.play(AssetSource('sounds/kitchen_alarm.m4a'), volume: 1.0);
    } catch (_) {
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 400));
      await HapticFeedback.vibrate();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen>
    with TickerProviderStateMixin {
  final Set<String> _knownTicketIds = {};
  bool _isMuted = false;
  bool _newTicketBlink = false;
  Timer? _blinkTimer;
  late TabController _tabCtrl;

  final Set<String> _overdueAlertedIds = {};
  final Set<String> _overdueCardIds    = {};
  Timer? _overdueCheckTimer;

  // Optimistic UI state
  final Set<String> _optimisticStartedTickets = {};
  final Set<String> _optimisticDoneTickets = {};
  final Set<String> _optimisticReopenedTickets = {};
  final Set<String> _optimisticDoneItems = {};
  final Set<String> _optimisticReopenedItems = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _overdueCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkOverdueTickets(),
    );
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _overdueCheckTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _checkForNewTickets(List<_TicketWithItems> tickets) {
    final waitingIds = tickets
        .where((t) => t.ticket.status == 'cho')
        .map((t) => t.ticket.id)
        .toSet();

    final newIds = waitingIds.difference(_knownTicketIds);
    if (newIds.isNotEmpty) {
      _knownTicketIds.addAll(newIds);
      _onNewTicket();
    }
    // ‼️ FIX #L2: Prune _knownTicketIds — chỉ giữ IDs còn hiện trên màn hình
    // Ngăn memory accumulation khi chạy lâu ngày
    final currentIds = tickets.map((t) => t.ticket.id).toSet();
    _knownTicketIds.retainAll(currentIds);
  }

  void _pruneOptimisticStates(List<_TicketWithItems> tickets) {
    bool changed = false;
    for (final tw in tickets) {
      final t = tw.ticket;
      if (t.status == 'xong') {
        if (_optimisticDoneTickets.remove(t.id)) changed = true;
      } else if (t.status == 'dang_lam') {
        if (_optimisticStartedTickets.remove(t.id)) changed = true;
        if (_optimisticReopenedTickets.remove(t.id)) changed = true;
      }
      for (final item in tw.items) {
        if (item.done) {
          if (_optimisticDoneItems.remove(item.id)) changed = true;
        } else {
          if (_optimisticReopenedItems.remove(item.id)) changed = true;
        }
      }
    }
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _checkOverdueTickets() {
    final tickets = ref.read(kitchenTicketsProvider).value ?? [];
    final now = DateTime.now().millisecondsSinceEpoch;
    bool hasNewOverdue = false;
    final currentOverdueIds = <String>{};

    for (final tw in tickets) {
      // Check cả phiếu “chờ” lẫn “đang làm” quá 30 phút
      final isActive = tw.ticket.status == 'cho' || tw.ticket.status == 'dang_lam';
      if (isActive) {
        final waitMin = (now - tw.ticket.sentAt) / 60000;
        if (waitMin >= 30) {
          currentOverdueIds.add(tw.ticket.id);
          if (!_overdueAlertedIds.contains(tw.ticket.id)) {
            hasNewOverdue = true;
            _overdueAlertedIds.add(tw.ticket.id);
          }
        }
      }
    }

    if (hasNewOverdue) _KitchenSoundService.playAlarm();
    if (mounted) {
      setState(() {
        _overdueCardIds
          ..clear()
          ..addAll(currentOverdueIds);
      });
    }
  }

  void _onNewTicket() {
    _KitchenSoundService.playBell();
    setState(() => _newTicketBlink = true);
    _blinkTimer?.cancel();
    _blinkTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _newTicketBlink = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(kitchenTicketsProvider);
    final stationFilter = ref.watch(stationFilterProvider);
    final kitchenRepo = ref.read(kitchenRepositoryProvider);

    // Theo dõi để phát hiện ticket mới và đồng bộ optimistic state
    ticketsAsync.whenData((tickets) {
      _checkForNewTickets(tickets);
      _pruneOptimisticStates(tickets);
    });

    // Phân loại trạm bếp theo tên sản phẩm hoặc stationCode từ DB
    String _classifyStation(KitchenTicketItemModel item) {
      if (item.stationCode == 'nuoc') return 'nuoc';
      if (item.stationCode == 'nong') return 'nong';
      final name = item.productName.toLowerCase();
      // ‼️ FIX #L4: Mở rộng keyword list — thêm matcha, soda, kem, yogurt, cốt dừa, nước ép
      const drinkWords = [
        'cà phê', 'cafe', 'trà', 'nước', 'sữa', 'sinh tố', 'bia', 'rượu',
        'juice', 'smoothie', 'matcha', 'soda', 'kem', 'yogurt', 'cốt dừa',
        'nước ép', 'chanh', 'càm', 'cam', 'cocktail', 'mojito', 'latte',
      ];
      return drinkWords.any((w) => name.contains(w)) ? 'nuoc' : 'nong';
    }

    // Hàm lọc ticket theo trạm
    List<TicketWithItems> _filterByStation(List<TicketWithItems> all) {
      if (stationFilter == 'all') return all;
      return all
          .map((tw) {
            final visibleItems = tw.items
                .where((i) => _classifyStation(i) == stationFilter)
                .toList();
            if (visibleItems.isEmpty) return null;
            return TicketWithItems(ticket: tw.ticket, items: visibleItems);
          })
          .whereType<TicketWithItems>()
          .toList();
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(ticketsAsync),
      drawer: _StatsDrawer(),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kOrange)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi_off_rounded, size: 42, color: _kOrange),
                ),
                const SizedBox(height: 16),
                Text(
                  'Gián đoạn kết nối máy chủ Bếp',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hệ thống đang tự động kết nối lại (502 Bad Gateway). Vui lòng đợi trong giây lát...',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Thử kết nối lại ngay', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    ref.invalidate(kitchenTicketsProvider);
                  },
                ),
              ],
            ),
          ),
        ),
        data: (tickets) {
          if (tickets.isEmpty) return const _EmptyKitchenState();

          final voidNotices = ref.watch(voidNoticesProvider).value ?? [];
          final filtered = _filterByStation(tickets);

          // Apply optimistic UI state
          final optimisticFiltered = filtered.map((tw) {
            var status = tw.ticket.status;
            if (_optimisticDoneTickets.contains(tw.ticket.id)) status = 'xong';
            else if (_optimisticReopenedTickets.contains(tw.ticket.id)) status = 'dang_lam';
            else if (_optimisticStartedTickets.contains(tw.ticket.id)) status = 'dang_lam';

            final updatedTicket = tw.ticket.copyWith(status: status);
            final updatedItems = tw.items.map((i) {
              var isDone = i.done;
              if (_optimisticDoneItems.contains(i.id)) isDone = true;
              else if (_optimisticReopenedItems.contains(i.id)) isDone = false;

              if (isDone == i.done) return i;
              return KitchenTicketItemModel(
                id: i.id, ticketId: i.ticketId, productId: i.productId,
                productName: i.productName, quantity: i.quantity,
                note: i.note, freeNote: i.freeNote, kitchenNote: i.kitchenNote,
                stationCode: i.stationCode, done: isDone,
              );
            }).toList();
            return TicketWithItems(ticket: updatedTicket, items: updatedItems);
          }).toList();


          // Khi lọc theo trạm, trạng thái dựa hoàn toàn vào item.done của trạm đó
          // KHÔNG dùng ticket.status — mỗi trạm theo dõi tiến độ độc lập
          String effectiveStatus(_TicketWithItems tw) {
            if (stationFilter == 'all') return tw.ticket.status;
            // Item-level tracking: chỉ nhìn vào item.done của trạm này
            final active = tw.items.where((i) => !i.done).toList();
            if (active.isEmpty) return 'xong';          // tất cả item trạm này đã xong
            if (tw.ticket.status == 'cho') return 'cho'; // phiếu chưa bắt đầu
            return 'dang_lam';                          // còn item chưa xong
          }

          final waitTickets  = optimisticFiltered.where((t) => effectiveStatus(t) == 'cho').toList();
          final doingTickets = optimisticFiltered.where((t) => effectiveStatus(t) == 'dang_lam').toList();
          final doneTickets  = optimisticFiltered.where((t) => effectiveStatus(t) == 'xong').toList();

          // ── Tablet/Desktop: Kanban 3 cột ──────────────────────────────
          if (Responsive.isLargeScreen(context)) {
            return Column(
              children: [
                _StationFilterBar(
                  selected: stationFilter,
                  onChanged: (s) =>
                      ref.read(stationFilterProvider.notifier).setStation(s),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _KanbanColumn(
                        label: 'Chờ xử lý',
                        icon: Icons.hourglass_bottom_rounded,
                        color: _kRed,
                        bgColor: const Color(0x15EF4444),
                        tickets: waitTickets,
                        isBlinking: _newTicketBlink,
                        onAction: (tw, act) => _handleAction(
                            context, kitchenRepo, tw, act, stationFilter),
                        getStatus: effectiveStatus,
                        overdueIds: _overdueCardIds,
                      ),
                      _KanbanColumn(
                        label: 'Đang làm',
                        icon: Icons.local_fire_department_rounded,
                        color: _kAmber,
                        bgColor: const Color(0x15F59E0B),
                        tickets: doingTickets,
                        onAction: (tw, act) => _handleAction(
                            context, kitchenRepo, tw, act, stationFilter),
                        getStatus: effectiveStatus,
                        overdueIds: _overdueCardIds,
                      ),
                      _KanbanColumn(
                        label: 'Hoàn thành',
                        icon: Icons.check_circle_rounded,
                        color: _kGreen,
                        bgColor: const Color(0x1522C55E),
                        tickets: doneTickets,
                        onAction: (tw, act) => _handleAction(
                            context, kitchenRepo, tw, act, stationFilter),
                        getStatus: effectiveStatus,
                        overdueIds: _overdueCardIds,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          // ── Mobile: Tab layout ─────────────────────────────────────────
          return Column(
            children: [
              // ── Void notice banner (hủy/sửa món từ Bàn) ──
              if (voidNotices.isNotEmpty)
                _VoidNoticeBanner(notices: voidNotices),

              // ── Station filter bar ──

              _StationFilterBar(
                selected: stationFilter,
                onChanged: (s) => ref.read(stationFilterProvider.notifier).setStation(s),
              ),
              // ── Tab bar ──
              Container(
                decoration: BoxDecoration(
                  color: _kCard,
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicatorColor: _kOrange,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    _TabWithBadge(
                      icon: Icons.hourglass_bottom_rounded,
                      label: 'Chờ',
                      count: waitTickets.length,
                      color: _kRed,
                      isBlinking: _newTicketBlink && waitTickets.isNotEmpty,
                    ),
                    _TabWithBadge(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Đang làm',
                      count: doingTickets.length,
                      color: _kAmber,
                    ),
                    _TabWithBadge(
                      icon: Icons.check_circle_rounded,
                      label: 'Xong',
                      count: doneTickets.length,
                      color: _kGreen,
                    ),
                  ],
                ),
              ),
              // ── Tab views ──
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _TicketList(
                      tickets: waitTickets,
                      emptyIcon: Icons.hourglass_empty_rounded,
                      emptyLabel: 'Không có phiếu chờ',
                      onAction: (tw, act) => _handleAction(context, kitchenRepo, tw, act, stationFilter),
                      getStatus: effectiveStatus,
                      overdueIds: _overdueCardIds,
                    ),
                    _TicketList(
                      tickets: doingTickets,
                      emptyIcon: Icons.local_fire_department_rounded,
                      emptyLabel: 'Chưa có phiếu đang làm',
                      onAction: (tw, act) => _handleAction(context, kitchenRepo, tw, act, stationFilter),
                      getStatus: effectiveStatus,
                      overdueIds: _overdueCardIds,
                    ),
                    _TicketList(
                      tickets: doneTickets,
                      emptyIcon: Icons.check_circle_outline_rounded,
                      emptyLabel: 'Chưa có phiếu hoàn thành',
                      onAction: (tw, act) => _handleAction(context, kitchenRepo, tw, act, stationFilter),
                      getStatus: effectiveStatus,
                      overdueIds: _overdueCardIds,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AsyncValue<List<_TicketWithItems>> ticketsAsync) {
    return AppBar(
      backgroundColor: _kCard,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          onPressed: () => Scaffold.of(ctx).openDrawer(),
          icon: const Icon(Icons.bar_chart_rounded, color: Colors.white70),
          tooltip: 'Thống kê hôm nay',
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kOrange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '🔥 BẾP',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('Phiếu bếp',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              )),
        ],
      ),
      actions: [
        // Badge số phiếu chờ (với hiệu ứng blink khi mới)
        ticketsAsync.when(
          data: (tickets) {
            final today = DateTime.now();
            final startOfDay = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
            final waitCount = tickets.where((t) =>
                t.ticket.sentAt >= startOfDay &&
                t.ticket.status == 'cho').length;

            if (waitCount == 0) return const SizedBox.shrink();
            return _BlinkingBadge(
              count: waitCount,
              isBlinking: _newTicketBlink,
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        // Nút mute
        IconButton(
          onPressed: () {
            _KitchenSoundService.toggleMute();
            setState(() => _isMuted = _KitchenSoundService.muted);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isMuted ? '🔇 Đã tắt tiếng chuông' : '🔔 Đã bật tiếng chuông',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          },
          icon: Icon(
            _isMuted
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            color: _isMuted ? Colors.white30 : _kOrange,
          ),
          tooltip: _isMuted ? 'Bật tiếng' : 'Tắt tiếng',
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
            height: 1, color: Colors.white.withValues(alpha: 0.08)),
      ),
    );
  }

  void _setOptimisticTimeout(VoidCallback undo) {
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) setState(undo);
    });
  }

  Future<void> _handleAction(
      BuildContext context, KitchenRepository repo, TicketWithItems tw, String action,
      [String stationFilter = 'all']) async {
    final ticket = tw.ticket;

    if (action == 'start') {
      setState(() => _optimisticStartedTickets.add(ticket.id));
      _setOptimisticTimeout(() => _optimisticStartedTickets.remove(ticket.id));
      repo.startTicket(ticket.id);
      HapticFeedback.mediumImpact();
    } else if (action == 'done') {
      setState(() {
        if (stationFilter == 'all') {
          _optimisticDoneTickets.add(ticket.id);
        } else {
          for (final item in tw.items) _optimisticDoneItems.add(item.id);
        }
      });
      _setOptimisticTimeout(() {
        _optimisticDoneTickets.remove(ticket.id);
        for (final item in tw.items) _optimisticDoneItems.remove(item.id);
      });
      
      if (stationFilter == 'all') {
        repo.doneTicket(ticket.id);
      } else {
        for (final item in tw.items) {
          if (!item.done) repo.toggleItemDone(item.id, ticket.id, true);
        }
      }
      _KitchenSoundService.playDone();
    } else if (action == 'reopen') {
      setState(() {
        if (stationFilter == 'all') {
          _optimisticReopenedTickets.add(ticket.id);
        } else {
          for (final item in tw.items) _optimisticReopenedItems.add(item.id);
        }
      });
      _setOptimisticTimeout(() {
        _optimisticReopenedTickets.remove(ticket.id);
        for (final item in tw.items) _optimisticReopenedItems.remove(item.id);
      });

      if (stationFilter == 'all') {
        repo.reopenTicket(ticket.id);
      } else {
        for (final item in tw.items) {
          if (item.done) repo.toggleItemDone(item.id, ticket.id, false);
        }
      }
      HapticFeedback.mediumImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('↩ Đã mở lại phiếu ${ticket.tableLabel ?? ""}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          backgroundColor: _kAmber,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } else if (action == 'archive') {
      repo.archiveTicket(ticket.id);
      HapticFeedback.lightImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🧹 Đã dọn phiếu ${ticket.tableLabel ?? ""}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BLINKING BADGE — nhấp nháy khi có phiếu mới
// ─────────────────────────────────────────────────────────────────────────────
class _BlinkingBadge extends StatefulWidget {
  final int count;
  final bool isBlinking;
  const _BlinkingBadge({required this.count, required this.isBlinking});

  @override
  State<_BlinkingBadge> createState() => _BlinkingBadgeState();
}

class _BlinkingBadgeState extends State<_BlinkingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 1.0, end: 0.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.isBlinking) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_BlinkingBadge old) {
    super.didUpdateWidget(old);
    if (widget.isBlinking && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.isBlinking && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FadeTransition(
        opacity: _anim,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kRed,
            borderRadius: BorderRadius.circular(20),
            boxShadow: widget.isBlinking
                ? [BoxShadow(color: _kRed.withValues(alpha: 0.5), blurRadius: 12)]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_active_rounded,
                  size: 13, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                '${widget.count} chờ',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
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
// STATS DRAWER — Bước 10: Thống kê + Bước 9: Cài đặt máy in
// ─────────────────────────────────────────────────────────────────────────────
class _StatsDrawer extends ConsumerWidget {
  const _StatsDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(kitchenStatsProvider);

    return Drawer(
      backgroundColor: _kCard,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _kOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('📊', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bếp hôm nay',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Thống kê hiệu suất',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Stats ──
                  _StatSection(title: 'THỐNG KÊ HÔM NAY'),
                  const SizedBox(height: 10),
                  Builder(builder: (_) {
                    if (statsAsync.isLoading && !statsAsync.hasValue) {
                      return const Center(child: CircularProgressIndicator(color: _kOrange));
                    }
                    if (statsAsync.hasError && !statsAsync.hasValue) {
                      return Text('${statsAsync.error}', style: const TextStyle(color: Colors.white38));
                    }
                    final stats = statsAsync.value;
                    if (stats == null) return const SizedBox.shrink();

                    final effectiveTotal = stats.totalToday - stats.totalCancelled;

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.receipt_long_rounded,
                                label: 'Phiếu hôm nay',
                                value: '${stats.totalToday}',
                                color: _kOrange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.hourglass_bottom_rounded,
                                label: 'Đang xử lý',
                                value: '${stats.totalActive}',
                                color: _kAmber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.check_circle_rounded,
                                label: 'Đã hoàn thành',
                                value: '${stats.totalDone}',
                                color: _kGreen,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.cancel_rounded,
                                label: 'Huỷ bàn/bill',
                                value: '${stats.totalCancelled}',
                                color: _kRed,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _StatRow(
                          icon: Icons.timer_outlined,
                          label: 'TB thời gian chờ',
                          value: stats.totalDone == 0
                              ? '--'
                              : '${stats.avgWaitMin.toStringAsFixed(1)} phút',
                          color: _kAmber,
                        ),
                        const SizedBox(height: 6),
                        _StatRow(
                          icon: Icons.bolt_rounded,
                          label: 'Nhanh nhất',
                          value: stats.totalDone == 0
                              ? '--'
                              : '${stats.fastestMin.toStringAsFixed(1)} phút',
                          color: _kGreen,
                        ),
                        const SizedBox(height: 6),
                        _StatRow(
                          icon: Icons.hourglass_full_rounded,
                          label: 'Chậm nhất',
                          value: stats.totalDone == 0
                              ? '--'
                              : '${stats.slowestMin.toStringAsFixed(1)} phút',
                          color: _kRed,
                        ),
                        if (effectiveTotal > 0) ...
                        [
                          const SizedBox(height: 12),
                          _CompletionBar(
                            done: stats.totalDone,
                            total: effectiveTotal,
                          ),
                        ],
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _StatSection extends StatelessWidget {
  final String title;
  const _StatSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Colors.white30,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.white60,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionBar extends StatelessWidget {
  final int done;
  final int total;
  const _CompletionBar({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tỷ lệ hoàn thành',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
              Text(
                '${(pct * 100).toInt()}%',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: pct >= 0.8 ? _kGreen : pct >= 0.5 ? _kAmber : _kRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 0.8 ? _kGreen : pct >= 0.5 ? _kAmber : _kRed,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$done / $total phiếu đã hoàn thành',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.white30,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRINTER FIELD — Input cho cài đặt máy in
// ─────────────────────────────────────────────────────────────────────────────
class _PrinterField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final IconData icon;

  const _PrinterField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboardType,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(
                color: Colors.white24,
                fontSize: 14,
              ),
              prefixIcon: Icon(icon, size: 18, color: Colors.white30),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OUTLINE BUTTON — Nút viền cho cài đặt máy in
// ─────────────────────────────────────────────────────────────────────────────
class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _OutlineBtn({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.white.withValues(alpha: 0.03)
              : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDisabled
                ? Colors.white.withValues(alpha: 0.08)
                : color.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: isDisabled ? Colors.white24 : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDisabled ? Colors.white24 : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB WITH BADGE — Tab label with count badge
// ─────────────────────────────────────────────────────────────────────────────
class _TabWithBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool isBlinking;

  const _TabWithBadge({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.isBlinking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isBlinking ? color : color.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
                boxShadow: isBlinking
                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                    : [],
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KANBAN COLUMN — Một cột trong Kanban board (tablet/desktop)
// ─────────────────────────────────────────────────────────────────────────────
class _KanbanColumn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final List<_TicketWithItems> tickets;
  final bool isBlinking;
  final void Function(_TicketWithItems tw, String action) onAction;
  final String Function(_TicketWithItems tw) getStatus;
  final Set<String> overdueIds;

  const _KanbanColumn({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.tickets,
    required this.onAction,
    required this.getStatus,
    this.isBlinking = false,
    this.overdueIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            // ── Column header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                border: Border(
                  bottom: BorderSide(color: color.withValues(alpha: 0.20)),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  // Count badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isBlinking ? 0.9 : 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tickets.length}',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Ticket list ──
            Expanded(
              child: tickets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: color.withValues(alpha: 0.25), size: 36),
                          const SizedBox(height: 10),
                          Text(
                            'Trống',
                            style: GoogleFonts.outfit(
                              color: Colors.white24,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: tickets.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TicketCard(
                          tw: tickets[i],
                          effectiveStatus: getStatus(tickets[i]),
                          onAction: onAction,
                          isOverdue: overdueIds.contains(tickets[i].ticket.id),
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
// TICKET LIST — Full-width scrollable list for each tab
// ─────────────────────────────────────────────────────────────────────────────
class _TicketList extends StatelessWidget {
  final List<_TicketWithItems> tickets;
  final IconData emptyIcon;
  final String emptyLabel;
  final void Function(_TicketWithItems tw, String action) onAction;
  final String Function(_TicketWithItems tw) getStatus;
  final Set<String> overdueIds;

  const _TicketList({
    required this.tickets,
    required this.emptyIcon,
    required this.emptyLabel,
    required this.onAction,
    required this.getStatus,
    this.overdueIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 48, color: Colors.white12),
            const SizedBox(height: 12),
            Text(
              emptyLabel,
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: Colors.white24,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: tickets.length,
      itemBuilder: (_, i) => _TicketCard(
        tw: tickets[i],
        effectiveStatus: getStatus(tickets[i]),
        onAction: onAction,
        isOverdue: overdueIds.contains(tickets[i].ticket.id),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TICKET CARD — KDS-style card với urgency strip + tall items + solid buttons
// ─────────────────────────────────────────────────────────────────────────────
class _TicketCard extends ConsumerWidget {
  final _TicketWithItems tw;
  final String effectiveStatus;
  final void Function(_TicketWithItems ticket, String action) onAction;
  final bool isOverdue;

  const _TicketCard({
    required this.tw,
    required this.effectiveStatus,
    required this.onAction,
    this.isOverdue = false,
  });

  // Urgency color dựa trên thời gian chờ
  Color _urgencyColor(String status, int sentAt) {
    if (status == 'xong') return _kGreen;
    if (status == 'dang_lam') return _kAmber;
    final waitMin = (DateTime.now().millisecondsSinceEpoch - sentAt) / 60000;
    if (waitMin >= 20) return _kRed;              // ≥ 20 phút: đỏ
    if (waitMin >= 10) return const Color(0xFFF97316); // ≥ 10 phút: cam
    if (waitMin >= 5)  return _kAmber;             // ≥ 5 phút: vàng
    return _kGreen;                                // < 5 phút: xanh
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = tw.ticket;
    final items   = tw.items;
    final status  = effectiveStatus;
    final isDone  = status == 'xong';
    final isNew   = status == 'cho';
    final accent  = _urgencyColor(status, ticket.sentAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDone ? 0.04 : 0.18),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Urgency left strip (KDS pattern) ──
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: accent,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent, accent.withValues(alpha: 0.6)],
                  ),
                ),
              ),

              // ── Card content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Header ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: isDone ? 0.04 : 0.11),
                            Colors.transparent,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Zone separator + Table badge
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if ((ticket.zoneLabel ?? ticket.zoneId ?? '').isNotEmpty)
                                Text(
                                  (ticket.zoneLabel ?? ticket.zoneId ?? '').toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: accent.withValues(alpha: 0.7),
                                    letterSpacing: 1,
                                  ),
                                ),
                              Text(
                                ticket.tableLabel ?? 'Bàn',
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          // Round + Item count
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Đợt ${ticket.round}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${items.where((i) => !i.done).length} món',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Status pill + Timer
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isDone)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: isOverdue
                                        ? _kRed.withValues(alpha: 0.2)
                                        : isNew
                                            ? _kOrange.withValues(alpha: 0.15)
                                            : _kAmber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isOverdue
                                          ? _kRed
                                          : isNew
                                              ? _kOrange.withValues(alpha: 0.5)
                                              : _kAmber.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    isOverdue ? 'TRỄ 30P!' : isNew ? 'MỚI' : 'LÀM',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: isOverdue ? _kRed : isNew ? _kOrange : _kAmber,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              _WaitTimer(sentAt: ticket.sentAt, status: status),
                              const SizedBox(height: 6),
                              // ── Nút in phiếu bếp (hiện mọi trạng thái) ──
                              GestureDetector(
                                onTap: () => _printKitchenTicket(context, ref),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF97316)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFF97316)
                                            .withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.print_rounded,
                                          size: 13,
                                          color: Color(0xFFF97316)),
                                      const SizedBox(width: 3),
                                      Text('In phiếu',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFF97316),
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Items list ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      child: Column(
                        children: [...items.map((item) {
                          final isItemDone = item.done;
                          // Modifiers — JSON array từ POS (ghi vào kitchen_note)
                          List modifiers = [];
                          final _rawModNote = item.kitchenNote; // ✅ FIX: dùng kitchenNote
                          if (_rawModNote != null && _rawModNote.trim().startsWith('[')) {
                            try { modifiers = jsonDecode(_rawModNote); } catch (_) {}
                          }

                          return InkWell(
                            onTap: isDone
                                ? null
                                : () => _showItemBottomSheet(context, item),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 11),
                              decoration: BoxDecoration(
                                color: isItemDone
                                    ? _kGreen.withValues(alpha: 0.06)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isItemDone
                                      ? _kGreen.withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Status circle — tap để toggle done
                                  GestureDetector(
                                    onTap: isDone
                                        ? () async {
                                            HapticFeedback.selectionClick();
                                            await ref.read(kitchenRepositoryProvider)
                                                .toggleItemDone(item.id, ticket.id, false);
                                          }
                                        : () async {
                                            HapticFeedback.selectionClick();
                                            await ref.read(kitchenRepositoryProvider)
                                                .toggleItemDone(item.id, ticket.id, true);
                                          },
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      margin: const EdgeInsets.only(right: 10),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isItemDone ? _kGreen : Colors.transparent,
                                        border: isItemDone
                                            ? null
                                            : Border.all(color: Colors.white38, width: 2),
                                      ),
                                      child: isItemDone
                                          ? const Icon(Icons.check_rounded,
                                              size: 16, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                  // Quantity badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 3),
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      'x${item.quantity.toInt()}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                  // Name + notes
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName,
                                          style: GoogleFonts.outfit(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: isItemDone
                                                ? Colors.white38
                                                : Colors.white.withValues(alpha: 0.95),
                                          ),
                                        ),
                                         if (modifiers.isNotEmpty)
                                           Padding(
                                             padding: const EdgeInsets.only(top: 3),
                                             child: Wrap(
                                               spacing: 4,
                                               runSpacing: 3,
                                               children: modifiers.map<Widget>((m) {
                                                 final isMap = m is Map;
                                                 final isTopping = isMap && (m['type'] as String? ?? '') == 'topping';
                                                 final label = isTopping
                                                     ? '${m['name']} x${m['qty']}'
                                                     : isMap
                                                         ? (m['name'] as String? ?? '$m')
                                                         : '$m';
                                                 return Container(
                                                   padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                   decoration: BoxDecoration(
                                                     color: isTopping
                                                         ? _kOrange.withValues(alpha: 0.15)
                                                         : Colors.white.withValues(alpha: 0.08),
                                                     borderRadius: BorderRadius.circular(5),
                                                     border: isTopping
                                                         ? Border.all(color: _kOrange.withValues(alpha: 0.4))
                                                         : null,
                                                   ),
                                                   child: Text(
                                                     label,
                                                     style: GoogleFonts.outfit(
                                                       fontSize: 11,
                                                       fontWeight: isTopping ? FontWeight.w700 : FontWeight.w400,
                                                       color: isTopping ? _kOrange : Colors.white54,
                                                     ),
                                                   ),
                                                 );
                                               }).toList(),
                                             ),
                                           ),
                                        // ── Free note: "không hành", "ít cay"... ──
                                        if (item.freeNote != null &&
                                            item.freeNote!.trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _kAmber.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(7),
                                                border: Border.all(
                                                  color: _kAmber.withValues(alpha: 0.5),
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text('📌', style: TextStyle(fontSize: 11)),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      item.freeNote!.trim(),
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: _kAmber,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        // 👨‍🍳 Ghi chú nội bộ bếp (chỉ hiện nếu không phải JSON modifiers)
                                        if (item.kitchenNote != null &&
                                            item.kitchenNote!.trim().isNotEmpty &&
                                            !item.kitchenNote!.trim().startsWith('['))
                                          _NoteChip(
                                              text: item.kitchenNote!.trim(),
                                              icon: '👨‍🍳',
                                              color: const Color(0xFF818CF8)),
                                        // 📝 note: chỉ hiện nếu không phải JSON array
                                        if (modifiers.isEmpty &&
                                            item.note != null &&
                                            item.note!.isNotEmpty)
                                          _NoteChip(
                                              text: item.note!,
                                              icon: '📝',
                                              color: _kAmber),
                                      ],
                                    ),
                                  ),
                                  if (!isDone)
                                    Icon(Icons.edit_note_rounded,
                                        size: 17, color: Colors.white24),
                                ],
                              ),
                            ),
                          );

                        })],
                      ),
                    ),

                    // ── Action button ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                      child: _buildActionButton(context, status, accent, ref),
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

  void _showItemBottomSheet(
      BuildContext context, KitchenTicketItemModel item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _ItemNoteSheet(item: item),
    );
  }

  Widget _buildActionButton(BuildContext context, String status, Color accent, WidgetRef ref) {
    if (status == 'cho') {
      return GestureDetector(
        onTap: () => onAction(tw, 'start'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _kAmber,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: _kAmber.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded,
                  size: 22, color: Colors.white),
              const SizedBox(width: 8),
              Text('Bắt đầu làm',
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ],
          ),
        ),
      );
    } else if (status == 'dang_lam') {
      return GestureDetector(
        onTap: () => onAction(tw, 'done'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _kGreen,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: _kGreen.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 22, color: Colors.white),
              const SizedBox(width: 8),
              Text('Xong',
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ],
          ),
        ),
      );
    } else {
      // Trạng thái XONG: 3 nút — Mở lại + Dọn phiếu + In phiếu
      return Row(
        children: [
          // Nút mở lại (Undo Xong)
          GestureDetector(
            onTap: () => onAction(tw, 'reopen'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: _kAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kAmber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.undo_rounded, size: 15, color: _kAmber),
                  const SizedBox(width: 4),
                  Text('Mở lại',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _kAmber)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Nút dọn phiếu
          Expanded(
            child: GestureDetector(
              onTap: () => onAction(tw, 'archive'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.archive_outlined, size: 16, color: Colors.white30),
                    const SizedBox(width: 4),
                    Text('Dọn phiếu',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white30)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Nút in phiếu bếp
          GestureDetector(
            onTap: () => _printKitchenTicket(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFF97316).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.print_outlined,
                      size: 16, color: Color(0xFFF97316)),
                  const SizedBox(width: 4),
                  Text('In',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFF97316))),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  Future<void> _printKitchenTicket(BuildContext context, WidgetRef ref) async {
    final ticket  = tw.ticket;
    final sRepo   = ref.read(settingsRepositoryProvider);
    final shopName = await sRepo.shopName;
    if (!context.mounted) return;
    final bill = BillData(
      shopName:    shopName,
      orderNumber: ticket.id.substring(0, 8).toUpperCase(),
      createdAt:   DateTime.fromMillisecondsSinceEpoch(ticket.sentAt),
      tableName:   ticket.tableLabel ?? 'Mang về',
      items: tw.items.map((i) {
        // ‼️ FIX Bug #24: i.note có thể là JSON array ["modifier1","extra"]
        // Parse thành text thuần để in đúng trên phiếu bếp
        String? noteText;
        // ✅ FIX: đọc từ kitchenNote (nơi lưu modifiers JSON)
        final rawNote = i.kitchenNote ?? i.note;
        if (rawNote != null && rawNote.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawNote);
            if (decoded is List) {
              // Format từng modifier/topping entry thành text readable
              noteText = decoded.map<String>((m) {
                if (m is Map) {
                  final name = m['name'] as String? ?? '';
                  final qty  = (m['qty'] as num?)?.toInt() ?? 1;
                  final type = m['type'] as String? ?? '';
                  if (type == 'topping') {
                    return qty > 1 ? '+$name ×$qty' : '+$name';
                  }
                  // on/off modifier (e.g. "Nhiều hành")
                  return name;
                }
                return '$m';
              }).where((s) => s.isNotEmpty).join(', ');
            } else {
              noteText = rawNote;
            }
          } catch (_) {
            noteText = rawNote; // không phải JSON → dùng thẳng
          }
        }

        return BillItem(
          name: i.productName,
          qty:  i.quantity.toInt(),
          price: 0,
          note: noteText,
        );
      }).toList(),
      subtotal: 0,
      total:    0,
      type:     BillType.kitchen,
      note: ticket.orderNote,
      waiterName: ticket.orderNote,
    );
    showBillPreview(context, bill, isKitchen: true);
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// NOTE CHIP — Ghi chú nhỏ gọn
// ─────────────────────────────────────────────────────────────────────────────
class _NoteChip extends StatelessWidget {
  final String text;
  final String icon;
  final Color color;
  const _NoteChip({required this.text, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Flexible(child: Text(text,
            style: GoogleFonts.outfit(fontSize: 12, color: color.withValues(alpha: 0.9),
                fontStyle: FontStyle.italic))),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ITEM NOTE SHEET — Bếp thêm ghi chú nội bộ
// ─────────────────────────────────────────────────────────────────────────────
class _ItemNoteSheet extends StatefulWidget {
  final KitchenTicketItemModel item;
  const _ItemNoteSheet({required this.item});
  @override
  State<_ItemNoteSheet> createState() => _ItemNoteSheetState();
}

class _ItemNoteSheetState extends State<_ItemNoteSheet> {
  late TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    // Prefill từ kitchenNote (ghi chú bếp riêng) — KHÔNG dùng note (JSON modifiers của POS)
    _ctrl = TextEditingController(text: widget.item.kitchenNote ?? '');
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final note = _ctrl.text.trim();
    // Lưu vào kitchen_note — KHÔNG đụng vào `note` (JSON modifiers từ POS)
    await Supabase.instance.client
        .from('kitchen_ticket_items')
        .update({'kitchen_note': note.isEmpty ? null : note})
        .eq('id', widget.item.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('\u{1F468}\u{200D}\u{1F373}', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.item.productName,
            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white))),
        ]),
        const SizedBox(height: 4),
        Text('Ghi chú nội bộ bếp (không hiển thị cho khách)',
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: TextField(
            controller: _ctrl, autofocus: true, maxLines: 3,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Ví dụ: làm chín kỹ, không cay...',
              hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Huỷ', style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF818CF8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text('Lưu ghi chú', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white)),
          )),
        ]),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REASON DIALOG — Hỏi lý do khi dọn phiếu
// ─────────────────────────────────────────────────────────────────────────────
class _ReasonDialog extends StatefulWidget {
  final String title;
  final String hint;
  const _ReasonDialog({required this.title, required this.hint});
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  late TextEditingController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = TextEditingController(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.hint, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: _ctrl,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Lý do (không bắt buộc)...',
              hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Huỷ bỏ', style: GoogleFonts.outfit(color: Colors.white38, fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kOrange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Xác nhận', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// WAIT TIMER — Live elapsed time on ticket header
// ─────────────────────────────────────────────────────────────────────────────
class _WaitTimer extends StatefulWidget {
  final int sentAt;
  final String status;
  const _WaitTimer({required this.sentAt, required this.status});

  @override
  State<_WaitTimer> createState() => _WaitTimerState();
}

class _WaitTimerState extends State<_WaitTimer> {
  late Duration _elapsed;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _elapsed = Duration(
        milliseconds: DateTime.now().millisecondsSinceEpoch - widget.sentAt);
    // Cập nhật mỗi 5 giây — màu thay đổi kịp thời với ngưỡng 5/10/20 phút
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() {
          _elapsed = Duration(
              milliseconds:
                  DateTime.now().millisecondsSinceEpoch - widget.sentAt);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMin = _elapsed.inMinutes;

    // Màu urgency: xanh → vàng → cam → đỏ
    final Color color;
    if (widget.status == 'xong') {
      color = _kGreen;
    } else if (widget.status == 'dang_lam') {
      color = totalMin >= 20 ? _kRed : totalMin >= 10 ? const Color(0xFFF97316) : _kAmber;
    } else {
      color = totalMin >= 20 ? _kRed
           : totalMin >= 10 ? const Color(0xFFF97316)
           : totalMin >= 5  ? _kAmber
           : _kGreen;
    }

    final label = totalMin == 0
        ? '< 1 phút'
        : totalMin < 60
            ? '$totalMin phút'
            : '${totalMin ~/ 60}g ${totalMin % 60}p';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: totalMin >= 10 ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: totalMin >= 20
            ? Border.all(color: color.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded,
              size: 13,
              color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VOID NOTICE BANNER — Thông báo hủy/sửa món từ Bàn hiển thị trên KDS
// ─────────────────────────────────────────────────────────────────────────────
class _VoidNoticeBanner extends StatefulWidget {
  final List<VoidNoticeModel> notices;
  const _VoidNoticeBanner({required this.notices});
  @override
  State<_VoidNoticeBanner> createState() => _VoidNoticeBannerState();
}

class _VoidNoticeBannerState extends State<_VoidNoticeBanner> {
  final Set<String> _dismissed = {};
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _scheduleAutoDismiss();
  }

  @override
  void didUpdateWidget(_VoidNoticeBanner old) {
    super.didUpdateWidget(old);
    if (widget.notices.length != old.notices.length) _scheduleAutoDismiss();
  }

  void _scheduleAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() => _dismissed.addAll(widget.notices.map((n) => n.id)));
      }
    });
  }

  @override
  void dispose() { _autoDismissTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final visible = widget.notices.where((n) => !_dismissed.contains(n.id)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF7C1D1D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.2), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFCA5A5), size: 18),
              const SizedBox(width: 6),
              Text('THÔNG BÁO SỬA ĐƠN',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFFCA5A5),
                  fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                ),
                onPressed: () => setState(() => _dismissed.addAll(visible.map((n) => n.id))),
                child: Text('Đã hiểu ✓',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF86EFAC), fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ]),
          ),
          // Notice items
          ...visible.take(3).map((n) => Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.shortLabel,
                    style: GoogleFonts.outfit(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  Row(children: [
                    Text(n.tableLabel,
                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4)),
                      child: Text(n.reason,
                        style: GoogleFonts.outfit(color: const Color(0xFFFCA5A5), fontSize: 10)),
                    ),
                    if (n.staffName.isNotEmpty) ...[ 
                      const SizedBox(width: 6),
                      Text('— ${n.staffName}',
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
                    ],
                  ]),
                ],
              )),
            ]),
          )),
          if (visible.length > 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text('+${visible.length - 3} thông báo khác',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyKitchenState extends StatelessWidget {
  const _EmptyKitchenState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🍳', style: TextStyle(fontSize: 44)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bếp đang yên tĩnh',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chưa có phiếu bếp nào.\nCác phiếu mới sẽ hiện ngay khi nhân viên gửi bếp.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.white38,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATION FILTER BAR — Thanh lọc bếp nóng / bếp nước
// ─────────────────────────────────────────────────────────────────────────────
class _StationFilterBar extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;

  const _StationFilterBar({
    required this.selected,
    required this.onChanged,
  });

  static const _stations = <(String, IconData, String, Color)>[
    ('all',  Icons.restaurant_menu_rounded,  'Tất cả',   Color(0xFF6B7280)),
    ('nong', Icons.outdoor_grill_rounded,    'Bếp nóng', Color(0xFFFF6B35)),
    ('nuoc', Icons.local_drink_rounded,      'Bếp nước', Color(0xFF3B82F6)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: _stations.map((s) {
          final (code, icon, label, color) = s;
          final isSelected = selected == code;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(code);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? color.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.1),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                      size: 14,
                      color: isSelected ? color : Colors.white38),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? color : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
