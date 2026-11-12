import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';

/// 오류 안내 (저장 실패, 녹음 실패, 연결 끊김).
class ErrorNotice extends StatelessWidget {
  const ErrorNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: AppColors.errorSoft,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Text(
          message,
          style: AppTextStyles.label14.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
