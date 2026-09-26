import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

enum FeedbackCue { correct, retry, batchComplete, milestone, timeReady }

/// One optional voice for accepted outcomes; a newer cue replaces the old one.
class SoundService with WidgetsBindingObserver {
  SoundService({this.playback}) {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _visible = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }
  static final instance = SoundService();
  final Future<void> Function(String asset)? playback;
  AudioPlayer? _player;
  bool _visible = true;
  int _generation = 0;
  Future<void> playCue(FeedbackCue cue, {required bool enabled}) async {
    if (!enabled || !_visible) return;
    final generation = ++_generation;
    final asset = 'sounds/${cue.name}.wav';
    try {
      if (playback != null) {
        await playback!(asset);
        return;
      }
      final player = _player ??= AudioPlayer();
      await player.stop();
      if (generation != _generation || !_visible) return;
      await player.play(AssetSource(asset), volume: .42);
    } catch (_) {
      // Reading and rewards remain usable when the browser blocks audio.
    }
  }

  Future<void> silence() async {
    _generation++;
    try {
      await _player?.stop();
    } catch (_) {
      /* Optional audio. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    if (!_visible) silence();
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await silence();
    await _player?.dispose();
  }
}
