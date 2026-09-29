import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readapp/ui/mimi_reading.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  late ReadingVideoPlatform platform;
  setUp(() {
    platform = ReadingVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  Widget scene({bool reduce = false, bool enabled = true}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: TickerMode(enabled: enabled, child: const MiMiReading()),
    ),
  );
  VideoPlayerController controller(WidgetTester tester) =>
      tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;

  testWidgets('bundled clip loops silently and survives ordinary rebuilds', (
    tester,
  ) async {
    await tester.pumpWidget(scene());
    await tester.pump();
    expect(find.byType(VideoPlayer), findsOneWidget);
    final video = controller(tester);
    expect(video.dataSourceType, DataSourceType.asset);
    expect(video.value.duration, const Duration(seconds: 5));
    expect(video.value.isLooping, isTrue);
    expect(video.value.volume, 0);
    expect(video.value.isPlaying, isTrue);
    await video.seekTo(const Duration(seconds: 2));
    await tester.pumpWidget(scene());
    expect(controller(tester), same(video));
    expect(video.value.position, const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(platform.disposed, [1]);
  });

  testWidgets('reduced motion shows still artwork without loading video', (
    tester,
  ) async {
    await tester.pumpWidget(scene(reduce: true));
    await tester.pump(const Duration(seconds: 6));
    expect(find.byType(VideoPlayer), findsNothing);
    expect(platform.created, 0);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('motion preference and hidden tickers pause existing playback', (
    tester,
  ) async {
    await tester.pumpWidget(scene());
    await tester.pump();
    final video = controller(tester);
    final surface = tester.state(find.byType(VideoPlayer));
    for (final options in [(true, true), (false, false)]) {
      await tester.pumpWidget(scene(reduce: options.$1, enabled: options.$2));
      await tester.pump();
      expect(video.value.isPlaying, isFalse);
      expect(tester.state(find.byType(VideoPlayer)), same(surface));
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(scene());
      await tester.pump();
      expect(video.value.isPlaying, isTrue);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('initialization finishing while hidden never starts playback', (
    tester,
  ) async {
    platform.delayInitialization = true;
    await tester.pumpWidget(scene());
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    platform.initialize();
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(platform.playCalls, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller(tester).value.isPlaying, isTrue);
    final video = controller(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(video.value.isPlaying, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('covered Home pauses and resumes after returning', (
    tester,
  ) async {
    await tester.pumpWidget(scene());
    await tester.pump();
    final video = controller(tester);
    Navigator.of(tester.element(find.byType(MiMiReading))).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Next')),
      ),
    );
    await tester.pumpAndSettle();
    expect(video.value.isPlaying, isFalse);
    Navigator.of(tester.element(find.text('Next'))).pop();
    await tester.pumpAndSettle();
    expect(video.value.isPlaying, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('decoder failure falls back to the original kitten', (
    tester,
  ) async {
    await tester.pumpWidget(scene());
    await tester.pump();
    platform.events.addError(
      PlatformException(code: 'VideoError', message: 'Unable to decode video'),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(VideoPlayer), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('leaving before initialization releases the player safely', (
    tester,
  ) async {
    platform.delayInitialization = true;
    await tester.pumpWidget(scene());
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    platform.initialize();
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(platform.disposed, [1]);
    expect(platform.playCalls, 0);
    expect(tester.takeException(), isNull);
  });
}

// Only the native decoder is replaced; widget and controller behavior are real.
class ReadingVideoPlatform extends VideoPlayerPlatform {
  late final StreamController<VideoEvent> events;
  bool delayInitialization = false;
  int created = 0;
  int playCalls = 0;
  final disposed = <int>[];
  Duration position = Duration.zero;
  void initialize() => events.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 5),
      size: const Size(972, 834),
    ),
  );
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    created++;
    events = StreamController<VideoEvent>();
    if (!delayInitialization) initialize();
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;
  @override
  Future<void> dispose(int playerId) async => disposed.add(playerId);
  @override
  Future<void> play(int playerId) async => playCalls++;
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> seekTo(int playerId, Duration value) async => position = value;
  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Widget buildView(int playerId) => const SizedBox();
}
