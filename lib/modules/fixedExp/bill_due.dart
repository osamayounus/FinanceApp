// ── Bill due dates ────────────────────────────────────────────────────────────
// Pure helpers: when a bill is due, whether it is late, what the card says, and
// which reminders should be scheduled. A bill's "cycle" starts at the last
// salary day (that is when every bill is reset to unpaid), not on the 1st.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/shared/utils/currency.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// First date on or after [from]'s day that falls on [dueDay]. A day the month
/// does not have (31 in April) means that month's last day.
DateTime billDueDate(int dueDay, DateTime from) {
  final start = _day(from);
  for (var m = 0; m < 2; m++) {
    final lastDay = DateTime(start.year, start.month + m + 1, 0).day;
    final candidate =
        DateTime(start.year, start.month + m, dueDay > lastDay ? lastDay : dueDay);
    if (!candidate.isBefore(start)) return candidate;
  }
  throw StateError('unreachable'); // a due day is always found within two months
}

/// Due date of [bill] in the cycle that began at [cycleStart]; null without a due day.
DateTime? dueDateOf(ExpenseModel bill, DateTime cycleStart) =>
    bill.dueDay == null ? null : billDueDate(bill.dueDay!, cycleStart);

/// Unpaid and its due day is already behind us (the due day itself is not late).
bool isOverdue(ExpenseModel bill, DateTime cycleStart, DateTime now) {
  final due = dueDateOf(bill, cycleStart);
  return !bill.isPaid && due != null && _day(now).isAfter(due);
}

String _ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
}

/// What the bill card shows under the category, or null when there is nothing
/// to say (no due day, or already paid).
({String text, bool late})? dueLabel(
    ExpenseModel bill, DateTime cycleStart, DateTime now) {
  final due = dueDateOf(bill, cycleStart);
  if (due == null || bill.isPaid) return null;
  return dueText(due, now, 'Due ${_ordinal(due.day)}');
}

/// How far [due] is from [now] in words; [far] is what a date more than a week
/// away says (a bill has no month to show, a debt has).
({String text, bool late}) dueText(DateTime due, DateTime now, String far) {
  // Whole calendar days via UTC: local midnights are 23 or 25 h apart over a clock change.
  final days = DateTime.utc(due.year, due.month, due.day)
      .difference(DateTime.utc(now.year, now.month, now.day))
      .inDays;
  if (days < 0) {
    return (
      text: days == -1 ? 'Overdue since yesterday' : 'Overdue by ${-days} days',
      late: true,
    );
  }
  return (
    text: switch (days) {
      0 => 'Due today',
      1 => 'Due tomorrow',
      <= 6 => 'Due in $days days',
      _ => far,
    },
    late: false,
  );
}

/// The toast after [paid] bills were charged to the Wallet by themselves.
String autoPaidText(List<ExpenseModel> paid, String currency) {
  final total = paid.fold<double>(0, (s, b) => s + b.amount);
  final what = paid.length == 1 ? paid.first.name : '${paid.length} bills';
  return '$what paid automatically · - ${fmtAmt(total, currency)}';
}

/// One notification to schedule.
typedef BillReminder = ({int id, DateTime at, String title, String body});

/// The reminders still to come for [bills]: 09:00 the day before and 09:00 on
/// the day it is due, for every unpaid bill with a due day. Ids are unique per
/// bill and kind (the bill id is a small autoincrement number).
List<BillReminder> pendingReminders(
    List<ExpenseModel> bills, DateTime cycleStart, DateTime now) {
  final out = <BillReminder>[];
  for (final b in bills) {
    final due = dueDateOf(b, cycleStart);
    if (b.isPaid || due == null) continue;
    final dayBefore = DateTime(due.year, due.month, due.day - 1, 9);
    final onTheDay = DateTime(due.year, due.month, due.day, 9);
    if (dayBefore.isAfter(now)) {
      out.add((id: b.id * 2, at: dayBefore, title: 'Bill due tomorrow', body: b.name));
    }
    if (onTheDay.isAfter(now)) {
      out.add((id: b.id * 2 + 1, at: onTheDay, title: 'Bill due today', body: b.name));
    }
  }
  return out;
}
