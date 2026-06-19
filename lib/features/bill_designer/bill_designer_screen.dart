// lib/features/bill_designer/bill_designer_screen.dart
// Thiết kế mẫu hoá đơn — live preview + lưu settings
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// ─── Settings Model ───────────────────────────────────────────────────────────

class BillTemplate {
  final String paperSize;    // '58mm' | '80mm' | 'a4'
  final bool showLogo;
  final bool showAddress;
  final bool showPhone;
  final bool showTableName;
  final bool showQr;
  final bool showLoyalty;
  final bool showNote;
  final String footerText;
  final int headerFontSize;  // 10-20
  final int bodyFontSize;    // 7-12
  final String alignment;    // 'left' | 'center'
  final bool showDividers;
  final bool boldTotals;

  const BillTemplate({
    this.paperSize    = '80mm',
    this.showLogo     = false,
    this.showAddress  = true,
    this.showPhone    = true,
    this.showTableName= true,
    this.showQr       = false,
    this.showLoyalty  = true,
    this.showNote     = true,
    this.footerText   = 'Cảm ơn quý khách!',
    this.headerFontSize = 14,
    this.bodyFontSize   = 12,
    this.alignment    = 'center',
    this.showDividers = true,
    this.boldTotals   = true,
  });

  BillTemplate copyWith({
    String? paperSize, bool? showLogo, bool? showAddress,
    bool? showPhone, bool? showTableName, bool? showQr,
    bool? showLoyalty, bool? showNote, String? footerText,
    int? headerFontSize, int? bodyFontSize, String? alignment,
    bool? showDividers, bool? boldTotals,
  }) => BillTemplate(
    paperSize:      paperSize     ?? this.paperSize,
    showLogo:       showLogo      ?? this.showLogo,
    showAddress:    showAddress   ?? this.showAddress,
    showPhone:      showPhone     ?? this.showPhone,
    showTableName:  showTableName ?? this.showTableName,
    showQr:         showQr        ?? this.showQr,
    showLoyalty:    showLoyalty   ?? this.showLoyalty,
    showNote:       showNote      ?? this.showNote,
    footerText:     footerText    ?? this.footerText,
    headerFontSize: headerFontSize?? this.headerFontSize,
    bodyFontSize:   bodyFontSize  ?? this.bodyFontSize,
    alignment:      alignment     ?? this.alignment,
    showDividers:   showDividers  ?? this.showDividers,
    boldTotals:     boldTotals    ?? this.boldTotals,
  );

  Map<String, dynamic> toMap() => {
    'bill_tpl_paper':  paperSize,
    'bill_tpl_logo':   showLogo   ? '1' : '0',
    'bill_tpl_addr':   showAddress? '1' : '0',
    'bill_tpl_phone':  showPhone  ? '1' : '0',
    'bill_tpl_table':  showTableName? '1':'0',
    'bill_tpl_qr':     showQr     ? '1' : '0',
    'bill_tpl_loyal':  showLoyalty? '1' : '0',
    'bill_tpl_note':   showNote   ? '1' : '0',
    'bill_tpl_footer': footerText,
    'bill_tpl_hfont':  headerFontSize.toString(),
    'bill_tpl_bfont':  bodyFontSize.toString(),
    'bill_tpl_align':  alignment,
    'bill_tpl_divider':showDividers? '1':'0',
    'bill_tpl_bold':   boldTotals ? '1' : '0',
  };

