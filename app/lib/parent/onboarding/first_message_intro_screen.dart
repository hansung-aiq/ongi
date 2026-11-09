import 'package:flutter/material.dart';

import '../../common/common.dart';
import 'onboarding_session.dart';
import 'recommended_situation_screen.dart';

/// 2-2 첫 메시지 안내.
class FirstMessageIntroScreen extends StatelessWidget {
  const FirstMessageIntroScreen({super.key, required this.session});

  final OnboardingSession session;

  @override
  Widget build(BuildContext context) {
    final profile = session.profile;
    return OnboardingScaffold(
      step: 0,
      actions: [
        OngiButton(
          label: '다음',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecommendedSituationScreen(session: session),
            ),
          ),
        ),
      ],
      children: [
        const SizedBox(height: 94),
        const Center(child: OngiLogo(size: 84)),
        const SizedBox(height: AppSpacing.s28),
        PageHeading(
          title: '${profile.nickname}를 위한\n첫 번째 메시지를\n남겨볼까요?',
          description:
              '힘든 날에도 혼자가 아니라고,\n'
              '${profile.title}의 목소리로 말해주세요.\n'
              '어떤 말부터 시작할지 함께 도와드릴게요.',
          centered: true,
          gap: AppSpacing.s28,
        ),
      ],
    );
  }
}
