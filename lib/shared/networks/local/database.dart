import 'dart:convert';
import 'dart:io';

import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/debt_model.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/models/savings_goal_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/models/user_model.dart';
import 'package:financeapp/modules/fixedExp/bill_due.dart';
import 'package:financeapp/modules/salaryDay/salary_cycle.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A validated backup, ready for [AppDatabase.restoreBackup].
typedef BackupRows = ({
  DateTime? exportedAt,
  Map<String, Object?> user,
  List<Map<String, Object?>> accounts,
  List<Map<String, Object?>> transactions,
  List<Map<String, Object?>> bills,
  List<Map<String, Object?>> categoryBudgets,
  List<Map<String, Object?>> savingsGoals,
  List<Map<String, Object?>> debts,
});

/// Thrown by [AppDatabase.processSalaryDay] when this salary cycle's salary was
/// already processed.
class SalaryAlreadyProcessed implements Exception {
  final DateTime at;
  final DateTime cycleStart;
  const SalaryAlreadyProcessed(this.at, this.cycleStart);
}

/// Per-profile data-access layer for a SQLite database.
/// Each user profile owns a separate file (e.g. finance_1.db).
/// Instances are cached by filename so the same file is never opened twice.
class AppDatabase {
  // ── Instance cache ────────────────────────────────────────────────────────
  static final _instances = <String, AppDatabase>{};

  /// Returns (or creates) the AppDatabase for a given file name.
  static AppDatabase forFile(String fileName) =>
      _instances.putIfAbsent(fileName, () => AppDatabase._(fileName));

  final String _fileName;
  Database? _db;

