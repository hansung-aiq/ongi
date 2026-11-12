import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';

class BottomTabItem {
  const BottomTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// 하단 탭바. 부모·자녀 화면이 탭 목록만 바꿔 함께 쓴다.
class BottomTabBar extends StatelessWidget {
  const BottomTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<BottomTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bgBase,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.tabBarHeight,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _tab(items[i], i == currentIndex, i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BottomTabItem item, bool active, int index) {
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: AppSizes.iconTab,
              color: active ? AppColors.textPrimary : AppColors.iconInactive,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              item.label,
              style: active
                  ? AppTextStyles.label12.copyWith(fontWeight: FontWeight.w700)
                  : AppTextStyles.caption12.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.25,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
