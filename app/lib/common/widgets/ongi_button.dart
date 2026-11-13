import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';
import 'press_scale.dart';

enum OngiButtonVariant { primary, secondary, onDark }

/// 주 버튼과 보조 버튼. [onPressed]가 null이면 비활성으로 보인다.
/// 누르면 0.97로 살짝 작아지고 가볍게 진동한다.
class OngiButton extends StatelessWidget {
  const OngiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = OngiButtonVariant.primary,
    this.icon,
  });

  const OngiButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : variant = OngiButtonVariant.secondary;

  /// 어두운 카드 위에 놓는 밝은 버튼
  const OngiButton.onDark({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  }) : variant = OngiButtonVariant.onDark;

  final String label;
  final VoidCallback? onPressed;
  final OngiButtonVariant variant;
  final IconData? icon;

  bool get _isPrimary => variant == OngiButtonVariant.primary;

  Color _background(Set<WidgetState> states) {
    if (variant == OngiButtonVariant.onDark) {
      return states.contains(WidgetState.pressed)
          ? AppColors.bgSoft
          : AppColors.bgBase;
    }
    if (_isPrimary) {
      if (states.contains(WidgetState.disabled)) {
        return AppColors.textPrimary.withValues(
          alpha: AppSizes.disabledOpacity,
        );
      }
      return states.contains(WidgetState.pressed)
          ? AppColors.primaryPressed
          : AppColors.textPrimary;
    }
    return states.contains(WidgetState.pressed)
        ? AppColors.bgSoft
        : AppColors.surface;
  }

  Color _foreground(Set<WidgetState> states) {
    if (variant == OngiButtonVariant.onDark) return AppColors.textPrimary;
    if (_isPrimary) return AppColors.bgBase;
    return states.contains(WidgetState.disabled)
        ? AppColors.textPrimary.withValues(alpha: AppSizes.disabledOpacity)
        : AppColors.textPrimary;
  }

  BorderSide? _border(Set<WidgetState> states) {
    if (variant != OngiButtonVariant.secondary) return BorderSide.none;
    return BorderSide(
      color: states.contains(WidgetState.disabled)
          ? AppColors.line.withValues(alpha: AppSizes.disabledOpacity)
          : AppColors.line,
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight,
      child: TextButton(
        onPressed: onPressed == null
            ? null
            : () {
                tapHaptic();
                onPressed!();
              },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(_background),
          foregroundColor: WidgetStateProperty.resolveWith(_foreground),
          side: WidgetStateProperty.resolveWith(_border),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          textStyle: WidgetStatePropertyAll(AppTextStyles.label16),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.s8),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
    if (variant == OngiButtonVariant.onDark && onPressed == null) {
      return Opacity(opacity: AppSizes.disabledOpacity, child: button);
    }

    /// 누르는 동안 살짝 작아지고, 누르면 가볍게 진동한다
    return PressScale(enabled: onPressed != null, child: button);
  }
}
