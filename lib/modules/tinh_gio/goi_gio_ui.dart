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

/// Hộp thêm / sửa một gói của bàn. Trả gói mới (null = huỷ). [daCo] = số phút của các gói khác của bàn.
class GoiGioSheet extends StatefulWidget {
  final GoiGio? goi;
  final Set<int> daCo;
  const GoiGioSheet({super.key, this.goi, this.daCo = const {}});

  @override
  State<GoiGioSheet> createState() => _GoiGioSheetState();
}

class _GoiGioSheetState extends State<GoiGioSheet> {
  static const _thoiLuong = [30, 60, 90, 120, 180, 240, 300];
  late int _phut = widget.goi?.soPhut ?? 120;
  late final _giaCtrl = TextEditingController(
    text: widget.goi == null ? '' : fmtVnd(widget.goi!.gia).replaceAll(' đ', ''),
  );
  String? _loi;

  @override
  void dispose() {
    _giaCtrl.dispose();
    super.dispose();
  }

  void _xong() {
    final gia = int.tryParse(_giaCtrl.text.replaceAll('.', ''));
    if (widget.daCo.contains(_phut)) return setState(() => _loi = 'Bàn đã có gói ${thoiLuongChu(_phut)}.');
    if (gia == null) return setState(() => _loi = 'Nhập giá của gói.');
    Navigator.pop(context, GoiGio(id: widget.goi?.id, soPhut: _phut, gia: gia.toDouble()));
  }

  @override
  Widget build(BuildContext context) {
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
              Text(widget.goi == null ? 'Thêm gói giờ' : 'Sửa gói giờ', style: _chu(18, FontWeight.w800)),
              const SizedBox(height: 12),
              Text('Thời gian của gói', style: _chu(12.5, FontWeight.w800, _nhat(0.65))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in _thoiLuong)
                    ChoiceChip(
                      label: Text(thoiLuongChu(p)),
                      selected: p == _phut,
                      onSelected: widget.daCo.contains(p)
                          ? null
                          : (_) => setState(() {
                                _phut = p;
                                _loi = null;
                              }),
                      showCheckmark: false,
                      labelStyle: _chu(13, FontWeight.w700, p == _phut ? Colors.white : _kNavy),
                      selectedColor: _kNavy,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: p == _phut ? _kNavy : _nhat(0.18)),
                      shape: const StadiumBorder(),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Giá trọn gói', style: _chu(12.5, FontWeight.w800, _nhat(0.65))),
              const SizedBox(height: 6),
              TextField(
                controller: _giaCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [SoChamFormatter()],
                onChanged: (_) => setState(() => _loi = null),
                style: _chu(22, FontWeight.w800),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: 'đ',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _nhat(0.14))),
                  enabledBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _nhat(0.14))),
                  focusedBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kNavy)),
                ),
              ),
              const SizedBox(height: 6),
              Text('Khách về sớm vẫn trả đủ giá gói. Chơi quá ${thoiLuongChu(_phut)} thì phần lố tính theo giá giờ.',
                  style: _chu(12, FontWeight.w500, _nhat(0.6))),
              if (_loi != null) ...[
                const SizedBox(height: 8),
                Text(_loi!, style: _chu(13, FontWeight.w700, _kRed)),
              ],
              const SizedBox(height: 14),
              _nutChinh('Xong', _xong),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hộp chọn gói cho bàn đang chơi. [goiPhut] / [goiGia] = gói phiên đang có (null = chưa chọn).
class ChonGoiSheet extends ConsumerStatefulWidget {
  final String tableId;
  final String sessionId;
  final int? goiPhut;
  final double? goiGia;
  const ChonGoiSheet({super.key, required this.tableId, required this.sessionId, this.goiPhut, this.goiGia});

  @override
  ConsumerState<ChonGoiSheet> createState() => _ChonGoiSheetState();
}

class _ChonGoiSheetState extends ConsumerState<ChonGoiSheet> {
  bool _dangLuu = false;
  String? _loi;

  bool get _daCo => widget.goiPhut != null;

