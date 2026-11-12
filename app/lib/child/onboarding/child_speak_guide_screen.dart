import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../common/common.dart';
import 'child_onboarding.dart';
import 'child_replay_guide_screen.dart';

/// 4-2 말하기 안내. 아이가 말하면 부모 메시지가 답하는 모습을 보여 준다.
class ChildSpeakGuideScreen extends StatelessWidget {
  const ChildSpeakGuideScreen({super.key, required this.session});

  final ChildOnboardingSession session;

  @override
  Widget build(BuildContext context) {
    final profile = session.profile;
    final secondary = AppColors.textSecondary;
    return OnboardingScaffold(
      step: 1,
      onSkip: () => session.finish(context),
      actions: [
        OngiButton(
          label: '다음',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChildReplayGuideScreen(session: session),
            ),
          ),
        ),
      ],
      children: [
        const SizedBox(height: AppSpacing.s32),
        PageHeading(
          title: '힘든 날엔\n온기한테 말해봐',
          description:
              '무슨 일이 있었는지 편하게 말해줘.\n'
              '${profile.title}의 메시지가 네 마음을 안아줄 거야.',
          centered: true,
        ),
        const SizedBox(height: AppSpacing.s24 + AppSpacing.s24),

        /// 아이의 말풍선 (오른쪽)
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s16,
            ),
            decoration: const BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.card),
                topRight: Radius.circular(AppRadius.card),
                bottomLeft: Radius.circular(AppRadius.card),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              '“오늘 친구랑 싸웠어.”',
              style: AppTextStyles.body16.copyWith(
                color: AppColors.bgBase,
                height: 19 / 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s20),

        /// 부모 메시지 카드
        OngiCard(
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ProfileAvatar(size: 48),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.title, style: AppTextStyles.label16),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          '${profile.nickname}를 위해 남긴 메시지',
                          style: AppTextStyles.caption12.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                '${profile.called}, 많이 속상했지?\n'
                '${profile.title}는 언제나 네 편이야.',
                style: AppTextStyles.body16,
              ),
              const SizedBox(height: AppSpacing.s16),
              const Waveform.small(width: 210),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        const HintRow(icon: LucideIcons.mic, text: '마이크를 누르고 네 이야기를 들려줘.'),
      ],
    );
  }
}
