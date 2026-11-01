/// Money lent to one person out of one account. [amount] is what was lent and
/// [repaid] what has come back. An account's `loaned_amount` is always the sum of
/// [remaining] over its debts.
class Debt {
  final int id;
  final int accountId;
  final String person;
  final double amount;
  final double repaid;

  /// Optional day it should be paid back by (time of day is always 00:00).
  final DateTime? dueDate;
  final DateTime createdAt;

  const Debt({
    required this.id,
    required this.accountId,
    required this.person,
    required this.amount,
    this.repaid = 0,
    this.dueDate,
    required this.createdAt,
  });

  double get remaining => amount - repaid;
}
