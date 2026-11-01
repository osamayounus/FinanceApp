// ── GoalPicker ────────────────────────────────────────────────────────────────
// Optional "which goal?" chips shown when money goes into or out of Savings.
// "No goal" (null) leaves the money unallocated.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/models/savings_goal_model.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';

class GoalPicker extends StatelessWidget {
  final List<SavingsGoal> goals;
  final int? selected;
  final String label;
  final ValueChanged<int?> onChanged;

  const GoalPicker({
    super.key,
    required this.goals,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  Widget _chip(String text, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(text),
          selected: on,
          showCheckmark: false,
          onSelected: (_) => onTap(),
          selectedColor: AppColors.myGreen.withValues(alpha: 0.25),
          backgroundColor: Colors.grey.withValues(alpha: 0.08),
          side: BorderSide.none,
          labelStyle: const TextStyle(
              fontFamily: 'Rubik', fontWeight: FontWeight.w600, color: AppColors.primary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontFamily: 'Rubik', fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip('No goal', selected == null, () => onChanged(null)),
              for (final g in goals)
                _chip(g.name, selected == g.id, () => onChanged(g.id)),
            ],
          ),
        ),
      ],
    );
  }
}
