// lib/modules/bill_printer/screens/print_rules_screen.dart
// Màn hình "Máy In & Luật In": chủ quán tự khai báo máy in, đặt luật in và xem trước
// đường đi của từng loại phiếu. Dữ liệu là PrintSetup (xem routing/print_setup.dart).
// Chưa có thiết lập -> quán vẫn dùng 4 trạm cũ ("Cấu Hình Trạm In").

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../providers/printer_settings_provider.dart';
import '../routing/legacy_print_setup.dart';
import '../routing/print_setup.dart';
import '../drivers/sunmi_builtin_driver.dart';

const _kIndigo = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);

String jobTypeLabel(PrintJobType t) => switch (t) {
      PrintJobType.receipt => 'Hóa đơn thanh toán',
      PrintJobType.provisional => 'Phiếu tạm tính',
      PrintJobType.kitchenHot => 'Phiếu bếp nóng',
      PrintJobType.kitchenBar => 'Phiếu bếp bar',
      PrintJobType.label => 'Tem / nhãn dán ly',
      PrintJobType.report => 'Báo cáo',
    };

String serviceTypeLabel(PrintServiceType t) => switch (t) {
      PrintServiceType.dineIn => 'Ăn tại bàn',
      PrintServiceType.takeaway => 'Mang đi',
      PrintServiceType.qr => 'Đặt qua QR',
      PrintServiceType.delivery => 'Giao hàng',
    };

String printerKindLabel(PrinterKind k) => switch (k) {
      PrinterKind.system => 'Máy in hệ thống (Windows/Mac)',
      PrinterKind.lan => 'Máy in mạng LAN / Wi-Fi (IP)',
      PrinterKind.sunmiBuiltin => 'Máy in tích hợp Sunmi',
    };

String paperLabel(PaperWidth p) => switch (p) {
      PaperWidth.mm50 => '50 mm',
      PaperWidth.mm58 => '58 mm',
      PaperWidth.mm80 => '80 mm',
    };

class PrintRulesScreen extends ConsumerStatefulWidget {
  const PrintRulesScreen({super.key});

  @override
  ConsumerState<PrintRulesScreen> createState() => _PrintRulesScreenState();
}

class _PrintRulesScreenState extends ConsumerState<PrintRulesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  PrintSetup? _draft; // bản đang sửa; null = chưa sửa gì
  bool _saving = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _dirty => _draft != null;

  void _update(PrintSetup s) => setState(() => _draft = s);

  Future<void> _save() async {
    final d = _draft;
    if (d == null) return;
    setState(() => _saving = true);
    await ref.read(printerSettingsProvider.notifier).savePrintSetup(d);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _draft = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu thiết lập in')),
    );
  }

  LegacyStation _ls(PrinterConfig c) =>
      LegacyStation(name: c.name, type: c.type, enabled: c.enabled);

  bool _canSeed(StationPrintersState st) => legacyHasAnyStation(
        cashier: _ls(st.cashier),
        bepNong: _ls(st.bepNong),
        bepBar: _ls(st.bepBar),
        barLabel: _ls(st.barLabel),
      );

  PrintSetup _legacySeed() {
    final st = ref.read(printerSettingsProvider);
    return legacyToPrintSetup(
      cashier: _ls(st.cashier),
      bepNong: _ls(st.bepNong),
      bepBar: _ls(st.bepBar),
      barLabel: _ls(st.barLabel),
    );
  }

  void _seedFromLegacy() => _update(_legacySeed());

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(printerSettingsProvider);
    final setup = _draft ?? st.printSetup;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: _kIndigo,
        foregroundColor: Colors.white,
        title: Text('Máy In & Luật In',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          if (_dirty)
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, color: Colors.white),
              label: const Text('Lưu', style: TextStyle(color: Colors.white)),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _kOrange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Máy in (${setup.printers.length})'),
            Tab(text: 'Luật in (${setup.rules.length})'),
          ],
        ),
      ),
      body: Column(children: [
        _StatusBanner(
          setup: setup,
          dirty: _dirty,
          canSeed: _canSeed(st),
          onSeed: _seedFromLegacy,
          onReset: () => _update(const PrintSetup()),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _PrintersTab(
              setup: setup,
              state: st,
              onChanged: _update,
              seedFromLegacy: _canSeed(st) ? _legacySeed : null,
            ),
            _RulesTab(setup: setup, deviceId: st.currentDeviceId, onChanged: _update),
          ]),
        ),
      ]),
    );
  }
}

