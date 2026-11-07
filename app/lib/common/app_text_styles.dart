import 'package:flutter/material.dart';

import 'app_colors.dart';


class AppTextStyles {
  AppTextStyles._();

  static const fontFamily = 'Pretendard';

  static const _base = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.textPrimary,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static final display40 = _base.copyWith(
    fontSize: 40,
    fontWeight: FontWeight.w700,
  );
  static final title28 = _base.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  static final heading20 = _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.5,
  );
  static final subtitle18 = _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );
  static final body18 = _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static final label16 = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static final body16 = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static final label14 = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
  static final body14 = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static final label13 = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
  static final label12 = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
  static final caption12 = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
}
