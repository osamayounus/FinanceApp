import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';

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
          style: const TextStyle(
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

class TransactionCard extends StatelessWidget {
  final String type;
  final double amount;
  final String description;
  final DateTime dateTime;

  const TransactionCard({
    super.key,
    required this.type,
    required this.amount,
    required this.description,
    required this.dateTime,
  });

  @override
  Widget build(BuildContext context) {
    final _TxStyle style = _TxStyle.of(type);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.s + 4),
      padding: const EdgeInsets.symmetric(
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
          const SizedBox(width: AppSizes.m),
          // Description + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Rubik',
                    fontWeight: FontWeight.w600,
                    fontSize: AppSizes.fontM,
                    color: AppColors.primary,
                  ),
                ),
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
          const SizedBox(width: AppSizes.s),
          // Amount
          Text(
            '${style.sign}${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 1)} JOD',
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