// ── Banner trạng thái ──────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final PrintSetup setup;
  final bool dirty;
  final bool canSeed;
  final VoidCallback onSeed;
  final VoidCallback onReset;
  const _StatusBanner({
    required this.setup,
    required this.dirty,
    required this.canSeed,
    required this.onSeed,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final empty = setup.isEmpty;
    final color = empty ? const Color(0xFFFFF4E0) : const Color(0xFFE6F6EC);
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Icon(empty ? Icons.info_outline_rounded : Icons.check_circle_rounded,
              color: empty ? const Color(0xFFB45309) : const Color(0xFF15803D), size: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(
              empty
                  ? (canSeed
                      ? 'Chưa dùng thiết lập mới: quán đang in theo 4 trạm cũ (Cấu Hình Trạm In). '
                          'Thêm máy in và luật rồi bấm Lưu để chuyển sang dùng luật in.'
                      : 'Quán chưa cấu hình máy in nào. Bắt đầu bằng "Thêm máy in" ở tab Máy in, '
                          'rồi tạo luật in ở tab Luật in.')
                  : 'Đang dùng luật in. Loại phiếu nào không có luật thì sẽ KHÔNG in. '
                      'Muốn quay lại cách cũ, bấm "Bỏ thiết lập mới" rồi Lưu.',
              style: GoogleFonts.outfit(fontSize: 13),
            ),
          ),
          if (empty && canSeed)
            OutlinedButton.icon(
              onPressed: onSeed,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: const Text('Dựng từ cấu hình hiện tại'),
            )
          else if (!empty)
            TextButton(onPressed: onReset, child: const Text('Bỏ thiết lập mới')),
          if (dirty)
            Text('Chưa lưu',
                style: GoogleFonts.outfit(
                    fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFB45309))),
        ],
      ),
    );
  }
}

// ── Tab Máy in ─────────────────────────────────────────────────────────────────
class _PrintersTab extends StatelessWidget {
  final PrintSetup setup;
  final StationPrintersState state;
  final ValueChanged<PrintSetup> onChanged;
  final PrintSetup Function()? seedFromLegacy;
  const _PrintersTab({
    required this.setup,
    required this.state,
    required this.onChanged,
    required this.seedFromLegacy,
  });

  void _replace(PrinterEntry p) {
    final list = [...setup.printers];
    final i = list.indexWhere((e) => e.id == p.id);
    if (i >= 0) {
      list[i] = p;
    } else {
      list.add(p);
    }
    onChanged(PrintSetup(printers: list, rules: setup.rules));
  }

  Future<void> _remove(BuildContext context, PrinterEntry p) async {
    final used = setup.rules.any((r) =>
        r.targets.any((t) => t.printerId == p.id) || r.fallbackPrinterId == p.id);
    if (used) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máy in đang được dùng trong một luật, hãy sửa luật trước.')),
      );
      return;
    }
    onChanged(PrintSetup(
      printers: setup.printers.where((e) => e.id != p.id).toList(),
      rules: setup.rules,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _ThisDeviceSection(
            setup: setup,
            state: state,
            onChanged: onChanged,
            seedFromLegacy: seedFromLegacy,
          ),
          const SizedBox(height: 16),
          if (setup.printers.isEmpty)
            const _EmptyHint(
              icon: Icons.print_disabled_rounded,
              text: 'Chưa có máy in nào. Bấm "Thêm máy in" để khai báo máy in thu ngân, bếp, bar...',
            ),
          for (final p in setup.printers)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  p.kind == PrinterKind.lan
                      ? Icons.wifi_rounded
                      : p.kind == PrinterKind.sunmiBuiltin
                          ? Icons.phone_android_rounded
                          : Icons.print_rounded,
                  color: p.enabled ? _kIndigo : Colors.grey,
                ),
                title: Text(p.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${printerKindLabel(p.kind)}'
                  '${p.address.isNotEmpty ? ' • ${p.address}${p.kind == PrinterKind.lan ? ':${p.port}' : ''}' : ''}'
                  ' • ${paperLabel(p.paper)}'
                  '${p.fontScale != 1.0 ? ' • chữ ${(p.fontScale * 100).round()}%' : ''}'
                  '${p.kind == PrinterKind.sunmiBuiltin && p.darkness != 3 ? ' • độ đậm ${p.darkness}/5' : ''}'
                  '${p.autoCut ? ' • tự cắt' : ''}${p.hasCashDrawer ? ' • có két' : ''}'
                  '${p.kind == PrinterKind.sunmiBuiltin && !SunmiBuiltinDriver.isSupportedPlatform ? '\nChỉ in được trên thiết bị Sunmi (Android)' : ''}',
                  style: GoogleFonts.outfit(fontSize: 12.5),
                ),
                isThreeLine: p.kind == PrinterKind.sunmiBuiltin && !SunmiBuiltinDriver.isSupportedPlatform,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Switch(value: p.enabled, onChanged: (v) => _replace(_copy(p, enabled: v))),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () async {
                      final r = await showDialog<PrinterEntry>(
                          context: context, builder: (_) => _PrinterDialog(initial: p));
                      if (r != null) _replace(r);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => _remove(context, p),
                  ),
                ]),
              ),
            ),
        ],
      ),
      Positioned(
        right: 16, bottom: 16,
        child: FloatingActionButton.extended(
          backgroundColor: _kOrange,
          foregroundColor: Colors.white,
          onPressed: () async {
            final r = await showDialog<PrinterEntry>(
                context: context, builder: (_) => const _PrinterDialog());
            if (r != null) _replace(r);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Thêm máy in'),
        ),
      ),
    ]);
  }

  PrinterEntry _copy(PrinterEntry p, {bool? enabled}) => PrinterEntry(
        id: p.id, name: p.name, kind: p.kind, address: p.address, port: p.port,
        paper: p.paper, autoCut: p.autoCut, hasCashDrawer: p.hasCashDrawer,
        ownerDeviceId: p.ownerDeviceId, enabled: enabled ?? p.enabled,
        fontScale: p.fontScale, darkness: p.darkness, softBold: p.softBold,
      );
}

