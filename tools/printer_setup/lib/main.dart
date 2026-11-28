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
  final _ipCtl = TextEditingController();
  PrinterRole _helpRole = PrinterRole.thuNgan;
  int _helpPaper = 80;
  bool _helpOpen = false; // tự mở mục trợ giúp khi không tìm thấy máy hoặc cài lỗi
  List<DetectedPrinter> _usbPorts = [];

  String get _store => _storeCtl.text.trim();

  @override
  void initState() {
    super.initState();
    _loadStoreName();
  }

  @override
  void dispose() {
    _storeCtl.dispose();
    _ipCtl.dispose();
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
        _step('Không thấy máy in nào. Hãy bật máy in, kiểm tra dây USB/mạng rồi bấm lại, hoặc xem mục "Cần trợ giúp?" bên dưới.');
        if (mounted) setState(() => _helpOpen = true);
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
    final installed = <Assignment>[];
    for (final a in list) {
      final qn = a.role.queueName(_store);
      _step('Đang cài máy in ${a.role.shortLabel}…');
      final err = await PrinterService.install(a.device, a.role, _store, paperMm: a.paperMm);
      if (err != null) {
        AppLog.error('Cài $qn thất bại: $err');
        _step('✗ Chưa cài được máy in ${a.role.shortLabel}. Xem mục "Cần trợ giúp?" bên dưới.');
        if (mounted) setState(() => _helpOpen = true);
        continue;
      }
      installed.add(a);
      _step('✓ Đã cài máy in ${a.role.shortLabel}');
    }
    final okCount = installed.length;
    if (okCount > 0) {
      // Cài xong tất cả mới in: mọi máy in tờ nhận diện CÙNG LÚC để chủ quán đứng nhìn và dán nhãn.
      _step('Đang in tờ nhận diện ở tất cả các máy…');
      final results = await Future.wait([
        for (final a in installed)
          PrinterService.identify(a.role, a.role.queueName(_store), storeName: _store),
      ]);
      for (var i = 0; i < installed.length; i++) {
        final qn = installed[i].role.queueName(_store);
        AppLog.info('Tờ nhận diện $qn: ${results[i] ? 'đã gửi' : 'KHÔNG gửi được'}');
        if (!results[i]) {
          _step('✗ Máy ${installed[i].role.shortLabel} chưa in được tờ nhận diện — kiểm tra giấy/nguồn máy in.');
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _assigned = list;
      _done = okCount > 0;
    });
    if (okCount > 0) {
      _step('Xong! Mỗi máy vừa in một tờ ghi to tên máy (THU NGAN, BEP, BAR…). Hãy ghi hoặc dán nhãn lên máy; nếu tờ nào ghi sai thì đổi vai trò bên dưới.');
    }
  }

  /// In lại tờ nhận biết ở mọi máy cùng lúc (khi chủ quán quên máy nào là máy nào).
  Future<void> _printAllSlips() async {
    setState(() => _running = true);
    try {
      final results = await Future.wait([
        for (final a in _assigned)
          PrinterService.identify(a.role, a.role.queueName(_store), storeName: _store),
      ]);
      final failed = [
        for (var i = 0; i < _assigned.length; i++)
          if (!results[i]) _assigned[i].role.shortLabel
      ];
      AppLog.info('In lại tờ nhận biết tất cả máy: ${failed.isEmpty ? 'đủ' : 'lỗi: ${failed.join(', ')}'}');
      _msg(failed.isEmpty
          ? 'Đã gửi tờ nhận biết tới tất cả các máy.'
          : 'Chưa in được ở máy: ${failed.join(', ')}. Kiểm tra giấy/nguồn.',
          error: failed.isNotEmpty);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  /// Cài thủ công một máy in theo cổng USB hoặc IP đã chọn, với vai trò/khổ giấy ở mục trợ giúp.
  Future<void> _installManual(DetectedPrinter dev) async {
    if (_store.isEmpty) {
      _msg('Hãy gõ tên quán ở ô phía trên trước.', error: true);
      return;
    }
    await StoreSettings.saveStoreName(_store);
    setState(() => _running = true);
    try {
      final role = _helpRole;
      final qn = role.queueName(_store);
      AppLog.info('Cài thủ công $qn: ${dev.detail}');
      final err = await PrinterService.install(dev, role, _store, paperMm: _helpPaper);
      if (err != null) {
        AppLog.error('Cài thủ công $qn thất bại: $err');
        _msg('Chưa cài được: $err. Bấm "Sao chép log" gửi hỗ trợ.', error: true);
        return;
      }
      final ok = await PrinterService.identify(role, qn, storeName: _store);
      final a = Assignment(dev, role, paperMm: _helpPaper);
      setState(() {
        _assigned.removeWhere((x) => x.role == role);
        _assigned.add(a);
        _assigned.sort((x, y) => x.role.index.compareTo(y.role.index));
        _done = true;
      });
      _msg(ok
          ? 'Đã cài "$qn" và in tờ nhận biết. Xem tờ giấy ra ở máy nào là máy đó.'
          : 'Đã cài "$qn" nhưng chưa in được tờ nhận biết. Kiểm tra giấy/nguồn máy in.');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _loadUsbPorts() async {
    final ports = await PrinterService.listUsbPorts();
    AppLog.info('Cổng USB hiện có: ${ports.map((e) => e.usbPort).join(', ')}');
    if (mounted) setState(() => _usbPorts = ports);
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
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _running ? null : _printAllSlips,
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('In tờ nhận biết máy ở TẤT CẢ các máy',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              for (final a in _assigned) _assignedCard(a),
            ],
            const SizedBox(height: 16),
            _helpCard(),
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

  Widget _helpCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey(_helpOpen),
        initiallyExpanded: _helpOpen,
        onExpansionChanged: (v) {
          if (v && _usbPorts.isEmpty) _loadUsbPorts();
        },
        leading: const Icon(Icons.support_agent_rounded, color: _kOrange),
        title: const Text('Cần trợ giúp? (máy in không được tìm thấy hoặc cài chưa được)',
            style: TextStyle(fontWeight: FontWeight.w800, color: _kIndigo)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chọn vai trò và khổ giấy cho máy in sẽ thêm thủ công:',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 8, children: [
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<PrinterRole>(
                isExpanded: true,
                initialValue: _helpRole,
                decoration: const InputDecoration(
                    labelText: 'Vai trò', isDense: true, border: OutlineInputBorder()),
                items: [
                  for (final r in PrinterRole.values)
                    DropdownMenuItem(value: r, child: Text(r.label, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _helpRole = v ?? _helpRole),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _helpPaper,
                decoration: const InputDecoration(
                    labelText: 'Khổ giấy', isDense: true, border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 80, child: Text('80 mm')),
                  DropdownMenuItem(value: 58, child: Text('58 mm')),
                ],
                onChanged: (v) => setState(() => _helpPaper = v ?? _helpPaper),
              ),
            ),
          ]),
          const Divider(height: 28),
          const Text('1. Máy in mạng (LAN/Wi-Fi): nhập địa chỉ IP',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Máy in bill thường cho in tờ thông tin có địa chỉ IP bằng cách giữ nút Feed khi bật nguồn.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _ipCtl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Địa chỉ IP', hintText: '192.168.1.240',
                    isDense: true, border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: (_running || !isValidIpv4(_ipCtl.text))
                  ? null
                  : () => _installManual(DetectedPrinter(
                        kind: DetectedKind.lan,
                        title: 'Máy in mạng',
                        detail: 'IP ${_ipCtl.text.trim()} (cổng 9100)',
                        ip: _ipCtl.text.trim(),
                      )),
              child: const Text('Cài theo IP'),
            ),
          ]),
          const Divider(height: 28),
          const Text('2. Máy in USB: chọn cổng Windows đã tạo',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Mỗi máy in USB chiếm một cổng USB001, USB002… Nếu không chắc máy nào ở cổng nào, thử từng cổng: tờ in ra ở máy nào là máy đó.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          const SizedBox(height: 8),
          if (_usbPorts.isEmpty)
            Row(children: [
              Text('Chưa thấy cổng USB nào.', style: TextStyle(color: Colors.grey.shade700)),
              TextButton(onPressed: _loadUsbPorts, child: const Text('Tải lại danh sách')),
            ])
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final d in _usbPorts)
                OutlinedButton(
                  onPressed: _running ? null : () => _installManual(d),
                  child: Text('Cài vào ${d.usbPort}'),
                ),
              TextButton(onPressed: _loadUsbPorts, child: const Text('Tải lại')),
            ]),
          const Divider(height: 28),
          const Text('3. Máy in cần driver của hãng (Windows không nhận ra máy in USB, máy in tem)',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Xem hãng và model ở nhãn dưới đáy máy, tải driver trên trang chính thức của hãng rồi cài. '
              'Sau đó trong Quán Nhỏ POS: In hoá đơn → Cấu Hình Trạm In → chọn máy in vừa cài.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => openWindowsTarget('ms-settings:printers'),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Mở cài đặt máy in của Windows'),
            ),
            OutlinedButton.icon(
              onPressed: () => openWindowsTarget('devmgmt.msc'),
              icon: const Icon(Icons.memory_rounded, size: 18),
              label: const Text('Mở Quản lý thiết bị'),
            ),
          ]),
          const Divider(height: 28),
          const Text('4. Nhờ hỗ trợ', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Bấm "Sao chép log" ở góc trên, rồi gửi kèm hãng và model máy in qua Zalo.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => openWindowsTarget('https://zalo.me/0927558888'),
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: const Text('Nhắn Zalo hỗ trợ (0927 55 8888)'),
          ),
        ],
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
                    final ok = await PrinterService.identify(a.role, qn, storeName: _store);
                    _msg(ok ? 'Đã gửi tờ in thử.' : 'Không in được. Kiểm tra giấy/nguồn máy in.', error: !ok);
                  },
            child: const Text('In tờ nhận biết máy'),
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
