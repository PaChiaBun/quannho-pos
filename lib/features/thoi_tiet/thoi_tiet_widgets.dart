import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/app_providers.dart';
import '../ai_assistant/providers/boom_chat_provider.dart';
import '../ai_assistant/screens/boom_chat_screen.dart';
import 'thoi_tiet_provider.dart';

const _kNavy = Color(0xFF1E1B4B);
const _kCam = Color(0xFFF26B21);

IconData iconTroi(String troi) {
  if (troi.contains('dông')) return Icons.thunderstorm_rounded;
  if (troi.contains('mưa')) return Icons.water_drop_rounded;
  if (troi.contains('sương') || troi.contains('mù')) return Icons.foggy;
  if (troi.contains('mây')) return Icons.cloud_rounded;
  if (troi.contains('gió')) return Icons.air_rounded;
  return Icons.wb_sunny_rounded;
}

String _do(double? x) => x == null ? '–' : '${x.round()}°';

/// Cảnh báo ngắn cho thẻ Trang chủ và dải trong màn chi tiết (09/11, Chủ Quán: "hiện cảnh báo trời sắp mưa").
/// Ưu tiên: sắp mưa trong vài giờ (≥ 40%) > hôm nay mưa (≥ 50%) > mai mưa (≥ 60%) > nắng nóng (≥ 35°).
({String ngan, String dai, bool mua})? canhBaoThoiTiet(ThoiTietData v) {
  final h = v.muaSapToi;
  if (h != null)
    return (
      ngan: 'Sắp mưa ~${h.gio}h',
      dai: 'Có thể mưa khoảng ${h.gio}h (khả năng ${h.mua}%)',
      mua: true,
    );
  final nay = v.ngay.isNotEmpty ? v.ngay.first : null,
      mai = v.ngay.length > 1 ? v.ngay[1] : null;
  if ((nay?.mua ?? 0) >= 50)
    return (
      ngan: 'Hôm nay mưa ${nay!.mua}%',
      dai: 'Hôm nay khả năng mưa ${nay.mua}%',
      mua: true,
    );
  if ((mai?.mua ?? 0) >= 60)
    return (
      ngan: 'Mai mưa ${mai!.mua}%',
      dai: 'Ngày mai khả năng mưa ${mai.mua}%',
      mua: true,
    );
  final nong = [
    v.nhiet,
    nay?.cao,
  ].whereType<double>().fold<double>(0, (a, b) => a > b ? a : b);
  if (nong >= 35)
    return (
      ngan: 'Nắng nóng ${nong.round()}°',
      dai: 'Nắng nóng, cao nhất khoảng ${nong.round()}°',
      mua: false,
    );
  return null;
}

