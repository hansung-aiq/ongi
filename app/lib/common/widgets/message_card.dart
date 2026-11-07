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
    this.category,
    this.body,
    this.bodyMaxLines = 3,
    required this.typeLabel,
    required this.typeIcon,
    this.statusLabel,
    this.statusMuted = false,
    required this.date,
    this.onTap,
    this.onMore,
  });

  final String title;

  /// 없으면 분류 줄을 숨긴다.
  final String? category;

  /// 없으면 본문 줄을 숨긴다 (녹음 메시지).
  final String? body;
  final int bodyMaxLines;
  final String typeLabel;
  final IconData typeIcon;

  /// 전달 상태 칩 ('전달됨', '전달 대기'). 없으면 숨긴다.
  final String? statusLabel;

  /// 아직 전달되지 않은 상태처럼 흐리게 보인다.
  final bool statusMuted;
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
                    if (category != null) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(category!, style: secondary),
                    ],
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
          if (body != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              body!,
              maxLines: bodyMaxLines,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body14.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              OngiChip(label: typeLabel, icon: typeIcon),
              if (statusLabel != null) ...[
                const SizedBox(width: AppSpacing.s8),
                Opacity(
                  opacity: statusMuted ? AppSizes.disabledOpacity : 1,
                  child: OngiChip(label: statusLabel!),
                ),
              ],
              const Spacer(),
              Text(date, style: secondary),
            ],
          ),
        ],
      ),
    );
  }
}
