import 'package:flutter/material.dart';

import '../common/common.dart';

enum MessageMenuAction { edit, delete }

/// 6-2 메시지 수정·삭제 메뉴. 고른 행동을, 닫으면 null을 돌려준다.
Future<MessageMenuAction?> showMessageMenu(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<MessageMenuAction>(
    context: context,
    backgroundColor: AppColors.bgBase,
    barrierColor: const Color(0x661A140F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.s12,
          AppSpacing.screenHorizontal,
          AppSpacing.s8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.s12),
              child: Center(child: SheetHandle()),
            ),
            Text(
              title,
              style: AppTextStyles.subtitle18.copyWith(height: 22 / 18),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              '이 메시지를 어떻게 할까요?',
              style: AppTextStyles.body14.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            _MenuItem(
              label: '수정하기',
              style: AppTextStyles.label16,
              padding: const EdgeInsets.only(top: 20, bottom: 16),
              onTap: () => Navigator.of(context).pop(MessageMenuAction.edit),
            ),
            _MenuItem(
              label: '삭제하기',
              style: AppTextStyles.label16.copyWith(color: AppColors.error),
              onTap: () => Navigator.of(context).pop(MessageMenuAction.delete),
            ),
            _MenuItem(
              label: '닫기',
              style: AppTextStyles.body16.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.6),
                height: 19 / 16,
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.style,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.s16),
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Text(label, style: style),
        ),
      ),
    );
  }
}
