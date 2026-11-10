import 'package:flutter/material.dart';

import '../../api/server_models.dart';
import '../../api/situations.dart';
import '../../common/common.dart';
import '../situation_info.dart';
import 'first_message_write_screen.dart';
import 'onboarding_session.dart';

/// 첫 메시지로 추천하는 순서. 이미 메시지가 있는 상황은 건너뛴다.
/// 시연 4개(친구·시험·보고 싶음·자랑)를 먼저, 나머지는 번호 순서.
const _priority = [4, 3, 10, 11, 1, 2, 5, 6, 7, 8, 9, 12];

/// 아이가 이렇게 말할 수 있어요 (추천 카드의 예시 말)
String _exampleFor(int id, String parentTitle) => switch (id) {
  3 => '“나 오늘 시험 망쳤어.”',
  4 => '“오늘 친구랑 싸웠어.”',
  10 => '“$parentTitle 보고 싶어.”',
  11 => '“나 오늘 상 받았어!”',
  1 => '“학교 가기 싫어.”',
  2 => '“선생님한테 혼났어.”',
  5 => '“친구가 나 싫어하는 것 같아.”',
  6 => '“나만 못하는 것 같아.”',
  7 => '“오늘 울고 싶어.”',
  8 => '“아무것도 하기 싫어.”',
  9 => '“잠이 안 와.”',
  _ => '“오늘 내 생일이야!”',
};

/// 서버 목록을 받기 전에 쓰는 분류
const _fallbackCategory = {
  1: '학교·학업', 2: '학교·학업', 3: '학교·학업',
  4: '관계·비교', 5: '관계·비교', 6: '관계·비교',
  7: '감정·일상', 8: '감정·일상', 9: '감정·일상',
  10: '가족·기념일', 11: '가족·기념일', 12: '가족·기념일',
};

/// 2-3 추천 상황.
/// 아직 메시지가 없는 상황 하나를 추천한다(같은 상황에는 하나만 남길 수 있어서, 이미 있는
/// 상황을 추천하면 저장할 때 E-409가 난다). 모든 상황에 메시지가 있으면 홈으로 가게 한다.
class RecommendedSituationScreen extends StatelessWidget {
  const RecommendedSituationScreen({super.key, required this.session});

  final OnboardingSession session;

  /// 추천할 상황. 모든 상황에 메시지가 있으면 null.
  Situation? get _situation {
    final store = session.store;
    for (final id in _priority) {
      if (store.loaded && store.messageFor(id) != null) continue;
      return store.situation(id) ??
          Situation(
            id: id,
            name: situationNames[id]!,
            category: _fallbackCategory[id]!,
          );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session.store,
      builder: (context, _) => switch (_situation) {
        final situation? => _recommend(context, situation),
        null => _allFilled(context),
      },
    );
  }

  /// 모든 상황에 이미 메시지가 있을 때
  Widget _allFilled(BuildContext context) {
    final profile = session.profile;
    return OnboardingScaffold(
      step: 1,
      actions: [
        OngiButton(label: '홈으로', onPressed: () => session.finish(context)),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s32),
          child: PageHeading(
            title: '모든 상황에\n이미 메시지가 있어요.',
            description:
                '${profile.nickname}를 위한 메시지가 모두 준비돼 있어요.\n'
                '홈에서 메시지를 다시 듣거나 고칠 수 있어요.',
          ),
        ),
      ],
    );
  }

  Widget _recommend(BuildContext context, Situation situation) {
    final profile = session.profile;
    final secondary = AppColors.textSecondary;
    return OnboardingScaffold(
      step: 1,
      onSkip: () => session.finish(context),
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
                      _exampleFor(situation.id, profile.title),
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