  static Future<BillTemplate> load() async {
    final prefs = await SharedPreferences.getInstance();
    return BillTemplate(
      paperSize:      prefs.getString('bill_tpl_paper')  ?? '80mm',
      showLogo:       prefs.getString('bill_tpl_logo')   == '1',
      showAddress:    prefs.getString('bill_tpl_addr')   != '0',
      showPhone:      prefs.getString('bill_tpl_phone')  != '0',
      showTableName:  prefs.getString('bill_tpl_table')  != '0',
      showQr:         prefs.getString('bill_tpl_qr')     == '1',
      showLoyalty:    prefs.getString('bill_tpl_loyal')  != '0',
      showNote:       prefs.getString('bill_tpl_note')   != '0',
      footerText:     prefs.getString('bill_tpl_footer') ?? 'Cảm ơn quý khách!',
      headerFontSize: int.tryParse(prefs.getString('bill_tpl_hfont') ?? '14') ?? 14,
      bodyFontSize:   int.tryParse(prefs.getString('bill_tpl_bfont') ?? '12') ?? 12,
      alignment:      prefs.getString('bill_tpl_align')  ?? 'center',
      showDividers:   prefs.getString('bill_tpl_divider')!= '0',
      boldTotals:     prefs.getString('bill_tpl_bold')   != '0',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    for (final e in toMap().entries) { prefs.setString(e.key, e.value.toString()); }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final _templateProvider = NotifierProvider<_TemplateNotifier, BillTemplate>(
    _TemplateNotifier.new);

class _TemplateNotifier extends Notifier<BillTemplate> {
  @override
  BillTemplate build() {
    _load();
    return const BillTemplate();
  }

  Future<void> _load() async {
    state = await BillTemplate.load();
  }

  void update(BillTemplate t) { state = t; }

  Future<void> save() async {
    await state.save();
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class BillDesignerScreen extends ConsumerStatefulWidget {
  const BillDesignerScreen({super.key});

  @override
  ConsumerState<BillDesignerScreen> createState() => _BillDesignerScreenState();
}

class _BillDesignerScreenState extends ConsumerState<BillDesignerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _footerCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  void _update(BillTemplate t) => ref.read(_templateProvider.notifier).update(t);

  Future<void> _save() async {
    await ref.read(_templateProvider.notifier).save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Đã lưu mẫu hoá đơn'),
        backgroundColor: Color(0xFF1C2151),
        duration: Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tpl = ref.watch(_templateProvider);
    // Sync footer text controller
    if (_footerCtrl.text != tpl.footerText) {
      _footerCtrl.text = tpl.footerText;
      _footerCtrl.selection = TextSelection.collapsed(offset: _footerCtrl.text.length);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2151),
        foregroundColor: Colors.white,
        title: const Text('Thiết Kế Hoá Đơn',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18),
            label: const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            onPressed: _save,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: const Color(0xFFFF6B35),
          tabs: const [
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Cấu hình'),
            Tab(icon: Icon(Icons.preview_rounded, size: 18), text: 'Xem trước'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ConfigTab(tpl: tpl, onUpdate: _update, footerCtrl: _footerCtrl),
          _PreviewTab(tpl: tpl),
        ],
      ),
    );
  }
}

// ─── Config Tab ───────────────────────────────────────────────────────────────

class _ConfigTab extends StatelessWidget {
  final BillTemplate tpl;
  final void Function(BillTemplate) onUpdate;
  final TextEditingController footerCtrl;
  const _ConfigTab({required this.tpl, required this.onUpdate, required this.footerCtrl});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [

      // ── Khổ giấy ────────────────────────────────────────────────
      _Section(title: '📏 Khổ Giấy', children: [
        Row(children: [
          _PaperChip(label: '58mm', value: '58mm', selected: tpl.paperSize == '58mm',
              onTap: () => onUpdate(tpl.copyWith(paperSize: '58mm'))),
          const SizedBox(width: 8),
          _PaperChip(label: '80mm', value: '80mm', selected: tpl.paperSize == '80mm',
              onTap: () => onUpdate(tpl.copyWith(paperSize: '80mm'))),
          const SizedBox(width: 8),
          _PaperChip(label: 'A4', value: 'a4', selected: tpl.paperSize == 'a4',
              onTap: () => onUpdate(tpl.copyWith(paperSize: 'a4'))),
        ]),
      ]),

      // ── Căn lề ──────────────────────────────────────────────────
      _Section(title: '↔️ Căn Lề Header', children: [
        Row(children: [
          _PaperChip(label: '⬛ Trái',   value: 'left',   selected: tpl.alignment == 'left',
              onTap: () => onUpdate(tpl.copyWith(alignment: 'left'))),
          const SizedBox(width: 8),
          _PaperChip(label: '⬜ Giữa',   value: 'center', selected: tpl.alignment == 'center',
              onTap: () => onUpdate(tpl.copyWith(alignment: 'center'))),
        ]),
      ]),

      // ── Font size ────────────────────────────────────────────────
      _Section(title: '🔤 Cỡ Chữ', children: [
        _SliderRow(
          label: 'Header (tên quán)',
          value: tpl.headerFontSize.toDouble(),
          min: 10, max: 20,
          onChanged: (v) => onUpdate(tpl.copyWith(headerFontSize: v.round())),
        ),
        const SizedBox(height: 8),
        _SliderRow(
          label: 'Nội dung',
          value: tpl.bodyFontSize.toDouble(),
          min: 7, max: 14,
          onChanged: (v) => onUpdate(tpl.copyWith(bodyFontSize: v.round())),
        ),
      ]),

      // ── Hiển thị ─────────────────────────────────────────────────
      _Section(title: '👁️ Hiển Thị Trên Hoá Đơn', children: [
        _ToggleRow('Địa chỉ quán',    tpl.showAddress,   (v) => onUpdate(tpl.copyWith(showAddress:   v))),
        _ToggleRow('Số điện thoại',   tpl.showPhone,     (v) => onUpdate(tpl.copyWith(showPhone:     v))),
        _ToggleRow('Tên bàn',         tpl.showTableName, (v) => onUpdate(tpl.copyWith(showTableName: v))),
        _ToggleRow('Điểm thưởng',     tpl.showLoyalty,   (v) => onUpdate(tpl.copyWith(showLoyalty:   v))),
        _ToggleRow('Ghi chú đơn',     tpl.showNote,      (v) => onUpdate(tpl.copyWith(showNote:      v))),
        _ToggleRow('Đường kẻ ngang',  tpl.showDividers,  (v) => onUpdate(tpl.copyWith(showDividers:  v))),
        _ToggleRow('In đậm tổng tiền',tpl.boldTotals,    (v) => onUpdate(tpl.copyWith(boldTotals:    v))),
      ]),

      // ── Footer text ──────────────────────────────────────────────
      _Section(title: '💬 Lời Cuối Hoá Đơn', children: [
        TextField(
          controller: footerCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'VD: Cảm ơn quý khách! Hẹn gặp lại 🙏',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE0D8CC))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF1C2151), width: 1.5)),
          ),
          onChanged: (v) => onUpdate(BillTemplate(
            paperSize: tpl.paperSize, showLogo: tpl.showLogo,
            showAddress: tpl.showAddress, showPhone: tpl.showPhone,
            showTableName: tpl.showTableName, showQr: tpl.showQr,
            showLoyalty: tpl.showLoyalty, showNote: tpl.showNote,
            footerText: v,
            headerFontSize: tpl.headerFontSize, bodyFontSize: tpl.bodyFontSize,
            alignment: tpl.alignment, showDividers: tpl.showDividers,
            boldTotals: tpl.boldTotals,
          )),
        ),
      ]),

      const SizedBox(height: 32),
    ]);
  }
}

