import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_colors.dart';

/// 듣는 중·생각하는 중 화면 마이크.
class MicHalo extends StatelessWidget {
  const MicHalo({
    super.key,
    this.color = AppColors.textPrimary,
    this.size = 156,
  });

  final Color color;

  /// 바깥 원 지름
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.line),
      ),
      child: Container(
        width: size * 120 / 156,
        height: size * 120 / 156,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(
          LucideIcons.mic,
          size: size * 48 / 156,
          color: AppColors.bgBase,
        ),
      ),
    );
  }
}
