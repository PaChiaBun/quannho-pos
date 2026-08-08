import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/services/event_bridge_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/update_checker_service.dart';
import 'core/providers/app_providers.dart';
import 'core/services/staff_service.dart';
import 'core/services/staff_shift_realtime_controller.dart';
import 'core/services/user_auth_service.dart' show SessionData, UserAuthService;
import 'dart:async';
import 'package:printing/printing.dart';

import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/loyalty_screen.dart';
import 'screens/report_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/ban_screen.dart';
import 'screens/kitchen_screen.dart';
import 'screens/nhan_vien_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/store_picker_screen.dart';
import 'screens/chamcong_screen.dart';
import 'modules/kho_chuyen_nghiep/screens/kho_chuyen_nghiep_screen.dart';
import 'modules/qr_order/screens/qr_order_screen.dart';
import 'modules/qr_order/screens/customer_qr_order_screen.dart';
import 'modules/tinhluong/screens/tinhluong_screen.dart';
import 'modules/tinhluong/screens/my_payslip_screen.dart';
import 'modules/ops/screens/ops_screen.dart';
import 'core/providers/session_provider.dart';
import 'screens/role_manager_screen.dart' show storeRolesProvider;
import 'screens/log_viewer_screen.dart';
import 'core/utils/responsive.dart';
import 'features/ai_assistant/screens/bum_chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// METADATA CHO TAB — icon + label (thêm module mới vào đây)
// ─────────────────────────────────────────────────────────────────────────────
const _kTabMeta = [
  (icon: Icons.home_rounded, label: 'Trang chủ'), // 0
  (icon: Icons.shopping_cart_rounded, label: 'Bán hàng'), // 1
  (icon: Icons.inventory_2_rounded, label: 'Kho'), // 2
  (icon: Icons.account_balance_wallet_rounded, label: 'Thu Chi'), // 3
  (
    icon: Icons.loyalty_rounded,
    label: 'Khách Hàng - Giảm Giá - Khuyến mãi',
  ), // 4
  (icon: Icons.bar_chart_rounded, label: 'Báo cáo'), // 5
  (icon: Icons.settings_rounded, label: 'Cài đặt'), // 6
  (
    icon: Icons.table_restaurant_rounded,
    label: 'Bàn',
  ), // 7 — Module Quản lý Bàn
  (
    icon: Icons.local_fire_department_rounded,
    label: 'Bếp',
  ), // 8 — Module Phiếu bếp
  (icon: Icons.badge_rounded, label: 'Nhân viên'), // 9 — Module Nhân viên
  (
    icon: Icons.fingerprint_rounded,
    label: 'Chấm công',
  ), // 10 — Module Chấm công
  (
    icon: Icons.restaurant_menu_rounded,
    label: 'Kho CN',
  ), // 11 — Module Kho Chuyên Nghiệp
  (icon: Icons.payments_rounded, label: 'Tính lương'), // 12 — Module Tính Lương
  (icon: Icons.checklist_rounded, label: 'Vận Hành'), // 13 — Module KAY Ops
  (
    icon: Icons.history_edu_rounded,
    label: 'Nhật ký',
  ), // 14 — Module Nhật ký Hệ thống
];

// Brand colors từ Quán Nhỏ Identity Sheet
const _kNavy = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kCream = Color(0xFFFFF8F0);

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  // Pre-cache fonts to avoid browser user-gesture print blocks
  unawaited(
    PdfGoogleFonts.notoSansRegular().catchError((_) => null as dynamic),
  );
  unawaited(PdfGoogleFonts.notoSansBold().catchError((_) => null as dynamic));
  unawaited(PdfGoogleFonts.robotoRegular().catchError((_) => null as dynamic));
  unawaited(PdfGoogleFonts.robotoBold().catchError((_) => null as dynamic));

  await initializeDateFormatting('vi', null);
  await SupabaseService.initialize(); // ⚠️ PHẢI await — Supabase cần sẵn sàng trước khi dùng

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: QuanNhoPOSApp()));
}

