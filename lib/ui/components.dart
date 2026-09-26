import 'package:flutter/material.dart';

import 'theme.dart';
import 'motion_spec.dart';

class SceneScaffold extends StatelessWidget {
  const SceneScaffold({
    super.key,
    required this.child,
    this.bottom,
    this.scrollController,
    this.title,
    this.onBack,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(22, 12, 22, 24),
  });
  final ScrollController? scrollController;
  final Widget child;
  final Widget? bottom, trailing;
  final String? title;
  final VoidCallback? onBack;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: WinTheme.ink,
                  ),
                Expanded(
                  child: Text(
                    title ?? 'littlewins',
                    textAlign: onBack != null
                        ? TextAlign.center
                        : TextAlign.start,
                    style: TextStyle(
                      fontSize: title == null ? 26 : 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: WinTheme.purple,
                    ),
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onBack != null)
                  const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: padding,
              child: child,
            ),
          ),
          ?bottom,
        ],
      ),
    ),
  );
}

class WinButton extends StatefulWidget {
  const WinButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.secondary = false,
    this.icon = Icons.arrow_forward_rounded,
    this.loading = false,
    this.autofocus = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, loading, autofocus;
  final IconData? icon;
  @override
  State<WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<WinButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onPressed != null && !widget.loading,
    child: AnimatedScale(
      scale: _pressed && !MotionSpec.of(context).reduceMotion ? .97 : 1,
      duration: MotionSpec.of(context).press,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: widget.secondary
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.onPressed == null
                      ? [const Color(0xFFD9CDEC), const Color(0xFFD9CDEC)]
                      : [const Color(0xFF9860FF), const Color(0xFF7037F4)],
                ),
          color: widget.secondary ? WinTheme.lavender : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            autofocus: widget.autofocus,
            onTap: widget.loading ? null : widget.onPressed,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else ...[
                    Flexible(
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: widget.secondary
                              ? WinTheme.purple
                              : Colors.white,
                        ),
                      ),
                    ),
                    if (widget.icon != null) ...[
                      const SizedBox(width: 10),
                      Icon(
                        widget.icon,
                        size: 24,
                        color: widget.secondary
                            ? WinTheme.purple
                            : Colors.white,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class Art extends StatelessWidget {
  const Art(
    this.name, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });
  final String name;
  final double? width, height;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/art/$name.webp',
      width: width,
      height: height,
      fit: fit,
    ),
  );
}

class SoftPanel extends StatelessWidget {
  const SoftPanel({
    super.key,
    required this.child,
    this.color = WinTheme.lavender,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class Heading extends StatelessWidget {
  const Heading(
    this.text, {
    super.key,
    this.large = false,
    this.center = false,
  });
  final String text;
  final bool large, center;
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: center ? TextAlign.center : TextAlign.start,
    style: large
        ? Theme.of(context).textTheme.headlineLarge
        : Theme.of(context).textTheme.headlineMedium,
  );
}

class FloatArt extends StatefulWidget {
  const FloatArt(this.name, {super.key, this.height = 260});
  final String name;
  final double height;
  @override
  State<FloatArt> createState() => _FloatArtState();
}

class _FloatArtState extends State<FloatArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: ColoredBox(
      color: const Color(0xFFF0E7FE),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            0,
            MediaQuery.disableAnimationsOf(context)
                ? 0
                : -3 * Curves.easeInOut.transform(_controller.value),
          ),
          child: child,
        ),
        child: Art(
          widget.name,
          height: widget.height,
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      ),
    ),
  );
}

const gap = SizedBox(height: 16);
const smallGap = SizedBox(height: 8);
