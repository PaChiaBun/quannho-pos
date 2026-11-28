// Gói giờ (đợt 7 lộ trình tính giờ, .docs/ke-hoach-goi-gio.md): hộp thêm / sửa gói của bàn, hộp chọn gói cho bàn
// đang chơi, dòng "Gói 2 giờ · còn 25 phút" trong khối ĐANG TÍNH GIỜ, và hộp nhắc khi còn 10 phút / hết gói.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/repositories/ban_repository.dart';
import '../../core/utils/money_formatter.dart';
import '../../screens/ban_screen.dart' show activeSessionsProvider, allBanTablesProvider;
import '../qr_order/services/qr_sound_service.dart';
import 'gia_gio.dart';
import 'tinh_gio.dart' show tinhGioThanhTien;
import 'gia_gio_ui.dart' show SoChamFormatter;
import 'tinh_gio_widgets.dart' show giaGioCaiDatProvider, tinhGioModuleActiveProvider;

const _kNavy = Color(0xFF1C2151);
const _kCream = Color(0xFFFFF8F0);
const _kTeal = Color(0xFF0D9488);
const _kRed = Color(0xFFEF4444);
const _kOrange = Color(0xFFF97316);

TextStyle _chu(double size, FontWeight w, [Color? c]) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c ?? _kNavy);
Color _nhat(double a) => _kNavy.withValues(alpha: a);

/// Nhắc trước khi hết gói.
const kGoiNhacTruoc = Duration(minutes: 10);

/// Số phút còn lại của gói (âm = đã lố), tính theo phút chơi thực từ [vao] tới [luc].
int goiConPhut(int goiPhut, DateTime vao, DateTime luc) => goiPhut - luc.difference(vao).inMinutes;

/// "Gói 2 giờ 100.000 đ" / "Phần còn của gói 1 giờ 20 phút" (giá 0 sau chuyển bàn).
String goiCuaPhienChu(int goiPhut, double? goiGia) => (goiGia ?? 0) > 0
    ? 'Gói ${thoiLuongChu(goiPhut)} ${fmtVnd(goiGia!)}'
    : 'Phần còn của gói ${thoiLuongChu(goiPhut)}';

/// Lượt nhắc kế tiếp: phiên có gói, đang trong 10 phút cuối (`daHet` false) hoặc đã hết trong vòng 30 phút
/// (`daHet` true), chưa nhắc ([daHien] chứa `khoa`). Hết gói thì nhắc "hết" (bỏ qua nhắc "sắp hết" chưa kịp hiện).
({BanSessionModel s, DateTime het, bool daHet, String khoa})? goiCanNhac(
    Iterable<BanSessionModel> ds, DateTime nay, Set<String> daHien) {
  for (final s in ds) {
    final goi = s.goiPhut;
    if (goi == null || goi <= 0 || s.gioBatDau == null) continue;
    final het = DateTime.fromMillisecondsSinceEpoch(s.gioBatDau!).add(Duration(minutes: goi));
    final khoa = '${s.id}|${s.gioBatDau}|$goi';
    if (!nay.isBefore(het) && nay.isBefore(het.add(const Duration(minutes: 30))) && !daHien.contains('$khoa|het')) {
      return (s: s, het: het, daHet: true, khoa: khoa);
    }
    if (!nay.isBefore(het.subtract(kGoiNhacTruoc)) && nay.isBefore(het) && !daHien.contains('$khoa|sap')) {
      return (s: s, het: het, daHet: false, khoa: khoa);
    }
  }
  return null;
}

/// Thẻ bàn: "còn 25'" / "lố 8'" (null khi không gói).
String? goiNganChu(int? goiPhut, DateTime? vao, DateTime luc) {
  if (goiPhut == null || goiPhut <= 0 || vao == null) return null;
  final con = goiConPhut(goiPhut, vao, luc);
  return con > 0 ? "gói còn $con'" : "hết gói, lố ${-con}'";
}

Widget _keo() => Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(color: _nhat(0.15), borderRadius: BorderRadius.circular(2)),
      ),
    );

