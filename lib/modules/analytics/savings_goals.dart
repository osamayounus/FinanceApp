// ── Savings goals ─────────────────────────────────────────────────────────────
// Pure helpers: how much of each goal the Savings balance really backs, what is
// still unallocated, and what has to be put aside per month to reach a goal by
// its target date.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/models/savings_goal_model.dart';

/// [saved] is what the Savings balance really backs of this goal's envelope;
/// [perMonth] is what still has to be saved each month (null: reached, no date,
/// or the date has passed).
typedef GoalProgress = ({
  SavingsGoal goal,
  double saved,
  bool reached,
  bool late,
  double? perMonth,
});

const _daysPerMonth = 30.44;

/// Each goal holds what the user set aside for it, but never more than the
/// [savings] balance has left: if Savings dropped below what the goals hold, the
/// later goals show less (the stored amounts are kept, so they come back when the
/// balance does).
List<GoalProgress> goalProgress(
    List<SavingsGoal> goals, double savings, DateTime now) {
  // Whole calendar days via UTC: local midnights are 23 or 25 h apart over a clock change.
  final today = DateTime.utc(now.year, now.month, now.day);
  var left = savings > 0 ? savings : 0.0;
  final out = <GoalProgress>[];
  for (final g in goals) {
    final saved = left < g.saved ? left : g.saved;
    left -= saved;
    final reached = g.target - saved < 1e-9; // 0.1 + 0.2 style float dust
    final date = g.targetDate;
    final days = date == null
        ? null
        : DateTime.utc(date.year, date.month, date.day).difference(today).inDays;
    final months = days == null ? 1 : (days / _daysPerMonth).ceil(); // 0 days left: this month
    out.add((
      goal: g,
      saved: saved,
      reached: reached,
      late: !reached && days != null && days < 0,
      perMonth: reached || days == null || days < 0
          ? null
          : (g.target - saved) / (months < 1 ? 1 : months),
    ));
  }
  return out;
}

/// What a deposit (or withdrawal) of [amount] really moves in [g]'s envelope: a
/// deposit cannot overfill it, a withdrawal cannot take more than it holds.
double goalShare(SavingsGoal g, double amount, {required bool deposit}) {
  final room = deposit ? g.target - g.saved : g.saved;
  if (!(room > 0)) return 0;
  return amount < room ? amount : room;
}

/// Part of [savings] that no goal holds.
double unallocated(List<GoalProgress> progress, double savings) {
  final free = savings - progress.fold(0.0, (s, p) => s + p.saved);
  return free > 0 ? free : 0;
}

/// How much the goals hold on paper beyond what [savings] backs (after Savings
/// was spent down); 0 when everything is covered.
double uncovered(List<GoalProgress> progress) =>
    progress.fold(0.0, (s, p) => s + p.goal.saved - p.saved);
