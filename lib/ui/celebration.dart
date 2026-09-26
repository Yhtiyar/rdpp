import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';
import 'motion_spec.dart';

class Celebration extends StatefulWidget {
  const Celebration({super.key, required this.child});
  final Widget child;
  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _started = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionSpec.of(context).reduceMotion ||
        !TickerMode.valuesOf(context).enabled) {
      _animation.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _animation.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _animation.value = 1;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (!MotionSpec.of(context).reduceMotion)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) =>
                  CustomPaint(painter: _Confetti(_animation.value)),
            ),
          ),
        ),
    ],
  );
}

class _Confetti extends CustomPainter {
  _Confetti(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    for (var i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final speed = .4 + random.nextDouble() * .6;
      final y = -30 + progress * size.height * speed;
      final paint = Paint()
        ..color = [
          WinTheme.purple,
          const Color(0xFFFFC940),
          const Color(0xFF69D7C7),
          const Color(0xFFF592C7),
        ][i % 4].withValues(alpha: 1 - progress);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * pi * 4 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -6, 6, 12),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Confetti oldDelegate) => progress != oldDelegate.progress;
}
