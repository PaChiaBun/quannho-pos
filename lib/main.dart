import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';
import 'core/services/event_bridge_service.dart';
import 'core/services/supabase_service.dart';
import 'core/providers/app_providers.dart';

import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/loyalty_screen.dart';
import 'screens/report_screen.dart';
import 'screens/settings_screen.dart';



void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Khởi tạo locale cho intl (fix LocaleDataException)
  await initializeDateFormatting('vi', null);

  // Khởi tạo Supabase (background, không block app)
  SupabaseService.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: QuanNhoPOSApp(),
    ),
  );
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
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/pin': (context) => const PinLockScreen(mode: PinMode.verify),
        '/home': (context) => const MainShell(),
      },
    );
  }
}

/// Scroll mượt toàn app — tắt stretch Android, dùng physics không nảy
class _SmoothScrollBehavior extends MaterialScrollBehavior {
  const _SmoothScrollBehavior();

  // Tắt hoàn toàn hiệu ứng stretch/glow khi kéo quá đầu
  @override
  Widget buildOverscrollIndicator(
    BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  // Dùng ClampingScrollPhysics — cuốn mượt, dừng đạt ngưỡng, không nảy
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

/// Shell chính — chứa Bottom Navigation + các màn hình
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int get _currentIndex => ref.watch(navTabProvider);
  void _setTab(int i) => ref.read(navTabProvider.notifier).goTo(i);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventBridgeProvider);
    });
  }

  void switchTab(int index) => _setTab(index);

  @override
  Widget build(BuildContext context) {
    final idx = ref.watch(navTabProvider);
    return Scaffold(
      body: IndexedStack(
        index: idx,
        children: const [
          DashboardScreen(),   // 0
          PosScreen(),         // 1
          InventoryScreen(),   // 2
          FinanceScreen(),     // 3
          LoyaltyScreen(),     // 4
          ReportScreen(),      // 5
          SettingsScreen(),    // 6
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.inkFaded.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                  _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Trang chủ',
                  isActive: _currentIndex == NavTab.home,
                  onTap: () => _setTab(NavTab.home),
                ),
                _NavItem(
                  icon: Icons.shopping_cart_rounded,
                  label: 'Bán hàng',
                  isActive: _currentIndex == NavTab.pos,
                  onTap: () => _setTab(NavTab.pos),
                ),
                _NavItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'Kho',
                  isActive: _currentIndex == NavTab.inventory,
                  onTap: () => _setTab(NavTab.inventory),
                ),
                _NavItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Thu Chi',
                  isActive: _currentIndex == NavTab.finance,
                  onTap: () => _setTab(NavTab.finance),
                ),
                _NavItem(
                  icon: Icons.loyalty_rounded,
                  label: 'Điểm thưởng',
                  isActive: _currentIndex == NavTab.loyalty,
                  onTap: () => _setTab(NavTab.loyalty),
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Báo cáo',
                  isActive: _currentIndex == NavTab.report,
                  onTap: () => _setTab(NavTab.report),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Cài đặt',
                  isActive: _currentIndex == NavTab.settings,
                  onTap: () => _setTab(NavTab.settings),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Item trong Bottom Navigation — có animation + badge
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.lpmNavy.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: isActive ? AppColors.lpmNavy : AppColors.inkLight,
                ),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.lpmOrange,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                color: isActive ? AppColors.lpmNavy : AppColors.inkLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
