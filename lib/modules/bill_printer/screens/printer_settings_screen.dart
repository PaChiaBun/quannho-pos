import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/printer_settings_provider.dart';
import '../providers/bill_template_provider.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../widgets/bill_preview_widget.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/services/network_printer_search_service.dart';

const _kIndigo = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kBg = Color(0xFFF0F2F8);

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  String _selectedStationKey = 'cashier';
  bool _isScanning = false;
  double _scanProgress = 0.0;
  final List<DiscoveredPrinter> _discoveredPrinters = [];
  StreamSubscription<DiscoveredPrinter>? _scanSubscription;
  final Map<String, TextEditingController> _ipControllers = {};
  final Map<String, FocusNode> _ipFocusNodes = {};

  @override
  void initState() {
    super.initState();
    final settings = ref.read(printerSettingsProvider);
    _ipControllers['cashier'] = TextEditingController(text: settings.cashier.type == 'network' ? settings.cashier.name : '');
    _ipControllers['bepNong'] = TextEditingController(text: settings.bepNong.type == 'network' ? settings.bepNong.name : '');
    _ipControllers['bepBar'] = TextEditingController(text: settings.bepBar.type == 'network' ? settings.bepBar.name : '');
    _ipControllers['barLabel'] = TextEditingController(text: settings.barLabel.type == 'network' ? settings.barLabel.name : '');

    for (final key in ['cashier', 'bepNong', 'bepBar', 'barLabel']) {
      _ipFocusNodes[key] = FocusNode();
      _ipFocusNodes[key]!.addListener(() {
        if (mounted && !_ipFocusNodes[key]!.hasFocus) {
          _saveIpAddress(key);
        }
      });
    }
  }

  void _saveIpAddress(String stationKey) {
    final ip = _ipControllers[stationKey]?.text.trim() ?? '';
    final settings = ref.read(printerSettingsProvider);
    final config = _getConfigByKey(settings, stationKey);
    if (config != null && config.type == 'network' && config.name != ip) {
      ref.read(printerSettingsProvider.notifier).saveConfig(
            stationKey,
            config.copyWith(name: ip),
          );
      debugPrint('[PrinterSettings] Auto-saved IP for $stationKey: $ip');
    }
  }

  PrinterConfig? _getConfigByKey(StationPrintersState settings, String key) {
    if (key == 'cashier') return settings.cashier;
    if (key == 'bepNong') return settings.bepNong;
    if (key == 'bepBar') return settings.bepBar;
    if (key == 'barLabel') return settings.barLabel;
    return null;
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    for (final ctrl in _ipControllers.values) {
      ctrl.dispose();
    }
    for (final node in _ipFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
      _discoveredPrinters.clear();
    });

    _scanSubscription?.cancel();
    _scanSubscription = NetworkPrinterSearchService.discoverPrinters(
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _scanProgress = progress;
          });
        }
      },
    ).listen(
      (printer) {
        if (mounted) {
          setState(() {
            _discoveredPrinters.add(printer);
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Đã quét xong mạng nội bộ. Tìm thấy ${_discoveredPrinters.length} máy in.',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            backgroundColor: _kIndigo,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
    );
  }

  Future<void> _runTestPrint(String stationName, PrinterConfig config) async {
    try {
      if (config.name.isEmpty) {
        throw Exception('Vui lòng chọn máy in hoặc nhập IP trước.');
      }
      if (kIsWeb) {
        final pdf = pw.Document();
        pdf.addPage(pw.Page(
          build: (context) => pw.Center(
            child: pw.Text('Quan Nho POS\nTEST PRINTER (WEB MODE)\nStation: $stationName\nTarget: ${config.name}'),
          ),
        ));
        await Printing.layoutPdf(onLayout: (_) async => pdf.save());
        return;
      }
      if (config.type == 'system') {
        final pdf = pw.Document();
        pdf.addPage(pw.Page(
          build: (context) => pw.Center(
            child: pw.Text('Quan Nho POS\nTEST SYSTEM PRINTER\nStation: $stationName\nPrinter: ${config.name}'),
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
        socket.add(utf8.encode('Station: $stationName\n'));
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
    // Tự động cập nhật nội dung TextControllers khi state thay đổi từ db
    ref.listen<StationPrintersState>(printerSettingsProvider, (previous, next) {
      if (next.cashier.type == 'network' && _ipControllers['cashier']?.text != next.cashier.name && _ipFocusNodes['cashier']?.hasFocus == false) {
        _ipControllers['cashier']?.text = next.cashier.name;
      }
      if (next.bepNong.type == 'network' && _ipControllers['bepNong']?.text != next.bepNong.name && _ipFocusNodes['bepNong']?.hasFocus == false) {
        _ipControllers['bepNong']?.text = next.bepNong.name;
      }
      if (next.bepBar.type == 'network' && _ipControllers['bepBar']?.text != next.bepBar.name && _ipFocusNodes['bepBar']?.hasFocus == false) {
        _ipControllers['bepBar']?.text = next.bepBar.name;
      }
      if (next.barLabel.type == 'network' && _ipControllers['barLabel']?.text != next.barLabel.name && _ipFocusNodes['barLabel']?.hasFocus == false) {
        _ipControllers['barLabel']?.text = next.barLabel.name;
      }
    });

    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kIndigo,
        foregroundColor: Colors.white,
        title: Text('Cấu Hình Máy In & Tem Dán Ly',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: isWide ? _buildWideLayout() : _buildMobileLayout(),
    );
  }

  // ── Layout cho Tablet & PC ──────────────────────────────────────────────────
  Widget _buildWideLayout() {
    final settings = ref.watch(printerSettingsProvider);
    final stationName = _getStationName(_selectedStationKey);
    final stationConfig = _getStationConfig(settings, _selectedStationKey);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cột bên trái: Danh sách các trạm in + Tự động in
        SizedBox(
          width: 360,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFE0E4F0))),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Trạm In Hệ Thống',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: _kIndigo)),
                  const SizedBox(height: 12),
                  _buildStationTabCard('cashier', '1. Thu Ngân (Cashier)', settings.cashier),
                  const SizedBox(height: 8),
                  _buildStationTabCard('bepNong', '2. Bếp Nóng (Hot Kitchen)', settings.bepNong),
                  const SizedBox(height: 8),
                  _buildStationTabCard('bepBar', '3. Bếp Bar (Drinks)', settings.bepBar),
                  const SizedBox(height: 8),
                  _buildStationTabCard('barLabel', '4. Nhãn Dán Ly (Stickers)', settings.barLabel),
                  const Divider(height: 32),
                  Text('Tuỳ Chọn Tự Động',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: _kIndigo)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    activeColor: _kIndigo,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('In khi thanh toán', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: const Text('In hoá đơn khi bán thành công', style: TextStyle(fontSize: 11)),
                    value: settings.autoPrintCheckout,
                    onChanged: (v) => ref.read(printerSettingsProvider.notifier).toggleAutoPrint(checkout: v),
                  ),
                  SwitchListTile(
                    activeColor: _kIndigo,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('In khi báo chế biến', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: const Text('Gửi món đến trạm bếp & nhãn ly', style: TextStyle(fontSize: 11)),
                    value: settings.autoPrintKitchen,
                    onChanged: (v) => ref.read(printerSettingsProvider.notifier).toggleAutoPrint(kitchen: v),
                  ),
                  SwitchListTile(
                    activeColor: _kIndigo,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tự động mở két tiền', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: const Text('Mở két khi in hoá đơn thanh toán', style: TextStyle(fontSize: 11)),
                    value: settings.autoOpenDrawer,
                    onChanged: (v) => ref.read(printerSettingsProvider.notifier).toggleAutoPrint(openDrawer: v),
                  ),
                  SwitchListTile(
                    activeColor: _kIndigo,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Máy chủ in ấn (Print Server)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: const Text('Tự động in hộ các thiết bị di động/web khác', style: TextStyle(fontSize: 11)),
                    value: settings.autoPrintServer,
                    onChanged: (v) => ref.read(printerSettingsProvider.notifier).toggleAutoPrint(printServer: v),
                  ),
                  const SizedBox(height: 16),
                  _buildHelpSection(),
                ],
              ),
            ),
          ),
        ),
        // Cột bên phải: Cấu hình chi tiết trạm đang chọn & Live Preview
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stationName,
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20, color: _kIndigo)),
                                Text('Trạng thái: ${stationConfig.enabled ? 'Đang hoạt động' : 'Đang tắt'}',
                                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Switch(
                            activeColor: _kIndigo,
                            value: stationConfig.enabled,
                            onChanged: (v) {
                              ref.read(printerSettingsProvider.notifier).saveConfig(
                                    _selectedStationKey,
                                    stationConfig.copyWith(enabled: v),
                                  );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (stationConfig.enabled) _buildStationConfigFields(_selectedStationKey, stationConfig),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              // Live Preview của trạm
              Expanded(
                flex: 3,
                child: Container(
                  color: const Color(0xFFF7F8FC),
                  child: _buildStationPreview(_selectedStationKey),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Layout cho Điện thoại di động ───────────────────────────────────────────
  Widget _buildMobileLayout() {
    final settings = ref.watch(printerSettingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toggles tự động
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: _kIndigo,
                    title: const Text('Tự động in khi thanh toán (Khách)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    value: settings.autoPrintCheckout,
                    onChanged: (v) => ref.read(printerSettingsProvider.notifier).toggleAutoPrint(checkout: v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    activeColor: _kIndigo,
                    title: const Text('Tự động in phiếu bếp khi báo chế biến', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    value: settings.autoPrintKitchen,
                    onChanged: (v) => ref.read(printerSettingsProvider.notifier).toggleAutoPrint(kitchen: v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    activeColor: _kIndigo,
                    title: const Text('Tự động mở két tiền khi thanh toán', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    value: settings.autoOpenDrawer,
                    onChanged: (v) => ref.read(printerSettingsProvider.notifier).toggleAutoPrint(openDrawer: v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    activeColor: _kIndigo,
                    title: const Text('Máy chủ in ấn (In hộ thiết bị khác)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    value: settings.autoPrintServer,
                    onChanged: (v) => ref.read(printerSettingsProvider.notifier).toggleAutoPrint(printServer: v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildHelpSection(),
          const SizedBox(height: 20),

          Text('Các trạm in cấu hình:',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: _kIndigo)),
          const SizedBox(height: 10),

          // Danh sách các trạm in (dạng mở rộng chi tiết hoặc Click)
          _buildMobileStationSection('cashier', '1. Thu Ngân (Cashier)', settings.cashier),
          const SizedBox(height: 12),
          _buildMobileStationSection('bepNong', '2. Bếp Nóng (Hot Kitchen)', settings.bepNong),
          const SizedBox(height: 12),
          _buildMobileStationSection('bepBar', '3. Bếp Bar (Drinks)', settings.bepBar),
          const SizedBox(height: 12),
          _buildMobileStationSection('barLabel', '4. Nhãn Dán Ly (Stickers)', settings.barLabel),
        ],
      ),
    );
  }

  // ── Các Helper Widgets ───────────────────────────────────────────────────────
  String _getStationName(String key) {
    switch (key) {
      case 'cashier': return 'Thu Ngân (Cashier)';
      case 'bepNong': return 'Bếp Nóng (Hot Kitchen)';
      case 'bepBar': return 'Bếp Bar (Drinks)';
      case 'barLabel': return 'Nhãn Dán Ly (Stickers)';
      default: return '';
    }
  }

  PrinterConfig _getStationConfig(StationPrintersState settings, String key) {
    switch (key) {
      case 'cashier': return settings.cashier;
      case 'bepNong': return settings.bepNong;
      case 'bepBar': return settings.bepBar;
      case 'barLabel': return settings.barLabel;
      default: return settings.cashier;
    }
  }

  Widget _buildStationTabCard(String key, String title, PrinterConfig config) {
    final isSelected = _selectedStationKey == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStationKey = key;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _kIndigo.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _kIndigo : Colors.grey.shade200,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: config.enabled ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                      color: isSelected ? _kIndigo : Colors.grey.shade800,
                    ),
                  ),
                  if (config.enabled && config.type == 'network' && config.name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Đã lưu IP: ${config.name}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isSelected ? _kIndigo : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileStationSection(String stationKey, String title, PrinterConfig config) {
    final systemPrintersAsync = ref.watch(systemPrintersProvider);
    final systemPrinters = systemPrintersAsync.value ?? [];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: config.enabled ? _kIndigo.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: config.enabled ? 1.5 : 1.0,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        iconColor: _kIndigo,
        collapsedIconColor: Colors.grey,
        title: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: config.enabled ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: _kIndigo)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            config.enabled
                ? 'Đang bật • ${config.type == 'system' ? 'M.in Hệ thống' : 'M.in IP Network'} (${config.name.isEmpty ? 'Chưa chọn' : config.name})'
                : 'Đang tắt',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        trailing: Switch(
          activeColor: _kIndigo,
          value: config.enabled,
          onChanged: (v) {
            ref.read(printerSettingsProvider.notifier).saveConfig(
                  stationKey,
                  config.copyWith(enabled: v),
                );
          },
        ),
        children: [
          if (config.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildStationConfigFields(stationKey, config),
            ),
        ],
      ),
    );
  }

  Widget _buildStationConfigFields(String stationKey, PrinterConfig config) {
    final systemPrintersAsync = ref.watch(systemPrintersProvider);
    final systemPrinters = systemPrintersAsync.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Segmented Connection Selection
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Máy in Hệ thống', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                selected: config.type == 'system',
                selectedColor: _kIndigo.withValues(alpha: 0.15),
                backgroundColor: Colors.grey.shade100,
                onSelected: (selected) {
                  if (selected) {
                    ref.read(printerSettingsProvider.notifier).saveConfig(
                          stationKey,
                          config.copyWith(type: 'system'),
                        );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Text('Kết nối Mạng IP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                selected: config.type == 'network',
                selectedColor: _kIndigo.withValues(alpha: 0.15),
                backgroundColor: Colors.grey.shade100,
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
        const SizedBox(height: 16),

        if (config.type == 'system') ...[
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Chọn Máy In',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  value: config.name.isNotEmpty ? config.name : null,
                  hint: const Text('Chọn máy in hệ thống được phát hiện...'),
                  items: (() {
                    final list = systemPrinters.map((p) {
                      return DropdownMenuItem<String>(
                        value: p.url,
                        child: Text(p.name, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList();
                    if (config.name.isNotEmpty && !systemPrinters.any((p) => p.url == config.name)) {
                      list.add(DropdownMenuItem<String>(
                        value: config.name,
                        child: Text('${config.name} (Đồng bộ đám mây)', 
                            style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                      ));
                    }
                    return list;
                  })(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(printerSettingsProvider.notifier).saveConfig(
                            stationKey,
                            config.copyWith(name: val),
                          );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: _kIndigo),
                tooltip: 'Dò lại máy in',
                onPressed: () {
                  ref.invalidate(systemPrintersProvider);
                },
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipControllers[stationKey],
                  focusNode: _ipFocusNodes[stationKey],
                  decoration: InputDecoration(
                    labelText: 'Địa chỉ IP máy in (ví dụ: 192.168.1.100)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.wifi_tethering_rounded, size: 20),
                  ),
                  keyboardType: TextInputType.url,
                  onSubmitted: (val) {
                    ref.read(printerSettingsProvider.notifier).saveConfig(
                          stationKey,
                          config.copyWith(name: val.trim()),
                        );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final ip = _ipControllers[stationKey]?.text ?? '';
                    ref.read(printerSettingsProvider.notifier).saveConfig(
                          stationKey,
                          config.copyWith(name: ip.trim()),
                        );
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Đã lưu cấu hình IP máy in.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Lưu IP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          if (config.type == 'network' && config.name.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Đã lưu IP: ${config.name}',
                style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // LAN Scan Section
          _buildLanScanWidget(stationKey, config),
        ],

        const SizedBox(height: 16),

        // Nút In Thử Nghiệm chiều cao 52px (Cảm ứng Desktop/Tablet)
        SizedBox(
          height: 52,
          child: TextButton.icon(
            onPressed: () => _runTestPrint(_getStationName(stationKey), config),
            icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
            label: Text('In thử nghiệm', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
            style: TextButton.styleFrom(
              foregroundColor: _kIndigo,
              backgroundColor: _kIndigo.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (stationKey == 'cashier') ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: TextButton.icon(
              onPressed: () async {
                if (config.type == 'network') {
                  if (config.name.isNotEmpty) {
                    try {
                      await ThermalPrinterService.openCashDrawer(printerIp: config.name);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Đã gửi lệnh mở két tiền.'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 1),
                        ));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Lỗi Kết Nối'),
                            content: Text('Không thể mở két: $e'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đồng ý')),
                            ],
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Vui lòng nhập IP máy in trước.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ));
                  }
                } else {
                  // Đối với máy in hệ thống (local USB)
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Mở Két Máy In Hệ Thống'),
                      content: const Text(
                        'Đối với máy in hệ thống (local USB), lệnh mở két tiền được điều khiển tự động bởi Driver máy in của hệ điều hành Windows.\n\n'
                        'Để kích hoạt, bạn vui lòng cấu hình "Device Settings -> Cash Drawer" trong Driver máy in của Windows, hoặc bấm nút "In thử nghiệm" phía trên để gửi lệnh in kích mở két.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đồng ý')),
                      ],
                    ),
                  );
                }
              },
              icon: const Icon(Icons.vpn_key_rounded, size: 18),
              label: Text('Mở két tiền', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _kOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLanScanWidget(String stationKey, PrinterConfig config) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dò tìm máy in tự động', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _kIndigo)),
                    Text(
                      _isScanning
                          ? 'Đang quét dải mạng IP... (${(_scanProgress * 100).toInt()}%)'
                          : 'Tự động phát hiện các máy in cổng 9100 trong mạng Wifi',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _startScanning,
                  icon: _isScanning
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
                      : const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Quét', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          if (_isScanning) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: _scanProgress, backgroundColor: Colors.grey.shade200, color: _kOrange),
          ],
          if (_discoveredPrinters.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Các máy in phát hiện được (click để chọn):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _discoveredPrinters.map((printer) {
                return ActionChip(
                  avatar: const Icon(Icons.print_rounded, size: 14, color: _kIndigo),
                  label: Text(printer.ip, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  backgroundColor: _kIndigo.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onPressed: () {
                    setState(() {
                      _ipControllers[stationKey]?.text = printer.ip;
                    });
                    ref.read(printerSettingsProvider.notifier).saveConfig(
                          stationKey,
                          config.copyWith(name: printer.ip),
                        );
                  },
                );
              }).toList(),
            ),
          ] else if (!_isScanning && _scanProgress > 0) ...[
            const SizedBox(height: 8),
            const Text('Không phát hiện máy in nào hoạt động trong dải IP này. Vui lòng kiểm tra kết nối mạng Wifi của máy in.',
                style: TextStyle(fontSize: 11, color: Colors.red)),
          ],
        ],
      ),
    );
  }

  Widget _buildStationPreview(String stationKey) {
    final asyncTpl = ref.watch(billTemplateProvider);
    return asyncTpl.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải mẫu: $e')),
      data: (tpl) {
        if (stationKey == 'barLabel') {
          // Tem dán ly Preview
          return _buildStickerMockPreview();
        } else {
          // Hoá đơn thông thường
          return BillPreviewWidget(tpl: tpl);
        }
      },
    );
  }

  Widget _buildStickerMockPreview() {
    return Center(
      child: Container(
        width: 220,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black45),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        padding: const EdgeInsets.all(10),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Text('QUÁN NHỎ POS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1))),
            Divider(height: 8, color: Colors.black54),
            Text('TRÀ ĐÀO ĐÁ (Peach Tea)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            SizedBox(height: 4),
            Text('+ 50% Đường, 70% Đá\n+ Topping: Thạch Đào', style: TextStyle(fontSize: 9, height: 1.3)),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ly: 1/3 (Mang đi)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                Text('10:45 22/06/2026', style: TextStyle(fontSize: 9, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.amber.shade800, size: 16),
              const SizedBox(width: 6),
              Text(
                'Hướng Dẫn Kết Nối Két Tiền',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '• Két tiền (Hộp đựng tiền thu ngân) phải được cắm dây kết nối (cổng RJ11) trực tiếp vào cổng phía sau máy in hóa đơn Thu Ngân.\n'
            '• Khi hoàn tất thanh toán hóa đơn hoặc khi nhấn nút "Mở két tiền", máy in sẽ truyền lệnh điện áp để tự động kích hoạt két tiền tự động nhảy ra.\n'
            '• Khổ giấy khuyên dùng cho máy in Thu Ngân: 80mm.',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.amber.shade900,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
