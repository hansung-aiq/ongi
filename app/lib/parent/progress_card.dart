import 'package:flutter/material.dart';

import '../common/common.dart';
import 'parent_store.dart';

/// '추천 10개 채우기' 진행 카드 (3-1, 3-5).
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.progress});

  final int progress;

  @override
  Widget build(BuildContext context) {
    const goal = ParentStore.goal;
    return OngiCard(
      color: AppColors.bgSoft,
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('추천 $goal개 채우기', style: AppTextStyles.label14),
              ),
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
              value: progress / goal,
              minHeight: 6,
              color: AppColors.accent,
              backgroundColor: AppColors.line,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '작은 메시지 하나가 아이의 든든한 힘이 돼요.',
            style: AppTextStyles.caption12.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
