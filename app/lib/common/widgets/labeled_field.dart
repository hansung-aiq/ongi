import 'package:flutter/material.dart';

import '../app_spacing.dart';
import '../app_text_styles.dart';

/// 항목 이름 아래에 입력칸이나 선택 버튼을 놓는 묶음.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTextStyles.label14),
        const SizedBox(height: AppSpacing.s8),
        child,
      ],
    );
  }
}
