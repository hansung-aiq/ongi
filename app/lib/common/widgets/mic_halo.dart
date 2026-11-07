import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_colors.dart';

/// 듣는 중·생각하는 중 화면 마이크.
class MicHalo extends StatelessWidget {
  const MicHalo({super.key, this.color = AppColors.textPrimary});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      height: 156,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.line),
      ),
      child: Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const Icon(LucideIcons.mic, size: 48, color: AppColors.bgBase),
      ),
    );
  }
}
