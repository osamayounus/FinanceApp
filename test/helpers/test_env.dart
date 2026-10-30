import 'dart:io';

import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/models/user_model.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Directory testDir;
int _n = 0;

/// Points sqflite at a throwaway directory. Call from setUpAll.
Future<void> setUpTestEnv() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  testDir = await Directory.systemTemp.createTemp('financeapp_test_');
  await databaseFactory.setDatabasesPath(testDir.path);
}

Future<void> tearDownTestEnv() async {
  try {
    await testDir.delete(recursive: true);
  } catch (_) {/* Windows may keep a handle open; the OS temp cleaner gets it */}
}

String uniqueDbName() => 'test_${_n++}.db';

const kTestUser = UserModel(
    id: 1, name: 'Tester', salary: 1000, monthlyBudget: 400, currency: 'JOD');

/// Fresh profile DB seeded the way onboarding does it:
/// salary 1000 / budget 400 -> wallet 600, budget 400, savings [savings].
Future<AppDatabase> freshDb({double savings = 100}) async {
  final db = AppDatabase.forFile(uniqueDbName());
  await db.insertUser(kTestUser);
  await db.initAccounts(
      initialSavings: savings,
      salary: kTestUser.salary,
      monthlyBudget: kTestUser.monthlyBudget);
  return db;
}

/// A Riverpod container wired exactly like main.dart's AppRoot does it.
Future<({AppDatabase db, ProviderContainer c})> seededContainer(
    {double savings = 100}) async {
  final db = await freshDb(savings: savings);
  final c = ProviderContainer(overrides: [
    dbProvider.overrideWithValue(db),
    userProvider.overrideWith((ref) => UserNotifier(db, kTestUser)),
    accountsProvider.overrideWith((ref) => AccountsNotifier(db, [])),
    expensesProvider.overrideWith((ref) => BillsNotifier(db, <ExpenseModel>[])),
  ]);
  // Replace the empty placeholder state with what is really in the DB.
  c.read(accountsProvider.notifier).state = await db.getAccounts();
  return (db: db, c: c);
}

TransactionModel mkTx(int accountId, String type, double amount,
        {DateTime? at, String title = 't', String note = '', int? related}) =>
    TransactionModel(
      id: 0,
      accountId: accountId,
      type: type,
      amount: amount,
      title: title,
      note: note,
      relatedAccountId: related,
      createdAt: at ?? DateTime.now(),
    );

double balanceOf(ProviderContainer c, int id) =>
    c.read(accountsProvider).firstWhere((a) => a.id == id).balance;

/// In-memory account state must always equal what is persisted.
Future<void> expectStateMatchesDb(ProviderContainer c, AppDatabase db) async {
  final mem = {for (final a in c.read(accountsProvider)) a.id: a};
  final disk = {for (final a in await db.getAccounts()) a.id: a};
  expect(mem.keys.toSet(), disk.keys.toSet(), reason: 'account id sets differ');
  for (final id in mem.keys) {
    if (!disk.containsKey(id)) continue;
    expect(mem[id]!.balance, disk[id]!.balance, reason: 'balance of #$id');
    expect(mem[id]!.loanedAmount, disk[id]!.loanedAmount,
        reason: 'loaned_amount of #$id');
  }
}
