// Giá theo khung giờ + làm tròn block (đợt 1 lộ trình tính giờ, .docs/ke-hoach-gia-gio-khung-block.md).
// CHÉP ĐÚNG TỪNG BƯỚC hàm máy chủ qn_tinh_gio_tinh_tien_v2 (migration 20261128_gia_gio_khung_block.sql):
// số tạm tính trên app phải bằng số máy chủ chốt lúc thanh toán. Bộ ca kiểm dùng chung:
// supabase/tests/gia_gio_khung_block_test.sql ↔ test/modules/tinh_gio/gia_gio_khung_test.dart;
// ngày lễ (đợt 6): supabase/tests/gia_gio_ngay_le_test.sql ↔ test/modules/tinh_gio/gia_gio_ngay_le_test.dart.

/// Thứ 8 trong [KhungGia.thu] = Ngày lễ (đợt 6, migration 20261128_gia_gio_ngay_le.sql).
const kThuNgayLe = 8;

/// Ngày dạng số yyyymmdd (khoá tập ngày lễ, không lệch giờ).
int soNgay(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Một khung giá của bàn. [thu]: 1 = Thứ Hai … 7 = Chủ nhật, 8 = Ngày lễ; theo ngày khung BẮT ĐẦU.
/// [tuPhut], [denPhut]: phút trong ngày (0–1439), giờ Việt Nam; đến < từ = qua đêm; từ = đến = cả ngày.
class KhungGia {
  final Set<int> thu;
  final int tuPhut;
  final int denPhut;
  final double gia;
  const KhungGia({required this.thu, required this.tuPhut, required this.denPhut, required this.gia});

  bool get caNgay => tuPhut == denPhut;
  bool get quaDem => tuPhut > denPhut;
  bool get coNgayLe => thu.contains(kThuNgayLe);

  /// Giờ [luc] thuộc khung khi ngày bắt đầu khung (hôm nay, hoặc hôm qua với phần qua đêm) hợp [nay] / [truoc].
  bool _khop(DateTime luc, bool nay, bool truoc) {
    final s = luc.hour * 3600000000 + luc.minute * 60000000 + luc.second * 1000000 + luc.millisecond * 1000 + luc.microsecond;
    final tu = tuPhut * 60000000, den = denPhut * 60000000;
    if (tu == den) return nay;
    if (tu < den) return nay && s >= tu && s < den;
    return (nay && s >= tu) || (truoc && s < den);
  }

  /// Thời điểm [luc] (giờ máy, coi là giờ Việt Nam) có thuộc khung theo THỨ không (bỏ qua ngày lễ).
  bool chua(DateTime luc) {
    final d = luc.weekday; // Dart: Thứ Hai = 1 … Chủ nhật = 7, giống isodow của Postgres
    return _khop(luc, thu.contains(d), thu.contains(d == 1 ? 7 : d - 1));
  }

  /// Khung Lễ có chứa [luc] không, với [ngayLe] là tập [soNgay] các ngày lễ của quán.
  bool chuaNgayLe(DateTime luc, Set<int> ngayLe) {
    if (!coNgayLe || ngayLe.isEmpty) return false;
    final homNay = DateTime(luc.year, luc.month, luc.day);
    return _khop(luc, ngayLe.contains(soNgay(homNay)),
        ngayLe.contains(soNgay(DateTime(homNay.year, homNay.month, homNay.day - 1))));
  }

  /// "17:00 – 23:00", "22:00 – 02:00 (qua đêm)", "Cả ngày".
  String get gioChu => caNgay ? 'Cả ngày' : '${gioPhutChu(tuPhut)} – ${gioPhutChu(denPhut)}';

  /// "T2–T6", "T7, CN", "Mọi ngày".
  String get thuChu => thuChuCua(thu);

  Map<String, dynamic> toJson() => {
        'thu': (thu.toList()..sort()),
        'tu': gioPhutChu(tuPhut),
        'den': gioPhutChu(denPhut),
        'gia': gia.round(),
      };

  /// Dòng của bảng ban_gia_gio_khung ("tu", "den" dạng "17:00:00").
  static KhungGia? tuDong(Map<String, dynamic> m) {
    int? phut(Object? v) {
      final p = '$v'.split(':');
      if (p.length < 2) return null;
      final h = int.tryParse(p[0]), mi = int.tryParse(p[1]);
      return h == null || mi == null ? null : h * 60 + mi;
    }

    final tu = phut(m['tu']), den = phut(m['den']);
    final thu = (m['thu'] as List?)?.map((e) => (e as num).toInt()).toSet();
    final gia = (m['gia'] as num?)?.toDouble();
    if (tu == null || den == null || thu == null || thu.isEmpty || gia == null) return null;
    return KhungGia(thu: thu, tuPhut: tu, denPhut: den, gia: gia);
  }
}

/// Một gói giờ của bàn (bảng ban_goi_gio, đợt 7): chơi [soPhut] phút giá [gia]; lố tính thêm theo giá giờ.
class GoiGio {
  final String? id;
  final int soPhut;
  final double gia;
  const GoiGio({this.id, required this.soPhut, required this.gia});

  /// "Gói 2 giờ".
  String get ten => 'Gói ${thoiLuongChu(soPhut)}';

  Map<String, dynamic> toJson() => {'so_phut': soPhut, 'gia': gia.round()};

  static GoiGio? tuDong(Map<String, dynamic> m) {
    final p = (m['so_phut'] as num?)?.toInt(), g = (m['gia'] as num?)?.toDouble();
    if (p == null || g == null) return null;
    return GoiGio(id: m['id'] as String?, soPhut: p, gia: g);
  }
}

/// "45 phút", "2 giờ", "1 giờ 30 phút" (như qn_tinh_gio_thoi_luong_v1 ở máy chủ).
String thoiLuongChu(int p) => p < 60
    ? '$p phút'
    : p % 60 == 0
        ? '${p ~/ 60} giờ'
        : '${p ~/ 60} giờ ${p % 60} phút';

/// Một ngày lễ của quán (bảng ban_ngay_le).
class NgayLe {
  final DateTime ngay;
  final String ten;
  const NgayLe(this.ngay, this.ten);
}

String gioPhutChu(int phut) => '${(phut ~/ 60).toString().padLeft(2, '0')}:${(phut % 60).toString().padLeft(2, '0')}';

String thuChuCua(Set<int> thu) {
  const ten = {1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7', 7: 'CN'};
  final ds = thu.where((d) => d != kThuNgayLe).toList()..sort();
  final le = thu.contains(kThuNgayLe);
  if (ds.isEmpty) return le ? 'Ngày lễ' : '';
  final chu = ds.length == 7
      ? 'Mọi ngày'
      // dãy liền nhau từ 3 ngày: "T2–T6"
      : ds.length >= 3 && ds.last - ds.first == ds.length - 1
          ? '${ten[ds.first]}–${ten[ds.last]}'
          : ds.map((d) => ten[d]).join(', ');
  return le ? '$chu, ngày lễ' : chu;
}

/// Các block được phép (khớp ràng buộc ban_gia_gio_block ở máy chủ).
const kBlockPhut = [1, 5, 10, 15, 20, 30, 60];

/// Cài đặt giá giờ của một bàn. Mặc định = tính theo phút, một giá (như trước đợt 1).
class GiaGioCaiDat {
  final int block;
  final int toiThieu;
  final int anHan;
  /// Theo thứ tự: khung đứng trên thắng khi chồng nhau (vào ngày lễ, khung Lễ thắng trước).
  final List<KhungGia> khung;
  /// Ngày lễ CỦA QUÁN ([soNgay]), dùng chung mọi bàn; không phải cài đặt của bàn (không so trong [trung]).
  final Set<int> ngayLe;
  /// Gói giờ của bàn (đợt 7), lưu riêng (ban_goi_gio_luu_v1): không tính trong [laMacDinh] / [trung], so bằng [goiTrung].
  final List<GoiGio> goi;
  const GiaGioCaiDat({
    this.block = 1,
    this.toiThieu = 0,
    this.anHan = 0,
    this.khung = const [],
    this.ngayLe = const {},
    this.goi = const [],
  });

  bool goiTrung(GiaGioCaiDat o) =>
      goi.length == o.goi.length &&
      [for (var i = 0; i < goi.length; i++) '${goi[i].toJson()}' == '${o.goi[i].toJson()}'].every((x) => x);

  static const macDinh = GiaGioCaiDat();

  bool get laMacDinh => block == 1 && toiThieu == 0 && anHan == 0 && khung.isEmpty;

  /// Cùng nội dung (để biết Chủ quán có đổi gì không trước khi gọi máy chủ).
  bool trung(GiaGioCaiDat o) =>
      block == o.block &&
      toiThieu == o.toiThieu &&
      anHan == o.anHan &&
      khung.length == o.khung.length &&
      [for (var i = 0; i < khung.length; i++) '${khung[i].toJson()}' == '${o.khung[i].toJson()}'].every((x) => x);

  GiaGioCaiDat copyWith(
          {int? block, int? toiThieu, int? anHan, List<KhungGia>? khung, Set<int>? ngayLe, List<GoiGio>? goi}) =>
      GiaGioCaiDat(
        block: block ?? this.block,
        toiThieu: toiThieu ?? this.toiThieu,
        anHan: anHan ?? this.anHan,
        khung: khung ?? this.khung,
        ngayLe: ngayLe ?? this.ngayLe,
        goi: goi ?? this.goi,
      );
}

/// Đoạn liền nhau cùng giá.
class DoanGia {
  final DateTime tu;
  final int phut;
  final double gia;
  const DoanGia(this.tu, this.phut, this.gia);
}

class TienGio {
  final int soPhutChoi;
  final int soPhutTinh;
  final double thanhTien;
  final List<DoanGia> doan;
  const TienGio(this.soPhutChoi, this.soPhutTinh, this.thanhTien, this.doan);
}

/// Bước 1: làm tròn số phút. Quá bội số block không quá ân hạn thì giữ bội số đó (chỉ khi đã đủ ít nhất
/// một block), còn lại lên block kế; rồi lấy tối đa với tối thiểu.
int tinhGioLamTron(int phutChoi, GiaGioCaiDat c) {
  final choi = phutChoi < 1 ? 1 : phutChoi;
  final b = c.block < 1 ? 1 : c.block;
  final q = choi ~/ b, r = choi % b;
  final tinh = r == 0
      ? choi
      : q > 0 && r <= c.anHan
          ? q * b
          : (q + 1) * b;
  return tinh < c.toiThieu ? c.toiThieu : tinh;
}

/// Giá một giờ tại thời điểm [luc]: khung đang áp ([tinhGioKhungLuc]), không thì giá gốc.
double tinhGioGiaLuc(DateTime luc, double giaGoc, GiaGioCaiDat c) =>
    tinhGioKhungLuc(luc, c)?.gia ?? (giaGoc < 0 ? 0 : giaGoc);

/// Khung đang áp lúc [luc] (null = giá gốc). Ngày lễ: khung Lễ đầu tiên chứa [luc] thắng; không có thì như
/// ngày thường — khung đầu tiên chứa [luc] theo thứ.
KhungGia? tinhGioKhungLuc(DateTime luc, GiaGioCaiDat c) {
  if (c.ngayLe.isNotEmpty) {
    for (final k in c.khung) {
      if (k.chuaNgayLe(luc, c.ngayLe)) return k;
    }
  }
  for (final k in c.khung) {
    if (k.chua(luc)) return k;
  }
  return null;
}

/// Lần đổi giá kế tiếp trong [trongPhut] phút tới tính từ [luc] (null = không đổi, hoặc bàn không có khung).
({DateTime luc, double gia})? tinhGioDoiGiaKe(DateTime luc, double giaGoc, GiaGioCaiDat c, {int trongPhut = 120}) {
  if (c.khung.isEmpty) return null;
  final nay = tinhGioGiaLuc(luc, giaGoc, c);
  final dau = DateTime(luc.year, luc.month, luc.day, luc.hour, luc.minute);
  for (var i = 1; i <= trongPhut; i++) {
    final t = dau.add(Duration(minutes: i));
    final g = tinhGioGiaLuc(t, giaGoc, c);
    if (g != nay) return (luc: t, gia: g);
  }
  return null;
}

/// Tiền giờ cho lượt bắt đầu [vao], chơi [phutChoi] phút (đã gồm phần kéo tới hết khung đặt trước).
/// Tính bằng số nguyên (phần trăm đồng) để khớp máy chủ (numeric) từng đồng. Chép qn_tinh_gio_tinh_tien_v3:
/// có gói ([goiPhut] > 0) thì về sớm vẫn tính đủ gói, tiền = [goiGia] + phần lố theo giá giờ; [doan] chỉ gồm phần lố.
TienGio tinhGioTien({
  required DateTime vao,
  required int phutChoi,
  required double giaGoc,
  GiaGioCaiDat caiDat = GiaGioCaiDat.macDinh,
  int? goiPhut,
  double? goiGia,
}) {
  final choi = phutChoi < 1 ? 1 : phutChoi;
  final goi = goiPhut == null || goiPhut < 0 ? 0 : goiPhut;
  final giaGoi = goi > 0 ? ((goiGia ?? 0) < 0 ? 0.0 : (goiGia ?? 0)) : 0.0;
  // Phần gói còn lại sau chuyển bàn (giá 0) thay cho "chơi tối thiểu" của bàn mới (28/11, như máy chủ).
  final lamTron = tinhGioLamTron(choi, goi > 0 && (goiGia ?? 0) == 0 ? caiDat.copyWith(toiThieu: 0) : caiDat);
  final tinh = lamTron > goi ? lamTron : goi;
  final goc = giaGoc < 0 ? 0.0 : giaGoc;
  final doan = <DoanGia>[];
  var tongXu = 0;
  if (caiDat.khung.isEmpty) {
    if (tinh > goi) doan.add(DoanGia(vao.add(Duration(minutes: goi)), tinh - goi, goc));
    tongXu = (tinh - goi) * (goc * 100).round();
  } else {
    DateTime? dTu;
    var dPhut = 0;
    double dGia = 0;
    for (var i = goi; i < tinh; i++) {
      final luc = vao.add(Duration(minutes: i));
      final gia = tinhGioGiaLuc(luc, goc, caiDat);
      if (dPhut > 0 && gia == dGia) {
        dPhut++;
      } else {
        if (dPhut > 0) doan.add(DoanGia(dTu!, dPhut, dGia));
        dTu = luc;
        dPhut = 1;
        dGia = gia;
      }
      tongXu += (gia * 100).round();
    }
    if (dPhut > 0) doan.add(DoanGia(dTu!, dPhut, dGia));
  }
  return TienGio(choi, tinh, giaGoi + tienTuTongXu(tongXu), doan);
}

/// ceil(Σ giá theo phút / 60 / 1000) × 1000, với Σ tính bằng phần trăm đồng.
double tienTuTongXu(int tongXu) {
  const moiNghin = 60 * 1000 * 100;
  if (tongXu <= 0) return 0;
  return ((tongXu + moiNghin - 1) ~/ moiNghin) * 1000.0;
}
