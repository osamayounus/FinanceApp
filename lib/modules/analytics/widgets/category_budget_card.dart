// ── CategoryBudgetCard ────────────────────────────────────────────────────────
// This month's spending per category (withdrawals + paid bills) next to an
// optional monthly limit. Tapping a row sets or removes that category's limit.

import 'package:financeapp/modules/fixedExp/bill_categories.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CategoryBudgetCard extends StatelessWidget {
  final Map<String, double> spending;
  final Map<String, double> budgets;
  final String currency;

  /// Called with the new limit; 0 removes it.
  final void Function(String category, double amount) onSetLimit;

  const CategoryBudgetCard({
    super.key,
    required this.spending,
    required this.budgets,
    required this.currency,
    required this.onSetLimit,
  });

  Future<void> _editLimit(BuildContext context, String category) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _LimitDialog(
          category: category, current: budgets[category], currency: currency),
    );
    if (result != null) onSetLimit(category, result);
  }

  @override
  Widget build(BuildContext context) {
    // Biggest spenders first; the rest keep the usual category order.
    final cats = [...kBillCats]..sort(
        (a, b) => (spending[b.name] ?? 0).compareTo(spending[a.name] ?? 0));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSizes.m),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending by Category',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: AppSizes.xs),
          Text(
            'This month · tap a category to set a limit',
            style: TextStyle(
                fontFamily: 'Rubik',
                fontSize: AppSizes.fontXS,
                color: Colors.grey[400]),
          ),
          SizedBox(height: AppSizes.s),
          for (final c in cats)
            _Row(
              cat: c,
              spent: spending[c.name] ?? 0,
              limit: budgets[c.name],
              currency: currency,
              onTap: () => _editLimit(context, c.name),
            ),
        ],
      ),
    );
  }
}

/// Pops the new limit (0 = remove) or null on cancel. It owns its controller so
/// the field is only disposed once the dialog has finished closing; disposing
/// it right after `await showDialog` rebuilds a closing dialog with a dead
/// controller.
class _LimitDialog extends StatefulWidget {
  final String category;
  final double? current;
  final String currency;
  const _LimitDialog(
      {required this.category, required this.current, required this.currency});

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  late final _ctrl = TextEditingController(
      text: widget.current == null ? '' : plainAmt(widget.current!));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
      title: Text(
        '${widget.category} limit',
        style: const TextStyle(
            fontFamily: 'Rubik',
            fontWeight: FontWeight.bold,
            color: AppColors.primary),
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          labelText: 'Monthly limit',
          suffixText: widget.currency,
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () => Navigator.pop(context, 0.0),
            child: const Text('Remove', style: TextStyle(color: AppColors.myRed)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          // An empty or unreadable field removes the limit (0 does).
          onPressed: () =>
              Navigator.pop(context, double.tryParse(_ctrl.text.trim()) ?? 0.0),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final BillCat cat;
  final double spent;
  final double? limit;
  final String currency;
  final VoidCallback onTap;

  const _Row({
    required this.cat,
    required this.spent,
    required this.limit,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final limit = this.limit;
    final over = limit != null && spent > limit;
    final ratio = limit == null ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final detail = limit == null
        ? (spent > 0 ? fmtAmt(spent, currency) : 'No limit')
        : '${fmtNum(spent, currency)} / ${fmtAmt(limit, currency)}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.s),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Icon(cat.icon, color: cat.color, size: AppSizes.iconM),
            ),
            SizedBox(width: AppSizes.s + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cat.name,
                          style: TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: AppSizes.fontS,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Text(
                        detail,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontXS,
                          fontWeight: FontWeight.w600,
                          color: over ? AppColors.myRed : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  if (limit != null) ...[
                    SizedBox(height: AppSizes.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: cat.color.withValues(alpha: 0.12),
                        color: over ? AppColors.myRed : cat.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
