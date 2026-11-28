import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/repositories/ban_repository.dart';
import '../../core/repositories/core_product_repository.dart';
import '../../core/utils/money_formatter.dart';
import '../../shared/widgets/module_tile.dart';
import 'gia_gio_ui.dart';
import 'loai_hinh.dart';
import 'nganh_icon.dart';
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

/// Ngày lễ của quán (đợt 6, bảng ban_ngay_le), từ tuần trước trở đi, theo ngày. Máy chủ chưa có bảng hoặc lỗi
/// mạng → rỗng (khung Lễ không áp, như máy chủ chưa áp đợt 6).
final ngayLeProvider = FutureProvider.autoDispose<List<NgayLe>>((ref) async {
  final storeId = ref.watch(sessionProvider.select((s) => s?.storeId));
  if (storeId == null) return const [];
  try {
    final tu = DateTime.now().subtract(const Duration(days: 7));
    final rows = await Supabase.instance.client
        .from('ban_ngay_le')
        .select('ngay, ten')
        .eq('store_id', storeId)
        .gte('ngay', '${tu.year}-${tu.month.toString().padLeft(2, '0')}-${tu.day.toString().padLeft(2, '0')}')
        .order('ngay', ascending: true)
        .timeout(const Duration(seconds: 10));
    return [
      for (final r in rows)
        if (DateTime.tryParse('${r['ngay']}') case final d?) NgayLe(DateTime(d.year, d.month, d.day), '${r['ten'] ?? ''}'),
    ];
  } catch (e) {
    debugPrint('[ngayLe] chưa đọc được ngày lễ (máy chủ chưa có hoặc lỗi mạng): $e');
    return const [];
  }
});

/// Khung giá + làm tròn của các bàn trong quán (đợt 1, bảng ban_gia_gio_cau_hinh / ban_gia_gio_khung). Đọc một
/// lần khi màn mở; lưu xong thì invalidate. Máy chủ chưa có hai bảng (chưa áp migration) hoặc lỗi mạng → rỗng:
/// app tính tạm như cũ, tiền thật vẫn do máy chủ chốt.
final giaGioCaiDatProvider = FutureProvider.autoDispose<Map<String, GiaGioCaiDat>>((ref) async {
  final storeId = ref.watch(sessionProvider.select((s) => s?.storeId));
  if (storeId == null) return const {};
  final ngayLe = {for (final n in await ref.watch(ngayLeProvider.future)) soNgay(n.ngay)};
  // Gói giờ (đợt 7) đọc riêng: máy chủ có khung giá mà chưa có bảng gói vẫn đọc được khung.
  final goi = <String, List<GoiGio>>{};
  try {
    final rows = await Supabase.instance.client
        .from('ban_goi_gio')
        .select('id, table_id, so_phut, gia, thu_tu')
        .eq('store_id', storeId)
        .order('thu_tu', ascending: true)
        .timeout(const Duration(seconds: 10));
    for (final r in rows) {
      final g = GoiGio.tuDong(r);
      if (g != null) (goi[r['table_id'] as String] ??= []).add(g);
    }
  } catch (e) {
    debugPrint('[giaGioCaiDat] chưa đọc được gói giờ (máy chủ chưa có hoặc lỗi mạng): $e');
  }
  try {
    final db = Supabase.instance.client;
    final kq = await Future.wait([
      db.from('ban_gia_gio_cau_hinh').select('table_id, block_phut, toi_thieu_phut, an_han_phut').eq('store_id', storeId),
      db
          .from('ban_gia_gio_khung')
          .select('id, table_id, thu, tu, den, gia, thu_tu')
          .eq('store_id', storeId)
          .order('thu_tu', ascending: true)
          .order('id', ascending: true), // như máy chủ: ORDER BY thu_tu, id
    ]).timeout(const Duration(seconds: 10));
    final khung = <String, List<KhungGia>>{};
    for (final r in kq[1]) {
      final k = KhungGia.tuDong(r);
      if (k != null) (khung[r['table_id'] as String] ??= []).add(k);
    }
    final ketQua = <String, GiaGioCaiDat>{};
    for (final r in kq[0]) {
      final id = r['table_id'] as String;
      ketQua[id] = GiaGioCaiDat(
        block: (r['block_phut'] as num?)?.toInt() ?? 1,
        toiThieu: (r['toi_thieu_phut'] as num?)?.toInt() ?? 0,
        anHan: (r['an_han_phut'] as num?)?.toInt() ?? 0,
        khung: khung[id] ?? const [],
        ngayLe: ngayLe,
        goi: goi[id] ?? const [],
      );
    }
    for (final e in khung.entries) {
      ketQua.putIfAbsent(e.key, () => GiaGioCaiDat(khung: e.value, ngayLe: ngayLe, goi: goi[e.key] ?? const []));
    }
    for (final e in goi.entries) {
      ketQua.putIfAbsent(e.key, () => GiaGioCaiDat(ngayLe: ngayLe, goi: e.value));
    }
    return ketQua;
  } catch (e) {
    debugPrint('[giaGioCaiDat] chưa đọc được khung giá (máy chủ chưa có hoặc lỗi mạng): $e');
    return {for (final e in goi.entries) e.key: GiaGioCaiDat(goi: e.value)};
  }
});

