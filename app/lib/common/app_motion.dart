import 'package:flutter/material.dart';

/// 움직임 값 모음. 화면마다 따로 정하지 않고 여기 값만 쓴다.
/// 온기 무드: 튀지 않고 부드럽게 떠오르는 움직임.
class AppMotion {
  AppMotion._();

  /// 탭 바꾸기처럼 짧은 교차
  static const fast = Duration(milliseconds: 180);

  /// 화면이 바뀌는 기본 시간
  static const normal = Duration(milliseconds: 320);

  /// 나가는 쪽은 조금 더 빨리
  static const exit = Duration(milliseconds: 200);

  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;

  /// 페이드 + 아래에서 살짝(화면 높이의 4%) 떠오르기. 자녀 대화 화면 사이에 쓴다.
  static Widget fadeRise(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: enterCurve,
      reverseCurve: exitCurve,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// 부모 화면 이동(화면 push): 오른쪽에서 6% 밀려 들어오며 페이드.
/// 안드로이드 기본 줌 대신 "다음 장으로 넘기는" 느낌. 테마에서 모든 MaterialPageRoute에 적용된다.
class OngiPageTransitionsBuilder extends PageTransitionsBuilder {
  const OngiPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.normal;

  @override
  Duration get reverseTransitionDuration => AppMotion.exit;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enterCurve,
      reverseCurve: AppMotion.exitCurve,
    );
    // 뒤에 깔리는 화면은 왼쪽으로 조금 밀리고 살짝 흐려진다
    final under = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.enterCurve,
    );
    return SlideTransition(
      position: Tween(
        begin: Offset.zero,
        end: const Offset(-0.04, 0),
      ).animate(under),
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(enter),
          child: child,
        ),
      ),
    );
  }
}
