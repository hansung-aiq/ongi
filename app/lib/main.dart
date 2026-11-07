import 'package:flutter/material.dart';

import 'child/child_screen.dart';
import 'common/common.dart';

void main() => runApp(const OngiApp());

class OngiApp extends StatelessWidget {
  const OngiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '온기',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // 시작·역할 선택 화면을 만들기 전까지 자녀 화면을 바로 띄운다.
      home: const ChildScreen(),
    );
  }
}
