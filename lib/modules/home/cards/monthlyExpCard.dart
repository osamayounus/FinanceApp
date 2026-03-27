import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/modules/history/historyPage.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MonthlyExpCard extends ConsumerWidget {
  const MonthlyExpCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final balance = ref
        .watch(accountsProvider)
        .firstWhere((a) => a.id == kBudgetId)
        .balance;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.budgetCardStart, AppColors.budgetCardEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
                top: -28,
                right: -18,
                child: cardBgCircle(130, 0.12, Colors.white)),
            Positioned(
                top: 18,
                right: 52,
                child: cardBgCircle(70, 0.08, Colors.white)),
            Positioned(
                bottom: -40,
                left: -20,
                child: cardBgCircle(110, 0.06, Colors.white)),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.m,
                vertical: AppSizes.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: AppSizes.cardIconBoxSize,
                        height: AppSizes.cardIconBoxSize,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusM),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: AppSizes.iconM,
                        ),
                      ),
                      SizedBox(width: AppSizes.s),
                      Text(
                        AppStrings.monthlyBudget,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontS,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  Text(
                    AppStrings.remaining,
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontXS,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        balance % 1 == 0
                            ? '${balance.toInt()}'
                            : balance.toStringAsFixed(2),
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.cardBalanceSize,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: AppSizes.s),
                      Text(
                        currency,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontM,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  CardActionButton(
                    label: AppStrings.history,
                    icon: Icons.history_rounded,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    foregroundColor: Colors.white,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Historypage(
                          accountId: kBudgetId,
                          accountName: AppStrings.monthlyBudget,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
