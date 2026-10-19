import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Dòng nhỏ "Phiên bản x.y.z (build N)" để nhân viên/chủ quán báo đúng bản đang dùng.
class AppVersionLabel extends StatelessWidget {
  final Color color;
  final TextAlign textAlign;
  const AppVersionLabel({
    super.key,
    this.color = Colors.white38,
    this.textAlign = TextAlign.center,
  });

  static Future<String> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'Phiên bản ${info.version} (build ${info.buildNumber})';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _load(),
    builder: (context, snap) {
      final text = snap.data ?? '';
      if (text.isEmpty) return const SizedBox.shrink();
      return Text(
        text,
        textAlign: textAlign,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      );
    },
  );
}
