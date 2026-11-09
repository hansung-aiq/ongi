import 'package:flutter/material.dart';

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
  });

  final ParentStore store;
  final ValueChanged<String> onCategory;

  @override
  Widget build(BuildContext context) {
    final categories = store.categories;
    return SingleChildScrollView(
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
          const SizedBox(height: AppSpacing.section),
          Text('어떤 순간에 마음을 전할까요?', style: AppTextStyles.subtitle18),
          const SizedBox(height: 14),
          for (var i = 0; i < categories.length; i += 2) ...[
            if (i > 0) const SizedBox(height: AppSpacing.s12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _categoryCard(categories[i])),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: i + 1 < categories.length
                        ? _categoryCard(categories[i + 1])
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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

  Widget _categoryCard(String category) {
    return OngiCard(
      onTap: () => onCategory(category),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 151 - 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  categoryIcon(category),
                  size: 25,
                  color: AppColors.textPrimary,
                ),
                const Spacer(),
                Text(
                  '${store.savedIn(category)}/${store.situationsIn(category).length}',
                  style: AppTextStyles.caption12.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              categoryLabel(category),
              style: AppTextStyles.subtitle18.copyWith(height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
