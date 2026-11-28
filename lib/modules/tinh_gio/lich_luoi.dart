// Lịch đặt dạng lưới "giờ × bàn / sân" (đợt 2 lộ trình tính giờ, .docs/ke-hoach-lich-dat-luoi.md).
// Chỉ đọc lượt đặt như màn danh sách; chạm ô trống mở hộp đặt đúng bàn + giờ, chạm khối mở hộp lượt đặt.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/repositories/ban_repository.dart' show BanTableModel;
import 'dat_truoc.dart';

const _kNavy = Color(0xFF1C2151);
const _kGreen = Color(0xFF15803D);
const _kRed = Color(0xFFEF4444);

TextStyle _chu(double size, FontWeight w, [Color? c]) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c ?? _kNavy);

/// Chiều cao một giờ trên lưới (điểm).
const kLichPxGio = 64.0;
const _kCotGio = 52.0;
const _kCotToiThieu = 112.0;
const _kDauCot = 48.0;

/// Giờ đầu của lưới: 06:00, sớm hơn nếu có lượt đặt bắt đầu sớm hơn trong ngày.
int lichGioDau(DateTime ngay, Iterable<DatTruoc> dat) {
  final dau = DateTime(ngay.year, ngay.month, ngay.day);
  var g = 6;
  for (final d in dat) {
    final s = d.gioTu.isBefore(dau) ? dau : d.gioTu;
    if (s.day == dau.day && s.hour < g) g = s.hour;
  }
  return g;
}

/// Vị trí khối lượt đặt trên cột: [top], [cao] tính bằng điểm từ đầu lưới; [quaDem] = còn tiếp sang hôm sau.
/// null khi lượt không rơi vào ngày đang xem.
({double top, double cao, bool quaDem})? lichViTriKhoi(DatTruoc d, DateTime ngay, int gioDau) {
  final dauNgay = DateTime(ngay.year, ngay.month, ngay.day);
  final dauLuoi = dauNgay.add(Duration(hours: gioDau));
  final cuoi = dauNgay.add(const Duration(days: 1));
  final s = d.gioTu.isBefore(dauLuoi) ? dauLuoi : d.gioTu;
  final e = d.gioDen.isAfter(cuoi) ? cuoi : d.gioDen;
  if (!e.isAfter(s)) return null;
  const px = kLichPxGio / 60;
  final top = s.difference(dauLuoi).inMinutes * px;
  final cao = e.difference(s).inMinutes * px;
  return (top: top, cao: cao < 24 ? 24 : cao, quaDem: d.gioDen.isAfter(cuoi));
}

/// Giờ bắt đầu khi chạm ô trống ở độ cao [dy]: làm tròn xuống nửa giờ.
DateTime lichGioCuaO(DateTime ngay, int gioDau, double dy) {
  final phut = (dy / (kLichPxGio / 60)).floor();
  final nuaGio = (phut ~/ 30) * 30;
  return DateTime(ngay.year, ngay.month, ngay.day, gioDau).add(Duration(minutes: nuaGio));
}

class LichLuoi extends StatefulWidget {
  final List<BanTableModel> bans;
  final List<DatTruoc> dat;
  final DateTime ngay;
  final void Function(BanTableModel ban, DateTime tu) onDatO;
  final void Function(BanTableModel ban, DatTruoc d) onMo;
  /// Giờ hiện tại (test cố định); null = bây giờ.
  final DateTime? luc;

  const LichLuoi({
    super.key,
    required this.bans,
    required this.dat,
    required this.ngay,
    required this.onDatO,
    required this.onMo,
    this.luc,
  });

  @override
  State<LichLuoi> createState() => _LichLuoiState();
}

class _LichLuoiState extends State<LichLuoi> {
  final _doc = ScrollController();
  final _ngang = ScrollController();
  final _ngangDau = ScrollController();

  DateTime get _bayGio => widget.luc ?? DateTime.now();

  bool get _homNay {
    final n = _bayGio;
    return n.year == widget.ngay.year && n.month == widget.ngay.month && n.day == widget.ngay.day;
  }

