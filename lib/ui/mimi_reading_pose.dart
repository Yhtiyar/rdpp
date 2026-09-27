import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// All parts share this five-second timeline; the page cannot outrun the paw.
class ReadingPose {
  ReadingPose.at(double phase) {
    final t = phase % 1;
    breath = math.sin(t * math.pi * 2);
    final attention = _smooth(.27, .46, t) * (1 - _smooth(.7, .9, t));
    headAngle = .012 * math.sin(t * math.pi * 2) - .095 * attention;
    headDrop = 1.1 * breath + 6.5 * attention;
    gaze = .4 + 2.2 * attention;
    tailAngle = .035 * math.sin(t * math.pi * 2);
    support = Offset(-.5 * breath, -.8 * breath - .8 * attention);
    blink = _blink(t, .17) + _blink(t, .81);
    pageVisible = t >= .44 && t < .72;
    page = _smooth(.44, .72, t);
    if (!pageVisible) page = 0;
    holdingPage = t >= .44 && t <= .53;

    const rest = Offset(234, 259);
    final grip = _grip(0);
    final release = _grip(_smooth(.44, .72, .53));
    if (t < .30 || t >= .84) {
      paw = rest;
      pawAngle = 0;
    } else if (t < .44) {
      final reach = _smooth(.30, .44, t);
      pawAngle = -.22 * reach;
      paw =
          Offset.lerp(rest, grip, reach)! +
          Offset(9 * math.sin(reach * math.pi), 0);
    } else if (t <= .53) {
      pawAngle = -.22;
      paw = _grip(page);
    } else if (t < .60) {
      final follow = _smooth(.53, .60, t);
      pawAngle = -.22 - .08 * follow;
      paw = Offset.lerp(release, release + const Offset(-6, 6), follow)!;
    } else {
      final settle = _smooth(.60, .84, t);
      pawAngle = -.30 * (1 - settle);
      paw =
          Offset.lerp(release + const Offset(-6, 6), rest, settle)! +
          Offset(12 * math.sin(settle * math.pi), 0);
    }
  }

  late final double breath, headAngle, headDrop, gaze, tailAngle, blink;
  late final Offset support, paw;
  late final double pawAngle;
  late double page;
  late final bool pageVisible, holdingPage;

  Offset get pageTip => tipAt(page);
  Offset get fingertip => paw + rotate(const Offset(-11, -15), pawAngle);

  static Offset _grip(double page) =>
      tipAt(page) - rotate(const Offset(-11, -15), -.22);

  static Offset tipAt(double page) {
    final angle = page * math.pi;
    final spread = math.cos(angle);
    return Offset(
      129 + (spread >= 0 ? 94 : 63) * spread,
      220 - (spread >= 0 ? 18 : 30) * spread.abs() - 37 * math.sin(angle),
    );
  }

  static Offset rotate(Offset point, double angle) => Offset(
    point.dx * math.cos(angle) - point.dy * math.sin(angle),
    point.dx * math.sin(angle) + point.dy * math.cos(angle),
  );

  static double _smooth(double start, double end, double t) {
    final v = ((t - start) / (end - start)).clamp(0.0, 1.0);
    return v * v * (3 - 2 * v);
  }

  static double _blink(double t, double center) {
    // Quick close, a brief closed lid, and a slower reopening.
    return _smooth(center - .027, center - .004, t) *
        (1 - _smooth(center + .004, center + .044, t));
  }
}