  Future<void> _chon(String? goiId) async {
    if (_dangLuu) return;
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    final loi = await ref.read(banRepositoryProvider).chonGoiGio(widget.sessionId, goiId);
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

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(giaGioCaiDatProvider).value?[widget.tableId]?.goi ?? const <GoiGio>[];
    Widget dong(String ten, String phu, bool dangDung, VoidCallback? bam) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: dangDung ? _kTeal : _nhat(0.12), width: dangDung ? 2 : 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _dangLuu || dangDung ? null : bam,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(dangDung ? Icons.check_circle_rounded : Icons.timer_outlined,
                        color: dangDung ? _kTeal : _nhat(0.55)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(ten, style: _chu(15, FontWeight.w800))),
                    Text(phu, style: _chu(15, FontWeight.w800, _kTeal)),
                  ],
                ),
              ),
            ),
          ),
        );
    return Container(
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
            Text(_daCo ? 'Đổi gói giờ' : 'Chọn gói giờ', style: _chu(18, FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              _daCo
                  ? 'Đang dùng: ${goiCuaPhienChu(widget.goiPhut!, widget.goiGia)}. Đổi hoặc bỏ gói cần Chủ quán / Quản lý.'
                  : 'Gói tính từ lúc khách vào. Về sớm vẫn trả đủ gói; chơi lố tính thêm theo giá giờ.',
              style: _chu(12.5, FontWeight.w500, _nhat(0.65)),
            ),
            const SizedBox(height: 12),
            if (ds.isEmpty)
              Text('Bàn này chưa có gói. Giữ lâu vào bàn → "Đặt giá giờ" → "Gói giờ" để thêm.',
                  style: _chu(13, FontWeight.w600, _nhat(0.6)))
            else
              for (final g in ds)
                dong(g.ten, fmtVnd(g.gia), (widget.goiGia ?? 0) > 0 && widget.goiPhut == g.soPhut && widget.goiGia == g.gia,
                    g.id == null ? null : () => _chon(g.id)),
            if (_daCo) dong('Không dùng gói', 'tính theo giờ', false, () => _chon(null)),
            if (_loi != null) ...[
              const SizedBox(height: 4),
              Text(_loi!, style: _chu(13, FontWeight.w700, _kRed)),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: _dangLuu ? null : () => Navigator.pop(context),
                child: _dangLuu
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text('Đóng', style: _chu(15, FontWeight.w700, _nhat(0.6))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dòng gói trong khối ĐANG TÍNH GIỜ (nền xanh đậm): "Gói 2 giờ 100.000 đ · còn 25 phút" + nút chọn / đổi gói.
/// Bàn không có gói nào và phiên chưa chọn gói thì không hiện gì.
class GoiGioDongBan extends ConsumerWidget {
  final String tableId;
  final String sessionId;
  final int? goiPhut;
  final double? goiGia;
  final DateTime vao;
  final DateTime luc;
  const GoiGioDongBan({
    super.key,
    required this.tableId,
    required this.sessionId,
    required this.goiPhut,
    required this.goiGia,
    required this.vao,
    required this.luc,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coGoi = goiPhut != null && goiPhut! > 0;
    final dsGoi = ref.watch(giaGioCaiDatProvider).value?[tableId]?.goi ?? const <GoiGio>[];
    if (!coGoi && dsGoi.isEmpty) return const SizedBox.shrink();
    final con = coGoi ? goiConPhut(goiPhut!, vao, luc) : 0;
    final mau = !coGoi
        ? Colors.white.withValues(alpha: 0.85)
        : con <= 0
            ? const Color(0xFFFFB4A8)
            : con <= kGoiNhacTruoc.inMinutes
                ? const Color(0xFFFFC94D)
                : const Color(0xFF7EE0D2);
    final chu = !coGoi
        ? 'Chưa chọn gói · tính theo giờ'
        : '${goiCuaPhienChu(goiPhut!, goiGia)} · ${con > 0 ? 'còn ${thoiLuongChu(con)}' : 'hết gói, lố ${thoiLuongChu(-con < 1 ? 0 : -con)}'}';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: mau.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 18, color: mau),
            const SizedBox(width: 8),
            Expanded(child: Text(chu, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: mau))),
            TextButton(
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => ChonGoiSheet(tableId: tableId, sessionId: sessionId, goiPhut: goiPhut, goiGia: goiGia),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 40),
                textStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              child: Text(coGoi ? 'Đổi gói' : 'Chọn gói'),
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
    final nay = DateTime.now();
    for (final s in ds.values) {
      final goi = s.goiPhut;
      if (goi == null || goi <= 0 || s.gioBatDau == null) continue;
      final het = DateTime.fromMillisecondsSinceEpoch(s.gioBatDau!).add(Duration(minutes: goi));
      final khoa = '${s.id}|${s.gioBatDau}|$goi';
      // Hết gói: nhắc trong 30 phút sau mốc (mở app muộn hơn thì thôi). Sắp hết: trong 10 phút cuối.
      if (!nay.isBefore(het) && nay.isBefore(het.add(const Duration(minutes: 30))) && !_daHien.contains('$khoa|het')) {
        _daHien
          ..add('$khoa|het')
          ..add('$khoa|sap');
        unawaited(_hien(s, het, true));
        return;
      }
      if (!nay.isBefore(het.subtract(kGoiNhacTruoc)) && nay.isBefore(het) && !_daHien.contains('$khoa|sap')) {
        _daHien.add('$khoa|sap');
        unawaited(_hien(s, het, false));
        return;
      }
    }
  }

  Future<void> _hien(BanSessionModel s, DateTime het, bool daHet) async {
    _dangHien = true;
    unawaited(QrSoundService.playNotificationSound());
    final ban = (ref.read(allBanTablesProvider).value ?? const <BanTableModel>[])
            .where((b) => b.id == s.tableId)
            .firstOrNull
            ?.label ??
        '';
    final gio = '${het.hour.toString().padLeft(2, '0')}:${het.minute.toString().padLeft(2, '0')}';
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(daHet ? Icons.timer_off_rounded : Icons.timer_outlined, color: daHet ? _kRed : _kOrange),
            const SizedBox(width: 8),
            Expanded(child: Text(daHet ? 'Hết gói giờ' : 'Còn 10 phút hết gói', style: _chu(18, FontWeight.w800))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${ban.isEmpty ? '' : '$ban · '}${goiCuaPhienChu(s.goiPhut!, s.goiGia)}',
                style: _chu(16, FontWeight.w800, daHet ? _kRed : _kOrange)),
            const SizedBox(height: 6),
            Text(daHet ? 'Hết gói lúc $gio. Chơi tiếp thì tính thêm theo giá giờ.' : 'Hết gói lúc $gio. Báo khách để gia hạn hoặc chuẩn bị về.',
                style: _chu(14, FontWeight.w600)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: _kNavy, foregroundColor: Colors.white, elevation: 0),
            child: Text('Đã báo khách', style: _chu(14, FontWeight.w800, Colors.white)),
          ),
        ],
      ),
    );
    _dangHien = false;
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
