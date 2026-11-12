import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 분류 카드(3-1)의 아이콘. 키는 서버(API-02)의 category다.
const _categoryIcons = <String, IconData>{
  '학교·학업': LucideIcons.bookOpen,
  '관계·비교': LucideIcons.usersRound,
  '감정·일상': LucideIcons.heart,
  '가족·기념일': LucideIcons.gift,
};

IconData categoryIcon(String category) =>
    _categoryIcons[category] ?? LucideIcons.heart;

/// 서버의 '학교·학업'을 디자인처럼 '학교 · 학업'으로 띄워 쓴다.
String categoryLabel(String category) => category.replaceAll('·', ' · ');
