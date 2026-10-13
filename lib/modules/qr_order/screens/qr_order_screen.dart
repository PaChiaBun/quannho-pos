import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/store_auth_service.dart';
import '../models/qr_order_model.dart';
import '../providers/qr_order_providers.dart';
import '../services/qr_pdf_service.dart';
import 'qr_poster_print_screen.dart';
import 'tabs/qr_channel_card.dart';
import 'tabs/qr_settings_tab.dart';

const String _typeTable = 'TABLE_SHARED';
const String _typeCounter = 'COUNTER_TAKEAWAY';

/// Màn "Mã QR": một màn cuộn, hai thẻ (Tại bàn / Mang đi) + mục thu gọn.
class QrOrderScreen extends ConsumerStatefulWidget {
  const QrOrderScreen({super.key});

  @override
  ConsumerState<QrOrderScreen> createState() => _QrOrderScreenState();
}

class _QrOrderScreenState extends ConsumerState<QrOrderScreen> {
  String _storeId = '';
  String _storeName = 'Quán Nhỏ';
  QrOrderSettingsModel _settings = const QrOrderSettingsModel();
  QrChannelModel? _tableChannel;
  QrChannelModel? _counterChannel;
  bool _loading = true;
  String? _loadError;
  final Set<String> _busyTypes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final info = await StoreAuthService.getStoreInfo();
      if (!mounted) return;
      final storeId = (info['store_id'] ?? '').trim();
      if (storeId.isEmpty) {
        setState(() {
          _loading = false;
          _loadError = 'Chưa xác định được cửa hàng. Vui lòng đăng nhập lại.';
        });
        return;
      }
      final repo = ref.read(qrOrderRepoProvider);
      final settings = await repo.getSettings();
      if (!mounted) return;
      final table = await repo.getChannelByType(
        storeId: storeId,
        type: _typeTable,
      );
      if (!mounted) return;
      final counter = await repo.getChannelByType(
        storeId: storeId,
        type: _typeCounter,
      );
      if (!mounted) return;
      setState(() {
        _storeId = storeId;
        _storeName = info['store_name'] ?? 'Quán Nhỏ';
        _settings = settings;
        _tableChannel = table;
        _counterChannel = counter;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Không tải được cấu hình QR. Vui lòng thử lại.';
      });
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  /// Đọc settings mới nhất ngay trước khi ghi, áp [mutate], rồi ghi.
  Future<bool> _updateSettings(
    QrOrderSettingsModel Function(QrOrderSettingsModel latest) mutate,
  ) async {
    if (_loading || _loadError != null) return false;
    final repo = ref.read(qrOrderRepoProvider);
    try {
      final latest = await repo.getSettings();
      if (!mounted) return false;
      final updated = mutate(latest);
      final Future<dynamic> saving = repo.saveSettings(updated);
      final result = await saving;
      if (!mounted) return false;
      if (result == false) return false;
      ref.invalidate(qrOrderSettingsProvider);
      setState(() => _settings = updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggleChannel(String type, bool value) async {
    if (_storeId.isEmpty) {
      _toast('Chưa xác định được cửa hàng, không thể lưu.', error: true);
      return;
    }
    if (_busyTypes.contains(type)) return;
    final repo = ref.read(qrOrderRepoProvider);
    final existing = type == _typeTable ? _tableChannel : _counterChannel;
    setState(() => _busyTypes.add(type));
    try {
      final res = await repo.manageQrChannel(
        storeId: _storeId,
        type: type,
        isActive: value,
        paymentMode: existing?.paymentMode ?? 'CASHIER_CONFIRM',
      );
      if (!mounted) return;
      if (!res.isSuccess) {
        _toast(
          QrErrorCode.toUserMessage(res.errorCode, res.message),
          error: true,
        );
      }
      // Luôn đọc lại trạng thái thật từ server sau khi gạt.
      final fresh = await repo.getChannelByType(storeId: _storeId, type: type);
      if (!mounted) return;
      setState(() {
        if (type == _typeTable) {
          _tableChannel = fresh ?? (res.isSuccess ? res.data : existing);
        } else {
          _counterChannel = fresh ?? (res.isSuccess ? res.data : existing);
        }
      });
    } finally {
      if (mounted) setState(() => _busyTypes.remove(type));
    }
  }

  /// Link dựng từ giá trị ĐÃ LƯU; null nếu kênh thiếu/tắt hoặc tên miền sai.
  String? _urlFor(QrChannelModel? ch) {
    if (ch == null || !ch.isActive) return null;
    return QrUrlBuilder.build(
      customBaseUrl: _settings.customBaseUrl,
      channelCode: ch.channelCode,
    );
  }

  String? _reasonFor(QrChannelModel? ch) {
    if (ch == null) return 'Kênh chưa được bật. Gạt công tắc để tạo mã QR.';
    if (!ch.isActive) return 'Kênh đang tắt nên không có mã QR để in.';
    if (ch.channelCode.isEmpty) return 'Kênh chưa có mã. Hãy tắt rồi bật lại.';
    if (QrUrlBuilder.resolveBaseUrl(_settings.customBaseUrl) == null) {
      return 'Tên miền đã lưu không hợp lệ. Sửa trong mục Nâng cao.';
    }
    return null;
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    _toast('Đã sao chép link.');
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _toast('Không mở được link.', error: true);
    } catch (_) {
      _toast('Không mở được link.', error: true);
    }
  }

  void _print(QrPosterKind kind, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrPosterPrintScreen(
          kind: kind,
          qrUrl: url,
          storeName: _storeName,
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required String description,
    required IconData icon,
    required String type,
    required QrChannelModel? channel,
    required QrPosterKind kind,
  }) {
    final url = _urlFor(channel);
    return QrChannelCard(
      title: title,
      description: description,
      icon: icon,
      channelExists: channel != null,
      isActive: channel?.isActive ?? false,
      busy: _busyTypes.contains(type),
      url: url,
      unavailableReason: _reasonFor(channel),
      onToggle: (v) => _toggleChannel(type, v),
      onCopy: () => _copy(url!),
      onOpen: () => _open(url!),
      onPrint: () => _print(kind, url!),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_loadError != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            title: 'Tại bàn',
            description: 'Một mã dùng chung cho mọi bàn, khách tự chọn số bàn.',
            icon: Icons.table_restaurant_rounded,
            type: _typeTable,
            channel: _tableChannel,
            kind: QrPosterKind.table,
          ),
          const SizedBox(height: 16),
          _card(
            title: 'Mang đi',
            description: 'Khách gọi món tại quầy và nhận mã lấy món.',
            icon: Icons.shopping_bag_rounded,
            type: _typeCounter,
            channel: _counterChannel,
            kind: QrPosterKind.counter,
          ),
          const SizedBox(height: 16),
          QrTransferSection(
            settings: _settings,
            enabled: true,
            onSave: _updateSettings,
          ),
          const SizedBox(height: 12),
          QrAdvancedSection(
            settings: _settings,
            enabled: true,
            onSave: _updateSettings,
            onTestOpen: _open,
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Mã QR gọi món',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }
}
