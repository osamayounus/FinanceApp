// ── IncomeCard ────────────────────────────────────────────────────────────────
// Wallet account swiper card. Shows the current Wallet balance and provides
// quick-link buttons to Transaction History and the Bills (FixedExpenses) page.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/modules/fixedExp/FixedExpensesPage.dart';
import 'package:financeapp/modules/history/historyPage.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IncomeCard extends ConsumerWidget {
  const IncomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final account = ref
        .watch(accountsProvider)
        .firstWhere((a) => a.id == kWalletId);
    final balance = account.balance;
    final loaned = account.loanedAmount;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.walletCardStart, AppColors.walletCardEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.14),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Background decoration circles ───────────────────────────────
            Positioned(
                top: -28,
                right: -18,
                child: cardBgCircle(130, 0.18, AppColors.primary)),
            Positioned(
                top: 18,
                right: 52,
                child: cardBgCircle(70, 0.12, AppColors.primary)),
            Positioned(
                bottom: -40,
                left: -20,
                child: cardBgCircle(110, 0.10, AppColors.primary)),

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
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusM),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.primary,
                          size: AppSizes.iconM,
                        ),
                      ),
                      SizedBox(width: AppSizes.s),
                      Text(
                        AppStrings.wallet,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontS,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary.withValues(alpha: 0.6),
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
                    label: AppStrings.balance,
                    mainColor: AppColors.primary,
                    subColor: AppColors.primary.withValues(alpha: 0.45),
                  ),

                  const Spacer(),

                  // ── Action buttons: History + Bills ──────────────────
                  Row(
                    children: [
                      Expanded(
                        child: CardActionButton(
                          label: AppStrings.history,
                          icon: Icons.history_rounded,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.07),
                          foregroundColor: AppColors.primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Historypage(
                                accountId: kWalletId,
                                accountName: AppStrings.wallet,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSizes.s),
                      Expanded(
                        child: CardActionButton(
                          label: AppStrings.bills,
                          icon: Icons.receipt_long_rounded,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.07),
                          foregroundColor: AppColors.primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const Fixedexpensespage()),
                          ),
                        ),
                      ),
                    ],
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