class _PrinterDialog extends StatefulWidget {
  final PrinterEntry? initial;
  const _PrinterDialog({this.initial});

  @override
  State<_PrinterDialog> createState() => _PrinterDialogState();
}

class _PrinterDialogState extends State<_PrinterDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _addr =
      TextEditingController(text: widget.initial?.address ?? '');
  late final TextEditingController _port =
      TextEditingController(text: '${widget.initial?.port ?? 9100}');
  late PrinterKind _kind = widget.initial?.kind ?? PrinterKind.system;
  late PaperWidth _paper = widget.initial?.paper ?? PaperWidth.mm80;
  late bool _cut = widget.initial?.autoCut ?? true;
  late bool _drawer = widget.initial?.hasCashDrawer ?? false;
  late double _scale = widget.initial?.fontScale ?? 1.0;
  late int _darkness = widget.initial?.darkness ?? 3;
  late bool _softBold = widget.initial?.softBold ?? false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _addr.dispose();
    _port.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _err = 'Hãy đặt tên cho máy in.');
    final addr = _addr.text.trim();
    if (_kind == PrinterKind.lan && addr.isEmpty) {
      return setState(() => _err = 'Máy in mạng cần địa chỉ IP, ví dụ 192.168.1.242.');
    }
    final port = int.tryParse(_port.text.trim()) ?? 9100;
    if (port < 1 || port > 65535) return setState(() => _err = 'Cổng không hợp lệ.');
    Navigator.pop(
      context,
      PrinterEntry(
        id: widget.initial?.id ?? const Uuid().v4(),
        name: name,
        kind: _kind,
        address: _kind == PrinterKind.sunmiBuiltin ? '' : addr,
        port: port,
        paper: _paper,
        autoCut: _cut,
        hasCashDrawer: _drawer,
        ownerDeviceId: widget.initial?.ownerDeviceId,
        enabled: widget.initial?.enabled ?? true,
        fontScale: _scale,
        darkness: _darkness,
        softBold: _softBold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Thêm máy in' : 'Sửa máy in'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên máy in (vd: Bill quầy, Bếp nóng)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PrinterKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Cách kết nối'),
              items: [
                for (final k in PrinterKind.values)
                  DropdownMenuItem(value: k, child: Text(printerKindLabel(k))),
              ],
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
            if (_kind != PrinterKind.sunmiBuiltin) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _addr,
                decoration: InputDecoration(
                  labelText: _kind == PrinterKind.lan
                      ? 'Địa chỉ IP (vd 192.168.1.242)'
                      : 'Tên máy in trong hệ thống (để trống = máy in mặc định)',
                ),
              ),
            ],
            if (_kind == PrinterKind.lan) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _port,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cổng (thường là 9100)'),
              ),
            ],
            if (_kind == PrinterKind.sunmiBuiltin)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Máy in tích hợp trên Sunmi V3: chỉ in được trên đúng thiết bị Sunmi (Android). '
                  'Thiết bị khác sẽ bỏ qua luật trỏ tới máy in này và dùng luật kế tiếp.',
                  style: TextStyle(color: Color(0xFFB45309), fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaperWidth>(
              initialValue: _paper,
              decoration: const InputDecoration(labelText: 'Khổ giấy'),
              items: [
                for (final p in PaperWidth.values)
                  DropdownMenuItem(value: p, child: Text(paperLabel(p))),
              ],
              onChanged: (v) => setState(() => _paper = v ?? _paper),
            ),
            const SizedBox(height: 8),
            Text('Tỉ lệ cỡ chữ khi in: ${(_scale * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(
              value: _scale,
              min: 0.5,
              max: 1.2,
              divisions: 14,
              label: '${(_scale * 100).round()}%',
              onChanged: (v) => setState(() => _scale = double.parse(v.toStringAsFixed(2))),
            ),
            const Text(
              'Nhỏ hơn 100% = chữ nhỏ lại, mỗi dòng chứa được nhiều chữ hơn. '
              'Dùng khi bill bị cụt mép hoặc chữ quá to trên giấy hẹp.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (_kind == PrinterKind.sunmiBuiltin) ...[
              const SizedBox(height: 4),
              Text(
                'Độ đậm nét chữ: ${const ['Rất mảnh', 'Mảnh', 'Vừa', 'Đậm', 'Rất đậm'][_darkness - 1]}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Slider(
                value: _darkness.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$_darkness',
                onChanged: (v) => setState(() => _darkness = v.round()),
              ),
              const Text(
                'Khuyến nghị cho Sunmi V3: Độ đậm Vừa (3) và hạ "Mật độ in" trong Cài đặt máy in '
                'của máy xuống 80% (nhiệt cao làm chữ đậm bị loe). Chữ mờ: kéo sang Đậm; chữ bết: kéo về Mảnh.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Chữ đậm dạng bán đậm'),
                subtitle: const Text(
                  'Mặc định tắt (Bold). Bật nếu chữ đậm bị loe, bết nét trên máy in này.',
                  style: TextStyle(fontSize: 12),
                ),
                value: _softBold,
                onChanged: (v) => setState(() => _softBold = v),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tự cắt giấy'),
              value: _cut,
              onChanged: (v) => setState(() => _cut = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Có két tiền gắn kèm'),
              value: _drawer,
              onChanged: (v) => setState(() => _drawer = v),
            ),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_err!, style: const TextStyle(color: Colors.redAccent)),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(onPressed: _submit, child: const Text('Xong')),
      ],
    );
  }
}

