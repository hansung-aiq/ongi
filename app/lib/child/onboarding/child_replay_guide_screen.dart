import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../common/common.dart';
import '../recent_message_card.dart';
import 'child_onboarding.dart';
import 'child_ready_screen.dart';

/// 4-3 다시 듣기 안내. 온기기록에서 들은 메시지를 다시 들을 수 있다고 알려 준다.
class ChildReplayGuideScreen extends StatelessWidget {
  const ChildReplayGuideScreen({super.key, required this.session});

  final ChildOnboardingSession session;

  @override
  Widget build(BuildContext context) {
    final profile = session.profile;
    return OnboardingScaffold(
      step: 2,
      onSkip: () => session.finish(context),
      actions: [
        OngiButton(
          label: '다음',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChildReadyScreen(session: session),
            ),
          ),
        ),
      ],
      children: [
        const SizedBox(height: AppSpacing.s32),
        PageHeading(
          title: '들은 말은\n언제든 다시 들을 수 있어',
          description:
              '마음에 남았던 ${profile.title}의 메시지,\n'
              '온기기록에서 다시 만나자.',
          centered: true,
        ),
        const SizedBox(height: AppSpacing.section),
        OngiCard(
          color: AppColors.bgSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('온기기록', style: AppTextStyles.subtitle18),
              const SizedBox(height: AppSpacing.s16),
              RecentMessageCard(
                highlighted: true,
                showPlay: true,
                message: RecentMessage(
                  author: profile.title,
                  situation: '친구와 싸운 날',
                  text:
                      '${profile.called}, 마음이 많이 속상했지?\n'
                      '${profile.title}는 언제나 네 편이야.',
                  heardAt: '들은 날 · 오늘 · 오후 4:32',
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              const _PlayTip(),
            ],
          ),
        ),
      ],
    );
  }
}

/// 재생 버튼을 알려 주는 어두운 말풍선
class _PlayTip extends StatelessWidget {
  const _PlayTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.play, size: 18, color: AppColors.bgBase),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  '재생 버튼을 눌러봐!',
                  style: AppTextStyles.label14.copyWith(
                    color: AppColors.bgBase,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            '이미 들었던 메시지를 다시 들을 수 있어.\n네 마음이 편해질 때까지.',
            style: AppTextStyles.body14.copyWith(
              color: AppColors.textOnDarkSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
