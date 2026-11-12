import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';

/// 칩. [selected]면 어두운 선택 칩, 아니면 기본 칩이다.
class OngiChip extends StatelessWidget {
  const OngiChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.dotColor,
    this.onTap,
  });

  final String label;
  final bool selected;
  final IconData? icon;

  /// 연결 상태처럼 앞에 점을 표시할 때 쓴다.
  final Color? dotColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.bgBase : AppColors.textSecondary;
    final chip = Container(
      height: AppSizes.chipHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      decoration: BoxDecoration(
        color: selected ? AppColors.textPrimary : AppColors.bgSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: AppSpacing.s4),
          ],
          Text(label, style: AppTextStyles.label12.copyWith(color: foreground)),
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}
