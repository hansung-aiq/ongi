import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// 토큰을 앱 전체 테마로 묶는다.
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    fontFamily: AppTextStyles.fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.textPrimary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.bgBase,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.textPrimary,
    ),
  );
}
