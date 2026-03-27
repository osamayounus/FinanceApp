import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppSizes {
  // Padding / Spacing
  static double get xs => 4.r;
  static double get s => 8.r;
  static double get m => 16.r;
  static double get l => 24.r;
  static double get xl => 32.r;
  static double get xxl => 48.r;

  // Border Radius
  static double get radiusS => 8.r;
  static double get radiusM => 12.r;
  static double get radiusL => 16.r;
  static double get radiusXL => 20.r;
  static double get radiusXXL => 25.r;

  // Button
  static double get buttonHeight => 50.r;

  // Icons
  static double get iconS => 18.r;
  static double get iconM => 24.r;
  static double get iconL => 32.r;
  static double get iconXL => 48.r;

  // Font sizes
  static double get fontXS => 12.sp;
  static double get fontS => 14.sp;
  static double get fontM => 16.sp;
  static double get fontL => 18.sp;
  static double get fontXL => 20.sp;
  static double get fontXXL => 22.sp;
  static double get fontTitle => 30.sp;
  static double get fontSection => 11.sp; // uppercase section headers

  // Specific component sizes
  static double get cardBalanceSize => 38.sp; // large balance number in cards
  static double get handleBarWidth => 40.r;   // modal bottom sheet handle
  static double get handleBarHeight => 4.r;
  static double get cardIconBoxSize => 36.r;  // icon container in card header
}
