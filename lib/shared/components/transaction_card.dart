import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A row card representing a single transaction in a list.
/// Reads the current currency symbol from Riverpod to format the amount.
class TransactionCard extends ConsumerWidget {
  final String type;
  final double amount;
  final String description;
  final String? subtitle;
  final String? note;
  final DateTime dateTime;

  const TransactionCard({
    super.key,
    required this.type,
    required this.amount,
    required this.description,
    this.subtitle,
    this.note,
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
          // Icon badge whose appearance is determined by transaction type
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
          // Description + optional subtitle (e.g. counterpart account) + timestamp
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
                if (note != null && note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: 11,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: AppSizes.fontXS,
                            color: Colors.grey[400],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
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
          // Signed amount (e.g. '+ 500 SAR', '- 200 SAR', '500 SAR' for transfers)
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

/// Maps a transaction type string to its display properties (icon, colors, sign).
/// The default case handles unknown/legacy types gracefully.
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
      case 'debt out':
        return _TxStyle(
          icon: Icons.handshake_outlined,
          iconColor: const Color(0xFFFF8F00),
          iconBg: const Color(0xFFFF8F00).withValues(alpha: 0.1),
          amountColor: const Color(0xFFFF8F00),
          sign: '- ',
        );
      case 'debt back':
        return _TxStyle(
          icon: Icons.handshake_outlined,
          iconColor: Colors.teal,
          iconBg: Colors.teal.withValues(alpha: 0.1),
          amountColor: Colors.teal,
          sign: '+ ',
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
