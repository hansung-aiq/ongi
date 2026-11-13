import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_motion.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';
import 'ongi_card.dart';

/// 목표 진행 카드 ('추천 10개 채우기').
class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({
    super.key,
    required this.title,
    required this.progress,
    required this.goal,
    this.caption,
    this.from,
  });

  final String title;
  final int progress;

  /// 이 값에서 [progress]까지 숫자가 굴러가고 막대가 차오른다(저장 완료 화면: 방금 하나 늘어난 것).
  /// 없으면 처음엔 그대로 보이고, 나중에 [progress]가 바뀔 때만 움직인다.
  final int? from;
  final int goal;

  /// 진행 막대 아래 안내 문구. 없으면 숨긴다.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return OngiCard(
      color: AppColors.bgSoft,
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(
              begin: (from ?? progress).toDouble(),
              end: progress.toDouble(),
            ),
            duration: AppMotion.count,
            curve: AppMotion.enterCurve,
            builder: (context, value, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: AppTextStyles.label14)),

                    /// 숫자가 바뀔 때 새 숫자가 아래에서 올라온다(오도미터)
                    ClipRect(
                      child: AnimatedSwitcher(
                        duration: AppMotion.fast,
                        transitionBuilder: (child, animation) =>
                            SlideTransition(
                              position: Tween(
                                begin: const Offset(0, 0.6),
                                end: Offset.zero,
                              ).animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: Text(
                          '${value.round()}/$goal',
                          key: ValueKey(value.round()),
                          style: AppTextStyles.label14.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: goal == 0 ? 0 : (value / goal).clamp(0.0, 1.0),
                    minHeight: 6,
                    color: AppColors.accent,
                    backgroundColor: AppColors.line,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ],
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 14),
            Text(
              caption!,
              style: AppTextStyles.caption12.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
