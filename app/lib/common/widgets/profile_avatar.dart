import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_colors.dart';

/// 원형 기본 프로필. 화면에서는 크기 28, 40, 52, 96을 쓴다.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.line),
      ),
      child: Icon(
        LucideIcons.userRound,
        size: size / 2,
        color: AppColors.textSecondary,
      ),
    );
  }
}
