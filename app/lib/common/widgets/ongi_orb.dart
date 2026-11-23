import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';

/// 온기의 상태. 빛 구슬이 상태마다 다르게 움직인다.
enum OrbMood {
  /// 기다림: 은은하게 숨 쉬기
  idle,

  /// 듣는 중: 빛 물결이 바깥으로 퍼짐
  listening,

  /// 생각하는 중: 작은 빛이 구슬 둘레를 돎
  thinking,

  /// 말하는 중: 빠르게 맥박
  speaking,
}

/// 11/23 온기 빛 구슬. 마이크 아이콘 대신 '온기'의 얼굴로 쓴다.
/// 이름 그대로 따뜻한 빛 덩어리가 아이의 말에 반응한다.
class OngiOrb extends StatefulWidget {
  const OngiOrb({
    super.key,
    this.size = 200,
    this.mood = OrbMood.idle,
    this.dim = false,
  });

  /// 그리는 영역 한 변. 구슬 자체는 이 크기의 약 56%다(나머지는 빛 번짐·물결).
  final double size;
  final OrbMood mood;

  /// 스피커가 연결되지 않았을 때처럼 흐리게
  final bool dim;

  @override
  State<OngiOrb> createState() => _OngiOrbState();
}

class _OngiOrbState extends State<OngiOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _durationFor(widget.mood),
  );

  static Duration _durationFor(OrbMood mood) => switch (mood) {
    OrbMood.idle => const Duration(milliseconds: 3200),
    OrbMood.listening => const Duration(milliseconds: 1800),
    OrbMood.thinking => const Duration(milliseconds: 1600),
    OrbMood.speaking => const Duration(milliseconds: 900),
  };

  bool get _reduce => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(restart: false);
  }

  @override
  void didUpdateWidget(OngiOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _c.duration = _durationFor(widget.mood);
      _sync(restart: true);
    }
  }

  void _sync({required bool restart}) {
    if (_reduce) {
      _c
        ..stop()
        ..value = 0.25;
    } else if (restart || !_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedOpacity(
        opacity: widget.dim ? 0.45 : 1,
        duration: const Duration(milliseconds: 320),
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _OrbPainter(t: _c.value, mood: widget.mood),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.t, required this.mood});

  final double t;
  final OrbMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.28;

    /// 0→1→0 한 번 숨
    final pulse = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
    final grow = switch (mood) {
      OrbMood.idle => 0.035,
      OrbMood.listening => 0.06,
      OrbMood.thinking => 0.02,
      OrbMood.speaking => 0.09,
    };
    final core = r * (1 + grow * pulse);

    /// 1. 바깥 빛 번짐
    final glowR = core * (1.75 + 0.12 * pulse);
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.38),
            AppColors.accent.withValues(alpha: 0.12),
            AppColors.accent.withValues(alpha: 0),
          ],
          stops: const [0.45, 0.7, 1],
        ).createShader(Rect.fromCircle(center: c, radius: glowR)),
    );

    /// 2. 듣는 중: 빛 물결 3겹이 차례로 퍼짐
    if (mood == OrbMood.listening) {
      for (var i = 0; i < 3; i++) {
        final p = (t + i / 3) % 1.0;
        canvas.drawCircle(
          c,
          core * (1.05 + 0.72 * p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.accent.withValues(alpha: 0.5 * (1 - p)),
        );
      }
    }

    /// 3. 구슬: 왼쪽 위가 밝은 빛, 아래로 짙어짐
    final coreRect = Rect.fromCircle(center: c, radius: core);
    canvas.drawCircle(
      c,
      core,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [AppColors.orbLight, AppColors.accent, AppColors.orbDeep],
          stops: [0, 0.55, 1],
        ).createShader(coreRect),
    );

    /// 4. 안쪽 하트 모양 빛(온기 로고의 하트를 아주 옅게)
    final heart = _heartPath(c.translate(0, core * 0.06), core * 0.42);
    canvas.drawPath(
      heart,
      Paint()..color = Colors.white.withValues(alpha: 0.28 + 0.12 * pulse),
    );

    /// 5. 생각하는 중: 작은 빛 두 개가 둘레를 돎
    if (mood == OrbMood.thinking) {
      final orbit = core * 1.22;
      final arc = Rect.fromCircle(center: c, radius: orbit);
      final a = t * 2 * math.pi - math.pi / 2;
      canvas.drawArc(
        arc,
        a,
        math.pi * 0.55,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3
          ..color = AppColors.accent.withValues(alpha: 0.85),
      );
      canvas.drawArc(
        arc,
        a + math.pi,
        math.pi * 0.3,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2
          ..color = AppColors.accent.withValues(alpha: 0.35),
      );
      final dot = Offset(
        c.dx + orbit * math.cos(a + math.pi * 0.55),
        c.dy + orbit * math.sin(a + math.pi * 0.55),
      );
      canvas.drawCircle(dot, 4, Paint()..color = AppColors.orbDeep);
    }

    /// 6. 반짝임
    canvas.drawCircle(
      c.translate(-core * 0.38, -core * 0.42),
      core * 0.12,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  /// 가운데가 [center], 가로 폭이 약 [w]인 하트
  static Path _heartPath(Offset center, double w) {
    final x = center.dx;
    final y = center.dy;
    final h = w * 0.9;
    return Path()
      ..moveTo(x, y + h * 0.45)
      ..cubicTo(x - w * 0.62, y + h * 0.02, x - w * 0.5, y - h * 0.55, x, y - h * 0.18)
      ..cubicTo(x + w * 0.5, y - h * 0.55, x + w * 0.62, y + h * 0.02, x, y + h * 0.45)
      ..close();
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t || old.mood != mood;
}
