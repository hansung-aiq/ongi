import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_colors.dart';
import '../app_motion.dart';

/// 듣는 중·생각하는 중 화면 마이크.
/// [breathe]면 안쪽 원이 숨 쉬듯 커졌다 작아지고(1.0↔1.06),
/// 바깥으로 옅은 주황 원이 퍼지며 사라진다. 듣는 중(5-2)에만 쓴다.
class MicHalo extends StatefulWidget {
  const MicHalo({
    super.key,
    this.color = AppColors.textPrimary,
    this.size = 156,
    this.breathe = false,
  });

  final Color color;

  /// 바깥 원 지름
  final double size;

  /// 숨쉬기 움직임. 반복 애니메이션이라 시험에서는 pumpAndSettle 대신 pump를 쓴다.
  final bool breathe;

  @override
  State<MicHalo> createState() => _MicHaloState();
}

class _MicHaloState extends State<MicHalo> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: AppMotion.breath,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MicHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.breathe && !reduce) {
      if (!_breath.isAnimating) _breath.repeat();
    } else {
      _breath
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final inner = size * 120 / 156;
    final mic = Container(
      width: inner,
      height: inner,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      child: Icon(
        LucideIcons.mic,
        size: size * 48 / 156,
        color: AppColors.bgBase,
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, _) {
          final t = _breath.value;

          /// 0→1→0 숨 (한 바퀴에 한 번)
          final wave = Curves.easeInOutSine.transform(
            t < 0.5 ? t * 2 : (1 - t) * 2,
          );
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              /// 퍼지는 원: 안쪽 원 크기에서 바깥 원보다 조금 더 크게 번지며 옅어진다
              if (widget.breathe)
                Container(
                  width: inner + (size * 1.15 - inner) * t,
                  height: inner + (size * 1.15 - inner) * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.22 * (1 - t)),
                  ),
                ),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.line),
                ),
              ),
              Transform.scale(scale: 1 + 0.06 * wave, child: mic),
            ],
          );
        },
      ),
    );
  }
}
