class ProfileModel {
  final String name;
  final double income;
  final double expenses;

  const ProfileModel({
    required this.name,
    required this.income,
    required this.expenses,
  });

  ProfileModel copyWith({String? name, double? income, double? expenses}) {
    return ProfileModel(
      name: name ?? this.name,
      income: income ?? this.income,
      expenses: expenses ?? this.expenses,
    );
  }
}
