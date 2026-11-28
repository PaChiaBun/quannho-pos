// Đặt trước (đặt sân / bàn / phòng hẹn giờ) — dữ liệu, luật thuần và kho đọc ghi.
// Máy chủ: supabase/migrations/20261124_ban_dat_truoc_v1.sql. App chỉ ĐỌC bảng ban_dat_truoc,
// mọi thay đổi đi qua 4 hàm máy chủ (máy chủ kiểm quyền và kiểm trùng giờ).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/session_provider.dart';
import '../../core/services/store_auth_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/paged_query.dart' show watchByRefetch;

/// Nhắc quán gọi khách trước giờ đặt bao lâu.
const kNhacTruocGioDat = Duration(minutes: 30);

class DatTruoc {
  final String id;
  final String tableId;
  final String tenKhach;
  final String? sdt;
  final DateTime gioTu;
  final DateTime gioDen;
  final String? ghiChu;
  final double tienCoc;

  /// 'da_dat' (chờ khách) | 'da_nhan' (khách đã đến) | 'huy' | 'khong_den'
  final String trangThai;
  final String? sessionId;
  final DateTime? nhacLuc;
  final String? nhacBoi;
  final String? nguoiTaoTen;
  final DateTime createdAt;
  /// Mã lịch cố định (đặt lặp hàng tuần, đợt 3); null = lượt lẻ.
  final String? chuoiId;
  /// Đợt 4: khách hàng của lượt đặt và tiền cọc trong ví khách.
  final String? customerId;
  /// null (không cọc) | 'da_thu' (đang trong ví, chờ trừ) | 'da_tru' | 'trong_vi' | 'quan_giu' | 'da_hoan'
  final String? cocTrangThai;
  /// Quỹ nhận cọc: 'cash' | 'bank'.
  final String? cocQuy;

  const DatTruoc({
    required this.id,
    required this.tableId,
    required this.tenKhach,
    required this.gioTu,
    required this.gioDen,
    required this.trangThai,
    required this.createdAt,
    this.sdt,
    this.ghiChu,
    this.tienCoc = 0,
    this.sessionId,
    this.nhacLuc,
    this.nhacBoi,
    this.nguoiTaoTen,
    this.chuoiId,
    this.customerId,
    this.cocTrangThai,
    this.cocQuy,
  });

  /// Cọc đã nhận vào ví khách, chưa trừ / chưa xử lý.
  bool get coCocCho => cocTrangThai == 'da_thu' && tienCoc > 0;

  bool get choKhach => trangThai == 'da_dat';
  bool get conHieuLuc => trangThai == 'da_dat' || trangThai == 'da_nhan';

  static DateTime _gio(dynamic v) => DateTime.parse(v as String).toLocal();

  factory DatTruoc.fromMap(Map<String, dynamic> m) => DatTruoc(
        id: m['id'] as String,
        tableId: m['table_id'] as String? ?? '',
        tenKhach: m['ten_khach'] as String? ?? '',
        sdt: m['sdt'] as String?,
        gioTu: _gio(m['gio_tu']),
        gioDen: _gio(m['gio_den']),
        ghiChu: m['ghi_chu'] as String?,
        tienCoc: (m['tien_coc'] as num?)?.toDouble() ?? 0,
        trangThai: m['trang_thai'] as String? ?? 'da_dat',
        sessionId: m['session_id'] as String?,
        nhacLuc: m['nhac_luc'] != null ? _gio(m['nhac_luc']) : null,
        nhacBoi: m['nhac_boi'] as String?,
        nguoiTaoTen: m['nguoi_tao_ten'] as String?,
        createdAt: m['created_at'] != null ? _gio(m['created_at']) : DateTime.fromMillisecondsSinceEpoch(0),
        chuoiId: m['chuoi_id'] as String?,
        customerId: m['customer_id'] as String?,
        cocTrangThai: m['coc_trang_thai'] as String?,
        cocQuy: m['coc_quy'] as String?,
      );
}

