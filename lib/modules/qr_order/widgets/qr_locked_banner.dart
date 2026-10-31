import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/qr_order_providers.dart';

/// Dải cảnh báo đỏ cho nhân viên khi kênh QR bị tạm khoá vì có người quét phá liên tục.
/// Chạm để mở màn "Mã QR gọi món" và tạo mã mới.
class QrLockedBanner extends ConsumerWidget {
  const QrLockedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(qrLockedChannelsProvider).asData?.value ?? const [];
    if (locked.isEmpty) return const SizedBox.shrink();
    final names = locked.map((c) => c.isTableShared ? 'Tại bàn' : 'Mang đi').join(' + ');
    return Material(
      color: const Color(0xFFB71C1C),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/qr_order'),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                const Icon(Icons.gpp_maybe_rounded, color: Colors.white, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Có người đang cố tình quét mã QR gọi món để phá quán',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Kênh $names đã tạm khoá. Đề nghị chủ quán tạo và in mã QR mới.',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Xử lý',
                    style: TextStyle(
                      color: Color(0xFFB71C1C),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
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
