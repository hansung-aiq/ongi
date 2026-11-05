import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 글자 토큰
class AppTextStyles {
  AppTextStyles._();

  static const title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(fontSize: 16, color: AppColors.textPrimary);
  static const button = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
}
