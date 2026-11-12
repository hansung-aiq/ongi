import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';
import 'ongi_card.dart';

/// 선택 카드. 고르면 부드러운 배경과 진한 테두리, 체크 표시로 바뀐다.
class SelectionCard extends StatelessWidget {
  const SelectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: OngiCard(
        onTap: onTap,
        color: selected ? AppColors.bgSoft : AppColors.surface,
        borderColor: selected ? AppColors.textPrimary : AppColors.line,
        borderWidth: selected
            ? AppSizes.borderSelected
            : AppSizes.borderDefault,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.label14),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      subtitle!,
                      style: AppTextStyles.caption12.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Icon(
              selected ? LucideIcons.circleCheck : LucideIcons.circle,
              size: AppSizes.iconNav,
              color: selected ? AppColors.accent : AppColors.line,
            ),
          ],
        ),
      ),
    );
  }
}
