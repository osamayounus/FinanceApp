import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';

class AppTextStyles {
  // Light backgrounds (dark text)
  static const TextStyle titleDark = TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontTitle,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const TextStyle headingDark = TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontXXL,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const TextStyle bodyDark = TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontM,
    color: AppColors.primary,
  );

  // Dark backgrounds (light text)
  static const TextStyle titleLight = TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontTitle,
    fontWeight: FontWeight.bold,
    color: AppColors.secondary,
  );

  static const TextStyle headingLight = TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontXXL,
    fontWeight: FontWeight.bold,
    color: AppColors.secondary,
  );

  static const TextStyle bodyLight = TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontM,
    color: AppColors.secondary,
  );

  static const TextStyle labelLight = TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontS,
    color: AppColors.secondary,
  );

  static const TextStyle subtleLight = TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontXL,
    color: Colors.white54,
  );

  // Buttons
  static const TextStyle buttonLight = TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontM,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const TextStyle buttonDark = TextStyle(
    fontFamily: 'Rubik',
    fontSize: AppSizes.fontM,
    fontWeight: FontWeight.bold,
    color: AppColors.secondary,
  );
}
