// ── AnalyticsSectionHeader ────────────────────────────────────────────────────
// Uppercase gray label used as a section divider between analytics cards.
// Consistent with the section header style used in Profile and FixedExpenses.

import 'package:flutter/material.dart';
import 'package:financeapp/shared/styles/sizes.dart';

// ── Widget ────────────────────────────────────────────────────────────────────

class AnalyticsSectionHeader extends StatelessWidget {
  final String label;
  const AnalyticsSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: AppSizes.xs),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Rubik',
          fontSize: AppSizes.fontSection,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: Colors.grey[500],
        ),
      ),
    );
  }
}
