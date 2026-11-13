import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_motion.dart';
import '../app_spacing.dart';
import 'press_scale.dart';

/// 진한 원형 아이콘 버튼 (녹음 시작·멈춤·재생).
/// [onPressed]가 null이면 비활성으로 보인다. 누르면 진동하고, 아이콘은 돌며 나타난다.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = AppSizes.buttonHeight,
    this.iconSize = 20,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// 지름
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final button = Opacity(
      opacity: onPressed == null ? AppSizes.disabledOpacity : 1,
      child: IconButton(
        onPressed: onPressed == null
            ? null
            : () {
                tapHaptic(strong: true);
                onPressed!();
              },
        tooltip: tooltip,
        iconSize: iconSize,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.bgBase,
          disabledBackgroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.bgBase,
          fixedSize: Size.square(size),
        ),

        /// 아이콘이 바뀌면(마이크 → 멈춤) 살짝 돌며 커져 나타난다
        icon: _MorphIcon(icon: icon),
      ),
    );
    return PressScale(enabled: onPressed != null, child: button);
  }
}

class _MorphIcon extends StatelessWidget {
  const _MorphIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return Icon(icon);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(icon),
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.normal,
      curve: AppMotion.enterCurve,
      builder: (context, t, child) => Transform.rotate(
        angle: (1 - t) * -0.5,
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
      child: Icon(icon),
    );
  }
}
