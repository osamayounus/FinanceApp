// ── SmartInsightsCard ─────────────────────────────────────────────────────────
// Rule-based card that surfaces up to 4 actionable observations about the
// user's finances. Each rule checks a specific condition and emits an _Insight
// (icon, colour, text). Rules run in priority order; first 4 are shown.

import 'package:flutter/material.dart';
import 'package:financeapp/models/analytics_model.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';

// ── Data class ────────────────────────────────────────────────────────────────

/// A single insight entry: an icon, a highlight colour, and a message string.
class _Insight {
  final IconData icon;
  final Color color;
  final String text;
  const _Insight(this.icon, this.color, this.text);
}

// ── SmartInsightsCard ─────────────────────────────────────────────────────────

class SmartInsightsCard extends StatelessWidget {
  final AnalyticsData data;
  final double budgetBalance;
  final double monthlyBudget;
  final List<ExpenseModel> bills;
  final String currency;

  const SmartInsightsCard({
    super.key,
    required this.data,
    required this.budgetBalance,
    required this.monthlyBudget,
    required this.bills,
    required this.currency,
  });

  // ── Insight generation ────────────────────────────────────────────────────

  /// Evaluates all rules and returns at most 4 insights in priority order.
  List<_Insight> get _insights {
    final out = <_Insight>[];
    final months = data.months;
    final curr = months.last;

    // ── Rule 1: Spending vs historical average ────────────────────────────
    // Compare current month expenses to the average of past months that have
    // data. Threshold ±15 % to avoid noise when amounts are tiny.
    final prevWithData = months
        .sublist(0, months.length - 1)
        .where((m) => m.expenses > 0)
        .toList();
    if (prevWithData.isNotEmpty && curr.expenses > 0) {
      final avg =
          prevWithData.map((m) => m.expenses).reduce((a, b) => a + b) /
          prevWithData.length;
      final pct = ((curr.expenses - avg) / avg * 100).round();
      if (pct >= 15) {
        out.add(
          _Insight(
            Icons.trending_up_rounded,
            AppColors.myRed,
            'Spending is $pct% above your usual average',
          ),
        );
      } else if (pct <= -15) {
        out.add(
          _Insight(
            Icons.trending_down_rounded,
            AppColors.myGreen,
            'Spending is ${pct.abs()}% below your usual average',
          ),
        );
      }
    }

    // ── Rule 2: Budget utilisation ────────────────────────────────────────
    if (monthlyBudget > 0) {
      final used = (monthlyBudget - budgetBalance).clamp(0.0, monthlyBudget);
      final pct = (used / monthlyBudget * 100).round();
      if (pct >= 85) {
        out.add(
          _Insight(
            Icons.warning_amber_rounded,
            Colors.orange,
            '$pct% of your monthly budget has been used',
          ),
        );
      } else if (pct <= 30 && curr.expenses > 0) {
        out.add(
          _Insight(
            Icons.check_circle_outline_rounded,
            AppColors.myGreen,
            'Only $pct% of budget used — you\'re well on track',
          ),
        );
      }
    }

    // ── Rule 3: Savings activity this month ───────────────────────────────
    if (data.savingsHistory.length >= 2) {
      final delta =
          data.savingsHistory.last -
          data.savingsHistory[data.savingsHistory.length - 2];
      if (delta.abs() > 0) {
        final amt = delta.abs() % 1 == 0
            ? delta.abs().toInt().toString()
            : delta.abs().toStringAsFixed(2);
        if (delta > 0) {
          out.add(
            _Insight(
              Icons.savings_rounded,
              AppColors.myGreen,
              'You added $amt $currency to savings this month',
            ),
          );
        } else {
          out.add(
            _Insight(
              Icons.savings_rounded,
              AppColors.myRed,
              'You withdrew $amt $currency from savings this month',
            ),
          );
        }
      }
    }

    // ── Rule 4: Three-month spending trend ────────────────────────────────
    if (months.length >= 3) {
      final last3 = months.sublist(months.length - 3);
      if (last3.every((m) => m.expenses > 0)) {
        if (last3[1].expenses < last3[0].expenses &&
            last3[2].expenses < last3[1].expenses) {
          out.add(
            _Insight(
              Icons.emoji_events_rounded,
              AppColors.myGreen,
              'Spending has dropped 3 months in a row — great job!',
            ),
          );
        } else if (last3[1].expenses > last3[0].expenses &&
            last3[2].expenses > last3[1].expenses) {
          out.add(
            _Insight(
              Icons.show_chart_rounded,
              Colors.orange,
              'Spending has been rising 3 months in a row',
            ),
          );
        }
      }
    }

    // ── Rule 5: Best / worst month in the 6-month window ─────────────────
    if (curr.expenses > 0 && out.length < 4) {
      final exps = months.map((m) => m.expenses).toList();
      final minExp = exps.reduce((a, b) => a < b ? a : b);
      final maxExp = exps.reduce((a, b) => a > b ? a : b);
      // Only fire when this month is uniquely best/worst (avoids ties).
      final uniqueBest =
          curr.expenses == minExp && exps.where((e) => e == minExp).length == 1;
      final uniqueWorst =
          curr.expenses == maxExp && exps.where((e) => e == maxExp).length == 1;
      if (uniqueBest) {
        out.add(
          _Insight(
            Icons.star_rounded,
            AppColors.myGreen,
            'Best spending month in the last 6 months!',
          ),
        );
      } else if (uniqueWorst) {
        out.add(
          _Insight(
            Icons.warning_rounded,
            AppColors.myRed,
            'Highest-spending month in the last 6 months',
          ),
        );
      }
    }

    // ── Rule 6: Unpaid bills ──────────────────────────────────────────────
    if (bills.isNotEmpty && out.length < 4) {
      final unpaid = bills.where((b) => !b.isPaid).length;
      if (unpaid == 0) {
        out.add(
          _Insight(
            Icons.task_alt_rounded,
            AppColors.myGreen,
            'All bills are paid for this month',
          ),
        );
      } else {
        out.add(
          _Insight(
            Icons.receipt_long_rounded,
            Colors.orange,
            '$unpaid bill${unpaid > 1 ? 's' : ''} still unpaid this month',
          ),
        );
      }
    }

    // ── Rule 7: No income recorded yet ───────────────────────────────────
    if (curr.income == 0 && out.length < 4) {
      out.add(
        _Insight(
          Icons.calendar_today_rounded,
          Colors.grey,
          'No income recorded yet this month',
        ),
      );
    }

    return out.take(4).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final items = _insights;

    return Container(
      padding: EdgeInsets.all(AppSizes.m),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header with lightbulb icon ────────────────────────────────
          Row(
            children: [
              Text(
                'Smart Insights',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontM,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.m),

          // ── Insight rows or empty state ───────────────────────────────
          if (items.isEmpty)
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.myGreen,
                  size: AppSizes.iconS,
                ),
                SizedBox(width: AppSizes.s),
                Text(
                  'Everything looks good this month!',
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontS,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            )
          else
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: AppSizes.m,
                  color: Colors.grey.withValues(alpha: 0.1),
                ),
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: items[i].color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    ),
                    child: Icon(
                      items[i].icon,
                      color: items[i].color,
                      size: AppSizes.iconS,
                    ),
                  ),
                  SizedBox(width: AppSizes.s),
                  Expanded(
                    child: Text(
                      items[i].text,
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: AppSizes.fontS,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}
