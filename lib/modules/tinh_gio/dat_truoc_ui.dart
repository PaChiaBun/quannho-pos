import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/repositories/ban_repository.dart';
import '../../core/repositories/core_customer_repository.dart';
import '../../core/services/staff_service.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/responsive.dart';
import '../qr_order/services/qr_sound_service.dart';
import 'dat_truoc.dart';
import 'gia_gio.dart' show thuChuCua, tinhGioGiaLuc, tinhGioTien;
import 'gia_gio_ui.dart' show SoChamFormatter;
import 'goi_gio_ui.dart' show TinhGioNhacGoi;
import 'lich_luoi.dart';
import 'tinh_gio_widgets.dart';

const _kNavy = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kCream = Color(0xFFFFF8F0);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);

TextStyle _chu(double size, FontWeight w, [Color? c]) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c ?? _kNavy);

const _kThu = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
String _ngayChu(DateTime d) =>
    '${_kThu[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
DateTime _dauNgay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Bàn của quán để đặt trước: bàn tính giờ trước; quán chưa gắn giá giờ cho bàn nào thì mọi bàn.
final banDeDatProvider = FutureProvider.autoDispose<List<BanTableModel>>((ref) async {
  ref.watch(sessionProvider);
  final tatCa = await ref.watch(banRepositoryProvider).getAllTables();
  final tinhGio = tatCa.where((b) => b.tinhGio).toList();
  final ds = (tinhGio.isEmpty ? tatCa : tinhGio)..sort((a, b) => compareNatural(a.label, b.label));
  return ds;
});

void _thongBao(BuildContext context, String s, {bool loi = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(s, style: _chu(13.5, FontWeight.w600, Colors.white)),
    backgroundColor: loi ? _kRed : _kGreen,
    behavior: SnackBarBehavior.floating,
  ));
}

/// Gọi điện cho khách; máy không gọi được (máy tính, web) thì chép số.
Future<void> goiKhach(BuildContext context, String sdt) async {
  var daGoi = false;
  try {
    daGoi = await launchUrl(Uri(scheme: 'tel', path: sdt));
  } catch (_) {}
  if (!daGoi) {
    await Clipboard.setData(ClipboardData(text: sdt));
    if (context.mounted) _thongBao(context, 'Đã chép số $sdt');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MÀN LỊCH ĐẶT
// ─────────────────────────────────────────────────────────────────────────────
class LichDatScreen extends ConsumerStatefulWidget {
  /// Ngày mở đầu (mặc định hôm nay).
  final DateTime? ngay;
  /// Mở ở kiểu lưới (mặc định) hay danh sách.
  final bool luoi;
  /// Giờ hiện tại cho lưới (ảnh mẫu trong test cố định); null = bây giờ.
  final DateTime? lucLuoi;

  const LichDatScreen({super.key, this.ngay, this.luoi = true, this.lucLuoi});

  @override
  ConsumerState<LichDatScreen> createState() => _LichDatScreenState();
}

class _LichDatScreenState extends ConsumerState<LichDatScreen> {
  late DateTime _ngay = _dauNgay(widget.ngay ?? DateTime.now());
  /// Lưới giờ × bàn (mặc định, đợt 2) hay danh sách theo bàn như trước.
  late bool _luoi = widget.luoi;

  void _doiNgay(int soNgay) => setState(() => _ngay = _ngay.add(Duration(days: soNgay)));

  Future<void> _chonNgay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _ngay,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (d != null) setState(() => _ngay = _dauNgay(d));
  }

  Future<void> _dat(BanTableModel ban, List<DatTruoc> trongNgay, {DatTruoc? sua, DateTime? tu}) async {
    final ok = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // bàn phím bật thì hộp cao hết màn: chừa thanh trạng thái (máy ảo 28/11 đầu hộp đè giờ, sóng)
      useSafeArea: true,
      builder: (_) => DatTruocFormSheet(ban: ban, ngay: _ngay, trongNgay: trongNgay, sua: sua, tuMacDinh: tu),
    );
    if (!mounted) return;
    if (ok == true) _thongBao(context, sua == null ? 'Đã đặt ${ban.label}' : 'Đã sửa lượt đặt');
    if (ok is String) _thongBao(context, ok, loi: true);
  }

  Future<void> _moLuot(BanTableModel ban, DatTruoc d, List<DatTruoc> trongNgay) async {
    final viec = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LuotDatSheet(ban: ban, dat: d),
    );
    if (!mounted || viec == null) return;
    final repo = ref.read(datTruocRepositoryProvider);
    switch (viec) {
      case 'sua':
        await _dat(ban, trongNgay, sua: d);
      case 'goi':
        if (d.sdt != null) await goiKhach(context, d.sdt!);
      case 'nhan':
        final loi = await nhanSanTuLuotDat(context, ref, d, ban.label);
        if (mounted) _thongBao(context, loi ?? 'Đã nhận ${ban.label} cho ${d.tenKhach}', loi: loi != null);
      case 'huy_chuoi':
        List<DatTruoc> chuoi = const [];
        try {
          chuoi = await ref.read(chuoiDatProvider(d.chuoiId!).future);
        } catch (_) {}
        if (!mounted) return;
        final seHuy = chuoi.where((c) => c.choKhach && !c.gioTu.isBefore(d.gioTu)).toList();
        final dongY = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(seHuy.isEmpty ? 'Huỷ lịch cố định?' : 'Huỷ ${seHuy.length} buổi?'),
            content: Text(
              seHuy.isEmpty
                  ? 'Huỷ buổi ${_ngayChu(d.gioTu)} và mọi buổi sau còn chờ khách của ${d.tenKhach} ở ${ban.label}. '
                      'Buổi khách đã đến giữ nguyên.'
                  : 'Huỷ ${seHuy.length} buổi chờ khách của ${d.tenKhach} ở ${ban.label}, từ ${_ngayChu(seHuy.first.gioTu)} '
                      'tới ${_ngayChu(seHuy.last.gioTu)}. Buổi khách đã đến và các buổi trước giữ nguyên.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Không')),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Huỷ các buổi', style: TextStyle(color: _kRed)),
              ),
            ],
          ),
        );
        if (dongY != true || !mounted) return;
        final r = await repo.huyChuoi(d.chuoiId!, d.gioTu);
        ref.invalidate(chuoiDatProvider(d.chuoiId!));
        if (mounted) {
          final so = (r['data'] as Map?)?['so_buoi_huy'];
          _thongBao(
            context,
            r['success'] == true ? 'Đã huỷ $so buổi' : (r['message'] as String? ?? 'Chưa làm được'),
            loi: r['success'] != true,
          );
        }
        // Cọc của lịch: chỉ xử lý khi không còn buổi nào chờ khách (các buổi trước mốc huỷ đã qua / đã nhận).
        final cocLich = chuoi.where((c) => c.coCocCho).firstOrNull;
        if (r['success'] == true && cocLich != null && !chuoi.any((c) => c.choKhach && c.gioTu.isBefore(d.gioTu))) {
          await _hoiXuLyCoc(ban, cocLich, khongDen: false);
        }
      case 'huy' || 'khong_den':
        final r = await repo.doiTrangThai(d.id, viec);
        if (mounted) {
          _thongBao(
            context,
            r['success'] == true
                ? (viec == 'huy' ? 'Đã huỷ lượt đặt' : 'Đã ghi khách không đến')
                : (r['message'] as String? ?? 'Chưa làm được'),
            loi: r['success'] != true,
          );
        }
        // Lượt lẻ có cọc: hỏi ngay. Buổi của lịch cố định: cọc giữ cho các buổi sau.
        if (r['success'] == true && d.coCocCho && d.chuoiId == null) {
          await _hoiXuLyCoc(ban, d, khongDen: viec == 'khong_den');
        }
      case 'xu_ly_coc':
        await _hoiXuLyCoc(ban, d, khongDen: d.trangThai == 'khong_den');
    }
  }

  Future<void> _hoiXuLyCoc(BanTableModel ban, DatTruoc d, {required bool khongDen}) async {
    if (!mounted) return;
    final phien = ref.read(sessionProvider);
    final vaiTro = StaffService.canonicalRole(phien?.role ?? '');
    final laQuanLy = phien?.isOwner == true || vaiTro == 'owner' || vaiTro == 'manager';
    final cach = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => XuLyCocSheet(dat: d, tenBan: ban.label, khongDen: khongDen, laQuanLy: laQuanLy),
    );
    if (cach == null || !mounted) return;
    final r = await ref.read(datTruocRepositoryProvider).xuLyCoc(d.id, cach, d.cocQuy ?? 'cash');
    if (!mounted) return;
    _thongBao(
      context,
      r['success'] == true
          ? switch (cach) {
              'trong_vi' => 'Đã để ${fmtVnd(d.tienCoc)} trong ví ${d.tenKhach}',
              'quan_giu' => 'Quán giữ cọc ${fmtVnd(d.tienCoc)}',
              _ => 'Đã hoàn cọc ${fmtVnd(d.tienCoc)} (phiếu chi Thu Chi)',
            }
          : (r['message'] as String? ?? 'Chưa làm được'),
      loi: r['success'] != true,
    );
  }

  /// Chạm ô trống trên lưới: nửa giờ đã qua thì báo, không mở hộp.
  void _datO(BanTableModel ban, DateTime tu, List<DatTruoc> trongNgay) {
    if (!tu.add(const Duration(minutes: 30)).isAfter(DateTime.now())) {
      _thongBao(context, 'Giờ này đã qua, chọn giờ khác', loi: true);
      return;
    }
    _dat(ban, trongNgay, tu: tu);
  }

  /// Nửa giờ kế tiếp của ngày đang xem để đặt nhanh: hôm nay = làm tròn lên từ bây giờ; ngày khác = 18:00.
  DateTime _gioDatNhanh() {
    final nay = DateTime.now();
    if (_ngay != _dauNgay(nay)) return _ngay.add(const Duration(hours: 18));
    final phut = nay.hour * 60 + nay.minute;
    // sau 23:30 không nhảy sang 00:00 ngày mai (lưới đang xem hôm nay)
    final len = math.min(((phut + 29) ~/ 30) * 30, 23 * 60 + 30);
    return _ngay.add(Duration(minutes: len));
  }

  /// Nút "+ Đặt lịch" (dạng lưới): chọn bàn / sân rồi mở hộp đặt ở nửa giờ kế tiếp (sửa giờ trong hộp).
  Future<void> _datNhanh(List<BanTableModel> bans, List<DatTruoc> dat) async {
    final ban = bans.length == 1
        ? bans.first
        : await showModalBottomSheet<BanTableModel>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: BoxDecoration(color: _kCream, borderRadius: BorderRadius.circular(26)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Đặt cho bàn / sân nào?', style: _chu(18, FontWeight.w800)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in bans)
                        ActionChip(
                          label: Text(b.label, style: _chu(15, FontWeight.w800)),
                          onPressed: () => Navigator.pop(ctx, b),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: _kNavy.withValues(alpha: 0.18)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
    if (ban == null || !mounted) return;
    _dat(ban, dat, tu: _gioDatNhanh());
  }

  @override
  Widget build(BuildContext context) {
    final bansAsync = ref.watch(banDeDatProvider);
    final datAsync = ref.watch(datTruocTheoNgayProvider(_ngay));
    final laHomNay = _ngay == _dauNgay(DateTime.now());

    Widget than(int soCot) {
      if (datAsync.hasError && !datAsync.hasValue) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Chưa tải được lịch đặt. Kiểm tra mạng; app tự thử lại sau ít giây.',
              textAlign: TextAlign.center,
              style: _chu(14, FontWeight.w600, _kNavy.withValues(alpha: 0.7)),
            ),
          ),
        );
      }
      final bans = bansAsync.value;
      final dat = datAsync.value;
      if (bans == null || dat == null) {
        return const Center(child: CircularProgressIndicator(color: _kNavy));
      }
      if (bans.isEmpty) {
        return Center(
          child: Text('Quán chưa có bàn nào. Thêm bàn ở màn Bàn trước.', style: _chu(14, FontWeight.w600)),
        );
      }
      if (_luoi) {
        return Column(
          children: [
            // Gợi ý cách đặt (Chủ Quán 28/11: lưới chưa nói chạm vào đâu để đặt)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB7E4DD)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, size: 20, color: Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chạm ô trống để đặt bàn / sân vào giờ đó. Chạm lượt đặt để xem, nhận khách hoặc huỷ.',
                      style: _chu(12.5, FontWeight.w600, const Color(0xFF0F5F58)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LichLuoi(
                bans: bans,
                dat: dat,
                ngay: _ngay,
                luc: widget.lucLuoi,
                onDatO: (b, tu) => _datO(b, tu, dat),
                onMo: (b, d) => _moLuot(b, d, dat),
              ),
            ),
          ],
        );
      }
      return LayoutBuilder(
        builder: (context, c) {
          final rong = (c.maxWidth - 16 * 2 - 12 * (soCot - 1)) / soCot;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final b in bans)
                  SizedBox(
                    width: rong,
                    child: _TheBanLich(
                      ban: b,
                      luot: dat.where((d) => d.tableId == b.id).toList(),
                      onDat: () => _dat(b, dat),
                      onMo: (d) => _moLuot(b, d, dat),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: _kCream,
      appBar: AppBar(
        backgroundColor: _kCream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _kNavy,
        // theme của app đặt biểu tượng thanh trên màu trắng: không ghi lại thì nút quay lại chìm vào nền kem
        iconTheme: const IconThemeData(color: _kNavy),
        title: Text('Lịch đặt', style: _chu(20, FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: _luoi ? 'Xem dạng danh sách' : 'Xem dạng lưới giờ',
            onPressed: () => setState(() => _luoi = !_luoi),
            icon: Icon(_luoi ? Icons.view_agenda_rounded : Icons.calendar_view_week_rounded, color: _kNavy),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Ngày trước',
                  onPressed: () => _doiNgay(-1),
                  icon: const Icon(Icons.chevron_left_rounded, color: _kNavy, size: 30),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _chonNgay,
                    child: Text(
                      laHomNay ? 'Hôm nay · ${_ngayChu(_ngay)}' : _ngayChu(_ngay),
                      style: _chu(16, FontWeight.w800),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Ngày sau',
                  onPressed: () => _doiNgay(1),
                  icon: const Icon(Icons.chevron_right_rounded, color: _kNavy, size: 30),
                ),
                if (!laHomNay)
                  TextButton(
                    onPressed: () => setState(() => _ngay = _dauNgay(DateTime.now())),
                    child: Text('Hôm nay', style: _chu(13.5, FontWeight.w700, _kOrange)),
                  ),
              ],
            ),
          ),
        ),
      ),
      // Điện thoại 1 cột, máy tính bảng 2 cột, màn rộng 3 cột.
      body: ResponsiveLayout(mobile: than(1), tablet: than(2), desktop: than(3)),
      floatingActionButton: _luoi && (bansAsync.value?.isNotEmpty ?? false) && datAsync.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => _datNhanh(bansAsync.value!, datAsync.value!),
              backgroundColor: _kNavy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text('Đặt lịch', style: _chu(15, FontWeight.w800, Colors.white)),
            )
          : null,
    );
  }
}

