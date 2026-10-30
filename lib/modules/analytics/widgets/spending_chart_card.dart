// ── SpendingChartCard ─────────────────────────────────────────────────────────
// Grouped bar chart: Income (green) vs Spent (red) for the last 6 months.
// Tapping a bar shows a tooltip with the exact value.

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:financeapp/models/analytics_model.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:financeapp/shared/utils/currency.dart';

// ── SpendingChartCard ─────────────────────────────────────────────────────────

class SpendingChartCard extends StatelessWidget {
  final AnalyticsData data;
  final String currency;

  const SpendingChartCard({
    super.key,
    required this.data,
    required this.currency,
  });

  // ── Y-axis helpers ────────────────────────────────────────────────────────

  /// Round up to the next clean 100-unit boundary with 15 % headroom.
  double get _maxY {
    double max = 0;
    for (final m in data.months) {
      if (m.income > max) max = m.income;
      if (m.expenses > max) max = m.expenses;
    }
    if (max <= 0) return 400;
    return (((max * 1.15) / 100).ceil() * 100).toDouble();
  }

  /// Divide the Y range into 4 equal intervals for grid lines and axis labels.
  double get _interval => (_maxY / 4).ceilToDouble();

  /// Abbreviate thousands (e.g. 1500 → "1.5K") to keep axis labels short.
  String _formatY(double value) {
    if (value >= 1000) {
      final k = value / 1000;
      return '${k % 1 == 0 ? k.toInt() : k.toStringAsFixed(1)}K';
    }
    return value.toInt().toString();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final months = data.months;

    // Build one BarChartGroupData per month; each group has 2 rods
    // (index 0 = income/green, index 1 = expenses/red).
    final groups = List.generate(months.length, (i) {
      final m = months[i];
      return BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: m.income,
            color: AppColors.myGreen,
            width: 10,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: m.expenses,
            color: AppColors.myRed,
            width: 10,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });

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
          // ── Header + legend ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spending Overview',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontM,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Row(
                children: [
                  _LegendDot(color: AppColors.myGreen, label: 'Income'),
                  SizedBox(width: AppSizes.s),
                  _LegendDot(color: AppColors.myRed, label: 'Spent'),
                ],
              ),
            ],
          ),
          SizedBox(height: AppSizes.m),

          // ── Bar chart ─────────────────────────────────────────────────
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: _maxY,
                barGroups: groups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.15),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: _interval,
                      getTitlesWidget: (value, meta) {
                        // Hide the zero label to reduce visual clutter.
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          _formatY(value),
                          style: TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: AppSizes.fontXS,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            AppStrings.monthsShort[months[idx].month],
                            style: TextStyle(
                              fontFamily: 'Rubik',
                              fontSize: AppSizes.fontXS,
                              color: Colors.grey[400],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final m = months[groupIndex];
                      final label = rodIndex == 0 ? 'Income' : 'Spent';
                      final amount =
                          rodIndex == 0 ? m.income : m.expenses;
                      final amountStr = fmtNum(amount, currency);
                      return BarTooltipItem(
                        '$label\n$amountStr $currency',
                        const TextStyle(
                          fontFamily: 'Rubik',
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _LegendDot ────────────────────────────────────────────────────────────────
// Small coloured dot + label used in the chart legend row.

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: AppSizes.fontXS,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}
