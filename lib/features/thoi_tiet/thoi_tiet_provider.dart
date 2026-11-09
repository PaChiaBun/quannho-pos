import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/session_provider.dart';
import '../ai_assistant/providers/boom_chat_provider.dart';

/// Thời tiết khu vực quán (07/11/2026, .docs/ke-hoach-boom-bo-nho-thoi-tiet.md, Cách A: chỉ Apple WeatherKit).
/// App không lưu thời tiết; mở app thì hỏi máy chủ, sau đó tối đa 3 tiếng hoặc sang ngày mới mới hỏi lại.
/// Máy chủ đệm theo khu vực nên quán cùng khu dùng chung một lần gọi Apple.

class ViTriThoiTiet {
  final double lat, lon;
  final String ten;
  const ViTriThoiTiet(this.lat, this.lon, this.ten);
}

class GioThoiTiet {
  final int gio;
  final double? nhiet;
  final int? mua;
  final String troi;

  /// Ngày của giờ này (chỉ có ở danh sách giờ cả tuần).
  final DateTime? ngay;
  const GioThoiTiet(this.gio, this.nhiet, this.mua, this.troi, {this.ngay});
}

class NgayThoiTiet {
  final DateTime ngay;
  final double? cao, thap;
  final int? mua;
  final String troi;
  const NgayThoiTiet(this.ngay, this.cao, this.thap, this.mua, this.troi);
}

class ThoiTietData {
  /// false: máy chủ chưa có khoá Apple → ẩn hẳn thẻ.
  final bool bat;
  final ViTriThoiTiet? viTri;
  final double? nhiet;
  final String troi;
  final List<GioThoiTiet> gio;
  final List<NgayThoiTiet> ngay;

  /// Mọi giờ tới hết ngày thứ 7 (09/11, để bấm xem từng ngày). Máy chủ cũ không gửi → rỗng.
  final List<GioThoiTiet> gioTuan;
  final String nguonTen, nguonLink;
  final String? logoSang, logoToi;
  final DateTime? luc;

  const ThoiTietData({
    required this.bat,
    this.viTri,
    this.nhiet,
    this.troi = '',
    this.gio = const [],
    this.ngay = const [],
    this.gioTuan = const [],
    this.nguonTen = 'Apple Weather',
    this.nguonLink =
        'https://developer.apple.com/weatherkit/data-source-attribution/',
    this.logoSang,
    this.logoToi,
    this.luc,
  });

  /// Các giờ của một ngày; máy chủ cũ chỉ có 12 giờ tới thì hôm nay dùng tạm danh sách đó.
  List<GioThoiTiet> gioCuaNgay(DateTime d) {
    final ds = gioTuan
        .where(
          (h) =>
              h.ngay != null &&
              h.ngay!.year == d.year &&
              h.ngay!.month == d.month &&
              h.ngay!.day == d.day,
        )
        .toList();
    if (ds.isNotEmpty || ngay.isEmpty || !_cungNgay(ngay.first.ngay, d)) {
      return ds;
    }
    return gio;
  }

  static bool _cungNgay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get coSo => nhiet != null || gio.isNotEmpty || ngay.isNotEmpty;

  /// Giờ sắp tới đầu tiên có khả năng mưa từ 40% (để thẻ nói "mưa ~16h").
  GioThoiTiet? get muaSapToi {
    for (final h in gio) {
      if ((h.mua ?? 0) >= 40) return h;
    }
    return null;
  }

