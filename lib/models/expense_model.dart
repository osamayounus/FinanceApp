class ExpenseModel {
  final int id;
  final String name;
  final double amount;
  final bool isPaid;
  final String category;

  /// Day of the month (1-31) the bill is due, or null when it has no due date.
  final int? dueDay;

  /// Charged to the Wallet by itself once the due day comes (needs a [dueDay]).
  final bool autoPay;

  const ExpenseModel({
    required this.id,
    required this.name,
    required this.amount,
    this.isPaid = false,
    this.category = '',
    this.dueDay,
    this.autoPay = false,
  });

  ExpenseModel copyWith({String? name, double? amount, bool? isPaid, String? category}) {
    return ExpenseModel(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isPaid: isPaid ?? this.isPaid,
      category: category ?? this.category,
      dueDay: dueDay,
      autoPay: autoPay,
    );
  }
}
