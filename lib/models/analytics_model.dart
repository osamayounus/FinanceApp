// ── AnalyticsModel ────────────────────────────────────────────────────────────
// Pure data classes used by analyticsProvider. Computed from the full
// transaction log on demand — nothing is persisted to the database.
// ─────────────────────────────────────────────────────────────────────────────

/// Income and expense totals for a single calendar month.
class MonthStat {
  final int year;
  final int month;

  /// Sum of `salary` + `deposit` transactions this month.
  /// Salary entries appear twice (wallet net + budget allocation) and together
  /// they represent the full salary received.
  final double income;

  /// Sum of `withdraw` + `bill_paid` transactions this month.
  final double expenses;

  const MonthStat({
    required this.year,
    required this.month,
    required this.income,
    required this.expenses,
  });

  /// Net gain/loss for the month.
  double get net => income - expenses;
}

/// Pre-computed analytics snapshot covering the last 6 months.
class AnalyticsData {
  /// Last 6 calendar months, oldest first (index 0 = 5 months ago).
  final List<MonthStat> months;

  /// Savings account end-of-month balance for the last 6 months, oldest first.
  /// Reconstructed backwards from the current live balance using the savings
  /// transaction log, so it always reflects real account history.
  final List<double> savingsHistory;

  /// Running savings balance after each transaction in the **current** month,
  /// sorted chronologically. Empty when no savings transactions occurred yet
  /// this month. When non-empty, the last value equals [savingsHistory.last].
  final List<double> currentMonthTimeline;

  const AnalyticsData({
    required this.months,
    required this.savingsHistory,
    required this.currentMonthTimeline,
  });

  /// Convenience accessor for the current (latest) month stats.
  MonthStat get currentMonth => months.last;
}
