import 'package:flutter/material.dart';

import 'motion_spec.dart';

enum Illustration { home, book, coin, trophy, lock }

/// Decorative artwork. The surrounding control supplies its accessible label.
class IllustratedIcon extends StatelessWidget {
  const IllustratedIcon(
    this.illustration, {
    super.key,
    this.size = 32,
    this.locked = false,
  });

  final Illustration illustration;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/art/icons/${illustration.name}.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
    if (!locked) return image;

    // Keep future milestones recognizable without presenting them as earned.
    return Opacity(
      opacity: .6,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          .2126,
          .7152,
          .0722,
          0,
          0,
          .2126,
          .7152,
          .0722,
          0,
          0,
          .2126,
          .7152,
          .0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: image,
      ),
    );
  }
}

/// One short spring on selection, respecting the app's reduced-motion policy.
class IllustratedNavigationIcon extends StatelessWidget {
  const IllustratedNavigationIcon(
    this.illustration, {
    super.key,
    required this.selected,
  });

  final Illustration illustration;
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: selected ? 1 : .86,
    duration: MotionSpec.of(context).reaction,
    curve: Curves.easeOutBack,
    child: IllustratedIcon(illustration, size: 40),
  );
}
