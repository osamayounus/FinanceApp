// ── CategoryChartCard ─────────────────────────────────────────────────────────
// Donut chart showing the current monthly bills grouped by category.
// Colors mirror the category palette used on the Fixed Expenses page.
// Tapping a slice expands it and highlights the matching legend row.

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/modules/fixedExp/bill_categories.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/utils/currency.dart';

// ── CategoryChartCard ─────────────────────────────────────────────────────────

class CategoryChartCard extends StatefulWidget {
  final List<ExpenseModel> bills;
  final String currency;

  const CategoryChartCard({
    super.key,
    required this.bills,
    required this.currency,
  });

  @override
  State<CategoryChartCard> createState() => _CategoryChartCardState();
}

class _CategoryChartCardState extends State<CategoryChartCard> {
  // Index of the currently highlighted pie slice (-1 = none).
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    // ── Build category totals ─────────────────────────────────────────────
    final Map<String, double> totals = {};
    for (final bill in widget.bills) {
      final cat = bill.category.isEmpty ? 'Other' : bill.category;
      totals[cat] = (totals[cat] ?? 0) + bill.amount;
    }

    // Show empty state when the user has no bills yet.
    if (totals.isEmpty) {
      return _EmptyBills();
    }

    final grandTotal = totals.values.fold(0.0, (a, b) => a + b);
    // Sort largest slice first for a consistent visual order.
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── Pie sections ──────────────────────────────────────────────────────
    final sections = List.generate(entries.length, (i) {
      final isTouched = i == _touchedIndex;
      final color = catFor(entries[i].key).color;
      return PieChartSectionData(
        value: entries[i].value,
        color: color,
        // Expand the touched slice slightly to give tactile feedback.
        radius: isTouched ? 42 : 34,
        showTitle: false,
      );
    });

    final totalStr = fmtNum(grandTotal, widget.currency);

    return Container(
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
          // ── Card header ───────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Bills by Category',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontM,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '$totalStr ${widget.currency} total',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontXS,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.m),

          // ── Donut chart with centered total label ─────────────────────
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    // centerSpaceRadius creates the donut hole.
                    centerSpaceRadius: 52,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback:
                          (FlTouchEvent event, PieTouchResponse? response) {
                        setState(() {
                          if (response == null ||
                              response.touchedSection == null) {
                            _touchedIndex = -1;
                          } else {
                            _touchedIndex = response
                                .touchedSection!.touchedSectionIndex;
                          }
                        });
                      },
                    ),
                  ),
                ),
                // Center text: shows selected category or overall total.
                _touchedIndex >= 0 && _touchedIndex < entries.length
                    ? _DonutCenter(
                        label: entries[_touchedIndex].key,
                        amount: entries[_touchedIndex].value,
                        currency: widget.currency,
                        pct: (entries[_touchedIndex].value /
                                grandTotal *
                                100)
                            .round(),
                      )
                    : _DonutCenter(
                        label: 'Total',
                        amount: grandTotal,
                        currency: widget.currency,
                        pct: null,
                      ),
              ],
            ),
          ),
          SizedBox(height: AppSizes.m),

          // ── Legend — 2-column grid ────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              // Two equal columns with a small gap between them.
              final itemWidth =
                  (constraints.maxWidth - AppSizes.s) / 2;
              return Wrap(
                spacing: AppSizes.s,
                runSpacing: AppSizes.xs + 2,
                children: List.generate(entries.length, (i) {
                  final entry = entries[i];
                  final color = catFor(entry.key).color;
                  final pct =
                      (entry.value / grandTotal * 100).round();
                  final isSelected = i == _touchedIndex;

                  return GestureDetector(
                    // Tapping a legend row also selects/deselects the slice.
                    onTap: () => setState(() {
                      _touchedIndex = isSelected ? -1 : i;
                    }),
                    child: SizedBox(
                      width: itemWidth,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.s,
                          vertical: AppSizes.xs + 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusS),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            SizedBox(width: AppSizes.xs),
                            Expanded(
                              child: Text(
                                entry.key,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Rubik',
                                  fontSize: AppSizes.fontXS,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: TextStyle(
                                fontFamily: 'Rubik',
                                fontSize: AppSizes.fontXS,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? color
                                    : Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── _DonutCenter ──────────────────────────────────────────────────────────────
// Text shown in the hole of the donut. Switches between total and selected
// category details when a slice is tapped.

class _DonutCenter extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;

  /// Non-null when showing a selected category (shows X% below amount).
  final int? pct;

  const _DonutCenter({
    required this.label,
    required this.amount,
    required this.currency,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    final amountStr = fmtNum(amount, currency);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Category name or "Total"
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: AppSizes.fontXS,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        // Main figure
        Text(
          amountStr,
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: AppSizes.fontM,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        // Percentage when a specific slice is selected; currency otherwise.
        if (pct != null)
          Text(
            '$pct%',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontXS,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          )
        else
          Text(
            currency,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontXS,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }
}

// ── _EmptyBills ───────────────────────────────────────────────────────────────
// Placeholder shown in place of the donut chart when the user has no bills.

class _EmptyBills extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: AppSizes.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.darkGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            color: Colors.white.withValues(alpha: 0.25),
            size: AppSizes.iconXL,
          ),
          SizedBox(height: AppSizes.s),
          Text(
            'No bills added yet',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontS,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
