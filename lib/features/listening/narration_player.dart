import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

abstract interface class NarrationPlayer {
  Future<void> start(
    String asset, {
    required Duration position,
    required void Function(Duration) onPosition,
    required void Function(Duration) onDuration,
    required void Function() onComplete,
    required void Function(Object) onError,
  });
  Future<void> stop();
  void dispose();
}

/// A fresh player owns each clip. Stop detaches it immediately, independently of
/// source preparation; ownership is checked after every asynchronous operation.
class AssetNarrationPlayer implements NarrationPlayer {
  AssetNarrationPlayer({
    AudioPlayer Function()? createPlayer,
    this.playbackRate = .85,
  }) : _createPlayer = createPlayer ?? AudioPlayer.new;
  final AudioPlayer Function() _createPlayer;
  final double playbackRate;
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> _releasing = Future.value();
  int _generation = 0;
  bool _disposed = false;

  Future<void> _release() {
    final previous = _player;
    _player = null;
    final subscriptions = List<StreamSubscription<dynamic>>.of(_subscriptions);
    _subscriptions.clear();
    // Start disposal now, never queue it behind setSource/resume.
    final release = previous?.dispose() ?? Future<void>.value();
    _releasing = Future.wait<void>([
      _releasing,
      release,
      ...subscriptions.map((s) => s.cancel()),
    ]).then<void>((_) {}).catchError((Object _) {});
    return _releasing;
  }

  @override
  Future<void> start(
    String asset, {
    required Duration position,
    required void Function(Duration) onPosition,
    required void Function(Duration) onDuration,
    required void Function() onComplete,
    required void Function(Object) onError,
  }) async {
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    var failed = false;
    void error(Object value) {
      if (current() && !failed) {
        failed = true;
        onError(value);
      }
    }

    try {
      await _release();
      if (!current()) return;
      final player = _createPlayer();
      _player = player;
      _subscriptions.addAll([
        player.onPositionChanged.listen((value) {
          if (current()) onPosition(value);
        }, onError: error),
        // A single platform subscription avoids propagating the same error
        // through several derived broadcast streams.
        player.eventStream.listen((event) {
          if (!current()) return;
          if (event.eventType == AudioEventType.duration &&
              event.duration != null) {
            onDuration(event.duration!);
          }
          if (event.eventType == AudioEventType.complete) onComplete();
        }, onError: error),
      ]);
      await player.setReleaseMode(ReleaseMode.stop);
      if (!current()) return;
      await player
          .setSource(AssetSource(asset.replaceFirst('assets/', '')))
          .timeout(const Duration(seconds: 20));
      if (!current()) return;
      if (position > Duration.zero) {
        await player.seek(position);
        if (!current()) return;
      }
      // Each edition keeps the pace reviewed for its narrator.
      await player.setPlaybackRate(playbackRate);
      if (!current()) return;
      await player.resume().timeout(const Duration(seconds: 20));
    } catch (value) {
      error(value);
    }
  }

  @override
  Future<void> stop() {
    ++_generation;
    return _release();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
  }
}
