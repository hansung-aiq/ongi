import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';
import 'ongi_card.dart';
import 'ongi_chip.dart';

/// 저장된 메시지를 보여 주는 카드.
class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.title,
    required this.category,
    required this.body,
    required this.typeLabel,
    required this.typeIcon,
    required this.date,
    this.onTap,
    this.onMore,
  });

  final String title;
  final String category;
  final String body;
  final String typeLabel;
  final IconData typeIcon;
  final String date;
  final VoidCallback? onTap;

  /// 없으면 더보기 버튼을 숨긴다.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final secondary = AppTextStyles.caption12.copyWith(
      color: AppColors.textSecondary,
    );
    return OngiCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.label16),
                    const SizedBox(height: AppSpacing.s4),
                    Text(category, style: secondary),
                  ],
                ),
              ),
              if (onMore != null)
                IconButton(
                  onPressed: onMore,
                  tooltip: '더보기',
                  icon: const Icon(LucideIcons.ellipsis),
                  iconSize: AppSizes.iconNav,
                  color: AppColors.textPrimary,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body14.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OngiChip(label: typeLabel, icon: typeIcon),
              Text(date, style: secondary),
            ],
          ),
        ],
      ),
    );
  }
}
