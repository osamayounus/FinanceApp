class ProfileModel {
  final String name;
  final int income;
  final int expenses;

  const ProfileModel({
    required this.name,
    required this.income,
    required this.expenses,
  });

  ProfileModel copyWith({String? name, int? income, int? expenses}) {
    return ProfileModel(
      name: name ?? this.name,
      income: income ?? this.income,
      expenses: expenses ?? this.expenses,
    );
  }
}
