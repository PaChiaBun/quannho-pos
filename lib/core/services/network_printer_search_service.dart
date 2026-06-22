import 'dart:async';
import 'dart:io';

class DiscoveredPrinter {
  final String ip;
  final int port;
  final String name;

  const DiscoveredPrinter({
    required this.ip,
    required this.port,
    required this.name,
  });

  @override
  String toString() => '$name ($ip:$port)';
}

class NetworkPrinterSearchService {
  static const int defaultPort = 9100;
  static const Duration connectTimeout = Duration(milliseconds: 350);

  /// Tìm địa chỉ IP IPv4 cục bộ của thiết bị
  static Future<String?> getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        if (interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('en') ||
            interface.name.toLowerCase().contains('eth') ||
            interface.name.toLowerCase().contains('wifi')) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback) {
              return addr.address;
            }
          }
        }
      }
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Quét dải mạng nội bộ (subnet) để tìm các máy in đang mở cổng 9100
  static Stream<DiscoveredPrinter> discoverPrinters({
    int port = defaultPort,
    Function(double progress)? onProgress,
  }) async* {
    final localIp = await getLocalIP();
    if (localIp == null) {
      return;
    }

    final parts = localIp.split('.');
    if (parts.length != 4) return;

    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
    final deviceLastOctet = int.tryParse(parts[3]) ?? 0;

    int scannedCount = 0;
    const totalHosts = 254;

    final List<String> ipsToScan = [];
    for (int i = 1; i <= 254; i++) {
      if (i != deviceLastOctet) {
        ipsToScan.add('$subnet.$i');
      }
    }

    final controller = StreamController<DiscoveredPrinter>();

    // Hàm kiểm tra một IP đơn lẻ với Hard Timeout ở mức Future để chống kẹt socket
    Future<void> checkIp(String ip) async {
      try {
        await Future(() async {
          Socket? socket;
          try {
            socket = await Socket.connect(ip, port, timeout: connectTimeout);
            controller.add(DiscoveredPrinter(
              ip: ip,
              port: port,
              name: 'Máy in IP $ip',
            ));
          } catch (_) {
            // Lỗi kết nối
          } finally {
            try {
              await socket?.close();
              socket?.destroy();
            } catch (_) {}
          }
        }).timeout(const Duration(milliseconds: 400));
      } catch (_) {
        // Hết thời gian Future timeout
      } finally {
        scannedCount++;
        if (onProgress != null) {
          onProgress(scannedCount / totalHosts);
        }
      }
    }

    // Chạy đồng thời với số lượng giới hạn để tránh quá tải socket hệ thống
    const int concurrencyLimit = 30;
    for (int i = 0; i < ipsToScan.length; i += concurrencyLimit) {
      final chunk = ipsToScan.sublist(
        i,
        i + concurrencyLimit > ipsToScan.length
            ? ipsToScan.length
            : i + concurrencyLimit,
      );
      // Đảm bảo mỗi nhóm đều hoàn thành nhanh chóng
      await Future.wait(chunk.map((ip) => checkIp(ip)));
    }

    await controller.close();
    yield* controller.stream;
  }
}
