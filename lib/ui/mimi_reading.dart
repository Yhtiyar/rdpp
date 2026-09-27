import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'mimi_reading_painter.dart';
import 'motion_spec.dart';

/// One coordinated reading loop, using the welcome kitten's original artwork.
class MiMiReading extends StatefulWidget {
  const MiMiReading({super.key, this.progress});

  /// A fixed pose for the animation scrubber and visual regression checks.
  /// Home leaves this null and plays the five-second loop.
  final double? progress;

  @override
  State<MiMiReading> createState() => _MiMiReadingState();
}

class _MiMiReadingState extends State<MiMiReading>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  ImageStream? _stream, _blinkStream;
  late final ImageStreamListener _listener = ImageStreamListener(_onImage);
  ui.Image? _artwork, _blinkArtwork;
  late final ImageStreamListener _blinkListener = ImageStreamListener((
    info,
    synchronous,
  ) {
    _blinkArtwork?.dispose();
    _blinkArtwork = info.image.clone();
    info.dispose();
    if (!synchronous && mounted) setState(() {});
  });
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _visible = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void _onImage(ImageInfo info, bool synchronous) {
    _artwork?.dispose();
    _artwork = info.image.clone();
    info.dispose();
    if (!synchronous && mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream == null) {
      _stream = const AssetImage('assets/art/mimi_reading.webp')
          .resolve(createLocalImageConfiguration(context));
      _stream!.addListener(_listener);
      _blinkStream = const AssetImage('assets/art/mimi/ready_blink.webp')
          .resolve(createLocalImageConfiguration(context));
      _blinkStream!.addListener(_blinkListener);
    }
    _syncActivity();
  }

  @override
  void didUpdateWidget(MiMiReading oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncActivity();
  }

  void _syncActivity() {
    final active =
        widget.progress == null &&
        _visible &&
        !MotionSpec.of(context).reduceMotion &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (!active) {
      _cycle.stop();
      // Always use the original relaxed pose when motion is disabled.
      _cycle.value = 0;
    } else if (!_cycle.isAnimating) {
      _cycle.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    _syncActivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stream?.removeListener(_listener);
    _artwork?.dispose();
    _blinkStream?.removeListener(_blinkListener);
    _blinkArtwork?.dispose();
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AspectRatio(
      aspectRatio: 381 / 327,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            key: const ValueKey('reading-cycle'),
            animation: _cycle,
            builder: (context, _) => _artwork == null
                ? Image.asset('assets/art/mimi_reading.webp', fit: BoxFit.fill)
                : CustomPaint(
                    painter: ReadingKittenPainter(
                      _artwork!,
                      widget.progress ?? _cycle.value,
                      blinkArtwork: _blinkArtwork,
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}