// ── Tab Luật in ────────────────────────────────────────────────────────────────
class _RulesTab extends StatelessWidget {
  final PrintSetup setup;
  final String deviceId;
  final ValueChanged<PrintSetup> onChanged;
  const _RulesTab({required this.setup, required this.deviceId, required this.onChanged});

  void _replace(PrintRule r) {
    final list = [...setup.rules];
    final i = list.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      list[i] = r;
    } else {
      list.add(r);
    }
    onChanged(PrintSetup(printers: setup.printers, rules: list));
  }

  String _sentence(PrintRule r) {
    String pn(String id) => setup.printerById(id)?.name ?? '(máy in đã xóa)';
    final cond = <String>[
      if (r.serviceTypes.isNotEmpty) r.serviceTypes.map(serviceTypeLabel).join(' / '),
      if (r.sourceDeviceIds.isNotEmpty) 'chỉ trên thiết bị đã chọn',
    ];
    final targets = r.targets.isEmpty
        ? 'không in'
        : r.targets.map((t) => '${pn(t.printerId)}${t.copies > 1 ? ' ×${t.copies}' : ''}').join(', ');
    final fb = r.fallbackPrinterId == null ? '' : ' • dự phòng: ${pn(r.fallbackPrinterId!)}';
    return 'Khi in ${jobTypeLabel(r.jobType)}'
        '${cond.isEmpty ? '' : ' (${cond.join(', ')})'} → $targets$fb';
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...setup.rules]..sort((a, b) => a.priority.compareTo(b.priority));
    return Stack(children: [
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (setup.rules.isEmpty)
            const _EmptyHint(
              icon: Icons.rule_rounded,
              text: 'Chưa có luật nào. Luật cho biết mỗi loại phiếu in ra máy nào, mấy bản.',
            ),
          for (final r in sorted)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(r.name.isEmpty ? jobTypeLabel(r.jobType) : r.name,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                subtitle: Text('${_sentence(r)}\nƯu tiên ${r.priority} (số nhỏ chạy trước)',
                    style: GoogleFonts.outfit(fontSize: 12.5)),
                isThreeLine: true,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Switch(
                    value: r.enabled,
                    onChanged: (v) => _replace(PrintRule(
                      id: r.id, name: r.name, jobType: r.jobType, serviceTypes: r.serviceTypes,
                      zoneIds: r.zoneIds, sourceDeviceIds: r.sourceDeviceIds, targets: r.targets,
                      fallbackPrinterId: r.fallbackPrinterId, priority: r.priority, enabled: v,
                    )),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () async {
                      final x = await showDialog<PrintRule>(
                        context: context,
                        builder: (_) => _RuleDialog(setup: setup, deviceId: deviceId, initial: r),
                      );
                      if (x != null) _replace(x);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: () => onChanged(PrintSetup(
                      printers: setup.printers,
                      rules: setup.rules.where((e) => e.id != r.id).toList(),
                    )),
                  ),
                ]),
              ),
            ),
        ],
      ),
      Positioned(
        right: 16, bottom: 16,
        child: FloatingActionButton.extended(
          backgroundColor: _kOrange,
          foregroundColor: Colors.white,
          onPressed: () async {
            if (setup.printers.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hãy thêm máy in trước khi tạo luật.')),
              );
              return;
            }
            final x = await showDialog<PrintRule>(
              context: context,
              builder: (_) => _RuleDialog(setup: setup, deviceId: deviceId),
            );
            if (x != null) _replace(x);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Thêm luật'),
        ),
      ),
    ]);
  }
}

