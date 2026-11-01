// ── AnalyticsPage ─────────────────────────────────────────────────────────────
// Financial analytics and spending reports. This file is a thin shell that
// wires up providers and composes the page from the individual widget cards
// found in lib/modules/analytics/widgets/.
//
// Page structure (top → bottom):
//   SmartInsightsCard      — rule-based actionable observations
//   DebtsCard              — who owes you money (only when someone does)
//   MonthlySnapshotCard   — income, spending & budget bar for current month
//   [SPENDING OVERVIEW]
//   SpendingChartCard      — grouped bar chart: Income vs Spent, 6 months
//   CategoryBudgetCard     — this month's spending per category + limits
//   [BILLS BREAKDOWN]
//   CategoryChartCard      — donut chart of bills by category
//   [SAVINGS GROWTH]
//   SavingsChartCard       — line chart of savings account balance over time
// ─────────────────────────────────────────────────────────────────────────────

import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/debt_model.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Widget imports ────────────────────────────────────────────────────────────
import 'widgets/smart_insights_card.dart';
import 'widgets/debts_card.dart';
import 'widgets/monthly_snapshot_card.dart';
import 'widgets/spending_chart_card.dart';
import 'widgets/category_budget_card.dart';
import 'widgets/category_chart_card.dart';
import 'widgets/savings_chart_card.dart';

// ── AnalyticsPage ─────────────────────────────────────────────────────────────

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Provider reads ────────────────────────────────────────────────────
    final analytics = ref.watch(analyticsProvider);
    final currency = ref.watch(currencyProvider);
    final user = ref.watch(userProvider);
    // Budget account balance is needed by both SmartInsights and MonthlySnapshot.
    final budgetBalance = ref
        .watch(accountsProvider)
        .firstWhere((a) => a.id == kBudgetId)
        .balance;
    final bills = ref.watch(expensesProvider);
    final budgets = ref.watch(categoryBudgetsProvider).valueOrNull ?? const {};
    final debts = ref.watch(debtsProvider).valueOrNull ?? const <Debt>[];
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        // bottom: false — let content extend behind the floating nav bar.
        // The scroll view adds its own bottom padding equal to the nav bar
        // height (via MediaQuery) so the last item can always be scrolled
        // into full view above the bar.
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSizes.m,
            right: AppSizes.m,
            top: AppSizes.s,
            bottom: AppSizes.m + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page header ───────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.xs,
                  vertical: AppSizes.s,
                ),
                child: Text(
                  'Analytics',
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),

              // ── Analytics content (async) ─────────────────────────────
              analytics.when(
                loading: () => const SizedBox(
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Smart Insights (top) ──────────────────────────
                    SmartInsightsCard(
                      data: data,
                      budgetBalance: budgetBalance,
                      monthlyBudget: user.monthlyBudget,
                      bills: bills,
                      currency: currency,
                      categoryBudgets: budgets,
                    ),
                    SizedBox(height: AppSizes.m),

                    // ── Who owes you money (only when someone does) ───
                    if (debts.isNotEmpty) ...[
                      DebtsCard(
                        debts: debts,
                        accountNames: {for (final a in accounts) a.id: a.displayName},
                        currency: currency,
                        now: DateTime.now(),
                        onSave: (debt, person, due) async {
                          await ref
                              .read(dbProvider)
                              .updateDebt(debt.id, person: person, dueDate: due);
                          ref.invalidate(debtsProvider);
                        },
                      ),
                      SizedBox(height: AppSizes.m),
                    ],

                    // ── Step 1: Monthly Snapshot ──────────────────────
                    MonthlySnapshotCard(
                      data: data,
                      currency: currency,
                      budgetBalance: budgetBalance,
                      monthlyBudget: user.monthlyBudget,
                    ),
                    SizedBox(height: AppSizes.m),

                    // ── Step 2: 6-month bar chart ─────────────────────
                    SpendingChartCard(data: data, currency: currency),
                    SizedBox(height: AppSizes.m),

                    // ── Step 3: Spending per category + limits ────────
                    CategoryBudgetCard(
                      spending: data.categorySpendingThisMonth,
                      budgets: budgets,
                      currency: currency,
                      onSetLimit: (category, amount) async {
                        await ref
                            .read(dbProvider)
                            .setCategoryBudget(category, amount);
                        ref.invalidate(categoryBudgetsProvider);
                      },
                    ),
                    SizedBox(height: AppSizes.m),

                    // ── Step 4: Bills donut chart ─────────────────────
                    CategoryChartCard(bills: bills, currency: currency),
                    SizedBox(height: AppSizes.m),

                    // ── Step 5: Savings account growth line chart ─────
                    SavingsChartCard(data: data, currency: currency),
                    SizedBox(height: AppSizes.m),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
