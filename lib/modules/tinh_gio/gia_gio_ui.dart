// Giao diện khung giá theo giờ + làm tròn (đợt 1 lộ trình tính giờ). Nằm trong hộp "Đặt giá giờ"
// (TinhGioGiaGioSheet); trạng thái do hộp đó giữ và lưu một lần cùng giá một giờ.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/money_formatter.dart';
import 'gia_gio.dart';

const _kNavy = Color(0xFF1C2151);
const _kCream = Color(0xFFFFF8F0);
const _kTeal = Color(0xFF0D9488);
const _kRed = Color(0xFFEF4444);

TextStyle _chu(double size, FontWeight w, [Color? c]) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c ?? _kNavy);
Color _nhat(double a) => _kNavy.withValues(alpha: a);

String _phutChu(int p) => p == 0
    ? 'Không'
    : p < 60
        ? '$p phút'
        : p % 60 == 0
            ? '${p ~/ 60} giờ'
            : '${p ~/ 60} giờ ${p % 60}';

/// Tóm tắt một dòng: "Tính theo từng phút", "2 khung giá · làm tròn 30 phút · tối thiểu 1 giờ".
String tomTatGiaGio(GiaGioCaiDat c) {
  if (c.laMacDinh) return 'Chưa cài · tính theo từng phút, một giá';
  return [
    if (c.khung.isNotEmpty) '${c.khung.length} khung giá',
    if (c.block > 1) 'làm tròn ${_phutChu(c.block)}${c.anHan > 0 ? ' (ân hạn ${c.anHan} phút)' : ''}',
    if (c.toiThieu > 0) 'tối thiểu ${_phutChu(c.toiThieu)}',
  ].join(' · ');
}

/// Phần "Giá theo giờ & làm tròn" (mở / đóng được).
class GiaGioCaiThem extends StatelessWidget {
  final GiaGioCaiDat caiDat;
  final bool mo;
  final bool khoa;
  final VoidCallback onMo;
  final ValueChanged<GiaGioCaiDat> onDoi;

  const GiaGioCaiThem({
    super.key,
    required this.caiDat,
    required this.mo,
    required this.khoa,
    required this.onMo,
    required this.onDoi,
  });

