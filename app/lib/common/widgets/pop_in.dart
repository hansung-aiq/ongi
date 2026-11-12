import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_motion.dart';

/// 화면에 들어올 때 작게 시작해 살짝 튕기며 제자리로 온다(저장 완료 로고 등).
/// [ring]이면 뒤에서 따뜻한 원이 한 번 퍼지며 사라진다.
class PopIn extends StatelessWidget {
  const PopIn({
    super.key,
    required this.child,
    this.ring = false,
    this.ringSize = 160,
    this.from = 0.6,
    this.curve = AppMotion.popCurve,
    this.duration = AppMotion.pop,
  });

  final Widget child;
  final bool ring;
  final double ringSize;

  /// 시작 크기
  final double from;
  final Curve curve;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final pop = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: from + (1 - from) * t, child: child),
      ),
      child: child,
    );
    if (!ring) return pop;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppMotion.ring,
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => IgnorePointer(
            child: Opacity(
              opacity: (0.35 * (1 - t)).clamp(0.0, 1.0),
              child: Container(
                width: ringSize * (0.7 + 0.6 * t),
                height: ringSize * (0.7 + 0.6 * t),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ),
        pop,
      ],
    );
  }
}
