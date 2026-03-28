// ── SavingsChartCard ──────────────────────────────────────────────────────────
// White card with a line chart tracking the Savings account balance.
// Past 5 months show a single end-of-month data point each. The current month
// expands to show every individual transaction, so you can follow each
// deposit/withdrawal in real time. Once a month passes it collapses to its
// final balance.

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:financeapp/models/analytics_model.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';

// ── SavingsChartCard ──────────────────────────────────────────────────────────

class SavingsChartCard extends StatelessWidget {
  final AnalyticsData data;
  final String currency;

  const SavingsChartCard({
    super.key,
    required this.data,
    required this.currency,
  });

  // ── Computed value helpers ────────────────────────────────────────────────

  /// All plotted values: 6 monthly snapshots + current-month intra-month points.
  /// Used to derive a Y-axis range that fits all data without clipping.
  List<double> get _allValues => [
        ...data.savingsHistory,
        ...data.currentMonthTimeline,
      ];

  /// Round down to the nearest 100 with 10 % padding below the minimum.
  double get _minY {
    final min = _allValues.reduce((a, b) => a < b ? a : b);
    if (min <= 0) return 0;
    return (((min * 0.9) / 100).floor() * 100).toDouble();
  }

  /// Round up to the next clean 100-unit boundary with 15 % headroom above peak.
  double get _maxY {
    final max = _allValues.reduce((a, b) => a > b ? a : b);
    if (max <= 0) return 400;
    return (((max * 1.15) / 100).ceil() * 100).toDouble();
  }

  /// Abbreviate thousands (e.g. 2500 → "2.5K") for axis labels.
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
    final history = data.savingsHistory;
    final months = data.months;
    final timeline = data.currentMonthTimeline;

    // ── Build spots ──────────────────────────────────────────────────────
    // x=0..4  → end-of-month balance for each of the 5 past months.
    // x=4..5  → current month: each transaction gets a proportional x position
    //           so they fill the space between last month (x=4) and now (x=5).
    //           With 0 transactions: a single point at x=5 (current balance).
    //
    // Spreading formula: x = 4 + (j+1)/n
    //   j goes from 0 to n-1, so the first point lands at 4+1/n and the
    //   last always lands exactly at x=5.  This guarantees no point overlaps
    //   the prior month boundary and the last point is always at the right edge.
    final List<FlSpot> spots = [
      for (int i = 0; i < 5; i++) FlSpot(i.toDouble(), history[i]),
    ];

    if (timeline.isEmpty) {
      // No intra-month transactions yet; plot the current month-end balance.
      spots.add(FlSpot(5.0, history[5]));
    } else {
      final n = timeline.length;
      for (int j = 0; j < n; j++) {
        // Spread evenly: x = 4 + (j+1)/n  →  ranges from 4+1/n … 5.0
        spots.add(FlSpot(4.0 + (j + 1) / n, timeline[j]));
      }
    }

    // ── Header: current balance + delta vs 6 months ago ──────────────────
    final current = history.last;
    final oldest = history.first;
    final delta = current - oldest;
    final deltaStr = delta % 1 == 0
        ? '${delta >= 0 ? '+' : ''}${delta.toInt()}'
        : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)}';
    final deltaColor = delta >= 0 ? AppColors.myGreen : AppColors.myRed;
    final trendIcon = delta >= 0
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;

    final interval = ((_maxY - _minY) / 4).ceilToDouble();

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
          // ── Header: title + delta over 6 months + trend icon ─────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Savings Growth',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontM,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Row(
                children: [
                  Text(
                    '$deltaStr $currency',
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontS,
                      fontWeight: FontWeight.bold,
                      color: deltaColor,
                    ),
                  ),
                  SizedBox(width: AppSizes.xs),
                  Icon(trendIcon, color: deltaColor, size: AppSizes.iconS),
                ],
              ),
            ],
          ),
          SizedBox(height: AppSizes.m),

          // ── Line chart ────────────────────────────────────────────────
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: _minY,
                maxY: _maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.myGreen,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    // Green gradient fill under the curve.
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.myGreen.withValues(alpha: 0.18),
                          AppColors.myGreen.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    // Red dot when balance dipped vs the previous data point.
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, barData, index) {
                        final dipped =
                            index > 0 && spot.y < spots[index - 1].y;
                        return FlDotCirclePainter(
                          radius: 4,
                          color: dipped ? AppColors.myRed : AppColors.myGreen,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                  ),
                ],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.12),
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
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        // Hide the min and max edge labels to avoid overlap
                        // with the chart border.
                        if (value == meta.min || value == meta.max) {
                          return const SizedBox.shrink();
                        }
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
                        // Only label exact integer positions (month boundaries).
                        // Sub-month transaction points (e.g. x=4.33) get no label.
                        if ((value - value.roundToDouble()).abs() > 0.01) {
                          return const SizedBox.shrink();
                        }
                        final idx = value.round();
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
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (touchedSpots) =>
                        touchedSpots.map((spot) {
                      final bal = spot.y;
                      final balStr = bal % 1 == 0
                          ? bal.toInt().toString()
                          : bal.toStringAsFixed(2);
                      return LineTooltipItem(
                        '$balStr $currency',
                        const TextStyle(
                          fontFamily: 'Rubik',
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
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
