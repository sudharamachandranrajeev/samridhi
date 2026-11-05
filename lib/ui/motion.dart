import 'package:flutter/material.dart';

/// Animation length that honours the OS "reduce motion" setting: zero when
/// the user asked for no animation, otherwise [ms] milliseconds.
Duration motionDuration(BuildContext context, [int ms = 350]) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: ms);

/// A progress bar that glides to its value.
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({
    required this.value,
    this.height = 8,
    this.color,
    super.key,
  });
  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.clamp(0, 1).toDouble()),
    duration: motionDuration(context, 500),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) =>
        LinearProgressIndicator(value: v, minHeight: height, color: color),
  );
}
