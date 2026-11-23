import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/product_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/repositories/ban_repository.dart';
import '../../core/utils/money_formatter.dart';
import 'tinh_gio.dart';

const _kNavy = Color(0xFF1C2151);
const _kCream = Color(0xFFFFF8F0);
const _kRed = Color(0xFFEF4444);

/// Quán có bật module Tính giờ không. Đang tắt thì mọi phần tính giờ ở màn Bàn ẩn hết
/// (bàn đã gắn giá giờ vẫn chạy giờ ở máy chủ; bật lại là thấy).
final tinhGioModuleActiveProvider = Provider<bool>((ref) {
  return ref
          .watch(activeModulesProvider)
          .whenData((mods) => mods.any((m) => m.id == kTinhGioModuleId))
          .value ??
      false;
});

/// MỘT nhịp chung cho mọi thẻ bàn đang chạy giờ (20 giây), không phải mỗi thẻ một bộ đếm.
final tinhGioTickProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 20), (_) => DateTime.now());
});

/// Giá một giờ theo mã món giá giờ.
final tinhGioGiaTheoMonProvider = Provider.autoDispose<Map<String, ProductModel>>((ref) {
  final ds = ref.watch(allProductsProvider).value ?? const <ProductModel>[];
  return {for (final p in ds) p.id: p};
});

/// Hộp chọn món giá giờ cho một bàn (hoặc cả khu). Trả về true khi đã lưu.
class TinhGioGiaGioSheet extends ConsumerStatefulWidget {
  final BanTableModel table;
  final String tenKhu;
  /// Mọi bàn của khu (kể cả [table]) — dùng cho "Áp cho cả khu".
  final List<BanTableModel> banCuaKhu;

  const TinhGioGiaGioSheet({
    super.key,
    required this.table,
    required this.tenKhu,
    required this.banCuaKhu,
  });

  @override
  ConsumerState<TinhGioGiaGioSheet> createState() => _TinhGioGiaGioSheetState();
}

class _TinhGioGiaGioSheetState extends ConsumerState<TinhGioGiaGioSheet> {
  final _timCtrl = TextEditingController();
  bool _caKhu = false;
  bool _dangLuu = false;
  String? _loi;

  @override
  void dispose() {
    _timCtrl.dispose();
    super.dispose();
  }

  Future<void> _chon(String? productId) async {
    if (_dangLuu) return;
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    final ids = _caKhu ? widget.banCuaKhu.map((b) => b.id).toList() : [widget.table.id];
    final loi = await ref.read(banRepositoryProvider).datGiaGio(ids, productId);
    if (!mounted) return;
    if (loi == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _dangLuu = false;
        _loi = loi;
      });
    }
  }

  TextStyle _chu(double size, FontWeight w, [Color? c]) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c ?? _kNavy);

  @override
  Widget build(BuildContext context) {
    final tuKhoa = _timCtrl.text.trim().toLowerCase();
    final mon = (ref.watch(posProductsProvider).value ?? const <ProductModel>[])
        .where((p) => !p.isTopping && (tuKhoa.isEmpty || p.name.toLowerCase().contains(tuKhoa)))
        .toList()
      ..sort((a, b) {
        // món đang chọn lên đầu, rồi danh mục có chữ "giờ", rồi theo tên
        int hang(ProductModel p) => p.id == widget.table.giaGioProductId
            ? 0
            : ((p.category ?? '').toLowerCase().contains('giờ') || p.name.toLowerCase().contains('giờ'))
                ? 1
                : 2;
        final h = hang(a).compareTo(hang(b));
        return h != 0 ? h : a.name.compareTo(b.name);
      });

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        decoration: BoxDecoration(color: _kCream, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kNavy.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text('Tính tiền giờ · ${widget.table.label}', style: _chu(18, FontWeight.w800)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Text(
                'Chọn món giá giờ. Giá bán của món là giá MỘT GIỜ. Chưa có thì vào Menu tạo món, '
                'ví dụ "Giờ bàn lỗ" 60.000đ, danh mục "Tiền giờ".',
                textAlign: TextAlign.center,
                style: _chu(12.5, FontWeight.w500, _kNavy.withValues(alpha: 0.65)),
              ),
            ),
            if (widget.banCuaKhu.length > 1)
              SwitchListTile(
                dense: true,
                value: _caKhu,
                activeThumbColor: _kNavy,
                onChanged: _dangLuu ? null : (v) => setState(() => _caKhu = v),
                title: Text(
                  'Áp cho cả khu ${widget.tenKhu} (${widget.banCuaKhu.length} bàn)',
                  style: _chu(14, FontWeight.w700),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _timCtrl,
                onChanged: (_) => setState(() {}),
                style: _chu(14, FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Tìm món',
                  prefixIcon: const Icon(Icons.search_rounded, color: _kNavy),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _kNavy.withValues(alpha: 0.2)),
                  ),
                ),
              ),
            ),
            if (_loi != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(_loi!, textAlign: TextAlign.center, style: _chu(13, FontWeight.w700, _kRed)),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  if (widget.table.tinhGio || _caKhu)
                    _dong(
                      icon: Icons.timer_off_rounded,
                      ten: 'Không tính giờ (bàn thường)',
                      phu: 'Gỡ giá giờ',
                      dangChon: false,
                      onTap: () => _chon(null),
                    ),
                  for (final p in mon)
                    _dong(
                      icon: Icons.timer_rounded,
                      ten: p.name,
                      phu: '${fmtVnd(p.sellPrice)} / giờ',
                      dangChon: p.id == widget.table.giaGioProductId,
                      onTap: () => _chon(p.id),
                    ),
                  if (mon.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Chưa có món nào. Vào Menu tạo món giá giờ trước.',
                        textAlign: TextAlign.center,
                        style: _chu(13, FontWeight.w600, _kNavy.withValues(alpha: 0.6)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dong({
    required IconData icon,
    required String ten,
    required String phu,
    required bool dangChon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: dangChon ? _kNavy.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _dangLuu ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52), // vùng chạm tối thiểu 52
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, color: _kNavy, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(ten, maxLines: 2, overflow: TextOverflow.ellipsis, style: _chu(14, FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Text(phu, style: _chu(13, FontWeight.w700, _kNavy.withValues(alpha: 0.7))),
                  if (dangChon) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle_rounded, color: _kNavy, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
