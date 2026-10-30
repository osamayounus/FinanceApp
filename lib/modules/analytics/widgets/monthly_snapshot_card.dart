// ── MonthlySnapshotCard ───────────────────────────────────────────────────────
// Dark gradient card showing current month income, spending, and a budget
// progress bar. Sits at the top of the analytics page below Smart Insights.

import 'package:flutter/material.dart';
import 'package:financeapp/models/analytics_model.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:financeapp/shared/utils/currency.dart';

// ── MonthlySnapshotCard ───────────────────────────────────────────────────────

class MonthlySnapshotCard extends StatelessWidget {
  final AnalyticsData data;
  final String currency;
  final double budgetBalance;
  final double monthlyBudget;

  const MonthlySnapshotCard({
    super.key,
    required this.data,
    required this.currency,
    required this.budgetBalance,
    required this.monthlyBudget,
  });

  @override
  Widget build(BuildContext context) {
    final month = data.currentMonth;
    // Clamp so we never exceed 100 % even if spending is over budget.
    final budgetUsed =
        (monthlyBudget - budgetBalance).clamp(0.0, monthlyBudget);
    final budgetPct = monthlyBudget > 0 ? budgetUsed / monthlyBudget : 0.0;
    final monthLabel =
        '${AppStrings.monthsFull[month.month]} ${month.year}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSizes.m),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.darkGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Month label (e.g. "MARCH 2026") ──────────────────────────
          Text(
            monthLabel.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontXS,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: AppSizes.xs),
          Text(
            'Monthly Snapshot',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: AppSizes.m),

          // ── Income / Spent stat boxes ─────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'Income',
                  amount: month.income,
                  currency: currency,
                  dotColor: AppColors.myGreen,
                ),
              ),
              SizedBox(width: AppSizes.s),
              Expanded(
                child: _StatBox(
                  label: 'Spent',
                  amount: month.expenses,
                  currency: currency,
                  dotColor: AppColors.myRed,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.s),

          // ── Budget progress bar ───────────────────────────────────────
          _BudgetBar(
            used: budgetUsed,
            total: monthlyBudget,
            pct: budgetPct,
            currency: currency,
          ),
        ],
      ),
    );
  }
}

// ── _StatBox ──────────────────────────────────────────────────────────────────
// Semi-transparent tile used to display a single financial figure (income or
// spending) inside the dark gradient card.

class _StatBox extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final Color dotColor;

  const _StatBox({
    required this.label,
    required this.amount,
    required this.currency,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final amountStr = fmtNum(amount, currency);

    return Container(
      padding: EdgeInsets.all(AppSizes.s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label row with colour dot ─────────────────────────────────
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              SizedBox(width: AppSizes.xs + 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontXS,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.xs),
          // ── Large amount value ────────────────────────────────────────
          Text(
            amountStr,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            currency,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontXS,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _BudgetBar ────────────────────────────────────────────────────────────────
// Linear progress indicator showing budget consumption.
// Turns red when consumption exceeds 85 % of the monthly budget.

class _BudgetBar extends StatelessWidget {
  final double used;
  final double total;
  final double pct; // 0.0 – 1.0
  final String currency;

  const _BudgetBar({
    required this.used,
    required this.total,
    required this.pct,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final usedStr = fmtNum(used, currency);
    final totalStr = fmtNum(total, currency);
    final pctInt = (pct * 100).round();
    // Switch bar to red as a warning when the user is near the budget limit.
    final barColor = pct > 0.85 ? AppColors.myRed : AppColors.myGreen;

    return Container(
      padding: EdgeInsets.all(AppSizes.s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Budget label + used/total figures ─────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget Used',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontXS,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '$usedStr / $totalStr $currency  ($pctInt%)',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontXS,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.xs),
          // ── Progress bar ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}
