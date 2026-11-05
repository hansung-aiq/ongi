import 'package:flutter/material.dart';

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
      home: const _PlaceholderScreen(),
    );
  }
}

/// 임시 화면.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('온기', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.lg),
              OngiButton(label: '시작하기', onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }
}
