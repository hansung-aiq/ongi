import 'package:flutter/material.dart';

/// 온기 로고. 크기는 48, 80, 96을 쓰고 모서리는 한 변의 22%로 둥글린다.
class OngiLogo extends StatelessWidget {
  const OngiLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/images/ongi_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: '온기',
      ),
    );
  }
}
