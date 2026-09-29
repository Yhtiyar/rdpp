import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/features/listening/narration_player.dart';

class ControlledPlayer extends Fake implements AudioPlayer {
  final events = StreamController<AudioEvent>.broadcast(sync: true);
  final preparation = Completer<void>();
  bool held = false, released = false;
  double? rate;
  @override
  Stream<AudioEvent> get eventStream => events.stream;
  @override
  Stream<Duration> get onDurationChanged => events.stream
      .where((e) => e.eventType == AudioEventType.duration)
      .map((e) => e.duration!);
  @override
  Stream<void> get onPlayerComplete =>
      events.stream.where((e) => e.eventType == AudioEventType.complete);
  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();
  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {}
  @override
  Future<void> setSource(Source source) async {
    if (held) await preparation.future;
  }

  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> setPlaybackRate(double playbackRate) async {
    rate = playbackRate;
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    if (held) await preparation.future;
  }

  @override
  Future<void> dispose() async {
    released = true;
  }
}

void main() {
  Future<void> flush() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> start(NarrationPlayer p, void Function(Object) error) => p.start(
    'assets/test.mp3',
    position: Duration.zero,
    onPosition: (_) {},
    onDuration: (_) {},
    onComplete: () {},
    onError: error,
  );
  test(
    'preserves the reviewed voice speed instead of slowing every model',
    () async {
      for (final rate in [.85, 1.0]) {
        final native = ControlledPlayer();
        final player = AssetNarrationPlayer(
          createPlayer: () => native,
          playbackRate: rate,
        );
        await start(player, (error) => fail('$error'));
        expect(native.rate, rate);
        await player.stop();
        player.dispose();
        await native.events.close();
      }
    },
  );
  test(
    'stop releases a player while source preparation is still pending',
    () async {
      final native = ControlledPlayer()..held = true;
      final player = AssetNarrationPlayer(createPlayer: () => native);
      final pending = start(player, (_) {});
      await flush();
      final stop = player.stop();
      await flush();
      expect(native.released, isTrue);
      native.preparation.complete();
      await pending;
      await stop;
      player.dispose();
      await native.events.close();
    },
  );
  test(
    'platform errors are delivered once and never escape derived streams',
    () async {
      final native = ControlledPlayer();
      final errors = <Object>[];
      final player = AssetNarrationPlayer(createPlayer: () => native);
      await start(player, errors.add);
      native.events.addError(StateError('decode failed'));
      await flush();
      expect(errors, hasLength(1));
      await player.stop();
      player.dispose();
      await native.events.close();
    },
  );
}
