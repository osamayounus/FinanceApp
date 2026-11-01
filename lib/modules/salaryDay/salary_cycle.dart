// ── Salary cycle ──────────────────────────────────────────────────────────────
// A cycle starts on the salary day (1-31) of each month and lasts until the
// next one; a salary day past the end of a short month falls on its last day.
// Pure date maths, shared by the DB guard and the Salary page.
// ─────────────────────────────────────────────────────────────────────────────

DateTime _on(int year, int month, int day) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day < last ? day : last);
}

/// First day of the cycle [now] is in: the latest salary day on or before today.
DateTime salaryCycleStart(DateTime now, int day) {
  final thisMonth = _on(now.year, now.month, day);
  return thisMonth.isAfter(DateTime(now.year, now.month, now.day))
      ? _on(now.year, now.month - 1, day)
      : thisMonth;
}

/// First day of the cycle after the one [now] is in.
DateTime nextSalaryDay(DateTime now, int day) {
  final start = salaryCycleStart(now, day);
  return _on(start.year, start.month + 1, day);
}

/// Salary already processed for the cycle [now] is in ([last] = the last run).
bool salaryProcessed(DateTime now, int day, DateTime? last) =>
    last != null && !last.isBefore(salaryCycleStart(now, day));

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String salaryDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// The line on the Salary page about where this cycle stands.
String salaryStatus(DateTime now, int day, DateTime? last) =>
    salaryProcessed(now, day, last)
        ? 'Salary processed on ${salaryDate(last!)} · next salary day ${salaryDate(nextSalaryDay(now, day))}'
        : 'Salary day ${salaryDate(salaryCycleStart(now, day))} · press the coin when your salary arrives';
