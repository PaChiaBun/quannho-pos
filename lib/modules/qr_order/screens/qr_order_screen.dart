import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/repositories/ban_repository.dart';
import '../../../core/services/store_auth_service.dart';
import '../models/qr_order_model.dart';
import '../providers/qr_order_providers.dart';
import 'table_qr_print_screen.dart';
import 'tabs/qr_settings_tab.dart';
import 'tabs/table_qr_list_tab.dart';
import 'tabs/batch_table_print_tab.dart';
import 'tabs/counter_qr_design_tab.dart';

class QrOrderScreen extends ConsumerStatefulWidget {
  const QrOrderScreen({super.key});

  @override
  ConsumerState<QrOrderScreen> createState() => _QrOrderScreenState();
}

class _QrOrderScreenState extends ConsumerState<QrOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _baseUrlCtrl = TextEditingController();
  final TextEditingController _tableSearchCtrl = TextEditingController();
  final BanRepository _banRepo = BanRepository();

  List<BanZoneModel> _zones = [];
  List<BanTableModel> _tables = [];
  Map<String, QrChannelModel?> _channelsByTableId = {};
  QrChannelModel? _counterChannel;
  bool _loadingTables = true;
  String _storeId = '';
  String _storeName = 'Quán Nhỏ';
  String _selectedZoneFilter = 'all';

  // Batch Print Tab State Variables
  String _batchSelectMode = 'all';
  String _batchSelectedZoneId = 'all';
  final Set<String> _selectedTableIds = {};

  String _decalPreset = '70x100';
  final TextEditingController _decalWidthCtrl = TextEditingController(
    text: '70',
  );
  final TextEditingController _decalHeightCtrl = TextEditingController(
    text: '100',
  );
  double _bleedMm = 2.0;
  bool _showCropMarks = true;

  final TextEditingController _tplTitleCtrl = TextEditingController(
    text: 'QUÉT QR GỌI MÓN',
  );
  final TextEditingController _tplInstructionCtrl = TextEditingController(
    text:
        'Quét mã QR bằng ứng dụng Zalo, Camera hoặc trình duyệt di động để xem Menu',
  );
  final TextEditingController _tplConfirmNoteCtrl = TextEditingController(
    text:
        'Sau khi đặt xong, vui lòng gọi nhân viên đến đọc lại và xác nhận món. Món chỉ được gửi xuống bếp sau khi nhân viên xác nhận.',
  );

  // Counter Poster Config State Variables
  String _ctrPreset = 'classic_orange';
  String _ctrSizePreset = 'a5';
  final TextEditingController _ctrWidthCtrl = TextEditingController(
    text: '148',
  );
  final TextEditingController _ctrHeightCtrl = TextEditingController(
    text: '210',
  );
  final TextEditingController _ctrTitleCtrl = TextEditingController(
    text: 'QUÉT QR GỌI MÓN TẠI QUẦY',
  );
  final TextEditingController _ctrSubtitleCtrl = TextEditingController(
    text: 'Tự chọn món & Nhận mã Pickup #Q01',
  );
  final TextEditingController _ctrInstructionsCtrl = TextEditingController(
    text: '1. Quét mã QR • 2. Chọn món & Gửi đơn • 3. Đợi nhận mã Pickup #Q01',
  );
  bool _showCtrNotice = true;
  final TextEditingController _ctrNoticeCtrl = TextEditingController(
    text:
        'Sau khi gửi đơn, vui lòng giữ điện thoại để nhận mã số lấy món tại quầy.',
  );
  final TextEditingController _wifiSsidCtrl = TextEditingController();
  final TextEditingController _wifiPasswordCtrl = TextEditingController();
  final TextEditingController _hotlineCtrl = TextEditingController();
  final TextEditingController _openingHoursCtrl = TextEditingController();
  final TextEditingController _promoFooterCtrl = TextEditingController();

  static const String kSysPosTakeawayZoneId =
      '00000000-0000-0000-0001-000000000001';
  static const String kSysPosTakeawayTableId =
      '00000000-0000-0000-0001-000000000002';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final info = await StoreAuthService.getStoreInfo();
    _storeId = info['store_id'] as String? ?? '';
    _storeName = info['store_name'] as String? ?? 'Quán Nhỏ';

    final settings = await ref.read(qrOrderRepoProvider).getSettings();
    _baseUrlCtrl.text = settings.customBaseUrl;

    _ctrPreset = settings.counterPreset;
    _ctrSizePreset = settings.counterSizePreset;
    _ctrWidthCtrl.text = settings.counterWidthMm.toInt().toString();
    _ctrHeightCtrl.text = settings.counterHeightMm.toInt().toString();
    _ctrTitleCtrl.text = settings.counterTitle;
    _ctrSubtitleCtrl.text = settings.counterSubtitle;
    _ctrInstructionsCtrl.text = settings.counterInstructions;
    _showCtrNotice = settings.showCounterNotice;
    _ctrNoticeCtrl.text = settings.counterNoticeText;
    _wifiSsidCtrl.text = settings.wifiSsid;
    _wifiPasswordCtrl.text = settings.wifiPassword;
    _hotlineCtrl.text = settings.hotline;
    _openingHoursCtrl.text = settings.openingHours;
    _promoFooterCtrl.text = settings.promoFooter;

    try {
      final rawZones = await _banRepo.getZones();
      final rawTables = await _banRepo.getAllTables();

      final zones =
          rawZones.where((z) => z.id != kSysPosTakeawayZoneId).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final tables =
          rawTables
              .where(
                (t) =>
                    t.id != kSysPosTakeawayTableId &&
                    t.zoneId != kSysPosTakeawayZoneId,
              )
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final repo = ref.read(qrOrderRepoProvider);

      final channelMap = <String, QrChannelModel?>{};
      for (final table in tables) {
        final ch = await repo.ensureChannelForTable(
          storeId: _storeId,
          tableId: table.id,
          tableName: table.label,
        );
        channelMap[table.id] = ch;
      }

      final counterCh = await repo.ensureCounterChannel(storeId: _storeId);

      if (mounted) {
        setState(() {
          _zones = zones;
          _tables = tables;
          _channelsByTableId = channelMap;
          _counterChannel = counterCh;
          _selectedTableIds.addAll(tables.map((t) => t.id));
          _loadingTables = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTables = false);
    }
  }

  String _normalizeUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  bool _isValidPublicUrl(String? url) {
    if (url == null) return false;
    final normalized = _normalizeUrl(url);
    if (normalized.isEmpty) return false;
    final uri = Uri.tryParse(normalized);
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;

    final host = uri.host.toLowerCase();
    if (host.isEmpty ||
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host.startsWith('192.168.') ||
        host.startsWith('10.')) {
      return false;
    }
    return true;
  }

  String? _getActiveBaseUrl() {
    final custom = _baseUrlCtrl.text.trim();
    if (custom.isNotEmpty) {
      final normalized = _normalizeUrl(custom);
      if (_isValidPublicUrl(normalized)) {
        return normalized;
      }
    }
    return null;
  }

  String _formatQrUrl(String baseUrl, String channelCode) {
    var trimmed = baseUrl.trim();
    if (trimmed.contains('{code}')) {
      return trimmed.replaceAll('{code}', channelCode);
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.contains('/#')) {
      trimmed = trimmed.substring(0, trimmed.indexOf('/#'));
    }
    final subpathsToStrip = ['/menu', '/goi-mon', '/pos', '/qr_order'];
    for (final sub in subpathsToStrip) {
      if (trimmed.endsWith(sub)) {
        trimmed = trimmed.substring(0, trimmed.length - sub.length);
        break;
      }
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return '$trimmed/goi-mon/?code=$channelCode';
  }

  String? _buildTableQrUrl(BanTableModel table) {
    final ch = _channelsByTableId[table.id];
    if (ch == null || ch.channelCode.isEmpty) return null;

    final baseUrl = _getActiveBaseUrl();
    if (baseUrl == null) return null;

    return _formatQrUrl(baseUrl, ch.channelCode);
  }

  String? _buildCounterQrUrl() {
    if (_counterChannel == null || _counterChannel!.channelCode.isEmpty) {
      return null;
    }

    final baseUrl = _getActiveBaseUrl();
    if (baseUrl == null) return null;

    return _formatQrUrl(baseUrl, _counterChannel!.channelCode);
  }

  Future<void> _testOpenDomain(String url) async {
    final normalized = _normalizeUrl(url);
    if (!_isValidPublicUrl(normalized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tên miền không hợp lệ! Phải là URL HTTPS công khai (ví dụ: https://quannho.lpm.vn/pos)',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final uri = Uri.parse(normalized);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showQrPreviewDialog(
    BuildContext context,
    BanTableModel table,
    String? url,
  ) {
    final ch = _channelsByTableId[table.id];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.qr_code_2_rounded,
              color: Color(0xFF8B5CF6),
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mã QR ${table.label}',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 100,
                    color: Color(0xFF8B5CF6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ch?.channelCode ?? 'CTR_CHUA_MIGRATE',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.purple.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (url != null) ...[
              SelectableText(
                url,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.blue.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ] else
              Text(
                '🔒 Chưa thể xuất URL do chưa cấu hình tên miền HTTPS hoặc chưa chạy migration DB.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.red),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          if (url != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('In Mã QR Bàn'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TableQrPrintScreen(
                      title: table.label,
                      qrUrl: url,
                      storeName: _storeName,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _saveCounterSettings() async {
    final repo = ref.read(qrOrderRepoProvider);
    final current = await repo.getSettings();
    final updated = current.copyWith(
      counterPreset: _ctrPreset,
      counterSizePreset: _ctrSizePreset,
      counterWidthMm: double.tryParse(_ctrWidthCtrl.text.trim()) ?? 148.0,
      counterHeightMm: double.tryParse(_ctrHeightCtrl.text.trim()) ?? 210.0,
      counterTitle: _ctrTitleCtrl.text.trim(),
      counterSubtitle: _ctrSubtitleCtrl.text.trim(),
      counterInstructions: _ctrInstructionsCtrl.text.trim(),
      showCounterNotice: _showCtrNotice,
      counterNoticeText: _ctrNoticeCtrl.text.trim(),
      wifiSsid: _wifiSsidCtrl.text.trim(),
      wifiPassword: _wifiPasswordCtrl.text.trim(),
      hotline: _hotlineCtrl.text.trim(),
      openingHours: _openingHoursCtrl.text.trim(),
      promoFooter: _promoFooterCtrl.text.trim(),
    );

    await repo.saveSettings(updated);
    ref.invalidate(qrOrderSettingsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu cấu hình thiết kế Poster QR Quầy!'),
        ),
      );
    }
  }

  void _resetCounterSettings() {
    setState(() {
      _ctrPreset = 'classic_orange';
      _ctrSizePreset = 'a5';
      _ctrWidthCtrl.text = '148';
      _ctrHeightCtrl.text = '210';
      _ctrTitleCtrl.text = 'QUÉT QR GỌI MÓN TẠI QUẦY';
      _ctrSubtitleCtrl.text = 'Tự chọn món & Nhận mã Pickup #Q01';
      _ctrInstructionsCtrl.text =
          '1. Quét mã QR • 2. Chọn món & Gửi đơn • 3. Đợi nhận mã Pickup #Q01';
      _showCtrNotice = true;
      _ctrNoticeCtrl.text =
          'Sau khi gửi đơn, vui lòng giữ điện thoại để nhận mã số lấy món tại quầy.';
      _wifiSsidCtrl.clear();
      _wifiPasswordCtrl.clear();
      _hotlineCtrl.clear();
      _openingHoursCtrl.clear();
      _promoFooterCtrl.clear();
    });
    _saveCounterSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _baseUrlCtrl.dispose();
    _tableSearchCtrl.dispose();
    _decalWidthCtrl.dispose();
    _decalHeightCtrl.dispose();
    _tplTitleCtrl.dispose();
    _tplInstructionCtrl.dispose();
    _tplConfirmNoteCtrl.dispose();
    _ctrWidthCtrl.dispose();
    _ctrHeightCtrl.dispose();
    _ctrTitleCtrl.dispose();
    _ctrSubtitleCtrl.dispose();
    _ctrInstructionsCtrl.dispose();
    _ctrNoticeCtrl.dispose();
    _wifiSsidCtrl.dispose();
    _wifiPasswordCtrl.dispose();
    _hotlineCtrl.dispose();
    _openingHoursCtrl.dispose();
    _promoFooterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(qrOrderSettingsProvider);
    final settings =
        settingsAsync.asData?.value ?? const QrOrderSettingsModel();
    final activeBaseUrl = _getActiveBaseUrl();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'QR Gọi Món (Bàn & Quầy)',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.settings_rounded), text: 'Thiết Lập'),
            Tab(
              icon: Icon(Icons.table_restaurant_rounded),
              text: 'QR Theo Bàn',
            ),
            Tab(icon: Icon(Icons.print_rounded), text: 'In Tem Bàn'),
            Tab(
              icon: Icon(Icons.point_of_sale_rounded),
              text: 'Thiết Kế QR Quầy',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          QrSettingsTab(
            settings: settings,
            baseUrlCtrl: _baseUrlCtrl,
            isValidPublicUrl: _isValidPublicUrl,
            normalizeUrl: _normalizeUrl,
            testOpenDomain: _testOpenDomain,
          ),
          TableQrListTab(
            loadingTables: _loadingTables,
            activeBaseUrl: activeBaseUrl,
            zones: _zones,
            tables: _tables,
            channelsByTableId: _channelsByTableId,
            tableSearchCtrl: _tableSearchCtrl,
            onSearchChanged: (val) => setState(() {}),
            selectedZoneFilter: _selectedZoneFilter,
            onZoneFilterChanged: (val) =>
                setState(() => _selectedZoneFilter = val),
            storeName: _storeName,
            buildTableQrUrl: _buildTableQrUrl,
            showQrPreviewDialog: _showQrPreviewDialog,
          ),
          BatchTablePrintTab(
            loadingTables: _loadingTables,
            activeBaseUrl: activeBaseUrl,
            zones: _zones,
            tables: _tables,
            batchSelectMode: _batchSelectMode,
            onBatchSelectModeChanged: (val) =>
                setState(() => _batchSelectMode = val),
            batchSelectedZoneId: _batchSelectedZoneId,
            onBatchZoneIdChanged: (val) =>
                setState(() => _batchSelectedZoneId = val),
            selectedTableIds: _selectedTableIds,
            onToggleTableSelected: (id, val) {
              setState(() {
                if (val) {
                  _selectedTableIds.add(id);
                } else {
                  _selectedTableIds.remove(id);
                }
              });
            },
            decalPreset: _decalPreset,
            onDecalPresetChanged: (val) => setState(() => _decalPreset = val),
            decalWidthCtrl: _decalWidthCtrl,
            decalHeightCtrl: _decalHeightCtrl,
            bleedMm: _bleedMm,
            onBleedMmChanged: (val) => setState(() => _bleedMm = val),
            showCropMarks: _showCropMarks,
            onCropMarksChanged: (val) => setState(() => _showCropMarks = val),
            tplTitleCtrl: _tplTitleCtrl,
            tplInstructionCtrl: _tplInstructionCtrl,
            tplConfirmNoteCtrl: _tplConfirmNoteCtrl,
            storeName: _storeName,
            buildTableQrUrl: _buildTableQrUrl,
          ),
          CounterQrDesignTab(
            counterChannel: _counterChannel,
            counterUrl: _buildCounterQrUrl(),
            activeBaseUrl: activeBaseUrl,
            storeName: _storeName,
            testOpenDomain: _testOpenDomain,
            ctrPreset: _ctrPreset,
            onPresetChanged: (val) => setState(() => _ctrPreset = val),
            ctrSizePreset: _ctrSizePreset,
            onSizePresetChanged: (val) => setState(() => _ctrSizePreset = val),
            ctrWidthCtrl: _ctrWidthCtrl,
            ctrHeightCtrl: _ctrHeightCtrl,
            ctrTitleCtrl: _ctrTitleCtrl,
            ctrSubtitleCtrl: _ctrSubtitleCtrl,
            ctrInstructionsCtrl: _ctrInstructionsCtrl,
            showCtrNotice: _showCtrNotice,
            onNoticeToggleChanged: (val) =>
                setState(() => _showCtrNotice = val),
            ctrNoticeCtrl: _ctrNoticeCtrl,
            wifiSsidCtrl: _wifiSsidCtrl,
            wifiPasswordCtrl: _wifiPasswordCtrl,
            hotlineCtrl: _hotlineCtrl,
            openingHoursCtrl: _openingHoursCtrl,
            promoFooterCtrl: _promoFooterCtrl,
            onSaveSettings: _saveCounterSettings,
            onResetSettings: _resetCounterSettings,
          ),
        ],
      ),
    );
  }
}