Widget _nutChinh(String chu, VoidCallback? onPressed, {bool dangLuu = false}) => SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _kNavy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: dangLuu
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(chu, style: _chu(15.5, FontWeight.w800, Colors.white)),
      ),
    );

/// Gói so với tính giờ thường: tiền tính giờ đủ [phut] phút theo [giaGoc] (làm tròn 1.000 đ như máy chủ) và phần
/// chênh (> 0 = gói rẻ hơn). null khi chưa có giá giờ.
({double theoGio, double chenh})? goiSoVoiGio(int phut, double gia, double? giaGoc) {
  if (giaGoc == null || giaGoc <= 0) return null;
  final theoGio = tinhGioThanhTien(phut, giaGoc);
  return (theoGio: theoGio, chenh: theoGio - gia);
}

String _gioPhut(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Hộp thêm / sửa một gói của bàn. Trả gói mới (null = huỷ). [daCo] = số phút của các gói khác của bàn.
class GoiGioSheet extends StatefulWidget {
  final GoiGio? goi;
  final Set<int> daCo;
  /// Giá một giờ thường của bàn, để báo gói rẻ hơn bao nhiêu. null = không báo.
  final double? giaGoc;
  const GoiGioSheet({super.key, this.goi, this.daCo = const {}, this.giaGoc});

  @override
  State<GoiGioSheet> createState() => _GoiGioSheetState();
}

class _GoiGioSheetState extends State<GoiGioSheet> {
  static const _thoiLuong = [30, 60, 90, 120, 180, 240, 300, 360];
  late int _phut = widget.goi?.soPhut ?? (widget.daCo.contains(120) ? 60 : 120);
  late final _giaCtrl = TextEditingController(
    text: widget.goi == null ? '' : fmtVnd(widget.goi!.gia).replaceAll(' đ', ''),
  );
  String? _loi;

  int? get _gia => int.tryParse(_giaCtrl.text.replaceAll('.', ''));

  @override
  void dispose() {
    _giaCtrl.dispose();
    super.dispose();
  }

  void _xong() {
    final gia = _gia;
    if (widget.daCo.contains(_phut)) return setState(() => _loi = 'Bàn đã có gói ${thoiLuongChu(_phut)}.');
    if (gia == null) return setState(() => _loi = 'Nhập giá của gói.');
    Navigator.pop(context, GoiGio(id: widget.goi?.id, soPhut: _phut, gia: gia.toDouble()));
  }

  Widget _oThoiGian(int p) {
    final chon = p == _phut;
    final daCo = widget.daCo.contains(p);
    final (so, donVi) = p < 60 ? ('$p', 'phút') : (p % 60 == 0 ? '${p ~/ 60}' : '${p ~/ 60},5', 'giờ');
    return Opacity(
      opacity: daCo ? 0.35 : 1,
      child: GestureDetector(
        onTap: daCo
            ? null
            : () => setState(() {
                  _phut = p;
                  _loi = null;
                }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 62,
          decoration: BoxDecoration(
            color: chon ? _kNavy : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: chon ? _kNavy : _nhat(0.14), width: 1.5),
            boxShadow: chon ? [BoxShadow(color: _kNavy.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 5))] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(so, style: _chu(20, FontWeight.w800, chon ? Colors.white : _kNavy)),
              Text(daCo ? '$donVi · đã có' : donVi,
                  style: _chu(11, FontWeight.w700, chon ? const Color(0xFFC9C7E8) : _nhat(0.55))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gia = _gia;
    final so = gia == null ? null : goiSoVoiGio(_phut, gia.toDouble(), widget.giaGoc);
    final goc = widget.giaGoc;
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
              _keo(),
              const SizedBox(height: 12),
              Text(widget.goi == null ? 'Thêm gói giờ' : 'Sửa gói giờ', style: _chu(19, FontWeight.w800)),
              Text('Bán trọn gói · về sớm vẫn tính đủ gói', style: _chu(13, FontWeight.w600, _nhat(0.6))),
              const SizedBox(height: 14),
              Text('THỜI GIAN', style: _chu(12, FontWeight.w800, _nhat(0.55))),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.25,
                children: [for (final p in _thoiLuong) _oThoiGian(p)],
              ),
              const SizedBox(height: 14),
              Text('GIÁ TRỌN GÓI', style: _chu(12, FontWeight.w800, _nhat(0.55))),
              const SizedBox(height: 8),
              TextField(
                controller: _giaCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [SoChamFormatter()],
                onChanged: (_) => setState(() => _loi = null),
                style: _chu(26, FontWeight.w800),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: 'đ',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _nhat(0.14))),
                  enabledBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _nhat(0.14))),
                  focusedBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _kNavy, width: 2)),
                ),
              ),
              if (so != null && gia != null && goc != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: so.chenh >= 0 ? const Color(0xFFE8F7F4) : const Color(0xFFFFF4EE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: so.chenh >= 0 ? const Color(0xFFB7E4DD) : const Color(0xFFF4B9A1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: so.chenh >= 0 ? _kTeal : _kOrange, shape: BoxShape.circle),
                        child: Icon(so.chenh >= 0 ? Icons.savings_rounded : Icons.trending_up_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              so.chenh == 0
                                  ? 'Bằng giá tính giờ'
                                  : so.chenh > 0
                                      ? 'Rẻ hơn ${fmtVnd(so.chenh)} (${(so.chenh / so.theoGio * 100).round()}%) so với tính giờ'
                                      : 'Đắt hơn tính giờ ${fmtVnd(-so.chenh)}',
                              style: _chu(13, FontWeight.w800, so.chenh >= 0 ? const Color(0xFF0F766E) : const Color(0xFF9A3412)),
                            ),
                            Text('${thoiLuongChu(_phut)} × ${fmtVnd(goc)}/giờ = ${fmtVnd(so.theoGio)}',
                                style: _chu(12, FontWeight.w600, _nhat(0.6))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Khách về sớm vẫn trả đủ giá gói. Chơi quá ${thoiLuongChu(_phut)} thì phần lố tính theo giá giờ.',
                style: _chu(12, FontWeight.w500, _nhat(0.6)),
              ),
              if (_loi != null) ...[
                const SizedBox(height: 8),
                Text(_loi!, style: _chu(13, FontWeight.w700, _kRed)),
              ],
              const SizedBox(height: 14),
              _nutChinh(
                gia == null ? 'Xong' : '${widget.goi == null ? 'Thêm' : 'Lưu'} gói ${thoiLuongChu(_phut)} · ${fmtVnd(gia)}',
                _xong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hộp chọn gói cho bàn đang chơi. [goiPhut] / [goiGia] = gói phiên đang có (null = chưa chọn). Chạm một thẻ để
/// chọn, bấm nút dưới để xác nhận (đụng tiền nên không chọn ngay khi chạm).
class ChonGoiSheet extends ConsumerStatefulWidget {
  final String tableId;
  final String sessionId;
  final int? goiPhut;
  final double? goiGia;
  final String? tenBan;
  final DateTime? vao;
  final double? giaGoc;
  const ChonGoiSheet({
    super.key,
    required this.tableId,
    required this.sessionId,
    this.goiPhut,
    this.goiGia,
    this.tenBan,
    this.vao,
    this.giaGoc,
  });

  @override
  ConsumerState<ChonGoiSheet> createState() => _ChonGoiSheetState();
}

class _ChonGoiSheetState extends ConsumerState<ChonGoiSheet> {
  static const _bo = '_bo_goi_';
  bool _dangLuu = false;
  String? _loi;
  String? _dangChon;

  bool get _daCo => widget.goiPhut != null;
  bool _laGoiDangDung(GoiGio g) => (widget.goiGia ?? 0) > 0 && widget.goiPhut == g.soPhut && widget.goiGia == g.gia;

  Future<void> _xacNhan() async {
    final chon = _dangChon;
    if (_dangLuu || chon == null) return;
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    final loi = await ref.read(banRepositoryProvider).chonGoiGio(widget.sessionId, chon == _bo ? null : chon);
    if (!mounted) return;
    if (loi == null) {
      ref.invalidate(activeSessionsProvider);
      Navigator.pop(context, true);
    } else {
      setState(() {
        _dangLuu = false;
        _loi = loi;
      });
    }
  }

  Widget _theGoi(GoiGio g, DateTime nay) {
    final dangDung = _laGoiDangDung(g);
    final chon = _dangChon == g.id;
    final so = goiSoVoiGio(g.soPhut, g.gia, widget.giaGoc);
    final het = widget.vao?.add(Duration(minutes: g.soPhut));
    final (soLon, donVi) = g.soPhut < 60
        ? ('${g.soPhut}', 'phút')
        : (g.soPhut % 60 == 0 ? '${g.soPhut ~/ 60}' : '${g.soPhut ~/ 60},5', 'giờ');
    final noiBat = chon || (dangDung && _dangChon == null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: noiBat ? const Color(0xFFF3FCFA) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: noiBat ? _kTeal : _nhat(0.12), width: noiBat ? 2 : 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _dangLuu || dangDung || g.id == null ? null : () => setState(() => _dangChon = g.id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: noiBat ? _kTeal : const Color(0xFFF1F0FA), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(soLon, style: _chu(21, FontWeight.w800, noiBat ? Colors.white : _kNavy)),
                      Text(donVi, style: _chu(11, FontWeight.w700, noiBat ? const Color(0xFFCFF3EC) : _nhat(0.55))),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmtVnd(g.gia), style: _chu(17, FontWeight.w800)),
                      if (so != null && so.chenh > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFDDF5F1), borderRadius: BorderRadius.circular(99)),
                          child: Text('rẻ hơn ${fmtVnd(so.chenh)}', style: _chu(11.5, FontWeight.w800, const Color(0xFF0F766E))),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (dangDung)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle_rounded, size: 15, color: _kTeal),
                        const SizedBox(width: 3),
                        Text('đang dùng', style: _chu(12, FontWeight.w800, _kTeal)),
                      ])
                    else if (het != null)
                      Text('hết lúc', style: _chu(11.5, FontWeight.w600, _nhat(0.55))),
                    if (het != null) Text(_gioPhut(het), style: _chu(14, FontWeight.w800, het.isBefore(nay) ? _kRed : _kNavy)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(giaGioCaiDatProvider).value?[widget.tableId]?.goi ?? const <GoiGio>[];
    final nay = DateTime.now();
    final vao = widget.vao;
    final daChoi = vao == null ? null : nay.difference(vao).inMinutes;
    final chonGoi = ds.where((g) => g.id == _dangChon).firstOrNull;
    final nhanNut = _dangChon == null
        ? (_daCo ? 'Chọn gói muốn đổi' : 'Chọn một gói')
        : _dangChon == _bo
            ? 'Bỏ gói · tính theo giờ'
            : 'Dùng ${chonGoi?.ten.toLowerCase() ?? 'gói'} · ${fmtVnd(chonGoi?.gia ?? 0)}';
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(color: _kCream, borderRadius: BorderRadius.circular(26)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _keo(),
            const SizedBox(height: 12),
            Text('${_daCo ? 'Đổi gói' : 'Chọn gói'}${widget.tenBan == null ? '' : ' · ${widget.tenBan}'}',
                style: _chu(19, FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              _daCo
                  ? 'Đang dùng: ${goiCuaPhienChu(widget.goiPhut!, widget.goiGia)}'
                  : [
                      if (vao != null) 'Khách vào ${_gioPhut(vao)}',
                      if (daChoi != null && daChoi >= 0) 'đã chơi ${thoiLuongChu(daChoi < 1 ? 1 : daChoi)}',
                    ].join(' · '),
              style: _chu(13, FontWeight.w600, _nhat(0.6)),
            ),
            const SizedBox(height: 14),
            if (ds.isEmpty)
              Text('Bàn này chưa có gói. Giữ lâu vào bàn → "Đặt giá giờ" → "Gói giờ" để thêm.',
                  style: _chu(13, FontWeight.w600, _nhat(0.6)))
            else
              for (final g in ds) _theGoi(g, nay),
            if (_daCo)
              Material(
                color: _dangChon == _bo ? const Color(0xFFFFF4EE) : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: _dangChon == _bo ? _kOrange : _nhat(0.2), width: 1.2),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _dangLuu ? null : () => setState(() => _dangChon = _bo),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.timer_off_outlined, size: 20, color: _nhat(0.6)),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Không dùng gói — tính theo giờ', style: _chu(14, FontWeight.w700, _nhat(0.75)))),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              _daCo
                  ? 'Đổi hoặc bỏ gói đã chọn cần Chủ quán / Quản lý.'
                  : 'Gói tính từ lúc khách vào. Về sớm vẫn trả đủ gói; chơi lố tính thêm theo giá giờ.',
              textAlign: TextAlign.center,
              style: _chu(12, FontWeight.w500, _nhat(0.6)),
            ),
            if (_loi != null) ...[
              const SizedBox(height: 8),
              Text(_loi!, textAlign: TextAlign.center, style: _chu(13, FontWeight.w700, _kRed)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _dangChon == null || _dangLuu ? null : _xacNhan,
                style: FilledButton.styleFrom(
                  backgroundColor: _dangChon == _bo ? _kOrange : _kTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _dangLuu
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(nhanNut, style: _chu(15.5, FontWeight.w800, Colors.white)),
              ),
            ),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: _dangLuu ? null : () => Navigator.pop(context),
                child: Text('Đóng', style: _chu(14.5, FontWeight.w700, _nhat(0.6))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mở hộp chọn / đổi gói.
Future<void> moChonGoi(
  BuildContext context, {
  required String tableId,
  required String sessionId,
  int? goiPhut,
  double? goiGia,
  String? tenBan,
  DateTime? vao,
  double? giaGoc,
}) =>
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChonGoiSheet(
        tableId: tableId,
        sessionId: sessionId,
        goiPhut: goiPhut,
        goiGia: goiGia,
        tenBan: tenBan,
        vao: vao,
        giaGoc: giaGoc,
      ),
    );

/// Dòng gói trong khối ĐANG TÍNH GIỜ (nền xanh đậm): tên gói + thanh còn lại (xanh ngọc → vàng khi còn ≤ 10 phút →
/// cam đỏ khi lố) + nút chọn / đổi gói. Bàn không có gói nào và phiên chưa chọn gói thì không hiện gì.
class GoiGioDongBan extends ConsumerWidget {
  final String tableId;
  final String sessionId;
  final int? goiPhut;
  final double? goiGia;
  final DateTime vao;
  final DateTime luc;
  final String? tenBan;
  final double? giaGoc;
  const GoiGioDongBan({
    super.key,
    required this.tableId,
    required this.sessionId,
    required this.goiPhut,
    required this.goiGia,
    required this.vao,
    required this.luc,
    this.tenBan,
    this.giaGoc,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coGoi = goiPhut != null && goiPhut! > 0;
    final dsGoi = ref.watch(giaGioCaiDatProvider).value?[tableId]?.goi ?? const <GoiGio>[];
    if (!coGoi && dsGoi.isEmpty) return const SizedBox.shrink();
    void mo() => moChonGoi(context,
        tableId: tableId, sessionId: sessionId, goiPhut: goiPhut, goiGia: goiGia, tenBan: tenBan, vao: vao, giaGoc: giaGoc);
    Widget nut(String chu, {Color? nen}) => Material(
          color: nen ?? Colors.white.withValues(alpha: 0.16),
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: mo,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Text(chu, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ),
        );
    TextStyle chu(double c, FontWeight w, Color m) => GoogleFonts.plusJakartaSans(fontSize: c, fontWeight: w, color: m);
    if (!coGoi) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: Colors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 8),
              Expanded(child: Text('Chưa chọn gói · đang tính theo giờ', style: chu(13, FontWeight.w700, Colors.white.withValues(alpha: 0.85)))),
              nut('Chọn gói', nen: _kTeal),
            ],
          ),
        ),
      );
    }
    final con = goiConPhut(goiPhut!, vao, luc);
    final het = vao.add(Duration(minutes: goiPhut!));
    final daLo = con <= 0;
    final sapHet = !daLo && con <= kGoiNhacTruoc.inMinutes;
    final mau = daLo ? const Color(0xFFFFB4A8) : (sapHet ? const Color(0xFFFFC94D) : const Color(0xFF7EE0D2));
    final phanDaDung = (1 - con / goiPhut!).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        decoration: BoxDecoration(
          color: daLo ? const Color(0x1FFF785A) : (sapHet ? const Color(0x14FFC94D) : Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: mau.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(daLo ? Icons.timer_off_outlined : Icons.timer_outlined, size: 18, color: mau),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(daLo ? 'Hết gói · hết lúc ${_gioPhut(het)}' : goiCuaPhienChu(goiPhut!, goiGia),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: chu(13, FontWeight.w800, mau)),
                ),
                nut('Đổi gói'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: phanDaDung,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(daLo ? const Color(0xFFFF8A65) : (sapHet ? const Color(0xFFFFC94D) : const Color(0xFF2DD4BF))),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: daLo ? 'Lố ' : 'Còn '),
                      TextSpan(text: thoiLuongChu(daLo ? -con : con), style: chu(15, FontWeight.w800, mau)),
                      if (daLo) const TextSpan(text: ' · tính thêm theo giá giờ') else if (sapHet) const TextSpan(text: ' · báo khách'),
                    ]),
                    style: chu(12.5, FontWeight.w700, Colors.white.withValues(alpha: 0.9)),
                  ),
                ),
                if (!daLo) Text('hết lúc ${_gioPhut(het)}', style: chu(12, FontWeight.w600, Colors.white.withValues(alpha: 0.75))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp nhắc khi bàn có gói còn [kGoiNhacTruoc] và khi hết gói. Gắn cạnh hộp nhắc đặt trước (TinhGioNhacDatSan).
/// shortcut: nhắc theo từng máy (nhớ trong bộ nhớ app), máy khác vẫn nhắc lại; ghi "đã báo" lên máy chủ khi quán
/// thấy phiền.
class TinhGioNhacGoi extends ConsumerStatefulWidget {
  const TinhGioNhacGoi({super.key});

  @override
  ConsumerState<TinhGioNhacGoi> createState() => _TinhGioNhacGoiState();
}

class _TinhGioNhacGoiState extends ConsumerState<TinhGioNhacGoi> {
  Timer? _dongHo;
  final _daHien = <String>{};
  bool _dangHien = false;

  @override
  void initState() {
    super.initState();
    _dongHo = Timer.periodic(const Duration(seconds: 30), (_) => _xet());
  }

  @override
  void dispose() {
    _dongHo?.cancel();
    super.dispose();
  }

  bool get _duocNhac {
    final phien = ref.read(sessionProvider);
    if (phien == null || !phien.hasStore) return false;
    if (phien.isOwner) return true;
    return ref.read(userActionPermsProvider).value?.contains('pos.checkout') ?? false;
  }

  void _xet() {
    if (!mounted || _dangHien || !_duocNhac) return;
    final ds = ref.read(activeSessionsProvider).value ?? const <String, BanSessionModel>{};
    final n = goiCanNhac(ds.values, DateTime.now(), _daHien);
    if (n == null) return;
    _daHien.add('${n.khoa}|sap');
    if (n.daHet) _daHien.add('${n.khoa}|het');
    unawaited(_hien(n.s, n.het, n.daHet));
  }

  Future<void> _hien(BanSessionModel s, DateTime het, bool daHet) async {
    _dangHien = true;
    unawaited(QrSoundService.playNotificationSound());
    final ban = (ref.read(allBanTablesProvider).value ?? const <BanTableModel>[])
            .where((b) => b.id == s.tableId)
            .firstOrNull
            ?.label ??
        '';
    final viec = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Dialog(
        backgroundColor: _kCream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: HopNhacGoi(
          tenBan: ban,
          goiPhut: s.goiPhut!,
          goiGia: s.goiGia,
          het: het,
          daHet: daHet,
          onDoiGoi: () => Navigator.pop(ctx, 'doi'),
          onDaBao: () => Navigator.pop(ctx),
        ),
      ),
    );
    _dangHien = false;
    if (viec == 'doi' && mounted) {
      await moChonGoi(context,
          tableId: s.tableId,
          sessionId: s.id,
          goiPhut: s.goiPhut,
          goiGia: s.goiGia,
          tenBan: ban.isEmpty ? null : ban,
          vao: s.gioBatDau == null ? null : DateTime.fromMillisecondsSinceEpoch(s.gioBatDau!));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(tinhGioModuleActiveProvider)) return const SizedBox.shrink();
    // Quán chưa cài gói nào thì không theo dõi phiên (đỡ tải máy chủ).
    final coGoi = ref.watch(giaGioCaiDatProvider).value?.values.any((c) => c.goi.isNotEmpty) ?? false;
    if (!coGoi) return const SizedBox.shrink();
    ref.watch(allBanTablesProvider);
    ref.listen(activeSessionsProvider, (_, _) => _xet());
    return const SizedBox.shrink();
  }
}

