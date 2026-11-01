class UserModel {
  final int id;
  final String name;
  final double salary;
  final double monthlyBudget;
  final String currency;

  /// Day of the month (1-31) the salary arrives; a new salary cycle starts then.
  final int salaryDay;

  const UserModel({
    required this.id,
    required this.name,
    required this.salary,
    required this.monthlyBudget,
    this.currency = 'JOD',
    this.salaryDay = 1,
  });

  UserModel copyWith({
    String? name,
    double? salary,
    double? monthlyBudget,
    String? currency,
    int? salaryDay,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      salary: salary ?? this.salary,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      currency: currency ?? this.currency,
      salaryDay: salaryDay ?? this.salaryDay,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'salary': salary,
        'monthly_budget': monthlyBudget,
        'currency': currency,
        'salary_day': salaryDay,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Absent in backups made before the salary day was configurable.
    final day = map['salary_day'];
    return UserModel(
      id: map['id'] as int,
      name: map['name'] as String,
      salary: (map['salary'] as num).toDouble(),
      monthlyBudget: (map['monthly_budget'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'JOD',
      salaryDay: day is int && day >= 1 && day <= 31 ? day : 1,
    );
  }
}
