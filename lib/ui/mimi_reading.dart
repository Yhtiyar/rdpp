import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'motion_spec.dart';

/// The welcome kitten reading in one silent, five-second character animation.
class MiMiReading extends StatefulWidget {
  const MiMiReading({super.key, this.progress});

  /// A fixed frame for the visual inspection workbench. Home plays the loop.
  final double? progress;

  @override
  State<MiMiReading> createState() => _MiMiReadingState();
}

class _MiMiReadingState extends State<MiMiReading> with WidgetsBindingObserver {
  VideoPlayerController? _video;
  bool _ready = false;
  bool _failed = false;
  bool _visible = true;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _visible = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncActivity();
  }

  @override
  void didUpdateWidget(MiMiReading oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncActivity();
  }

  void _syncActivity() {
    _active =
        _visible &&
        !MotionSpec.of(context).reduceMotion &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (_active && _video == null && !_failed) {
      unawaited(_initialize());
    } else {
      unawaited(_syncPlayback());
    }
  }

  Future<void> _initialize() async {
    final video = VideoPlayerController.asset(
      'assets/art/mimi/reading/reading.mp4',
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        // This widget owns lifecycle changes, including reduced motion.
        allowBackgroundPlayback: true,
      ),
    );
    _video = video;
    video.addListener(_checkError);
    try {
      await video.initialize();
      if (!mounted) return;
      await video.setVolume(0);
      await video.setLooping(true);
      if (!mounted) return;
      setState(() => _ready = true);
      await _syncPlayback();
    } catch (_) {
      _showStill();
    }
  }

  void _checkError() {
    if (_video?.value.hasError ?? false) _showStill();
  }

  void _showStill() {
    if (!mounted || _failed) return;
    setState(() {
      _failed = true;
      _ready = false;
    });
  }

  Future<void> _syncPlayback() async {
    final video = _video;
    if (!_ready || video == null || _failed) return;
    try {
      final progress = widget.progress;
      if (!_active || progress != null) {
        await video.pause();
        if (mounted &&
            _active &&
            progress != null &&
            progress == widget.progress) {
          await video.seekTo(
            Duration(
              microseconds:
                  (video.value.duration.inMicroseconds *
                          progress.clamp(0.0, .999))
                      .round(),
            ),
          );
        }
      } else if (!video.value.isPlaying) {
        await video.play();
      }
    } catch (_) {
      _showStill();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() => _visible = state == AppLifecycleState.resumed);
    _syncActivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _video?.removeListener(_checkError);
    unawaited(_video?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AspectRatio(
      aspectRatio: 381 / 327,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: RepaintBoundary(
          // Keep the surface attached while paused. Removing and recreating a
          // web video element interrupts playback when motion is re-enabled.
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready && !_failed)
                IgnorePointer(
                  child: VideoPlayer(
                    _video!,
                    key: const ValueKey('reading-video'),
                  ),
                ),
              if (!_ready || !_active || _failed)
                Image.asset('assets/art/mimi_reading.webp', fit: BoxFit.fill),
            ],
          ),
        ),
      ),
    ),
  );
}