  @override
  void initState() {
    super.initState();
    // Tên cột cuộn ngang theo thân lưới.
    _ngang.addListener(() {
      if (_ngangDau.hasClients) _ngangDau.jumpTo(_ngang.offset.clamp(0, _ngangDau.position.maxScrollExtent));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _cuonToiBayGio());
  }

  @override
  void didUpdateWidget(LichLuoi cu) {
    super.didUpdateWidget(cu);
    if (cu.ngay != widget.ngay) WidgetsBinding.instance.addPostFrameCallback((_) => _cuonToiBayGio());
  }

  /// Hôm nay: cuộn tới một giờ trước giờ hiện tại; ngày khác: về đầu.
  void _cuonToiBayGio() {
    if (!mounted || !_doc.hasClients) return;
    final gioDau = lichGioDau(widget.ngay, widget.dat);
    final dich = _homNay ? ((_bayGio.hour - 1 - gioDau) * kLichPxGio).toDouble() : 0.0;
    _doc.jumpTo(dich.clamp(0, _doc.position.maxScrollExtent));
  }

  @override
  void dispose() {
    _doc.dispose();
    _ngang.dispose();
    _ngangDau.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bans = widget.bans;
    final gioDau = lichGioDau(widget.ngay, widget.dat);
    final soGio = 24 - gioDau;
    final cao = soGio * kLichPxGio;
    return LayoutBuilder(
      builder: (context, c) {
        final rongCot = ((c.maxWidth - _kCotGio - 8) / bans.length).clamp(_kCotToiThieu, double.infinity);
        final tongRong = rongCot * bans.length;
        return Column(
          children: [
            // Tên bàn / sân: đứng yên khi cuộn dọc, cuộn ngang theo thân lưới.
            Container(
              height: _kDauCot,
              color: Colors.white,
              child: Row(
                children: [
                  const SizedBox(width: _kCotGio),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _ngangDau,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: [
                          for (final b in bans)
                            SizedBox(
                              width: rongCot,
                              child: Center(
                                child: Text(
                                  b.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _chu(14, FontWeight.w800),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _kNavy.withValues(alpha: 0.1)),
            Expanded(
              child: SingleChildScrollView(
                controller: _doc,
                padding: const EdgeInsets.only(top: 10, bottom: 24),
                child: SizedBox(
                  height: cao,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: _kCotGio,
                        height: cao,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (var i = 0; i <= soGio; i++)
                              Positioned(
                                top: i * kLichPxGio - 8,
                                left: 0,
                                right: 8,
                                child: Text(
                                  '${((gioDau + i) % 24).toString().padLeft(2, '0')}:00',
                                  textAlign: TextAlign.right,
                                  style: _chu(11.5, FontWeight.w700, _kNavy.withValues(alpha: 0.55)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _ngang,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tongRong,
                            height: cao,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CustomPaint(
                                  size: Size(tongRong, cao),
                                  painter: _LuoiPainter(soCot: bans.length, rongCot: rongCot, soGio: soGio),
                                ),
                                // ô trống: chạm để đặt đúng bàn + nửa giờ đó
                                for (var i = 0; i < bans.length; i++)
                                  Positioned(
                                    left: i * rongCot,
                                    top: 0,
                                    width: rongCot,
                                    height: cao,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapUp: (e) => widget.onDatO(
                                        bans[i],
                                        lichGioCuaO(widget.ngay, gioDau, e.localPosition.dy),
                                      ),
                                    ),
                                  ),
                                for (var i = 0; i < bans.length; i++)
                                  for (final d in widget.dat.where((d) => d.tableId == bans[i].id))
                                    if (lichViTriKhoi(d, widget.ngay, gioDau) case final v?)
                                      Positioned(
                                        left: i * rongCot + 3,
                                        top: v.top + 1,
                                        width: rongCot - 6,
                                        height: v.cao - 2,
                                        child: _KhoiLuot(d: d, quaDem: v.quaDem, onTap: () => widget.onMo(bans[i], d)),
                                      ),
                                if (_homNay && _bayGio.hour >= gioDau)
                                  Positioned(
                                    left: 0,
                                    width: tongRong,
                                    top: (_bayGio.hour - gioDau) * kLichPxGio + _bayGio.minute * kLichPxGio / 60 - 1,
                                    child: IgnorePointer(child: Container(height: 2, color: _kRed)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KhoiLuot extends StatelessWidget {
  final DatTruoc d;
  final bool quaDem;
  final VoidCallback onTap;
  const _KhoiLuot({required this.d, required this.quaDem, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (nen, chu) = switch (d.trangThai) {
      'da_dat' => (_kNavy, Colors.white),
      'da_nhan' => (_kGreen, Colors.white),
      _ => (const Color(0xFFE5E1EC), _kNavy.withValues(alpha: 0.55)),
    };
    final gio = '${gioPhut(d.gioTu)}–${quaDem ? '24:00' : gioPhut(d.gioDen)}';
    final gach = d.conHieuLuc ? null : TextDecoration.lineThrough;
    return Semantics(
      button: true,
      label: '${d.tenKhach}, $gio',
      child: Material(
        color: nen,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
            child: LayoutBuilder(
              builder: (context, c) => c.maxHeight < 40
                  ? Text('${gioPhut(d.gioTu)} ${d.tenKhach}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _chu(11.5, FontWeight.w700, chu).copyWith(decoration: gach))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(gio, maxLines: 1, style: _chu(11, FontWeight.w600, chu).copyWith(decoration: gach)),
                            ),
                            if (d.chuoiId != null) ...[
                              const SizedBox(width: 3),
                              Icon(Icons.repeat_rounded, size: 12, color: chu), // lịch cố định
                            ],
                          ],
                        ),
                        Flexible(
                          child: Text(
                            d.tenKhach,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _chu(13, FontWeight.w800, chu).copyWith(decoration: gach),
                          ),
                        ),
                        if (quaDem && c.maxHeight >= 64)
                          Text('→ hôm sau', style: _chu(10.5, FontWeight.w600, chu)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LuoiPainter extends CustomPainter {
  final int soCot;
  final double rongCot;
  final int soGio;
  _LuoiPainter({required this.soCot, required this.rongCot, required this.soGio});

  @override
  void paint(Canvas canvas, Size size) {
    final gio = Paint()
      ..color = _kNavy.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    final nua = Paint()
      ..color = _kNavy.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = 0; i <= soGio; i++) {
      final y = i * kLichPxGio;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gio);
      if (i < soGio) canvas.drawLine(Offset(0, y + kLichPxGio / 2), Offset(size.width, y + kLichPxGio / 2), nua);
    }
    for (var i = 0; i <= soCot; i++) {
      final x = i * rongCot;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gio);
    }
  }

  @override
  bool shouldRepaint(_LuoiPainter o) => o.soCot != soCot || o.rongCot != rongCot || o.soGio != soGio;
}
