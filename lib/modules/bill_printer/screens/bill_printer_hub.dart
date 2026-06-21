import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/bill_template_provider.dart';
import '../providers/printer_settings_provider.dart';
import '../widgets/bill_preview_widget.dart';
import 'bill_designer_v2.dart';
import 'kitchen_ticket_designer.dart';
import 'template_gallery_screen.dart';

const _kIndigo = Color(0xFF1C2151);

class BillPrinterHub extends ConsumerWidget {
  const BillPrinterHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTpl = ref.watch(billTemplateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: _kIndigo,
        foregroundColor: Colors.white,
        title: Text('In Hoá Đơn',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: asyncTpl.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (tpl) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // ── Cấu hình máy in trạm ──────────────────────────────────────────
            _HubCard(
              icon: Icons.print_rounded,
              color: const Color(0xFFD97706),
              title: 'Cấu Hình Máy In & Tem Dán Ly',
              subtitle: 'Phân trạm: Thu Ngân, Bếp Nóng, Bếp Bar, và Tem Nhãn Dán Ly',
              onTap: () => _openPrinterSettings(context),
            ),

            const SizedBox(height: 12),

            // ── Thiết kế hoá đơn khách ────────────────────────────────────────
            _HubCard(
              icon: Icons.tune_rounded,
              color: _kIndigo,
              title: 'Thiết Kế Hoá Đơn',
              subtitle: '${tpl.blocks.where((b) => b.enabled).length} blocks đang hiện  •  ${tpl.paperSize.toUpperCase()}',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BillDesignerV2())),
            ),

            const SizedBox(height: 12),