// ─── Preview Tab ──────────────────────────────────────────────────────────────

class _PreviewTab extends StatelessWidget {
  final BillTemplate tpl;
  const _PreviewTab({required this.tpl});

  static final _fmt = NumberFormat('#,###', 'vi_VN');
  static String _money(double v) => '${_fmt.format(v.round())}đ';

  // Sample data
  static const _sampleItems = [
    ('Phở Bò Đặc Biệt', 2, 85000.0),
    ('Cà Phê Sữa Đá', 1, 30000.0),
    ('Bánh Mì Thịt', 3, 25000.0),
  ];

  @override
  Widget build(BuildContext context) {
    // Width ratio based on paper size
    final widthFactor = tpl.paperSize == '58mm' ? 0.65
        : tpl.paperSize == '80mm' ? 0.82 : 1.0;

    final isCenter = tpl.alignment == 'center';
    final h = tpl.headerFontSize.toDouble();
    final b = tpl.bodyFontSize.toDouble();

    const shopName    = 'Quán Nhỏ POS';
    const shopAddress = '123 Nguyễn Trãi, Q.1, TP.HCM';
    const shopPhone   = '0909 123 456';

    double subtotal = _sampleItems.fold(0, (s, e) => s + e.$2 * e.$3);
    double discount = 15000;
    double total    = subtotal - discount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

              // ── Header ──
              Text(shopName,
                  textAlign: isCenter ? TextAlign.center : TextAlign.left,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: h)),
              if (tpl.showAddress) ...[
                const SizedBox(height: 2),
                Text(shopAddress,
                    textAlign: isCenter ? TextAlign.center : TextAlign.left,
                    style: TextStyle(fontSize: b - 2, color: Colors.grey.shade600)),
              ],
              if (tpl.showPhone)
                Text('SĐT: $shopPhone',
                    textAlign: isCenter ? TextAlign.center : TextAlign.left,
                    style: TextStyle(fontSize: b - 2, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              if (tpl.showDividers) const Divider(thickness: 0.5),

              // ── Order info ──
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('HÓA ĐƠN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: b)),
                Text('#2506110042', style: TextStyle(fontWeight: FontWeight.w700, fontSize: b)),
              ]),
              const SizedBox(height: 2),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Ngày:', style: TextStyle(fontSize: b - 2)),
                Text('11/05/2026 21:30', style: TextStyle(fontSize: b - 2)),
              ]),
              if (tpl.showTableName)
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Bàn:', style: TextStyle(fontSize: b - 2)),
                  Text('Bàn 5', style: TextStyle(fontWeight: FontWeight.w700, fontSize: b - 2)),
                ]),
              if (tpl.showDividers) const Divider(thickness: 0.5),

              // ── Items header ──
              Row(children: [
                Expanded(flex: 4, child: Text('Món', style: TextStyle(fontWeight: FontWeight.w700, fontSize: b - 2))),
                Text('SL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: b - 2)),
                const SizedBox(width: 16),
                Text('T.Tiền', style: TextStyle(fontWeight: FontWeight.w700, fontSize: b - 2)),
              ]),
              if (tpl.showDividers) const Divider(thickness: 0.3),

              // ── Items ──
              ..._sampleItems.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(flex: 4, child: Text(item.$1, style: TextStyle(fontSize: b - 2))),
                  Text('×${item.$2}', style: TextStyle(fontSize: b - 2)),
                  const SizedBox(width: 8),
                  Text(_money(item.$2 * item.$3),
                      style: TextStyle(fontSize: b - 2)),
                ]),
              )),
              if (tpl.showDividers) const Divider(thickness: 0.5),

              // ── Totals ──
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Tạm tính:', style: TextStyle(fontSize: b - 1)),
                Text(_money(subtotal), style: TextStyle(fontSize: b - 1)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Giảm giá:', style: TextStyle(fontSize: b - 1)),
                Text('-${_money(discount)}',
                    style: TextStyle(fontSize: b - 1, color: Colors.red.shade600)),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('TỔNG CỘNG:',
                    style: TextStyle(fontWeight: tpl.boldTotals ? FontWeight.w700 : FontWeight.normal,
                        fontSize: b + 1)),
                Text(_money(total),
                    style: TextStyle(fontWeight: tpl.boldTotals ? FontWeight.w800 : FontWeight.normal,
                        fontSize: b + 2)),
              ]),

              // ── Loyalty ──
              if (tpl.showLoyalty) ...[
                if (tpl.showDividers) const Divider(thickness: 0.3),
                Text('⭐ Cộng 34 điểm thưởng',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: b - 1)),
              ],

              // ── Note ──
              if (tpl.showNote) ...[
                if (tpl.showDividers) const Divider(thickness: 0.3),
                Text('Ghi chú: Không cay',
                    style: TextStyle(fontSize: b - 2, fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600)),
              ],

              // ── Footer ──
              const SizedBox(height: 8),
              if (tpl.showDividers) const Divider(thickness: 0.5),
              Text(tpl.footerText.isEmpty ? 'Cảm ơn quý khách!' : tpl.footerText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: b)),
              Text('Hẹn gặp lại 🙏',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: b - 2, color: Colors.grey.shade500)),

              const SizedBox(height: 4),
              // Cutter mark
              Row(children: List.generate(28, (i) => Expanded(
                child: Container(height: 1,
                    color: i % 2 == 0 ? Colors.black : Colors.transparent)))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700,
          fontSize: 14, color: Color(0xFF1C2151))),
      const SizedBox(height: 14),
      ...children,
    ]),
  );
}

class _PaperChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _PaperChip({required this.label, required this.value,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1C2151) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: selected ? const Color(0xFF1C2151) : Colors.grey.shade300),
      ),
      child: Text(label, style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 13,
          color: selected ? Colors.white : const Color(0xFF555555))),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
      Switch(
        value: value,
        activeColor: const Color(0xFF1C2151),
        onChanged: onChanged,
      ),
    ]),
  );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min, max;
  final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.value,
      required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF1C2151).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8)),
          child: Text('${value.round()}px',
              style: const TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 12, color: Color(0xFF1C2151))),
        ),
      ]),
      Slider(
        value: value, min: min, max: max,
        divisions: (max - min).round(),
        activeColor: const Color(0xFF1C2151),
        inactiveColor: const Color(0xFFE0D8CC),
        onChanged: onChanged,
      ),
    ],
  );
}
