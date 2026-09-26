import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion_spec.dart';

/// The welcome illustration, with a quiet page turn every five visible seconds.
/// The page is drawn in the artwork's coordinates so its hinge stays on the book.
class MiMiReading extends StatefulWidget {
  const MiMiReading({super.key});

  @override
  State<MiMiReading> createState() => _MiMiReadingState();
}

class _MiMiReadingState extends State<MiMiReading>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  Timer? _interval;
  bool _visible = true;

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

  void _syncActivity() {
    final active =
        _visible &&
        !MotionSpec.of(context).reduceMotion &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (!active) {
      _interval?.cancel();
      _interval = null;
      _turn.value = 0;
      return;
    }
    // Ordinary locale/progress rebuilds do not postpone the next page turn.
    _interval ??= Timer.periodic(const Duration(seconds: 5), (_) {
      _turn.forward(from: 0);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    _syncActivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _interval?.cancel();
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AspectRatio(
      aspectRatio: 381 / 327,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/art/mimi_reading.webp', fit: BoxFit.fill),
            RepaintBoundary(
              child: AnimatedBuilder(
                key: const ValueKey('reading-page-turn'),
                animation: _turn,
                builder: (context, _) => CustomPaint(
                  painter: _BookPage(
                    Curves.easeInOutCubic.transform(_turn.value),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A curled cream leaf above the book's rim, without moving the kitten or cover.
class _BookPage extends CustomPainter {
  const _BookPage(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    canvas.save();
    canvas.scale(size.width / 381, size.height / 327);
    final angle = progress * math.pi;
    final spread = math.cos(angle);
    final lift = math.sin(angle);
    final right = spread >= 0;
    final opacity = (math.min(progress, 1 - progress) / .09).clamp(0.0, 1.0);
    const hingeFront = Offset(129, 220);
    const hingeBack = Offset(127, 214);
    final outerFront = Offset(
      129 + (right ? 94 : 63) * spread,
      220 - (right ? 18 : 30) * spread.abs() - 39 * lift,
    );
    final outerBack = Offset(
      127 + (right ? 84 : 57) * spread,
      214 - (right ? 20 : 29) * spread.abs() - 58 * lift,
    );
    final curl = Offset(12 * lift, -9 * lift);
    final frontMid = Offset.lerp(hingeFront, outerFront, .55)! + curl;
    final backMid = Offset.lerp(outerBack, hingeBack, .5)! + curl;
    final page = Path()
      ..moveTo(hingeFront.dx, hingeFront.dy)
      ..quadraticBezierTo(
        frontMid.dx,
        frontMid.dy,
        outerFront.dx,
        outerFront.dy,
      )
      ..quadraticBezierTo(
        outerFront.dx + 5 * lift,
        outerBack.dy + 6,
        outerBack.dx,
        outerBack.dy,
      )
      ..quadraticBezierTo(backMid.dx, backMid.dy, hingeBack.dx, hingeBack.dy)
      ..close();
    canvas.drawPath(
      page.shift(Offset(2 * lift, 3 * lift)),
      Paint()
        ..color = const Color(0xFF765039).withValues(alpha: .13 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      page,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFF1B5).withValues(alpha: opacity),
            const Color(0xFFFFFDE9).withValues(alpha: opacity),
            const Color(0xFFF2D78B).withValues(alpha: opacity),
          ],
          stops: const [0, .55, 1],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(page.getBounds()),
    );
    canvas.drawPath(
      page,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = const Color(0xFFE5CE91).withValues(alpha: .7 * opacity),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BookPage oldDelegate) => oldDelegate.progress != progress;
}