/// Thẻ nhỏ cạnh doanh thu trên Trang chủ: một dòng, cao bằng nhãn "Sẵn sàng"; có cảnh báo thì đổi màu.
/// Chưa có khoá Apple, lỗi mạng, chưa có số → ẩn; không bao giờ làm chậm Trang chủ.
class ThoiTietThe extends ConsumerWidget {
  const ThoiTietThe({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(thoiTietProvider).value;
    if (v == null || !v.bat) return const SizedBox.shrink();
    final chuaChon = v.viTri == null;
    if (!chuaChon && !v.coSo) return const SizedBox.shrink();
    final cb = chuaChon ? null : canhBaoThoiTiet(v);
    final nen = cb == null
        ? const Color(0x22FFFFFF)
        : cb.mua
        ? const Color(0x553B82F6)
        : const Color(0x55F26B21);
    final vien = cb == null
        ? const Color(0x33FFFFFF)
        : cb.mua
        ? const Color(0xAA7FB0FF)
        : const Color(0xAAFFA463);
    final icon = chuaChon
        ? Icons.wb_cloudy_outlined
        : cb == null
        ? iconTroi(v.troi)
        : cb.mua
        ? Icons.water_drop_rounded
        : Icons.wb_sunny_rounded;
    final mauIcon = cb == null
        ? Colors.white
        : cb.mua
        ? const Color(0xFFB7D3FF)
        : const Color(0xFFFFC28A);
    // 09/11 Chủ Quán: nằm cùng hàng chip "đơn / khách", dưới "Sẵn sàng", cao bằng chip đó (padding v9, chữ 14/12)
    return Semantics(
      button: true,
      label: chuaChon
          ? 'Thời tiết, chọn khu vực quán'
          : 'Thời tiết ${_do(v.nhiet)}${cb != null ? ', ${cb.dai}' : ', ${v.troi}'}',
      child: Material(
        color: nen,
        shape: StadiumBorder(side: BorderSide(color: vien)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ThoiTietScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: mauIcon, size: 15),
                const SizedBox(width: 6),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: chuaChon ? 'Thời tiết' : _do(v.nhiet),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (chuaChon || cb != null || v.troi.isNotEmpty)
                          TextSpan(
                            text:
                                '  ${chuaChon ? 'Chọn khu vực' : cb?.ngan ?? v.troi}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: cb != null
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: cb != null
                                  ? Colors.white
                                  : const Color(0xCCFFFFFF),
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Màn chi tiết: hiện tại, 12 giờ tới, các ngày tới, nút hỏi Bé Boom, ghi nguồn Apple Weather.
/// 09/11 (xem trên máy ảo): tiêu đề bị cắt, nền tím mặc định lệch màu app, 7 ngày trông giống hệt nhau, giờ mưa không nổi
/// → tiêu đề 2 dòng, nền kem của app, thanh khả năng mưa + thanh nhiệt độ theo thang cả tuần, tô giờ mưa ≥ 30%.
class ThoiTietScreen extends ConsumerWidget {
  const ThoiTietScreen({super.key});

  static const _thu = ['', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final as = ref.watch(thoiTietProvider);
    final v = as.value;
    final ten = v?.viTri?.ten ?? '';
    return Scaffold(
      backgroundColor: _kNen,
      // 09/11 app thật: theme ép chữ tiêu đề trắng → nền kem làm chữ chìm; theo thanh tiêu đề xanh đậm chữ trắng như mọi màn
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thời tiết',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            if (ten.isNotEmpty)
              Text(
                ten,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xCCFFFFFF)),
              ),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFFB27A),
            ),
            onPressed: () => chonKhuVuc(context, ref),
            icon: const Icon(Icons.place_outlined, size: 18),
            label: const Text('Đổi khu vực'),
          ),
        ],
      ),
      body: as.isLoading && v == null
          ? const Center(child: CircularProgressIndicator())
          : v == null || !v.bat
          ? const _Rong('Chưa lấy được thời tiết. Thử lại sau ít phút.')
          : v.viTri == null
          ? _Rong(
              'Chọn khu vực quán để xem thời tiết.',
              nut: () => chonKhuVuc(context, ref),
            )
          : !v.coSo
          ? const _Rong('Chưa có dự báo cho khu vực này.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _HienTai(v),
                const SizedBox(height: 22),
                if (v.gio.isNotEmpty) ...[
                  const _TieuDe('Các giờ tới', Icons.schedule_rounded),
                  _CacGio(v.gio),
                  const SizedBox(height: 22),
                ],
                if (v.ngay.isNotEmpty) ...[
                  const _TieuDe('7 ngày tới', Icons.calendar_month_rounded),
                  _CacNgay(v),
                  const SizedBox(height: 16),
                ],
                _HoiBoom(v),
                const SizedBox(height: 20),
                _GhiNguon(v),
              ],
            ),
    );
  }
}

const _kNen = Color(0xFFF7F4EE);

const _kMua = Color(0xFF2F6FDE);
const _kNguongMua = 30;

class _TieuDe extends StatelessWidget {
  final String chu;
  final IconData icon;
  const _TieuDe(this.chu, this.icon);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 17, color: _kCam),
        const SizedBox(width: 6),
        Text(
          chu,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: _kNavy,
          ),
        ),
      ],
    ),
  );
}

