// lib/core/widgets/net_status_banner.dart
// Dải "Đang mất mạng" phủ trên mọi màn (gắn ở MaterialApp.builder).
// Thử Sunmi Bò Đen 23/11/2026: mất mạng app vẫn hiện 0 đ, thực đơn trống, "Sẵn sàng"
// như thể quán chưa có gì — không chỗ nào nói là đang mất mạng.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/net_status.dart';

class NetStatusBanner extends StatelessWidget {
  const NetStatusBanner({super.key, required this.child});

  final Widget child;

  static const text = 'Đang mất mạng. Số liệu có thể thiếu.'; // vừa một dòng trên Sunmi 360dp

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NetStatus.offline,
      child: child,
      builder: (context, offline, child) {
        // Cây widget giữ nguyên hình dạng khi bật / tắt dải: đổi hình dạng là mọi màn bên dưới
        // bị dựng lại từ đầu (mất chồng màn đang mở).
        return Column(
          children: [
            if (offline)
              Material(
                color: const Color(0xFFB71C1C),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    MediaQuery.paddingOf(context).top + 6,
                    12,
                    6,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          text,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              // Dải đã chiếm phần thanh trạng thái, màn bên dưới không chừa thêm lần nữa.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: offline,
                child: child!,
              ),
            ),
          ],
        );
      },
    );
  }
}