class QuanNhoPOSApp extends StatelessWidget {
  const QuanNhoPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quán Nhỏ POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scrollBehavior: const _SmoothScrollBehavior(),
      // ── Tiếng Việt cho date picker & các widget hệ thống ──
      locale: const Locale('vi', 'VN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/auth': (context) => const AuthScreen(),
        '/store_picker': (context) => const StorePickerScreen(),
        '/home': (context) => const MainShell(),
        '/qr_order': (context) => const QrOrderScreen(),
      },
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');
        if (uri.path == '/qr_order' || uri.path.endsWith('/qr_order')) {
          final code = uri.queryParameters['code'];
          if (code != null && code.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => CustomerQrOrderScreen(channelCode: code),
            );
          }
          return MaterialPageRoute(builder: (_) => const QrOrderScreen());
        }
        return null;
      },
    );
  }
}

/// Scroll mượt toàn app
class _SmoothScrollBehavior extends MaterialScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ✅ FIX #4 — Cache GoogleFonts TextStyle thành static const
// Tránh tạo TextStyle object mới 28 lần mỗi khi sidebar rebuild
// ─────────────────────────────────────────────────────────────────────────────
final _kSidebarActiveStyle = GoogleFonts.outfit(
  fontSize: 9,
  fontWeight: FontWeight.w700,
  color: _kNavy,
);
final _kSidebarInactiveStyle = GoogleFonts.outfit(
  fontSize: 9,
  fontWeight: FontWeight.w400,
  color: const Color(0xFF9E9E9E),
);
final _kSidebarActiveLgStyle = GoogleFonts.outfit(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: _kNavy,
);
final _kSidebarInactiveLgStyle = GoogleFonts.outfit(
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: const Color(0xFF9E9E9E),
);
final _kSidebarFooterStyle = GoogleFonts.outfit(
  fontSize: 10,
  fontWeight: FontWeight.w600,
  color: const Color(0xFF9E9E9E),
);

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SHELL — 4 slot tuỳ chỉnh + Bum AI ở giữa
// ─────────────────────────────────────────────────────────────────────────────
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int get _currentIndex => ref.watch(navTabProvider);

  // ── Tab-switch animation — lightweight fade only ──
  late final AnimationController _tabFadeCtrl;
  late final Animation<double> _tabFade;

  // ── Children của IndexedStack — tạo 1 lần, không bao giờ recreate ──
  late final List<Widget> _bodyChildren;
  void _setTab(int i) {
    if (i == ref.read(navTabProvider)) return;
    ref.read(navTabProvider.notifier).goTo(i);
    _tabFadeCtrl.forward(from: 0.35); // quick fade-in chỉ từ 35%→100%
  }

  RealtimeChannel? _roleChannel;
  late final StaffShiftRealtimeController _shiftController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _shiftController = StaffShiftRealtimeController(
      onInvalidateOpenShift: () {
        if (mounted) ref.invalidate(openShiftCCProvider);
      },
    );

    // Lightweight fade controller — 150ms thay vì 240ms
    _tabFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 1.0,
    );
    _tabFade = CurvedAnimation(parent: _tabFadeCtrl, curve: Curves.easeOut);

    // Cache children một lần — IndexedStack sử dụng lại, không tạo mới
    _bodyChildren = List.generate(
      _screens.length,
      (i) => RepaintBoundary(child: _screens[i]),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventBridgeProvider);
      _startRoleWatcher();
      _startShiftWatcher();
      _validateMembershipOnResume();
      // Kiểm tra bản cập nhật sau 2 giây — cho UI render xong trước
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) UpdateCheckerService.checkForUpdate(context);
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _validateMembershipOnResume();
    }
  }

  bool _isNavigatingAway = false;

  Future<void> _validateMembershipOnResume() async {
    final session = ref.read(sessionProvider);
    if (session == null ||
        session.isOwner ||
        session.storeId == null ||
        session.storeId!.isEmpty) {
      return;
    }

    final val = await UserAuthService.validateActiveMembership(
      userId: session.userId,
      storeId: session.storeId!,
    );

    if (!mounted) return;

    if (!val.isActive && !val.isOffline) {
      debugPrint(
        '[MainShell] Membership revoked on resume -> clearing store context',
      );
      await ref.read(sessionProvider.notifier).clearStoreContext();
      if (!mounted || _isNavigatingAway) return;
      _isNavigatingAway = true;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/store_picker', (route) => false);
    } else if (val.isActive) {
      // Sau khi validate thành công, mới refresh openShiftCCProvider
      ref.invalidate(openShiftCCProvider);
      _shiftController.manualReconnect();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  /// Lắng nghe thay đổi ca làm việc trong staff_shifts — chạy suốt vòng đời app
  void _startShiftWatcher() {
    final session = ref.read(sessionProvider);
    if (session == null ||
        session.storeId == null ||
        session.storeId!.isEmpty ||
        session.userId.isEmpty) {
      _shiftController.stop();
      return;
    }

    _shiftController.start(storeId: session.storeId!, userId: session.userId);
  }

  /// Lắng nghe thay đổi role trong store_members — chạy suốt vòng đời app
  void _startRoleWatcher() {
    // Huỷ channel cũ trước khi subscribe lại
    _roleChannel?.unsubscribe();
    _roleChannel = null;

    final session = ref.read(sessionProvider);
    if (session == null || session.isOwner) return;
    final userId = session.userId;
    final storeId = session.storeId ?? '';
    if (userId.isEmpty || storeId.isEmpty) {
      // Retry sau 2 giây nếu chưa có store
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _startRoleWatcher();
      });
      return;
    }

    try {
      _roleChannel = Supabase.instance.client
          .channel('role_watch_${userId}_$storeId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'store_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final newRole = payload.newRecord['role'] as String?;
              if (newRole == null || !mounted) return;
              final cur = ref.read(sessionProvider);
              if (cur == null || cur.role == newRole) return;
              debugPrint('[RoleWatcher] role changed: ${cur.role} → $newRole');
              // Cập nhật session → MainShell tự rebuild tabs ngay lập tức
              ref
                  .read(sessionProvider.notifier)
                  .setSession(
                    SessionData(
                      userId: cur.userId,
                      phone: cur.phone,
                      displayName: cur.displayName,
                      storeId: cur.storeId,
                      storeName: cur.storeName,
                      storeCode: cur.storeCode,
                      role: newRole,
                      isOwner: cur.isOwner,
                    ),
                  );
              // Hiện banner thông báo
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🔄 Vai trò của bạn đã đổi sang: $newRole'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[RoleWatcher] subscribe error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabFadeCtrl.dispose();
    _roleChannel?.unsubscribe();
    _shiftController.dispose();
    super.dispose();
  }

  void _showBumSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const BumChatScreen(),
    );
  }

  void _showSlotPicker(int slotIndex) {
    HapticFeedback.mediumImpact();
    final session = ref.read(sessionProvider);
    final storeRoles = ref.read(storeRolesProvider).value ?? [];
    final allowed = _navBarTabsForRole(
      session?.role,
      storeRoles,
      session?.isOwner ?? false,
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _SlotPickerSheet(slotIndex: slotIndex, allowedTabs: allowed),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SessionData?>(sessionProvider, (previous, next) {
      if (previous?.storeId != next?.storeId ||
          previous?.userId != next?.userId) {
        _startRoleWatcher();
        _startShiftWatcher();
      }
      if (previous?.storeId != null &&
          next?.storeId == null &&
          !_isNavigatingAway) {
        _isNavigatingAway = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/store_picker', (route) => false);
          }
        });
      }
    });

    final idx = ref.watch(navTabProvider);
    final slotsAsync = ref.watch(navSlotsProvider);
    // ✅ .select() — chỉ rebuild khi role hoặc isOwner thay đổi
    // Không rebuild khi storeName, token, hay các field khác update
    final role = ref.watch(sessionProvider.select((s) => s?.role));
    final isOwner = ref.watch(
      sessionProvider.select((s) => s?.isOwner ?? false),
    );
    final session = ref.read(sessionProvider); // read full object chỉ khi cần
    final rawSlots = slotsAsync.value ?? [0, 1, 2, 6];

    // Tabs trên nav bar theo role (tính từ store_roles modules)
    // ✅ FIX #3: đọc .value trực tiếp — storeRolesProvider đã keepAlive ở định nghĩa
    final storeRoles = ref.watch(storeRolesProvider).value ?? [];
    final navBarTabs = _navBarTabsForRole(role, storeRoles, isOwner);

    // ⭐ Vận Hành (tab 13) luôn accessible cho mọi nhân viên — phải add TRƯỚC khi filter slots
    navBarTabs.add(13);

    // ⭐ Với nhân viên: Tạo displaySlots trực tiếp từ navBarTabs (đã bao gồm 13)
    final isStaff =
        !(session?.isOwner ?? false) &&
        session?.role != 'owner' &&
        session?.role != 'manager';
    final List<int> displaySlots;

    if (isStaff) {
      final staffAllowed =
          navBarTabs.where((t) => t != 0 && t != 6 && t != 13).toList()..sort();
      final mid = staffAllowed.isNotEmpty ? staffAllowed.first : 6;
      displaySlots = [0, 6, mid, 13];
    } else {
      final slots = rawSlots.where((t) => navBarTabs.contains(t)).toList();
      displaySlots = _padSlots(slots, navBarTabs);
    }

    // ✅ FIX #2: bỏ watch storeRolesProvider lần 2 — dùng lại giá trị storeRoles đã watch ở trên
    // (storeRoles.isNotEmpty đồng nghĩa provider đã load xong)
    if (storeRoles.isNotEmpty &&
        !navBarTabs.contains(idx) &&
        displaySlots.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(navTabProvider.notifier).goTo(displaySlots[0]);
      });
    }

    // ── Tablet/Desktop: Navigation Rail bên trái ─────────────
    if (Responsive.isLargeScreen(context)) {
      return _buildLargeLayout(context, idx, navBarTabs);
    }

    // ── Mobile: Bottom Bar + Bum FAB ──────────────────────────────
    return Scaffold(
      body: _buildBody(idx),
      floatingActionButton: _BumButton(onTap: _showBumSheet),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomBar(displaySlots),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BODY — IndexedStack giữ state + chỉ animate screen đang active
  // ✅ FIX #1: bỏ List.generate + AnimatedOpacity/Slide cho 13 screens inactive
  //    → tiết kiệm 26 widget nodes + implicit animation reconcile mỗi tap
  // ─────────────────────────────────────────────────────────────
  static const _screens = [
    DashboardScreen(), // 0
    PosScreen(), // 1
    InventoryScreen(), // 2
    FinanceScreen(), // 3
    LoyaltyScreen(), // 4
    ReportScreen(), // 5
    SettingsScreen(), // 6
    BanScreen(), // 7
    KitchenScreen(), // 8
    NhanVienScreen(), // 9
    ChamCongScreen(), // 10
    KhoProScreen(), // 11
    _TinhLuongRouteScreen(), // 12
    OpsScreen(), // 13
    const LogViewerScreen(), // 14
  ];

  Widget _buildBody(int idx) {
    // ── CLOCK-IN GUARD CHO NHÂN VIÊN ──
    final session = ref.watch(sessionProvider);
    final isStaff =
        session != null &&
        !(session.isOwner) &&
        session.role != 'owner' &&
        session.role != 'manager' &&
        session.role.toLowerCase() != 'quản lý';

    if (isStaff && idx != 0 && idx != 10 && idx != 6) {
      final openShiftAsync = ref.watch(openShiftCCProvider);
      return openShiftAsync.when(
        data: (open) {
          if (open == null) {
            return _buildClockInRequiredScreen();
          }
          return FadeTransition(
            opacity: _tabFade,
            child: IndexedStack(index: idx, children: _bodyChildren),
          );
        },
        loading: () => _buildClockInCheckingScreen(),
        error: (err, _) => _buildClockInErrorScreen(err),
      );
    }

    // ✅ PERF: chỉ FadeTransition, bỏ SlideTransition
    // → giảm 50% repaint cost vì không cần transform matrix
    return FadeTransition(
      opacity: _tabFade,
      child: IndexedStack(index: idx, children: _bodyChildren),
    );
  }

  Widget _buildClockInRequiredScreen() {
    return Container(
      color: const Color(0xFFFAF7F2), // _kBg
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_clock_rounded,
                color: Color(0xFFEA580C),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'YÊU CẦU CHẤM CÔNG',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E1C5E), // _kNavy
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tính năng này tạm khóa vì bạn chưa vào ca làm việc.\nVui lòng hoàn thành chấm công để mở khóa các module của quán.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF9E9085), // _kMuted
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1C5E), // _kNavy
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  ref
                      .read(navTabProvider.notifier)
                      .goTo(10); // Chuyển sang tab Chấm công (ChamCongScreen)
                },
                icon: const Icon(Icons.fingerprint_rounded, size: 20),
                label: Text(
                  'Đi chấm công ngay',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockInCheckingScreen() {
    return Container(
      color: const Color(0xFFFAF7F2),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF1E1C5E)),
            const SizedBox(height: 16),
            Text(
              'Đang kiểm tra ca làm việc...',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF9E9085),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockInErrorScreen(Object error) {
    return Container(
      color: const Color(0xFFFAF7F2),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sync_problem_rounded,
                color: Color(0xFFDC2626),
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'LỖI ĐỒNG BỘ TRẠNG THÁI CA',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E1C5E),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Không thể kết nối CSDL để kiểm tra ca làm việc.\nVui lòng kiểm tra kết nối mạng và bấm Thử lại.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF9E9085),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1C5E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                ref.invalidate(openShiftCCProvider);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Thử lại',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LARGE LAYOUT — Navigation Rail + Content
  // ─────────────────────────────────────────────────────────────
  Widget _buildLargeLayout(
    BuildContext context,
    int idx,
    Set<int> allowedTabs,
  ) {
    final sortedTabs = allowedTabs.toList()..sort();
    final isDesktop = Responsive.isDesktop(context);
    // ✅ FIX #5: bỏ ref.watch(sessionProvider) thừa — build() đã watch rồi
    // Dùng ref.read để lấy giá trị hiện tại mà không tạo thêm subscription
    final storeName = ref.read(sessionProvider)?.storeName ?? '';

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // ── Custom Sidebar (scrollable) ───────────────────────────────────
            _buildCustomSidebar(sortedTabs, idx, storeName, isDesktop),
            // ── Divider mảnh ────────────────────────────────────
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: Color(0xFFEEEBE6),
            ),
            // ── Nội dung chính ──────────────────────────────────
            Expanded(child: _buildBody(idx)),
          ],
        ),
      ),
    );
  }

  /// Custom sidebar thay thế NavigationRail — scrollable, không bị overflow
  Widget _buildCustomSidebar(
    List<int> sortedTabs,
    int currentIdx,
    String storeName,
    bool isDesktop,
  ) {
    final sidebarWidth = isDesktop ? 180.0 : 88.0;
    return Container(
      width: sidebarWidth,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── AI Logo + Name ─────────────────────────────────
          GestureDetector(
            onTap: _showBumSheet,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                0,
                isDesktop ? 20 : 16,
                0,
                isDesktop ? 16 : 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kNavy.withValues(alpha: 0.04), Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  // ── Logo Bum AI — to hơn, glow ring ──
                  Container(
                    width: isDesktop ? 72 : 64,
                    height: isDesktop ? 72 : 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E1C5E), Color(0xFFE85D20)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _kNavy.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: _kOrange.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/branding/logo_head.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isDesktop ? 10 : 6),
                  // ── Tên AI ──
                  Text(
                    'Bum AI',
                    style: GoogleFonts.outfit(
                      fontSize: isDesktop ? 14 : 11,
                      fontWeight: FontWeight.w800,
                      color: _kNavy,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (isDesktop)
                    Text(
                      'Trợ lý thông minh',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9E9085),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // ── Divider gradient ────────────────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFE0D8CC).withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // ── Nav items (scrollable) ─────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              itemCount: sortedTabs.length,
              itemBuilder: (context, i) {
                final tabIdx = sortedTabs[i];
                final meta = _kTabMeta[tabIdx];
                final isActive = currentIdx == tabIdx;
                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _setTab(tabIdx);
                    },
                    borderRadius: BorderRadius.circular(12),
                    splashColor: _kNavy.withValues(alpha: 0.08),
                    highlightColor: _kNavy.withValues(alpha: 0.04),
                    // ✅ PERF: plain Container — no implicit animation
                    child: Container(
                      height: isDesktop ? 48 : 64,
                      padding: isDesktop
                          ? const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            )
                          : const EdgeInsets.symmetric(vertical: 4),
                      margin: const EdgeInsets.symmetric(vertical: 1),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _kNavy.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: isDesktop
                          ? Row(
                              children: [
                                // ── Left accent pill ──
                                if (isActive)
                                  Container(
                                    width: 3,
                                    height: 24,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: _kOrange,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  )
                                else
                                  const SizedBox(width: 13),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? _kNavy.withValues(alpha: 0.10)
                                        : const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    meta.icon,
                                    size: 18,
                                    color: isActive
                                        ? _kNavy
                                        : Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    meta.label,
                                    style: isActive
                                        ? _kSidebarActiveLgStyle
                                        : _kSidebarInactiveLgStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // ── Active dot ──
                                if (isActive)
                                  Container(
                                    height: 3,
                                    width: 22,
                                    margin: const EdgeInsets.only(bottom: 3),
                                    decoration: BoxDecoration(
                                      color: _kOrange,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  )
                                else
                                  const SizedBox(height: 6),
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? _kNavy.withValues(alpha: 0.10)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    meta.icon,
                                    size: 20,
                                    color: isActive
                                        ? _kNavy
                                        : Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  meta.label,
                                  style: isActive
                                      ? _kSidebarActiveStyle
                                      : _kSidebarInactiveStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
          // ── Footer ─────────────────────────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFE0D8CC).withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0EA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
                if (isDesktop && storeName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      storeName,
                      style: _kSidebarFooterStyle,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Các tab hiển thị trên Bottom Nav Bar — tính từ store_roles.modules hoặc phân quyền nhân viên
  Set<int> _navBarTabsForRole(
    String? role,
    List<dynamic> storeRoles,
    bool isOwner,
  ) {
    final canonical = StaffService.canonicalRole(role ?? '');
    if (isOwner || canonical == 'owner' || canonical == 'manager') {
      return {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14};
    }

    // Map module ID → tab index
    const moduleToTab = {
      'pos': 1,
      'kho': 2,
      'finance': 3,
      'loyalty': 4,
      'report': 5,
      'ban': 7,
      'table': 7,
      'kitchen': 8,
      'staff': 9,
      'chamcong': 10,
      'kho_pro': 11,
      'tinhluong': 12,
      'kay_ops': 13,
      'log_viewer': 14,
    };

    // Luôn có tab Home + Cài đặt
    final tabs = <int>{0, 6};

    // Tìm role trong store_roles (khớp trực tiếp tên hoặc qua canonicalRole)
    debugPrint(
      '[NavTabs] role=$role storeRoles=${storeRoles.map((r) => r.name).toList()} isOwner=$isOwner',
    );
    if (role != null && storeRoles.isNotEmpty) {
      for (final r in storeRoles) {
        final rName = r.name.toString();
        if (rName == role || StaffService.canonicalRole(rName) == canonical) {
          for (final mod in r.modules) {
            final tab = moduleToTab[mod.toString()];
            if (tab != null) tabs.add(tab);
          }
          tabs.add(13); // ⭐ Vận Hành — mọi nhân viên đều có quyền truy cập
          debugPrint('[NavTabs] matched role=$role ($rName) → tabs=$tabs');
          return tabs;
        }
      }
      debugPrint('[NavTabs] no match for role=$role in storeRoles');
    }

    // Fallback: role cũ hardcoded
    switch (canonical) {
      case 'kitchen':
        return {0, 8, 6, 1, 13};
      case 'cashier':
        return {0, 1, 7, 6, 13, 14};
      case 'waiter':
        return {0, 7, 8, 6, 13};
      case 'stock':
        return {0, 2, 1, 6, 13};
      default:
        return tabs.isEmpty ? {0, 1, 2, 6, 13} : (tabs..add(13));
    }
  }

  /// Đảm bảo luôn có đủ 4 slot cho bottom bar (padding với các allowed tabs khác nhau)
  List<int> _padSlots(List<int> slots, Set<int> allowed) {
    final result = List<int>.from(slots);
    // Thêm các tab được phép chưa có trong result
    for (final t in allowed.toList()..sort()) {
      if (result.length >= 4) break;
      if (!result.contains(t)) result.add(t);
    }
    // Vẫn thiếu? dùng tab đầu tiên lặp lại
    while (result.length < 4) result.add(result.first);
    return result.take(4).toList();
  }

  Widget _buildBottomBar(List<int> slots) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Bottom App Bar chính (Navy premium + arch) ───────────────
        BottomAppBar(
          shape: const _ArchNotchedShape(),
          notchMargin: 6,
          color: _kNavy,
          elevation: 0,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                Expanded(
                  child: _NavSlotItem(
                    tabIndex: slots[0],
                    isActive: _currentIndex == slots[0],
                    onTap: () => _setTab(slots[0]),
                    onLongPress: () => _showSlotPicker(0),
                  ),
                ),
                Expanded(
                  child: _NavSlotItem(
                    tabIndex: slots[1],
                    isActive: _currentIndex == slots[1],
                    onTap: () => _setTab(slots[1]),
                    onLongPress: () => _showSlotPicker(1),
                  ),
                ),
                const SizedBox(width: 96),
                Expanded(
                  child: _NavSlotItem(
                    tabIndex: slots[2],
                    isActive: _currentIndex == slots[2],
                    onTap: () => _setTab(slots[2]),
                    onLongPress: () => _showSlotPicker(2),
                  ),
                ),
                Expanded(
                  child: _NavSlotItem(
                    tabIndex: slots[3],
                    isActive: _currentIndex == slots[3],
                    onTap: () => _setTab(slots[3]),
                    onLongPress: () => _showSlotPicker(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
} // end _MainShellState

// ─────────────────────────────────────────────────────────────────────────────
// NAV SLOT ITEM — ô tuỳ chỉnh, scale animation khi tap
// ─────────────────────────────────────────────────────────────────────────────
class _NavSlotItem extends StatefulWidget {
  final int tabIndex;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NavSlotItem({
    required this.tabIndex,
    required this.isActive,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_NavSlotItem> createState() => _NavSlotItemState();
}

class _NavSlotItemState extends State<_NavSlotItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.80,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _pressCtrl.forward();
  void _onTapUp(TapUpDetails _) => _pressCtrl.reverse();
  void _onTapCancel() => _pressCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    final meta = _kTabMeta[widget.tabIndex];

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onLongPress();
      },
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 72,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icon pill ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: widget.isActive ? _kOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    meta.icon,
                    key: ValueKey('icon_${widget.tabIndex}_${widget.isActive}'),
                    size: 22,
                    color: widget.isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.70),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // ── Label ──
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: widget.isActive
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: widget.isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.65),
                ),
                child: Text(
                  meta.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
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
// ARCH NOTCHED SHAPE — Vòm xanh ôm mascot Bum giữa thanh nav
// ─────────────────────────────────────────────────────────────────────────────
class _ArchNotchedShape extends NotchedShape {
  const _ArchNotchedShape();

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    if (guest == null || !guest.overlaps(host)) {
      return Path()..addRRect(
        RRect.fromRectAndCorners(
          host,
          topLeft: const Radius.circular(22),
          topRight: const Radius.circular(22),
        ),
      );
    }
    final cx = guest.center.dx;
    final archR = guest.width / 2 + 12.0;
    final shoulder = 20.0;
    final peak = host.top - 16.0; // vòm nhô lên 16px

    return Path()
      ..moveTo(host.left, host.bottom)
      ..lineTo(host.left, host.top + 22)
      ..quadraticBezierTo(host.left, host.top, host.left + 22, host.top)
      ..lineTo(cx - archR - shoulder, host.top)
      ..cubicTo(cx - archR, host.top, cx - archR, peak, cx, peak)
      ..cubicTo(
        cx + archR,
        peak,
        cx + archR,
        host.top,
        cx + archR + shoulder,
        host.top,
      )
      ..lineTo(host.right - 22, host.top)
      ..quadraticBezierTo(host.right, host.top, host.right, host.top + 22)
      ..lineTo(host.right, host.bottom)
      ..close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUM BUTTON — Logo chú voi Bum, animation thở nhẹ nhàng
// ─────────────────────────────────────────────────────────────────────────────
class _BumButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BumButton({required this.onTap});

  @override
  State<_BumButton> createState() => _BumButtonState();
}

class _BumButtonState extends State<_BumButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000), // thở chậm hơn
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _glowAnim = Tween<double>(
      begin: 0.25,
      end: 0.50,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: _kOrange, width: 3.0),
            boxShadow: [
              BoxShadow(
                color: _kOrange.withValues(alpha: 0.35),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/branding/logo_head.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kNavy.withValues(alpha: _glowAnim.value),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: _kOrange.withValues(alpha: _glowAnim.value * 0.4),
                  blurRadius: 28,
                  spreadRadius: -2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Màu accent cho từng tab (dùng trong SlotPicker)
// ─────────────────────────────────────────────────────────────────────────────
const _kTabColors = [
  Color(0xFF1C2151),
  Color(0xFFE07B39),
  Color(0xFF00796B),
  Color(0xFF2E7D32),
  Color(0xFFAD1457),
  Color(0xFF6A1B9A),
  Color(0xFF455A64),
  Color(0xFFF57F17),
  Color(0xFFC62828),
  Color(0xFF1565C0),
  Color(0xFF283593),
  Color(0xFF00838F),
  Color(0xFF558B2F),
  Color(0xFF4527A0),
];

// ─────────────────────────────────────────────────────────────────────────────
// SLOT PICKER SHEET — Grid 3 cột + stagger animation
// ─────────────────────────────────────────────────────────────────────────────
class _SlotPickerSheet extends ConsumerStatefulWidget {
  final int slotIndex;
  final Set<int> allowedTabs;
  const _SlotPickerSheet({required this.slotIndex, required this.allowedTabs});

  @override
  ConsumerState<_SlotPickerSheet> createState() => _SlotPickerSheetState();
}

class _SlotPickerSheetState extends ConsumerState<_SlotPickerSheet>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();
    final count = _kTabMeta.length;
    _controllers = List.generate(
      count,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      ),
    );
    _fadeAnims = _controllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    _slideAnims = _controllers
        .map(
          (c) => Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)),
        )
        .toList();

    // Staggered entrance
    for (var i = 0; i < count; i++) {
      Future.delayed(Duration(milliseconds: 40 + i * 35), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(navSlotsProvider).value ?? [0, 1, 2, 6];
    final allowedList = List.generate(
      _kTabMeta.length,
      (i) => i,
    ).where((i) => widget.allowedTabs.contains(i)).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      decoration: BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _kNavy.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _kNavy,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Ô ${widget.slotIndex + 1}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Chọn mục hiển thị',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _kNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Giữ lâu vào ô để thay đổi',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: _kNavy.withValues(alpha: 0.40),
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: _kNavy.withValues(alpha: 0.07)),
          const SizedBox(height: 12),
          // Grid
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.9,
                ),
                itemCount: allowedList.length,
                itemBuilder: (ctx, idx) {
                  final tabIdx = allowedList[idx];
                  final meta = _kTabMeta[tabIdx];
                  final isSelected = slots[widget.slotIndex] == tabIdx;
                  final usedElsewhere = slots.indexed.any(
                    (e) => e.$1 != widget.slotIndex && e.$2 == tabIdx,
                  );
                  final color = _kTabColors.length > tabIdx
                      ? _kTabColors[tabIdx]
                      : _kNavy;

                  return FadeTransition(
                    opacity: _fadeAnims[tabIdx],
                    child: SlideTransition(
                      position: _slideAnims[tabIdx],
                      child: _SlotTabTile(
                        meta: meta,
                        color: color,
                        isSelected: isSelected,
                        isDisabled: usedElsewhere,
                        onTap: usedElsewhere
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                ref
                                    .read(navSlotsProvider.notifier)
                                    .updateSlot(widget.slotIndex, tabIdx);
                                Navigator.pop(context);
                              },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SlotTabTile extends StatefulWidget {
  final ({IconData icon, String label}) meta;
  final Color color;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;
  const _SlotTabTile({
    required this.meta,
    required this.color,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  State<_SlotTabTile> createState() => _SlotTabTileState();
}

class _SlotTabTileState extends State<_SlotTabTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.93,
    ).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.isDisabled ? 0.30 : 1.0;
    return GestureDetector(
      onTapDown: (_) => widget.isDisabled ? null : _scaleCtrl.forward(),
      onTapUp: (_) => _scaleCtrl.reverse(),
      onTapCancel: () => _scaleCtrl.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.color.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isSelected ? widget.color : Colors.transparent,
              width: widget.isSelected ? 2 : 0,
            ),
            boxShadow: widget.isSelected
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Opacity(
            opacity: opacity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isSelected
                        ? widget.color
                        : widget.color.withValues(alpha: 0.10),
                  ),
                  child: Icon(
                    widget.meta.icon,
                    size: 22,
                    color: widget.isSelected ? Colors.white : widget.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.meta.label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: widget.isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: widget.isSelected
                        ? widget.color
                        : _kNavy.withValues(alpha: 0.75),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.isSelected) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 20,
                    height: 3,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Owner/Manager → TinhLuongScreen (quản lý bảng lương)
// Staff → MyPayslipScreen (xem phiếu của chính mình)

class _TinhLuongRouteScreen extends ConsumerWidget {
  const _TinhLuongRouteScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    // Session chưa load xong → show loading
    if (session == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF8F0),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1C2151)),
        ),
      );
    }

    // Owner hoặc các role quản lý → bảng quản lý lương
    final canonical = StaffService.canonicalRole(session.role);
    final isManager =
        session.isOwner ||
        canonical == 'owner' ||
        canonical == 'manager' ||
        canonical == 'accountant' ||
        canonical == 'ketoan';

    return isManager ? const TinhLuongScreen() : const MyPayslipScreen();
  }
}