/// 09/11 Chủ Quán "chưa bắt mắt": thẻ đầu nền màu theo tình hình (mưa xanh, nắng nóng cam, thường xanh đậm),
/// nhiệt độ lớn, cao / thấp hôm nay, cảnh báo + việc nên chuẩn bị nằm ngay trong thẻ.
class _HienTai extends StatelessWidget {
  final ThoiTietData v;
  const _HienTai(this.v);
  @override
  Widget build(BuildContext context) {
    final cb = canhBaoThoiTiet(v);
    final nay = v.ngay.isNotEmpty ? v.ngay.first : null;
    final mau = cb == null
        ? const [Color(0xFF3B3896), Color(0xFF1E1B4B)]
        : cb.mua
        ? const [Color(0xFF4A8BF0), Color(0xFF1E3F99)]
        : const [Color(0xFFFFA24C), Color(0xFFE0531A)];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: mau,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: mau.last.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -14,
            child: Icon(
              iconTroi(v.troi),
              size: 150,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BÂY GIỜ',
                  style: TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _do(v.nhiet),
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.troi.isEmpty
                                ? ''
                                : v.troi[0].toUpperCase() + v.troi.substring(1),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (nay != null)
                            Text(
                              'Cao ${_do(nay.cao)} · Thấp ${_do(nay.thap)}${nay.mua == null ? '' : ' · Mưa ${nay.mua}%'}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xD9FFFFFF),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          cb == null
                              ? Icons.check_rounded
                              : cb.mua
                              ? Icons.water_drop_rounded
                              : Icons.wb_sunny_rounded,
                          size: 18,
                          color: mau.last,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cb?.dai ?? 'Vài giờ tới ít khả năng mưa',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              cb == null
                                  ? 'Buôn bán bình thường.'
                                  : cb.mua
                                  ? 'Chuẩn bị mái che, khăn lau sàn chống trơn, túi đựng đồ mang đi; nhập hàng tươi vừa đủ.'
                                  : 'Chuẩn bị thêm đá, đồ uống lạnh; để ý chỗ ngồi có bóng mát.',
                              style: const TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Các giờ trong một khung trắng; giờ mưa ≥ 30% tô xanh, giờ hiện tại ghi "Bây giờ".
class _CacGio extends StatelessWidget {
  final List<GioThoiTiet> ds;
  const _CacGio(this.ds);
  @override
  Widget build(BuildContext context) {
    final bayGio = DateTime.now().hour;
    return Container(
      height: 128,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: ds.length,
        itemBuilder: (_, i) {
          final h = ds[i];
          final mua = (h.mua ?? 0) >= _kNguongMua;
          final dau = h.gio == bayGio;
          return Container(
            width: 58,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: dau
                  ? _kNavy
                  : mua
                  ? const Color(0xFFE6EEFC)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dau ? 'Bây giờ' : '${h.gio}h',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: dau ? FontWeight.w700 : FontWeight.w500,
                    color: dau ? Colors.white : Colors.black54,
                  ),
                ),
                Icon(
                  mua ? Icons.water_drop_rounded : iconTroi(h.troi),
                  size: 22,
                  color: dau
                      ? Colors.white
                      : mua
                      ? _kMua
                      : const Color(0xFFF59E0B),
                ),
                Text(
                  _do(h.nhiet),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: dau ? Colors.white : _kNavy,
                  ),
                ),
                Text(
                  h.mua == null ? '' : '${h.mua}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: mua ? FontWeight.w800 : FontWeight.w500,
                    color: dau
                        ? const Color(0xCCFFFFFF)
                        : mua
                        ? _kMua
                        : Colors.black38,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Mỗi ngày: thứ, thanh khả năng mưa (đậm dần theo %), thanh nhiệt độ đặt trên thang thấp nhất – cao nhất của cả tuần.
class _CacNgay extends StatelessWidget {
  final ThoiTietData v;
  const _CacNgay(this.v);
  @override
  Widget build(BuildContext context) {
    final ds = v.ngay;
    final (lo, hi) = _thang(ds);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < ds.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Color(0x11000000),
              ),
            InkWell(
              // 09/11 Chủ Quán: "sao không xem được các ngày khác" → bấm mở xem theo giờ, như app Thời tiết của Apple
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => ManNgayThoiTiet(v, i))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _DongNgay(
                  ds[i],
                  lo,
                  hi,
                  homNay: i == 0,
                  bayGio: i == 0 ? v.nhiet : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thang nhiệt độ chung của cả tuần cho các thanh cao / thấp.
(double, double) _thang(List<NgayThoiTiet> ds) {
  final thap = ds.map((d) => d.thap).whereType<double>(),
      cao = ds.map((d) => d.cao).whereType<double>();
  return (
    thap.isEmpty ? 0.0 : thap.reduce((a, b) => a < b ? a : b),
    cao.isEmpty ? 1.0 : cao.reduce((a, b) => a > b ? a : b),
  );
}

class _DongNgay extends StatelessWidget {
  final NgayThoiTiet d;
  final double lo, hi;
  final bool homNay;

  /// Nhiệt độ lúc này: chấm trắng trên thanh hôm nay (như Apple).
  final double? bayGio;
  const _DongNgay(this.d, this.lo, this.hi, {this.homNay = false, this.bayGio});
  @override
  Widget build(BuildContext context) {
    final p = d.mua ?? 0;
    final mau = Color.lerp(
      const Color(0xFFB9CDF6),
      _kMua,
      (p / 100).clamp(0.0, 1.0),
    )!;
    final span = (hi - lo) <= 0 ? 1.0 : hi - lo;
    final a = (((d.thap ?? lo) - lo) / span).clamp(0.0, 1.0),
        b = (((d.cao ?? hi) - lo) / span).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homNay ? 'Hôm nay' : ThoiTietScreen._thu[d.ngay.weekday],
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _kNavy,
                  ),
                ),
                Text(
                  '${d.ngay.day}/${d.ngay.month}',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
          Icon(
            p >= _kNguongMua ? Icons.water_drop_rounded : iconTroi(d.troi),
            size: 22,
            color: p >= _kNguongMua ? mau : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 40,
            child: Text(
              d.mua == null ? '' : '$p%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: p >= _kNguongMua ? mau : Colors.black45,
              ),
            ),
          ),
          Text(
            _do(d.thap),
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0x12000000),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Positioned(
                    left: c.maxWidth * a,
                    width: (c.maxWidth * (b - a)).clamp(6.0, c.maxWidth),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB066), _kCam],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  if (bayGio != null)
                    Positioned(
                      left:
                          (c.maxWidth * ((bayGio! - lo) / span).clamp(0, 1) - 5)
                              .clamp(0.0, c.maxWidth - 10),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _kNavy, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _do(d.cao),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _kNavy,
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Colors.black26,
          ),
        ],
      ),
    );
  }
}

/// Câu tóm tắt một ngày cho chủ quán: khung giờ dễ mưa, giờ nóng nhất. Giờ < 6 hoặc > 22 bỏ qua (quán thường đóng).
String tomTatNgay(List<GioThoiTiet> ds) {
  final mo = ds.where((h) => h.gio >= 6 && h.gio <= 22).toList();
  if (mo.isEmpty) return 'Chưa có dự báo theo giờ cho ngày này.';
  final nong = mo
      .where((h) => h.nhiet != null)
      .fold<GioThoiTiet?>(
        null,
        (a, h) => a == null || h.nhiet! > a.nhiet! ? h : a,
      );
  final dinh = mo.reduce((a, b) => (b.mua ?? 0) > (a.mua ?? 0) ? b : a);
  final p = dinh.mua ?? 0;
  // 09/11 số thật: ngày 65% nhưng từng giờ chỉ tới 38% (Apple tính cả ngày cao hơn từng giờ) → vẫn chỉ khung dễ mưa nhất
  final khung = mo
      .where((h) => (h.mua ?? 0) >= (p * 0.6).clamp(20, 40))
      .toList();
  final cau = <String>[];
  if (p < 20) {
    cau.add('Ít khả năng mưa trong giờ buôn bán');
  } else {
    final tu = khung.first.gio, den = khung.last.gio + 1;
    final gio = khung.length == 1 ? 'khoảng ${dinh.gio}h' : '$tu–${den}h';
    cau.add(
      p >= 40
          ? khung.length == 1
                ? 'Dễ mưa $gio ($p%)'
                : 'Dễ mưa $gio, cao nhất $p% lúc ${dinh.gio}h'
          : 'Nếu mưa thường rơi $gio (mỗi giờ tối đa $p%)',
    );
  }
  if (nong != null) cau.add('nóng nhất ${_do(nong.nhiet)} lúc ${nong.gio}h');
  return '${cau.join('; ')}.';
}

/// Xem một ngày theo giờ, học theo app Thời tiết của Apple: dải chọn ngày ở trên, vuốt ngang đổi ngày,
/// câu tóm tắt, biểu đồ nhiệt độ, biểu đồ khả năng mưa, rồi từng giờ.
class ManNgayThoiTiet extends StatefulWidget {
  final ThoiTietData v;
  final int dau;
  const ManNgayThoiTiet(this.v, this.dau, {super.key});
  @override
  State<ManNgayThoiTiet> createState() => _ManNgayThoiTietState();
}

class _ManNgayThoiTietState extends State<ManNgayThoiTiet> {
  late int chon = widget.dau;
  late final PageController trang = PageController(initialPage: widget.dau);

  @override
  void dispose() {
    trang.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = widget.v.ngay;
    return Scaffold(
      backgroundColor: _kNen,
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          widget.v.viTri?.ten.isNotEmpty == true
              ? 'Dự báo · ${widget.v.viTri!.ten}'
              : 'Dự báo theo ngày',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: _kNavy,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
            child: Row(
              children: [
                for (var i = 0; i < ds.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => trang.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                      child: Column(
                        children: [
                          Text(
                            i == 0
                                ? 'Nay'
                                : ThoiTietScreen._thu[ds[i].ngay.weekday],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: i == chon
                                  ? Colors.white
                                  : const Color(0x99FFFFFF),
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: i == chon ? Colors.white : null,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${ds[i].ngay.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: i == chon ? _kNavy : Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            (ds[i].mua ?? 0) >= _kNguongMua
                                ? Icons.water_drop_rounded
                                : iconTroi(ds[i].troi),
                            size: 15,
                            color: (ds[i].mua ?? 0) >= _kNguongMua
                                ? const Color(0xFF8DB6FF)
                                : const Color(0xFFFFC56B),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: trang,
              itemCount: ds.length,
              onPageChanged: (i) => setState(() => chon = i),
              itemBuilder: (_, i) => _TrangNgay(widget.v, i),
            ),
          ),
        ],
      ),
    );
  }
}

/// 09/11 Chủ Quán "chưa trực quan": thẻ màu đầu trang, 4 buổi (sáng / trưa / chiều / tối), một dải giờ
/// gộp nhiệt độ + mưa trên cùng cột (đọc số ngay tại giờ, không phải dò trục như 2 biểu đồ rời).
class _TrangNgay extends StatelessWidget {
  final ThoiTietData v;
  final int i;
  const _TrangNgay(this.v, this.i);

  static const _thuDai = [
    '',
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  @override
  Widget build(BuildContext context) {
    final d = v.ngay[i];
    final gio = v.gioCuaNgay(d.ngay);
    final mua = (d.mua ?? 0) >= 50, nong = (d.cao ?? 0) >= 35;
    final mau = mua
        ? const [Color(0xFF4A8BF0), Color(0xFF1E3F99)]
        : nong
        ? const [Color(0xFFFFA24C), Color(0xFFE0531A)]
        : const [Color(0xFF3B3896), Color(0xFF1E1B4B)];
    final tomTat = tomTatNgay(gio);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: mau,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -14,
                top: -10,
                child: Icon(
                  (d.mua ?? 0) >= _kNguongMua
                      ? Icons.water_drop_rounded
                      : iconTroi(d.troi),
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i == 0 ? 'Hôm nay' : _thuDai[d.ngay.weekday]}, ${d.ngay.day}/${d.ngay.month}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xD9FFFFFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _do(d.cao),
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 44,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          ' / ${_do(d.thap)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xB3FFFFFF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (d.mua != null)
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.water_drop_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Mưa ${d.mua}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            i == 0
                                ? 'Từ giờ tới tối: ${tomTat[0].toLowerCase()}${tomTat.substring(1)}'
                                : tomTat,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (gio.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _TieuDe('Theo buổi', Icons.wb_twilight_rounded),
          _CacBuoi(gio),
          const SizedBox(height: 20),
          const _TieuDe('Từng giờ', Icons.schedule_rounded),
          _DaiGio(gio, homNay: i == 0),
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Vuốt ngang để xem thêm giờ · cột xanh: khả năng mưa',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ),
        ],
      ],
    );
  }
}

/// 4 buổi theo giờ buôn bán. Buổi đã qua (hôm nay) không có giờ → ghi "Đã qua".
class _CacBuoi extends StatelessWidget {
  final List<GioThoiTiet> ds;
  const _CacBuoi(this.ds);

  static const _buoi = [
    ('Sáng', 6, 10),
    ('Trưa', 11, 13),
    ('Chiều', 14, 17),
    ('Tối', 18, 22),
  ];

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (ten, tu, den) in _buoi) ...[
        if (ten != 'Sáng') const SizedBox(width: 8),
        Expanded(
          child: _OBuoi(
            ten,
            '$tu–${den + 1}h',
            ds.where((h) => h.gio >= tu && h.gio <= den).toList(),
          ),
        ),
      ],
    ],
  );
}

class _OBuoi extends StatelessWidget {
  final String ten, khung;
  final List<GioThoiTiet> ds;
  const _OBuoi(this.ten, this.khung, this.ds);
  @override
  Widget build(BuildContext context) {
    final t = ds.map((h) => h.nhiet).whereType<double>().toList();
    final p = ds.fold<int>(0, (a, h) => (h.mua ?? 0) > a ? h.mua! : a);
    final hi = t.isEmpty ? null : t.reduce((a, b) => a > b ? a : b);
    final lo = t.isEmpty ? null : t.reduce((a, b) => a < b ? a : b);
    final mua = p >= _kNguongMua, nong = (hi ?? 0) >= 34;
    final troi = ds.isEmpty ? '' : ds[ds.length ~/ 2].troi;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: ds.isEmpty
            ? const Color(0x08000000)
            : mua
            ? const Color(0xFFE6EEFC)
            : nong
            ? const Color(0xFFFFEEDF)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mua
              ? const Color(0xFF9DB8F2)
              : nong
              ? const Color(0xFFFFC9A3)
              : const Color(0x0F000000),
        ),
      ),
      child: Column(
        children: [
          Text(
            ten,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _kNavy,
              fontSize: 14,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              khung,
              style: const TextStyle(fontSize: 10.5, color: Colors.black45),
            ),
          ),
          const SizedBox(height: 8),
          if (ds.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Đã qua',
                style: TextStyle(fontSize: 12, color: Colors.black38),
              ),
            )
          else ...[
            Icon(
              mua ? Icons.water_drop_rounded : iconTroi(troi),
              size: 26,
              color: mua ? _kMua : const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                lo == hi ? _do(hi) : '${lo?.round()}–${_do(hi)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _kNavy,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Mưa $p%',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: mua ? FontWeight.w800 : FontWeight.w500,
                  color: mua ? _kMua : Colors.black45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dải giờ trượt ngang: mỗi cột 56 điểm ảnh gồm giờ, biểu tượng, nhiệt độ trên đường cong, cột mưa + %.
class _DaiGio extends StatefulWidget {
  final List<GioThoiTiet> ds;
  final bool homNay;
  const _DaiGio(this.ds, {required this.homNay});
  static const cot = 56.0;
  @override
  State<_DaiGio> createState() => _DaiGioState();
}

class _DaiGioState extends State<_DaiGio> {
  // ngày sau: mở ở 6h (quán thường đóng đêm), vẫn vuốt về được 0h
  late final ScrollController cuon = ScrollController(
    initialScrollOffset: widget.homNay
        ? 0
        : widget.ds.indexWhere((h) => h.gio >= 6).clamp(0, 1 << 20) *
              _DaiGio.cot,
  );

  @override
  void dispose() {
    cuon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 222,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: cuon,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CustomPaint(
        size: Size(widget.ds.length * _DaiGio.cot, 222),
        painter: _VeDaiGio(widget.ds, widget.homNay ? DateTime.now().hour : -1),
      ),
    ),
  );
}

class _VeDaiGio extends CustomPainter {
  final List<GioThoiTiet> ds;
  final int bayGio;
  _VeDaiGio(this.ds, this.bayGio);

  void _chu(Canvas c, String t, Offset o, TextStyle st) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: st),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas c, Size s) {
    const w = _DaiGio.cot;
    final n = ds.length;
    double x(int i) => w * i + w / 2;
    // vùng: giờ 18 · biểu tượng 46 · đường nhiệt 84–132 · cột mưa 150–190 · % 204
    const tTren = 88.0, tDuoi = 132.0, mDay = 190.0, mCao = 38.0;
    for (var i = 0; i < n; i++) {
      final h = ds[i];
      final la = h.gio == bayGio;
      if (la) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * i + 3, 6, w - 6, s.height - 12),
            const Radius.circular(14),
          ),
          Paint()..color = const Color(0xFFEDEBFA),
        );
      }
      _chu(
        c,
        la ? 'Bây giờ' : '${h.gio}h',
        Offset(x(i), 20),
        TextStyle(
          fontSize: 12,
          fontWeight: la ? FontWeight.w800 : FontWeight.w500,
          color: la ? _kNavy : Colors.black54,
        ),
      );
      final p = (h.mua ?? 0);
      final ic = p >= _kNguongMua ? Icons.water_drop_rounded : iconTroi(h.troi);
      _chu(
        c,
        String.fromCharCode(ic.codePoint),
        Offset(x(i), 48),
        TextStyle(
          fontSize: 22,
          fontFamily: ic.fontFamily,
          package: ic.fontPackage,
          color: p >= _kNguongMua ? _kMua : const Color(0xFFF59E0B),
        ),
      );
      final q = (p / 100).clamp(0.0, 1.0);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x(i) - 9, mDay - mCao, 18, mCao),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0x0D000000),
      );
      if (q > 0) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x(i) - 9, mDay - mCao * q, 18, mCao * q),
            const Radius.circular(5),
          ),
          Paint()..color = Color.lerp(const Color(0xFFB9CDF6), _kMua, q)!,
        );
      }
      _chu(
        c,
        '$p%',
        Offset(x(i), 205),
        TextStyle(
          fontSize: 11,
          fontWeight: p >= _kNguongMua ? FontWeight.w800 : FontWeight.w500,
          color: p >= _kNguongMua ? _kMua : Colors.black38,
        ),
      );
    }
    final t = ds.map((g) => g.nhiet).whereType<double>().toList();
    if (t.isEmpty) return;
    final lo = t.reduce((a, b) => a < b ? a : b),
        hi = t.reduce((a, b) => a > b ? a : b);
    double y(double v) => hi == lo
        ? (tTren + tDuoi) / 2
        : tDuoi - (tDuoi - tTren) * (v - lo) / (hi - lo);
    final pts = [
      for (var i = 0; i < n; i++)
        if (ds[i].nhiet != null) (i, Offset(x(i), y(ds[i].nhiet!))),
    ];
    final duong = Path()..moveTo(pts.first.$2.dx, pts.first.$2.dy);
    for (var k = 1; k < pts.length; k++) {
      final p0 = pts[k > 1 ? k - 2 : 0].$2, p1 = pts[k - 1].$2, p2 = pts[k].$2;
      final p3 = pts[k + 1 < pts.length ? k + 1 : k].$2;
      final c1 = p1 + (p2 - p0) / 6, c2 = p2 - (p3 - p1) / 6;
      duong.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    c.drawPath(
      duong,
      Paint()
        ..color = _kCam
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    for (final (i, o) in pts) {
      c.drawCircle(o, 3.5, Paint()..color = _kCam);
      _chu(
        c,
        _do(ds[i].nhiet),
        o - const Offset(0, 13),
        const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _kNavy,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_VeDaiGio o) => o.ds != ds || o.bayGio != bayGio;
}

/// Nút hỏi Bé Boom: gửi sẵn câu hỏi theo dự báo rồi mở khung Boom; Boom trả lời bằng dự báo thật và số bán của quán.
class _HoiBoom extends ConsumerWidget {
  final ThoiTietData v;
  const _HoiBoom(this.v);

  static String cauHoi(ThoiTietData v) {
    final mai = v.ngay.length > 1 ? v.ngay[1] : null;
    if (v.muaSapToi != null)
      return 'Chiều nay có thể mưa khoảng ${v.muaSapToi!.gio}h, quán nên chuẩn bị gì?';
    if (mai != null && (mai.mua ?? 0) >= 50)
      return 'Ngày mai khả năng mưa ${mai.mua}%, quán nên chuẩn bị gì?';
    return 'Thời tiết mấy ngày tới thế này, quán nên chuẩn bị gì?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = cauHoi(v);
    return Material(
      color: _kNavy,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ref.read(boomChatProvider.notifier).sendMessage(q);
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => const BoomChatScreen(),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: _kCam),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hỏi Bé Boom',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      q,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rong extends StatelessWidget {
  final String chu;
  final VoidCallback? nut;
  const _Rong(this.chu, {this.nut});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(chu, textAlign: TextAlign.center),
          if (nut != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: nut,
              icon: const Icon(Icons.place_outlined),
              label: const Text('Chọn khu vực'),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Apple yêu cầu nhãn Apple Weather và liên kết tới trang nguồn dữ liệu; kèm câu dự báo có thể không chính xác.
class _GhiNguon extends StatelessWidget {
  final ThoiTietData v;
  const _GhiNguon(this.v);

  @override
  Widget build(BuildContext context) {
    final toi = Theme.of(context).brightness == Brightness.dark;
    final logo = toi ? v.logoToi : v.logoSang;
    final luc = v.luc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (logo != null)
              Image.network(
                logo,
                height: 14,
                errorBuilder: (_, _, _) =>
                    Text(v.nguonTen, style: const TextStyle(fontSize: 12)),
              )
            else
              Text(
                v.nguonTen,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
              ),
              onPressed: () => launchUrl(
                Uri.parse(v.nguonLink),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text(
                'Nguồn dữ liệu',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        Text(
          'Đây là dự báo, có thể không chính xác.${luc == null ? '' : ' Cập nhật lúc ${luc.hour.toString().padLeft(2, '0')}:${luc.minute.toString().padLeft(2, '0')}.'}',
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
      ],
    );
  }
}

/// Toạ độ trung tâm một số thành phố lớn; ai không dùng GPS thì chọn thành phố gần nhất.
const kThanhPhoThoiTiet = <(String, double, double)>[
  ('Hà Nội', 21.03, 105.85),
  ('TP. Hồ Chí Minh', 10.78, 106.70),
  ('Đà Nẵng', 16.05, 108.22),
  ('Hải Phòng', 20.86, 106.68),
  ('Cần Thơ', 10.03, 105.79),
  ('Huế', 16.46, 107.59),
  ('Nha Trang', 12.24, 109.19),
  ('Đà Lạt', 11.94, 108.44),
  ('Vũng Tàu', 10.35, 107.08),
  ('Biên Hòa', 10.95, 106.82),
  ('Thủ Dầu Một', 10.98, 106.65),
  ('Buôn Ma Thuột', 12.67, 108.04),
  ('Quy Nhơn', 13.78, 109.22),
  ('Vinh', 18.68, 105.68),
  ('Hạ Long', 20.95, 107.08),
  ('Long Xuyên', 10.38, 105.44),
];

/// Lưu khu vực vào cài đặt quán (app_settings 'thoi_tiet_vi_tri'). Làm tròn 0,05 độ (khoảng 5 km): không lưu vị trí chính xác.
Future<void> chonKhuVuc(BuildContext context, WidgetRef ref) async {
  final chon = await showModalBottomSheet<(String, double, double)>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.my_location_rounded, color: _kCam),
            title: const Text('Dùng vị trí hiện tại'),
            subtitle: const Text(
              'Chỉ lưu khu vực gần đúng, không lưu vị trí chính xác',
            ),
            onTap: () async {
              final p = await _viTriHienTai(ctx);
              if (p != null && ctx.mounted)
                Navigator.of(ctx).pop(('Vị trí quán', p.latitude, p.longitude));
            },
          ),
          const Divider(),
          for (final t in kThanhPhoThoiTiet)
            ListTile(title: Text(t.$1), onTap: () => Navigator.of(ctx).pop(t)),
        ],
      ),
    ),
  );
  if (chon == null) return;
  double tron(double x) => (x * 20).round() / 20;
  try {
    await ref
        .read(settingsRepositoryProvider)
        .set(
          'thoi_tiet_vi_tri',
          jsonEncode({
            'lat': tron(chon.$2),
            'lon': tron(chon.$3),
            'ten': chon.$1,
          }),
        );
    ref.read(thoiTietProvider.notifier).lamMoi();
  } catch (e) {
    if (kDebugMode) debugPrint('[ThoiTiet] $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa lưu được khu vực. Tài khoản này có thể chưa có quyền, nhờ chủ quán chọn giúp.',
          ),
        ),
      );
    }
  }
}

Future<Position?> _viTriHienTai(BuildContext context) async {
  void bao(String s) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  try {
    if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
      bao('Định vị (GPS) đang tắt. Bật GPS hoặc chọn thành phố.');
      return null;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      bao('Chưa được cấp quyền vị trí. Chọn thành phố gần nhất.');
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 15),
      ),
    );
  } catch (_) {
    bao('Không lấy được vị trí. Chọn thành phố gần nhất.');
    return null;
  }
}