class _RuleDialog extends StatefulWidget {
  final PrintSetup setup;
  final String deviceId;
  final PrintRule? initial;
  const _RuleDialog({required this.setup, required this.deviceId, this.initial});

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late PrintJobType _job = widget.initial?.jobType ?? PrintJobType.receipt;
  late Set<PrintServiceType> _services = {...?widget.initial?.serviceTypes};
  late bool _onlyThisDevice = widget.deviceId.isNotEmpty &&
      (widget.initial?.sourceDeviceIds.contains(widget.deviceId) ?? false);
  late String? _printerId = widget.initial?.targets.firstOrNull?.printerId ??
      widget.setup.printers.firstOrNull?.id;
  late int _copies = widget.initial?.targets.firstOrNull?.copies ?? 1;
  late String? _fallback = widget.initial?.fallbackPrinterId;
  late int _priority = widget.initial?.priority ?? 100;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_printerId == null) return setState(() => _err = 'Hãy chọn máy in.');
    final old = widget.initial;
    Navigator.pop(
      context,
      PrintRule(
        id: old?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        jobType: _job,
        serviceTypes: _services,
        zoneIds: old?.zoneIds ?? const {},
        sourceDeviceIds: _onlyThisDevice
            ? {widget.deviceId}
            : (old?.sourceDeviceIds.where((e) => e != widget.deviceId).toSet() ?? const {}),
        targets: [
          PrintTarget(
            printerId: _printerId!,
            copies: _copies,
            templateKey: old?.targets.firstOrNull?.templateKey,
          ),
        ],
        fallbackPrinterId: _fallback == _printerId ? null : _fallback,
        priority: _priority,
        enabled: old?.enabled ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final printers = widget.setup.printers;
    return AlertDialog(
      title: Text(widget.initial == null ? 'Thêm luật in' : 'Sửa luật in'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên luật (không bắt buộc)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PrintJobType>(
              initialValue: _job,
              decoration: const InputDecoration(labelText: 'Loại phiếu'),
              items: [
                for (final j in PrintJobType.values)
                  DropdownMenuItem(value: j, child: Text(jobTypeLabel(j))),
              ],
              onChanged: (v) => setState(() => _job = v ?? _job),
            ),
            const SizedBox(height: 12),
            Text('Chỉ áp dụng cho hình thức (không chọn = tất cả)',
                style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.black54)),
            Wrap(spacing: 8, children: [
              for (final s in PrintServiceType.values)
                FilterChip(
                  label: Text(serviceTypeLabel(s)),
                  selected: _services.contains(s),
                  onSelected: (v) => setState(() {
                    _services = {..._services};
                    v ? _services.add(s) : _services.remove(s);
                  }),
                ),
            ]),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _onlyThisDevice,
              onChanged: widget.deviceId.isEmpty
                  ? null
                  : (v) => setState(() => _onlyThisDevice = v ?? false),
              title: const Text('Chỉ khi thao tác trên thiết bị này'),
              subtitle: widget.deviceId.isEmpty
                  ? const Text('Chưa nhận diện được thiết bị này')
                  : null,
            ),
            const Divider(),
            DropdownButtonFormField<String>(
              initialValue: _printerId,
              decoration: const InputDecoration(labelText: 'In ra máy'),
              items: [for (final p in printers) DropdownMenuItem(value: p.id, child: Text(p.name))],
              onChanged: (v) => setState(() => _printerId = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Số bản:'),
              IconButton(
                  onPressed: _copies > 1 ? () => setState(() => _copies--) : null,
                  icon: const Icon(Icons.remove_circle_outline)),
              Text('$_copies', style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(
                  onPressed: _copies < 9 ? () => setState(() => _copies++) : null,
                  icon: const Icon(Icons.add_circle_outline)),
            ]),
            DropdownButtonFormField<String?>(
              initialValue: _fallback,
              decoration: const InputDecoration(labelText: 'Máy dự phòng (khi máy trên bị tắt)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Không có')),
                for (final p in printers) DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _fallback = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Ưu tiên:'),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: '$_priority',
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _priority = int.tryParse(v) ?? _priority,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Số nhỏ chạy trước. Luật cụ thể hơn thắng khi bằng nhau.',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ]),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_err!, style: const TextStyle(color: Colors.redAccent)),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(onPressed: _submit, child: const Text('Xong')),
      ],
    );
  }
}

