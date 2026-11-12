import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';

/// 내용 너비만큼만 차지하는 작은 테두리 버튼 (다시 듣기, 다시 녹음).
/// [onPressed]가 null이면 비활성으로 보인다.
class OngiPillButton extends StatelessWidget {
  const OngiPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? AppSizes.disabledOpacity : 1,
      child: Material(
        color: AppColors.surface,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14.4, color: AppColors.textPrimary),
                  const SizedBox(width: 6),
                ],
                Text(label, style: AppTextStyles.label14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
