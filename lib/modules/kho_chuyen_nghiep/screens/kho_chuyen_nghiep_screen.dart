import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/kho_theme.dart';
import '../../../core/providers/app_providers.dart'; // navTabProvider
import 'kho_chuyen_nghiep_dashboard_screen.dart';
import 'recipe_list_screen.dart';
import 'ingredient_list_screen.dart';
import 'production_order_screen.dart';
import 'kho_chuyen_nghiep_report_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KHO HÀNG CHUYÊN NGHIỆP — Entry Screen
// Cấu trúc tab mirror với Kho Hàng thường, thêm tính năng Pro
// ─────────────────────────────────────────────────────────────────────────────

class KhoProScreen extends ConsumerStatefulWidget {
  const KhoProScreen({super.key});

  @override
  ConsumerState<KhoProScreen> createState() => _KhoProScreenState();
}

class _KhoProScreenState extends ConsumerState<KhoProScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _currentTab = 0;

  static const _tabs = [
    (icon: Icons.dashboard_rounded,      label: 'Tổng quan'),
    (icon: Icons.egg_alt_rounded,        label: 'Nguyên liệu'),
    (icon: Icons.menu_book_rounded,      label: 'Công thức'),
    (icon: Icons.precision_manufacturing_rounded, label: 'Sản xuất'),
    (icon: Icons.bar_chart_rounded,      label: 'Báo cáo'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      setState(() => _currentTab = _tabCtrl.index);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainBody = NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildAppBar()],
        body: TabBarView(
          controller: _tabCtrl,
          children: const [
            KhoProDashboardScreen(),
            IngredientListScreen(),
            RecipeListScreen(),
            ProductionOrderScreen(),
            KhoProReportScreen(),
          ],
        ),
      );

    return Scaffold(
      backgroundColor: KhoTheme.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return Row(children: [
              Expanded(flex: 3, child: mainBody),
              SizedBox(
                width: 280,
                child: _KhoProRightPanel(currentTab: _currentTab),
              ),
            ]);
          }
          return mainBody;
        },
      ),
    );
  }

  Widget _buildAppBar() => SliverAppBar(
    pinned: true,
    expandedHeight: 110,
    backgroundColor: KhoTheme.navy,
    elevation: 0,
    // ── Nút back — leading chuẩn ──────────────────────────────────
    leading: Padding(
      padding: const EdgeInsets.only(left: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(navTabProvider.notifier).goTo(0);
        },
        child: Center(
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: Colors.white),
          ),
        ),
      ),
    ),
    // ── Title — không bị clip, không bị parallax ──────────────────
    title: Text('Kho Chuyên Nghiệp',
        style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4)),
    titleSpacing: 6,
    // ── Background gradient + subtitle ───────────────────────────
    flexibleSpace: FlexibleSpaceBar(
      collapseMode: CollapseMode.pin, // không parallax, chỉ thu gọn
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KhoTheme.navy, KhoTheme.navyLight],
          ),
        ),
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.fromLTRB(72, 0, 20, 14),
        child: Text(
          'Định lượng & giá vốn nhà hàng',
          style: GoogleFonts.outfit(
              color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    ),
    // ── Tab bar ───────────────────────────────────────────────────
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(44),
      child: Container(
        color: KhoTheme.navy,
        child: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFFE85D20),
          indicatorWeight: 3,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          padding: EdgeInsets.zero,
          tabs: _tabs.map((t) => Tab(
            height: 44,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(t.icon, size: 15),
              const SizedBox(width: 5),
              Text(t.label,
                  style: GoogleFonts.outfit(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          )).toList(),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET RIGHT PANEL — Kho Pro Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _KhoProRightPanel extends StatelessWidget {
  final int currentTab;
  const _KhoProRightPanel({required this.currentTab});

  static const _tabInfo = [
    (icon: Icons.dashboard_rounded,      title: 'Tổng quan', desc: 'Tổng hợp kho chuyên nghiệp'),
    (icon: Icons.egg_alt_rounded,        title: 'Nguyên liệu', desc: 'Quản lý nguyên liệu đầu vào'),
    (icon: Icons.menu_book_rounded,      title: 'Công thức', desc: 'Định lượng & công thức chế biến'),
    (icon: Icons.precision_manufacturing_rounded, title: 'Sản xuất', desc: 'Lệnh sản xuất & chế biến'),
    (icon: Icons.bar_chart_rounded,      title: 'Báo cáo', desc: 'Phân tích giá vốn & tồn kho'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F0EA),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: KhoTheme.navy.withValues(alpha: 0.07),
                blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(children: [
                  const Icon(Icons.precision_manufacturing_rounded, size: 16, color: KhoTheme.navy),
                  const SizedBox(width: 6),
                  Text('Kho Chuyên Nghiệp', style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w800, color: KhoTheme.navy)),
                ]),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: List.generate(_tabInfo.length, (i) {
                  final t = _tabInfo[i];
                  final isActive = i == currentTab;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? KhoTheme.navy.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(t.icon, size: 16,
                        color: isActive ? KhoTheme.navy : const Color(0xFF9E9085)),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.title, style: GoogleFonts.outfit(
                          fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? KhoTheme.navy : const Color(0xFF1A1207))),
                        Text(t.desc, style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF9E9085))),
                      ])),
                      if (isActive)
                        Container(width: 6, height: 6, decoration: BoxDecoration(
                          color: KhoTheme.navy, shape: BoxShape.circle)),
                    ]),
                  );
                })),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
