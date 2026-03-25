import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';

class AppTextStyles {
  // Light backgrounds (dark text)
  static TextStyle get titleDark => TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontTitle,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static TextStyle get headingDark => TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontXXL,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static TextStyle get bodyDark => TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontM,
    color: AppColors.primary,
  );

  // Dark backgrounds (light text)
  static TextStyle get titleLight => TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontTitle,
    fontWeight: FontWeight.bold,
    color: AppColors.secondary,
  );

  static TextStyle get headingLight => TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontXXL,
    fontWeight: FontWeight.bold,
    color: AppColors.secondary,
  );

  static TextStyle get bodyLight => TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontM,
    color: AppColors.secondary,
  );

  static TextStyle get labelLight => TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontS,
    color: AppColors.secondary,
  );

  static TextStyle get subtleLight => TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontXL,
    color: Colors.white54,
  );

  // Buttons
  static TextStyle get buttonLight => TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontM,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static TextStyle get buttonDark => TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontM,
    fontWeight: FontWeight.bold,
    color: AppColors.secondary,
  );
}
