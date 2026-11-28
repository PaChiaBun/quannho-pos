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
const _kTeal = Color(0xFF0D9488);
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
    final ds = ngayLeSapToi(dsAsync.value ?? const [], _nay);
    final daCo = {for (final n in dsAsync.value ?? const <NgayLe>[]) soNgay(n.ngay)};
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
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
              Text('Ngày lễ của quán', style: _chu(18, FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Dùng chung cho mọi bàn. Khung giá có chọn "Ngày lễ" áp vào các ngày này. '
                'Bàn đang chơi cũng tính theo danh sách mới khi thanh toán.',
                style: _chu(12.5, FontWeight.w500, _nhat(0.65)),
              ),
              const SizedBox(height: 14),
              Text('SẮP TỚI', style: _chu(12, FontWeight.w800, _nhat(0.6))),
              const SizedBox(height: 6),
              if (dsAsync.isLoading && !dsAsync.hasValue)
                const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
              else if (ds.isEmpty)
                Container(
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
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _nhat(0.1)),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < ds.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: _nhat(0.07), indent: 14, endIndent: 14),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 34,
                                child: Text(_thuNgan[ds[i].ngay.weekday]!, style: _chu(12.5, FontWeight.w700, _nhat(0.55))),
                              ),
                              Text('${ngayLeNgan(ds[i].ngay)}/${ds[i].ngay.year}', style: _chu(14.5, FontWeight.w800)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(ds[i].ten, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: _chu(13, FontWeight.w600, _nhat(0.6))),
                              ),
                              IconButton(
                                tooltip: 'Bỏ ngày này',
                                onPressed: _dangLuu ? null : () => _luu(xoa: [ds[i].ngay]),
                                icon: const Icon(Icons.close_rounded, size: 20, color: _kRed),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text('THÊM NHANH', style: _chu(12, FontWeight.w800, _nhat(0.6))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (d, ten) in ngayLeNhanh(_nay))
                    if (daCo.contains(soNgay(d)))
                      Chip(
                        avatar: const Icon(Icons.check_rounded, size: 16, color: _kTeal),
                        label: Text('${ngayLeNgan(d)}/${d.year}'),
                        labelStyle: _chu(12.5, FontWeight.w700, _nhat(0.5)),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: _nhat(0.12)),
                        shape: const StadiumBorder(),
                      )
                    else
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 16, color: _kNavy),
                        label: Text('${ngayLeNgan(d)}/${d.year}'),
                        tooltip: ten,
                        onPressed: _dangLuu ? null : () => _luu(them: {d: ten}),
                        labelStyle: _chu(12.5, FontWeight.w700),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: _nhat(0.2)),
                        shape: const StadiumBorder(),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                ],
              ),
              const SizedBox(height: 16),
              Text('TẾT ÂM LỊCH, NGÀY KHÁC', style: _chu(12, FontWeight.w800, _nhat(0.6))),
              const SizedBox(height: 6),
              TextField(
                controller: _tenCtrl,
                maxLength: 40,
                style: _chu(15, FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Tên, ví dụ Tết (không bắt buộc)',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _nhat(0.14))),
                  enabledBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _nhat(0.14))),
                  focusedBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kNavy)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _dangLuu ? null : _chonTrenLich,
                  icon: const Icon(Icons.calendar_month_rounded, size: 20),
                  label: const Text('Chọn ngày trên lịch'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kNavy,
                    side: BorderSide(color: _nhat(0.25)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: _chu(14, FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('Chọn được nhiều ngày liền (tối đa 15), ví dụ cả kỳ nghỉ Tết.',
                  style: _chu(11.5, FontWeight.w500, _nhat(0.55))),
              if (_loi != null) ...[
                const SizedBox(height: 10),
                Text(_loi!, style: _chu(13, FontWeight.w700, _kRed)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kNavy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _dangLuu
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text('Xong', style: _chu(15.5, FontWeight.w800, Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mở hộp ngày lễ.
Future<void> moNgayLeSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const NgayLeSheet(),
    );
