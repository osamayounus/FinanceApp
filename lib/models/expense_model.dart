class ExpenseModel {
  final int id;
  final String name;
  final int amount;
  final bool isPaid;
  final String category;

  const ExpenseModel({
    required this.id,
    required this.name,
    required this.amount,
    this.isPaid = false,
    this.category = '',
  });

  ExpenseModel copyWith({String? name, int? amount, bool? isPaid, String? category}) {
    return ExpenseModel(
      id: id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isPaid: isPaid ?? this.isPaid,
      category: category ?? this.category,
    );
  }
}
