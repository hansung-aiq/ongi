import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';

/// 진한 원형 아이콘 버튼 (녹음 시작·멈춤·재생).
/// [onPressed]가 null이면 비활성으로 보인다.
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
    return Opacity(
      opacity: onPressed == null ? AppSizes.disabledOpacity : 1,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: iconSize,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.bgBase,
          disabledBackgroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.bgBase,
          fixedSize: Size.square(size),
        ),
        icon: Icon(icon),
      ),
    );
  }
}
