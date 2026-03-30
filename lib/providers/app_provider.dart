import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/analytics_model.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/models/user_model.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Nav ───────────────────────────────────────────────────────────────────────

// Tracks the currently selected bottom-nav index.
// 0 = Salary Day, 1 = Home/Wallet, 2 = Analytics, 3 = Profile
final navIndexProvider = StateProvider<int>((ref) => 1);

// ── Database ──────────────────────────────────────────────────────────────────

// All providers here are seeded with `throw UnimplementedError()` as a
// placeholder. main.dart overrides them via ProviderScope(overrides: [...])
// once real data has been loaded from SQLite.
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

/// Convenience provider — reads the user's selected currency symbol (e.g. 'JOD').
final currencyProvider = Provider<String>((ref) => ref.watch(userProvider).currency);

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
    // Write transaction to DB before updating state so analyticsProvider reads
    // the complete picture when it re-runs after the state change.
    await _db.insertTransaction(tx);
    await _setBalance(accountId, current.balance + amount);
  }

  /// Returns false if the account has insufficient funds.
  Future<bool> withdraw(int accountId, double amount, TransactionModel tx) async {
    final current = state.firstWhere((a) => a.id == accountId);
    if (current.balance < amount) return false;
    // Same ordering as deposit — transaction in DB before state change.
    await _db.insertTransaction(tx);
    await _setBalance(accountId, current.balance - amount);
    return true;
  }

  /// Returns false if the source account has insufficient funds.
  ///
  /// All DB writes (balances + transactions) complete before state is updated.
  /// This ensures analyticsProvider reads a consistent snapshot when it
  /// re-runs in response to the state change. On local SQLite the writes
  /// complete in ~1 ms so there is no perceptible delay in the UI.
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
    await _db.updateBalance(fromId, from.balance - amount);
    await _db.updateBalance(toId, to.balance + amount);
    await _db.insertTransaction(txOut);
    await _db.insertTransaction(txIn);
    // Update in-memory state last — analyticsProvider re-runs here and the
    // DB already has the full updated picture.
    state = [
      for (final a in state)
        if (a.id == fromId)
          a.copyWith(balance: from.balance - amount)
        else if (a.id == toId)
          a.copyWith(balance: to.balance + amount)
        else
          a,
    ];
    return true;
  }

  Future<AccountModel> addCustomAccount(String name, int colorIndex, int iconCode) async {
    final id = await _db.insertCustomAccount(name, colorIndex, iconCode);
    final account = AccountModel(
      id: id,
      type: AccountType.custom,
      balance: 0.0,
      customName: name,
      colorIndex: colorIndex,
      iconCode: iconCode,
    );
    state = [...state, account];
    return account;
  }

  Future<void> updateCustomAccount(
      int accountId, String name, int colorIndex, int iconCode) async {
    await _db.updateCustomAccount(accountId, name, colorIndex, iconCode);
    state = [
      for (final a in state)
        if (a.id == accountId)
          AccountModel(
            id: a.id,
            type: a.type,
            balance: a.balance,
            customName: name,
            colorIndex: colorIndex,
            iconCode: iconCode,
          )
        else
          a,
    ];
  }

  /// Deletes a custom account.
  /// When [transferToWallet] is true, the account's remaining balance is swept
  /// into the wallet before deletion so no money is "lost" from the total.
  Future<void> deleteCustomAccount(int accountId,
      {bool transferToWallet = false}) async {
    if (transferToWallet) {
      final account = state.firstWhere((a) => a.id == accountId);
      if (account.balance > 0) {
        final wallet = state.firstWhere((a) => a.id == kWalletId);
        final now = DateTime.now();
        await _db.updateBalance(kWalletId, wallet.balance + account.balance);
        await _db.insertTransaction(TransactionModel(
          id: 0,
          accountId: kWalletId,
          type: 'transfer_in',
          amount: account.balance,
          title: 'Transfer',
          note: account.displayName,
          relatedAccountId: accountId,
          createdAt: now,
        ));
        state = [
          for (final a in state)
            if (a.id == kWalletId)
              a.copyWith(balance: wallet.balance + account.balance)
            else
              a,
        ];
      }
    }
    // deleteAccount also removes all transaction history for this account.
    await _db.deleteAccount(accountId);
    state = state.where((a) => a.id != accountId).toList();
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

  Future<void> add(String name, double amount, String category) async {
    final id = await _db.insertBill(name, amount, category);
    state = [...state, ExpenseModel(id: id, name: name, amount: amount, category: category)];
  }

  Future<void> edit(int index, String name, double amount, String category) async {
    await _db.updateBill(state[index].id, name, amount, category);
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) state[i].copyWith(name: name, amount: amount, category: category) else state[i],
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

// ── Analytics ─────────────────────────────────────────────────────────────────

/// Computes monthly income/expense stats for the last 6 months.
///
/// Watches [accountsProvider] so it re-runs automatically after every
/// transaction write (every deposit/withdraw/transfer updates at least one
/// account balance, which invalidates this provider).
final analyticsProvider = FutureProvider.autoDispose<AnalyticsData>((ref) async {
  ref.watch(accountsProvider);
  final db = ref.read(dbProvider);
  final allTxs = await db.getAllTransactions();
  // Fetch savings transactions separately for the balance-history computation.
  final savingsTxs = await db.getTransactions(kSavingsId);
  final currentSavings = ref
      .read(accountsProvider)
      .firstWhere((a) => a.id == kSavingsId)
      .balance;
  return _computeAnalytics(allTxs, savingsTxs, currentSavings);
});

/// Builds [AnalyticsData] from the raw transaction lists.
///
/// Income   = salary + deposit (wallet + budget salary entries sum to full salary).
/// Expenses = withdraw + bill_paid.
/// transfer_in/out and initial are excluded — internal moves only.
///
/// Savings history is reconstructed backwards from [currentSavings]:
///   balance_at_end_of_month = currentSavings − net_savings_transactions_after_that_month
AnalyticsData _computeAnalytics(
  List<TransactionModel> txs,
  List<TransactionModel> savingsTxs,
  double currentSavings,
) {
  final now = DateTime.now();
  final months = <MonthStat>[];

  for (int i = 5; i >= 0; i--) {
    final date = DateTime(now.year, now.month - i);
    double income = 0;
    double expenses = 0;

    for (final tx in txs) {
      if (tx.createdAt.year != date.year || tx.createdAt.month != date.month) {
        continue;
      }
      if (tx.type == 'salary' || tx.type == 'deposit') income += tx.amount;
      if (tx.type == 'withdraw' || tx.type == 'bill_paid') expenses += tx.amount;
    }

    months.add(MonthStat(
      year: date.year,
      month: date.month,
      income: income,
      expenses: expenses,
    ));
  }

  // ── Savings balance history ─────────────────────────────────────────────
  // For each month, sum every savings transaction that falls AFTER the end of
  // that month, then subtract from the current live balance to get what the
  // balance was at the end of that month.
  final savingsHistory = <double>[];
  for (int i = 5; i >= 0; i--) {
    // cutoff = first instant of the month that follows month[i].
    final cutoff = DateTime(now.year, now.month - i + 1);
    double netAfterCutoff = 0;

    for (final tx in savingsTxs) {
      if (tx.createdAt.isBefore(cutoff)) continue;
      if (tx.type == 'transfer_in' || tx.type == 'deposit' || tx.type == 'initial') {
        netAfterCutoff += tx.amount;
      } else if (tx.type == 'transfer_out' || tx.type == 'withdraw') {
        netAfterCutoff -= tx.amount;
      }
    }

    savingsHistory.add(currentSavings - netAfterCutoff);
  }

  // ── Current-month savings timeline ─────────────────────────────────────
  // Reconstruct the running savings balance after each individual transaction
  // that occurred in the current calendar month. Past months show only their
  // end-of-month snapshot; the current month shows each operation's impact.
  final currentMonthStart = DateTime(now.year, now.month);
  final currentMonthTxs = savingsTxs
      .where((tx) => !tx.createdAt.isBefore(currentMonthStart))
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  // Starting balance for the current month = end-of-last-month snapshot.
  double runningBal = savingsHistory[4];
  final currentMonthTimeline = <double>[];
  for (final tx in currentMonthTxs) {
    if (tx.type == 'transfer_in' ||
        tx.type == 'deposit' ||
        tx.type == 'initial') {
      runningBal += tx.amount;
    } else if (tx.type == 'transfer_out' || tx.type == 'withdraw') {
      runningBal -= tx.amount;
    }
    currentMonthTimeline.add(runningBal);
  }

  return AnalyticsData(
    months: months,
    savingsHistory: savingsHistory,
    currentMonthTimeline: currentMonthTimeline,
  );
}
