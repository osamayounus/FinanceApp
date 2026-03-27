class UserModel {
  final int id;
  final String name;
  final double salary;
  final double monthlyBudget;
  final String currency;

  const UserModel({
    required this.id,
    required this.name,
    required this.salary,
    required this.monthlyBudget,
    this.currency = 'JOD',
  });

  UserModel copyWith({
    String? name,
    double? salary,
    double? monthlyBudget,
    String? currency,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      salary: salary ?? this.salary,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'salary': salary,
        'monthly_budget': monthlyBudget,
        'currency': currency,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] as int,
        name: map['name'] as String,
        salary: (map['salary'] as num).toDouble(),
        monthlyBudget: (map['monthly_budget'] as num).toDouble(),
        currency: map['currency'] as String? ?? 'JOD',
      );
}