// ── Máy này in bill ra + máy in tích hợp (nằm đầu tab Máy in) ───────────────────────
const _kDeviceRulePrefix = kDeviceBillRulePrefix;

class _ThisDeviceSection extends StatelessWidget {
  final PrintSetup setup;
  final StationPrintersState state;
  final ValueChanged<PrintSetup> onChanged;
  final PrintSetup Function()? seedFromLegacy;
  const _ThisDeviceSection({
    required this.setup,
    required this.state,
    required this.onChanged,
    required this.seedFromLegacy,
  });

  String get _deviceId => state.currentDeviceId;
  String get _shortId => _deviceId.length >= 8 ? _deviceId.substring(0, 8) : _deviceId;

  bool _isDeviceRule(PrintRule r) =>
      r.id.startsWith('$_kDeviceRulePrefix$_shortId') &&
      r.sourceDeviceIds.contains(_deviceId);

  /// null = theo luật chung; '' = không in; còn lại = id máy in được chọn.
  String? get _current {
    PrintRule? r;
    for (final x in setup.rules) {
      if (_isDeviceRule(x) && x.jobType == PrintJobType.receipt) r = x;
    }
    if (r == null) return null;
    if (r.targets.isEmpty) return '';
    return r.targets.first.printerId;
  }

  List<PrintRule> _withoutDeviceRules() =>
      setup.rules.where((r) => !_isDeviceRule(r)).toList();

  /// Máy in tích hợp của máy này: ưu tiên máy đã khai báo (gắn đúng máy này hoặc chưa gắn máy nào).
  PrinterEntry? _findBuiltin(PrintSetup from) {
    for (final p in from.printers) {
      if (p.kind != PrinterKind.sunmiBuiltin) continue;
      final owner = p.ownerDeviceId;
      if (owner == null || owner.isEmpty || owner == _deviceId) return p;
    }
    return null;
  }

