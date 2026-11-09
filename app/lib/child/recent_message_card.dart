import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../common/common.dart';
import '../parent/parent_profile.dart';

class RecentMessage {
  const RecentMessage({
    required this.author,
    required this.situation,
    required this.text,
    required this.heardAt,
  });

  final String author;
  final String situation;
  final String text;
  final String heardAt;
}

/// 시안의 예시 데이터. 재생 기록 API-09를 붙일 때 실제 데이터로 바꾼다.
/// 이름과 호칭은 부모가 첫 설정에서 저장한 값을 쓴다.
List<RecentMessage> sampleRecentMessages(ParentProfile profile) => [
  for (var i = 0; i < 2; i++)
    RecentMessage(
      author: profile.title,
      situation: '친구와 싸운 날',
      text:
          '${profile.called}, 마음이 많이 속상했지?\n'
          '${profile.title}는 언제나 네 편이야.',
      heardAt: '들은 날 · 오늘 · 오후 4:32',
    ),
];

/// 최근에 들은 메시지 카드.
class RecentMessageCard extends StatelessWidget {
  const RecentMessageCard({
    super.key,
    required this.message,
    this.highlighted = false,
  });

  final RecentMessage message;

  /// 4-3 안내처럼 진한 1.5 테두리로 강조한다.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary;
    return OngiCard(
      borderColor: highlighted ? AppColors.textPrimary : AppColors.line,
      borderWidth: highlighted
          ? AppSizes.borderSelected
          : AppSizes.borderDefault,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ProfileAvatar(),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.author,
                      style: AppTextStyles.caption12.copyWith(
                        color: secondary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(message.situation, style: AppTextStyles.label16),
                  ],
                ),
              ),
              // 앱은 재생하지 않는다. 시안 모양만 보여 준다.
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.textPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.play,
                  size: 14.4,
                  color: AppColors.bgBase,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: AppTextStyles.body14.copyWith(color: secondary),
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  message.heardAt,
                  style: AppTextStyles.caption12.copyWith(color: secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
