import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';

/// 온보딩 단계 점. 지금 단계는 긴 막대, 나머지는 점으로 보인다.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.count, required this.current});

  final int count;

  /// 0부터 센다.
  final int current;

  static const _dot = 6.0;
  static const _activeWidth = 24.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count단계 중 ${current + 1}단계',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: _dot),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == current ? _activeWidth : _dot,
                height: _dot,
                decoration: BoxDecoration(
                  color: i == current ? AppColors.textPrimary : AppColors.line,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
