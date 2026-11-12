import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';

/// 입력창. 기본·선택됨·오류·비활성 상태를 가진다.
class OngiTextField extends StatelessWidget {
  const OngiTextField({
    super.key,
    this.controller,
    this.hintText,
    this.errorText,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? hintText;

  /// 값이 있으면 오류 상태로 보이고 입력창 아래에 표시한다.
  final String? errorText;
  final bool enabled;

  /// 넘기면 더 입력되지 않는다. 글자 수 표시는 하지 않는다.
  final int? maxLength;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.input),
    borderSide: BorderSide(color: color, width: width),
  );

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLength: maxLength,
      maxLines: maxLines,
      onChanged: onChanged,
      style: AppTextStyles.body16.copyWith(
        color: enabled
            ? AppColors.textPrimary
            : AppColors.textPrimary.withValues(alpha: AppSizes.disabledOpacity),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.body16.copyWith(
          color: enabled
              ? AppColors.textSecondary
              : AppColors.textSecondary.withValues(
                  alpha: AppSizes.disabledOpacity,
                ),
        ),
        errorText: errorText,
        errorStyle: AppTextStyles.caption12.copyWith(color: AppColors.error),
        counterText: '',
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: 14,
        ),
        enabledBorder: _border(AppColors.line, AppSizes.borderDefault),
        disabledBorder: _border(
          AppColors.line.withValues(alpha: AppSizes.disabledOpacity),
          AppSizes.borderDefault,
        ),
        focusedBorder: _border(AppColors.textPrimary, AppSizes.borderSelected),
        errorBorder: _border(AppColors.error, AppSizes.borderSelected),
        focusedErrorBorder: _border(AppColors.error, AppSizes.borderSelected),
      ),
    );
  }
}
