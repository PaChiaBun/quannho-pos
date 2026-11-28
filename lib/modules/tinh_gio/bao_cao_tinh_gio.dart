// Báo cáo tính giờ (đợt 5, .docs/ke-hoach-bao-cao-tinh-gio.md) — CHỈ ĐỌC.
// Nguồn: phiên bàn đã thanh toán có gio_bat_dau + các dòng của phiên (dòng tiền giờ có gio_tu / gio_den).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/app_providers.dart' show banRepositoryProvider;
import '../../core/providers/session_provider.dart';
import '../../core/repositories/ban_repository.dart';
import '../../core/services/store_auth_service.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/utils/paged_query.dart' show fetchAllPages;
import 'tinh_gio.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DỮ LIỆU + LUẬT THUẦN
// ─────────────────────────────────────────────────────────────────────────────

/// Một khoảng giờ chơi đã tính tiền (một dòng tiền giờ).
class DoanGio {
  final DateTime tu;
  final DateTime den;
  const DoanGio(this.tu, this.den);
  double get phut => den.isAfter(tu) ? den.difference(tu).inSeconds / 60 : 0;
}

/// Một lượt chơi = một phiên bàn tính giờ đã thanh toán.
class LuotChoi {
  final String tableId;
  final DateTime thanhToanLuc;
  final List<DoanGio> doan;
  final double tienGio;
  final double tienMon;
  const LuotChoi({
    required this.tableId,
    required this.thanhToanLuc,
    required this.doan,
    required this.tienGio,
    required this.tienMon,
  });
  double get phut => doan.fold(0, (s, d) => s + d.phut);
}

class TheoBan {
  int luot = 0;
  double phut = 0, tienGio = 0, tienMon = 0;
}

class TongHopTinhGio {
  final int soNgay;
  final int soBan;
  int luot = 0;
  double phut = 0, tienGio = 0, tienMon = 0;
  /// Phút chơi rơi vào từng giờ trong ngày (0–23), giờ theo máy.
  final List<double> phutTheoGio = List.filled(24, 0);
  /// Ngày (00:00) → (tiền giờ, tiền món).
  final Map<DateTime, ({double gio, double mon})> theoNgay = {};
  final Map<String, TheoBan> theoBan = {};

  TongHopTinhGio(this.soNgay, this.soBan);

  /// % bàn tính giờ có khách trung bình trong giờ [h].
  double tiLeGio(int h) => soNgay <= 0 || soBan <= 0 ? 0 : phutTheoGio[h] / (60 * soNgay * soBan);
  double get tiLeTienGio => tienGio + tienMon <= 0 ? 0 : tienGio / (tienGio + tienMon);
}

/// Cộng phút của đoạn [tu]–[den] vào từng giờ trong ngày (vắt qua nhiều giờ / nửa đêm thì chia đúng phần).
void chiaPhutTheoGio(DateTime tu, DateTime den, List<double> phutTheoGio) {
  var a = tu;
  while (a.isBefore(den)) {
    final hetGio = DateTime(a.year, a.month, a.day, a.hour + 1);
    final b = hetGio.isBefore(den) ? hetGio : den;
    phutTheoGio[a.hour] += b.difference(a).inSeconds / 60;
    a = b;
  }
}

/// Tổng hợp các lượt trong [soNgay] ngày cho [soBan] bàn tính giờ.
TongHopTinhGio tongHopTinhGio(Iterable<LuotChoi> ds, {required int soNgay, required int soBan}) {
  final t = TongHopTinhGio(soNgay, soBan);
  for (final l in ds) {
    t.luot++;
    t.phut += l.phut;
    t.tienGio += l.tienGio;
    t.tienMon += l.tienMon;
    for (final d in l.doan) {
      chiaPhutTheoGio(d.tu, d.den, t.phutTheoGio);
    }
    final ngay = DateTime(l.thanhToanLuc.year, l.thanhToanLuc.month, l.thanhToanLuc.day);
    final cu = t.theoNgay[ngay];
    t.theoNgay[ngay] = (gio: (cu?.gio ?? 0) + l.tienGio, mon: (cu?.mon ?? 0) + l.tienMon);
    final b = t.theoBan.putIfAbsent(l.tableId, TheoBan.new)
      ..luot += 1
      ..phut += l.phut
      ..tienGio += l.tienGio
      ..tienMon += l.tienMon;
    assert(b.luot > 0);
  }
  return t;
}

