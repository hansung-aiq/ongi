import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';

/// 상단 내비게이션. 콜백을 주지 않은 버튼은 보이지 않는다.
class TopNavBar extends StatelessWidget {
  const TopNavBar({super.key, required this.title, this.onBack, this.onClose});

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return SizedBox.square(
      dimension: AppSizes.navBarHeight,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: AppSizes.iconNav,
        color: AppColors.textPrimary,
        icon: Icon(icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.navBarHeight,
      child: Row(
        children: [
          if (onBack != null) ...[
            _iconButton(LucideIcons.arrowLeft, '뒤로', onBack!),
            const SizedBox(width: AppSpacing.s4),
          ],
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.subtitle18,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onClose != null) _iconButton(LucideIcons.x, '닫기', onClose!),
        ],
      ),
    );
  }
}
