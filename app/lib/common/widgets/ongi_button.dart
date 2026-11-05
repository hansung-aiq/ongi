import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';

/// 공통 버튼
class OngiButton extends StatelessWidget {
  const OngiButton({super.key, required this.label, required this.onPressed});

  final String label;

  /// null이면 비활성 상태로 보인다.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.buttonDark,
          foregroundColor: AppColors.onButtonDark,
          textStyle: AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