            // ── Thiết kế phiếu bếp ───────────────────────────────────────────
            _HubCard(
              icon: Icons.local_fire_department_rounded,
              color: const Color(0xFF7C3AED),
              title: 'Thiết Kế Phiếu Bếp',
              subtitle: 'Font to, số lượng nổi bật, ghi chú đặc biệt',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const KitchenTicketDesigner())),
            ),

            const SizedBox(height: 12),

            // ── Chọn mẫu dựng sẵn ──────────────────────────────────────────
            _HubCard(
              icon: Icons.collections_bookmark_rounded,
              color: const Color(0xFF0F766E),
              title: 'Chọn Mẫu Hoá Đơn & Phiếu Bếp',
              subtitle: '10 mẫu hoá đơn + 8 mẫu phiếu bếp dựng sẵn — chọn & áp dụng ngay',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TemplateGalleryScreen())),
            ),

            const SizedBox(height: 16),

            // ── Xem trước nhanh theo mẫu hiện tại ──────────────────────────
            Text('Xem Trước Nhanh',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700, fontSize: 15, color: _kIndigo)),
            const SizedBox(height: 12),
            Container(
              height: 380,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)],
              ),
              clipBehavior: Clip.hardEdge,
              child: BillPreviewWidget(tpl: tpl),
            ),

            const SizedBox(height: 16),

            // ── Đặt lại ──────────────────────────────────────────────────
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('Đặt lại về mặc định',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                side: BorderSide(color: Colors.red.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _confirmReset(context, ref),
            ),

            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  void _openPrinterSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PrinterSettingsSheet(),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Đặt lại thiết kế?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text('Toàn bộ cài đặt hoá đơn sẽ trở về mặc định.',
            style: GoogleFonts.outfit()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Huỷ', style: GoogleFonts.outfit(color: _kIndigo))),
          TextButton(
            onPressed: () {
              ref.read(billTemplateProvider.notifier).reset();
              Navigator.pop(ctx);
            },
            child: Text('Đặt lại',
                style: GoogleFonts.outfit(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Printer Settings Sheet ──────────────────────────────────────────────────
class _PrinterSettingsSheet extends ConsumerStatefulWidget {
  const _PrinterSettingsSheet();

  @override
  ConsumerState<_PrinterSettingsSheet> createState() => _PrinterSettingsSheetState();
}

class _PrinterSettingsSheetState extends ConsumerState<_PrinterSettingsSheet> {
  final Map<String, TextEditingController> _ipControllers = {};

  @override
  void initState() {
    super.initState();
    final settings = ref.read(printerSettingsProvider);
    _ipControllers['cashier'] = TextEditingController(text: settings.cashier.type == 'network' ? settings.cashier.name : '');
    _ipControllers['bepNong'] = TextEditingController(text: settings.bepNong.type == 'network' ? settings.bepNong.name : '');
    _ipControllers['bepBar'] = TextEditingController(text: settings.bepBar.type == 'network' ? settings.bepBar.name : '');
    _ipControllers['barLabel'] = TextEditingController(text: settings.barLabel.type == 'network' ? settings.barLabel.name : '');
  }

  @override
  void dispose() {
    for (final ctrl in _ipControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _runTestPrint(String station, PrinterConfig config) async {
    try {
      if (config.name.isEmpty) {
        throw Exception('Vui lòng chọn máy in hoặc nhập IP trước.');
      }
      if (config.type == 'system') {
        final pdf = pw.Document();
        pdf.addPage(pw.Page(
          build: (context) => pw.Center(
            child: pw.Text('Quan Nho POS\nTEST SYSTEM PRINTER\nStation: $station\nPrinter: ${config.name}'),
          ),
        ));
        await Printing.directPrintPdf(
          printer: Printer(url: config.name),
          onLayout: (_) async => pdf.save(),
        );
      } else {
        final socket = await Socket.connect(config.name, 9100, timeout: const Duration(seconds: 3));
        socket.add(utf8.encode('\x1b\x40')); // Init printer
        socket.add(utf8.encode('Quan Nho POS - Test IP Printer\n'));
        socket.add(utf8.encode('Station: $station\n'));
        socket.add(utf8.encode('IP: ${config.name}\n'));
        socket.add(utf8.encode('Status: Connected successfully!\n\n\n\n\n'));
        socket.add(utf8.encode('\x1d\x56\x01')); // Cut command
        await socket.flush();
        await socket.close();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Đã gửi lệnh in thử nghiệm.'),
          behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Lỗi Kết Nối'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đồng ý')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(printerSettingsProvider);
    final systemPrintersAsync = ref.watch(systemPrintersProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Cấu Hình Máy In & Tem Dán Ly',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: _kIndigo)),
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Auto print switches
                    SwitchListTile(
                      activeColor: _kIndigo,
                      title: const Text('Tự động in khi thanh toán (Khách)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('In hoá đơn thu ngân ngay khi bấm thanh toán thành công', style: TextStyle(fontSize: 12)),
                      value: settings.autoPrintCheckout,
                      onChanged: (v) => ref.read(printerSettingsProvider.notifier).toggleAutoPrint(checkout: v),
                    ),
                    SwitchListTile(
                      activeColor: _kIndigo,
                      title: const Text('Tự động in phiếu bếp khi báo chế biến', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Gửi món đến bếp nóng, quầy bar & tem dán ly tự động', style: TextStyle(fontSize: 12)),
                      value: settings.autoPrintKitchen,
                      onChanged: (v) => ref.read(printerSettingsProvider.notifier).toggleAutoPrint(kitchen: v),
                    ),
                    const Divider(height: 24),

                    // Cashier Printer
                    _buildStationSection(
                      title: '1. Máy in Thu Ngân (Cashier)',
                      subtitle: 'In hoá đơn thanh toán đầy đủ cho khách',
                      stationKey: 'cashier',
                      config: settings.cashier,
                      systemPrinters: systemPrintersAsync.value ?? [],
                    ),
                    const SizedBox(height: 16),

                    // Hot Kitchen Printer
                    _buildStationSection(
                      title: '2. Máy in Bếp Nóng (Hot Kitchen)',
                      subtitle: 'Chỉ nhận phiếu in các món chế biến bằng lửa',
                      stationKey: 'bepNong',
                      config: settings.bepNong,
                      systemPrinters: systemPrintersAsync.value ?? [],
                    ),
                    const SizedBox(height: 16),

                    // Bar Printer
                    _buildStationSection(
                      title: '3. Máy in Bếp Bar (Drinks)',
                      subtitle: 'Chỉ nhận phiếu các món nước uống, sinh tố, trà sữa',
                      stationKey: 'bepBar',
                      config: settings.bepBar,
                      systemPrinters: systemPrintersAsync.value ?? [],
                    ),
                    const SizedBox(height: 16),

                    // Bar Label Printer
                    _buildStationSection(
                      title: '4. Máy in Nhãn Dán Ly (Stickers)',
                      subtitle: 'In tem dán ly cho từng cốc trà sữa, đồ uống mang đi',
                      stationKey: 'barLabel',
                      config: settings.barLabel,
                      systemPrinters: systemPrintersAsync.value ?? [],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationSection({
    required String title,
    required String subtitle,
    required String stationKey,
    required PrinterConfig config,
    required List<Printer> systemPrinters,
  }) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF5F7FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: config.enabled ? _kIndigo.withValues(alpha: 0.3) : Colors.grey.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kIndigo)),
                      Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Switch(
                  activeColor: _kIndigo,
                  value: config.enabled,
                  onChanged: (v) {
                    ref.read(printerSettingsProvider.notifier).saveConfig(
                      stationKey,
                      config.copyWith(enabled: v),
                    );
                  },
                ),
              ],
            ),
            if (config.enabled) ...[
              const SizedBox(height: 12),
              // Segmented selection: System vs Network IP
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Máy in Hệ thống', style: TextStyle(fontSize: 12)),
                      selected: config.type == 'system',
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(printerSettingsProvider.notifier).saveConfig(
                            stationKey,
                            config.copyWith(type: 'system', name: ''),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Kết nối Mạng IP', style: TextStyle(fontSize: 12)),
                      selected: config.type == 'network',
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(printerSettingsProvider.notifier).saveConfig(
                            stationKey,
                            config.copyWith(type: 'network', name: _ipControllers[stationKey]?.text ?? ''),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (config.type == 'system') ...[
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Chọn Máy In',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  value: systemPrinters.any((p) => p.url == config.name) ? config.name : null,
                  hint: const Text('Chọn máy in phát hiện được...'),
                  items: systemPrinters.map((p) {
                    return DropdownMenuItem<String>(
                      value: p.url,
                      child: Text(p.name, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(printerSettingsProvider.notifier).saveConfig(
                        stationKey,
                        config.copyWith(name: val),
                      );
                    }
                  },
                ),
              ] else ...[
                TextField(
                  controller: _ipControllers[stationKey],
                  decoration: InputDecoration(
                    labelText: 'Nhập địa chỉ IP máy in (ví dụ: 192.168.1.100)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (val) {
                    ref.read(printerSettingsProvider.notifier).saveConfig(
                      stationKey,
                      config.copyWith(name: val.trim()),
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _runTestPrint(title, config),
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                  label: const Text('In thử nghiệm', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: _kIndigo,
                    backgroundColor: _kIndigo.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Hub Card ───────────────────────────────────────────────────────────────
class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 2),
              Text(subtitle, style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            ])),
        const Icon(Icons.arrow_forward_ios_rounded,
            color: Colors.white54, size: 16),
      ]),
    ),
  );
}
