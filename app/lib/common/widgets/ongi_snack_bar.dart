import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';

/// 화면 아래에 잠깐 뜨는 안내 (메시지를 고쳤어요, 녹음을 재생하지 못했어요 등).
/// [error]면 오류 색으로 보인다. 이미 떠 있는 안내는 바로 바꾼다.
void showOngiSnackBar(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: AppTextStyles.body14.copyWith(
            color: error ? AppColors.errorSoft : AppColors.bgBase,
          ),
        ),
        backgroundColor: error ? AppColors.error : AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
