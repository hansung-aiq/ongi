import 'dart:io';

import 'package:flutter/material.dart';

import '../../config.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';

/// 11/23 누구의 메시지인지 보여 주는 글자 도장.
/// '아빠'는 진갈색, '엄마'는 코랄. 부모가 사진을 등록했으면 사진을 보인다.
class ParentStamp extends StatelessWidget {
  const ParentStamp({
    super.key,
    required this.title,
    this.size = 44,
    this.imagePath,
  });

  /// 화면에 쓰는 호칭('아빠', '엄마'). 앞 두 글자를 도장에 새긴다.
  final String title;
  final double size;
  final String? imagePath;

  bool get _mom => title.startsWith(AppConfig.momTitle) || title.contains('엄마');

  @override
  Widget build(BuildContext context) {
    final tone = _mom ? AppColors.momTone : AppColors.dadTone;
    final soft = _mom ? AppColors.momSoft : AppColors.dadSoft;
    final label = title.characters.take(2).toString();
    final stamp = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
      child: Container(
        /// 도장 안쪽 테두리
        width: size * 0.82,
        height: size * 0.82,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: tone.withValues(alpha: 0.55), width: size >= 64 ? 2 : 1.2),
        ),
        child: Text(
          label,
          style: AppTextStyles.label16.copyWith(
            fontSize: size * 0.3,
            fontWeight: FontWeight.w800,
            color: tone,
            height: 1,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
    final path = imagePath;
    if (path == null) return Semantics(label: title, child: stamp);
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => stamp,
        ),
      ),
    );
  }
}
