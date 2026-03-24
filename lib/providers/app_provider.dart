import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/models/profile_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current bottom nav index (default: 1 = Wallet/Home)
final navIndexProvider = StateProvider<int>((ref) => 1);

/// Expenses state notifier
class ExpensesNotifier extends StateNotifier<List<ExpenseModel>> {
  int _nextId = 3;

  ExpensesNotifier()
      : super(const [
          ExpenseModel(id: 1, name: 'My Family', amount: 100),
          ExpenseModel(id: 2, name: 'I phone', amount: 44),
        ]);

  void add(String name, int amount) {
    state = [...state, ExpenseModel(id: _nextId++, name: name, amount: amount)];
  }

  void edit(int index, String name, int amount) {
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) state[i].copyWith(name: name, amount: amount) else state[i],
    ];
  }

  void delete(int index) {
    state = [
      for (int i = 0; i < state.length; i++)
        if (i != index) state[i],
    ];
  }

  void markPaid(int index) {
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) state[i].copyWith(isPaid: true) else state[i],
    ];
  }
}

final expensesProvider =
    StateNotifierProvider<ExpensesNotifier, List<ExpenseModel>>(
  (ref) => ExpensesNotifier(),
);

/// Profile state notifier
class ProfileNotifier extends StateNotifier<ProfileModel> {
  ProfileNotifier()
      : super(const ProfileModel(name: 'Osama', income: 555, expenses: 80));

  void update({String? name, int? income, int? expenses}) {
    state = state.copyWith(name: name, income: income, expenses: expenses);
  }

  void reset() {
    state = const ProfileModel(name: 'Osama', income: 555, expenses: 80);
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileModel>(
  (ref) => ProfileNotifier(),
);
