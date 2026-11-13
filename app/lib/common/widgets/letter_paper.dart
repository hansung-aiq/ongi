import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_text_styles.dart';

/// 편지지. 종이색 바탕에 글 줄 간격과 맞춘 옅은 가로줄을 긋는다.
/// 줄과 글이 맞도록 안의 글에는 [strut]를 쓴다.
class LetterPaper extends StatelessWidget {
  const LetterPaper({
    super.key,
    required this.child,
    required this.lineHeight,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.s20,
      AppSpacing.s16,
      AppSpacing.s20,
      AppSpacing.s16,
    ),
    this.ruled = true,
    this.borderColor = AppColors.line,
    this.borderWidth = AppSizes.borderDefault,
    this.ruleBottom = 0,
  });

  /// 아래쪽에서 이만큼은 줄을 긋지 않는다(글자 수 같은 줄 아래 칸)
  final double ruleBottom;

  final Widget child;

  /// 글 한 줄 높이(글자 크기 × 줄 높이). 가로줄 간격이 된다.
  final double lineHeight;
  final EdgeInsets padding;
  final bool ruled;
  final Color borderColor;
  final double borderWidth;

  /// 글 줄 높이를 [lineHeight]에 고정한다(가로줄과 글이 어긋나지 않게).
  static StrutStyle strut(TextStyle style) => StrutStyle(
    fontSize: style.fontSize,
    height: style.height,
    forceStrutHeight: true,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: CustomPaint(
        painter: ruled
            ? _RulePainter(
                lineHeight: lineHeight,
                top: padding.top,
                bottom: padding.bottom + ruleBottom,
              )
            : null,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _RulePainter extends CustomPainter {
  _RulePainter({
    required this.lineHeight,
    required this.top,
    required this.bottom,
  });

  final double lineHeight;
  final double top;
  final double bottom;

  @override
  void paint(Canvas canvas, Size size) {
    if (lineHeight <= 0) return;
    final paint = Paint()
      ..color = AppColors.paperRule
      ..strokeWidth = 1;
    const inset = AppSpacing.s12;
    for (
      var y = top + lineHeight;
      y <= size.height - bottom + 1;
      y += lineHeight
    ) {
      canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), paint);
    }
  }

  @override
  bool shouldRepaint(_RulePainter old) =>
      old.lineHeight != lineHeight || old.top != top || old.bottom != bottom;
}

/// 편지 머리 "민준이에게"
class LetterTo extends StatelessWidget {
  const LetterTo(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.label14.copyWith(color: AppColors.textSecondary),
    );
  }
}

/// 편지 끝 서명 "아빠가". 오른쪽 아래에 주황빛으로.
class LetterFrom extends StatelessWidget {
  const LetterFrom(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: AppTextStyles.label14.copyWith(color: AppColors.stampText),
    );
  }
}

/// 우표처럼 보이는 작은 칩(상황 이름). 점선 테두리.
class StampChip extends StatelessWidget {
  const StampChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.stampBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption12.copyWith(
            color: AppColors.stampText,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 6) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => false;
}

/// 편지 아래쪽 점선(받은 날 위)
class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashLinePainter()),
    );
  }
}

class _DashLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 3, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashLinePainter old) => false;
}
