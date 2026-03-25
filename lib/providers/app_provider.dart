import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/models/user_model.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Nav ───────────────────────────────────────────────────────────────────────

final navIndexProvider = StateProvider<int>((ref) => 1);

// ── Database ──────────────────────────────────────────────────────────────────

final dbProvider =
    Provider<AppDatabase>((ref) => throw UnimplementedError());

// ── User ──────────────────────────────────────────────────────────────────────

class UserNotifier extends StateNotifier<UserModel> {
  final AppDatabase _db;
  UserNotifier(this._db, UserModel initial) : super(initial);

  Future<void> update({String? name, double? salary, double? monthlyBudget}) async {
    state = state.copyWith(
        name: name, salary: salary, monthlyBudget: monthlyBudget);
    await _db.updateUser(state);
  }
}

final userProvider =
    StateNotifierProvider<UserNotifier, UserModel>((ref) => throw UnimplementedError());

// ── Accounts ──────────────────────────────────────────────────────────────────

class AccountsNotifier extends StateNotifier<List<AccountModel>> {
  final AppDatabase _db;
  AccountsNotifier(this._db, List<AccountModel> initial) : super(initial);

  AccountModel get wallet => state.firstWhere((a) => a.id == kWalletId);
  AccountModel get budget => state.firstWhere((a) => a.id == kBudgetId);
  AccountModel get savings => state.firstWhere((a) => a.id == kSavingsId);

  Future<void> _setBalance(int accountId, double balance) async {
    state = [
      for (final a in state)
        if (a.id == accountId) a.copyWith(balance: balance) else a,
    ];
    await _db.updateBalance(accountId, balance);
  }

  Future<void> deposit(int accountId, double amount, TransactionModel tx) async {
    final current = state.firstWhere((a) => a.id == accountId);
    await _setBalance(accountId, current.balance + amount);
    await _db.insertTransaction(tx);
  }

  /// Returns false if the account has insufficient funds.
  Future<bool> withdraw(int accountId, double amount, TransactionModel tx) async {
    final current = state.firstWhere((a) => a.id == accountId);
    if (current.balance < amount) return false;
    await _setBalance(accountId, current.balance - amount);
    await _db.insertTransaction(tx);
    return true;
  }

  /// Returns false if the source account has insufficient funds.
  Future<bool> transfer({
    required int fromId,
    required int toId,
    required double amount,
    required TransactionModel txOut,
    required TransactionModel txIn,
  }) async {
    final from = state.firstWhere((a) => a.id == fromId);
    if (from.balance < amount) return false;
    final to = state.firstWhere((a) => a.id == toId);
    state = [
      for (final a in state)
        if (a.id == fromId)
          a.copyWith(balance: from.balance - amount)
        else if (a.id == toId)
          a.copyWith(balance: to.balance + amount)
        else
          a,
    ];
    await _db.updateBalance(fromId, from.balance - amount);
    await _db.updateBalance(toId, to.balance + amount);
    await _db.insertTransaction(txOut);
    await _db.insertTransaction(txIn);
    return true;
  }

  /// Called after salary day — updates wallet + budget balances in state.
  Future<void> processSalaryDay(double salary, double monthlyBudget) async {
    final result = await _db.processSalaryDay(
        salary: salary, monthlyBudget: monthlyBudget);
    state = [
      for (final a in state)
        if (a.id == kWalletId)
          a.copyWith(balance: result['wallet']!)
        else if (a.id == kBudgetId)
          a.copyWith(balance: result['budget']!)
        else
          a,
    ];
  }
}

final accountsProvider =
    StateNotifierProvider<AccountsNotifier, List<AccountModel>>(
        (ref) => throw UnimplementedError());

// ── Bills (Fixed Expenses) ────────────────────────────────────────────────────

class BillsNotifier extends StateNotifier<List<ExpenseModel>> {
  final AppDatabase _db;
  BillsNotifier(this._db, List<ExpenseModel> initial) : super(initial);

  Future<void> add(String name, int amount) async {
    final id = await _db.insertBill(name, amount);
    state = [...state, ExpenseModel(id: id, name: name, amount: amount)];
  }

  Future<void> edit(int index, String name, int amount) async {
    await _db.updateBill(state[index].id, name, amount);
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) state[i].copyWith(name: name, amount: amount) else state[i],
    ];
  }

  Future<void> delete(int index) async {
    await _db.deleteBill(state[index].id);
    state = [
      for (int i = 0; i < state.length; i++)
        if (i != index) state[i],
    ];
  }

  Future<void> markPaid(int index) async {
    await _db.markBillPaid(state[index].id);
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) state[i].copyWith(isPaid: true) else state[i],
    ];
  }

  void resetAll() {
    state = state.map((b) => b.copyWith(isPaid: false)).toList();
  }
}

// Keep the name 'expensesProvider' so FixedExpensesPage needs minimal changes.
final expensesProvider =
    StateNotifierProvider<BillsNotifier, List<ExpenseModel>>(
        (ref) => throw UnimplementedError());
