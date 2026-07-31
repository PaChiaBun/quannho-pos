import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class QrSoundService {
  static final AudioPlayer _player = AudioPlayer();

  /// Haptic + audio chime for STAFF device when a new pending QR order arrives
  static Future<void> playNotificationSound() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();

      try {
        await _player.play(AssetSource('sounds/notification.mp3'));
      } catch (_) {
        await SystemSound.play(SystemSoundType.click);
      }
    } catch (_) {}
  }
}
