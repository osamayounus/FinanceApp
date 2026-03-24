import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';

class Historypage extends StatelessWidget {
  final String pageName;

  const Historypage(this.pageName, {super.key});

  // ── Data: type + amount + description + dateTime in one place ────────────
  static final List<Map<String, dynamic>> _transactions = [
    {'type': 'Withdraw',  'amount': 5.0,   'description': 'I bought a Book',       'dateTime': DateTime(2025, 5, 27, 17, 30)},
    {'type': 'Deposit',   'amount': 20.0,  'description': 'Sold Old Laptop',        'dateTime': DateTime(2025, 5, 26, 10, 15)},
    {'type': 'Transfer',  'amount': 10.0,  'description': 'To Saving Account',      'dateTime': DateTime(2025, 5, 25, 15, 45)},
    {'type': 'Withdraw',  'amount': 7.5,   'description': 'Dinner at Restaurant',   'dateTime': DateTime(2025, 5, 24, 20,  0)},
    {'type': 'Deposit',   'amount': 100.0, 'description': 'Salary Payment',         'dateTime': DateTime(2025, 5, 24,  9,  0)},
    {'type': 'Withdraw',  'amount': 15.0,  'description': 'Bought Groceries',       'dateTime': DateTime(2025, 5, 23, 18, 30)},
    {'type': 'Deposit',   'amount': 30.0,  'description': 'Returned Item Refund',   'dateTime': DateTime(2025, 5, 22, 12, 45)},
    {'type': 'Transfer',  'amount': 8.0,   'description': 'To Investment Account',  'dateTime': DateTime(2025, 5, 21, 14, 20)},
    {'type': 'Withdraw',  'amount': 3.0,   'description': 'Coffee with friends',    'dateTime': DateTime(2025, 5, 20, 19, 10)},
    {'type': 'Deposit',   'amount': 60.0,  'description': 'Freelance Project',      'dateTime': DateTime(2025, 5, 19, 13, 50)},
    {'type': 'Withdraw',  'amount': 12.0,  'description': 'Cinema Ticket',          'dateTime': DateTime(2025, 5, 18, 21, 15)},
    {'type': 'Transfer',  'amount': 25.0,  'description': 'To Family Support',      'dateTime': DateTime(2025, 5, 17, 11, 30)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.s,
                vertical: AppSizes.s,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.primary,
                      size: AppSizes.iconM,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$pageName History',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: AppSizes.fontXXL,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  // Balance placeholder to keep title centered
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── List ─────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.m,
                  vertical: AppSizes.s,
                ),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final tx = _transactions[index];
                  return TransactionCard(
                    type: tx['type'] as String,
                    amount: tx['amount'] as double,
                    description: tx['description'] as String,
                    dateTime: tx['dateTime'] as DateTime,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
