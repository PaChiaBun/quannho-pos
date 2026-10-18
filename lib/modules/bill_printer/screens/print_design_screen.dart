// lib/modules/bill_printer/screens/print_design_screen.dart
// Thiết Kế Mẫu In — gộp một chỗ: Hoá đơn · Bếp nóng · Bếp bar · Tem dán ly.
// Mẫu dựng sẵn nằm trong từng tab (chế độ "Mẫu dựng sẵn").
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bill_designer_v2.dart';
import 'kitchen_ticket_designer.dart';
import 'label_designer.dart';

const _kIndigo = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);

class PrintDesignScreen extends StatelessWidget {
  /// 0 Hoá đơn · 1 Bếp nóng · 2 Bếp bar · 3 Tem ly
  final int initialTab;
  const PrintDesignScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab.clamp(0, 3),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F8),
        appBar: AppBar(
          backgroundColor: _kIndigo,
          foregroundColor: Colors.white,
          title: Text('Thiết Kế Mẫu In',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
          bottom: TabBar(
            isScrollable: MediaQuery.of(context).size.width < 600,
            tabAlignment: MediaQuery.of(context).size.width < 600
                ? TabAlignment.start
                : TabAlignment.fill,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: _kOrange,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Hoá Đơn'),
              Tab(icon: Icon(Icons.local_fire_department_rounded, size: 18), text: 'Bếp Nóng'),
              Tab(icon: Icon(Icons.local_bar_rounded, size: 18), text: 'Bếp Bar'),
              Tab(icon: Icon(Icons.sell_rounded, size: 18), text: 'Tem Dán Ly'),
            ],
          ),
        ),
        body: const TabBarView(
          // Tắt vuốt ngang để không đụng thao tác kéo-thả khối hoá đơn.
          physics: NeverScrollableScrollPhysics(),
          children: [
            BillDesignerV2(),
            KitchenTicketDesigner(stationKey: 'bepNong'),
            KitchenTicketDesigner(stationKey: 'bepBar'),
            LabelDesigner(),
          ],
        ),
      ),
    );
  }
}
