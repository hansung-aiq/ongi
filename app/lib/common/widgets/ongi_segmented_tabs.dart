import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';

class OngiSegment {
  const OngiSegment({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// 입력 방식 탭 (음성 녹음 / 텍스트 입력).
class OngiSegmentedTabs extends StatelessWidget {
  const OngiSegmentedTabs({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<OngiSegment> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.inputHeight,
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < segments.length; i++)
            Expanded(child: _segment(i)),
        ],
      ),
    );
  }

  Widget _segment(int index) {
    final segment = segments[index];
    final selected = index == selectedIndex;
    final color = selected ? AppColors.textPrimary : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(index),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (segment.icon != null) ...[
                Icon(segment.icon, size: AppSizes.iconSmall, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                segment.label,
                style: (selected ? AppTextStyles.label14 : AppTextStyles.body14)
                    .copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
