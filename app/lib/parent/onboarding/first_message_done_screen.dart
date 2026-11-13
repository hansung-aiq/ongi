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
  void _finish(BuildContext context, int tab) =>
      session.finish(context, tab: tab);

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

          /// 로고가 살짝 튕기며 나타나고 뒤에서 따뜻한 원이 한 번 퍼진다
          const Center(child: PopIn(ring: true, child: OngiLogo(size: 96))),
          const SizedBox(height: AppSpacing.s28),
          PageHeading(
            title: '첫 메시지를 남겼어요',
            description:
                '${profile.nickname}가 필요한 순간,\n'
                '${profile.title}의 목소리로 마음을 전해드릴게요.',
            centered: true,
          ),
          const SizedBox(height: AppSpacing.s28),
          ProgressCard(
            progress: session.store.progress,
            from: session.store.progress > 0
                ? session.store.progress - 1
                : null,
          ),
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
