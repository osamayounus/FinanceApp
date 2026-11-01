// ── DebtsCard ─────────────────────────────────────────────────────────────────
// Who still owes you money: one row per open debt with what is left and when it
// is due (red once late). Tapping a row changes the person or the due date; the
// amounts only move through Give Debt / Receive Back on the Operation page.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/models/debt_model.dart';
import 'package:financeapp/modules/fixedExp/bill_due.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:financeapp/shared/utils/dates.dart';
import 'package:flutter/material.dart';

const _amber = Color(0xFFFF8F00);

class DebtsCard extends StatelessWidget {
  final List<Debt> debts;

  /// Account id -> name, to say which account the money came from.
  final Map<int, String> accountNames;
  final String currency;
  final DateTime now;
  final void Function(Debt debt, String person, DateTime? due) onSave;

  const DebtsCard({
    super.key,
    required this.debts,
    required this.accountNames,
    required this.currency,
    required this.now,
    required this.onSave,
  });

  Future<void> _edit(BuildContext context, Debt debt) async {
    final r = await showModalBottomSheet<_DebtEdit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DebtSheet(debt: debt),
    );
    if (r != null) onSave(debt, r.person, r.due);
  }

  @override
  Widget build(BuildContext context) {
    final owed = debts.fold<double>(0, (s, d) => s + d.remaining);
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Money you lent',
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Text(
                fmtAmt(owed, currency),
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontM,
                  fontWeight: FontWeight.bold,
                  color: _amber,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.xs),
          Text(
            'Tap one to change the name or the due date',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontXS,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: AppSizes.s),
          for (final d in debts)
            _Row(
              debt: d,
              account: accountNames[d.accountId] ?? '',
              currency: currency,
              now: now,
              onTap: () => _edit(context, d),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Debt debt;
  final String account;
  final String currency;
  final DateTime now;
  final VoidCallback onTap;

  const _Row({
    required this.debt,
    required this.account,
    required this.currency,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final due = debt.dueDate;
    final label = due == null ? null : dueText(due, now, 'Due ${fmtDay(due)}');
    final late = label?.late ?? false;
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
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Text(
                debt.person.characters.first.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Rubik',
                  fontWeight: FontWeight.bold,
                  color: _amber,
                ),
              ),
            ),
            SizedBox(width: AppSizes.s + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    debt.person,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontS,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    [
                      account,
                      label?.text ?? 'No due date',
                    ].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontXS,
                      color: late ? AppColors.myRed : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtAmt(debt.remaining, currency),
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontS,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                if (debt.repaid > 0)
                  Text(
                    'of ${fmtAmt(debt.amount, currency)}',
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontXS,
                      color: Colors.grey[400],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtEdit {
  final String person;
  final DateTime? due;
  const _DebtEdit(this.person, this.due);
}

/// Bottom sheet for one debt's person and due date; pops a [_DebtEdit] or null
/// on cancel. It owns its controller so it is only disposed once the sheet has
/// finished closing (see _GoalSheet).
class _DebtSheet extends StatefulWidget {
  final Debt debt;
  const _DebtSheet({required this.debt});

  @override
  State<_DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends State<_DebtSheet> {
  late final _person = TextEditingController(text: widget.debt.person);
  late DateTime? _due = widget.debt.dueDate;
  String _error = '';

  @override
  void dispose() {
    _person.dispose();
    super.dispose();
  }

  void _save() {
    final person = _person.text.trim();
    if (person.isEmpty) {
      setState(() => _error = 'Enter who owes it');
    } else {
      Navigator.pop(context, _DebtEdit(person, _due));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusXXL),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSizes.l,
          AppSizes.m,
          AppSizes.l,
          AppSizes.l,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ModalHandle(),
              SizedBox(height: AppSizes.l),
              Text(
                'Edit debt',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontXXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: AppSizes.l),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.pageBackground,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
                child: TextField(
                  controller: _person,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontM,
                    color: AppColors.primary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Who owes it',
                    labelStyle: TextStyle(
                      fontFamily: 'Rubik',
                      color: Colors.grey[400],
                    ),
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: Colors.grey[400],
                      size: AppSizes.iconM,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSizes.m,
                      vertical: AppSizes.m,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSizes.s + 4),
              OptionalDateField(
                label: 'Pay back by',
                value: _due,
                onChanged: (d) => setState(() => _due = d),
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: AppSizes.s),
                  child: Text(
                    _error,
                    style: const TextStyle(
                      fontFamily: 'Rubik',
                      color: AppColors.myRed,
                      fontSize: 13,
                    ),
                  ),
                ),
              SizedBox(height: AppSizes.l),
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusL),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontWeight: FontWeight.bold,
                      fontSize: AppSizes.fontM,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
