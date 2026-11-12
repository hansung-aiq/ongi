import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_motion.dart';
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

    /// 화면 이동은 플랫폼과 상관없이 같은 움직임 (AppMotion)
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: OngiPageTransitionsBuilder(),
        TargetPlatform.iOS: OngiPageTransitionsBuilder(),
        TargetPlatform.windows: OngiPageTransitionsBuilder(),
        TargetPlatform.macOS: OngiPageTransitionsBuilder(),
        TargetPlatform.linux: OngiPageTransitionsBuilder(),
        TargetPlatform.fuchsia: OngiPageTransitionsBuilder(),
      },
    ),
  );
}
