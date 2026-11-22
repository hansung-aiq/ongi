import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../child/heard_messages.dart';
import '../child/recent_message_card.dart';
import '../common/common.dart';
import 'parent_store.dart';
import 'progress_card.dart';
import 'situation_info.dart';

/// 3-1 부모 홈. 분류 카드를 누르면 그 분류의 메시지 목록(3-3)으로 간다.
class ParentHomeScreen extends StatelessWidget {
  const ParentHomeScreen({
    super.key,
    required this.store,
    required this.onCategory,
    this.heard,
    this.onWriteFor,
    this.onVoice,
    this.voiceName,
  });

  /// 11/22 '내 목소리' 카드를 누르면 부른다. null이면 카드를 숨긴다.
  final VoidCallback? onVoice;

  /// 만든 목소리 캐릭터 이름. 없으면 '내 목소리 만들기'로 보인다.
  final String? voiceName;

  /// 아이가 찾았던 상황에 바로 메시지를 남기러 간다 (11/11)
  final ValueChanged<int>? onWriteFor;

  final ParentStore store;

  /// 자녀가 들은 메시지 (API-09). 들은 것이 있으면 진행률 아래에 2개까지 보인다.
  final HeardMessages? heard;

  static const _recentCount = 2;
  final ValueChanged<String> onCategory;

  @override
  Widget build(BuildContext context) {
    final categories = store.categories;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.s16,
        AppSpacing.screenHorizontal,
        AppSpacing.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _greeting(),
          const SizedBox(height: AppSpacing.section),
          ProgressCard(progress: store.progress),
          if (onVoice != null) ...[
            const SizedBox(height: AppSpacing.s12),
            _voiceCard(),
          ],
          const SizedBox(height: AppSpacing.section),
          _needed(),
          if (heard case final heard?)
            ListenableBuilder(
              listenable: heard,
              builder: (context, _) => _recentlyHeard(heard),
            ),
          Text('어떤 순간에 마음을 전할까요?', style: AppTextStyles.subtitle18),
          const SizedBox(height: 14),
          _categoryList(categories),
        ],
      ),
    );
  }

  static const _needCount = 3;

  /// 11/11: 아이가 온기에게 말했는데 메시지가 없었던 상황(API-18). 없으면 구역을 숨긴다.
  /// 카드를 누르면 그 상황에 메시지를 남기러 간다.
  Widget _needed() {
    final needs = store.needs.take(_needCount).toList();
    final onWrite = onWriteFor;
    if (needs.isEmpty || onWrite == null) return const SizedBox.shrink();
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${store.profile.nickname}가 이런 순간에 메시지를 찾았어요',
          style: AppTextStyles.subtitle18,
        ),
        const SizedBox(height: 6),
        Text(
          '아직 남긴 메시지가 없는 상황이에요. 지금 남겨 보세요.',
          style: AppTextStyles.body14.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        for (final n in needs) ...[
          EmptySituationCard(
            title: n.name,
            subtitle: '${_ago(n.lastNeededAt, now)} · 최근 ${n.count}번 찾았어요',
            onTap: () => onWrite(n.situationId),
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        const SizedBox(height: AppSpacing.section - AppSpacing.s12),
      ],
    );
  }

  static String _ago(DateTime at, DateTime now) {
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(at.year, at.month, at.day)).inDays;
    return switch (days) {
      <= 0 => '오늘',
      1 => '어제',
      _ => '$days일 전',
    };
  }

  /// 아이가 최근에 들은 메시지. 불러오지 못했거나 아직 없으면 구역을 숨긴다.
  Widget _recentlyHeard(HeardMessages heard) {
    final cards = heard.error == null
        ? heard.cards(store.profile).take(_recentCount).toList()
        : const <RecentMessage>[];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${store.profile.nickname}가 최근에 들은 메시지',
          style: AppTextStyles.subtitle18,
        ),
        const SizedBox(height: 14),
        for (final m in cards) ...[
          RecentMessageCard(message: m, maxLines: 2),
          const SizedBox(height: AppSpacing.s12),
        ],
        const SizedBox(height: AppSpacing.section - AppSpacing.s12),
      ],
    );
  }

  Widget _greeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const OngiLogo(size: 30),
            const SizedBox(width: AppSpacing.s8),
            Text(
              '온기',
              style: AppTextStyles.subtitle18.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${store.profile.nickname}의 부모님',
                    style: AppTextStyles.title28,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    '오늘도 아이의 든든한 편이 되어주세요.',
                    style: AppTextStyles.body14.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            ProfileAvatar(size: 52, imagePath: store.profile.parentPhoto),
          ],
        ),
      ],
    );
  }

  /// 11/22 내 목소리 카드: 만든 목소리가 있으면 이름과 '써 보기', 없으면 만들기 안내
  Widget _voiceCard() {
    final name = voiceName;
    return OngiCard(
      onTap: onVoice,
      color: AppColors.stampBg,
      borderColor: AppColors.stampBg,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: const Icon(LucideIcons.audioLines, size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name == null ? '내 목소리 만들기' : '$name 목소리', style: AppTextStyles.label16),
                const SizedBox(height: 2),
                Text(
                  name == null ? '문장 5개를 읽으면 남긴 글을 내 목소리로 들려줘요' : '남긴 글을 이 목소리로 들려줘요 · 써 보기',
                  style: AppTextStyles.caption12.copyWith(color: AppColors.stampText),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.stampText),
        ],
      ),
    );
  }

  /// 분류 목록: 한 카드 안에 네 줄(아이콘 · 이름 · 채운 정도 · 화살표)
  Widget _categoryList(List<String> categories) {
    return OngiCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, indent: 68, color: AppColors.line),
            _categoryRow(categories[i]),
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(String category) {
    final saved = store.savedIn(category);
    final total = store.situationsIn(category).length;
    return InkWell(
      onTap: () => onCategory(category),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.bgSoft,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Icon(categoryIcon(category), size: 20, color: AppColors.textPrimary),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(categoryLabel(category), style: AppTextStyles.label16),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : saved / total,
                      minHeight: 4,
                      color: AppColors.accent,
                      backgroundColor: AppColors.line,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Text(
              '$saved/$total',
              style: AppTextStyles.caption12.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.s4),
            const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.iconInactive),
          ],
        ),
      ),
    );
  }
}
