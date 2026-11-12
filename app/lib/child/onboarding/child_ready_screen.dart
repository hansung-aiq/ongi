import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../common/common.dart';
import 'child_onboarding.dart';

/// 4-4 자녀 준비 완료. '온기 시작하기'를 누르면 자녀 홈(5-1)으로 간다.
class ChildReadyScreen extends StatelessWidget {
  const ChildReadyScreen({super.key, required this.session});

  final ChildOnboardingSession session;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 3,
      onSkip: () => session.finish(context),
      actions: [
        OngiButton(label: '온기 시작하기', onPressed: () => session.finish(context)),
      ],
      children: [
        const SizedBox(height: 58),
        const Center(child: OngiLogo(size: 96)),
        const SizedBox(height: AppSpacing.s28),
        const PageHeading(
          title: '이제 준비 끝!',
          description: '하고 싶은 말이 있으면 언제든 찾아와.\n온기가 네 이야기를 기다릴게.',
          centered: true,
        ),
        const SizedBox(height: AppSpacing.s28),
        const OngiCard(
          padding: EdgeInsets.all(AppSpacing.s20),
          child: Column(
            children: [
              _CheckRow(icon: LucideIcons.mic, text: '마이크를 누르고 이야기하기'),
              SizedBox(height: AppSpacing.s24),
              _CheckRow(icon: LucideIcons.headphones, text: '온기기록에서 다시 듣기'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s28),
        Text(
          '기쁜 날도, 속상한 날도 함께할게.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body14.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// 아이콘 + 할 수 있는 일 + 주황 체크
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppSizes.iconNav, color: AppColors.textPrimary),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.label16.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        const Icon(LucideIcons.check, size: 20, color: AppColors.accent),
      ],
    );
  }
}