  static double? _so(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
  static int? _nguyen(Object? v) => v is num && v.isFinite ? v.round() : null;
  static String _chu(Object? v) => v is String ? v : '';

  /// Đọc phòng thủ: trường nào sai kiểu thì bỏ, không làm vỡ Trang chủ.
  factory ThoiTietData.fromJson(Map<String, dynamic> j) {
    final vt = j['vi_tri'];
    final w = j['thoi_tiet'];
    final n = j['nguon'];
    final ViTriThoiTiet? viTri =
        vt is Map && _so(vt['lat']) != null && _so(vt['lon']) != null
        ? ViTriThoiTiet(_so(vt['lat'])!, _so(vt['lon'])!, _chu(vt['ten']))
        : null;
    final gio = <GioThoiTiet>[];
    final ngay = <NgayThoiTiet>[];
    final gioTuan = <GioThoiTiet>[];
    if (w is Map) {
      for (final h
          in (w['gio_tuan'] is List ? w['gio_tuan'] as List : const [])) {
        final t = h is Map ? DateTime.tryParse(_chu(h['ngay'])) : null;
        if (t != null && h['gio'] is num) {
          gioTuan.add(
            GioThoiTiet(
              (h['gio'] as num).toInt(),
              _so(h['nhiet']),
              _nguyen(h['mua']),
              _chu(h['troi']),
              ngay: t,
            ),
          );
        }
      }
      for (final h in (w['gio'] is List ? w['gio'] as List : const [])) {
        if (h is Map && h['gio'] is num)
          gio.add(
            GioThoiTiet(
              (h['gio'] as num).toInt(),
              _so(h['nhiet']),
              _nguyen(h['mua']),
              _chu(h['troi']),
            ),
          );
      }
      for (final d in (w['ngay'] is List ? w['ngay'] as List : const [])) {
        final t = d is Map ? DateTime.tryParse(_chu(d['ngay'])) : null;
        if (t != null)
          ngay.add(
            NgayThoiTiet(
              t,
              _so(d['cao']),
              _so(d['thap']),
              _nguyen(d['mua']),
              _chu(d['troi']),
            ),
          );
      }
    }
    return ThoiTietData(
      bat: j['bat'] == true,
      viTri: viTri,
      nhiet: w is Map ? _so(w['nhiet']) : null,
      troi: w is Map ? _chu(w['troi']) : '',
      gio: gio,
      ngay: ngay,
      gioTuan: gioTuan,
      nguonTen: n is Map && _chu(n['ten']).isNotEmpty
          ? _chu(n['ten'])
          : 'Apple Weather',
      nguonLink: n is Map && _chu(n['link']).startsWith('https://')
          ? _chu(n['link'])
          : 'https://developer.apple.com/weatherkit/data-source-attribution/',
      logoSang: n is Map && _chu(n['logo_sang']).startsWith('https://')
          ? _chu(n['logo_sang'])
          : null,
      logoToi: n is Map && _chu(n['logo_toi']).startsWith('https://')
          ? _chu(n['logo_toi'])
          : null,
      luc: w is Map ? DateTime.tryParse(_chu(w['luc']))?.toLocal() : null,
    );
  }
}

/// Đã cũ chưa: quá 3 tiếng, hoặc đã sang ngày khác.
bool thoiTietDaCu(DateTime luc, DateTime now) =>
    now.difference(luc) >= const Duration(hours: 3) ||
    now.year != luc.year ||
    now.month != luc.month ||
    now.day != luc.day;

class ThoiTietNotifier extends AsyncNotifier<ThoiTietData?> {
  Timer? _kiem;
  DateTime? _lay;

  @override
  Future<ThoiTietData?> build() async {
    final storeId = ref.watch(sessionProvider.select((s) => s?.storeId));
    final ai = ref.watch(boomAiServiceProvider);
    _kiem?.cancel();
    // app vẫn mở: cứ 15 phút xem đã cũ chưa; chỉ gọi máy chủ khi đã cũ
    _kiem = Timer.periodic(const Duration(minutes: 15), (_) {
      final lay = _lay;
      if (lay != null && thoiTietDaCu(lay, DateTime.now()))
        ref.invalidateSelf();
    });
    ref.onDispose(() => _kiem?.cancel());
    if (storeId == null || storeId.isEmpty || ai == null) return null;
    final j = await ai.thoiTiet(storeId);
    _lay = DateTime.now();
    return j == null ? null : ThoiTietData.fromJson(j);
  }

  /// Sau khi đổi khu vực.
  void lamMoi() => ref.invalidateSelf();
}

final thoiTietProvider = AsyncNotifierProvider<ThoiTietNotifier, ThoiTietData?>(
  ThoiTietNotifier.new,
);
