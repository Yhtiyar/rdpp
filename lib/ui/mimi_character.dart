import 'dart:async';

import 'package:flutter/material.dart';

import 'motion_spec.dart';

enum MiMiMood { ready, thinking, encouraging, proud, celebrating, calm }

/// Aligned expression frames. Reactions are route-local and purely decorative.
class MiMiCharacter extends StatefulWidget {
  const MiMiCharacter({
    super.key,
    required this.mood,
    required this.size,
    this.reactionId,
    this.idle = false,
  });
  final MiMiMood mood;
  final double size;
  final Object? reactionId;
  final bool idle;
  @override
  State<MiMiCharacter> createState() => _MiMiCharacterState();
}

class _MiMiCharacterState extends State<MiMiCharacter>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _reaction = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  Timer? _idle;
  bool _visible = true, _reduce = false, _started = false, _preloaded = false;
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
    if (!_preloaded) {
      _preloaded = true;
      for (final frame in [
        ...MiMiMood.values.map((m) => m.name),
        'ready_blink',
        'proud_blink',
      ]) {
        unawaited(
          precacheImage(
            AssetImage('assets/art/mimi/$frame.webp'),
            context,
            onError: (error, stack) {},
          ),
        );
      }
    }
    _reduce = MotionSpec.of(context).reduceMotion;
    _configure();
    if (!_started) {
      _started = true;
      if (widget.reactionId != null && !_reduce) _reaction.forward();
    }
  }

  @override
  void didUpdateWidget(MiMiCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reactionId != oldWidget.reactionId &&
        widget.reactionId != null &&
        !_reduce &&
        _visible) {
      _reaction.forward(from: 0);
    }
    _configure();
  }

  void _configure() {
    _idle?.cancel();
    final active =
        _visible &&
        !_reduce &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (!active) _reaction.value = 1;
    if (active && widget.idle) {
      _idle = Timer(const Duration(seconds: 7), () {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent ?? true) {
          _reaction.forward(from: 0);
        }
        _configure();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    _configure();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idle?.cancel();
    _reaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _reaction,
        builder: (context, _) {
          final t = _reaction.value;
          final reacting = !_reduce && _reaction.isAnimating;
          // Expression/paw frames move the character itself; no whole-image bob.
          final frame = !reacting
              ? widget.mood.name
              : switch (widget.mood) {
                  MiMiMood.ready =>
                    t >= .36 && t < .65 ? 'ready_blink' : 'ready',
                  MiMiMood.proud =>
                    t < .20
                        ? 'ready'
                        : t >= .36 && t < .65
                        ? 'proud_blink'
                        : 'proud',
                  MiMiMood.celebrating =>
                    t < .22
                        ? 'proud'
                        : t < .48
                        ? 'proud_blink'
                        : 'celebrating',
                  MiMiMood.encouraging => t < .28 ? 'thinking' : 'encouraging',
                  MiMiMood.calm => t < .28 ? 'encouraging' : 'calm',
                  MiMiMood.thinking => t < .28 ? 'ready' : 'thinking',
                };
          return Image.asset(
            'assets/art/mimi/$frame.webp',
            key: const ValueKey('mimi-frame'),
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, synchronouslyLoaded) =>
                frame != null
                ? child
                : Image.asset('assets/art/mimi_face.webp'),
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) =>
                Image.asset('assets/art/mimi_face.webp'),
          );
        },
      ),
    ),
  );
}
