import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';

/// 음성 파형. 막대 높이는 디자인의 값을 쓴다.
class Waveform extends StatefulWidget {
  /// 듣는 중 화면의 큰 파형
  const Waveform.large({super.key, this.animate = true, this.opacity = 1})
    : width = 200,
      height = 80,
      barWidth = 4,
      scale = 1;

  /// 공감·재생 화면의 작은 파형
  /// [width]를 넓히면 막대 사이만 벌어진다.
  const Waveform.small({
    super.key,
    this.animate = true,
    this.opacity = 1,
    this.width = 170,
  }) : height = 30,
       barWidth = 3,
       scale = 0.48;

  /// 메시지 카드(6-2) 재생 줄의 아주 작은 파형
  const Waveform.mini({super.key, this.animate = false, this.opacity = 1})
    : width = 65,
      height = 24,
      barWidth = 2,
      scale = 0.45;

  final double width;
  final double height;
  final double barWidth;
  final double scale;
  final bool animate;
  final double opacity;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  // dart format off
  static const _bars = <double>[
    9, 18, 12, 28, 38, 22, 45, 30, 16, 36, 49, 24, 40, 19, 28, 12, 20, 8,
  ];
  // dart format on

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool get _moving =>
      widget.animate &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(Waveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_moving) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _barHeight(int index) {
    final base = _bars[index] * widget.scale;
    if (!_moving) return base;
    final phase = _controller.value * 2 * math.pi + index * 0.7;
    final height = base * (1 + 0.3 * math.sin(phase));
    return math.min(height, widget.height);
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Opacity(
        opacity: widget.opacity,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < _bars.length; i++)
                  Container(
                    width: widget.barWidth,
                    height: _barHeight(i),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(widget.barWidth),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
