// Hộp "Ngày lễ của quán" (đợt 6 lộ trình tính giờ, .docs/ke-hoach-ngay-le-gia-gio.md). Danh sách dùng chung mọi
// bàn; khung giá có chọn "Ngày lễ" áp vào các ngày này. Mỗi lần thêm / xoá gọi máy chủ ngay (ban_ngay_le_luu_v1).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import 'gia_gio.dart';
import 'tinh_gio_widgets.dart' show ngayLeProvider;

const _kNavy = Color(0xFF1C2151);
const _kCream = Color(0xFFFFF8F0);
const _kRed = Color(0xFFEF4444);

TextStyle _chu(double size, FontWeight w, [Color? c]) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c ?? _kNavy);
Color _nhat(double a) => _kNavy.withValues(alpha: a);

const _thuNgan = {1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7', 7: 'CN'};
String _hai(int n) => n.toString().padLeft(2, '0');

/// "30/04" — dùng cho dòng tóm tắt.
String ngayLeNgan(DateTime d) => '${_hai(d.day)}/${_hai(d.month)}';

/// Các ngày lễ từ hôm nay trở đi.
List<NgayLe> ngayLeSapToi(List<NgayLe> ds, DateTime nay) {
  final homNay = DateTime(nay.year, nay.month, nay.day);
  return [for (final n in ds) if (!n.ngay.isBefore(homNay)) n];
}

/// Lễ dương lịch cố định để thêm nhanh: lần tới của mỗi ngày (hôm nay vẫn tính).
List<(DateTime, String)> ngayLeNhanh(DateTime nay) {
  final homNay = DateTime(nay.year, nay.month, nay.day);
  DateTime toi(int thang, int ngay) {
    final d = DateTime(homNay.year, thang, ngay);
    return d.isBefore(homNay) ? DateTime(homNay.year + 1, thang, ngay) : d;
  }

  return [
    (toi(1, 1), 'Tết Dương lịch'),
    (toi(4, 30), 'Giải phóng miền Nam'),
    (toi(5, 1), 'Quốc tế Lao động'),
    (toi(9, 2), 'Quốc khánh'),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
}

/// Gộp các ngày liền nhau cùng tên (khác rỗng) thành một kỳ nghỉ; ngày lẻ đứng riêng. [ds] đã sắp theo ngày.
List<List<NgayLe>> gopKyNghi(List<NgayLe> ds) {
  final ra = <List<NgayLe>>[];
  for (final n in ds) {
    final cuoi = ra.isEmpty ? null : ra.last.last;
    if (cuoi != null &&
        n.ten.isNotEmpty &&
        n.ten == cuoi.ten &&
        DateTime(cuoi.ngay.year, cuoi.ngay.month, cuoi.ngay.day + 1) == n.ngay) {
      ra.last.add(n);
    } else {
      ra.add([n]);
    }
  }
  return ra;
}

class NgayLeSheet extends ConsumerStatefulWidget {
  /// Ngày "hôm nay" (để test / ảnh mẫu cố định); mặc định giờ máy.
  final DateTime? homNay;
  const NgayLeSheet({super.key, this.homNay});

  @override
  ConsumerState<NgayLeSheet> createState() => _NgayLeSheetState();
}

class _NgayLeSheetState extends ConsumerState<NgayLeSheet> {
  final _tenCtrl = TextEditingController();
  bool _dangLuu = false;
  String? _loi;

  DateTime get _nay => widget.homNay ?? DateTime.now();

  @override
  void dispose() {
    _tenCtrl.dispose();
    super.dispose();
  }

  Future<void> _luu({Map<DateTime, String> them = const {}, List<DateTime> xoa = const []}) async {
    if (_dangLuu) return;
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    final loi = await ref.read(banRepositoryProvider).luuNgayLe(them: them, xoa: xoa);
    if (!mounted) return;
    if (loi == null) ref.invalidate(ngayLeProvider);
    setState(() {
      _dangLuu = false;
      _loi = loi;
    });
  }

  Future<void> _chonTrenLich() async {
    final homNay = DateTime(_nay.year, _nay.month, _nay.day);
    final kq = await showDateRangePicker(
      context: context,
      firstDate: homNay,
      lastDate: DateTime(homNay.year + 3, homNay.month, homNay.day - 1),
      helpText: 'Chọn một ngày, hoặc ngày đầu và ngày cuối',
      saveText: 'Thêm',
    );
    if (kq == null) return;
    final soNgayChon = kq.end.difference(kq.start).inDays + 1;
    if (soNgayChon > 15) {
      setState(() => _loi = 'Mỗi lần chọn tối đa 15 ngày liền.');
      return;
    }
    final ten = _tenCtrl.text.trim();
    await _luu(them: {
      for (var i = 0; i < soNgayChon; i++) DateTime(kq.start.year, kq.start.month, kq.start.day + i): ten,
    });
    if (mounted && _loi == null) _tenCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final dsAsync = ref.watch(ngayLeProvider);
    final homNay = DateTime(_nay.year, _nay.month, _nay.day);
    final nhom = gopKyNghi(ngayLeSapToi(dsAsync.value ?? const [], _nay));
    final daCo = {for (final n in dsAsync.value ?? const <NgayLe>[]) soNgay(n.ngay)};
    final soNgaySapToi = nhom.fold<int>(0, (t, g) => t + g.length);
    const cam = Color(0xFFE8590C);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFF97316), cam], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.celebration_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ngày lễ của quán', style: _chu(19, FontWeight.w800)),
                        Text(
                          soNgaySapToi == 0 ? 'Dùng chung mọi bàn' : 'Dùng chung mọi bàn · $soNgaySapToi ngày sắp tới',
                          style: _chu(12.5, FontWeight.w600, _nhat(0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (dsAsync.isLoading && !dsAsync.hasValue)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
              else if (nhom.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _nhat(0.1)),
                  ),
                  child: Text('Chưa có ngày lễ nào. Thêm nhanh hoặc chọn trên lịch ở dưới.',
                      style: _chu(13, FontWeight.w600, _nhat(0.6))),
                )
              else
                for (var i = 0; i < nhom.length; i++) ...[
                  if (i == 0 || nhom[i].first.ngay.month != nhom[i - 1].first.ngay.month ||
                      nhom[i].first.ngay.year != nhom[i - 1].first.ngay.year)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 12, 0, 6),
                      child: Text('Tháng ${nhom[i].first.ngay.month} · ${nhom[i].first.ngay.year}',
                          style: _chu(13, FontWeight.w800)),
                    ),
                  _dongKyNghi(nhom[i], homNay),
                ],
              const SizedBox(height: 16),
              Text('THÊM NHANH', style: _chu(12, FontWeight.w800, _nhat(0.55))),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (_, c) {
                  final rong = (c.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (d, ten) in ngayLeNhanh(_nay))
                        SizedBox(width: rong, child: _oThemNhanh(d, ten, daCo.contains(soNgay(d)))),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('TẾT ÂM LỊCH, NGÀY KHÁC', style: _chu(12, FontWeight.w800, _nhat(0.55))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tenCtrl,
                      maxLength: 40,
                      style: _chu(15, FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Tên, ví dụ Tết',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _nhat(0.14))),
                        enabledBorder:
                            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _nhat(0.14))),
                        focusedBorder:
                            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kNavy)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _dangLuu ? null : _chonTrenLich,
                      icon: const Icon(Icons.calendar_month_rounded, size: 19),
                      label: const Text('Chọn ngày'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kNavy,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: _chu(14, FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Chọn một ngày hoặc cả kỳ nghỉ (tối đa 15 ngày liền). Bàn đang chơi cũng tính theo danh sách mới khi thanh toán.',
                  style: _chu(12, FontWeight.w500, _nhat(0.6))),
              if (_loi != null) ...[
                const SizedBox(height: 10),
                Text(_loi!, style: _chu(13, FontWeight.w700, _kRed)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kNavy,
                    side: BorderSide(color: _nhat(0.25)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _dangLuu
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text('Xong', style: _chu(15.5, FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Một dòng: một ngày, hoặc cả kỳ nghỉ liền nhau cùng tên ("05→09 · 5 ngày liền").
  Widget _dongKyNghi(List<NgayLe> g, DateTime homNay) {
    const cam = Color(0xFFE8590C);
    final dau = g.first.ngay, cuoi = g.last.ngay;
    final ky = g.length > 1;
    final con = dau.difference(homNay).inDays;
    final ten = g.first.ten.isEmpty ? (ky ? 'Kỳ nghỉ' : 'Ngày lễ') : g.first.ten;
    final phu = [
      if (ky) '${ngayLeNgan(dau)} – ${ngayLeNgan(cuoi)} · ${g.length} ngày liền',
      con == 0 ? 'Hôm nay' : 'Còn $con ngày',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: ky ? const Color(0xFFFFFBF8) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ky ? const Color(0xFFF4B9A1) : _nhat(0.09)),
      ),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 46),
            height: 48,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFFF4B9A1)),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: cam,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  height: 16,
                  alignment: Alignment.center,
                  child: Text(ky ? '${g.length} NGÀY' : _thuNgan[dau.weekday]!, style: _chu(9.5, FontWeight.w800, Colors.white)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Center(
                      child: Text(ky ? '${_hai(dau.day)}→${_hai(cuoi.day)}' : _hai(dau.day),
                          style: _chu(ky ? 14 : 18, FontWeight.w800)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ten, maxLines: 1, overflow: TextOverflow.ellipsis, style: _chu(14.5, FontWeight.w800)),
                Text(phu, style: _chu(12, FontWeight.w600, _nhat(0.55))),
              ],
            ),
          ),
          IconButton(
            tooltip: ky ? 'Bỏ cả kỳ nghỉ' : 'Bỏ ngày này',
            onPressed: _dangLuu ? null : () => _luu(xoa: [for (final n in g) n.ngay]),
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFFDECEC)),
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFDC2626)),
          ),
        ],
      ),
    );
  }

  /// Ô thêm nhanh một ngày lễ dương lịch: "+ 30/04 · Giải phóng miền Nam" (đã có thì "✓").
  Widget _oThemNhanh(DateTime d, String ten, bool daCo) => Material(
        color: daCo ? const Color(0xFFF0FBF9) : const Color(0xFFFFFBF8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: daCo ? const Color(0xFFB7E4DD) : const Color(0xFFF4B9A1), width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: daCo || _dangLuu ? null : () => _luu(them: {d: ten}),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(daCo ? Icons.check_rounded : Icons.add_rounded,
                        size: 16, color: daCo ? const Color(0xFF0F766E) : const Color(0xFF9A3412)),
                    const SizedBox(width: 3),
                    Text('${ngayLeNgan(d)}/${d.year}',
                        style: _chu(14, FontWeight.w800, daCo ? const Color(0xFF0F766E) : const Color(0xFF9A3412))),
                  ],
                ),
                Text(ten, maxLines: 1, overflow: TextOverflow.ellipsis, style: _chu(11.5, FontWeight.w600, _nhat(0.6))),
              ],
            ),
          ),
        ),
      );
}

/// Mở hộp ngày lễ.
Future<void> moNgayLeSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const NgayLeSheet(),
    );
