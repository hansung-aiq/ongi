import 'package:flutter/material.dart';

import 'common/common.dart';
import 'start/login_screen.dart';

void main() => runApp(const OngiApp());

class OngiApp extends StatelessWidget {
  const OngiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '온기',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}
