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
                if (canhBaoThoiTiet(v) case final cb?) ...[
                  const SizedBox(height: 12),
                  _DaiCanhBao(cb),
                ],
                const SizedBox(height: 20),
                if (v.gio.isNotEmpty) ...[
                  const _TieuDe('Các giờ tới'),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: v.gio.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _OGio(v.gio[i]),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (v.ngay.isNotEmpty) ...[
                  const _TieuDe('Các ngày tới'),
                  _CacNgay(v.ngay),
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

/// Dải cảnh báo dưới phần "bây giờ": mưa thì gợi ý chuẩn bị chỗ ngồi, đồ mang đi; nắng nóng thì đồ uống lạnh, đá.
class _DaiCanhBao extends StatelessWidget {
  final ({String ngan, String dai, bool mua}) cb;
  const _DaiCanhBao(this.cb);
  @override
  Widget build(BuildContext context) {
    final mau = cb.mua ? _kMua : _kCam;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cb.mua ? const Color(0xFFE6EEFC) : const Color(0xFFFFEEDF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mau.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            cb.mua ? Icons.water_drop_rounded : Icons.wb_sunny_rounded,
            color: mau,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cb.dai,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: mau,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cb.mua
                      ? 'Chuẩn bị mái che, khăn lau sàn chống trơn, túi đựng đồ mang đi; nhập hàng tươi vừa đủ.'
                      : 'Chuẩn bị thêm đá, đồ uống lạnh; để ý chỗ ngồi có bóng mát.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.35,
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

const _kMua = Color(0xFF2F6FDE);
const _kNguongMua = 30;

class _TieuDe extends StatelessWidget {
  final String chu;
  const _TieuDe(this.chu);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      chu,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
        color: _kNavy,
      ),
    ),
  );
}

class _HienTai extends StatelessWidget {
  final ThoiTietData v;
  const _HienTai(this.v);
  @override
  Widget build(BuildContext context) {
    final mua = v.muaSapToi;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(iconTroi(v.troi), size: 48, color: _kCam),
          const SizedBox(width: 14),
          Text(
            _do(v.nhiet),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: _kNavy,
              height: 1,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.troi.isEmpty ? 'Bây giờ' : v.troi,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _kNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mua != null
                      ? 'Có thể mưa khoảng ${mua.gio}h (${mua.mua}%)'
                      : 'Vài giờ tới khả năng mưa thấp',
                  style: TextStyle(
                    fontSize: 13,
                    color: mua != null ? _kMua : Colors.black54,
                    fontWeight: mua != null ? FontWeight.w700 : FontWeight.w400,
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

class _OGio extends StatelessWidget {
  final GioThoiTiet h;
  const _OGio(this.h);
  @override
  Widget build(BuildContext context) {
    final mua = (h.mua ?? 0) >= _kNguongMua;
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: mua ? const Color(0xFFE6EEFC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: mua ? const Color(0xFF9DB8F2) : const Color(0x14000000),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${h.gio}h',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          Icon(
            mua ? Icons.water_drop_rounded : iconTroi(h.troi),
            size: 20,
            color: mua ? _kMua : _kNavy,
          ),
          Text(
            _do(h.nhiet),
            style: const TextStyle(fontWeight: FontWeight.w800, color: _kNavy),
          ),
          Text(
            h.mua == null ? '' : '${h.mua}%',
            style: TextStyle(
              fontSize: 11,
              color: mua ? _kMua : Colors.black45,
              fontWeight: mua ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mỗi ngày: thứ, thanh khả năng mưa (đậm dần theo %), thanh nhiệt độ đặt trên thang thấp nhất – cao nhất của cả tuần.
class _CacNgay extends StatelessWidget {
  final List<NgayThoiTiet> ds;
  const _CacNgay(this.ds);
  @override
  Widget build(BuildContext context) {
    final thap = ds.map((d) => d.thap).whereType<double>(),
        cao = ds.map((d) => d.cao).whereType<double>();
    final lo = thap.isEmpty ? 0.0 : thap.reduce((a, b) => a < b ? a : b),
        hi = cao.isEmpty ? 1.0 : cao.reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (var i = 0; i < ds.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0x11000000)),
            _DongNgay(ds[i], lo, hi, homNay: i == 0),
          ],
        ],
      ),
    );
  }
}

class _DongNgay extends StatelessWidget {
  final NgayThoiTiet d;
  final double lo, hi;
  final bool homNay;
  const _DongNgay(this.d, this.lo, this.hi, {this.homNay = false});
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
            width: 58,
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
            size: 20,
            color: p >= _kNguongMua ? mau : _kNavy,
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
        ],
      ),
    );
  }
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
