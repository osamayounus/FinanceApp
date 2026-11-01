// ── DebtPicker ────────────────────────────────────────────────────────────────
// "Who is paying you back?" chips on the Receive Back step: one per open debt
// of the account, with what that person still owes.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/models/debt_model.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter/material.dart';

class DebtPicker extends StatelessWidget {
  final List<Debt> debts;
  final int? selected;
  final String currency;
  final ValueChanged<int> onChanged;

  const DebtPicker({
    super.key,
    required this.debts,
    required this.selected,
    required this.currency,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who is paying you back?',
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final d in debts)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '${d.person} · ${fmtAmt(d.remaining, currency)}',
                    ),
                    selected: selected == d.id,
                    showCheckmark: false,
                    onSelected: (_) => onChanged(d.id),
                    selectedColor: Colors.teal.withValues(alpha: 0.25),
                    backgroundColor: Colors.grey.withValues(alpha: 0.08),
                    side: BorderSide.none,
                    labelStyle: const TextStyle(
                      fontFamily: 'Rubik',
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
