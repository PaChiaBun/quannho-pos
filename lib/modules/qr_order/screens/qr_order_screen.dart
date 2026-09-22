import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/store_auth_service.dart';
import '../models/qr_order_model.dart';
import '../providers/qr_order_providers.dart';
import 'tabs/counter_qr_design_tab.dart';
import 'tabs/qr_settings_tab.dart';
import 'tabs/table_shared_poster_tab.dart';

class QrOrderScreen extends ConsumerStatefulWidget {
  const QrOrderScreen({super.key});

  @override
  ConsumerState<QrOrderScreen> createState() => _QrOrderScreenState();
}

class _QrOrderScreenState extends ConsumerState<QrOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _baseUrlCtrl = TextEditingController();

  QrChannelModel? _tableSharedChannel;
  QrChannelModel? _counterChannel;
  String _storeId = '';
  String _storeName = 'Quán Nhỏ';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final info = await StoreAuthService.getStoreInfo();
    _storeId = info['store_id'] ?? '';
    _storeName = info['store_name'] ?? 'Quán Nhỏ';

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
      final repo = ref.read(qrOrderRepoProvider);
      var tblCh = await repo.getChannelByType(
        storeId: _storeId,
        type: 'TABLE_SHARED',
      );
      var ctrCh = await repo.getChannelByType(
        storeId: _storeId,
        type: 'COUNTER_TAKEAWAY',
      );

      // Only create a missing channel. Never mutate an existing channel merely
      // because the settings screen was opened.
      tblCh ??= (await repo.manageQrChannel(
        storeId: _storeId,
        type: 'TABLE_SHARED',
        isActive: settings.isTableEnabled,
        paymentMode: 'CASHIER_CONFIRM',
      )).data;
      ctrCh ??= (await repo.manageQrChannel(
        storeId: _storeId,
        type: 'COUNTER_TAKEAWAY',
        isActive: settings.isCounterEnabled,
        paymentMode: 'CASHIER_CONFIRM',
      )).data;

      if (mounted) {
        setState(() {
          _tableSharedChannel = tblCh;
          _counterChannel = ctrCh;
        });
      }
    } catch (_) {
      // Keep the screen usable; individual tabs show missing-channel state.
    }
  }

  String _normalizeUrl(String url) => QrUrlBuilder.normalizeUrl(url);

  bool _isValidPublicUrl(String? url) => QrUrlBuilder.isValidPublicUrl(url);

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

  String _formatQrUrl(String baseUrl, String channelCode) =>
      QrUrlBuilder.formatQrUrl(baseUrl, channelCode);

  String? _buildTableSharedQrUrl() {
    if (_tableSharedChannel == null ||
        _tableSharedChannel!.channelCode.isEmpty) {
      return null;
    }
    final baseUrl = _getActiveBaseUrl();
    if (baseUrl == null) return null;
    return _formatQrUrl(baseUrl, _tableSharedChannel!.channelCode);
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
          'QR Gọi Món V4 (Bàn & Quầy)',
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
              text: 'QR Dùng Chung Bàn',
            ),
            Tab(
              icon: Icon(Icons.point_of_sale_rounded),
              text: 'QR Quầy Mang Đi',
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
          TableSharedPosterTab(
            tableSharedChannel: _tableSharedChannel,
            tableSharedUrl: _buildTableSharedQrUrl(),
            activeBaseUrl: activeBaseUrl,
            storeName: _storeName,
            testOpenDomain: _testOpenDomain,
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
