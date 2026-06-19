import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRINTER SETTINGS — Lưu cài đặt máy in vào SharedPreferences
// ─────────────────────────────────────────────────────────────────────────────
class PrinterSettingsService {
  static const _keyIp      = 'printer_ip';
  static const _keyPort    = 'printer_port';
  static const _keyEnabled = 'printer_enabled';

  static const int defaultPort = 9100;

  static Future<PrinterConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PrinterConfig(
      ip:      prefs.getString(_keyIp) ?? '',
      port:    prefs.getInt(_keyPort) ?? defaultPort,
      enabled: prefs.getBool(_keyEnabled) ?? false,
    );
  }

  static Future<void> save(PrinterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIp, config.ip);
    await prefs.setInt(_keyPort, config.port);
    await prefs.setBool(_keyEnabled, config.enabled);
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }
}

class PrinterConfig {
  final String ip;
  final int port;
  final bool enabled;

  const PrinterConfig({
    required this.ip,
    required this.port,
    required this.enabled,
  });

  bool get isConfigured => ip.isNotEmpty;

  PrinterConfig copyWith({String? ip, int? port, bool? enabled}) {
    return PrinterConfig(
      ip:      ip      ?? this.ip,
      port:    port    ?? this.port,
      enabled: enabled ?? this.enabled,
    );
  }
}
