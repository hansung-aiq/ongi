import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';
import 'bottom_actions.dart';
import 'step_dots.dart';

/// 첫 설정 화면(부모 2-x, 자녀 4-x)의 공통 틀.
/// 위에 단계 점(또는 [header]), 가운데 내용, 아래 버튼 묶음이 온다.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    this.step,
    this.header,
    this.onSkip,
    required this.children,
    required this.actions,
  });

  /// 단계 점에서 지금 단계 (0~3). 없으면 점을 숨긴다.
  final int? step;

  /// 단계 점 대신 놓을 위쪽 줄 (2-1의 상단 내비게이션)
  final Widget? header;

  /// 있으면 단계 점 오른쪽에 '건너뛰기'를 보인다.
  final VoidCallback? onSkip;
  final List<Widget> children;
  final List<Widget> actions;

  static const stepCount = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.s8,
                  AppSpacing.screenHorizontal,
                  AppSpacing.s24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?header,
                    if (step != null) _stepRow(),
                    const SizedBox(height: AppSpacing.section),
                    ...children,
                  ],
                ),
              ),
            ),
            BottomActions(children: actions),
          ],
        ),
      ),
    );
  }

  Widget _stepRow() {
    return SizedBox(
      height: AppSizes.navBarHeight,
      child: Row(
        children: [
          StepDots(count: stepCount, current: step!),
          const Spacer(),
          if (onSkip != null)
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: AppTextStyles.body14,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                minimumSize: const Size(48, AppSizes.navBarHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('건너뛰기'),
            ),
        ],
      ),
    );
  }
}
