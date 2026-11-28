import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/permission_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/repositories/ban_repository.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/responsive.dart';
import '../qr_order/services/qr_sound_service.dart';
import 'dat_truoc.dart';
import 'gia_gio.dart' show thuChuCua;
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
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DatTruocFormSheet(ban: ban, ngay: _ngay, trongNgay: trongNgay, sua: sua, tuMacDinh: tu),
    );
    if (ok == true && mounted) _thongBao(context, sua == null ? 'Đã đặt ${ban.label}' : 'Đã sửa lượt đặt');
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
    }
  }

  /// Chạm ô trống trên lưới: nửa giờ đã qua thì báo, không mở hộp.
  void _datO(BanTableModel ban, DateTime tu, List<DatTruoc> trongNgay) {
    if (!tu.add(const Duration(minutes: 30)).isAfter(DateTime.now())) {
      _thongBao(context, 'Giờ này đã qua, chọn giờ khác', loi: true);
      return;
    }
    _dat(ban, trongNgay, tu: tu);
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
        return LichLuoi(
          bans: bans,
          dat: dat,
          ngay: _ngay,
          luc: widget.lucLuoi,
          onDatO: (b, tu) => _datO(b, tu, dat),
          onMo: (b, d) => _moLuot(b, d, dat),
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
      if (dat.tienCoc > 0) 'đã cọc ${fmtVnd(dat.tienCoc)}',
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
  late final _coc = TextEditingController(
    text: (widget.sua?.tienCoc ?? 0) > 0 ? widget.sua!.tienCoc.toInt().toString() : '',
  );
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
          tienCoc: double.tryParse(_coc.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
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
      Navigator.pop(context, true);
    } else {
      setState(() {
        _dangLuu = false;
        _loi = r['message'] as String? ?? 'Chưa lưu được';
      });
    }
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
    if (_lap) return _luuLap();
    final r = await ref.read(datTruocRepositoryProvider).luu(
          id: widget.sua?.id,
          tableId: widget.ban.id,
          tenKhach: _ten.text,
          sdt: _sdt.text,
          gioTu: _tu,
          gioDen: _den,
          ghiChu: _ghiChu.text,
          tienCoc: double.tryParse(_coc.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        );
    if (!mounted) return;
    if (r['success'] == true) {
      Navigator.pop(context, true);
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
              TextField(
                controller: _coc,
                keyboardType: TextInputType.number,
                style: _chu(14, FontWeight.w500),
                decoration: _o('Tiền đã cọc (chỉ ghi nhớ)', goiY: '0'),
              ),
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
                          widget.sua != null
                              ? 'Lưu'
                              : _lap
                                  ? 'Đặt ${_buoi.length} buổi'
                                  : 'Đặt',
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
    return const SizedBox.shrink();
  }
}
