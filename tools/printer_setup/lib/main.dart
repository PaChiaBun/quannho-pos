// Quán Nhỏ — Công cụ cài máy in (Windows). MỘT NÚT: tìm máy in, tự gán vai trò, cài, in tờ nhận diện.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_log.dart';
import 'auto_setup.dart';
import 'printer_service.dart';
import 'store_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) await AppLog.init();
  FlutterError.onError = (d) => AppLog.error('Flutter: ${d.exceptionAsString()}');
  runApp(const SetupApp());
}

const _kIndigo = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kGreen = Color(0xFF16A34A);

class SetupApp extends StatelessWidget {
  const SetupApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Quán Nhỏ — Cài máy in',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _kIndigo),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF0F2F8),
        ),
        home: const SetupPage(),
      );
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  bool _running = false;
  bool _done = false;
  final List<String> _steps = []; // dòng tiến trình dễ hiểu cho chủ quán
  List<Assignment> _assigned = [];
  final _storeCtl = TextEditingController();
  bool _storeFromPos = false;

  String get _store => _storeCtl.text.trim();

  @override
  void initState() {
    super.initState();
    _loadStoreName();
  }

  @override
  void dispose() {
    _storeCtl.dispose();
    super.dispose();
  }

  /// Ưu tiên tên quán từ POS đã đăng nhập; không có thì dùng tên đã nhập lần trước.
  Future<void> _loadStoreName() async {
    final fromPos = await storeNameFromPos();
    final saved = fromPos.isNotEmpty ? fromPos : await StoreSettings.loadStoreName();
    if (!mounted) return;
    setState(() {
      _storeCtl.text = saved;
      _storeFromPos = fromPos.isNotEmpty;
    });
    AppLog.info('Tên quán: "${_storeCtl.text}" (${fromPos.isNotEmpty ? 'lấy từ POS' : 'đã lưu/nhập tay'})');
  }

  void _step(String s) {
    AppLog.info('Bước: $s');
    if (mounted) setState(() => _steps.add(s));
  }

  void _msg(String m, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: error ? Colors.red.shade700 : _kIndigo,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
    ));
  }

  /// MỘT NÚT: dò → gán vai trò → cài → in tờ nhận diện.
  Future<void> _runAll() async {
    if (_store.isEmpty) {
      _msg('Hãy gõ tên quán vào ô phía trên rồi bấm lại.', error: true);
      return;
    }
    await StoreSettings.saveStoreName(_store);
    setState(() {
      _running = true;
      _done = false;
      _steps.clear();
      _assigned = [];
    });
    try {
      _step('Đang tìm máy in (USB và mạng)… mất khoảng 20 giây');
      final usb = await PrinterService.scanUsb();
      final lan = await PrinterService.scanLan();
      final devices = [...usb, ...lan];
      if (devices.isEmpty) {
        _step('Không thấy máy in nào. Hãy bật máy in, kiểm tra dây USB/mạng rồi bấm lại.');
        return;
      }
      _step('Tìm thấy ${devices.length} máy in.');
      final existing = await PrinterService.listQueues();
      final list = assignRoles(devices, existing);
      await _installAll(list, existing);
    } catch (e, st) {
      AppLog.error('runAll: $e\n$st');
      _step('Có lỗi: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _installAll(List<Assignment> list, List<InstalledQueue> existing) async {
    // Dọn máy in QN-… cũ nằm trên cùng cổng hoặc trùng tên để không bị nhân đôi.
    final keys = {for (final a in list) deviceKey(a.device)};
    final names = {for (final a in list) a.role.queueName(_store)};
    for (final q in existing) {
      if (q.isQn && (keys.contains(q.port) || names.contains(q.name))) {
        await PrinterService.remove(q.name);
      }
    }
    var okCount = 0;
    for (final a in list) {
      final qn = a.role.queueName(_store);
      _step('Đang cài máy in ${a.role.shortLabel}…');
      final err = await PrinterService.install(a.device, a.role, _store, paperMm: a.paperMm);
      if (err != null) {
        AppLog.error('Cài $qn thất bại: $err');
        _step('✗ Chưa cài được máy in ${a.role.shortLabel}. Bấm "Sao chép log" gửi hỗ trợ.');
        continue;
      }
      final printed = await PrinterService.identify(a.role, qn);
      AppLog.info('Cài $qn xong; in tờ nhận diện: ${printed ? 'được' : 'KHÔNG được'}');
      okCount++;
      _step(printed
          ? '✓ ${a.role.shortLabel}: đã cài và in tờ nhận diện'
          : '✓ ${a.role.shortLabel}: đã cài (chưa in được tờ nhận diện — kiểm tra giấy/nguồn)');
    }
    if (!mounted) return;
    setState(() {
      _assigned = list;
      _done = okCount > 0;
    });
    if (okCount > 0) {
      _step('Xong! Xem tờ giấy vừa in ra ở mỗi máy: nếu đúng vai trò thì không cần làm gì thêm.');
    }
  }

  Future<void> _reapply() async {
    setState(() => _running = true);
    try {
      final existing = await PrinterService.listQueues();
      _steps.clear();
      await _installAll(_assigned, existing);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return const Scaffold(body: Center(child: Text('Công cụ này chỉ chạy trên Windows.')));
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kIndigo,
        foregroundColor: Colors.white,
        title: const Text('Quán Nhỏ — Cài máy in', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: AppLog.openFolder,
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: const Text('Mở thư mục log'),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () async {
              final t = await AppLog.readToday();
              await Clipboard.setData(ClipboardData(text: t.isEmpty ? '(chưa có log)' : t));
              _msg('Đã sao chép log hôm nay — dán gửi cho bộ phận hỗ trợ.');
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Sao chép log'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            _Card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Cắm máy in, bật nguồn rồi bấm nút bên dưới.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kIndigo)),
                const SizedBox(height: 14),
                TextField(
                  controller: _storeCtl,
                  enabled: !_running,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Tên quán',
                    hintText: 'Ví dụ: KAY - Rạch Giá',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    helperText: _store.isEmpty
                        ? 'Gõ tên quán một lần, tên này được gắn vào tên máy in cho dễ nhận biết.'
                        : '${_storeFromPos ? 'Lấy từ phần mềm Quán Nhỏ POS. ' : ''}'
                            'Máy in sẽ có tên: ${PrinterRole.thuNgan.queueName(_store)}…',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _kOrange),
                    onPressed: _running ? null : _runAll,
                    icon: _running
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                        : const Icon(Icons.print_rounded, size: 28),
                    label: Text(
                      _running ? 'Đang cài, vui lòng chờ…' : (_done ? 'Cài lại từ đầu' : 'CÀI MÁY IN'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ]),
            ),
            if (_steps.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Card(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final s in _steps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(s,
                          style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: s.startsWith('✗') ? Colors.red.shade700 : null,
                              fontWeight: s.startsWith('Xong') ? FontWeight.w800 : null)),
                    ),
                ]),
              ),
            ],
            if (_assigned.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Máy in đã cài',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kIndigo)),
              const SizedBox(height: 4),
              Text('Chỉ cần chỉnh nếu tờ giấy in ra ở máy nào ghi sai vai trò.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
              const SizedBox(height: 8),
              for (final a in _assigned) _assignedCard(a),
            ],
            const SizedBox(height: 24),
            Text(
              'Sau khi cài xong, mở Quán Nhỏ POS và bấm in như bình thường — POS tự dùng các máy in QN-… này, '
              'bạn không phải chọn hay cài driver.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _assignedCard(Assignment a) {
    final qn = a.role.queueName(_store);
    final d = a.device;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(d.kind == DetectedKind.usb ? Icons.usb_rounded : Icons.wifi_rounded,
              size: 28, color: _kGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.role.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('${d.title} · ${d.detail}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              Text(qn, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<PrinterRole>(
              isExpanded: true,
              initialValue: a.role,
              decoration: const InputDecoration(
                  labelText: 'Đổi vai trò (nếu sai)', isDense: true, border: OutlineInputBorder()),
              items: [
                for (final r in PrinterRole.values)
                  DropdownMenuItem(value: r, child: Text(r.label, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: _running
                  ? null
                  : (v) {
                      if (v == null || v == a.role) return;
                      setState(() => changeRole(_assigned, a, v));
                      _reapply();
                    },
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: a.paperMm,
              decoration: const InputDecoration(
                  labelText: 'Khổ giấy', isDense: true, border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 80, child: Text('80 mm (phổ biến)')),
                DropdownMenuItem(value: 58, child: Text('58 mm (nhỏ)')),
              ],
              onChanged: _running
                  ? null
                  : (v) {
                      if (v == null || v == a.paperMm) return;
                      setState(() => a.paperMm = v);
                      _reapply();
                    },
            ),
          ),
          OutlinedButton(
            onPressed: _running
                ? null
                : () async {
                    final ok = await PrinterService.identify(a.role, qn);
                    _msg(ok ? 'Đã gửi tờ in thử.' : 'Không in được. Kiểm tra giấy/nguồn máy in.', error: !ok);
                  },
            child: const Text('In thử'),
          ),
          if (a.role == PrinterRole.thuNgan)
            OutlinedButton(
              onPressed: _running
                  ? null
                  : () async {
                      final ok = await PrinterService.kickDrawer(qn);
                      _msg(ok ? 'Đã gửi lệnh mở két. Két có mở không?' : 'Không gửi được lệnh mở két.',
                          error: !ok);
                    },
              child: const Text('Mở két thử'),
            ),
        ]),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
        ),
        child: child,
      );
}
