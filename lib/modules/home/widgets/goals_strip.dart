// ── GoalsStrip ────────────────────────────────────────────────────────────────
// Savings goals under the cards on the dashboard. Each goal is an envelope
// inside Savings (see goalProgress): a horizontal row of tiles with a progress
// ring, "+" adds a goal and tapping a tile edits or deletes it. Money gets into
// a goal when it is added to Savings (Operation / Transfer pages pick the goal).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/savings_goal_model.dart';
import 'package:financeapp/modules/analytics/savings_goals.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

class GoalsStrip extends ConsumerWidget {
  const GoalsStrip({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    List<GoalProgress> progress,
    double savings,
    String currency, [
    GoalProgress? p,
  ]) async {
    final goal = p?.goal;
    final r = await showModalBottomSheet<_GoalResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalSheet(
        goal: goal,
        saved: p?.saved ?? 0,
        // What this goal may hold: its own envelope plus what no goal holds.
        available: unallocated(progress, savings) + (p?.saved ?? 0),
        currency: currency,
      ),
    );
    if (r == null) return;
    final db = ref.read(dbProvider);
    if (r.delete) {
      await db.deleteSavingsGoal(goal!.id);
    } else if (goal == null) {
      await db.insertSavingsGoal(
        r.name,
        r.target,
        saved: r.saved,
        targetDate: r.date,
      );
    } else {
      await db.updateSavingsGoal(
        goal.id,
        r.name,
        r.target,
        saved: r.saved,
        targetDate: r.date,
      );
    }
    ref.invalidate(savingsGoalsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingsGoalsProvider).valueOrNull ?? const [];
    final currency = ref.watch(currencyProvider);
    final savings = ref
        .watch(accountsProvider)
        .firstWhere((a) => a.id == kSavingsId)
        .balance;
    final progress = goalProgress(goals, savings, DateTime.now());
    final over = uncovered(progress);
    final subtle = AppColors.secondary.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.l),
          child: Row(
            children: [
              Text(
                'Goals',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontM,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              SizedBox(width: AppSizes.s),
              Expanded(
                child: Text(
                  over > 0.005
                      ? '${fmtAmt(over, currency)} no longer in Savings'
                      : 'Unallocated: ${fmtAmt(unallocated(progress, savings), currency)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontXS,
                    color: over > 0.005 ? AppColors.myRed : subtle,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _open(context, ref, progress, savings, currency),
                child: Tooltip(
                  message: 'Add goal',
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary.withValues(alpha: 0.08),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: AppColors.secondary.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSizes.s),
        if (progress.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.l),
            child: Text(
              'No goals yet · tap + to add one',
              style: TextStyle(
                fontFamily: 'Rubik',
                fontSize: AppSizes.fontS,
                color: subtle,
              ),
            ),
          )
        else
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: AppSizes.l),
              itemCount: progress.length,
              separatorBuilder: (_, _) => SizedBox(width: AppSizes.s),
              itemBuilder: (_, i) => _GoalTile(
                progress: progress[i],
                currency: currency,
                onTap: () => _open(
                  context,
                  ref,
                  progress,
                  savings,
                  currency,
                  progress[i],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  final GoalProgress progress;
  final String currency;
  final VoidCallback onTap;

  const _GoalTile({
    required this.progress,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final g = p.goal;
    final pct = (p.saved / g.target).clamp(0.0, 1.0);
    final color = p.reached
        ? AppColors.myGreen
        : p.late
        ? AppColors.myRed
        : AppColors.blueIcon;
    final left = g.target - p.saved;
    final String note;
    if (p.reached) {
      note = 'Reached';
    } else if (p.late) {
      note = 'Date passed · ${fmtAmt(left, currency)} left';
    } else if (p.perMonth != null) {
      note = '${fmtAmt(p.perMonth!, currency)} / month';
    } else {
      note = '${fmtAmt(left, currency)} left';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        child: Ink(
          width: 156,
          padding: EdgeInsets.all(AppSizes.s + 4),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            value: pct,
                            strokeWidth: 3.5,
                            strokeCap: StrokeCap.round,
                            backgroundColor: color.withValues(alpha: 0.2),
                            color: color,
                          ),
                        ),
                        p.reached
                            ? Icon(Icons.check_rounded, size: 16, color: color)
                            : Text(
                                '${(pct * 100).floor()}%',
                                style: TextStyle(
                                  fontFamily: 'Rubik',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary,
                                ),
                              ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSizes.s),
                  Expanded(
                    child: Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: AppSizes.fontS,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${fmtNum(p.saved, currency)} / ${fmtAmt(g.target, currency)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontS,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontXS,
                  color: p.late
                      ? AppColors.myRed
                      : p.reached
                      ? AppColors.myGreen
                      : AppColors.secondary.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalResult {
  final bool delete;
  final String name;
  final double target;
  final double saved;
  final DateTime? date;
  const _GoalResult({
    this.delete = false,
    this.name = '',
    this.target = 0,
    this.saved = 0,
    this.date,
  });
}

/// Bottom sheet for a new or existing goal; pops a [_GoalResult] or null on
/// cancel. It owns its controllers so they are only disposed once the sheet has
/// finished closing (see _LimitDialog).
class _GoalSheet extends StatefulWidget {
  final SavingsGoal? goal;

  /// What the goal holds now (as shown) and the most it may hold.
  final double saved;
  final double available;
  final String currency;
  const _GoalSheet({
    required this.goal,
    required this.saved,
    required this.available,
    required this.currency,
  });

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final _name = TextEditingController(text: widget.goal?.name ?? '');
  late final _target = TextEditingController(
    text: widget.goal == null ? '' : plainAmt(widget.goal!.target),
  );
  late final _saved = TextEditingController(
    text: widget.saved > 0 ? plainAmt(widget.saved) : '',
  );
  late DateTime? _date = widget.goal?.targetDate;
  String _error = '';

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 30),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final name = _name.text.trim();
    final target = double.tryParse(_target.text.trim()) ?? 0;
    final savedText = _saved.text.trim();
    final saved = savedText.isEmpty ? 0.0 : double.tryParse(savedText);
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name for the goal');
    } else if (!(target > 0)) {
      setState(() => _error = 'Enter a valid target amount');
    } else if (saved == null) {
      setState(() => _error = 'Enter a valid saved amount');
    } else if (saved > target) {
      setState(() => _error = 'Saved cannot be more than the target');
    } else if (saved > widget.available + 1e-9) {
      setState(
        () => _error =
            'Only ${fmtAmt(widget.available, widget.currency)} of your savings is free',
      );
    } else {
      Navigator.pop(
        context,
        _GoalResult(name: name, target: target, saved: saved, date: _date),
      );
    }
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool number = false,
    bool autofocus = false,
    String? suffix,
    String? helper,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        decoration: BoxDecoration(
          color: AppColors.pageBackground,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        child: TextField(
          controller: c,
          autofocus: autofocus,
          textCapitalization: number
              ? TextCapitalization.none
              : TextCapitalization.sentences,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          inputFormatters: number
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: AppSizes.fontM,
            color: AppColors.primary,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(fontFamily: 'Rubik', color: Colors.grey[400]),
            prefixIcon: Icon(
              icon,
              color: Colors.grey[400],
              size: AppSizes.iconM,
            ),
            suffixText: suffix,
            suffixStyle: TextStyle(
              fontFamily: 'Rubik',
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSizes.m,
              vertical: AppSizes.m,
            ),
          ),
        ),
      ),
      if (helper != null)
        Padding(
          padding: EdgeInsets.only(left: AppSizes.m, top: AppSizes.xs),
          child: Text(
            helper,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontS,
              color: Colors.grey[400],
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final editing = widget.goal != null;
    final gap = SizedBox(height: AppSizes.s + 4);

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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.blueIcon.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    child: Icon(
                      Icons.flag_rounded,
                      color: AppColors.blueIcon,
                      size: AppSizes.iconM,
                    ),
                  ),
                  SizedBox(width: AppSizes.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editing ? 'Edit goal' : 'New goal',
                          style: TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: AppSizes.fontXXL,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          editing
                              ? 'Change it or remove it'
                              : 'What are you saving for?',
                          style: TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: AppSizes.fontS,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSizes.l),
              _field(
                _name,
                'Goal name',
                Icons.edit_outlined,
                autofocus: !editing,
              ),
              gap,
              _field(
                _target,
                'Target amount',
                Icons.flag_outlined,
                number: true,
                suffix: widget.currency,
              ),
              gap,
              _field(
                _saved,
                'Set aside from Savings',
                Icons.savings_outlined,
                number: true,
                suffix: widget.currency,
                helper: 'Free: ${fmtAmt(widget.available, widget.currency)}',
              ),
              gap,
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.pageBackground,
                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.m,
                    vertical: AppSizes.m,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        color: Colors.grey[400],
                        size: AppSizes.iconM,
                      ),
                      SizedBox(width: AppSizes.m),
                      Expanded(
                        child: _date == null
                            ? Text(
                                'Target date (optional)',
                                style: TextStyle(
                                  fontFamily: 'Rubik',
                                  fontSize: AppSizes.fontM,
                                  color: Colors.grey[400],
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Target date',
                                    style: TextStyle(
                                      fontFamily: 'Rubik',
                                      fontSize: 11,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _fmtDate(_date!),
                                    style: TextStyle(
                                      fontFamily: 'Rubik',
                                      fontSize: AppSizes.fontM,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      if (_date != null)
                        GestureDetector(
                          onTap: () => setState(() => _date = null),
                          child: Tooltip(
                            message: 'Clear date',
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.grey[400],
                                size: AppSizes.iconS,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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
              SizedBox(height: AppSizes.xs),
              Row(
                mainAxisAlignment: editing
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.center,
                children: [
                  if (editing)
                    TextButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        const _GoalResult(delete: true),
                      ),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.myRed,
                        size: 20,
                      ),
                      label: const Text(
                        'Delete',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          color: AppColors.myRed,
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
