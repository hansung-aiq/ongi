import 'package:flutter/material.dart';

import '../app_colors.dart';

/// 아래에서 올라오는 창 맨 위의 손잡이 (6-2 메뉴, 프로필 수정).
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.sheetHandle,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
