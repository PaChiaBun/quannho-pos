import 'dart:async';

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
import 'gia_gio.dart' show thuChuCua;
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
    final len = ((phut + 29) ~/ 30) * 30;
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
  late final _ten = TextEditingController(text: widget.sua?.tenKhach ?? '');
  late final _sdt = TextEditingController(text: widget.sua?.sdt ?? '');
  late final _ghiChu = TextEditingController(text: widget.sua?.ghiChu ?? '');
  late final _coc = TextEditingController();
  /// Đợt 4: khách hàng của lượt đặt (cọc vào ví khách này), quỹ nhận cọc, mã chống nhận cọc trùng.
  CustomerModel? _khach;
  String _quyCoc = 'cash';
  final _khoaCoc = const Uuid().v4();
  /// Lượt đã lưu trong hộp này (lưu xong mà nhận cọc lỗi, bấm lại thì không đặt thêm lượt mới).
  String? _idDaLuu;

  /// Lượt đang sửa đã có cọc trong hệ thống (đã thu / đã trừ / đã xử lý) → ô cọc chỉ để xem.
  bool get _cocDaKhoa => widget.sua?.cocTrangThai != null;
  double get _soCoc => double.tryParse(_coc.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
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
          if (mounted && k != null) setState(() => _khach = k);
        }).catchError((_) {});
      }
    } else if (widget.tuMacDinh != null) {
      _tu = widget.tuMacDinh!;
      _phut = 60;
    } else {
      // mặc định: đầu giờ kế tiếp nếu là hôm nay, không thì 18:00
      final luc = DateTime.now();
      final n = widget.ngay;
      _tu = _dauNgay(n) == _dauNgay(luc) ? DateTime(n.year, n.month, n.day, luc.hour + 1) : DateTime(n.year, n.month, n.day, 18);
      _phut = 60;
    }
  }

  @override
  void dispose() {
    _ten.dispose();
    _sdt.dispose();
    _ghiChu.dispose();
    _coc.dispose();
    super.dispose();
  }

  DateTime get _den => _tu.add(Duration(minutes: _phut));

  Future<void> _chonGio() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_tu),
      // Giờ kiểu 24: không ép thì ô gõ số báo "13" là giờ không hợp lệ (thử trên Android 24/11).
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => _tu = DateTime(_tu.year, _tu.month, _tu.day, t.hour, t.minute));
  }

  String _ngayNgan(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  /// Lưu lịch cố định: trùng thì hỏi bỏ qua các buổi trùng rồi gửi lại.
  Future<void> _luuLap() async {
    final repo = ref.read(datTruocRepositoryProvider);
    Future<Map<String, dynamic>> gui(bool boQua) => repo.datLap(
          tableId: widget.ban.id,
          tenKhach: _ten.text,
          sdt: _sdt.text,
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
    final sdt = _sdt.text.trim();
    if (sdt.length < 9) return 'Nhận cọc cần khách hàng: chọn khách hoặc nhập số điện thoại';
    try {
      final repo = CoreCustomerRepository();
      var k = await repo.getByPhone(sdt);
      if (k == null) {
        await repo.create(name: _ten.text.trim(), phone: sdt);
        k = await repo.getByPhone(sdt);
      }
      if (k == null) return 'Chưa tạo được khách hàng';
      setState(() => _khach = k);
      return null;
    } catch (_) {
      return 'Chưa tìm / tạo được khách hàng, kiểm tra mạng rồi thử lại';
    }
  }

  Future<void> _chonKhach() async {
    final k = await showModalBottomSheet<CustomerModel>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ChonKhachSheet(tenMoi: _ten.text.trim(), sdtMoi: _sdt.text.trim()),
    );
    if (k == null || !mounted) return;
    setState(() {
      _khach = k;
      _ten.text = k.name;
      if ((k.phone ?? '').isNotEmpty) _sdt.text = k.phone!;
      _loi = null;
    });
  }

  Future<void> _luu() async {
    if (_dangLuu) return;
    if (_ten.text.trim().isEmpty) {
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
          tenKhach: _ten.text,
          sdt: _sdt.text,
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

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kNavy.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.repeat_rounded, color: _kNavy, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Lặp lại hàng tuần (khách quen)', style: _chu(14, FontWeight.w700))),
                Switch(
                  value: _lap,
                  activeThumbColor: Colors.white,
                  activeTrackColor: _kNavy,
                  onChanged: (v) => setState(() {
                    _lap = v;
                    _loi = null;
                    if (v && _thuLap.isEmpty) _thuLap = {_tu.weekday};
                    if (v && _denNgay == null) _denNgay = DateTime(_tu.year, _tu.month, _tu.day + 27);
                  }),
                ),
              ],
            ),
            if (_lap) ...[
              Text('Các thứ', style: _chu(12.5, FontWeight.w700, _kNavy.withValues(alpha: 0.6))),
              const SizedBox(height: 6),
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
                              height: 44,
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
                style: _chu(13, FontWeight.w700, buoi.isEmpty || buoi.length > 120 ? _kRed : _kGreen),
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
          ],
        ),
      ),
    );
  }

  /// Khách hàng của lượt đặt (module Khách hàng): chọn khách có sẵn hoặc tạo mới.
  Widget _theKhach() {
    final k = _khach;
    final khoa = widget.sua?.coCocCho == true; // cọc đang trong ví khách này: không đổi khách
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: k != null ? _kNavy : _kNavy.withValues(alpha: 0.2), width: k != null ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: khoa ? null : _chonKhach,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Icon(k != null ? Icons.account_circle_rounded : Icons.person_search_rounded, color: _kNavy, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: k == null
                    ? Text('Chọn khách hàng (để nhận cọc, tích điểm)', style: _chu(14, FontWeight.w600, _kNavy.withValues(alpha: 0.7)))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.name, style: _chu(14.5, FontWeight.w800)),
                          Text(
                            [if ((k.phone ?? '').isNotEmpty) k.phone!, 'ví ${fmtVnd(k.realBalance)}'].join(' · '),
                            style: _chu(12.5, FontWeight.w600, const Color(0xFF0D9488)),
                          ),
                        ],
                      ),
              ),
              if (k != null && !khoa)
                IconButton(
                  tooltip: 'Bỏ chọn khách',
                  onPressed: () => setState(() => _khach = null),
                  icon: Icon(Icons.close_rounded, color: _kNavy.withValues(alpha: 0.5), size: 20),
                )
              else if (!khoa)
                const Icon(Icons.chevron_right_rounded, color: _kNavy),
            ],
          ),
        ),
      ),
    );
  }

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
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Text('Đã cọc ${fmtVnd(s.tienCoc)} · $trangThai', style: _chu(13.5, FontWeight.w700, const Color(0xFF0D9488))),
      );
    }
    Widget quy(String ma, String nhan) => ChoiceChip(
          label: Text(nhan, style: _chu(13, FontWeight.w700, _quyCoc == ma ? Colors.white : _kNavy)),
          selected: _quyCoc == ma,
          selectedColor: _kNavy,
          backgroundColor: Colors.white,
          showCheckmark: false,
          onSelected: (_) => setState(() => _quyCoc = ma),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _coc,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          style: _chu(15, FontWeight.w700),
          decoration: _o('Tiền cọc (không có thì để trống)', icon: Icons.savings_rounded, goiY: '0'),
        ),
        if (_soCoc > 0) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [quy('cash', 'Tiền mặt'), quy('bank', 'Chuyển khoản')]),
          const SizedBox(height: 4),
          Text(
            'Cọc vào ví ${_khach?.name ?? 'khách'} và ghi phiếu thu ngay. Thanh toán bàn sẽ tự trừ'
            '${_lap ? ' (lịch cố định: một lần cọc, trừ ở buổi đầu khách đến)' : ''}.',
            style: _chu(12.5, FontWeight.w500, _kNavy.withValues(alpha: 0.65)),
          ),
        ],
      ],
    );
  }

  InputDecoration _o(String nhan, {IconData? icon, String? goiY}) => InputDecoration(
        labelText: nhan,
        hintText: goiY,
        labelStyle: _chu(13.5, FontWeight.w500, _kNavy.withValues(alpha: 0.6)),
        prefixIcon: icon == null ? null : Icon(icon, color: _kNavy, size: 20),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _kNavy.withValues(alpha: 0.2)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final trung = luotDatTrung(widget.trongNgay, widget.ban.id, _tu, _den, boQuaId: widget.sua?.id);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        decoration: BoxDecoration(color: _kCream, borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
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
              const SizedBox(height: 14),
              Text(
                '${widget.sua == null ? 'Đặt' : 'Sửa lượt đặt'} · ${widget.ban.label}',
                textAlign: TextAlign.center,
                style: _chu(18, FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(_ngayChu(_tu), textAlign: TextAlign.center, style: _chu(13.5, FontWeight.w700, _kOrange)),
              const SizedBox(height: 14),
              _theKhach(),
              const SizedBox(height: 10),
              TextField(controller: _ten, textCapitalization: TextCapitalization.words, style: _chu(15, FontWeight.w600), decoration: _o('Tên khách', icon: Icons.person_rounded)),
              const SizedBox(height: 10),
              TextField(
                controller: _sdt,
                keyboardType: TextInputType.phone,
                style: _chu(15, FontWeight.w600),
                decoration: _o('Số điện thoại (để gọi nhắc)', icon: Icons.call_rounded),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _chonGio,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kNavy,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: _kNavy.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.schedule_rounded, size: 20),
                  label: Text('Từ ${gioPhut(_tu)} đến ${gioPhut(_den)}', style: _chu(16, FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final (phut, nhan) in const [(30, '30 phút'), (60, '1 giờ'), (90, '1 giờ 30'), (120, '2 giờ'), (180, '3 giờ')])
                    ChoiceChip(
                      label: Text(nhan, style: _chu(13, FontWeight.w700, _phut == phut ? Colors.white : _kNavy)),
                      selected: _phut == phut,
                      selectedColor: _kNavy,
                      backgroundColor: Colors.white,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _phut = phut),
                    ),
                ],
              ),
              if (trung != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Trùng giờ với ${trung.tenKhach} (${gioPhut(trung.gioTu)}–${gioPhut(trung.gioDen)})',
                    textAlign: TextAlign.center,
                    style: _chu(13, FontWeight.w700, _kRed),
                  ),
                ),
              if (widget.sua == null) _phanLap(),
              const SizedBox(height: 10),
              TextField(controller: _ghiChu, style: _chu(14, FontWeight.w500), decoration: _o('Ghi chú')),
              const SizedBox(height: 10),
              _phanCoc(),
              if (_loi != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_loi!, textAlign: TextAlign.center, style: _chu(13.5, FontWeight.w700, _kRed)),
                ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
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
                      : Text(
                          [
                            widget.sua != null
                                ? 'Lưu'
                                : _lap
                                    ? 'Đặt ${_buoi.length} buổi'
                                    : 'Đặt',
                            if (_soCoc > 0 && !_cocDaKhoa) 'nhận cọc ${fmtVnd(_soCoc)}',
                          ].join(' · '),
                          style: _chu(15.5, FontWeight.w800, Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHỌN KHÁCH HÀNG CHO LƯỢT ĐẶT
// ─────────────────────────────────────────────────────────────────────────────
class _ChonKhachSheet extends StatefulWidget {
  final String tenMoi;
  final String sdtMoi;
  const _ChonKhachSheet({required this.tenMoi, required this.sdtMoi});

  @override
  State<_ChonKhachSheet> createState() => _ChonKhachSheetState();
}

class _ChonKhachSheetState extends State<_ChonKhachSheet> {
  late final _tim = TextEditingController(text: widget.sdtMoi.isNotEmpty ? widget.sdtMoi : widget.tenMoi);
  late final _ten = TextEditingController(text: widget.tenMoi);
  late final _sdt = TextEditingController(text: widget.sdtMoi);
  final _repo = CoreCustomerRepository();
  List<CustomerModel> _ds = const [];
  bool _dangTim = false;
  bool _taoMoi = false;
  String? _loi;
  Timer? _cho;

  @override
  void initState() {
    super.initState();
    if (_tim.text.trim().length >= 2) _timKhach();
  }

  @override
  void dispose() {
    _cho?.cancel();
    _tim.dispose();
    _ten.dispose();
    _sdt.dispose();
    super.dispose();
  }

  Future<void> _timKhach() async {
    final q = _tim.text.trim();
    if (q.length < 2) return setState(() => _ds = const []);
    setState(() => _dangTim = true);
    try {
      final ds = await _repo.searchByNameOrPhone(q);
      if (mounted && _tim.text.trim() == q) setState(() => _ds = ds);
    } catch (_) {
      if (mounted) setState(() => _loi = 'Chưa tìm được, kiểm tra mạng');
    }
    if (mounted) setState(() => _dangTim = false);
  }

  Future<void> _tao() async {
    final ten = _ten.text.trim();
    final sdt = _sdt.text.trim();
    if (ten.isEmpty || sdt.length < 9) return setState(() => _loi = 'Nhập tên và số điện thoại');
    setState(() {
      _dangTim = true;
      _loi = null;
    });
    try {
      final co = await _repo.getByPhone(sdt);
      if (co != null) {
        if (mounted) Navigator.pop(context, co); // số đã có khách: dùng luôn, không tạo trùng
        return;
      }
      final id = await _repo.create(name: ten, phone: sdt);
      final k = await _repo.getById(id);
      if (mounted) Navigator.pop(context, k);
    } catch (_) {
      if (mounted) {
        setState(() {
          _dangTim = false;
          _loi = 'Chưa tạo được khách, kiểm tra mạng rồi thử lại';
        });
      }
    }
  }

  InputDecoration _o(String nhan, IconData icon) => InputDecoration(
        labelText: nhan,
        prefixIcon: Icon(icon, color: _kNavy, size: 20),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        decoration: BoxDecoration(color: _kCream, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_taoMoi ? 'Khách mới' : 'Chọn khách hàng', textAlign: TextAlign.center, style: _chu(18, FontWeight.w800)),
            const SizedBox(height: 12),
            if (!_taoMoi) ...[
              TextField(
                controller: _tim,
                autofocus: _tim.text.isEmpty,
                style: _chu(15, FontWeight.w600),
                decoration: _o('Tìm số điện thoại hoặc tên', Icons.search_rounded),
                onChanged: (_) {
                  _cho?.cancel();
                  _cho = Timer(const Duration(milliseconds: 350), _timKhach);
                },
              ),
              const SizedBox(height: 8),
              Flexible(
                child: _dangTim && _ds.isEmpty
                    ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final k in _ds)
                            ListTile(
                              minTileHeight: 52,
                              leading: const Icon(Icons.account_circle_rounded, color: _kNavy),
                              title: Text(k.name, style: _chu(15, FontWeight.w700)),
                              subtitle: Text(
                                [if ((k.phone ?? '').isNotEmpty) k.phone!, 'ví ${fmtVnd(k.realBalance)}'].join(' · '),
                                style: _chu(12.5, FontWeight.w500, _kNavy.withValues(alpha: 0.65)),
                              ),
                              onTap: () => Navigator.pop(context, k),
                            ),
                          if (!_dangTim && _ds.isEmpty && _tim.text.trim().length >= 2)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text('Không có khách nào khớp', textAlign: TextAlign.center, style: _chu(13, FontWeight.w600, _kNavy.withValues(alpha: 0.6))),
                            ),
                        ],
                      ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _taoMoi = true;
                  _loi = null;
                }),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text('Khách mới (tên + số điện thoại)', style: _chu(14, FontWeight.w800)),
              ),
            ] else ...[
              TextField(controller: _ten, textCapitalization: TextCapitalization.words, style: _chu(15, FontWeight.w600), decoration: _o('Tên khách', Icons.person_rounded)),
              const SizedBox(height: 10),
              TextField(controller: _sdt, keyboardType: TextInputType.phone, style: _chu(15, FontWeight.w600), decoration: _o('Số điện thoại', Icons.call_rounded)),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _dangTim ? null : _tao,
                  style: ElevatedButton.styleFrom(backgroundColor: _kNavy, foregroundColor: Colors.white, elevation: 0),
                  child: Text('Tạo khách', style: _chu(15, FontWeight.w800, Colors.white)),
                ),
              ),
              TextButton(onPressed: () => setState(() => _taoMoi = false), child: Text('Quay lại tìm', style: _chu(14, FontWeight.w700))),
            ],
            if (_loi != null) Text(_loi!, textAlign: TextAlign.center, style: _chu(13, FontWeight.w700, _kRed)),
          ],
        ),
      ),
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
