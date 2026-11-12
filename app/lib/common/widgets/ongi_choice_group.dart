import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';

/// 여러 개 중 하나를 고르는 둥근 버튼 묶음 (호칭 선택 등).
/// 버튼들은 같은 너비로 한 줄을 나눠 갖는다.
class OngiChoiceGroup extends StatelessWidget {
  const OngiChoiceGroup({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> options;

  /// 아무것도 고르지 않았으면 null
  final int? selectedIndex;
  final ValueChanged<int> onChanged;

  static const _height = 44.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.s8),
          Expanded(child: _option(i)),
        ],
      ],
    );
  }

  Widget _option(int index) {
    final selected = index == selectedIndex;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.textPrimary : AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.textPrimary : AppColors.line,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(index),
          child: SizedBox(
            height: _height,
            child: Center(
              child: Text(
                options[index],
                overflow: TextOverflow.ellipsis,
                style: selected
                    ? AppTextStyles.label14.copyWith(color: AppColors.bgBase)
                    : AppTextStyles.label14.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