/// Nội dung hộp nhắc: vòng đếm ngược (sắp hết) hoặc biểu tượng hết gói, tên bàn, giờ hết, hai nút.
class HopNhacGoi extends StatelessWidget {
  final String tenBan;
  final int goiPhut;
  final double? goiGia;
  final DateTime het;
  final bool daHet;
  final VoidCallback onDoiGoi;
  final VoidCallback onDaBao;
  /// Giờ "bây giờ" (test / ảnh mẫu); mặc định giờ máy.
  final DateTime? nay;
  const HopNhacGoi({
    super.key,
    required this.tenBan,
    required this.goiPhut,
    required this.goiGia,
    required this.het,
    required this.daHet,
    required this.onDoiGoi,
    required this.onDaBao,
    this.nay,
  });

  @override
  Widget build(BuildContext context) {
    final con = het.difference(nay ?? DateTime.now()).inMinutes.clamp(0, 999);
    final ten = tenBan.isEmpty ? 'Bàn' : tenBan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: daHet
                ? Container(
                    decoration: const BoxDecoration(color: Color(0xFFFDECEC), shape: BoxShape.circle),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_off_rounded, size: 34, color: Color(0xFFDC2626)),
                        Text('HẾT GÓI', style: _chu(11, FontWeight.w800, const Color(0xFFB42318))),
                      ],
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: (1 - con / goiPhut).clamp(0.0, 1.0),
                        strokeWidth: 9,
                        backgroundColor: const Color(0xFFFCE3D2),
                        valueColor: const AlwaysStoppedAnimation(_kOrange),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("$con'", style: _chu(28, FontWeight.w800, const Color(0xFFE8590C))),
                            Text('CÒN LẠI', style: _chu(10.5, FontWeight.w800, const Color(0xFF9A3412))),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Text(daHet ? '$ten đã hết gói' : '$ten sắp hết gói', textAlign: TextAlign.center, style: _chu(19, FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            daHet
                ? '${goiCuaPhienChu(goiPhut, goiGia)} · hết lúc ${_gioPhut(het)}. Chơi tiếp thì tính thêm theo giá giờ.'
                : '${goiCuaPhienChu(goiPhut, goiGia)} · hết lúc ${_gioPhut(het)}. Báo khách gia hạn hoặc chuẩn bị về.',
            textAlign: TextAlign.center,
            style: _chu(13.5, FontWeight.w500, _nhat(0.7)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onDoiGoi,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kNavy,
                      side: BorderSide(color: _nhat(0.25)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: FittedBox(child: Text('Đổi / thêm gói', style: _chu(14, FontWeight.w800))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: onDaBao,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kNavy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: FittedBox(child: Text('Đã báo khách', style: _chu(14, FontWeight.w800, Colors.white))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
