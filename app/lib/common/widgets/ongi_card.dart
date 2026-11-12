import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';

/// 기본 카드. [onTap]을 주면 누를 수 있다.
class OngiCard extends StatelessWidget {
  const OngiCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.color = AppColors.surface,
    this.borderColor = AppColors.line,
    this.borderWidth = AppSizes.borderDefault,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