/// Cài đặt giá giờ của một bàn (mặc định khi chưa cài / chưa đọc được).
GiaGioCaiDat giaGioCuaBan(WidgetRef ref, String tableId) =>
    ref.watch(giaGioCaiDatProvider).value?[tableId] ?? GiaGioCaiDat.macDinh;

/// Loại hình quán đã chọn cho module Tính giờ (mặc định mục chung "Nhiều loại" khi chưa chọn hoặc chưa đọc được).
final tinhGioLoaiHinhProvider = FutureProvider<LoaiHinh>((ref) async {
  ref.watch(sessionProvider); // đổi quán thì đọc lại
  return loaiHinhTheoId(await ref.watch(settingsRepositoryProvider).get(kLoaiHinhSettingKey));
});

/// Ô module Tính giờ ở Trang chủ theo loại hình: giữ màu và đường dẫn, đổi tên + biểu tượng.
/// Quán nhiều loại hình (hoặc chưa chọn) giữ ô gốc: tên "Các hoạt động tính giờ" và cụm bốn hình.
ModuleTileData tinhGioTileData(ModuleTileData goc, LoaiHinh l) => l.nhieuLoai
    ? goc
    : ModuleTileData(
        id: goc.id,
        title: l.ten,
        subtitle: l.moTa,
        icon: l.icon ?? goc.icon,
        iconBuilder: l.hinh == null ? null : (size, color) => NganhIcon(l.hinh!, size: size, color: color),
        baseColor: goc.baseColor,
        route: goc.route,
      );

/// Hộp chọn loại hình. Chọn xong lưu vào cài đặt của quán và đóng.
class TinhGioLoaiHinhSheet extends ConsumerStatefulWidget {
  const TinhGioLoaiHinhSheet({super.key});

  @override
  ConsumerState<TinhGioLoaiHinhSheet> createState() => _TinhGioLoaiHinhSheetState();
}

class _TinhGioLoaiHinhSheetState extends ConsumerState<TinhGioLoaiHinhSheet> {
  String? _dangLuu;
  String? _loi;

