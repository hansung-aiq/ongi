import 'package:flutter/material.dart';

import '../keep_words.dart';

/// 말하는 것처럼 한 글자씩 나타나는 글 (5-3 받아쓴 말, 5-4 공감, 5-6 받아주는 말).
/// 아직 안 나온 글자는 투명하게 자리를 차지해서 줄바꿈과 높이가 흔들리지 않는다.
/// 글이 바뀌면 처음부터 다시 나타난다. '애니메이션 줄이기'가 켜져 있으면 바로 다 보인다.
class TypingText extends StatelessWidget {
  const TypingText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.center,
    this.perChar = const Duration(milliseconds: 60),
    this.maxDuration = const Duration(milliseconds: 1800),
    this.delay = Duration.zero,
    this.strutStyle,
  });

  /// 편지지 가로줄과 맞추려고 줄 높이를 고정할 때 쓴다
  final StrutStyle? strutStyle;

  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  /// 한 글자에 걸리는 시간
  final Duration perChar;

  /// 글이 길어도 이 시간 안에 다 나온다
  final Duration maxDuration;

  /// 화면 전환이 끝난 뒤 시작하도록 기다리는 시간
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final full = keepWords(text);
    final chars = full.characters;
    final length = chars.length;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return Text(
        full,
        textAlign: textAlign,
        style: style,
        strutStyle: strutStyle,
      );
    }
    final typing = perChar * length;
    final total = delay + (typing > maxDuration ? maxDuration : typing);
    final start = total.inMicroseconds == 0
        ? 0.0
        : delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, t, _) {
        final p = start >= 1
            ? 1.0
            : ((t - start) / (1 - start)).clamp(0.0, 1.0);
        final shown = (p * length).round();
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: chars.take(shown).toString()),
              TextSpan(
                text: chars.skip(shown).toString(),
                style: style.copyWith(color: Colors.transparent),
              ),
            ],
          ),
          textAlign: textAlign,
          style: style,
          strutStyle: strutStyle,
        );
      },
    );
  }
}
