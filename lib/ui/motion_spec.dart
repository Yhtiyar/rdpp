import 'package:flutter/material.dart';

/// One motion policy for optional presentation, never business state.
class MotionSpec {
  const MotionSpec({required this.reduceMotion});
  factory MotionSpec.of(BuildContext context) =>
      MotionSpec(reduceMotion: MediaQuery.disableAnimationsOf(context));
  final bool reduceMotion;
  Duration _duration(int ms) => Duration(milliseconds: reduceMotion ? 0 : ms);
  Duration get press => _duration(90);
  Duration get selection => _duration(140);
  Duration get transition => _duration(220);
  Duration get reaction => _duration(550);
  Duration get reward => _duration(1100);
}
