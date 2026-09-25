import 'package:audioplayers/audioplayers.dart';

class SoundService {
  SoundService._();
  static final instance = SoundService._();
  final AudioPlayer _player = AudioPlayer();
  Future<void> play(String name, {required bool enabled}) async {
    if (!enabled) {
      return;
    }
    try {
      await _player.play(AssetSource('sounds/$name.wav'), volume: .5);
    } catch (_) {
      /* Audio is optional; a muted/browser-blocked device still works. */
    }
  }
}
