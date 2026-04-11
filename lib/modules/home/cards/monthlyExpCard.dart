// ── MonthlyExpCard ────────────────────────────────────────────────────────────
// Monthly Budget account swiper card. Shows the remaining budget balance and
// a quick-link button to Transaction History.
// ─────────────────────────────────────────────────────────────────────────────
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
    final account = ref
        .watch(accountsProvider)
        .firstWhere((a) => a.id == kBudgetId);
    final balance = account.balance;
    final loaned = account.loanedAmount;

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
            // ── Background decoration circles ───────────────────────────────
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
                  // ── Header row: icon + account name ─────────────────────
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

                  // ── Balance section (single or dual when debt exists) ──
                  CardBalanceSection(
                    available: balance,
                    loanedAmount: loaned,
                    currency: currency,
                    label: AppStrings.remaining,
                    mainColor: Colors.white,
                    subColor: Colors.white.withValues(alpha: 0.65),
                  ),

                  const Spacer(),

                  // ── Action button: History ───────────────────────────
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
