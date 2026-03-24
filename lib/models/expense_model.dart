class ExpenseModel {
  final int id;
  final String name;
  final int amount;
  final bool isPaid;

  const ExpenseModel({
    required this.id,
    required this.name,
    required this.amount,
    this.isPaid = false,
  });

  ExpenseModel copyWith({String? name, int? amount, bool? isPaid}) {
    return ExpenseModel(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}