/// Ghép phiên + dòng đọc từ máy chủ thành lượt chơi.
List<LuotChoi> ghepLuotChoi(List<Map<String, dynamic>> phien, List<Map<String, dynamic>> dong) {
  final theoPhien = <String, List<Map<String, dynamic>>>{};
  for (final d in dong) {
    (theoPhien[d['session_id'] as String] ??= []).add(d);
  }
  DateTime gio(Object? v) => DateTime.parse(v as String).toLocal();
  return [
    for (final p in phien)
      () {
        final ds = theoPhien[p['id'] as String] ?? const [];
        final gioDs = ds.where((d) => d['gio_tu'] != null && d['gio_den'] != null);
        return LuotChoi(
          tableId: '${p['table_id']}',
          thanhToanLuc: gio(p['closed_at']),
          doan: [for (final d in gioDs) DoanGio(gio(d['gio_tu']), gio(d['gio_den']))],
          tienGio: gioDs.fold(0.0, (s, d) => s + ((d['subtotal'] as num?)?.toDouble() ?? 0)),
          tienMon: ds
              .where((d) => d['gio_tu'] == null)
              .fold(0.0, (s, d) => s + ((d['subtotal'] as num?)?.toDouble() ?? 0)),
        );
      }(),
  ];
}

/// Khoảng báo cáo: [tu] (00:00) tới hết ngày [den].
typedef KhoangBaoCao = ({DateTime tu, DateTime den});

int soNgayCua(KhoangBaoCao k) => DateTime(k.den.year, k.den.month, k.den.day).difference(k.tu).inDays + 1;

Future<List<LuotChoi>> docLuotChoi(KhoangBaoCao k) async {
  final storeId = (await StoreAuthService.getStoreInfo())['store_id'];
  if (storeId == null) return const [];
  final sb = Supabase.instance.client;
  final hetNgay = DateTime(k.den.year, k.den.month, k.den.day + 1);
  final phien = await fetchAllPages((a, b) => sb
      .from('ban_sessions')
      .select('id, table_id, closed_at')
      .eq('store_id', storeId)
      .eq('status', 'closed')
      .not('gio_bat_dau', 'is', null)
      .gte('closed_at', k.tu.toUtc().toIso8601String())
      .lt('closed_at', hetNgay.toUtc().toIso8601String())
      .order('id')
      .range(a, b));
  final ids = [for (final p in phien) p['id'] as String];
  final dong = <Map<String, dynamic>>[];
  // shortcut: chia 200 phiên một lần cho URL ngắn; quán rất đông (hàng nghìn lượt / tháng) thì chuyển sang hàm máy chủ.
  for (var i = 0; i < ids.length; i += 200) {
    final phan = ids.sublist(i, i + 200 > ids.length ? ids.length : i + 200);
    dong.addAll(await fetchAllPages((a, b) => sb
        .from('ban_session_items')
        .select('session_id, subtotal, gio_tu, gio_den')
        .eq('store_id', storeId)
        .inFilter('session_id', phan)
        .order('id')
        .range(a, b)));
  }
  return ghepLuotChoi(phien, dong);
}

final luotChoiProvider = FutureProvider.autoDispose.family<List<LuotChoi>, KhoangBaoCao>((ref, k) {
  ref.watch(sessionProvider);
  return docLuotChoi(k);
});

final banBaoCaoTinhGioProvider = FutureProvider.autoDispose<List<BanTableModel>>((ref) async {
  ref.watch(sessionProvider);
  return ref.watch(banRepositoryProvider).getAllTables();
});

// ─────────────────────────────────────────────────────────────────────────────
// MÀN BÁO CÁO
// ─────────────────────────────────────────────────────────────────────────────
const _kNavy = Color(0xFF1C2151);
const _kCream = Color(0xFFFFF8F0);
const _kGold = Color(0xFFE0A400);
const _kTeal = Color(0xFF0D9488);

TextStyle _chu(double size, FontWeight w, [Color? c]) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c ?? _kNavy);

String _gioPhut(double phut) => tinhGioThoiLuongDai(phut.round());

class BaoCaoTinhGioScreen extends ConsumerStatefulWidget {
  /// Ngày "hôm nay" (ảnh mẫu trong test cố định); null = bây giờ.
  final DateTime? homNay;
  const BaoCaoTinhGioScreen({super.key, this.homNay});

  @override
  ConsumerState<BaoCaoTinhGioScreen> createState() => _BaoCaoTinhGioScreenState();
}

class _BaoCaoTinhGioScreenState extends ConsumerState<BaoCaoTinhGioScreen> {
  String _chon = '7';

