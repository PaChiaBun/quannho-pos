// Quán Nhỏ — Công cụ cài máy in (Windows). Một nút: tìm máy in, chọn vai trò, cài và in thử.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_log.dart';
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
  bool _scanning = false;
  String _status = 'Cắm máy in vào máy tính (hoặc bật máy in mạng) rồi bấm "Tìm máy in".';
  List<DetectedPrinter> _found = [];
  List<InstalledQueue> _queues = [];
  final Map<int, PrinterRole> _roles = {};
  final Set<int> _busy = {};
  final _storeCtl = TextEditingController();

  String get _store => _storeCtl.text.trim();

  @override
  void initState() {
    super.initState();
    StoreSettings.loadStoreName().then((n) {
      if (mounted) setState(() => _storeCtl.text = n);
    });
    _refreshQueues();
  }

  @override
  void dispose() {
    _storeCtl.dispose();
    super.dispose();
  }

  Future<void> _refreshQueues() async {
    final q = await PrinterService.listQueues();
    if (mounted) setState(() => _queues = q.where((e) => e.isQn).toList());
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _status = 'Đang tìm máy in USB...';
      _found = [];
    });
    final usb = await PrinterService.scanUsb();
    if (!mounted) return;
    setState(() => _status = 'Đang tìm máy in mạng (mất khoảng 10–20 giây)...');
    final lan = await PrinterService.scanLan(onProgress: (d, t) {
      if (mounted && d % 64 == 0) {
        setState(() => _status = 'Đang tìm máy in mạng... ${(d * 100 ~/ t)}%');
      }
    });
    if (!mounted) return;
    final all = [...usb, ...lan];
    setState(() {
      _scanning = false;
      _found = all;
      _roles.clear();
      _status = all.isEmpty
          ? 'Chưa thấy máy in nào. Kiểm tra dây USB/mạng, bật nguồn máy in rồi bấm tìm lại.'
          : 'Tìm thấy ${all.length} máy in. Chọn máy này dùng để làm gì rồi bấm "Cài và in thử".';
    });
  }

  Future<void> _install(int i) async {
    final dev = _found[i];
    final role = _roles[i];
    if (role == null) return;
    if (_store.isEmpty) {
      _msg('Hãy nhập tên quán ở Bước 1 trước khi cài máy in.', error: true);
      return;
    }
    await StoreSettings.saveStoreName(_store);
    final qn = role.queueName(_store);
    setState(() => _busy.add(i));
    final err = await PrinterService.install(dev, role, _store);
    if (err != null) {
      AppLog.error('Cài $qn thất bại: $err');
      if (mounted) {
        setState(() => _busy.remove(i));
        _msg('Chưa cài được: $err', error: true);
      }
      return;
    }
    final printed = await PrinterService.identify(role, qn);
    AppLog.info('Cài $qn xong; in tờ nhận diện: ${printed ? 'được' : 'KHÔNG được'}');
    await _refreshQueues();
    if (!mounted) return;
    setState(() => _busy.remove(i));
    _msg(printed
        ? 'Đã cài "$qn". Máy in vừa in một tờ nhận diện — đúng máy chưa?'
        : 'Đã cài "$qn" nhưng chưa in được tờ thử. Kiểm tra giấy/nguồn máy in.');
  }

  void _msg(String m, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: error ? Colors.red.shade700 : _kIndigo,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
    ));
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
                const Text('Bước 1 — Nhập tên quán và tìm máy in',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kIndigo)),
                const SizedBox(height: 12),
                TextField(
                  controller: _storeCtl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Tên quán (kèm vào tên máy in cho dễ nhận biết)',
                    hintText: 'Ví dụ: KAY - Rạch Giá',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    helperText: _store.isEmpty
                        ? null
                        : 'Máy in sẽ có tên dạng: ${PrinterRole.thuNgan.queueName(_store)}',
                  ),
                ),
                const SizedBox(height: 12),
                Text(_status, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
                const SizedBox(height: 14),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _kOrange),
                    onPressed: _scanning ? null : _scan,
                    icon: _scanning
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search_rounded),
                    label: Text(_scanning ? 'Đang tìm...' : 'Tìm máy in',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
            if (_found.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Bước 2 — Chọn vai trò và cài',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kIndigo)),
              const SizedBox(height: 8),
              for (var i = 0; i < _found.length; i++) _deviceCard(i),
            ],
            if (_queues.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Máy in đã cài cho Quán Nhỏ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kIndigo)),
              const SizedBox(height: 8),
              for (final q in _queues) _queueCard(q),
            ],
            const SizedBox(height: 24),
            Text(
              'Máy in được đặt tên theo mẫu QN-<Tên quán>-<Vai trò> (ví dụ QN-KAY-Rach-Gia-ThuNgan). Trong Quán Nhỏ POS, '
              'ở mục máy in hệ thống chỉ cần chọn đúng máy in có tên QN-... này, không phải gõ tên hay cài driver.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _deviceCard(int i) {
    final d = _found[i];
    final busy = _busy.contains(i);
    return _Card(
      child: Row(children: [
        Icon(d.kind == DetectedKind.usb ? Icons.usb_rounded : Icons.wifi_rounded,
            size: 30, color: _kIndigo),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(d.detail, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 230,
          child: DropdownButtonFormField<PrinterRole>(
            isExpanded: true,
            initialValue: _roles[i],
            decoration: const InputDecoration(
                labelText: 'Máy này dùng để', isDense: true, border: OutlineInputBorder()),
            items: [
              for (final r in PrinterRole.values)
                DropdownMenuItem(value: r, child: Text(r.label, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => v == null ? _roles.remove(i) : _roles[i] = v),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: (_roles[i] == null || busy) ? null : () => _install(i),
          child: busy
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Cài và in thử'),
        ),
      ]),
    );
  }

  Widget _queueCard(InstalledQueue q) {
    final role = q.role;
    return _Card(
      child: Row(children: [
        const Icon(Icons.print_rounded, color: Colors.green, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('Cổng ${q.port}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
          ]),
        ),
        if (role != null) ...[
          OutlinedButton(
            onPressed: () async {
              final ok = await PrinterService.identify(role, q.name);
              _msg(ok ? 'Đã gửi tờ in thử.' : 'Không in được. Kiểm tra máy in.', error: !ok);
            },
            child: const Text('In thử'),
          ),
          if (role == PrinterRole.thuNgan) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final ok = await PrinterService.kickDrawer(q.name);
                _msg(ok ? 'Đã gửi lệnh mở két. Két có mở không?' : 'Không gửi được lệnh mở két.',
                    error: !ok);
              },
              child: const Text('Mở két thử'),
            ),
          ],
        ],
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Gỡ máy in này',
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          onPressed: () async {
            final err = await PrinterService.remove(q.name);
            await _refreshQueues();
            if (err != null) _msg('Chưa gỡ được: $err', error: true);
          },
        ),
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
