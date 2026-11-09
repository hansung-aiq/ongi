import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';

/// 화면 제목 묶음: 윗줄(선택) + 큰 제목 + 안내 문구(선택).
class PageHeading extends StatelessWidget {
  /// 설정·안내 화면 (2-1, 2-3). 안내 문구는 body16, 줄 간격 12.
  const PageHeading({
    super.key,
    required this.title,
    this.eyebrow,
    this.description,
    this.centered = false,
    this.gap = AppSpacing.s12,
  }) : _compact = false;

  /// 상황 이름을 보여 주는 작성 화면 (2-4~2-6).
  /// 윗줄에 분류, 안내 문구는 body14, 줄 간격 8.
  const PageHeading.situation({
    super.key,
    required this.title,
    required String category,
    this.description,
  }) : eyebrow = category,
       centered = false,
       gap = AppSpacing.s8,
       _compact = true;

  final String title;

  /// 제목 위 작은 글씨 (상황 분류 등)
  final String? eyebrow;
  final String? description;

  /// 로고와 함께 가운데 정렬로 쓰는 화면 (2-2, 2-7)
  final bool centered;

  /// 줄 사이 간격
  final double gap;
  final bool _compact;

  @override
  Widget build(BuildContext context) {
    final align = centered ? TextAlign.center : TextAlign.start;
    final descriptionStyle =
        (_compact ? AppTextStyles.body14 : AppTextStyles.body16).copyWith(
          color: AppColors.textSecondary,
        );
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            textAlign: align,
            style: AppTextStyles.caption12.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: gap),
        ],
        Semantics(
          header: true,
          child: Text(title, textAlign: align, style: AppTextStyles.title28),
        ),
        if (description != null) ...[
          SizedBox(height: gap),
          Text(description!, textAlign: align, style: descriptionStyle),
        ],
      ],
    );
  }
}
