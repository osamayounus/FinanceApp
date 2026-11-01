/// Something the user is saving towards. [saved] is the part of the Savings
/// account balance the user set aside for it (an envelope: it moves no money,
/// the balance stays in Savings). What no goal holds is "unallocated".
class SavingsGoal {
  final int id;
  final String name;
  final double target;
  final double saved;

  /// Optional day the goal should be reached by (time of day is always 00:00).
  final DateTime? targetDate;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.target,
    this.saved = 0,
    this.targetDate,
  });
}
