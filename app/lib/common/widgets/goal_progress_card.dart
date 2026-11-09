import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';
import 'ongi_card.dart';

/// 목표 진행 카드 ('추천 10개 채우기').
class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({
    super.key,
    required this.title,
    required this.progress,
    required this.goal,
    this.caption,
  });

  final String title;
  final int progress;
  final int goal;

  /// 진행 막대 아래 안내 문구. 없으면 숨긴다.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return OngiCard(
      color: AppColors.bgSoft,
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.label14)),
              Text(
                '$progress/$goal',
                style: AppTextStyles.label14.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: goal == 0 ? 0 : (progress / goal).clamp(0.0, 1.0),
              minHeight: 6,
              color: AppColors.accent,
              backgroundColor: AppColors.line,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 14),
            Text(
              caption!,
              style: AppTextStyles.caption12.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
