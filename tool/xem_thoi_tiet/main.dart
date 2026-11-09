// Màn XEM THỬ thẻ thời tiết trên máy ảo (09/11/2026) — KHÔNG vào bản phát hành, không cần đăng nhập.
// Dữ liệu: câu trả lời thật của máy chủ (mode thoi_tiet) cho quán Demo lúc 12h51 09/11.
// Chạy: flutter run -t tool/xem_thoi_tiet/main.dart -d emulator-5554
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quannho_pos/features/thoi_tiet/thoi_tiet_provider.dart';
import 'package:quannho_pos/features/thoi_tiet/thoi_tiet_widgets.dart';

const _json = {
  'bat': true,
  'vi_tri': {'lat': 10.8, 'lon': 106.7, 'ten': 'TP. Hồ Chí Minh'},
  'thoi_tiet': {
    'luc': '2026-11-09T05:51:09.291Z',
    'nhiet': 34,
    'troi': 'nhiều mây',
    'gio': [
      {'gio': 12, 'nhiet': 34, 'mua': 2, 'troi': 'mây rải rác'},
      {'gio': 13, 'nhiet': 34, 'mua': 2, 'troi': 'mây rải rác'},
      {'gio': 14, 'nhiet': 34, 'mua': 0, 'troi': 'mây rải rác'},
      {'gio': 15, 'nhiet': 34, 'mua': 6, 'troi': 'mây rải rác'},
      {'gio': 16, 'nhiet': 33, 'mua': 9, 'troi': 'nhiều mây'},
      {'gio': 17, 'nhiet': 31, 'mua': 18, 'troi': 'mưa'},
      {'gio': 18, 'nhiet': 30, 'mua': 0, 'troi': 'mây rải rác'},
      {'gio': 19, 'nhiet': 29, 'mua': 0, 'troi': 'mây rải rác'},
      {'gio': 20, 'nhiet': 28, 'mua': 10, 'troi': 'nhiều mây'},
      {'gio': 21, 'nhiet': 28, 'mua': 0, 'troi': 'nhiều mây'},
      {'gio': 22, 'nhiet': 27, 'mua': 6, 'troi': 'nhiều mây'},
      {'gio': 23, 'nhiet': 27, 'mua': 0, 'troi': 'mây rải rác'},
    ],
    'ngay': [
      {'ngay': '2026-11-09', 'cao': 34, 'thap': 26, 'mua': 46, 'troi': 'mưa'},
      {'ngay': '2026-11-10', 'cao': 34, 'thap': 25, 'mua': 65, 'troi': 'mưa'},
      {'ngay': '2026-11-11', 'cao': 32, 'thap': 25, 'mua': 67, 'troi': 'mưa'},
      {'ngay': '2026-11-12', 'cao': 31, 'thap': 25, 'mua': 71, 'troi': 'mưa'},
      {'ngay': '2026-11-13', 'cao': 31, 'thap': 25, 'mua': 80, 'troi': 'mưa'},
      {'ngay': '2026-11-14', 'cao': 32, 'thap': 25, 'mua': 60, 'troi': 'mưa'},
      {'ngay': '2026-11-15', 'cao': 32, 'thap': 25, 'mua': 66, 'troi': 'mưa'},
    ],
  },
  'nguon': {
    'ten': 'Apple Weather',
    'link': 'https://developer.apple.com/weatherkit/data-source-attribution/',
    'logo_sang': 'https://weatherkit.apple.com/assets/branding/vi/Apple_Weather_blk_vi_2X_090122.png',
    'logo_toi': 'https://weatherkit.apple.com/assets/branding/vi/Apple_Weather_wht_vi_2X_090122.png',
  },
};

class _CoDinh extends ThoiTietNotifier {
  @override
  Future<ThoiTietData?> build() async => ThoiTietData.fromJson(_json);
}

void main() => runApp(ProviderScope(
      overrides: [thoiTietProvider.overrideWith(_CoDinh.new)],
      child: const MaterialApp(debugShowCheckedModeBanner: false, home: _TrangChu()),
    ));

/// Dải tiêu đề Trang chủ dựng lại cho giống thật (màu, chữ, nhãn "Sẵn sàng" như dashboard_screen.dart).
class _TrangChu extends StatelessWidget {
  const _TrangChu();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F4EE),
        body: Column(children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2D2B8A), Color(0xFF1E1C5E), Color(0xFF12103A)]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Quán Nhỏ POS (Demo)', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Thứ 2, 09/11/2026', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('DOANH THU HÔM NAY', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    SizedBox(height: 6),
                    Text('0 đ', style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800, height: 1)),
                  ]),
                ),
                const ThoiTietThe(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0x334CAF50), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x664CAF50))),
                  child: const Row(children: [
                    Icon(Icons.circle, size: 8, color: Color(0xFF81C784)),
                    SizedBox(width: 4),
                    Text('Sẵn sàng', style: TextStyle(color: Color(0xFF81C784), fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ]),
          ),
          const Expanded(child: Center(child: Text('(phần chức năng bên dưới — lược bớt trong màn xem thử)', style: TextStyle(color: Colors.black38)))),
        ]),
      );
}
