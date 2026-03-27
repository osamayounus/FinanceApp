import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class TransactionCard extends ConsumerWidget {
  final String type;
  final double amount;
  final String description;
  final String? subtitle;
  final DateTime dateTime;

  const TransactionCard({
    super.key,
    required this.type,
    required this.amount,
    required this.description,
    this.subtitle,
    required this.dateTime,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final _TxStyle style = _TxStyle.of(type);

    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.s + 4),
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.m,
        vertical: AppSizes.m - 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: style.iconBg,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Icon(style.icon, color: style.iconColor, size: AppSizes.iconM),
          ),
          SizedBox(width: AppSizes.m),
          // Description + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontWeight: FontWeight.w600,
                    fontSize: AppSizes.fontM,
                    color: AppColors.primary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontXS,
                      fontWeight: FontWeight.w500,
                      color: Colors.blueAccent.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  '${_formatDate(dateTime)}  ·  ${_formatTime(dateTime)}',
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontXS,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSizes.s),
          // Amount
          Text(
            '${style.sign}${fmtAmt(amount, currency)}',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontWeight: FontWeight.bold,
              fontSize: AppSizes.fontM,
              color: style.amountColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }
}

// ── Transaction style helper ──────────────────────────────────────────────────

class _TxStyle {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color amountColor;
  final String sign;

  const _TxStyle({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.amountColor,
    required this.sign,
  });

  factory _TxStyle.of(String type) {
    switch (type.toLowerCase()) {
      case 'withdraw':
        return _TxStyle(
          icon: Icons.arrow_upward_rounded,
          iconColor: AppColors.myRed,
          iconBg: AppColors.myRed.withValues(alpha: 0.1),
          amountColor: AppColors.myRed,
          sign: '- ',
        );
      case 'deposit':
        return _TxStyle(
          icon: Icons.arrow_downward_rounded,
          iconColor: AppColors.myGreen,
          iconBg: AppColors.myGreen.withValues(alpha: 0.1),
          amountColor: AppColors.myGreen,
          sign: '+ ',
        );
      case 'transfer':
        return _TxStyle(
          icon: Icons.swap_horiz_rounded,
          iconColor: Colors.blueAccent,
          iconBg: Colors.blueAccent.withValues(alpha: 0.1),
          amountColor: Colors.blueAccent,
          sign: '',
        );
      default:
        return _TxStyle(
          icon: Icons.help_outline,
          iconColor: Colors.grey,
          iconBg: Colors.grey.withValues(alpha: 0.1),
          amountColor: Colors.grey,
          sign: '',
        );
    }
  }
}