  Future<void> _chon(LoaiHinh l) async {
    if (_dangLuu != null) return;
    setState(() {
      _dangLuu = l.id;
      _loi = null;
    });
    try {
      await ref.read(settingsRepositoryProvider).set(kLoaiHinhSettingKey, l.id);
      ref.invalidate(tinhGioLoaiHinhProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _dangLuu = null;
          _loi = 'Chưa lưu được loại hình. Kiểm tra mạng rồi thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dangChon = ref.watch(tinhGioLoaiHinhProvider).value?.id;
    TextStyle chu(double size, FontWeight w, [Color? c]) =>
        GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c ?? _kNavy);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(color: _kCream, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _kNavy.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text('Quán thuộc loại hình nào?', style: chu(18, FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Ô module ở Trang chủ sẽ mang tên và biểu tượng của loại hình này. Đổi lại lúc nào cũng được.',
            textAlign: TextAlign.center,
            style: chu(12.5, FontWeight.w500, _kNavy.withValues(alpha: 0.65)),
          ),
          if (_loi != null) ...[
            const SizedBox(height: 8),
            Text(_loi!, textAlign: TextAlign.center, style: chu(13, FontWeight.w700, _kRed)),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final l in kLoaiHinh)
                Material(
                  color: l.id == dangChon ? _kNavy : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _dangLuu != null ? null : () => _chon(l),
                    child: SizedBox(
                      width: 104,
                      height: 92,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _dangLuu == l.id
                              ? const SizedBox.square(
                                  dimension: 30,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : l.bieuTuong(size: 30, color: l.id == dangChon ? Colors.white : _kNavy),
                          const SizedBox(height: 8),
                          Text(
                            l.nhan,
                            style: chu(13.5, FontWeight.w700, l.id == dangChon ? Colors.white : _kNavy),
                          ),
                        ],
                      ),
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

/// Hộp chọn món giá giờ cho một bàn (hoặc cả khu). Trả về true khi đã lưu.
class TinhGioGiaGioSheet extends ConsumerStatefulWidget {
  final BanTableModel table;
  final String tenKhu;
  /// Mọi bàn của khu (kể cả [table]) — dùng cho "Áp cho cả khu".
  final List<BanTableModel> banCuaKhu;
  /// Giờ "khách vào" của các ví dụ tính tiền; null = bây giờ (ảnh mẫu trong test cố định giờ này).
  final DateTime? lucViDu;

  const TinhGioGiaGioSheet({
    super.key,
    required this.table,
    required this.tenKhu,
    required this.banCuaKhu,
    this.lucViDu,
  });

  @override
  ConsumerState<TinhGioGiaGioSheet> createState() => _TinhGioGiaGioSheetState();
}

String _soCham(int v) => fmtVnd(v).replaceAll(' đ', '');

/// Ô giá: chỉ nhận chữ số, tự chèn dấu chấm hàng nghìn ("60000" → "60.000").
class _GiaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue cu, TextEditingValue moi) {
    final so = moi.text.replaceAll(RegExp(r'[^0-9]'), '');
    final chu = so.isEmpty ? '' : _soCham(int.parse(so.length > 9 ? so.substring(0, 9) : so));
    return TextEditingValue(text: chu, selection: TextSelection.collapsed(offset: chu.length));
  }
}

class _TinhGioGiaGioSheetState extends ConsumerState<TinhGioGiaGioSheet> {
  /// Mức giá thường gặp ở quán bi da, sân, phòng hát — bấm để điền nhanh.
  static const _goiY = [30000, 40000, 50000, 60000, 80000, 100000, 120000, 150000];
  static const _kTeal = Color(0xFF0D9488);

  final _giaCtrl = TextEditingController();
  bool _caKhu = false;
  /// Khung giá + làm tròn đang sửa; [_caiDatGoc] = bản đọc từ máy chủ (null = chưa đọc xong).
  GiaGioCaiDat _caiDat = GiaGioCaiDat.macDinh;
  GiaGioCaiDat? _caiDatGoc;
  bool _moCaiThem = false;
  bool _dangLuu = false;
  String? _loi;

  int get _gia => int.tryParse(_giaCtrl.text.replaceAll('.', '')) ?? 0;

  /// Bàn đã có giá thì điền sẵn để sửa, một lần, khi danh sách món đã tải (mở hộp lúc món chưa tải xong
  /// thì điền muộn hơn một chút).
  bool _daDienSan = false;

  void _dienSan() {
    if (_caiDatGoc == null) {
      final ds = ref.watch(giaGioCaiDatProvider);
      if (ds.hasValue) {
        _caiDatGoc = ds.value![widget.table.id] ?? GiaGioCaiDat.macDinh;
        _caiDat = _caiDatGoc!;
        _moCaiThem = !_caiDat.laMacDinh || _caiDat.goi.isNotEmpty;
      }
    }
    if (_daDienSan) return;
    final id = widget.table.giaGioProductId;
    if (id == null) {
      _daDienSan = true;
      return;
    }
    final p = ref.watch(tinhGioGiaTheoMonProvider)[id];
    if (p == null) return;
    _daDienSan = true;
    if (_giaCtrl.text.isEmpty && p.sellPrice >= 1000) _giaCtrl.text = _soCham(p.sellPrice.round());
  }

  @override
  void dispose() {
    _giaCtrl.dispose();
    super.dispose();
  }

  Future<void> _chon(String? productId) async {
    if (_dangLuu) return;
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    final ids = _caKhu ? widget.banCuaKhu.map((b) => b.id).toList() : [widget.table.id];
    // Khung giá + làm tròn lưu TRƯỚC giá một giờ: máy chủ từ chối thì chưa đổi gì cả. Không đổi gì (và không chép
    // cho cả khu) thì không gọi, để máy chủ chưa có khung giá vẫn đặt được giá một giờ như cũ.
    if (productId != null) {
      final daCaiTrongKhu = ref.read(giaGioCaiDatProvider).value ?? const <String, GiaGioCaiDat>{};
      final canLuu = !_caiDat.trung(_caiDatGoc ?? GiaGioCaiDat.macDinh) ||
          (_caKhu && (!_caiDat.laMacDinh || ids.any((id) => !(daCaiTrongKhu[id]?.laMacDinh ?? true))));
      if (canLuu) {
        final loiCd = await ref.read(banRepositoryProvider).luuGiaGioCaiDat(
              ids,
              block: _caiDat.block,
              toiThieu: _caiDat.toiThieu,
              anHan: _caiDat.anHan,
              khung: [for (final k in _caiDat.khung) k.toJson()],
            );
        if (!mounted) return;
        if (loiCd != null) {
          setState(() {
            _dangLuu = false;
            _loi = loiCd;
          });
          return;
        }
        ref.invalidate(giaGioCaiDatProvider);
      }
      // Gói giờ (đợt 7) lưu riêng; không đổi gì (và không chép cho cả khu) thì không gọi.
      final goc = _caiDatGoc ?? GiaGioCaiDat.macDinh;
      final canLuuGoi = !_caiDat.goiTrung(goc) ||
          (_caKhu && (_caiDat.goi.isNotEmpty || ids.any((id) => (daCaiTrongKhu[id]?.goi ?? const []).isNotEmpty)));
      if (canLuuGoi) {
        final loiGoi = await ref
            .read(banRepositoryProvider)
            .luuGoiGio(ids, [for (final g in _caiDat.goi) g.toJson()]);
        if (!mounted) return;
        if (loiGoi != null) {
          ref.invalidate(giaGioCaiDatProvider);
          setState(() {
            _dangLuu = false;
            _loi = loiGoi;
          });
          return;
        }
        ref.invalidate(giaGioCaiDatProvider);
      }
    }
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

  /// Lưu giá vừa gõ: dùng lại món giá giờ cùng giá nếu có, không thì tạo món mới trong Kho hàng.
  Future<void> _luuGia(List<ProductModel> monGio) async {
    if (_dangLuu) return;
    final gia = _gia;
    if (gia < 1000) {
      setState(() => _loi = 'Nhập giá một giờ, ít nhất 1.000 đ.');
      return;
    }
    var id = monGio.where((p) => p.sellPrice.round() == gia).firstOrNull?.id;
    if (id == null) {
      setState(() {
        _dangLuu = true;
        _loi = null;
      });
      try {
        id = await CoreProductRepository.instance.create(
          // "/giờ" luôn đi kèm đơn giá: tên cũ "Tiền giờ 60.000 đ" đọc như số tiền phải trả.
          name: 'Giờ chơi ${fmtVnd(gia)}/giờ',
          category: kDanhMucTienGio,
          unit: 'giờ',
          sellPrice: gia.toDouble(),
        );
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _dangLuu = false;
          _loi = 'Chưa lưu được giá giờ. Kiểm tra mạng rồi thử lại.';
        });
        return;
      }
      if (!mounted) return;
      _dangLuu = false;
    }
    await _chon(id);
  }

  TextStyle _chu(double size, FontWeight w, [Color? c]) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c ?? _kNavy);

  Color _nhat(double a) => _kNavy.withValues(alpha: a);

  DateTime get _lucViDu => widget.lucViDu ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    _dienSan();
    // Chỉ các món giá giờ (và món bàn này đang dùng), không phải cả thực đơn. Đọc từ mọi món vì thực đơn
    // bán hàng (posProductsProvider) đã giấu món giá giờ.
    final mon = (ref.watch(allProductsProvider).value ?? const <ProductModel>[])
        .where((p) =>
            p.isActive &&
            !p.isTopping &&
            (p.id == widget.table.giaGioProductId || laMonGiaGio(p.name, p.category)))
        .toList();
    final gia = _gia;
    final loaiHinh = ref.watch(tinhGioLoaiHinhProvider).value ?? kLoaiHinh.last;
    // Chọn nhanh: giá quán đang dùng đứng trước, rồi các mức thường gặp.
    final giaDaCo = {for (final p in mon) p.sellPrice.round()}..removeWhere((g) => g < 1000);
    final chonNhanh = [...giaDaCo.toList()..sort(), ..._goiY.where((g) => !giaDaCo.contains(g))];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
        decoration: BoxDecoration(
          color: _kCream,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: _nhat(0.15), borderRadius: BorderRadius.circular(2)),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 14, bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dauHop(loaiHinh),
                    const SizedBox(height: 16),
                    _oGia(gia, mon),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: Row(
                        children: [
                          Text('Chọn nhanh', style: _chu(12.5, FontWeight.w800, _nhat(0.6))),
                          if (giaDaCo.isNotEmpty) ...[
                            const Spacer(),
                            const Icon(Icons.check_circle_rounded, size: 14, color: _kTeal),
                            const SizedBox(width: 4),
                            Text('giá quán đang dùng', style: _chu(12, FontWeight.w600, _nhat(0.6))),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 46,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: chonNhanh.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => _chipGia(chonNhanh[i], dangDung: giaDaCo.contains(chonNhanh[i])),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GiaGioCaiThem(
                      caiDat: _caiDat,
                      mo: _moCaiThem,
                      khoa: _dangLuu || _caiDatGoc == null,
                      onMo: () => setState(() => _moCaiThem = !_moCaiThem),
                      onDoi: (c) => setState(() {
                        _caiDat = c;
                        _loi = null;
                      }),
                    ),
                    if (widget.banCuaKhu.length > 1) ...[
                      const SizedBox(height: 16),
                      _phamVi(),
                    ],
                  ],
                ),
              ),
            ),
            // Báo lỗi ngay trên nút Lưu (trong phần cuộn thì bấm Lưu xong không thấy — máy ảo 28/11)
            if (_loi != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(_loi!, textAlign: TextAlign.center, style: _chu(13, FontWeight.w700, _kRed)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _dangLuu || gia < 1000 ? null : () => _luuGia(mon),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kNavy,
                    disabledBackgroundColor: _nhat(_dangLuu ? 0.85 : 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _dangLuu
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          gia >= 1000 ? 'Lưu  ·  ${fmtVnd(gia)} / giờ' : 'Lưu giá giờ',
                          style: _chu(15.5, FontWeight.w800, gia >= 1000 ? Colors.white : _nhat(0.38)),
                        ),
                ),
              ),
            ),
            if (widget.table.tinhGio || _caKhu)
              TextButton.icon(
                onPressed: _dangLuu ? null : () => _chon(null),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.timer_off_rounded, size: 18, color: _kRed),
                label: Text('Không tính giờ (bàn thường)', style: _chu(13.5, FontWeight.w700, _kRed)),
              )
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  // Huy hiệu ngành + tên bàn + nút đổi loại hình.
  Widget _dauHop(LoaiHinh loaiHinh) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2DD4BF), _kTeal, Color(0xFF115E59)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: _kTeal.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: Center(child: loaiHinh.bieuTuong(size: 28, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Giá giờ · ${widget.table.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _chu(19, FontWeight.w800).copyWith(letterSpacing: -0.3),
                ),
                const SizedBox(height: 2),
                Text(
                  _caiDat.block > 1
                      ? 'Làm tròn mỗi ${tinhGioThoiLuongDai(_caiDat.block)}'
                      : _caiDat.khung.isNotEmpty
                          ? 'Thu theo số phút, giá theo khung giờ'
                          : 'Thu theo số phút',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _chu(12.5, FontWeight.w500, _nhat(0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white,
            shape: StadiumBorder(side: BorderSide(color: _nhat(0.14))),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: _dangLuu
                  ? null
                  : () => showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => const TinhGioLoaiHinhSheet(),
                      ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loaiHinh.nhan, style: _chu(12.5, FontWeight.w700)),
                      const Icon(Icons.expand_more_rounded, size: 18, color: _kNavy),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Thẻ trắng: số tiền lớn + quy ra tiền cho 30 phút, 1 giờ 30, 2 giờ.
  Widget _oGia(int gia, List<ProductModel> mon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _nhat(0.08)),
        boxShadow: [BoxShadow(color: _nhat(0.07), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Giá một giờ', style: _chu(12.5, FontWeight.w700, _nhat(0.6))),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _giaCtrl,
                  enabled: !_dangLuu,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_GiaFormatter()],
                  onChanged: (_) => setState(() => _loi = null),
                  onSubmitted: (_) => _luuGia(mon),
                  cursorColor: _kNavy,
                  style: _chu(34, FontWeight.w800).copyWith(letterSpacing: -0.5),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: _chu(34, FontWeight.w800, _nhat(0.2)),
                    // app có khung ô nhập mặc định trong theme: tắt hết để số tiền nằm trần trên thẻ trắng
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              Text('đ / giờ', style: _chu(15, FontWeight.w700, _nhat(0.55))),
            ],
          ),
          Divider(height: 18, color: _nhat(0.08)),
          if (gia >= 1000) ...[
            // Ví dụ sống theo cài đặt đang sửa (khung giá, làm tròn), tính như máy chủ, khách vào lúc này.
            Text('Khách vào lúc ${gioPhutChu(_lucViDu.hour * 60 + _lucViDu.minute)}, chơi:',
                style: _chu(11.5, FontWeight.w600, _nhat(0.55))),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final (nhan, phut) in const [('25 phút', 25), ('47 phút', 47), ('1 giờ 40', 100)])
                  Expanded(
                    child: Builder(builder: (_) {
                      final v = tinhGioTien(vao: _lucViDu, phutChoi: phut, giaGoc: gia.toDouble(), caiDat: _caiDat);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nhan, style: _chu(11.5, FontWeight.w600, _nhat(0.55))),
                          const SizedBox(height: 2),
                          Text(fmtVnd(v.thanhTien), style: _chu(13.5, FontWeight.w800)),
                          if (v.soPhutTinh != phut)
                            Text('tính ${tinhGioThoiLuongDai(v.soPhutTinh)}', style: _chu(10.5, FontWeight.w600, _kTeal)),
                        ],
                      );
                    }),
                  ),
              ],
            ),
          ] else
            Text('Tính theo từng phút, làm tròn lên 1.000 đ.', style: _chu(12.5, FontWeight.w500, _nhat(0.6))),
        ],
      ),
    );
  }

  Widget _chipGia(int g, {required bool dangDung}) {
    final chon = g == _gia;
    return Material(
      color: chon ? _kNavy : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: chon ? _kNavy : _nhat(0.14))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: _dangLuu
            ? null
            : () => setState(() {
                  _giaCtrl.text = _soCham(g);
                  _loi = null;
                }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dangDung) ...[
                Icon(Icons.check_circle_rounded, size: 15, color: chon ? Colors.white : _kTeal),
                const SizedBox(width: 5),
              ],
              Text(_soCham(g), style: _chu(14, FontWeight.w700, chon ? Colors.white : _kNavy)),
            ],
          ),
        ),
      ),
    );
  }

  // Áp cho một bàn hay cả khu.
  Widget _phamVi() {
    Widget doan(String chu, bool chon, bool giaTri) => Expanded(
          child: Semantics(
            button: true,
            selected: chon,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dangLuu ? null : () => setState(() => _caKhu = giaTri),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 44,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: chon ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: chon ? [BoxShadow(color: _nhat(0.10), blurRadius: 8, offset: const Offset(0, 2))] : null,
                ),
                child: Text(
                  chu,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _chu(13.5, chon ? FontWeight.w800 : FontWeight.w600, chon ? _kNavy : _nhat(0.6)),
                ),
              ),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _nhat(0.06), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          doan('Chỉ ${widget.table.label}', !_caKhu, false),
          doan('Cả khu · ${widget.banCuaKhu.length} bàn', _caKhu, true),
        ],
      ),
    );
  }
}
