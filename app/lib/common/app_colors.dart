import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const bgBase = Color(0xFFFFFDF7);
  static const bgSoft = Color(0xFFFAF3E8);
  static const surface = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF1F1A17);
  static const textSecondary = Color(0xFF6B5D4F);
  static const textOnDarkSecondary = Color(0xFFD7CBBE);

  static const line = Color(0xFFEADFCF);

  /// 편지지(5-5 재생, 3-4 작성, 5-7 온기기록). 바탕보다 아주 조금 따뜻한 종이색과 옅은 줄
  static const paper = Color(0xFFFFFBF2);
  static const paperRule = Color(0xFFF1E6D3);

  /// 우표처럼 보이는 상황 이름 칩
  static const stampBg = Color(0xFFFFF3E0);
  static const stampText = Color(0xFF9A5B12);
  static const accent = Color(0xFFF5A623);

  static const error = Color(0xFFC8442E);
  static const errorSoft = Color(0xFFFBECE8);

  /// 가이드에는 없고 화면 CSS에만 있는 색
  static const iconInactive = Color(0xFFAD9E8C);
  static const micThinking = Color(0xFF523829);
  static const dotOffline = Color(0xFF9E9991);

  /// 아래에서 올라오는 창(6-2)의 손잡이
  static const sheetHandle = Color(0xFFD9D1C7);

  /// 메뉴를 연 메시지 카드(6-2)의 배경
  static const errorTint = Color(0xFFFFF4F1);

  /// 주 버튼을 눌렀을 때의 배경
  static const primaryPressed = Color(0xFF3D332D);
}
