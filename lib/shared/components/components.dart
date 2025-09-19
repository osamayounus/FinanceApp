import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Widget LightButton(
      {
        required double width,
        required String text,
        required Color textColor,
        required VoidCallback onPressed,
      }
    ) =>
    SizedBox(
  width: width,
  height: 50,
  child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
            fontSize: 16,
            fontFamily: 'Rubik',
            fontWeight: FontWeight.bold,
            color: textColor
        ),
      )
  ),
);

Widget DarkButton(
    {
      required double width,
      required String text,
      required VoidCallback onPressed,
    }
    ) =>
    SizedBox(
      width: width,
      height: 50,
      child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            text,
            style: TextStyle(
                fontSize: 16,
                fontFamily: 'Rubik',
                fontWeight: FontWeight.bold,
                color: AppColors.secondary
            ),
          )
      ),
    );

class TransactionCard extends StatelessWidget {
  final String type; // Withdraw, Deposit, Transfer
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
    Color bgColor;
    Icon icon;
    Color iconColor;
    Color textColor;

    switch (type.toLowerCase()) {
      case 'withdraw':
        bgColor = Colors.red.shade50;
        iconColor = Colors.red;
        textColor = Colors.black87;
        icon = Icon(Icons.attach_money, color: iconColor, size: 35);
        break;
      case 'deposit':
        bgColor = Colors.green.shade50;
        iconColor = Colors.green;
        textColor = Colors.black87;
        icon = Icon(Icons.attach_money, color: iconColor, size: 35);
        break;
      case 'transfer':
        bgColor = Colors.grey.shade200;
        iconColor = Colors.black54;
        textColor = Colors.black87;
        icon = Icon(Icons.sync_alt, color: iconColor, size: 35);
        break;
      default:
        bgColor = Colors.grey.shade100;
        iconColor = Colors.grey;
        textColor = Colors.black;
        icon = Icon(Icons.help_outline, color: iconColor, size: 35);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: icon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$type  ${amount.toStringAsFixed(0)} JOD',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(dateTime),
                style: TextStyle(fontSize: 12, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(dateTime),
                style: TextStyle(fontSize: 12, color: textColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${_monthName(dt.month)} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }
}