  KhoangBaoCao get _khoang {
    final n = widget.homNay ?? DateTime.now();
    final hom = DateTime(n.year, n.month, n.day);
    return switch (_chon) {
      'nay' => (tu: hom, den: hom),
      '30' => (tu: hom.subtract(const Duration(days: 29)), den: hom),
      'thang' => (tu: DateTime(hom.year, hom.month), den: hom),
      _ => (tu: hom.subtract(const Duration(days: 6)), den: hom),
    };
  }

  @override
  Widget build(BuildContext context) {
    final k = _khoang;
    final luot = ref.watch(luotChoiProvider(k));
    final ban = ref.watch(banBaoCaoTinhGioProvider).value ?? const <BanTableModel>[];
    final tenBan = {for (final b in ban) b.id: b.label};
    return Scaffold(
      backgroundColor: _kCream,
      appBar: AppBar(
        backgroundColor: _kCream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _kNavy,
        // theme của app đặt biểu tượng thanh trên màu trắng: không ghi lại thì nút quay lại chìm vào nền kem
        iconTheme: const IconThemeData(color: _kNavy),
        title: Text('Báo cáo tính giờ', style: _chu(20, FontWeight.w800)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (ma, nhan) in const [('nay', 'Hôm nay'), ('7', '7 ngày'), ('30', '30 ngày'), ('thang', 'Tháng này')])
                    ChoiceChip(
                      label: Text(nhan, style: _chu(13, FontWeight.w700, _chon == ma ? Colors.white : _kNavy)),
                      selected: _chon == ma,
                      selectedColor: _kNavy,
                      backgroundColor: Colors.white,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _chon = ma),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ...luot.when(
                loading: () => [const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))],
                error: (e, _) => [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text('Chưa tải được báo cáo. Kiểm tra mạng rồi thử lại.', textAlign: TextAlign.center, style: _chu(14, FontWeight.w600)),
                        TextButton(onPressed: () => ref.invalidate(luotChoiProvider(k)), child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                ],
                data: (ds) {
                  final soBanTinhGio = ban.where((b) => b.tinhGio).length;
                  final t = tongHopTinhGio(ds,
                      soNgay: soNgayCua(k), soBan: soBanTinhGio > 0 ? soBanTinhGio : {for (final l in ds) l.tableId}.length);
                  if (t.luot == 0) {
                    return [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('Chưa có lượt chơi nào được thanh toán trong khoảng này.',
                            textAlign: TextAlign.center, style: _chu(14, FontWeight.w600, _kNavy.withValues(alpha: 0.6))),
                      ),
                    ];
                  }
                  return [
                    _oTong(t),
                    const SizedBox(height: 16),
                    _GioDong(t),
                    if (soNgayCua(k) > 1) ...[const SizedBox(height: 16), _TheoNgay(t, k)],
                    const SizedBox(height: 16),
                    _theoBan(t, tenBan, soNgayCua(k)),
                    const SizedBox(height: 12),
                    Text(
                      'Chỉ tính lượt đã thanh toán, theo giờ thanh toán. Tiền là trước giảm giá / phụ thu của hoá đơn.',
                      style: _chu(12, FontWeight.w500, _kNavy.withValues(alpha: 0.55)),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _oTong(TongHopTinhGio t) {
    Widget o(String nhan, String so, {String? phu, Color? mau}) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6DDD0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nhan, style: _chu(12, FontWeight.w700, _kNavy.withValues(alpha: 0.6))),
              const SizedBox(height: 2),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(so, style: _chu(20, FontWeight.w800, mau))),
              if (phu != null) Text(phu, style: _chu(11.5, FontWeight.w600, _kNavy.withValues(alpha: 0.55))),
            ],
          ),
        );
    final cot = MediaQuery.sizeOf(context).width >= 700 ? 4 : 2;
    final o4 = [
      o('Lượt chơi', '${t.luot}', phu: 'TB ${_gioPhut(t.phut / t.luot)} / lượt'),
      o('Giờ chơi', _gioPhut(t.phut)),
      o('Tiền giờ', fmtVnd(t.tienGio), phu: 'TB ${fmtVnd(t.tienGio / t.luot)} / lượt', mau: const Color(0xFFB07A00)),
      o('Món kèm', fmtVnd(t.tienMon), phu: 'tiền giờ ${(t.tiLeTienGio * 100).round()}% tổng', mau: _kTeal),
    ];
    return GridView.count(
      crossAxisCount: cot,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: cot == 4 ? 2.1 : 1.75,
      children: o4,
    );
  }