  Future<void> _suaKhung(BuildContext context, int? viTri) async {
    final kq = await showModalBottomSheet<KhungGia>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => KhungGiaSheet(khung: viTri == null ? null : caiDat.khung[viTri]),
    );
    if (kq == null) return;
    final ds = [...caiDat.khung];
    if (viTri == null) {
      ds.add(kq);
    } else {
      ds[viTri] = kq;
    }
    onDoi(caiDat.copyWith(khung: ds));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _nhat(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onMo,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: _kTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.tune_rounded, size: 20, color: _kTeal),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Giá theo giờ & làm tròn', style: _chu(14.5, FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(tomTatGiaGio(caiDat), style: _chu(12, FontWeight.w600, _nhat(0.6))),
                      ],
                    ),
                  ),
                  Icon(mo ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: _nhat(0.6)),
                ],
              ),
            ),
          ),
          if (mo) ...[
            Divider(height: 1, color: _nhat(0.08)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Text('Giá theo khung giờ', style: _chu(13.5, FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text(
                'Ngoài các khung này tính giá một giờ ở trên. Khung nằm trên được ưu tiên khi hai khung trùng giờ.',
                style: _chu(12, FontWeight.w500, _nhat(0.6)),
              ),
            ),
            for (var i = 0; i < caiDat.khung.length; i++) _dongKhung(context, i),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: OutlinedButton.icon(
                onPressed: khoa || caiDat.khung.length >= 12 ? null : () => _suaKhung(context, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Thêm khung giá'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kNavy,
                  minimumSize: const Size(0, 44),
                  side: BorderSide(color: _nhat(0.25)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: _chu(13.5, FontWeight.w700),
                ),
              ),
            ),
            Divider(height: 16, color: _nhat(0.08), indent: 14, endIndent: 14),
            _nhom(
              'Tính tiền theo',
              [
                for (final b in kBlockPhut) (b == 1 ? 'Từng phút' : 'Mỗi ${_phutChu(b)}', b),
              ],
              caiDat.block,
              (b) => onDoi(caiDat.copyWith(block: b, anHan: caiDat.anHan < b ? caiDat.anHan : 0)),
              ghiChu: caiDat.block > 1 ? 'Chơi lố sang block mới thì tính trọn block đó.' : null,
            ),
            if (caiDat.block > 1)
              _nhom(
                'Ân hạn',
                [for (final a in const [0, 2, 3, 5, 10]) if (a < caiDat.block) (_phutChu(a), a)],
                caiDat.anHan,
                (a) => onDoi(caiDat.copyWith(anHan: a)),
                ghiChu: caiDat.anHan > 0
                    ? 'Lố không quá ${caiDat.anHan} phút thì chưa tính sang block mới.'
                    : null,
              ),
            _nhom(
              'Chơi tối thiểu',
              [for (final t in const [0, 15, 30, 60, 120]) (_phutChu(t), t)],
              caiDat.toiThieu,
              (t) => onDoi(caiDat.copyWith(toiThieu: t)),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _dongKhung(BuildContext context, int i) {
    final k = caiDat.khung[i];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 8, 8),
      child: Material(
        color: _kCream,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: khoa ? null : () => _suaKhung(context, i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${k.thuChu} · ${k.gioChu}${k.quaDem ? ' (qua đêm)' : ''}',
                          style: _chu(13, FontWeight.w700)),
                      Text('${fmtVnd(k.gia)}/giờ', style: _chu(14, FontWeight.w800, _kTeal)),
                    ],
                  ),
                ),
                if (i > 0)
                  IconButton(
                    tooltip: 'Đưa lên (ưu tiên hơn)',
                    onPressed: khoa
                        ? null
                        : () {
                            final ds = [...caiDat.khung];
                            ds.insert(i - 1, ds.removeAt(i));
                            onDoi(caiDat.copyWith(khung: ds));
                          },
                    icon: Icon(Icons.arrow_upward_rounded, size: 20, color: _nhat(0.6)),
                  ),
                IconButton(
                  tooltip: 'Xoá khung',
                  onPressed: khoa ? null : () => onDoi(caiDat.copyWith(khung: [...caiDat.khung]..removeAt(i))),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: _kRed),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _nhom(String ten, List<(String, int)> lua, int dangChon, ValueChanged<int> chon, {String? ghiChu}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ten, style: _chu(12.5, FontWeight.w800, _nhat(0.65))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (nhan, gt) in lua)
                ChoiceChip(
                  label: Text(nhan),
                  selected: gt == dangChon,
                  onSelected: khoa ? null : (_) => chon(gt),
                  showCheckmark: false,
                  labelStyle: _chu(12.5, FontWeight.w700, gt == dangChon ? Colors.white : _kNavy),
                  selectedColor: _kNavy,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: gt == dangChon ? _kNavy : _nhat(0.18)),
                  shape: const StadiumBorder(),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
            ],
          ),
          if (ghiChu != null) ...[
            const SizedBox(height: 4),
            Text(ghiChu, style: _chu(11.5, FontWeight.w500, _nhat(0.6))),
          ],
        ],
      ),
    );
  }
}

/// Hộp thêm / sửa một khung giá. Trả về khung mới (null = huỷ).
class KhungGiaSheet extends StatefulWidget {
  final KhungGia? khung;
  const KhungGiaSheet({super.key, this.khung});

  @override
  State<KhungGiaSheet> createState() => _KhungGiaSheetState();
}

class _KhungGiaSheetState extends State<KhungGiaSheet> {
  static const _tenThu = {1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7', 7: 'CN'};
  late Set<int> _thu = {...?widget.khung?.thu};
  late int _tu = widget.khung?.tuPhut ?? 17 * 60;
  late int _den = widget.khung?.denPhut ?? 23 * 60;
  late bool _caNgay = widget.khung?.caNgay ?? false;
  late final _giaCtrl = TextEditingController(
    text: widget.khung == null ? '' : fmtVnd(widget.khung!.gia).replaceAll(' đ', ''),
  );
  String? _loi;

  @override
  void initState() {
    super.initState();
    if (_thu.isEmpty) _thu = {1, 2, 3, 4, 5, 6, 7};
  }

  @override
  void dispose() {
    _giaCtrl.dispose();
    super.dispose();
  }

  int? get _gia => int.tryParse(_giaCtrl.text.replaceAll('.', ''));

  Future<void> _chonGio(bool laTu) async {
    final p = laTu ? _tu : _den;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: p ~/ 60, minute: p % 60),
      helpText: laTu ? 'Khung bắt đầu lúc' : 'Khung kết thúc lúc',
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return;
    setState(() {
      if (laTu) {
        _tu = t.hour * 60 + t.minute;
      } else {
        _den = t.hour * 60 + t.minute;
      }
      _loi = null;
    });
  }

  void _luu() {
    final gia = _gia;
    if (_thu.isEmpty) return setState(() => _loi = 'Chọn ít nhất một ngày.');
    if (gia == null) return setState(() => _loi = 'Nhập giá một giờ của khung này.');
    if (!_caNgay && _tu == _den) return setState(() => _loi = 'Giờ bắt đầu và kết thúc trùng nhau. Muốn cả ngày thì bật "Cả ngày".');
    Navigator.pop(
      context,
      KhungGia(thu: _thu, tuPhut: _caNgay ? 0 : _tu, denPhut: _caNgay ? 0 : _den, gia: gia.toDouble()),
    );
  }

