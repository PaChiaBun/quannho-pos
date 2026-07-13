import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/staff_service.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/utils/responsive.dart';
import 'ops_staff_screen.dart';
import 'ops_config_screen.dart';
import 'ops_report_screen.dart';
import 'ops_manager_dashboard.dart';

class OpsScreen extends ConsumerWidget {
  const OpsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsiveLayout(mobile: const _OpsScreenInner(), desktop: const _OpsScreenInner());
  }
}

class _OpsScreenInner extends ConsumerWidget {
  const _OpsScreenInner();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session   = ref.watch(sessionProvider);
    final canonical = StaffService.canonicalRole(session?.role ?? '');
    final isManager = session?.isOwner == true || canonical == 'owner' || canonical == 'manager';

    if (!isManager) {
      // Staff: single tab Nhiệm Vụ
      final staffBody = const OpsStaffScreen();
      return Scaffold(
        backgroundColor: const Color(0xFFFFF8F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1C2151),
          elevation: 0,
          centerTitle: false,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Vận Hành', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('Nhiệm Vụ Của Tôi', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withValues(alpha: 0.65))),
          ]),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 700) {
              return Row(children: [
                Expanded(flex: 3, child: staffBody),
                SizedBox(
                  width: 280,
                  child: _OpsRightPanel(isManager: false),
                ),
              ]);
            }
            return staffBody;
          },
        ),
      );
    }

    // Manager: 3 tabs
    final tabs = [
      const Tab(icon: Icon(Icons.dashboard_rounded), text: 'Tổng Quan'),
      const Tab(icon: Icon(Icons.tune_rounded), text: 'Cấu Hình'),
      const Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Báo Cáo'),
    ];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1C2151),
          elevation: 0,
          centerTitle: false,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Vận Hành', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('Check List Công Việc', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withValues(alpha: 0.65))),
          ]),
          bottom: TabBar(
            tabs: tabs,
            indicatorColor: const Color(0xFFFF6B35),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.outfit(fontSize: 11),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 700) {
              return Row(children: [
                const Expanded(flex: 3, child: TabBarView(children: [
                  OpsManagerDashboard(),
                  OpsConfigScreen(),
                  OpsReportScreen(),
                ])),
                SizedBox(
                  width: 280,
                  child: _OpsRightPanel(isManager: true),
                ),
              ]);
            }
            return const TabBarView(children: [
              OpsManagerDashboard(),
              OpsConfigScreen(),
              OpsReportScreen(),
            ]);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET RIGHT PANEL — Ops Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _OpsRightPanel extends StatelessWidget {
  final bool isManager;
  const _OpsRightPanel({required this.isManager});

  static const _kNavy = Color(0xFF1C2151);

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
                color: _kNavy.withValues(alpha: 0.07),
                blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(children: [
                  const Icon(Icons.checklist_rounded, size: 16, color: _kNavy),
                  const SizedBox(width: 6),
                  Text('Vận Hành', style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w800, color: _kNavy)),
                ]),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _ORow(label: 'Vai trò', value: isManager ? 'Quản lý' : 'Nhân viên', color: _kNavy),
                  const Divider(height: 1),
                  _ORow(label: 'Module', value: 'Check List', color: const Color(0xFFFF6B35)),
                  const Divider(height: 1),
                  _ORow(label: 'Trạng thái', value: 'Đang hoạt động', color: const Color(0xFF2E7D32)),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ORow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ORow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF1A1207)))),
      Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}
