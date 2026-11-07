import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../common/common.dart';

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
const sampleRecentMessages = [
  RecentMessage(
    author: '엄마',
    situation: '친구와 싸운 날',
    text: '민준아, 마음이 많이 속상했지?\n엄마는 언제나 네 편이야.',
    heardAt: '들은 날 · 오늘 · 오후 4:32',
  ),
  RecentMessage(
    author: '엄마',
    situation: '친구와 싸운 날',
    text: '민준아, 마음이 많이 속상했지?\n엄마는 언제나 네 편이야.',
    heardAt: '들은 날 · 오늘 · 오후 4:32',
  ),
];

/// 최근에 들은 메시지 카드.
class RecentMessageCard extends StatelessWidget {
  const RecentMessageCard({super.key, required this.message});

  final RecentMessage message;

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary;
    return OngiCard(
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
