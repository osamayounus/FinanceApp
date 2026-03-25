import 'dart:io';

import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/models/user_model.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  static AppDatabase? _instance;
  static Database? _db;

  AppDatabase._();
  static AppDatabase get instance => _instance ??= AppDatabase._();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _openDB();
    return _db!;
  }

  Future<Database> _openDB() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'finance.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        salary REAL NOT NULL,
        monthly_budget REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0.0
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
        is_paid INTEGER NOT NULL DEFAULT 0
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
    return r.map(AccountModel.fromMap).toList();
  }

  Future<void> updateBalance(int accountId, double balance) async {
    final db = await database;
    await db.update('accounts', {'balance': balance},
        where: 'id = ?', whereArgs: [accountId]);
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

  Future<void> insertTransaction(TransactionModel tx) async {
    final db = await database;
    await db.insert('transactions', tx.toMap());
  }

  // ── Bills ─────────────────────────────────────────────────────────────────

  Future<List<ExpenseModel>> getBills() async {
    final db = await database;
    final r = await db.query('bills', orderBy: 'id ASC');
    return r
        .map((e) => ExpenseModel(
              id: e['id'] as int,
              name: e['name'] as String,
              amount: (e['amount'] as num).toInt(),
              isPaid: (e['is_paid'] as int) == 1,
            ))
        .toList();
  }

  Future<int> insertBill(String name, int amount) async {
    final db = await database;
    return db
        .insert('bills', {'name': name, 'amount': amount.toDouble(), 'is_paid': 0});
  }

  Future<void> updateBill(int id, String name, int amount) async {
    final db = await database;
    await db.update('bills', {'name': name, 'amount': amount.toDouble()},
        where: 'id = ?', whereArgs: [id]);
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

  /// Returns updated {wallet, budget} balances after processing salary day.
  Future<Map<String, double>> processSalaryDay({
    required double salary,
    required double monthlyBudget,
  }) async {
    final db = await database;
    final now = DateTime.now();

    final walletRow = (await db
            .query('accounts', where: 'id = ?', whereArgs: [kWalletId]))
        .first;
    final budgetRow = (await db
            .query('accounts', where: 'id = ?', whereArgs: [kBudgetId]))
        .first;

    double walletBalance = (walletRow['balance'] as num).toDouble();
    double budgetBalance = (budgetRow['balance'] as num).toDouble();

    await db.transaction((txn) async {
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
}
