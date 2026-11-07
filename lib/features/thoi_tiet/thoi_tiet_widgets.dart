import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/app_providers.dart';
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

/// Thẻ nhỏ cạnh doanh thu trên Trang chủ. Chưa có khoá Apple, lỗi mạng, chưa có số → ẩn; không bao giờ làm chậm Trang chủ.
class ThoiTietThe extends ConsumerWidget {
  const ThoiTietThe({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(thoiTietProvider).value;
    if (v == null || !v.bat) return const SizedBox.shrink();
    final chuaChon = v.viTri == null;
    if (!chuaChon && !v.coSo) return const SizedBox.shrink();
    final mua = v.muaSapToi;
    final dong2 = chuaChon
        ? 'Chọn khu vực'
        : mua != null
        ? 'Mưa ~${mua.gio}h'
        : v.troi;
    // khoảng cách với nhãn "Sẵn sàng" nằm trong thẻ: thẻ ẩn thì không để lại khoảng trống
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        label: chuaChon
            ? 'Thời tiết, chọn khu vực quán'
            : 'Thời tiết ${_do(v.nhiet)}, $dong2',
        child: Material(
          color: const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ThoiTietScreen())),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      chuaChon
                          ? Icons.wb_cloudy_outlined
                          : iconTroi(mua != null ? 'mưa' : v.troi),
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            chuaChon ? 'Thời tiết' : _do(v.nhiet),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (dong2.isNotEmpty)
                            Text(
                              dong2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Màn chi tiết: hiện tại, 12 giờ tới, các ngày tới, ghi nguồn Apple Weather.
class ThoiTietScreen extends ConsumerWidget {
  const ThoiTietScreen({super.key});

  static const _thu = ['', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final as = ref.watch(thoiTietProvider);
    final v = as.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          v?.viTri?.ten.isNotEmpty == true
              ? 'Thời tiết · ${v!.viTri!.ten}'
              : 'Thời tiết',
        ),
        actions: [
          TextButton.icon(
            onPressed: () => chonKhuVuc(context, ref),
            icon: const Icon(Icons.place_outlined),
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
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Icon(iconTroi(v.troi), size: 44, color: _kCam),
                    const SizedBox(width: 12),
                    Text(
                      _do(v.nhiet),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: _kNavy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(v.troi, style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
                if (v.muaSapToi != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Khả năng mưa khoảng ${v.muaSapToi!.gio}h: ${v.muaSapToi!.mua}%',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 20),
                if (v.gio.isNotEmpty) ...[
                  const Text(
                    'Các giờ tới',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _kNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: v.gio.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final h = v.gio[i];
                        return Container(
                          width: 64,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${h.gio}h',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Icon(iconTroi(h.troi), size: 20, color: _kNavy),
                              Text(
                                _do(h.nhiet),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                h.mua == null ? '' : '${h.mua}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (v.ngay.isNotEmpty) ...[
                  const Text(
                    'Các ngày tới',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _kNavy,
                    ),
                  ),
                  for (final d in v.ngay)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(iconTroi(d.troi), color: _kNavy),
                      title: Text(
                        '${_thu[d.ngay.weekday]} ${d.ngay.day}/${d.ngay.month}${d.troi.isEmpty ? '' : ' · ${d.troi}'}',
                      ),
                      subtitle: d.mua == null
                          ? null
                          : Text('Khả năng mưa ${d.mua}%'),
                      trailing: Text(
                        '${_do(d.thap)} – ${_do(d.cao)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                _GhiNguon(v),
              ],
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
