// ── components.dart ───────────────────────────────────────────────────────────
// Shared UI component library — re-exported and used across all feature pages.
// Contains: ModalHandle, SectionLabel, CardActionButton, cardBgCircle.
// TransactionCard is re-exported from transaction_card.dart.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';

export 'transaction_card.dart';

// ── Modal handle bar ──────────────────────────────────────────────────────────

class ModalHandle extends StatelessWidget {
  const ModalHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppSizes.handleBarWidth,
        height: AppSizes.handleBarHeight,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

/// Uppercase section header used above grouped content (e.g. 'PERSONAL INFO').
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: AppSizes.xs),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Rubik',
          fontSize: AppSizes.fontSection,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}

// ── Card background circle ────────────────────────────────────────────────────

/// Decorative translucent circle used in the card background Stack.
Widget cardBgCircle(double size, double opacity, Color baseColor) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: baseColor.withValues(alpha: opacity),
      ),
    );

// ── Card action button ────────────────────────────────────────────────────────

/// Button shown at the bottom of account cards (History, Bills, etc.).
/// Pass [backgroundColor] and [foregroundColor] to match the card theme.
class CardActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;

  const CardActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: AppSizes.s + 2, horizontal: AppSizes.s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foregroundColor, size: AppSizes.iconS),
                SizedBox(width: AppSizes.xs + 2),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontS,
                    fontWeight: FontWeight.w600,
                    color: foregroundColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── App Toast ─────────────────────────────────────────────────────────────────

class AppToast {
  static void success(ScaffoldMessengerState messenger, String message) =>
      _show(messenger, message, isSuccess: true);

  static void error(ScaffoldMessengerState messenger, String message) =>
      _show(messenger, message, isSuccess: false);

  static void _show(
    ScaffoldMessengerState messenger,
    String message, {
    required bool isSuccess,
  }) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isSuccess ? AppColors.myGreen : AppColors.myRed)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess
                      ? Icons.check_rounded
                      : Icons.error_outline_rounded,
                  color: isSuccess ? AppColors.myGreen : AppColors.myRed,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontWeight: FontWeight.w600,
                    fontSize: AppSizes.fontS,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            side: BorderSide(
              color: (isSuccess ? AppColors.myGreen : AppColors.myRed)
                  .withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

class LightButton extends StatelessWidget {
  final double width;
  final String text;
  final Color textColor;
  final VoidCallback onPressed;

  const LightButton({
    super.key,
    required this.width,
    required this.text,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: AppSizes.buttonHeight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppSizes.fontM,
            fontFamily: 'Rubik',
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class DarkButton extends StatelessWidget {
  final double width;
  final String text;
  final VoidCallback onPressed;

  const DarkButton({
    super.key,
    required this.width,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: AppSizes.buttonHeight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppSizes.fontM,
            fontFamily: 'Rubik',
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
      ),
    );
  }
}