class _TheBanLich extends StatelessWidget {
  final BanTableModel ban;
  final List<DatTruoc> luot;
  final VoidCallback onDat;
  final ValueChanged<DatTruoc> onMo;

  const _TheBanLich({required this.ban, required this.luot, required this.onDat, required this.onMo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kNavy.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(ban.label, style: _chu(17, FontWeight.w800))),
              SizedBox(
                height: 44,
                child: TextButton.icon(
                  onPressed: onDat,
                  style: TextButton.styleFrom(
                    backgroundColor: _kNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Đặt', style: _chu(13.5, FontWeight.w800, Colors.white)),
                ),
              ),
            ],
          ),
          if (luot.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Chưa có lượt đặt', style: _chu(13, FontWeight.w500, _kNavy.withValues(alpha: 0.5))),
            ),
          for (final d in luot)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 4),
              child: Material(
                color: (d.conHieuLuc ? _kNavy : Colors.grey).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onMo(d),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${gioPhut(d.gioTu)}–${gioPhut(d.gioDen)} · ${d.tenKhach}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: _chu(14.5, FontWeight.w700).copyWith(
                                          decoration: d.conHieuLuc ? null : TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ),
                                    if (d.chuoiId != null) ...[
                                      const SizedBox(width: 4),
                                      Tooltip(
                                        message: 'Lịch cố định',
                                        child: Icon(Icons.repeat_rounded, size: 15, color: _kNavy.withValues(alpha: 0.7)),
                                      ),
                                    ],
                                  ],
                                ),
                                if ((d.sdt ?? '').isNotEmpty || d.nhacLuc != null)
                                  Text(
                                    [
                                      if ((d.sdt ?? '').isNotEmpty) d.sdt!,
                                      if (d.nhacLuc != null) 'đã nhắc ${gioPhut(d.nhacLuc!)}',
                                    ].join(' · '),
                                    style: _chu(12, FontWeight.w500, _kNavy.withValues(alpha: 0.6)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _NhanTrangThai(d.trangThai),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NhanTrangThai extends StatelessWidget {
  final String trangThai;
  const _NhanTrangThai(this.trangThai);

  @override
  Widget build(BuildContext context) {
    final (chu, mau) = switch (trangThai) {
      'da_nhan' => ('Đã nhận', _kGreen),
      'huy' => ('Đã huỷ', Colors.grey),
      'khong_den' => ('Không đến', _kRed),
      _ => ('Chờ khách', _kOrange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: mau.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(chu, style: _chu(11.5, FontWeight.w800, mau)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HỘP VIỆC CỦA MỘT LƯỢT ĐẶT
// ─────────────────────────────────────────────────────────────────────────────
class _LuotDatSheet extends ConsumerWidget {
  final BanTableModel ban;
  final DatTruoc dat;
  const _LuotDatSheet({required this.ban, required this.dat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lịch cố định: "buổi 3/8 · T3, T5 · tới 26/12"
    final chuoi = dat.chuoiId == null ? null : ref.watch(chuoiDatProvider(dat.chuoiId!)).value;
    String? dongChuoi;
    if (chuoi != null && chuoi.isNotEmpty) {
      final thu = {for (final c in chuoi) c.gioTu.weekday};
      final i = chuoi.indexWhere((c) => c.id == dat.id) + 1;
      final cuoi = chuoi.last.gioTu;
      dongChuoi = 'Lịch cố định · buổi $i/${chuoi.length} · ${thuChuCua(thu)} · tới '
          '${cuoi.day.toString().padLeft(2, '0')}/${cuoi.month.toString().padLeft(2, '0')}';
    }
    Widget viec(String ma, IconData icon, String chu, {Color? mau}) => ListTile(
          minTileHeight: 52,
          leading: Icon(icon, color: mau ?? _kNavy),
          title: Text(chu, style: _chu(15, FontWeight.w700, mau)),
          onTap: () => Navigator.pop(context, ma),
        );
    final phu = [
      if ((dat.sdt ?? '').isNotEmpty) dat.sdt!,
      if (dat.tienCoc > 0)
        switch (dat.cocTrangThai) {
          'da_thu' => 'cọc ${fmtVnd(dat.tienCoc)} trong ví khách',
          'da_tru' => 'cọc ${fmtVnd(dat.tienCoc)} đã trừ',
          'trong_vi' => 'cọc ${fmtVnd(dat.tienCoc)} để trong ví',
          'quan_giu' => 'quán giữ cọc ${fmtVnd(dat.tienCoc)}',
          'da_hoan' => 'đã hoàn cọc ${fmtVnd(dat.tienCoc)}',
          _ => 'đã cọc ${fmtVnd(dat.tienCoc)}',
        },
      if ((dat.nguoiTaoTen ?? '').isNotEmpty) 'đặt bởi ${dat.nguoiTaoTen}',
      if (dat.nhacLuc != null) 'đã nhắc ${gioPhut(dat.nhacLuc!)}${dat.nhacBoi != null ? ' · ${dat.nhacBoi}' : ''}',
      if (dat.chuoiId != null && dongChuoi == null) 'lịch cố định hàng tuần',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      decoration: BoxDecoration(color: _kCream, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '${dat.tenKhach} · ${ban.label}',
              textAlign: TextAlign.center,
              style: _chu(18, FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_ngayChu(dat.gioTu)} · ${gioPhut(dat.gioTu)}–${gioPhut(dat.gioDen)}',
            style: _chu(14, FontWeight.w700, _kOrange),
          ),
          if (dongChuoi != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.repeat_rounded, size: 16, color: _kNavy),
                  const SizedBox(width: 4),
                  Flexible(child: Text(dongChuoi, style: _chu(12.5, FontWeight.w700))),
                ],
              ),
            ),
          if (phu.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Text(phu, textAlign: TextAlign.center, style: _chu(12.5, FontWeight.w500, _kNavy.withValues(alpha: 0.65))),
            ),
          if ((dat.ghiChu ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Text('Ghi chú: ${dat.ghiChu}', textAlign: TextAlign.center, style: _chu(13, FontWeight.w500)),
            ),
          const SizedBox(height: 8),
          if ((dat.sdt ?? '').isNotEmpty) viec('goi', Icons.call_rounded, 'Gọi khách'),
          if (dat.choKhach) ...[
            viec('nhan', Icons.how_to_reg_rounded, 'Khách đã đến: nhận ${ban.label}', mau: _kGreen),
            viec('sua', Icons.edit_rounded, 'Sửa lượt đặt'),
            viec('khong_den', Icons.person_off_rounded, 'Khách không đến'),
            viec('huy', Icons.cancel_rounded, dat.chuoiId != null ? 'Huỷ riêng buổi này' : 'Huỷ lượt đặt', mau: _kRed),
            if (dat.chuoiId != null)
              viec('huy_chuoi', Icons.event_busy_rounded, 'Huỷ buổi này và các buổi sau', mau: _kRed),
          ],
          // đã huỷ / không đến mà cọc chưa xử lý (đóng hộp hỏi lúc trước); đã nhận khách mà cọc chưa trừ (bàn bị gộp /
          // huỷ — QC 28/11): máy chủ chỉ cho khi bàn không còn mở, còn mở thì báo "thanh toán bàn sẽ tự trừ cọc"
          if (dat.coCocCho && (!dat.conHieuLuc || dat.trangThai == 'da_nhan'))
            viec('xu_ly_coc', Icons.savings_rounded, 'Xử lý tiền cọc ${fmtVnd(dat.tienCoc)}', mau: _kOrange),
        ],
      ),
    );
  }
}

/// Khách của lượt đặt đã đến: mở bàn (hoặc dùng bàn đang mở) rồi gắn lượt đặt. Trả câu lỗi, null = xong.
Future<String?> nhanSanTuLuotDat(BuildContext context, WidgetRef ref, DatTruoc d, String tenBan) async {
  final banRepo = ref.read(banRepositoryProvider);
  try {
    // Bàn đang có khách khác ngồi: hỏi trước khi gắn lượt đặt vào phiên đang mở.
    final dangMo = await Supabase.instance.client
        .from('ban_sessions')
        .select('id')
        .eq('table_id', d.tableId)
        .eq('status', 'open')
        .maybeSingle();
    if (dangMo != null) {
      if (!context.mounted) return 'Đã dừng';
      final dongY = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('$tenBan đang có khách'),
          content: Text('Gắn lượt đặt của ${d.tenKhach} vào bàn đang mở này?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gắn vào')),
          ],
        ),
      );
      if (dongY != true) return 'Chưa nhận: $tenBan đang có khách';
    }
    final phien = await banRepo.openSession(d.tableId);
    final r = await ref.read(datTruocRepositoryProvider).nhan(d.id, phien.id);
    return r['success'] == true ? null : (r['message'] as String? ?? 'Chưa nhận được');
  } catch (e) {
    return 'Chưa nhận được, kiểm tra mạng rồi thử lại';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HỘP ĐẶT / SỬA LƯỢT ĐẶT
// ─────────────────────────────────────────────────────────────────────────────
class DatTruocFormSheet extends ConsumerStatefulWidget {
  final BanTableModel ban;
  final DateTime ngay;
  final List<DatTruoc> trongNgay;
  final DatTruoc? sua;
  /// Giờ bắt đầu điền sẵn (chạm ô trống trên lưới).
  final DateTime? tuMacDinh;

  const DatTruocFormSheet({
    super.key,
    required this.ban,
    required this.ngay,
    required this.trongNgay,
    this.sua,
    this.tuMacDinh,
  });

  @override
  ConsumerState<DatTruocFormSheet> createState() => _DatTruocFormSheetState();
}

class _DatTruocFormSheetState extends ConsumerState<DatTruocFormSheet> {
  /// Ô tìm khách (28/11): gõ tên hoặc số điện thoại; không chọn khách có sẵn thì chữ gõ là khách mới.
  late final _tim = TextEditingController(text: widget.sua?.tenKhach ?? '');
  /// Ô phụ của khách mới: số điện thoại (ô tìm là tên) hoặc tên (ô tìm là số).
  late final _phu = TextEditingController(text: widget.sua?.sdt ?? '');
  late final _ghiChu = TextEditingController(text: widget.sua?.ghiChu ?? '');
  late final _coc = TextEditingController();
  /// Đợt 4: khách hàng của lượt đặt (cọc vào ví khách này), quỹ nhận cọc, mã chống nhận cọc trùng.
  CustomerModel? _khach;
  String _quyCoc = 'cash';
  final _khoaCoc = const Uuid().v4();
  /// Lượt đã lưu trong hộp này (lưu xong mà nhận cọc lỗi, bấm lại thì không đặt thêm lượt mới).
  String? _idDaLuu;
  /// Khách có sẵn khớp chữ đang gõ.
  List<CustomerModel> _goiY = const [];
  Timer? _cho;
  bool _moCoc = false;
  late bool _moGhiChu = _ghiChu.text.isNotEmpty;
  bool _ghiChuMoTay = false;
  /// Tạm tính cả lịch cố định đã tính (khoá, tiền): khung giá tính theo từng phút, đừng tính lại mỗi lần gõ phím.
  (int, double)? _nhoLap;

  /// Lượt đang sửa đã có cọc trong hệ thống (đã thu / đã trừ / đã xử lý) → ô cọc chỉ để xem.
  bool get _cocDaKhoa => widget.sua?.cocTrangThai != null;
  double get _soCoc => double.tryParse(_coc.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  bool get _timLaSo => RegExp(r'^[0-9+][0-9 .]{2,}$').hasMatch(_tim.text.trim());
  String get _tenLuu => (_timLaSo ? _phu.text : _tim.text).trim();
  String get _sdtLuu => (_timLaSo ? _tim.text : _phu.text).replaceAll(RegExp(r'[\s.\-]'), '');
  late DateTime _tu;
  late int _phut;
  bool _dangLuu = false;
  String? _loi;
  /// Lịch cố định (đợt 3): lặp hàng tuần vào các [_thuLap] tới hết [_denNgay].
  bool _lap = false;
  Set<int> _thuLap = {};
  DateTime? _denNgay;

  List<DateTime> get _buoi =>
      _lap && _denNgay != null ? cacBuoiLap(_tu, _thuLap, _denNgay!, _phut, DateTime.now()) : const [];

  @override
  void initState() {
    super.initState();
    final s = widget.sua;
    if (s != null) {
      _tu = s.gioTu;
      _phut = s.gioDen.difference(s.gioTu).inMinutes;
      if (s.customerId != null) {
        CoreCustomerRepository().getById(s.customerId!).then((k) {
          if (mounted && k != null && _khach == null) setState(() => _khach = k);
        }).catchError((_) {});
      }
    } else if (widget.tuMacDinh != null) {
      _tu = widget.tuMacDinh!;
      _phut = 60;
    } else {
      // mặc định: đầu giờ kế tiếp nếu là hôm nay, không thì 18:00
      final luc = DateTime.now();
      final n = widget.ngay;
      _tu = _dauNgay(n) == _dauNgay(luc) ? DateTime(n.year, n.month, n.day, math.min(luc.hour + 1, 23)) : DateTime(n.year, n.month, n.day, 18);
      _phut = 60;
    }
  }

  @override
  void dispose() {
    _cho?.cancel();
    _tim.dispose();
    _phu.dispose();
    _ghiChu.dispose();
    _coc.dispose();
    super.dispose();
  }

  DateTime get _den => _tu.add(Duration(minutes: _phut));

  Future<TimeOfDay?> _hoiGio(DateTime luc) => showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(luc),
        // Giờ kiểu 24: không ép thì ô gõ số báo "13" là giờ không hợp lệ (thử trên Android 24/11).
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );

  Future<void> _chonGio() async {
    final t = await _hoiGio(_tu);
    if (t != null) setState(() => _tu = DateTime(_tu.year, _tu.month, _tu.day, t.hour, t.minute));
  }

  /// Chọn giờ kết thúc: sớm hơn giờ bắt đầu thì hiểu là qua nửa đêm.
  Future<void> _chonGioDen() async {
    final t = await _hoiGio(_den);
    if (t == null) return;
    var den = DateTime(_tu.year, _tu.month, _tu.day, t.hour, t.minute);
    if (den == _tu) return; // bằng giờ bắt đầu: bấm nhầm, không thành lượt 24 giờ
    if (den.isBefore(_tu)) den = den.add(const Duration(days: 1));
    setState(() => _phut = den.difference(_tu).inMinutes);
  }

  /// −/+ giờ bắt đầu, giữ thời lượng, không nhảy sang ngày khác.
  void _doiTu(int phut) {
    final t = _tu.add(Duration(minutes: phut));
    if (_dauNgay(t) == _dauNgay(_tu)) setState(() => _tu = t);
  }

  void _doiPhut(int them) {
    final p = _phut + them;
    if (p >= 15 && p <= 24 * 60) setState(() => _phut = p);
  }

  void _goTim(String _) {
    _cho?.cancel();
    final q = _tim.text.trim();
    setState(() {
      _loi = null;
      if (q.length < 2) _goiY = const [];
    });
    if (q.length < 2) return;
    _cho = Timer(const Duration(milliseconds: 300), () async {
      try {
        final ds = await CoreCustomerRepository().searchByNameOrPhone(q);
        if (mounted && _khach == null && _tim.text.trim() == q) setState(() => _goiY = ds.take(4).toList());
      } catch (_) {}
    });
  }

  void _chonKhach(CustomerModel k) => setState(() {
        _cho?.cancel();
        _khach = k;
        _goiY = const [];
        _loi = null;
        // khách chưa lưu số thì giữ số vừa gõ (gửi kèm lượt đặt để gọi nhắc)
        final soGo = _sdtLuu;
        _tim.text = k.name;
        _phu.text = (k.phone ?? '').trim().isNotEmpty ? k.phone! : soGo;
      });

  void _chonQuen(KhachQuen q) {
    if (q.khach != null) return _chonKhach(q.khach!);
    setState(() {
      _tim.text = q.ten;
      _phu.text = q.sdt ?? '';
      _loi = null;
    });
  }

  void _batLap(bool v) => setState(() {
        _lap = v;
        _loi = null;
        if (v && _thuLap.isEmpty) _thuLap = {_tu.weekday};
        if (v && _denNgay == null) _denNgay = DateTime(_tu.year, _tu.month, _tu.day + 27);
      });

  String _ngayNgan(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  /// Lưu lịch cố định: trùng thì hỏi bỏ qua các buổi trùng rồi gửi lại.
  Future<void> _luuLap() async {
    final repo = ref.read(datTruocRepositoryProvider);
    Future<Map<String, dynamic>> gui(bool boQua) => repo.datLap(
          tableId: widget.ban.id,
          tenKhach: _tenLuu,
          sdt: _sdtLuu,
          gioTu: _tu,
          phut: _phut,
          thu: _thuLap,
          denNgay: _denNgay!,
          ghiChu: _ghiChu.text,
          boQuaTrung: boQua,
        );
    var r = await gui(false);
    if (!mounted) return;
    final trung = (r['trung'] as List?) ?? const [];
    final conLai = (r['so_buoi_ghi_duoc'] as num?)?.toInt() ?? 0;
    if (r['error_code'] == 'TRUNG_GIO' && conLai > 0) {
      String gio(Object? v) => gioPhut(DateTime.parse(v as String).toLocal());
      final dong = [
        for (final t in trung.take(6))
          '• ${_ngayChu(DateTime.parse(t['tu'] as String).toLocal())}, ${gio(t['tu'])}–${gio(t['den'])}: '
              'trùng ${t['ten_khach']} (${gio(t['trung_tu'])}–${gio(t['trung_den'])})',
        if (trung.length > 6) '• … và ${trung.length - 6} buổi nữa',
        '',
        'Đặt được $conLai buổi không trùng.',
      ].join('\n');
      final boQua = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('${trung.length} buổi trùng giờ'),
          content: Text(dong),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Chọn lại')),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text('Bỏ qua, đặt $conLai buổi còn lại'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (boQua != true) {
        setState(() => _dangLuu = false);
        return;
      }
      r = await gui(true);
      if (!mounted) return;
    }
    if (r['success'] == true) {
      // cọc của lịch cố định: một lần, gắn vào buổi đầu
      final chuoiId = (r['data'] as Map?)?['chuoi_id'] as String?;
      String? dau;
      if (chuoiId != null && (_khach != null || _soCoc > 0)) {
        try {
          dau = (await repo.docChuoi(chuoiId)).where((d) => d.choKhach).firstOrNull?.id;
        } catch (_) {}
      }
      if (!mounted) return;
      await _xongLuot(dau, buoi: true);
    } else {
      setState(() {
        _dangLuu = false;
        _loi = r['message'] as String? ?? 'Chưa lưu được';
      });
    }
  }

  /// Lượt đã lưu: gắn khách, nhận cọc vào ví khách. Lỗi ở bước này thì lượt vẫn giữ, hộp báo lỗi và
  /// bấm lại chỉ làm phần còn thiếu ([_idDaLuu]).
  Future<void> _xongLuot(String? id, {bool buoi = false}) async {
    final repo = ref.read(datTruocRepositoryProvider);
    if (id == null) {
      if (_khach != null || (_soCoc > 0 && !_cocDaKhoa)) {
        if (mounted) Navigator.pop(context, 'Đã đặt, nhưng chưa tìm được buổi để gắn khách / nhận cọc');
      } else if (mounted) {
        Navigator.pop(context, true);
      }
      return;
    }
    _idDaLuu = id;
    if (_khach != null && _khach!.id != widget.sua?.customerId) {
      final g = await repo.ganKhach(id, _khach!.id);
      if (!mounted) return;
      if (g['success'] != true) return _loiSauLuu(g['message'] as String?);
    }
    if (_soCoc > 0 && !_cocDaKhoa) {
      final c = await repo.nhanCoc(id, _soCoc, _quyCoc, _khoaCoc);
      if (!mounted) return;
      if (c['success'] != true) return _loiSauLuu(c['message'] as String?);
    }
    Navigator.pop(context, true);
  }

  void _loiSauLuu(String? m) => setState(() {
        _dangLuu = false;
        _loi = 'Đã lưu lượt đặt, nhưng chưa nhận được cọc: ${m ?? 'lỗi mạng'}. Bấm lại để thử.';
      });

  /// Cọc phải có khách hàng (tiền nằm trong ví khách): chưa chọn thì tìm theo số điện thoại, không có thì tạo.
  Future<String?> _damBaoKhach() async {
    if (_khach != null || _soCoc <= 0 || _cocDaKhoa) return null;
    final sdt = _sdtLuu;
    if (sdt.length < 9) return 'Nhận cọc cần khách hàng: chọn khách hoặc nhập số điện thoại';
    try {
      final repo = CoreCustomerRepository();
      var k = await repo.getByPhone(sdt);
      if (k == null) {
        await repo.create(name: _tenLuu, phone: sdt);
        k = await repo.getByPhone(sdt);
      }
      if (k == null) return 'Chưa tạo được khách hàng';
      setState(() => _khach = k);
      return null;
    } catch (_) {
      return 'Chưa tìm / tạo được khách hàng, kiểm tra mạng rồi thử lại';
    }
  }

  Future<void> _luu() async {
    if (_dangLuu) return;
    if (_tenLuu.isEmpty) {
      setState(() => _loi = 'Nhập tên khách');
      return;
    }
    if (_lap && (_buoi.isEmpty || _buoi.length > 120)) {
      setState(() => _loi = _buoi.isEmpty ? 'Không có buổi nào: chọn thứ và ngày kết thúc' : 'Tối đa 120 buổi một lần');
      return;
    }
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    final loiKhach = await _damBaoKhach();
    if (!mounted) return;
    if (loiKhach != null) {
      setState(() {
        _dangLuu = false;
        _loi = loiKhach;
      });
      return;
    }
    if (_idDaLuu != null) return _xongLuot(_idDaLuu);
    if (_lap) return _luuLap();
    final r = await ref.read(datTruocRepositoryProvider).luu(
          id: widget.sua?.id,
          tableId: widget.ban.id,
          tenKhach: _tenLuu,
          sdt: _sdtLuu,
          gioTu: _tu,
          gioDen: _den,
          ghiChu: _ghiChu.text,
          // cọc thật đi qua nhận cọc (ví khách); lượt đã có cọc giữ nguyên số
          tienCoc: _cocDaKhoa ? widget.sua!.tienCoc : 0,
        );
    if (!mounted) return;
    if (r['success'] == true) {
      await _xongLuot(((r['data'] as Map?)?['id'] as String?) ?? widget.sua?.id);
    } else {
      setState(() {
        _dangLuu = false;
        _loi = r['message'] as String? ?? 'Chưa lưu được';
      });
    }
  }

  double _tamTinhLap(List<DateTime> buoi, double gia, Object caiDat, double Function(DateTime) tienBuoi) {
    final khoa = Object.hash(Object.hashAll(buoi), _phut, gia, identityHashCode(caiDat));
    if (_nhoLap?.$1 == khoa) return _nhoLap!.$2;
    final v = buoi.fold<double>(0, (s, b) => s + tienBuoi(b));
    _nhoLap = (khoa, v);
    return v;
  }

  // ── Các phần của hộp ──────────────────────────────────────────────────────

  Widget _nhanMuc(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s, style: _chu(12, FontWeight.w800, _kNavy.withValues(alpha: 0.55)).copyWith(letterSpacing: 0.5)),
      );

  Widget _anh(String ten, double co, Color mau) => Container(
        width: co,
        height: co,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
        child: Text(_chuDau(ten), style: _chu(co * 0.45, FontWeight.w800, Colors.white)),
      );

  /// Khách: thẻ khách đã chọn, hoặc ô tìm + khách khớp + khách quen + ô phụ của khách mới.
  Widget _phanKhach(List<KhachQuen> quen) {
    final k = _khach;
    // cọc đang trong ví khách của lượt: không đổi khách (kể cả lúc chưa tải được hồ sơ khách)
    final khoa = widget.sua?.coCocCho == true;
    if (k != null || khoa) {
      final ten = k?.name ?? _tim.text.trim();
      // 30 lượt mới nhất của khách (cùng nguồn với hồ sơ khách); chưa đọc được thì không ghi
      final dsDat = k == null ? null : ref.watch(luotDatCuaKhachProvider(k.id)).value;
      final lanDat = dsDat == null ? null : soLanDat(dsDat);
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kNavy, width: 1.5),
        ),
        child: Row(
          children: [
            _anh(ten, 40, _kNavy),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ten, maxLines: 1, overflow: TextOverflow.ellipsis, style: _chu(15.5, FontWeight.w800)),
                  Text(
                    k == null
                        ? [if (_sdtLuu.isNotEmpty) _sdtLuu, 'đã cọc, không đổi khách'].join(' · ')
                        : [
                            if ((k.phone ?? '').isNotEmpty) k.phone!,
                            if (lanDat != null && lanDat.lan > 0) 'đã đặt\u00A0${lanDat.lan}${lanDat.conNua ? '+' : ''}\u00A0lần',
                            'ví\u00A0${fmtVnd(k.realBalance).replaceAll(' ', '\u00A0')}',
                          ].join(' · '),
                    style: _chu(12.5, FontWeight.w600, _kTeal),
                  ),
                ],
              ),
            ),
            if (!khoa)
              TextButton(
                onPressed: () => setState(() => _khach = null),
                child: Text('Đổi', style: _chu(13.5, FontWeight.w800, _kNavy.withValues(alpha: 0.6))),
              ),
          ],
        ),
      );
    }
    final q = _tim.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _tim,
          textCapitalization: TextCapitalization.words,
          onChanged: _goTim,
          style: _chu(15, FontWeight.w600),
          decoration: _o(null, icon: Icons.search_rounded, goiY: 'Tìm tên, SĐT hoặc gõ khách mới'),
        ),
        for (final g in _goiY)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _chonKhach(g),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      _anh(g.name, 30, _kNavy),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _chu(14, FontWeight.w700)),
                            Text(
                              [if ((g.phone ?? '').isNotEmpty) g.phone!, 'ví\u00A0${fmtVnd(g.realBalance).replaceAll(' ', '\u00A0')}'].join(' · '),
                              style: _chu(12, FontWeight.w500, _kNavy.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.add_circle_outline_rounded, color: _kNavy, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (q.isEmpty && quen.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (i, kq) in quen.indexed)
                  Material(
                    color: Colors.white,
                    shape: StadiumBorder(side: BorderSide(color: _kNavy.withValues(alpha: 0.12))),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => _chonQuen(kq),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(5, 5, 11, 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _anh(kq.ten, 22, _kMauAnh[i % _kMauAnh.length]),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(kq.ten, maxLines: 1, overflow: TextOverflow.ellipsis, style: _chu(13, FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (q.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _phu,
            keyboardType: _timLaSo ? TextInputType.name : TextInputType.phone,
            textCapitalization: _timLaSo ? TextCapitalization.words : TextCapitalization.none,
            onChanged: (_) => setState(() => _loi = null),
            style: _chu(15, FontWeight.w600),
            decoration: _timLaSo
                ? _o('Tên khách mới', icon: Icons.person_rounded)
                : _o('Số điện thoại (để gọi nhắc)', icon: Icons.call_rounded),
          ),
        ],
      ],
    );
  }

  Widget _nutCongTru(IconData icon, String nhan, VoidCallback onTap) => Semantics(
        button: true,
        label: nhan,
        child: Material(
          color: _kNavy.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox.square(dimension: 32, child: Icon(icon, size: 18, color: _kNavy)),
          ),
        ),
      );

  Widget _oGio(String nhan, DateTime gio, {required VoidCallback tru, required VoidCallback cong, required VoidCallback chon}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kNavy.withValues(alpha: 0.12), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(nhan, style: _chu(12, FontWeight.w700, _kNavy.withValues(alpha: 0.6))),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _nutCongTru(Icons.remove_rounded, '$nhan sớm 30 phút', tru),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: chon,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(gioPhut(gio), style: _chu(23, FontWeight.w800)),
                      ),
                    ),
                  ),
                  _nutCongTru(Icons.add_rounded, '$nhan muộn 30 phút', cong),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _chonThoiLuong() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            for (final (phut, nhan) in const [(30, "30'"), (60, '1 giờ'), (90, '1g30'), (120, '2 giờ'), (180, '3 giờ')])
              Expanded(
                child: Semantics(
                  button: true,
                  selected: _phut == phut,
                  child: GestureDetector(
                    onTap: () => setState(() => _phut = phut),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _phut == phut ? _kNavy : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        nhan,
                        style: _chu(13, FontWeight.w800, _phut == phut ? Colors.white : _kNavy.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  /// Một dòng "Thêm": đầu dòng (chạm để mở) + phần mở ra.
  Widget _dongThem({
    required IconData icon,
    required Color nen,
    required String tieuDe,
    required String phu,
    bool mo = false,
    VoidCallback? onTap,
    Widget? sau,
    List<Widget> noiDung = const [],
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: mo ? _kNavy : _kNavy.withValues(alpha: 0.1), width: mo ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: nen, borderRadius: BorderRadius.circular(11)),
                        child: Icon(icon, size: 18, color: _kNavy),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tieuDe, style: _chu(14.5, FontWeight.w800)),
                            if (phu.isNotEmpty)
                              Text(phu, maxLines: 2, overflow: TextOverflow.ellipsis, style: _chu(12, FontWeight.w600, _kNavy.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                      sau ?? (onTap == null ? const SizedBox.shrink() : Icon(mo ? Icons.expand_less_rounded : Icons.chevron_right_rounded, color: _kNavy.withValues(alpha: 0.4))),
                    ],
                  ),
                ),
              ),
              if (mo && noiDung.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: noiDung),
                ),
            ],
          ),
        ),
      );

  /// Tiền cọc: vào ví khách + Thu Chi ngay, thanh toán bàn tự trừ.
  Widget _phanCoc() {
    final s = widget.sua;
    if (_cocDaKhoa) {
      final trangThai = switch (s!.cocTrangThai) {
        'da_thu' => 'đang trong ví khách, thanh toán bàn tự trừ',
        'da_tru' => 'đã trừ khi thanh toán',
        'trong_vi' => 'để trong ví khách',
        'quan_giu' => 'quán giữ cọc',
        'da_hoan' => 'đã hoàn cọc',
        _ => '',
      };
      return _dongThem(icon: Icons.savings_rounded, nen: const Color(0xFFFFF3D6), tieuDe: 'Tiền cọc', phu: 'Đã cọc ${fmtVnd(s.tienCoc)} · $trangThai');
    }
    Widget chip(String nhan, bool chon, VoidCallback bam) => ChoiceChip(
          label: Text(nhan, style: _chu(13, FontWeight.w700, chon ? Colors.white : _kNavy)),
          selected: chon,
          selectedColor: _kNavy,
          backgroundColor: Colors.white,
          showCheckmark: false,
          onSelected: (_) => bam(),
        );
    return _dongThem(
      icon: Icons.savings_rounded,
      nen: const Color(0xFFFFF3D6),
      tieuDe: 'Tiền cọc',
      phu: _soCoc > 0 ? '${fmtVnd(_soCoc)} · ${_quyCoc == 'cash' ? 'tiền mặt' : 'chuyển khoản'}' : 'Không cọc',
      mo: _moCoc,
      onTap: () => setState(() => _moCoc = !_moCoc),
      noiDung: [
        TextField(
          controller: _coc,
          keyboardType: TextInputType.number,
          inputFormatters: [SoChamFormatter()],
          onChanged: (_) => setState(() {}),
          style: _chu(16, FontWeight.w800),
          decoration: _o('Số tiền cọc', goiY: '0', duoi: 'đ'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final v in const [100000, 200000, 500000])
              chip(fmtVnd(v).replaceAll(' đ', ''), _soCoc == v, () => setState(() => _coc.text = fmtVnd(v).replaceAll(' đ', ''))),
          ],
        ),
        if (_soCoc > 0) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            chip('Tiền mặt', _quyCoc == 'cash', () => setState(() => _quyCoc = 'cash')),
            chip('Chuyển khoản', _quyCoc == 'bank', () => setState(() => _quyCoc = 'bank')),
          ]),
          const SizedBox(height: 4),
          Text(
            'Cọc vào ví ${_khach?.name ?? 'khách'} và ghi phiếu thu ngay. Thanh toán bàn sẽ tự trừ'
            '${_lap ? ' (lịch cố định: một lần cọc, trừ ở buổi đầu khách đến)' : ''}.',
            style: _chu(12, FontWeight.w500, _kNavy.withValues(alpha: 0.65)),
          ),
        ],
      ],
    );
  }

  // "Lặp lại hàng tuần": thứ, ngày kết thúc, dòng đếm buổi.
  Widget _phanLap() {
    const tenThu = {1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7', 7: 'CN'};
    final buoi = _buoi;
    Widget nutDen(String nhan, DateTime d) {
      final chon = _denNgay != null && _denNgay!.year == d.year && _denNgay!.month == d.month && _denNgay!.day == d.day;
      return ChoiceChip(
        label: Text(nhan, style: _chu(12.5, FontWeight.w700, chon ? Colors.white : _kNavy)),
        selected: chon,
        selectedColor: _kNavy,
        backgroundColor: Colors.white,
        showCheckmark: false,
        onSelected: (_) => setState(() => _denNgay = d),
      );
    }

    return _dongThem(
      icon: Icons.repeat_rounded,
      nen: const Color(0xFFEEF0FF),
      tieuDe: 'Lặp lại hàng tuần',
      phu: _lap ? 'Khách quen, mỗi tuần ${thuChuCua(_thuLap)}' : 'Chỉ một lần',
      mo: _lap,
      onTap: () => _batLap(!_lap),
      sau: Switch(
        value: _lap,
        activeThumbColor: Colors.white,
        activeTrackColor: _kTeal,
        onChanged: _batLap,
      ),
      noiDung: [
        Row(
          children: [
            for (final d in tenThu.keys)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Semantics(
                    button: true,
                    selected: _thuLap.contains(d),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => setState(() => _thuLap.contains(d) ? _thuLap.remove(d) : _thuLap.add(d)),
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _thuLap.contains(d) ? _kNavy : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _thuLap.contains(d) ? _kNavy : _kNavy.withValues(alpha: 0.2)),
                        ),
                        child: Text(tenThu[d]!, style: _chu(12, FontWeight.w800, _thuLap.contains(d) ? Colors.white : _kNavy)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Đến ngày', style: _chu(12.5, FontWeight.w700, _kNavy.withValues(alpha: 0.6))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            nutDen('4 tuần', DateTime(_tu.year, _tu.month, _tu.day + 27)),
            nutDen('8 tuần', DateTime(_tu.year, _tu.month, _tu.day + 55)),
            // thuê "cả tháng": tới ngày cuối tháng (ngày 0 của tháng kế = ngày cuối tháng này)
            nutDen('Hết tháng này', DateTime(_tu.year, _tu.month + 1, 0)),
            nutDen('Hết tháng sau', DateTime(_tu.year, _tu.month + 2, 0)),
            nutDen('3 tháng', DateTime(_tu.year, _tu.month, _tu.day + 90)),
            ActionChip(
              avatar: const Icon(Icons.event_rounded, size: 16, color: _kNavy),
              label: Text(_denNgay == null ? 'Chọn ngày' : '${_ngayNgan(_denNgay!)}/${_denNgay!.year}',
                  style: _chu(12.5, FontWeight.w700)),
              backgroundColor: Colors.white,
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _denNgay ?? _tu,
                  firstDate: DateTime(_tu.year, _tu.month, _tu.day),
                  lastDate: DateTime(_tu.year, _tu.month, _tu.day + 366),
                );
                if (d != null) setState(() => _denNgay = d);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          buoi.isEmpty
              ? 'Chưa có buổi nào: chọn thứ và ngày kết thúc'
              : '${buoi.length} buổi · ${thuChuCua(_thuLap)} · ${gioPhut(_tu)}–${gioPhut(_den)} · '
                  '${_ngayNgan(buoi.first)} → ${_ngayNgan(buoi.last)}',
          style: _chu(13, FontWeight.w700, buoi.isEmpty || buoi.length > 120 ? _kRed : _kTealDam),
        ),
        if (buoi.length > 120) Text('Tối đa 120 buổi một lần', style: _chu(12, FontWeight.w600, _kRed)),
        // xem trước các buổi đầu: "T3 03/12", "T5 05/12"…
        if (buoi.isNotEmpty && buoi.length <= 120) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final b in buoi.take(6))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kNavy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${tenThu[b.weekday]} ${_ngayNgan(b)}', style: _chu(11.5, FontWeight.w700)),
                ),
              if (buoi.length > 6)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text('+${buoi.length - 6} buổi', style: _chu(11.5, FontWeight.w600, _kNavy.withValues(alpha: 0.6))),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _phanGhiChu() => _dongThem(
        icon: Icons.sticky_note_2_rounded,
        nen: const Color(0xFFF1EEE6),
        tieuDe: 'Ghi chú',
        phu: _moGhiChu ? '' : (_ghiChu.text.trim().isEmpty ? 'Ví dụ: 7 người, cần bóng mới' : _ghiChu.text.trim()),
        mo: _moGhiChu,
        onTap: () => setState(() {
          _moGhiChu = !_moGhiChu;
          _ghiChuMoTay = true;
        }),
        noiDung: [
          TextField(
            controller: _ghiChu,
            autofocus: _ghiChuMoTay,
            minLines: 1,
            maxLines: 3,
            style: _chu(14, FontWeight.w500),
            decoration: _o(null, goiY: 'Ví dụ: 7 người, cần bóng mới'),
          ),
        ],
      );

  InputDecoration _o(String? nhan, {IconData? icon, String? goiY, String? duoi}) => InputDecoration(
        labelText: nhan,
        hintText: goiY,
        suffixText: duoi,
        hintStyle: _chu(14, FontWeight.w500, _kNavy.withValues(alpha: 0.45)),
        labelStyle: _chu(13.5, FontWeight.w500, _kNavy.withValues(alpha: 0.6)),
        prefixIcon: icon == null ? null : Icon(icon, color: _kNavy.withValues(alpha: 0.7), size: 20),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _kNavy.withValues(alpha: 0.12), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kNavy, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ban = widget.ban;
    final trung = luotDatTrung(widget.trongNgay, ban.id, _tu, _den, boQuaId: widget.sua?.id);
    final gia = ref.watch(tinhGioGiaTheoMonProvider)[ban.giaGioProductId]?.sellPrice ?? 0;
    final caiDat = giaGioCuaBan(ref, ban.id);
    double tienBuoi(DateTime vao) => tinhGioTien(vao: vao, phutChoi: _phut, giaGoc: gia, caiDat: caiDat).thanhTien;
    final tien = gia > 0 ? tienBuoi(_tu) : null;
    final quen = widget.sua == null ? (ref.watch(khachQuenDatProvider).value ?? const <KhachQuen>[]) : const <KhachQuen>[];
    final khac = [
      for (final d in widget.trongNgay)
        if (d.tableId == ban.id && d.conHieuLuc && d.id != widget.sua?.id) d,
    ];
    final coc = _soCoc > 0 && !_cocDaKhoa;
    final buoi = _buoi;
    final tomTat = [
      if (_lap && buoi.isNotEmpty && tien != null) 'Tạm tính ${buoi.length} buổi · ${fmtVnd(_tamTinhLap(buoi, gia, caiDat, tienBuoi))}',
      if (!_lap && coc && tien != null) 'Tạm tính ${fmtVnd(tien)}',
      if (coc) 'cọc ${fmtVnd(_soCoc)}',
    ].join(' · ');
    final nhanNut = [
      widget.sua != null
          ? 'Lưu'
          : _lap
              ? 'Đặt ${buoi.length} buổi'
              : coc
                  ? 'Đặt ${ban.label}'
                  : 'Đặt ${ban.label} · ${gioPhut(_tu)} – ${gioPhut(_den)}',
      if (coc) 'nhận cọc ${fmtVnd(_soCoc)}',
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        decoration: BoxDecoration(color: _kCream, borderRadius: BorderRadius.circular(26)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(14)),
                  child: Text(_viTatBan(ban.label), style: _chu(14, FontWeight.w800, Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.sua == null ? 'Đặt ${ban.label}' : 'Sửa lượt đặt · ${ban.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _chu(19, FontWeight.w800),
                      ),
                      Text(
                        [_ngayChu(_tu), if (gia > 0) '${fmtVnd(tinhGioGiaLuc(_tu, gia, caiDat))}/giờ'].join(' · '),
                        style: _chu(13, FontWeight.w700, _kOrange),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: _kNavy.withValues(alpha: 0.06)),
                  icon: Icon(Icons.close_rounded, color: _kNavy.withValues(alpha: 0.6)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _nhanMuc('KHÁCH'),
                    _phanKhach(quen),
                    const SizedBox(height: 18),
                    _nhanMuc('GIỜ'),
                    Row(
                      children: [
                        _oGio('Bắt đầu', _tu, tru: () => _doiTu(-30), cong: () => _doiTu(30), chon: _chonGio),
                        const SizedBox(width: 10),
                        _oGio(_dauNgay(_den) == _dauNgay(_tu) ? 'Kết thúc' : 'Kết thúc · hôm sau', _den, tru: () => _doiPhut(-30), cong: () => _doiPhut(30), chon: _chonGioDen),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _chonThoiLuong(),
                    const SizedBox(height: 12),
                    _DaiLichBan(ds: khac, tu: _tu, den: _den, trung: trung != null),
                    const SizedBox(height: 8),
                    if (trung != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFB42318)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Trùng ${trung.tenKhach} ${gioPhut(trung.gioTu)}–${gioPhut(trung.gioDen)} · đổi giờ hoặc chọn bàn khác',
                                style: _chu(12.5, FontWeight.w700, const Color(0xFFB42318)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: _kTealDam),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                const TextSpan(text: 'Trống, không trùng lượt nào'),
                                if (tien != null) ...[
                                  const TextSpan(text: ' · tạm tính '),
                                  TextSpan(text: fmtVnd(tien), style: _chu(12.5, FontWeight.w800)),
                                ],
                              ]),
                              style: _chu(12.5, FontWeight.w700, _kTealDam),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    _nhanMuc('THÊM (KHÔNG BẮT BUỘC)'),
                    _phanCoc(),
                    if (widget.sua == null) _phanLap(),
                    _phanGhiChu(),
                  ],
                ),
              ),
            ),
            if (_loi != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_loi!, textAlign: TextAlign.center, style: _chu(13.5, FontWeight.w700, _kRed)),
              ),
            if (tomTat.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(tomTat, textAlign: TextAlign.center, style: _chu(12.5, FontWeight.w700, _kNavy.withValues(alpha: 0.6))),
              ),
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _dangLuu ? null : _luu,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _dangLuu
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(nhanNut, style: _chu(15.5, FontWeight.w800, Colors.white)),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _kTeal = Color(0xFF0D9488);
const _kTealDam = Color(0xFF0F766E);
const _kMauAnh = [_kNavy, _kTeal, _kOrange, Color(0xFF7C3AED)];

String _chuDau(String s) {
  final t = s.trim();
  return t.isEmpty ? '?' : t.characters.first.toUpperCase();
}

/// "A 2" → "A2", "Sân 10" → "S10", "VIP" → "VIP".
String _viTatBan(String nhan) {
  final tu = nhan.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (tu.length <= 1) return nhan.trim().characters.take(3).toString();
  return tu.map((w) => RegExp(r'^\d+$').hasMatch(w) ? w : w.characters.first.toUpperCase()).join().characters.take(4).toString();
}

/// Khách đặt gần đây cho chip chọn nhanh: [khach] là khách hàng có sẵn (chạm là chọn luôn), null = chỉ tên + số.
typedef KhachQuen = ({String ten, String? sdt, CustomerModel? khach});

final khachQuenDatProvider = FutureProvider.autoDispose<List<KhachQuen>>((ref) async {
  ref.watch(sessionProvider);
  try {
    final ds = khachQuenTu(await ref.read(datTruocRepositoryProvider).docGanDay());
    final ids = ds.map((d) => d.customerId).whereType<String>().toList();
    final khach = <String, CustomerModel>{};
    if (ids.isNotEmpty) {
      final rows = await Supabase.instance.client.from('customers').select().inFilter('id', ids).timeout(const Duration(seconds: 8));
      for (final r in rows) {
        final k = CustomerModel.fromMap(r);
        if (!k.isDeleted) khach[k.id] = k;
      }
    }
    return [for (final d in ds) (ten: khach[d.customerId]?.name ?? d.tenKhach, sdt: d.sdt, khach: khach[d.customerId])];
  } catch (_) {
    return const [];
  }
});

/// Dải lịch trong ngày của bàn: các lượt đã đặt + khung đang chọn (đỏ khi trùng).
class _DaiLichBan extends StatelessWidget {
  final List<DatTruoc> ds;
  final DateTime tu;
  final DateTime den;
  final bool trung;
  const _DaiLichBan({required this.ds, required this.tu, required this.den, required this.trung});

  @override
  Widget build(BuildContext context) {
    final ngay = _dauNgay(tu);
    double gio(DateTime d) => (d.difference(ngay).inMinutes / 60).clamp(0, 24).toDouble();
    var lo = gio(tu).floor();
    var hi = gio(den).ceil();
    for (final d in ds) {
      lo = math.min(lo, gio(d.gioTu).floor());
      hi = math.max(hi, gio(d.gioDen).ceil());
    }
    final khoang = math.min(24, math.max(6, ((hi - lo) / 3).ceil() * 3));
    if (lo + khoang > 24) lo = 24 - khoang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i <= 3; i++)
              Text('${(lo + khoang * i ~/ 3).toString().padLeft(2, '0')}:00',
                  style: _chu(11, FontWeight.w700, _kNavy.withValues(alpha: 0.45))),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kNavy.withValues(alpha: 0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth;
              double x(DateTime d) => ((gio(d) - lo) / khoang * w).clamp(0, w).toDouble();
              Widget khoi(DateTime a, DateTime b, String nhan, Color mau, {bool noi = false}) {
                final l = x(a), r = x(b);
                if (r - l < 1) return const SizedBox.shrink();
                return Positioned(
                  left: l,
                  width: r - l,
                  top: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: mau,
                      borderRadius: BorderRadius.circular(7),
                      border: noi ? Border.all(color: Colors.white, width: 1.5) : null,
                      boxShadow: noi ? [BoxShadow(color: mau.withValues(alpha: 0.35), blurRadius: 6)] : null,
                    ),
                    child: noi
                        ? FittedBox(fit: BoxFit.scaleDown, child: Text(nhan, style: _chu(10.5, FontWeight.w800, Colors.white)))
                        : Text(nhan, maxLines: 1, softWrap: false, overflow: TextOverflow.clip, style: _chu(10.5, FontWeight.w800, Colors.white)),
                  ),
                );
              }

              return Stack(
                children: [
                  for (var i = 1; i < khoang; i++)
                    Positioned(left: w * i / khoang, top: 0, bottom: 0, child: Container(width: 1, color: _kNavy.withValues(alpha: 0.06))),
                  for (final d in ds)
                    khoi(d.gioTu, d.gioDen, d.tenKhach, d.trangThai == 'da_nhan' ? const Color(0xFF15803D) : _kNavy.withValues(alpha: 0.85)),
                  khoi(tu, den, 'Lượt này', trung ? _kRed : _kTeal, noi: true),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HUỶ / KHÔNG ĐẾN: TIỀN CỌC XỬ LÝ THẾ NÀO
// ─────────────────────────────────────────────────────────────────────────────
/// Trả 'trong_vi' | 'quan_giu' | 'hoan', null = để sau (hộp lượt đặt còn nút "Xử lý tiền cọc").
class XuLyCocSheet extends StatefulWidget {
  final DatTruoc dat;
  final String tenBan;
  final bool khongDen;
  final bool laQuanLy;
  const XuLyCocSheet({super.key, required this.dat, required this.tenBan, required this.khongDen, required this.laQuanLy});

  @override
  State<XuLyCocSheet> createState() => _XuLyCocSheetState();
}

class _XuLyCocSheetState extends State<XuLyCocSheet> {
  // Chủ Quán chốt: không đến → chọn sẵn "Quán giữ cọc"; khách báo huỷ → "Để trong ví".
  late String _cach = widget.khongDen ? 'quan_giu' : 'trong_vi';

  @override
  Widget build(BuildContext context) {
    final d = widget.dat;
    final tien = fmtVnd(d.tienCoc);
    final quy = d.cocQuy == 'bank' ? 'chuyển khoản' : 'tiền mặt';
    Widget lc(String ma, String tieuDe, String phu, {bool khoa = false}) {
      final chon = _cach == ma;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Opacity(
          opacity: khoa ? 0.5 : 1,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: chon ? _kNavy : _kNavy.withValues(alpha: 0.15), width: chon ? 2 : 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: khoa ? null : () => setState(() => _cach = ma),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(chon ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: _kNavy),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text(tieuDe, style: _chu(15, FontWeight.w800))),
                              if (khoa) ...[const SizedBox(width: 4), const Icon(Icons.lock_rounded, size: 15, color: _kNavy)],
                            ],
                          ),
                          Text(phu, style: _chu(12.5, FontWeight.w500, _kNavy.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: _kCream, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              '${widget.khongDen ? 'Khách không đến' : widget.dat.trangThai == 'da_nhan' ? 'Bàn đã gộp / huỷ, cọc chưa trừ' : 'Đã huỷ'}'
              ' · ${widget.tenBan}',
              textAlign: TextAlign.center,
              style: _chu(18, FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${d.tenKhach} · ${_ngayChu(d.gioTu)} ${gioPhut(d.gioTu)} · đã cọc $tien $quy',
              textAlign: TextAlign.center, style: _chu(13, FontWeight.w600, _kNavy.withValues(alpha: 0.7))),
          const SizedBox(height: 12),
          Text('TIỀN CỌC $tien XỬ LÝ THẾ NÀO?', style: _chu(12.5, FontWeight.w800, _kNavy.withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          lc('trong_vi', 'Để trong ví khách', 'Lần sau ${d.tenKhach} đến trả bằng ví. Thu Chi không đổi.'),
          lc('quan_giu', 'Quán giữ cọc', 'Trừ ví, lịch sử ví ghi "Mất cọc". Thu Chi không đổi vì đã thu lúc đặt.'),
          lc('hoan', 'Hoàn cọc', 'Trừ ví + phiếu chi $tien $quy. Chỉ Chủ quán / Quản lý.', khoa: !widget.laQuanLy),
          const SizedBox(height: 6),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _cach),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                switch (_cach) {
                  'trong_vi' => 'Xác nhận · để $tien trong ví',
                  'quan_giu' => 'Xác nhận · quán giữ $tien',
                  _ => 'Xác nhận · hoàn $tien',
                },
                style: _chu(15.5, FontWeight.w800, Colors.white),
              ),
            ),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Để sau', style: _chu(14, FontWeight.w700))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HỒ SƠ KHÁCH: LƯỢT ĐẶT SÂN + CỌC (module Khách hàng gọi)
// ─────────────────────────────────────────────────────────────────────────────
class LuotDatCuaKhach extends ConsumerWidget {
  final String customerId;
  const LuotDatCuaKhach({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(luotDatCuaKhachProvider(customerId)).value ?? const <DatTruoc>[];
    if (ds.isEmpty) return const SizedBox.shrink();
    final dangGiu = ds.where((d) => d.coCocCho).fold<double>(0, (s, d) => s + d.tienCoc);
    final bans = {for (final b in ref.watch(banDeDatProvider).value ?? const <BanTableModel>[]) b.id: b.label};
    String dong(DatTruoc d) {
      final trangThai = switch (d.trangThai) {
        'da_nhan' => 'Đã đến',
        'huy' => 'Đã huỷ',
        'khong_den' => 'Không đến',
        _ => 'Chờ khách',
      };
      final coc = switch (d.cocTrangThai) {
        'da_thu' => 'cọc ${fmtVnd(d.tienCoc)} trong ví',
        'da_tru' => 'cọc đã trừ',
        'trong_vi' => 'cọc để trong ví',
        'quan_giu' => 'quán giữ cọc',
        'da_hoan' => 'đã hoàn cọc',
        _ => null,
      };
      return [trangThai, if (coc != null) coc].join(' · ');
    }

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: const Icon(Icons.event_available_rounded, color: _kNavy),
      title: Text('Đặt sân · ${ds.length} lượt', style: _chu(14, FontWeight.w800)),
      subtitle: dangGiu > 0 ? Text('Cọc đang giữ ${fmtVnd(dangGiu)}', style: _chu(12.5, FontWeight.w700, const Color(0xFF0D9488))) : null,
      children: [
        for (final d in ds.take(10))
          ListTile(
            dense: true,
            leading: Icon(d.chuoiId != null ? Icons.repeat_rounded : Icons.event_rounded, size: 18, color: _kNavy),
            title: Text(
              '${bans[d.tableId] ?? 'Bàn'} · ${_ngayChu(d.gioTu)} ${gioPhut(d.gioTu)}–${gioPhut(d.gioDen)}',
              style: _chu(13, FontWeight.w700),
            ),
            subtitle: Text(dong(d), style: _chu(12, FontWeight.w500, _kNavy.withValues(alpha: 0.65))),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HỘP NHẮC TRƯỚC 30 PHÚT
// ─────────────────────────────────────────────────────────────────────────────
/// Đặt ở khung chính của app (luôn mở dù đang ở màn nào). Chỉ chạy khi quán bật module Tính giờ.
/// Mỗi 30 giây so giờ trên danh sách lượt đặt đã tải sẵn — không hỏi thêm máy chủ.
class TinhGioNhacDatSan extends ConsumerStatefulWidget {
  const TinhGioNhacDatSan({super.key});

  @override
  ConsumerState<TinhGioNhacDatSan> createState() => _TinhGioNhacDatSanState();
}

class _TinhGioNhacDatSanState extends ConsumerState<TinhGioNhacDatSan> {
  Timer? _dongHo;
  final _daHien = <String>{};
  String? _dangHien; // mã lượt đặt của hộp nhắc đang mở

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
    if (!ref.read(tinhGioModuleActiveProvider)) return false;
    final phien = ref.read(sessionProvider);
    if (phien == null || !phien.hasStore) return false;
    if (phien.isOwner) return true;
    // cùng quyền mà máy chủ đòi khi đặt / đánh dấu đã nhắc
    return ref.read(userActionPermsProvider).value?.contains('pos.checkout') ?? false;
  }

  void _xet() {
    if (!mounted || !_duocNhac) return;
    final ds = ref.read(datTruocGanDayProvider).value ?? const <DatTruoc>[];
    // Hộp đang mở mà lượt đó đã có người nhắc / đã huỷ / khách đã đến → tự đóng.
    final dang = _dangHien;
    if (dang != null) {
      final d = ds.where((x) => x.id == dang).firstOrNull;
      if (d == null || !d.choKhach || d.nhacLuc != null) {
        _dangHien = null;
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      return;
    }
    final can = datTruocCanNhac(ds, DateTime.now()).where((d) => !_daHien.contains(d.id)).toList();
    if (can.isEmpty) return;
    _hien(can.first);
  }

  Future<void> _hien(DatTruoc d) async {
    _daHien.add(d.id);
    _dangHien = d.id;
    unawaited(QrSoundService.playNotificationSound());
    String tenBan = '';
    try {
      tenBan = (await ref.read(banRepositoryProvider).getAllTables()).where((b) => b.id == d.tableId).firstOrNull?.label ?? '';
    } catch (_) {}
    if (!mounted || _dangHien != d.id) return;
    final viec = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: _kOrange),
            const SizedBox(width: 8),
            Expanded(child: Text('Sắp tới giờ đặt', style: _chu(18, FontWeight.w800))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tenBan.isEmpty ? '' : '$tenBan · '}${gioPhut(d.gioTu)}–${gioPhut(d.gioDen)}',
              style: _chu(17, FontWeight.w800, _kOrange),
            ),
            const SizedBox(height: 6),
            Text(d.tenKhach, style: _chu(16, FontWeight.w700)),
            if ((d.sdt ?? '').isNotEmpty) Text(d.sdt!, style: _chu(15, FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Gọi nhắc khách để giữ chỗ.', style: _chu(13, FontWeight.w500, _kNavy.withValues(alpha: 0.65))),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Đóng', style: _chu(14, FontWeight.w700, _kNavy.withValues(alpha: 0.6)))),
          if ((d.sdt ?? '').isNotEmpty)
            TextButton(onPressed: () => Navigator.pop(ctx, 'goi'), child: Text('Gọi khách', style: _chu(14, FontWeight.w800))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'da_nhac'),
            style: ElevatedButton.styleFrom(backgroundColor: _kNavy, foregroundColor: Colors.white, elevation: 0),
            child: Text('Đã nhắc', style: _chu(14, FontWeight.w800, Colors.white)),
          ),
        ],
      ),
    );
    if (_dangHien == d.id) _dangHien = null;
    if (!mounted) return;
    if (viec == 'goi') {
      await goiKhach(context, d.sdt!);
      _daHien.remove(d.id); // gọi xong hỏi lại để bấm "Đã nhắc"
    } else if (viec == 'da_nhac') {
      final r = await ref.read(datTruocRepositoryProvider).daNhac(d.id);
      if (r['success'] != true) _daHien.remove(d.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Quán không bật module thì không nghe gì, không tải bảng lượt đặt.
    if (!ref.watch(tinhGioModuleActiveProvider)) return const SizedBox.shrink();
    ref.listen(datTruocGanDayProvider, (truoc, sau) => _xet());
    return const TinhGioNhacGoi(); // nhắc còn 10 phút / hết gói giờ (đợt 7)
  }
}