  AppDatabase._(this._fileName);

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _openDB();
    return _db!;
  }

  /// Closes the underlying SQLite connection and removes this instance from
  /// the cache. Call before deleting the file (e.g. on profile reset).
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _instances.remove(_fileName);
  }

  Future<Database> _openDB() async {
    // sqflite only ships a native plugin for Android/iOS. On desktop we must
    // swap in the FFI implementation before any database calls are made.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _fileName);
    return openDatabase(
      path,
      version: 14,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Additive migration strategy: each version gate only adds columns/tables,
  /// never drops anything, so upgrades can safely skip versions
  /// (e.g. v1 → v5 runs all four blocks sequentially).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      // Custom account metadata added in v3
      await db.execute('ALTER TABLE accounts ADD COLUMN custom_name TEXT');
      await db.execute('ALTER TABLE accounts ADD COLUMN color_index INTEGER');
      await db.execute('ALTER TABLE accounts ADD COLUMN icon_code INTEGER');
    }
    if (oldVersion < 4) {
      // Bill category tagging added in v4
      await db.execute("ALTER TABLE bills ADD COLUMN category TEXT NOT NULL DEFAULT ''");
    }
    if (oldVersion < 5) {
      // Per-user currency preference added in v5; defaults to JOD for existing installs
      await db.execute("ALTER TABLE user ADD COLUMN currency TEXT NOT NULL DEFAULT 'JOD'");
    }
    if (oldVersion < 6) {
      // Per-user currency preference (already handled in v5 block above —
      // this block intentionally left empty for version-gap safety).
    }
    if (oldVersion < 7) {
      // Debt/loan tracking: stores the total amount lent out per account.
      // Wrapped in try-catch so re-running after a partial v6 migration
      // (where the version was bumped but the column was not added) is safe.
      try {
        await db.execute(
            'ALTER TABLE accounts ADD COLUMN loaned_amount REAL DEFAULT 0.0');
      } catch (_) {
        // Column already exists — nothing to do.
      }
    }
    if (oldVersion < 8) {
      // Spending categories: a tag on each transaction + a monthly limit per category.
      await db.execute(
          "ALTER TABLE transactions ADD COLUMN category TEXT NOT NULL DEFAULT ''");
      await db.execute(_categoryBudgetsDdl);
    }
    if (oldVersion < 9) {
      // Optional day of the month a bill is due (1-31); NULL = no due date.
      await db.execute('ALTER TABLE bills ADD COLUMN due_day INTEGER');
    }
    if (oldVersion < 10) {
      await db.execute(_savingsGoalsDdl); // already has `saved`
    } else if (oldVersion < 11) {
      // Goals used to be filled from the Savings balance in order; now each holds
      // what the user set aside, so existing goals start empty.
      await db.execute(
          'ALTER TABLE savings_goals ADD COLUMN saved REAL NOT NULL DEFAULT 0');
    }
    if (oldVersion < 12) {
      // Day of the month the salary arrives; 1 = the calendar month, as before.
      await db.execute(
          'ALTER TABLE user ADD COLUMN salary_day INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 13) {
      await db.execute(_debtsDdl);
      // Money already lent out has no person: give each account one row so its
      // loaned_amount is still the sum of its debts.
      await db.rawInsert('''
        INSERT INTO debts (account_id, person, amount, created_at)
        SELECT id, ?, loaned_amount, ? FROM accounts WHERE loaned_amount > 0
      ''', [_earlierDebts, DateTime.now().millisecondsSinceEpoch]);
    }
    if (oldVersion < 14) {
      // A bill can charge the Wallet by itself on its due day; off for existing bills.
      await db.execute(
          'ALTER TABLE bills ADD COLUMN auto_pay INTEGER NOT NULL DEFAULT 0');
    }
  }

  /// Who debts that were lent before people were recorded are lent to.
  static const _earlierDebts = 'Earlier debts';

  static const _debtsDdl = '''
    CREATE TABLE IF NOT EXISTS debts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL,
      person TEXT NOT NULL,
      amount REAL NOT NULL,
      repaid REAL NOT NULL DEFAULT 0,
      due_date INTEGER,
      created_at INTEGER NOT NULL
    )
  ''';

  static const _savingsGoalsDdl = '''
    CREATE TABLE IF NOT EXISTS savings_goals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      target REAL NOT NULL,
      saved REAL NOT NULL DEFAULT 0,
      target_date INTEGER
    )
  ''';

  static const _categoryBudgetsDdl = '''
    CREATE TABLE IF NOT EXISTS category_budgets (
      category TEXT PRIMARY KEY,
      amount REAL NOT NULL
    )
  ''';

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        salary REAL NOT NULL,
        monthly_budget REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'JOD',
        salary_day INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0.0,
        loaned_amount REAL DEFAULT 0.0,
        custom_name TEXT,
        color_index INTEGER,
        icon_code INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        note TEXT DEFAULT '',
        category TEXT NOT NULL DEFAULT '',
        related_account_id INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(_categoryBudgetsDdl);
    await db.execute(_savingsGoalsDdl);
    await db.execute(_debtsDdl);
    await db.execute('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        is_paid INTEGER NOT NULL DEFAULT 0,
        category TEXT NOT NULL DEFAULT '',
        due_day INTEGER,
        auto_pay INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ── User ──────────────────────────────────────────────────────────────────

  Future<bool> hasUser() async {
    final db = await database;
    final r = await db.query('user', limit: 1);
    return r.isNotEmpty;
  }

  Future<UserModel?> getUser() async {
    final db = await database;
    final r = await db.query('user', limit: 1);
    return r.isEmpty ? null : UserModel.fromMap(r.first);
  }

  Future<void> insertUser(UserModel user) async {
    final db = await database;
    await db.insert('user', user.toMap());
  }

  Future<void> updateUser(UserModel user) async {
    final db = await database;
    await db.update('user', user.toMap(),
        where: 'id = ?', whereArgs: [user.id]);
  }

  // ── Accounts ──────────────────────────────────────────────────────────────

  Future<void> initAccounts({
    required double initialSavings,
    required double salary,
    required double monthlyBudget,
  }) async {
    if (monthlyBudget > salary) {
      throw ArgumentError('Monthly budget cannot exceed the salary');
    }
    final db = await database;
    final now = DateTime.now();
    final walletBalance = salary - monthlyBudget;

    await db.insert('accounts',
        {'id': kWalletId, 'type': 'wallet', 'balance': walletBalance});
    await db.insert('accounts',
        {'id': kBudgetId, 'type': 'budget', 'balance': monthlyBudget});
    await db.insert('accounts',
        {'id': kSavingsId, 'type': 'savings', 'balance': initialSavings});

    // Record initial salary transactions
    await insertTransaction(TransactionModel(
      id: 0,
      accountId: kWalletId,
      type: 'salary',
      amount: walletBalance,
      title: 'Salary',
      createdAt: now,
    ));
    await insertTransaction(TransactionModel(
      id: 0,
      accountId: kBudgetId,
      type: 'salary',
      amount: monthlyBudget,
      title: 'Monthly Budget Reset',
      createdAt: now,
    ));
    if (initialSavings > 0) {
      await insertTransaction(TransactionModel(
        id: 0,
        accountId: kSavingsId,
        type: 'initial',
        amount: initialSavings,
        title: 'Initial Savings',
        createdAt: now,
      ));
    }
  }

  Future<List<AccountModel>> getAccounts() async {
    final db = await database;
    final r = await db.query('accounts');
    return r.map((map) => AccountModel.fromMap(map)).toList();
  }

  Future<void> updateBalance(int accountId, double balance) async {
    final db = await database;
    await db.update('accounts', {'balance': balance},
        where: 'id = ?', whereArgs: [accountId]);
  }

  /// Writes one account's new balance (and, for debt moves, its new
  /// [loanedAmount]) together with the transaction that caused it, atomically.
  /// [lend] also records a debt of the transaction's amount; [repaysDebt] also
  /// takes the transaction's amount off that debt (nothing is written when it
  /// is not an open debt of this account with that much still owed).
  Future<void> applyTx({
    required int accountId,
    required double balance,
    double? loanedAmount,
    required TransactionModel tx,
    ({String person, DateTime? due})? lend,
    int? repaysDebt,
  }) async {
    if (lend != null) _checkPerson(lend.person);
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
          'accounts', {'balance': balance, 'loaned_amount': ?loanedAmount},
          where: 'id = ?', whereArgs: [accountId]);
      await txn.insert('transactions', tx.toMap());
      if (lend != null) {
        await txn.insert('debts', {
          'account_id': accountId,
          'person': lend.person.trim(),
          'amount': tx.amount,
          'due_date': _dayMillis(lend.due),
          'created_at': tx.createdAt.millisecondsSinceEpoch,
        });
      }
      if (repaysDebt != null) {
        final n = await txn.rawUpdate(
          'UPDATE debts SET repaid = MIN(amount, repaid + ?) '
          'WHERE id = ? AND account_id = ? AND amount - repaid >= ? - 0.005',
          [tx.amount, repaysDebt, accountId, tx.amount],
        );
        if (n != 1) throw StateError('Not an open debt of this account');
      }
    });
  }

  static void _checkPerson(String person) {
    if (person.trim().isEmpty) throw ArgumentError('A debt needs a person');
  }

  /// Debts still owed, soonest due first (no due date last, then oldest first).
  Future<List<Debt>> getOpenDebts() async {
    final db = await database;
    final r = await db.query(
      'debts',
      where: 'amount - repaid > 0.005',
      orderBy: 'due_date IS NULL, due_date ASC, id ASC',
    );
    return [
      for (final row in r)
        Debt(
          id: row['id'] as int,
          accountId: row['account_id'] as int,
          person: row['person'] as String,
          amount: (row['amount'] as num).toDouble(),
          repaid: (row['repaid'] as num).toDouble(),
          dueDate: row['due_date'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(row['due_date'] as int),
          createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        ),
    ];
  }

  /// Fixes who owes it or when it is due; omitting [dueDate] clears it. The
  /// amounts only change through lending and receiving back.
  Future<void> updateDebt(int id,
      {required String person, DateTime? dueDate}) async {
    _checkPerson(person);
    final db = await database;
    await db.update(
      'debts',
      {'person': person.trim(), 'due_date': _dayMillis(dueDate)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Moves money between two accounts atomically: both balances and both
  /// transaction rows are written, or none of them are.
  Future<void> transferFunds({
    required int fromId,
    required double fromBalance,
    required int toId,
    required double toBalance,
    required TransactionModel txOut,
    required TransactionModel txIn,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('accounts', {'balance': fromBalance},
          where: 'id = ?', whereArgs: [fromId]);
      await txn.update('accounts', {'balance': toBalance},
          where: 'id = ?', whereArgs: [toId]);
      await txn.insert('transactions', txOut.toMap());
      await txn.insert('transactions', txIn.toMap());
    });
  }

  Future<void> updateCustomAccount(
      int id, String name, int colorIndex, int iconCode) async {
    final db = await database;
    await db.update(
      'accounts',
      {'custom_name': name, 'color_index': colorIndex, 'icon_code': iconCode},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertCustomAccount(String name, int colorIndex, int iconCode) async {
    final db = await database;
    final id = await db.insert('accounts', {
      'type': 'custom',
      'balance': 0.0,
      'custom_name': name,
      'color_index': colorIndex,
      'icon_code': iconCode,
    });
    return id;
  }

  Future<void> deleteAccount(int id) async {
    if (id == kWalletId || id == kBudgetId || id == kSavingsId) {
      throw ArgumentError('The built-in accounts cannot be deleted');
    }
    final db = await database;
    // Wrap in a transaction so the account row and its history are deleted
    // atomically — a partial delete would leave orphaned transaction records.
    await db.transaction((txn) async {
      await txn.delete('transactions', where: 'account_id = ?', whereArgs: [id]);
      await txn.delete('debts', where: 'account_id = ?', whereArgs: [id]);
      await txn.delete('accounts', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  Future<List<TransactionModel>> getTransactions(int accountId) async {
    final db = await database;
    final r = await db.query(
      'transactions',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'created_at DESC',
    );
    return r.map(TransactionModel.fromMap).toList();
  }

  /// Returns every transaction across all accounts, newest first.
  /// Used by [analyticsProvider] to compute monthly income/expense stats.
  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final r = await db.query('transactions', orderBy: 'created_at DESC');
    return r.map(TransactionModel.fromMap).toList();
  }

  Future<void> insertTransaction(TransactionModel tx) async {
    final db = await database;
    await db.insert('transactions', tx.toMap());
  }

  /// Types that can be corrected on their own: their only effect is +/- amount
  /// on their own account. Transfers are two linked rows, bills also flip the
  /// bill's paid flag and debts also move loaned_amount, so those stay as logged.
  static const editableTxTypes = {'deposit', 'withdraw'};

  /// Rewrites a deposit/withdraw and moves its account's balance by the
  /// difference, atomically. A null [category] keeps the stored one. Returns
  /// false, changing nothing, when the row is gone or not editable, [amount] is
  /// not positive, or the balance would go negative.
  Future<bool> updateTransaction(int id,
      {required double amount,
      required String title,
      required String note,
      String? category}) async {
    // "9" * 400 parses to Infinity, which would poison the balance.
    if (!(amount > 0 && amount.isFinite)) return false;
    final db = await database;
    return db.transaction((txn) async {
      final tx = await _editableTx(txn, id);
      if (tx == null) return false;
      final delta = _signed(tx, amount) - _signed(tx, tx.amount);
      if (!await _shiftBalance(txn, tx.accountId, delta)) return false;
      await txn.update(
          'transactions',
          {
            'amount': amount,
            'title': title,
            'note': note,
            if (category != null) 'category': category,
          },
          where: 'id = ?',
          whereArgs: [id]);
      return true;
    });
  }

  /// Deletes a deposit/withdraw and reverses its effect on the balance,
  /// atomically. Returns false, changing nothing, when the row is gone or not
  /// editable, or reversing a deposit would take the balance below zero.
  Future<bool> deleteTransaction(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final tx = await _editableTx(txn, id);
      if (tx == null) return false;
      if (!await _shiftBalance(txn, tx.accountId, -_signed(tx, tx.amount))) {
        return false;
      }
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
      return true;
    });
  }

  /// The row as it is on disk right now (never the caller's copy, which may be
  /// stale), or null when it is missing or not of an editable type.
  Future<TransactionModel?> _editableTx(DatabaseExecutor ex, int id) async {
    final rows = await ex.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final tx = TransactionModel.fromMap(rows.first);
    return editableTxTypes.contains(tx.type) ? tx : null;
  }

  /// Effect of an [amount] of this transaction's type on its account balance.
  double _signed(TransactionModel tx, double amount) =>
      tx.type == 'deposit' ? amount : -amount;

  /// Adds [delta] to the account balance; false (nothing written) if it would
  /// end up negative.
  Future<bool> _shiftBalance(
      DatabaseExecutor ex, int accountId, double delta) async {
    final balance = await _balanceOf(ex, accountId) + delta;
    // Balances are REAL, so a sum of cents can land a hair under zero.
    if (balance < -1e-9) return false;
    await ex.update('accounts', {'balance': balance < 0 ? 0.0 : balance},
        where: 'id = ?', whereArgs: [accountId]);
    return true;
  }

  // ── Bills ─────────────────────────────────────────────────────────────────

  Future<List<ExpenseModel>> getBills() async {
    final db = await database;
    final r = await db.query('bills', orderBy: 'id ASC');
    return r
        .map((e) => ExpenseModel(
              id: e['id'] as int,
              name: e['name'] as String,
              amount: (e['amount'] as num).toDouble(),
              isPaid: (e['is_paid'] as int) == 1,
              category: e['category'] as String? ?? '',
              dueDay: e['due_day'] as int?,
              autoPay: (e['auto_pay'] as int) == 1,
            ))
        .toList();
  }

  /// A [dueDay] outside 1-31 is stored as "no due date".
  static int? validDay(int? day) => day != null && day >= 1 && day <= 31 ? day : null;

  /// Auto-pay needs a due day to know when to charge.
  static int _autoPayFlag(bool autoPay, int? dueDay) =>
      autoPay && validDay(dueDay) != null ? 1 : 0;

  Future<int> insertBill(String name, double amount, String category,
      {int? dueDay, bool autoPay = false}) async {
    final db = await database;
    return db.insert('bills', {
      'name': name,
      'amount': amount,
      'is_paid': 0,
      'category': category,
      'due_day': validDay(dueDay),
      'auto_pay': _autoPayFlag(autoPay, dueDay),
    });
  }

  Future<void> updateBill(int id, String name, double amount, String category,
      {int? dueDay, bool autoPay = false}) async {
    final db = await database;
    await db.update(
      'bills',
      {
        'name': name,
        'amount': amount,
        'category': category,
        'due_day': validDay(dueDay),
        'auto_pay': _autoPayFlag(autoPay, dueDay),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Charges the Wallet for every unpaid auto-pay bill whose due day has come
  /// (soonest first) and marks it paid. A bill is claimed, charged and logged as
  /// a `bill_paid` transaction in one SQLite transaction, so it can never be
  /// charged twice or charged without being marked paid. A bill the Wallet
  /// cannot cover stays unpaid and the next one is tried. Returns the ids paid.
  Future<List<int>> autoPayDueBills(DateTime now) async {
    final cycleStart = await billCycleStart();
    final today = DateTime(now.year, now.month, now.day);
    final due = <(ExpenseModel, DateTime)>[
      for (final b in await getBills())
        if (b.autoPay && !b.isPaid)
          if (dueDateOf(b, cycleStart) case final d? when !d.isAfter(today)) (b, d),
    ]..sort((a, b) {
        final byDate = a.$2.compareTo(b.$2);
        return byDate != 0 ? byDate : a.$1.id.compareTo(b.$1.id);
      });
    final db = await database;
    final paid = <int>[];
    for (final (bill, _) in due) {
      await db.transaction((txn) async {
        final claimed = await txn.rawUpdate(
            'UPDATE bills SET is_paid = 1 WHERE id = ? AND is_paid = 0', [bill.id]);
        if (claimed != 1) return; // paid by hand (or deleted) in the meantime
        final charged = await txn.rawUpdate(
            'UPDATE accounts SET balance = balance - ? WHERE id = ? AND balance >= ?',
            [bill.amount, kWalletId, bill.amount]);
        if (charged != 1) {
          await txn.rawUpdate('UPDATE bills SET is_paid = 0 WHERE id = ?', [bill.id]);
          return;
        }
        await txn.insert(
          'transactions',
          TransactionModel(
            id: 0,
            accountId: kWalletId,
            type: 'bill_paid',
            amount: bill.amount,
            title: bill.name,
            note: AppStrings.monthlyBill,
            category: bill.category,
            createdAt: now,
          ).toMap(),
        );
        paid.add(bill.id);
      });
    }
    return paid;
  }

  /// When the current bill cycle began: the last salary day (it resets every
  /// bill to unpaid), or the 1st of this month when there has been none.
  Future<DateTime> billCycleStart() async {
    final db = await database;
    final r = await db.rawQuery(
        "SELECT MAX(created_at) AS at FROM transactions WHERE type = 'salary'");
    final at = r.first['at'] as int?;
    if (at != null) return DateTime.fromMillisecondsSinceEpoch(at);
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  Future<void> deleteBill(int id) async {
    final db = await database;
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markBillPaid(int id) async {
    final db = await database;
    await db.update('bills', {'is_paid': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> resetAllBills() async {
    final db = await database;
    await db.update('bills', {'is_paid': 0});
  }

  // ── Salary Day ────────────────────────────────────────────────────────────

  static const _lastSalaryKey = 'last_salary_at';

  Future<DateTime?> _lastSalaryAt(DatabaseExecutor db) async {
    final r = await db.query('settings',
        where: 'key = ?', whereArgs: [_lastSalaryKey], limit: 1);
    final ms = r.isEmpty ? null : int.tryParse(r.first['value'] as String);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// When [processSalaryDay] last ran; null if it never has.
  Future<DateTime?> lastSalaryProcessedAt() async => _lastSalaryAt(await database);

  /// Executes the salary-day flow atomically in 5 steps:
  ///   1. Sweep any remaining budget balance into the wallet (rollover).
  ///   2. Credit the net income (salary − budget) to the wallet.
  ///   3. Reset the budget account back to [monthlyBudget].
  ///   4. Persist both updated balances.
  ///   5. Mark all bills as unpaid for the new month.
  ///
  /// All steps run inside a single SQLite transaction so a crash mid-way
  /// leaves the database unchanged.
  ///
  /// Only once per salary cycle (it starts on the user's salary day): a second
  /// run throws [SalaryAlreadyProcessed] and changes nothing. The onboarding
  /// seed does not count, only runs of this method do ([_lastSalaryKey]).
  Future<Map<String, double>> processSalaryDay({
    required double salary,
    required double monthlyBudget,
    DateTime? at, // when it happens; only tests pass it
  }) async {
    if (monthlyBudget > salary) {
      throw ArgumentError('Monthly budget cannot exceed the salary');
    }
    final db = await database;
    final now = at ?? DateTime.now();
    double walletBalance = 0;
    double budgetBalance = 0;

    await db.transaction((txn) async {
      final u = await txn.query('user', columns: ['salary_day'], limit: 1);
      final cycleStart =
          salaryCycleStart(now, u.isEmpty ? 1 : u.first['salary_day'] as int);
      final last = await _lastSalaryAt(txn);
      if (last != null && !last.isBefore(cycleStart)) {
        throw SalaryAlreadyProcessed(last, cycleStart);
      }
      await txn.insert(
        'settings',
        {'key': _lastSalaryKey, 'value': '${now.millisecondsSinceEpoch}'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Read inside the transaction: balances read before it could be stale by
      // the time we write, silently overwriting a concurrent deposit/withdraw.
      walletBalance = await _balanceOf(txn, kWalletId);
      budgetBalance = await _balanceOf(txn, kBudgetId);

      // 1. Transfer any leftover budget to wallet
      if (budgetBalance > 0) {
        walletBalance += budgetBalance;
        await txn.insert('transactions', {
          'account_id': kBudgetId,
          'type': 'transfer_out',
          'amount': budgetBalance,
          'title': 'Leftover to Wallet',
          'note': '',
          'related_account_id': kWalletId,
          'created_at': now.millisecondsSinceEpoch,
        });
        await txn.insert('transactions', {
          'account_id': kWalletId,
          'type': 'transfer_in',
          'amount': budgetBalance,
          'title': 'Budget Leftover',
          'note': '',
          'related_account_id': kBudgetId,
          'created_at': now.millisecondsSinceEpoch,
        });
      }

      // 2. Add net income (salary - budget) to wallet
      final netIncome = salary - monthlyBudget;
      walletBalance += netIncome;
      await txn.insert('transactions', {
        'account_id': kWalletId,
        'type': 'salary',
        'amount': netIncome,
        'title': 'Salary',
        'note': '',
        'related_account_id': null,
        'created_at': now.millisecondsSinceEpoch,
      });

      // 3. Reset budget account to monthly budget
      await txn.insert('transactions', {
        'account_id': kBudgetId,
        'type': 'salary',
        'amount': monthlyBudget,
        'title': 'Monthly Budget Reset',
        'note': '',
        'related_account_id': null,
        'created_at': now.millisecondsSinceEpoch,
      });
      budgetBalance = monthlyBudget;

      // 4. Update balances in DB
      await txn.update('accounts', {'balance': walletBalance},
          where: 'id = ?', whereArgs: [kWalletId]);
      await txn.update('accounts', {'balance': budgetBalance},
          where: 'id = ?', whereArgs: [kBudgetId]);

      // 5. Reset all bills to unpaid
      await txn.update('bills', {'is_paid': 0});
    });

    return {'wallet': walletBalance, 'budget': budgetBalance};
  }

  Future<double> _balanceOf(DatabaseExecutor ex, int accountId) async {
    final rows = await ex.query('accounts',
        columns: ['balance'], where: 'id = ?', whereArgs: [accountId]);
    if (rows.isEmpty) {
      throw StateError('Account #$accountId is missing - profile not initialised');
    }
    return (rows.first['balance'] as num).toDouble();
  }

  // ── Category budgets ──────────────────────────────────────────────────────

  /// Monthly spending limit per category name; categories without one are absent.
  Future<Map<String, double>> getCategoryBudgets() async {
    final db = await database;
    final r = await db.query('category_budgets');
    return {
      for (final row in r)
        row['category'] as String: (row['amount'] as num).toDouble(),
    };
  }

  /// Sets the limit of [category]; an [amount] that is not a positive number
  /// removes it.
  Future<void> setCategoryBudget(String category, double amount) async {
    final db = await database;
    if (amount > 0 && amount.isFinite) {
      await db.insert('category_budgets', {'category': category, 'amount': amount},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.delete('category_budgets',
          where: 'category = ?', whereArgs: [category]);
    }
  }

  // ── Savings goals ─────────────────────────────────────────────────────────

  /// Goals in creation order.
  Future<List<SavingsGoal>> getSavingsGoals() async {
    final db = await database;
    final r = await db.query('savings_goals', orderBy: 'id ASC');
    return [
      for (final row in r)
        SavingsGoal(
          id: row['id'] as int,
          name: row['name'] as String,
          target: (row['target'] as num).toDouble(),
          saved: (row['saved'] as num).toDouble(),
          targetDate: row['target_date'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(row['target_date'] as int),
        ),
    ];
  }

  static bool _goalAmountsOk(double target, double saved) =>
      target > 0 && target.isFinite && saved >= 0 && saved <= target;

  static void _checkGoal(String name, double target, double saved) {
    if (name.trim().isEmpty) throw ArgumentError('A goal needs a name');
    if (!(target > 0 && target.isFinite)) {
      throw ArgumentError('A goal needs a target above zero');
    }
    if (!_goalAmountsOk(target, saved)) {
      throw ArgumentError('Saved must be between zero and the target');
    }
  }

  /// Only the calendar day of [date] is kept.
  static int? _dayMillis(DateTime? date) => date == null
      ? null
      : DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;

  /// [saved] is what the user sets aside for the goal; the caller makes sure the
  /// Savings account has it free (see goalProgress), nothing is moved here.
  Future<int> insertSavingsGoal(String name, double target,
      {double saved = 0, DateTime? targetDate}) async {
    _checkGoal(name, target, saved);
    final db = await database;
    return db.insert('savings_goals', {
      'name': name.trim(),
      'target': target,
      'saved': saved,
      'target_date': _dayMillis(targetDate),
    });
  }

  /// Omitting [targetDate] clears it; [saved] is required so it is never wiped by accident.
  Future<void> updateSavingsGoal(int id, String name, double target,
      {required double saved, DateTime? targetDate}) async {
    _checkGoal(name, target, saved);
    final db = await database;
    await db.update(
      'savings_goals',
      {
        'name': name.trim(),
        'target': target,
        'saved': saved,
        'target_date': _dayMillis(targetDate),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Puts [delta] into a goal's envelope, or takes it out when negative. Moves no
  /// money; the envelope can neither pass its target nor go below zero.
  Future<void> addToGoal(int id, double delta) async {
    if (!delta.isFinite) throw ArgumentError('Not a number');
    final db = await database;
    await db.rawUpdate(
      'UPDATE savings_goals SET saved = MIN(target, MAX(0, saved + ?)) WHERE id = ?',
      [delta, id],
    );
  }

  Future<void> deleteSavingsGoal(int id) async {
    final db = await database;
    await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
  }

  // ── Tutorial / Settings ───────────────────────────────────────────────────

  Future<bool> hasTutorialSeen(String key) async {
    final db = await database;
    final r = await db.query('settings',
        where: 'key = ?', whereArgs: [key], limit: 1);
    return r.isNotEmpty;
  }

  Future<void> markTutorialSeen(String key) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Backup ────────────────────────────────────────────────────────────────

  static const _backupVersion = 1;

  /// Everything the user entered (profile, accounts, transactions, bills,
  /// category limits, savings goals, debts) as JSON text. Settings (tutorial flags) are not data and
  /// are left out.
  Future<String> exportBackup() async {
    final db = await database;
    // One transaction so the tables are read as a single snapshot.
    return db.transaction((txn) async => jsonEncode({
          'app': 'financeapp',
          'version': _backupVersion,
          'exportedAt': DateTime.now().toIso8601String(),
          'user': await txn.query('user'),
          'accounts': await txn.query('accounts', orderBy: 'id ASC'),
          'transactions': await txn.query('transactions', orderBy: 'id ASC'),
          'bills': await txn.query('bills', orderBy: 'id ASC'),
          'category_budgets':
              await txn.query('category_budgets', orderBy: 'category ASC'),
          'savings_goals': await txn.query('savings_goals', orderBy: 'id ASC'),
          'debts': await txn.query('debts', orderBy: 'id ASC'),
        }));
  }

  /// Checks backup [json] and returns the rows to restore, rebuilt through the
  /// models so nothing but known columns of the right type reaches SQLite.
  /// Throws [FormatException] when the text is not a usable backup.
  static BackupRows parseBackup(String json) {
    const invalid = FormatException('This file is not a valid FinanceApp backup');
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw invalid; // jsonDecode's own message ("Unexpected character...") means nothing to the user
    }
    try {
      final data = decoded as Map<String, dynamic>;
      if (data['app'] != 'financeapp') throw invalid;
      if ((data['version'] as int) > _backupVersion) {
        throw const FormatException(
            'This backup was made by a newer version of the app');
      }
      List<Map<String, dynamic>> rows(String key) => [
            for (final r in data[key] as List) Map<String, dynamic>.from(r as Map),
          ];

      final users = rows('user');
      if (users.length != 1) throw invalid;
      final user = UserModel.fromMap(users.first);

      final accounts = [for (final r in rows('accounts')) AccountModel.fromMap(r)];
      final ids = {for (final a in accounts) a.id};
      const builtIn = {
        kWalletId: AccountType.wallet,
        kBudgetId: AccountType.budget,
        kSavingsId: AccountType.savings,
      };
      if (ids.length != accounts.length || !ids.containsAll(builtIn.keys)) {
        throw invalid;
      }
      // fromKey silently maps an unknown type to wallet, so check the raw text.
      for (final (i, r) in rows('accounts').indexed) {
        if (r['type'] != (builtIn[accounts[i].id] ?? AccountType.custom).key) {
          throw invalid;
        }
      }

      final txs = [for (final r in rows('transactions')) TransactionModel.fromMap(r)];
      if (txs.any((t) => !ids.contains(t.accountId))) throw invalid;

      // Absent in backups made before debts had people: one row per account keeps
      // its loaned_amount backed by something owed.
      final debts = data['debts'] == null
          ? [
              for (final a in accounts)
                if (a.loanedAmount > 0)
                  <String, Object?>{
                    'account_id': a.id,
                    'person': _earlierDebts,
                    'amount': a.loanedAmount,
                    'repaid': 0.0,
                    'due_date': null,
                    'created_at': DateTime.now().millisecondsSinceEpoch,
                  },
            ]
          : [
              for (final r in rows('debts'))
                () {
                  final person = (r['person'] as String).trim();
                  final amount = (r['amount'] as num).toDouble();
                  final repaid = (r['repaid'] as num).toDouble();
                  if (person.isEmpty ||
                      !(amount > 0 && amount.isFinite) ||
                      !(repaid >= 0 && repaid <= amount) ||
                      !ids.contains(r['account_id'])) {
                    throw invalid;
                  }
                  return <String, Object?>{
                    'id': r['id'] as int,
                    'account_id': r['account_id'] as int,
                    'person': person,
                    'amount': amount,
                    'repaid': repaid,
                    'due_date': r['due_date'] as int?,
                    'created_at': r['created_at'] as int,
                  };
                }(),
            ];
      // What is owed must add up to what the account says is lent out.
      for (final a in accounts) {
        final owed = debts
            .where((d) => d['account_id'] == a.id)
            .fold<double>(0, (s, d) => s + (d['amount'] as double) - (d['repaid'] as double));
        if ((owed - a.loanedAmount).abs() > 0.01) throw invalid;
      }

      return (
        exportedAt: DateTime.tryParse(data['exportedAt'] as String? ?? ''),
        user: user.toMap(),
        accounts: [for (final a in accounts) a.toMap()],
        transactions: [for (final t in txs) {...t.toMap(), 'id': t.id}],
        bills: [
          for (final r in rows('bills'))
            {
              'id': r['id'] as int,
              'name': r['name'] as String,
              'amount': (r['amount'] as num).toDouble(),
              'is_paid': (r['is_paid'] as int) == 1 ? 1 : 0,
              'category': r['category'] as String? ?? '',
              // Absent in backups made before due days existed.
              'due_day': validDay(r['due_day'] as int?),
              // Absent in backups made before auto-pay existed.
              'auto_pay': _autoPayFlag(
                  (r['auto_pay'] as int?) == 1, r['due_day'] as int?),
            },
        ],
        // Absent in backups made before categories existed.
        categoryBudgets: [
          for (final r in (data['category_budgets'] as List? ?? const []))
            () {
              final m = r as Map;
              final amount = (m['amount'] as num).toDouble();
              if (!(amount > 0 && amount.isFinite)) throw invalid;
              return <String, Object?>{
                'category': m['category'] as String,
                'amount': amount,
              };
            }(),
        ],
        // Absent in backups made before savings goals existed.
        savingsGoals: [
          for (final r in (data['savings_goals'] as List? ?? const []))
            () {
              final m = r as Map;
              final name = (m['name'] as String).trim();
              final target = (m['target'] as num).toDouble();
              // Absent in backups made before goals held their own money.
              final saved = (m['saved'] as num? ?? 0).toDouble();
              if (name.isEmpty || !_goalAmountsOk(target, saved)) throw invalid;
              return <String, Object?>{
                'id': m['id'] as int,
                'name': name,
                'target': target,
                'saved': saved,
                'target_date': m['target_date'] as int?,
              };
            }(),
        ],
        debts: debts,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      // A missing key or a wrong type surfaces as a TypeError.
      throw invalid;
    }
  }

  /// Replaces this profile's data with [backup] (from [parseBackup]) in one
  /// SQLite transaction: if anything fails, the current data is untouched.
  Future<void> restoreBackup(BackupRows backup) async {
    final db = await database;
    await db.transaction((txn) async {
      final b = txn.batch();
      for (final t in [
        'transactions', 'bills', 'category_budgets', 'savings_goals', 'debts', 'accounts', 'user'
      ]) {
        b.delete(t);
      }
      // The restored data has its own history: the old salary run no longer applies.
      b.delete('settings', where: 'key = ?', whereArgs: [_lastSalaryKey]);
      b.insert('user', backup.user);
      for (final r in backup.accounts) {
        b.insert('accounts', r);
      }
      for (final r in backup.transactions) {
        b.insert('transactions', r);
      }
      for (final r in backup.bills) {
        b.insert('bills', r);
      }
      for (final r in backup.categoryBudgets) {
        b.insert('category_budgets', r);
      }
      for (final r in backup.savingsGoals) {
        b.insert('savings_goals', r);
      }
      for (final r in backup.debts) {
        b.insert('debts', r);
      }
      await b.commit(noResult: true);
    });
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  /// Wipes all data so the app behaves as if freshly installed.
  Future<void> resetDatabase() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('bills');
      await txn.delete('category_budgets');
      await txn.delete('savings_goals');
      await txn.delete('debts');
      await txn.delete('accounts');
      await txn.delete('settings');
      await txn.delete('user');
    });
  }
}
