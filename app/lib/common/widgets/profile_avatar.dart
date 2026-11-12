import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_colors.dart';

/// 원형 프로필. 화면에서는 크기 28, 40, 44, 52, 96, 128을 쓴다.
/// [imagePath]가 있으면 그 사진을, 없거나 읽지 못하면 기본 아이콘을 보인다.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 40, this.imagePath});

  final double size;

  /// 기기에 저장한 프로필 사진 경로 (3-6 설정에서 등록)
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      LucideIcons.userRound,
      size: size / 2,
      color: AppColors.textSecondary,
    );
    final path = imagePath;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.line),
      ),
      child: path == null
          ? icon
          : Image.file(
              File(path),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => icon,
            ),
    );
  }
}