  Widget _theoBan(TongHopTinhGio t, Map<String, String> tenBan, int soNgay) {
    final ds = t.theoBan.entries.toList()
      ..sort((a, b) {
        final c = b.value.tienGio.compareTo(a.value.tienGio);
        return c != 0 ? c : compareNatural(tenBan[a.key] ?? '', tenBan[b.key] ?? '');
      });
    return _Khung(
      tieuDe: 'Theo bàn',
      child: Column(
        children: [
          for (final e in ds)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tenBan[e.key] ?? 'Bàn đã xoá', style: _chu(14.5, FontWeight.w800)),
                        Text(
                          '${e.value.luot} lượt · ${_gioPhut(e.value.phut)} · TB ${_gioPhut(e.value.phut / soNgay)} / ngày',
                          style: _chu(12, FontWeight.w600, _kNavy.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(fmtVnd(e.value.tienGio), style: _chu(14.5, FontWeight.w800, const Color(0xFFB07A00))),
                      Text('món ${fmtVnd(e.value.tienMon)}', style: _chu(12, FontWeight.w600, _kTeal)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Khung extends StatelessWidget {
  final String tieuDe;
  final String? phu;
  final Widget child;
  const _Khung({required this.tieuDe, this.phu, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6DDD0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tieuDe, style: _chu(15.5, FontWeight.w800)),
            if (phu != null) Text(phu!, style: _chu(12, FontWeight.w500, _kNavy.withValues(alpha: 0.6))),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

/// 24 cột: % bàn tính giờ có khách trung bình trong từng giờ.
class _GioDong extends StatelessWidget {
  final TongHopTinhGio t;
  const _GioDong(this.t);

  @override
  Widget build(BuildContext context) {
    final cao = [for (var h = 0; h < 24; h++) t.tiLeGio(h)];
    final max = cao.reduce((a, b) => a > b ? a : b);
    final dinh = cao.indexOf(max);
    return _Khung(
      tieuDe: 'Giờ đông khách',
      phu: 'Cột cao = nhiều bàn có khách. Đông nhất ${dinh.toString().padLeft(2, '0')}:00–${(dinh + 1).toString().padLeft(2, '0')}:00, '
          'trung bình ${(max * 100).round()}% số bàn.',
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var h = 0; h < 24; h++)
              Expanded(
                child: Semantics(
                  label: '$h giờ: ${(cao[h] * 100).round()}% bàn có khách',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: max <= 0 ? 0 : 92 * cao[h] / max,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: h == dinh ? _kGold : _kNavy.withValues(alpha: 0.75),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 14,
                        child: h % 3 == 0
                            ? FittedBox(child: Text('$h', style: _chu(10, FontWeight.w700, _kNavy.withValues(alpha: 0.6))))
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tiền giờ + món kèm từng ngày (cột chồng).
class _TheoNgay extends StatelessWidget {
  final TongHopTinhGio t;
  final KhoangBaoCao k;
  const _TheoNgay(this.t, this.k);

  @override
  Widget build(BuildContext context) {
    final dau = k.tu, cuoi = DateTime(k.den.year, k.den.month, k.den.day);
    final ds = [for (var d = dau; !d.isAfter(cuoi); d = DateTime(d.year, d.month, d.day + 1)) d];
    final max = ds.map((d) => (t.theoNgay[d]?.gio ?? 0) + (t.theoNgay[d]?.mon ?? 0)).reduce((a, b) => a > b ? a : b);
    final nhan = ds.length <= 10 ? 1 : (ds.length / 6).ceil();
    return _Khung(
      tieuDe: 'Theo ngày',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < ds.length; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: max <= 0 ? 0 : 88 * (t.theoNgay[ds[i]]?.mon ?? 0) / max,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          color: _kTeal,
                        ),
                        Container(
                          height: max <= 0 ? 0 : 88 * (t.theoNgay[ds[i]]?.gio ?? 0) / max,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          color: _kGold,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 14,
                          // cột hẹp (30 ngày): chữ ngày tràn sang hai bên thay vì bị thu nhỏ
                          child: i % nhan == 0
                              ? OverflowBox(
                                  maxWidth: 48,
                                  child: Text('${ds[i].day}/${ds[i].month}',
                                      softWrap: false, style: _chu(10, FontWeight.w700, _kNavy.withValues(alpha: 0.6))),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(width: 10, height: 10, color: _kGold),
              const SizedBox(width: 4),
              Text('Tiền giờ', style: _chu(12, FontWeight.w600)),
              const SizedBox(width: 12),
              Container(width: 10, height: 10, color: _kTeal),
              const SizedBox(width: 4),
              Text('Món kèm', style: _chu(12, FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
