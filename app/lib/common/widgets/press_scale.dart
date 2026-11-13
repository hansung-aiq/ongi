import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_motion.dart';

/// 누르는 동안 살짝(0.97) 작아졌다가 떼면 돌아온다. 버튼 공통.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// false면 움직이지 않는다(비활성 버튼).
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AppMotion.press,
        curve: AppMotion.enterCurve,
        child: widget.child,
      ),
    );
  }
}

/// 가벼운 진동. 에뮬레이터·시험에서는 아무 일도 없다.
void tapHaptic({bool strong = false}) {
  final f = strong
      ? HapticFeedback.mediumImpact()
      : HapticFeedback.lightImpact();
  f.catchError((Object _) {});
}
