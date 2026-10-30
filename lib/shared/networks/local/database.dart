import 'dart:convert';
import 'dart:io';

import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/models/user_model.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A validated backup, ready for [AppDatabase.restoreBackup].
typedef BackupRows = ({
  DateTime? exportedAt,
  Map<String, Object?> user,
  List<Map<String, Object?>> accounts,
  List<Map<String, Object?>> transactions,
  List<Map<String, Object?>> bills,
});

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
      version: 7,
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
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        salary REAL NOT NULL,
        monthly_budget REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'JOD'
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
        related_account_id INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        is_paid INTEGER NOT NULL DEFAULT 0,
        category TEXT NOT NULL DEFAULT ''
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
  Future<void> applyTx({
    required int accountId,
    required double balance,
    double? loanedAmount,
    required TransactionModel tx,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
          'accounts', {'balance': balance, 'loaned_amount': ?loanedAmount},
          where: 'id = ?', whereArgs: [accountId]);
      await txn.insert('transactions', tx.toMap());
    });
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

  Future<void> updateLoanedAmount(int accountId, double loaned) async {
    final db = await database;
    await db.update('accounts', {'loaned_amount': loaned},
        where: 'id = ?', whereArgs: [accountId]);
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
  /// difference, atomically. Returns false, changing nothing, when the row is
  /// gone or not editable, [amount] is not positive, or the balance would go
  /// negative.
  Future<bool> updateTransaction(int id,
      {required double amount,
      required String title,
      required String note}) async {
    // "9" * 400 parses to Infinity, which would poison the balance.
    if (!(amount > 0 && amount.isFinite)) return false;
    final db = await database;
    return db.transaction((txn) async {
      final tx = await _editableTx(txn, id);
      if (tx == null) return false;
      final delta = _signed(tx, amount) - _signed(tx, tx.amount);
      if (!await _shiftBalance(txn, tx.accountId, delta)) return false;
      await txn.update(
          'transactions', {'amount': amount, 'title': title, 'note': note},
          where: 'id = ?', whereArgs: [id]);
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
            ))
        .toList();
  }

  Future<int> insertBill(String name, double amount, String category) async {
    final db = await database;
    return db.insert('bills', {
      'name': name,
      'amount': amount,
      'is_paid': 0,
      'category': category,
    });
  }

  Future<void> updateBill(int id, String name, double amount, String category) async {
    final db = await database;
    await db.update(
      'bills',
      {'name': name, 'amount': amount, 'category': category},
      where: 'id = ?',
      whereArgs: [id],
    );
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

  /// Executes the salary-day flow atomically in 5 steps:
  ///   1. Sweep any remaining budget balance into the wallet (rollover).
  ///   2. Credit the net income (salary − budget) to the wallet.
  ///   3. Reset the budget account back to [monthlyBudget].
  ///   4. Persist both updated balances.
  ///   5. Mark all bills as unpaid for the new month.
  ///
  /// All steps run inside a single SQLite transaction so a crash mid-way
  /// leaves the database unchanged.
  Future<Map<String, double>> processSalaryDay({
    required double salary,
    required double monthlyBudget,
  }) async {
    if (monthlyBudget > salary) {
      throw ArgumentError('Monthly budget cannot exceed the salary');
    }
    final db = await database;
    final now = DateTime.now();
    double walletBalance = 0;
    double budgetBalance = 0;

    await db.transaction((txn) async {
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

  /// Everything the user entered (profile, accounts, transactions, bills) as
  /// JSON text. Settings (tutorial flags) are not data and are left out.
  Future<String> exportBackup() async {
    final db = await database;
    // One transaction so the four tables are read as a single snapshot.
    return db.transaction((txn) async => jsonEncode({
          'app': 'financeapp',
          'version': _backupVersion,
          'exportedAt': DateTime.now().toIso8601String(),
          'user': await txn.query('user'),
          'accounts': await txn.query('accounts', orderBy: 'id ASC'),
          'transactions': await txn.query('transactions', orderBy: 'id ASC'),
          'bills': await txn.query('bills', orderBy: 'id ASC'),
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
            },
        ],
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
      for (final t in ['transactions', 'bills', 'accounts', 'user']) {
        b.delete(t);
      }
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
      await txn.delete('accounts');
      await txn.delete('settings');
      await txn.delete('user');
    });
  }
}
