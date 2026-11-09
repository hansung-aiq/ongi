import 'package:flutter/material.dart';

import '../../api/server_models.dart';
import '../../api/situations.dart';
import '../../common/common.dart';
import '../situation_info.dart';
import 'first_message_write_screen.dart';
import 'onboarding_session.dart';

/// 첫 메시지로 추천하는 상황 (친구와 싸운 날).
/// 서버 목록을 아직 못 받았으면 같은 값을 그대로 쓴다.
const _recommendedId = 4;
const _fallbackCategory = '관계·비교';

/// 2-3 추천 상황.
class RecommendedSituationScreen extends StatelessWidget {
  const RecommendedSituationScreen({super.key, required this.session});

  final OnboardingSession session;

  Situation get _situation =>
      session.store.situation(_recommendedId) ??
      Situation(
        id: _recommendedId,
        name: situationNames[_recommendedId]!,
        category: _fallbackCategory,
      );

  @override
  Widget build(BuildContext context) {
    final profile = session.profile;
    final situation = _situation;
    final secondary = AppColors.textSecondary;
    return OnboardingScaffold(
      step: 1,
      actions: [
        OngiButton(
          label: '이 상황에 메시지 남기기',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FirstMessageWriteScreen(
                session: session,
                situation: situation,
              ),
            ),
          ),
        ),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s32),
          child: PageHeading(
            title: '이런 순간,\n${profile.title}의 목소리가 필요해요.',
            description: '${profile.nickname}가 꺼낼 수 있는 말에 귀 기울여주세요.',
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        OngiCard(
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OngiChip(label: categoryLabel(situation.category)),
              const SizedBox(height: AppSpacing.s20),
              Row(
                children: [
                  Icon(
                    categoryIcon(situation.category),
                    size: 28,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      situation.name,
                      style: AppTextStyles.subtitle18.copyWith(
                        fontSize: 22,
                        height: 27 / 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: AppColors.bgSoft,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.nickname}가 이렇게 말할 수 있어요.',
                      style: AppTextStyles.caption12.copyWith(color: secondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '“오늘 친구랑 싸웠어.”',
                      style: AppTextStyles.body16.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        Text(
          '속상한 마음을 먼저 알아주세요.\n'
          '정답보다 “네 편이야”라는 한마디가\n'
          '아이에게 큰 힘이 될 수 있어요.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body14.copyWith(color: secondary),
        ),
      ],
    );
  }
}