  Widget _nutNhanh(String nhan, Set<int> thu) {
    final chon = _thu.length == thu.length && _thu.containsAll(thu);
    return ChoiceChip(
      label: Text(nhan),
      selected: chon,
      onSelected: (_) => setState(() => _thu = {...thu}),
      showCheckmark: false,
      labelStyle: _chu(12.5, FontWeight.w700, chon ? Colors.white : _kNavy),
      selectedColor: _kNavy,
      backgroundColor: Colors.white,
      side: BorderSide(color: chon ? _kNavy : _nhat(0.18)),
      shape: const StadiumBorder(),
    );
  }

  Widget _oGio(String nhan, int phut, bool laTu) => Expanded(
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _nhat(0.14))),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _caNgay ? null : () => _chonGio(laTu),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nhan, style: _chu(12, FontWeight.w600, _nhat(0.6))),
                  Text(gioPhutChu(phut), style: _chu(22, FontWeight.w800, _caNgay ? _nhat(0.3) : _kNavy)),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final quaDem = !_caNgay && _den < _tu;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        decoration: BoxDecoration(color: _kCream, borderRadius: BorderRadius.circular(26)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: _nhat(0.15), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Text(widget.khung == null ? 'Thêm khung giá' : 'Sửa khung giá', style: _chu(18, FontWeight.w800)),
              const SizedBox(height: 12),
              Text('Áp dụng các ngày', style: _chu(12.5, FontWeight.w800, _nhat(0.65))),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final d in _tenThu.keys)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Semantics(
                          button: true,
                          selected: _thu.contains(d),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => setState(() => _thu.contains(d) ? _thu.remove(d) : _thu.add(d)),
                            child: Container(
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _thu.contains(d) ? _kNavy : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: _thu.contains(d) ? _kNavy : _nhat(0.18)),
                              ),
                              child: Text(_tenThu[d]!,
                                  style: _chu(12.5, FontWeight.w800, _thu.contains(d) ? Colors.white : _kNavy)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  _nutNhanh('Mọi ngày', {1, 2, 3, 4, 5, 6, 7}),
                  _nutNhanh('T2–T6', {1, 2, 3, 4, 5}),
                  _nutNhanh('T7, CN', {6, 7}),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Giờ', style: _chu(12.5, FontWeight.w800, _nhat(0.65))),
                  const Spacer(),
                  Text('Cả ngày', style: _chu(13, FontWeight.w700)),
                  Switch(
                    value: _caNgay,
                    activeTrackColor: _kTeal,
                    onChanged: (v) => setState(() {
                      _caNgay = v;
                      _loi = null;
                    }),
                  ),
                ],
              ),
              Row(
                children: [
                  _oGio('Từ', _caNgay ? 0 : _tu, true),
                  const SizedBox(width: 10),
                  _oGio('Đến', _caNgay ? 0 : _den, false),
                ],
              ),
              if (quaDem) ...[
                const SizedBox(height: 6),
                Text('Qua đêm: từ ${gioPhutChu(_tu)} tới ${gioPhutChu(_den)} hôm sau.',
                    style: _chu(12, FontWeight.w600, _kTeal)),
              ],
              const SizedBox(height: 12),
              Text('Giá một giờ trong khung', style: _chu(12.5, FontWeight.w800, _nhat(0.65))),
              const SizedBox(height: 6),
              TextField(
                controller: _giaCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [_SoChamFormatter()],
                onChanged: (_) => setState(() => _loi = null),
                style: _chu(22, FontWeight.w800),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: 'đ / giờ',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _nhat(0.14))),
                  enabledBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _nhat(0.14))),
                  focusedBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kNavy)),
                ),
              ),
              if (_loi != null) ...[
                const SizedBox(height: 8),
                Text(_loi!, style: _chu(13, FontWeight.w700, _kRed)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _luu,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kNavy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Xong', style: _chu(15.5, FontWeight.w800, Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chỉ nhận chữ số, tự chèn dấu chấm hàng nghìn.
class _SoChamFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue cu, TextEditingValue moi) {
    final so = moi.text.replaceAll(RegExp(r'[^0-9]'), '');
    final chu = so.isEmpty ? '' : fmtVnd(int.parse(so.length > 9 ? so.substring(0, 9) : so)).replaceAll(' đ', '');
    return TextEditingValue(text: chu, selection: TextSelection.collapsed(offset: chu.length));
  }
}
