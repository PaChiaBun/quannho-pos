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
  });

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
        .order('gio_tu');
    return rows.map(DatTruoc.fromMap).toList();
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

  /// [trangThai]: 'huy' hoặc 'khong_den'.
  Future<Map<String, dynamic>> doiTrangThai(String id, String trangThai) =>
      _rpc('ban_dat_truoc_doi_trang_thai_v1', {'p_id': id, 'p_trang_thai': trangThai});

  /// Khách đến: gắn lượt đặt với phiên bàn đang mở của đúng bàn đã đặt.
  Future<Map<String, dynamic>> nhan(String id, String sessionId) =>
      _rpc('ban_dat_truoc_nhan_v1', {'p_id': id, 'p_session_id': sessionId});

  Future<Map<String, dynamic>> daNhac(String id) => _rpc('ban_dat_truoc_da_nhac_v1', {'p_id': id});
}

final datTruocRepositoryProvider = Provider<DatTruocRepository>((ref) => DatTruocRepository());

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