  Future<bool?> _confirmSeed(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Chuyển sang dùng Luật in?'),
      content: const Text(
        'Quán đang in theo 4 trạm cũ. Để đặt riêng cho máy này, app sẽ dựng sẵn máy in '
        'và luật từ cấu hình hiện tại (bếp, bar, bill vẫn in như cũ), rồi thêm một '
        'luật riêng cho máy này. Bạn vẫn phải bấm Lưu để áp dụng.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tiếp tục')),
      ],
    ),
  );

  /// Thiết lập nhanh. [mode]: 'win' = máy quầy in; 'pos' = máy này in, máy quầy nhường;
  /// 'dual' = bill ra cả máy này lẫn máy quầy.
  Future<void> _quick(BuildContext context, String mode) async {
    if (_deviceId.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    if (mode == 'win') {
      onChanged(PrintSetup(printers: setup.printers, rules: _withoutDeviceRules()));
      messenger.showSnackBar(const SnackBar(
        content: Text('Bill của máy này sẽ in ra máy in quầy (máy Windows). Bấm Lưu để áp dụng.'),
      ));
      return;
    }
    var base = setup;
    if (base.isEmpty) {
      final seeded = seedFromLegacy?.call();
      if (seeded != null && !seeded.isEmpty) {
        if (await _confirmSeed(context) != true) return;
        base = seeded;
      }
    }
    var builtin = _findBuiltin(base);
    if (builtin == null) {
      builtin = PrinterEntry(
        id: 'builtin_$_shortId',
        name: 'Máy in tích hợp – ${state.deviceState.deviceName}',
        kind: PrinterKind.sunmiBuiltin,
        paper: PaperWidth.mm50,
        ownerDeviceId: _deviceId,
        fontScale: 0.8,
      );
      base = PrintSetup(printers: [...base.printers, builtin], rules: base.rules);
    }
    await _choose(context, builtin.id, dual: mode == 'dual', baseOverride: base);
    messenger.showSnackBar(SnackBar(
      content: Text(mode == 'dual'
          ? 'Bill sẽ ra cả máy này và máy in quầy. Bấm Lưu để áp dụng.'
          : 'Bill thanh toán trên máy này sẽ in ra máy in tích hợp; máy quầy nhường. Bấm Lưu để áp dụng.'),
    ));
  }

  Future<void> _choose(
    BuildContext context,
    String? choice, {
    bool dual = false,
    PrintSetup? baseOverride,
  }) async {
    if (_deviceId.isEmpty) return;
    var base = baseOverride ?? setup;

    // Chọn "theo luật chung": chỉ gỡ luật riêng của máy này.
    if (choice == null) {
      onChanged(PrintSetup(printers: base.printers, rules: _withoutDeviceRules()));
      return;
    }

    // Quán chưa dùng thiết lập mới: dựng từ 4 trạm cũ trước để bếp/bar/bill
    // của các máy khác KHÔNG bị mất khi bật chế độ luật in.
    if (baseOverride == null && base.isEmpty) {
      final seeded = seedFromLegacy?.call();
      if (seeded != null && !seeded.isEmpty) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Chuyển sang dùng Luật in?'),
            content: const Text(
              'Quán đang in theo 4 trạm cũ. Để đặt riêng cho máy này, app sẽ dựng sẵn máy in '
              'và luật từ cấu hình hiện tại (bếp, bar, bill vẫn in như cũ), rồi thêm một '
              'luật riêng cho máy này. Bạn vẫn phải bấm Lưu để áp dụng.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tiếp tục')),
            ],
          ),
        );
        if (ok != true) return;
        base = seeded;
      }
    }

    final rules = [
      ...base.rules.where((r) => !_isDeviceRule(r)),
      for (final job in const [PrintJobType.receipt, PrintJobType.provisional])
        PrintRule(
          id: '$_kDeviceRulePrefix$_shortId${dual ? kDeviceBillDualMarker : '_'}${job.name}',
          name: '${jobTypeLabel(job)} – ${state.deviceState.deviceName}',
          jobType: job,
          sourceDeviceIds: {_deviceId},
          targets: choice.isEmpty ? const [] : [PrintTarget(printerId: choice)],
          priority: 50, // trước luật chung (100)
        ),
    ];
    onChanged(PrintSetup(printers: base.printers, rules: rules));
  }

  void _addBuiltin() {
    if (_deviceId.isEmpty) return;
    final id = 'builtin_$_shortId';
    if (setup.printerById(id) != null) return;
    onChanged(PrintSetup(
      printers: [
        ...setup.printers,
        PrinterEntry(
          id: id,
          name: 'Máy in tích hợp – ${state.deviceState.deviceName}',
          kind: PrinterKind.sunmiBuiltin,
          paper: PaperWidth.mm50,
          ownerDeviceId: _deviceId,
          fontScale: 0.8, // giấy hẹp: mặc định chữ 80% cho vừa
        ),
      ],
      rules: setup.rules,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final selected = setup.printerById(current ?? '');
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final builtinExists = setup.printerById('builtin_$_shortId') != null;
    final printerItems = [
      const DropdownMenuItem<String?>(value: null, child: Text('Theo luật chung của quán')),
      for (final p in setup.printers.where((p) => p.enabled))
        DropdownMenuItem<String?>(
          value: p.id,
          child: Text(
            p.kind == PrinterKind.sunmiBuiltin && !SunmiBuiltinDriver.isSupportedPlatform
                ? '${p.name} (chỉ in được trên Sunmi)'
                : p.name,
          ),
        ),
      const DropdownMenuItem<String?>(value: '', child: Text('Không in bill từ máy này')),
    ];
    final validValue = (current == null || current == '' || selected != null) ? current : null;

    final deviceRules = setup.rules.where(_isDeviceRule).toList();
    final isDual = deviceRules.any((r) => r.id.contains(kDeviceBillDualMarker));
    final activeMode = deviceRules.isEmpty ? 'win' : (isDual ? 'dual' : 'pos');

    Widget quickOption({
      required String mode,
      required IconData icon,
      required String title,
      required String desc,
      bool needAndroid = false,
    }) {
      final disabled = _deviceId.isEmpty || (needAndroid && !isAndroid);
      final active = activeMode == mode && !disabled;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(14),
            side: BorderSide(
              color: active ? const Color(0xFF1E1C5E) : Colors.black26,
              width: active ? 2 : 1,
            ),
            backgroundColor: active ? const Color(0xFFEDEBFA) : null,
          ),
          onPressed: disabled ? null : () => _quick(context, mode),
          child: Row(children: [
            Icon(icon, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  active ? '$title  ✓ đang dùng' : title,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  needAndroid && !isAndroid ? '$desc (chỉ có trên máy Sunmi/Android)' : desc,
                  style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.black54),
                ),
              ]),
            ),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Thiết lập nhanh', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              'Chọn cách in bill khi thanh toán TRÊN MÁY NÀY. Bếp và bar không đổi. Chọn xong bấm Lưu.',
              style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            quickOption(
              mode: 'win',
              icon: Icons.desktop_windows_rounded,
              title: 'Dùng máy Win làm máy in',
              desc: 'Bill ra máy in quầy (máy Windows). Máy này không tự in.',
            ),
            quickOption(
              mode: 'pos',
              icon: Icons.phone_android_rounded,
              title: 'Dùng máy POS cầm tay làm máy in',
              desc: 'Bill ra máy in gắn trong máy này. Máy Windows tự nhường, không in trùng.',
              needAndroid: true,
            ),
            quickOption(
              mode: 'dual',
              icon: Icons.copy_all_rounded,
              title: 'Dùng song song 2 máy',
              desc: 'Mỗi bill ra 2 bản: một ở máy này, một ở máy in quầy.',
              needAndroid: true,
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Máy này in bill ra', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              'Chỉ áp dụng cho hóa đơn và phiếu tạm tính khi thao tác trên máy này. '
              'Bếp và bar vẫn theo luật chung.',
              style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: validValue,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: printerItems,
              onChanged: _deviceId.isEmpty ? null : (v) => _choose(context, v),
            ),
            if (_deviceId.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Chưa nhận diện được thiết bị này nên chưa đặt riêng được.',
                    style: TextStyle(color: Color(0xFFB45309), fontSize: 12.5)),
              ),
            if (selected?.kind == PrinterKind.sunmiBuiltin && !SunmiBuiltinDriver.isSupportedPlatform)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Thiết bị này không in được ra máy in tích hợp Sunmi. Bill của máy này vẫn được in '
                  'qua máy in của quán như cũ, không bị mất.',
                  style: TextStyle(color: Color(0xFFB45309), fontSize: 12.5),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Máy in tích hợp (Sunmi V3...)',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              'Khai báo máy in gắn sẵn trong thiết bị này (khổ giấy 50 mm). Sau khi thêm, chọn nó ở ô '
              '"Máy này in bill ra" phía trên. Bấm "In thử" để kiểm tra giấy và tiếng Việt.',
              style: GoogleFonts.outfit(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (isAndroid)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(const SnackBar(content: Text('Đang gửi phiếu in thử...')));
                    final r = await SunmiBuiltinDriver.printTestSlip(
                      deviceName: state.deviceState.deviceName,
                    );
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(SnackBar(
                      content: Text(r.ok ? 'In thử: ${r.message}' : 'In thử thất bại: ${r.message}'),
                    ));
                  },
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('In thử máy in tích hợp'),
                ),
              ),
            OutlinedButton.icon(
              onPressed: (isAndroid && !builtinExists && _deviceId.isNotEmpty) ? _addBuiltin : null,
              icon: const Icon(Icons.phone_android_rounded),
              label: Text(builtinExists
                  ? 'Đã khai báo máy in tích hợp của máy này'
                  : (isAndroid ? 'Thêm máy in tích hợp của máy này' : 'Chỉ có trên thiết bị Android')),
            ),
          ]),
        ),
      ),
    ]);
  }

}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          Icon(icon, size: 48, color: Colors.black26),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.black54)),
        ]),
      );
}
