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
  bool _visible = true, _reduce = false, _started = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
        TickerMode.of(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (!active) _reaction.value = 1;
    if (active && widget.idle) {
      _idle = Timer(const Duration(seconds: 7), () {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent ?? true)
          _reaction.forward(from: 0);
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
          final blink =
              !_reduce &&
              _reaction.isAnimating &&
              _reaction.value >= .36 &&
              _reaction.value < .65;
          final frame =
              blink &&
                  (widget.mood == MiMiMood.ready ||
                      widget.mood == MiMiMood.proud)
              ? '${widget.mood.name}_blink'
              : widget.mood.name;
          return Image.asset(
            'assets/art/mimi/$frame.webp',
            key: ValueKey(frame),
            gaplessPlayback: true,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) =>
                Image.asset('assets/art/mimi_face.webp'),
          );
        },
      ),
    ),
  );
}
