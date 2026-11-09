import 'package:flutter/material.dart';

import '../../common/common.dart';
import '../parent_shell.dart';
import '../progress_card.dart';
import 'onboarding_session.dart';

/// 2-7 첫 메시지 완료
class FirstMessageDoneScreen extends StatelessWidget {
  const FirstMessageDoneScreen({super.key, required this.session});

  final OnboardingSession session;

  /// 첫 설정 화면을 모두 닫고 부모 화면으로 간다.
  void _finish(BuildContext context, int tab) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => ParentShell(
          serverClient: session.serverClient,
          recorderFactory: session.recorderFactory,
          initialTab: tab,
          profile: session.profile,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = session.profile;
    return PopScope(
      canPop: false,
      child: OnboardingScaffold(
        step: 3,
        actions: [
          OngiButton(
            label: '메시지 더 남기기',
            onPressed: () => _finish(context, ParentShell.messagesTab),
          ),
          OngiButton.secondary(
            label: '홈으로',
            onPressed: () => _finish(context, ParentShell.homeTab),
          ),
        ],
        children: [
          const SizedBox(height: 58),
          const Center(child: OngiLogo(size: 96)),
          const SizedBox(height: AppSpacing.s28),
          PageHeading(
            title: '첫 메시지를 남겼어요',
            description:
                '${profile.nickname}가 필요한 순간,\n'
                '${profile.title}의 목소리로 마음을 전해드릴게요.',
            centered: true,
          ),
          const SizedBox(height: AppSpacing.s28),
          ProgressCard(progress: session.store.progress),
          const SizedBox(height: AppSpacing.s28),
          Text(
            '좋은 시작이에요. 하나씩 채워가세요.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body14.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