String gioPhut(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Lượt cần hiện hộp nhắc lúc [luc]: còn chờ khách, chưa ai nhắc, còn tối đa 30 phút tới giờ đặt và chưa
/// tới giờ. Lượt được đặt khi đã vào khoảng 30 phút đó thì bỏ (vừa nói chuyện với khách xong).
List<DatTruoc> datTruocCanNhac(Iterable<DatTruoc> ds, DateTime luc) {
  final ra = ds.where((d) {
    if (!d.choKhach || d.nhacLuc != null) return false;
    final mocNhac = d.gioTu.subtract(kNhacTruocGioDat);
    return !luc.isBefore(mocNhac) && luc.isBefore(d.gioTu) && d.createdAt.isBefore(mocNhac);
  }).toList()
    ..sort((a, b) => a.gioTu.compareTo(b.gioTu));
  return ra;
}

/// Lượt đang chờ khách gần nhất của một bàn mà khung giờ chưa hết.
DatTruoc? luotDatKeTiep(Iterable<DatTruoc> ds, String tableId, DateTime luc) {
  DatTruoc? ra;
  for (final d in ds) {
    if (d.tableId != tableId || !d.choKhach || !d.gioDen.isAfter(luc)) continue;
    if (ra == null || d.gioTu.isBefore(ra.gioTu)) ra = d;
  }
  return ra;
}

/// Giờ hết khung của lượt đặt mà phiên [sessionId] đã nhận, khi phiên còn ở đúng bàn đã đặt [tableId].
/// Máy chủ tính tiền giờ tới mốc này nếu khách về sớm; app dùng để tạm tính cho khớp.
DateTime? khungDatCuaPhien(Iterable<DatTruoc> ds, String sessionId, String tableId) {
  DateTime? ra;
  for (final d in ds) {
    if (d.trangThai == 'da_nhan' && d.sessionId == sessionId && d.tableId == tableId) {
      if (ra == null || d.gioDen.isAfter(ra)) ra = d.gioDen;
    }
  }
  return ra;
}

/// Lượt còn hiệu lực của [tableId] trùng với khung [tu]–[den] (bỏ qua chính [boQuaId]).
/// Chỉ để báo sớm trên màn hình; máy chủ mới là nơi chặn thật.
DatTruoc? luotDatTrung(Iterable<DatTruoc> ds, String tableId, DateTime tu, DateTime den, {String? boQuaId}) {
  for (final d in ds) {
    if (d.tableId == tableId && d.conHieuLuc && d.id != boQuaId && d.gioTu.isBefore(den) && d.gioDen.isAfter(tu)) {
      return d;
    }
  }
  return null;
}

/// Các buổi của lịch cố định (đợt 3), chép đúng ban_dat_truoc_lap_v1: từ ngày của [tu] tới [denNgay] (tính cả
/// ngày đó), đúng các [thu] (1 = T2 … 7 = CN), cùng giờ đồng hồ của [tu]; bỏ buổi đã kết thúc trước [luc].
List<DateTime> cacBuoiLap(DateTime tu, Set<int> thu, DateTime denNgay, int phut, DateTime luc) {
  final ra = <DateTime>[];
  final cuoi = DateTime(denNgay.year, denNgay.month, denNgay.day);
  for (var d = DateTime(tu.year, tu.month, tu.day); !d.isAfter(cuoi); d = DateTime(d.year, d.month, d.day + 1)) {
    if (!thu.contains(d.weekday)) continue;
    final b = DateTime(d.year, d.month, d.day, tu.hour, tu.minute);
    if (b.add(Duration(minutes: phut)).isAfter(luc)) ra.add(b);
  }
  return ra;
}

class DatTruocRepository {
  SupabaseClient get _sb => Supabase.instance.client;

  Future<String?> _storeId() async => (await StoreAuthService.getStoreInfo())['store_id'];

  Future<List<DatTruoc>> _doc(String storeId, DateTime tu, DateTime den) async {
    final rows = await _sb
        .from('ban_dat_truoc')
        .select()
        .eq('store_id', storeId)
        .lt('gio_tu', den.toUtc().toIso8601String())
        .gt('gio_den', tu.toUtc().toIso8601String())
        .order('gio_tu', ascending: true); // thư viện mặc định GIẢM dần → phải ghi rõ
    return rows.map(DatTruoc.fromMap).toList()..sort((a, b) => a.gioTu.compareTo(b.gioTu));
  }

  /// Các lượt có khung giờ chạm vào khoảng thời gian do [khoang] trả về (gọi lại mỗi lần tải).
  Stream<List<DatTruoc>> watch(({DateTime tu, DateTime den}) Function() khoang) async* {
    final storeId = await _storeId();
    if (storeId == null) {
      yield const [];
      return;
    }
    yield* watchByRefetch(
      table: 'ban_dat_truoc',
      storeId: storeId,
      fetch: () {
        final k = khoang();
        return _doc(storeId, k.tu, k.den);
      },
    );
  }

  Future<Map<String, dynamic>> _rpc(String fn, Map<String, dynamic> params) async {
    final storeId = await _storeId();
    if (storeId == null) {
      return {'success': false, 'error_code': 'NO_STORE', 'message': 'Chưa chọn quán'};
    }
    try {
      final res = await _sb.rpc(fn, params: {...params, 'p_store_id': storeId}).timeout(const Duration(seconds: 15));
      if (res is Map) return Map<String, dynamic>.from(res);
      return {'success': false, 'error_code': 'RPC_ERROR', 'message': 'Máy chủ trả kết quả lạ'};
    } catch (e) {
      AppLogger.warning('dat_truoc', '$fn lỗi: $e');
      final s = '$e';
      return {
        'success': false,
        'error_code': 'RPC_ERROR',
        'message': s.contains('PERMISSION_DENIED')
            ? 'Bạn không có quyền làm việc này'
            : s.contains('PGRST202') || s.contains('Could not find the function')
                ? (fn.contains('lap') || fn.contains('chuoi')
                    ? 'Máy chủ chưa có lịch cố định. Báo chủ app cập nhật máy chủ.'
                    : 'Máy chủ chưa có tiền cọc vào ví khách. Báo chủ app cập nhật máy chủ.')
                : 'Chưa làm được, kiểm tra mạng rồi thử lại',
      };
    }
  }

  Future<Map<String, dynamic>> luu({
    String? id,
    required String tableId,
    required String tenKhach,
    String? sdt,
    required DateTime gioTu,
    required DateTime gioDen,
    String? ghiChu,
    double tienCoc = 0,
  }) =>
      _rpc('ban_dat_truoc_luu_v1', {
        'p_id': id,
        'p_table_id': tableId,
        'p_ten_khach': tenKhach,
        'p_sdt': sdt,
        'p_gio_tu': gioTu.toUtc().toIso8601String(),
        'p_gio_den': gioDen.toUtc().toIso8601String(),
        'p_ghi_chu': ghiChu,
        'p_tien_coc': tienCoc,
      });

  /// Đặt lặp hàng tuần (lịch cố định). Có buổi trùng mà [boQuaTrung] = false: không ghi gì, trả error_code
  /// TRUNG_GIO kèm 'trung' (danh sách buổi) và 'so_buoi_ghi_duoc'.
  Future<Map<String, dynamic>> datLap({
    required String tableId,
    required String tenKhach,
    String? sdt,
    required DateTime gioTu,
    required int phut,
    required Set<int> thu,
    required DateTime denNgay,
    String? ghiChu,
    double tienCoc = 0,
    bool boQuaTrung = false,
  }) =>
      _rpc('ban_dat_truoc_lap_v1', {
        'p_table_id': tableId,
        'p_ten_khach': tenKhach,
        'p_sdt': sdt,
        'p_gio_tu': gioTu.toUtc().toIso8601String(),
        'p_phut': phut,
        'p_thu': (thu.toList()..sort()),
        'p_den_ngay':
            '${denNgay.year}-${denNgay.month.toString().padLeft(2, '0')}-${denNgay.day.toString().padLeft(2, '0')}',
        'p_ghi_chu': ghiChu,
        'p_tien_coc': tienCoc,
        'p_bo_qua_trung': boQuaTrung,
      });

  /// Mọi buổi của lịch cố định [chuoiId] (kể cả đã huỷ), theo giờ.
  Future<List<DatTruoc>> docChuoi(String chuoiId) async {
    final storeId = await _storeId();
    if (storeId == null) return const [];
    final rows = await _sb
        .from('ban_dat_truoc')
        .select()
        .eq('store_id', storeId)
        .eq('chuoi_id', chuoiId)
        .order('gio_tu', ascending: true)
        .timeout(const Duration(seconds: 10));
    return rows.map(DatTruoc.fromMap).toList();
  }

  /// Huỷ các buổi còn chờ khách của lịch cố định [chuoiId] từ [tu] trở đi.
  Future<Map<String, dynamic>> huyChuoi(String chuoiId, DateTime tu) =>
      _rpc('ban_dat_truoc_huy_chuoi_v1', {'p_chuoi_id': chuoiId, 'p_tu': tu.toUtc().toIso8601String()});

  /// [trangThai]: 'huy' hoặc 'khong_den'.
  Future<Map<String, dynamic>> doiTrangThai(String id, String trangThai) =>
      _rpc('ban_dat_truoc_doi_trang_thai_v1', {'p_id': id, 'p_trang_thai': trangThai});

  /// Khách đến: gắn lượt đặt với phiên bàn đang mở của đúng bàn đã đặt.
  Future<Map<String, dynamic>> nhan(String id, String sessionId) =>
      _rpc('ban_dat_truoc_nhan_v1', {'p_id': id, 'p_session_id': sessionId});

  Future<Map<String, dynamic>> daNhac(String id) => _rpc('ban_dat_truoc_da_nhac_v1', {'p_id': id});

  /// Gắn khách hàng cho lượt đặt (cả các buổi còn chờ của lịch cố định).
  Future<Map<String, dynamic>> ganKhach(String id, String? customerId) =>
      _rpc('ban_dat_truoc_gan_khach_v1', {'p_id': id, 'p_customer_id': customerId});

  /// Nhận cọc: cộng ví thật của khách + phiếu thu Thu Chi ngay. [quy]: 'cash' | 'bank'.
  Future<Map<String, dynamic>> nhanCoc(String id, double soTien, String quy, String khoa) => _rpc(
        'ban_dat_truoc_nhan_coc_v1',
        {'p_id': id, 'p_so_tien': soTien, 'p_quy': quy, 'p_idempotency_key': khoa},
      );

  /// Lượt huỷ / không đến có cọc. [cach]: 'trong_vi' | 'quan_giu' | 'hoan' (chỉ Quản lý, phiếu chi quỹ [quy]).
  Future<Map<String, dynamic>> xuLyCoc(String id, String cach, String quy) =>
      _rpc('ban_dat_truoc_xu_ly_coc_v1', {'p_id': id, 'p_cach': cach, 'p_quy': quy});

  /// Cọc chưa trừ của phiên bàn (chép qn_coc_cua_phien_v1): lượt đã nhận vào phiên + cả lịch cố định của nó.
  /// Máy chủ chưa có cột cọc → không có cọc.
  Future<CocCuaPhien?> docCocCuaPhien(String sessionId) async {
    final storeId = await _storeId();
    if (storeId == null) return null;
    final nhan = await _sb
        .from('ban_dat_truoc')
        .select()
        .eq('store_id', storeId)
        .eq('session_id', sessionId)
        .eq('trang_thai', 'da_nhan')
        .timeout(const Duration(seconds: 10));
    final dsNhan = nhan.map(DatTruoc.fromMap).toList();
    if (dsNhan.isEmpty) return null;
    final chuoi = {for (final d in dsNhan) if (d.chuoiId != null) d.chuoiId!};
    final cung = chuoi.isEmpty
        ? const <DatTruoc>[]
        : (await _sb.from('ban_dat_truoc').select().eq('store_id', storeId).inFilter('chuoi_id', chuoi.toList()))
            .map(DatTruoc.fromMap)
            .toList();
    final coc = {for (final d in [...dsNhan, ...cung]) if (d.coCocCho) d.id: d}.values.toList();
    final khachId = (coc.isNotEmpty ? coc : dsNhan).map((d) => d.customerId).whereType<String>().firstOrNull;
    if (khachId == null) return null;
    final k = await _sb
        .from('customers')
        .select('id, name, phone, real_balance')
        .eq('id', khachId)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));
    if (k == null) return null;
    return CocCuaPhien(
      tien: coc.fold<double>(0, (s, d) => s + d.tienCoc),
      customerId: khachId,
      tenKhach: (k['name'] as String?) ?? '',
      sdt: k['phone'] as String?,
      soDuVi: (k['real_balance'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Lượt đặt của một khách (hồ sơ khách), mới nhất trước.
  Future<List<DatTruoc>> docCuaKhach(String customerId) async {
    final storeId = await _storeId();
    if (storeId == null) return const [];
    final rows = await _sb
        .from('ban_dat_truoc')
        .select()
        .eq('store_id', storeId)
        .eq('customer_id', customerId)
        .order('gio_tu', ascending: false)
        .limit(30)
        .timeout(const Duration(seconds: 10));
    return rows.map(DatTruoc.fromMap).toList();
  }
}

/// Khách của lượt đặt mà phiên bàn đã nhận và tiền cọc còn trong ví (màn thu tiền bàn).
class CocCuaPhien {
  final double tien;
  final String customerId;
  final String tenKhach;
  final String? sdt;
  final double soDuVi;
  const CocCuaPhien({required this.tien, required this.customerId, required this.tenKhach, this.sdt, required this.soDuVi});
}

/// Phần trả bằng ví khi thanh toán bàn (chép settle_ban_session_v6): tối đa tổng, cọc + phần chọn trả thêm,
/// và số dư ví thật.
double tienTraBangVi({required double tong, required double coc, double traThem = 0, required double soDu}) {
  if (tong <= 0) return 0;
  final v = [tong, coc + traThem, soDu < 0 ? 0.0 : soDu].reduce((a, b) => a < b ? a : b);
  return v < 0 ? 0 : v;
}

final datTruocRepositoryProvider = Provider<DatTruocRepository>((ref) => DatTruocRepository());

/// Lượt đặt của một khách hàng (hồ sơ khách).
final luotDatCuaKhachProvider = FutureProvider.autoDispose.family<List<DatTruoc>, String>((ref, customerId) {
  return ref.read(datTruocRepositoryProvider).docCuaKhach(customerId);
});

/// Các buổi của một lịch cố định (hộp lượt đặt ghi "buổi 3/8", hộp huỷ đếm số buổi sẽ huỷ).
final chuoiDatProvider = FutureProvider.autoDispose.family<List<DatTruoc>, String>((ref, chuoiId) {
  return ref.read(datTruocRepositoryProvider).docChuoi(chuoiId);
});

/// Lượt đặt của một ngày (khoá = ngày, giờ 00:00 theo máy).
final datTruocTheoNgayProvider = StreamProvider.autoDispose.family<List<DatTruoc>, DateTime>((ref, ngay) {
  ref.watch(sessionProvider); // đổi quán thì đọc lại
  final dau = DateTime(ngay.year, ngay.month, ngay.day);
  return ref.watch(datTruocRepositoryProvider).watch(() => (tu: dau, den: dau.add(const Duration(days: 1))));
});

/// Lượt đặt quanh hiện tại (6 giờ trước → 36 giờ tới): cho thẻ bàn và hộp nhắc trước 30 phút.
/// Khoảng thời gian tính lại ở mỗi lần tải nên không cũ đi khi app mở qua đêm.
final datTruocGanDayProvider = StreamProvider.autoDispose<List<DatTruoc>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(datTruocRepositoryProvider).watch(() {
    final luc = DateTime.now();
    return (tu: luc.subtract(const Duration(hours: 6)), den: luc.add(const Duration(hours: 36)));
  });
});
