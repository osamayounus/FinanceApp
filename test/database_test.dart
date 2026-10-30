import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/user_model.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_env.dart';

void main() {
  setUpAll(setUpTestEnv);
  tearDownAll(tearDownTestEnv);

  Future<double> total(AppDatabase db) async =>
      (await db.getAccounts()).fold<double>(0, (s, a) => s + a.balance);

  group('schema', () {
    test('fresh DB has all tables and columns', () async {
      final db = AppDatabase.forFile(uniqueDbName());
      final raw = await db.database;
      Future<Set<String>> cols(String t) async =>
          (await raw.rawQuery('PRAGMA table_info($t)'))
              .map((r) => r['name'] as String)
              .toSet();
      expect(await cols('user'),
          {'id', 'name', 'salary', 'monthly_budget', 'currency'});
      expect(await cols('accounts'), {
        'id', 'type', 'balance', 'loaned_amount', 'custom_name',
        'color_index', 'icon_code'
      });
      expect(await cols('transactions'), {
        'id', 'account_id', 'type', 'amount', 'title', 'note',
        'related_account_id', 'created_at'
      });
      expect(await cols('bills'),
          {'id', 'name', 'amount', 'is_paid', 'category'});
      expect(await cols('settings'), {'key', 'value'});
      await db.close();
    });

    test('forFile caches instances; close() evicts', () async {
      final name = uniqueDbName();
      final a = AppDatabase.forFile(name);
      expect(identical(a, AppDatabase.forFile(name)), isTrue);
      await a.database;
      await a.close();
      expect(identical(a, AppDatabase.forFile(name)), isFalse);
      await AppDatabase.forFile(name).close();
    });

    test('close() twice is safe', () async {
      final db = AppDatabase.forFile(uniqueDbName());
      await db.database;
      await db.close();
      await db.close();
    });

    test('concurrent first access opens the DB only once', () async {
      final db = AppDatabase.forFile(uniqueDbName());
      final dbs = await Future.wait([db.database, db.database, db.database]);
      expect(identical(dbs[0], dbs[1]) && identical(dbs[1], dbs[2]), isTrue);
      await db.close();
    });
  });

  group('user', () {
    test('hasUser / insert / get / update', () async {
      final db = AppDatabase.forFile(uniqueDbName());
      expect(await db.hasUser(), isFalse);
      expect(await db.getUser(), isNull);
      await db.insertUser(kTestUser);
      expect(await db.hasUser(), isTrue);
      await db.updateUser(
          kTestUser.copyWith(name: 'Z', salary: 2000.5, currency: 'USD'));
      final u = (await db.getUser())!;
      expect((u.name, u.salary, u.currency), ('Z', 2000.5, 'USD'));
      await db.close();
    });

    test('inserting a second user with the same id is rejected', () async {
      final db = AppDatabase.forFile(uniqueDbName());
      await db.insertUser(kTestUser);
      await expectLater(db.insertUser(kTestUser), throwsA(anything));
      await db.close();
    });

    test('decimal salary/budget survive the DB', () async {
      final db = AppDatabase.forFile(uniqueDbName());
      await db.insertUser(const UserModel(
          id: 1, name: 'n', salary: 1500.55, monthlyBudget: 300.25));
      final u = (await db.getUser())!;
      expect((u.salary, u.monthlyBudget), (1500.55, 300.25));
      await db.close();
    });
  });

  group('initAccounts', () {
    test('creates wallet/budget/savings with right balances + 3 txs',
        () async {
      final db = await freshDb(savings: 100);
      final accs = {for (final a in await db.getAccounts()) a.id: a};
      expect(accs[kWalletId]!.balance, 600);
      expect(accs[kBudgetId]!.balance, 400);
      expect(accs[kSavingsId]!.balance, 100);
      final txs = await db.getAllTransactions();
      expect(txs.length, 3);
      expect(txs.map((t) => t.type).toSet(), {'salary', 'initial'});
      await db.close();
    });

    test('zero initial savings records no "initial" tx', () async {
      final db = await freshDb(savings: 0);
      expect(
          (await db.getAllTransactions()).where((t) => t.type == 'initial'),
          isEmpty);
      await db.close();
    });

    test('calling it twice fails instead of duplicating accounts', () async {
      final db = await freshDb();
      await expectLater(
          db.initAccounts(initialSavings: 0, salary: 1, monthlyBudget: 1),
          throwsA(anything));
      expect((await db.getAccounts()).length, 3);
      await db.close();
    });

    test('budget larger than salary is rejected (would create a negative wallet)',
        () async {
      final db = AppDatabase.forFile(uniqueDbName());
      await db.insertUser(kTestUser);
      Object? err;
      try {
        await db.initAccounts(
            initialSavings: 0, salary: 100, monthlyBudget: 500);
      } catch (e) {
        err = e;
      }
      final wallet = (await db.getAccounts())
          .where((a) => a.id == kWalletId)
          .map((a) => a.balance);
      expect(err != null || wallet.every((b) => b >= 0), isTrue,
          reason: 'wallet created with balance $wallet');
      await db.close();
    });
  });

  group('accounts', () {
    test('custom account ids never collide with the fixed 1-3', () async {
      final db = await freshDb();
      final id = await db.insertCustomAccount('Trip', 1, 0xe318);
      expect(id, greaterThan(kSavingsId));
      final acc = (await db.getAccounts()).firstWhere((a) => a.id == id);
      expect(acc.isCustom, isTrue);
      expect(acc.customName, 'Trip');
      expect(acc.loanedAmount, 0);
      await db.close();
    });

    test('updateBalance / updateLoanedAmount / updateCustomAccount', () async {
      final db = await freshDb();
      final id = await db.insertCustomAccount('A', 0, 1);
      await db.updateBalance(id, 55.5);
      await db.updateLoanedAmount(id, 10);
      await db.updateCustomAccount(id, 'B', 3, 4);
      final a = (await db.getAccounts()).firstWhere((a) => a.id == id);
      expect(
          (a.balance, a.loanedAmount, a.customName, a.colorIndex, a.iconCode),
          (55.5, 10.0, 'B', 3, 4));
      await db.close();
    });

    test('deleteAccount removes the account and its own txs only', () async {
      final db = await freshDb();
      final id = await db.insertCustomAccount('A', 0, 1);
      await db.insertTransaction(mkTx(id, 'deposit', 5));
      await db.insertTransaction(mkTx(kWalletId, 'deposit', 7));
      await db.deleteAccount(id);
      expect((await db.getAccounts()).any((a) => a.id == id), isFalse);
      expect(await db.getTransactions(id), isEmpty);
      expect(await db.getTransactions(kWalletId), isNotEmpty);
      await db.close();
    });

    test('deleteAccount must refuse the built-in wallet/budget/savings',
        () async {
      final db = await freshDb();
      Object? err;
      try {
        await db.deleteAccount(kWalletId);
      } catch (e) {
        err = e;
      }
      final stillThere =
          (await db.getAccounts()).any((a) => a.id == kWalletId);
      expect(err != null || stillThere, isTrue,
          reason: 'wallet was deleted and no error was raised');
      await db.close();
    });
  });

  group('transactions', () {
    test('getTransactions is per account and newest first', () async {
      final db = await freshDb(savings: 0);
      final t0 = DateTime(2024, 1, 1);
      await db.insertTransaction(
          mkTx(kWalletId, 'deposit', 1, at: t0, title: 'old'));
      await db.insertTransaction(mkTx(kWalletId, 'deposit', 2,
          at: t0.add(const Duration(days: 1)), title: 'new'));
      await db.insertTransaction(mkTx(kSavingsId, 'deposit', 3, at: t0));
      final w = await db.getTransactions(kWalletId);
      final titles = w.map((t) => t.title).toList();
      expect(titles.indexOf('new'), lessThan(titles.indexOf('old')));
      expect(w.every((t) => t.accountId == kWalletId), isTrue);
      await db.close();
    });

    test('unicode and null-byte notes survive (transfer notes embed \\x00)',
        () async {
      final db = await freshDb(savings: 0);
      await db.insertTransaction(mkTx(kWalletId, 'transfer_out', 1,
          note: 'مرحبا\x00Savings', title: 'تحويل'));
      final t = (await db.getTransactions(kWalletId))
          .firstWhere((t) => t.type == 'transfer_out');
      expect(t.note, 'مرحبا\x00Savings');
      expect(t.title, 'تحويل');
      await db.close();
    });

    test('SQL-injection-looking text is stored verbatim', () async {
      final db = await freshDb(savings: 0);
      const evil = "x'); DROP TABLE accounts;--";
      await db.insertTransaction(mkTx(kWalletId, 'deposit', 1, title: evil));
      await db.insertBill(evil, 1, evil);
      expect((await db.getAccounts()).length, 3);
      expect((await db.getBills()).single.name, evil);
      await db.close();
    });
  });

  group('bills', () {
    test('CRUD + markPaid + resetAllBills', () async {
      final db = AppDatabase.forFile(uniqueDbName());
      final a = await db.insertBill('Rent', 300, 'home');
      final b = await db.insertBill('Net', 20.5, '');
      expect((await db.getBills()).map((e) => e.name), ['Rent', 'Net']);
      await db.updateBill(a, 'Rent2', 310, 'housing');
      await db.markBillPaid(a);
      await db.markBillPaid(b);
      final bills = await db.getBills();
      expect(bills[0].name, 'Rent2');
      expect(bills[0].category, 'housing');
      expect(bills.every((x) => x.isPaid), isTrue);
      await db.resetAllBills();
      expect((await db.getBills()).any((x) => x.isPaid), isFalse);
      await db.deleteBill(a);
      expect((await db.getBills()).length, 1);
      await db.close();
    });

    test('updating a paid bill keeps it paid', () async {
      final db = AppDatabase.forFile(uniqueDbName());
      final a = await db.insertBill('Rent', 300, '');
      await db.markBillPaid(a);
      await db.updateBill(a, 'Rent', 350, '');
      expect((await db.getBills()).single.isPaid, isTrue);
      await db.close();
    });
  });

  group('processSalaryDay', () {
    test('rolls leftover into wallet, credits net salary, resets budget + bills',
        () async {
      final db = await freshDb(savings: 0);
      final bill = await db.insertBill('Rent', 100, '');
      await db.markBillPaid(bill);
      await db.updateBalance(kBudgetId, 150); // 250 spent from budget
      final r = await db.processSalaryDay(salary: 1000, monthlyBudget: 400);
      expect(r['wallet'], 600 + 150 + 600);
      expect(r['budget'], 400);
      final accs = {for (final a in await db.getAccounts()) a.id: a.balance};
      expect(accs[kWalletId], 1350);
      expect(accs[kBudgetId], 400);
      expect((await db.getBills()).single.isPaid, isFalse);
      final types = (await db.getAllTransactions()).map((t) => t.type);
      expect(types.where((t) => t == 'transfer_out').length, 1);
      expect(types.where((t) => t == 'transfer_in').length, 1);
      await db.close();
    });

    test('no leftover -> no transfer rows', () async {
      final db = await freshDb(savings: 0);
      await db.updateBalance(kBudgetId, 0);
      await db.processSalaryDay(salary: 1000, monthlyBudget: 400);
      final types = (await db.getAllTransactions()).map((t) => t.type);
      expect(types.where((t) => t.startsWith('transfer')), isEmpty);
      await db.close();
    });

    test('exactly the salary is created as new money', () async {
      final db = await freshDb(savings: 50);
      await db.updateBalance(kBudgetId, 123.45);
      final before = await total(db);
      await db.processSalaryDay(salary: 1000, monthlyBudget: 400);
      // leftover just moves budget -> wallet; the only new money is the salary
      expect(await total(db) - before, closeTo(1000, 0.0001));
      await db.close();
    });

    test('state returned equals what was persisted', () async {
      final db = await freshDb(savings: 0);
      final r = await db.processSalaryDay(salary: 1000, monthlyBudget: 400);
      final accs = {for (final a in await db.getAccounts()) a.id: a.balance};
      expect(accs[kWalletId], r['wallet']);
      expect(accs[kBudgetId], r['budget']);
      await db.close();
    });

    test('two salary days in a row credit twice (the once-per-month guard is the UI\'s job)',
        () async {
      final db = await freshDb(savings: 0);
      await db.processSalaryDay(salary: 1000, monthlyBudget: 400);
      await db.processSalaryDay(salary: 1000, monthlyBudget: 400);
      final salaryRows = (await db.getAllTransactions()).where(
          (t) => t.type == 'salary' && t.accountId == kWalletId);
      expect(salaryRows.length, 3); // seed + 2 runs
      await db.close();
    });

    test('a balance write racing with salary day must not be lost', () async {
      final db = await freshDb(savings: 0);
      await db.updateBalance(kBudgetId, 0);
      await Future.wait([
        db.processSalaryDay(salary: 1000, monthlyBudget: 400),
        db.updateBalance(kWalletId, 5600), // wallet was 600; +5000 top-up
      ]);
      final w =
          (await db.getAccounts()).firstWhere((a) => a.id == kWalletId).balance;
      // Serialised either way the +5000 must still be there: 5600+600 or (600+600 then 5600).
      expect(w, anyOf(6200, 5600));
      await db.close();
    });

    test('missing wallet/budget gives a meaningful error, not StateError("No element")',
        () async {
      final db = AppDatabase.forFile(uniqueDbName());
      await db.database;
      Object? err;
      try {
        await db.processSalaryDay(salary: 1, monthlyBudget: 1);
      } catch (e) {
        err = e;
      }
      expect(err.toString(), contains('profile not initialised'));
      await db.close();
    });

    test('salary lower than budget is rejected (would drain the wallet)',
        () async {
      final db = await freshDb(savings: 0);
      await db.updateBalance(kBudgetId, 0); // no leftover to mask the debit
      Object? err;
      try {
        await db.processSalaryDay(salary: 300, monthlyBudget: 400);
      } catch (e) {
        err = e;
      }
      final w =
          (await db.getAccounts()).firstWhere((a) => a.id == kWalletId).balance;
      expect(err != null || w >= 600, isTrue,
          reason: 'wallet went 600 -> $w after a salary of 300');
      await db.close();
    });
  });

  group('settings + reset', () {
    test('tutorial flags', () async {
      final db = AppDatabase.forFile(uniqueDbName());
      expect(await db.hasTutorialSeen('a'), isFalse);
      await db.markTutorialSeen('a');
      await db.markTutorialSeen('a');
      expect(await db.hasTutorialSeen('a'), isTrue);
      expect(await db.hasTutorialSeen('b'), isFalse);
      await db.close();
    });

    test('resetDatabase empties every table', () async {
      final db = await freshDb();
      await db.insertBill('x', 1, '');
      await db.markTutorialSeen('t');
      await db.resetDatabase();
      expect(await db.hasUser(), isFalse);
      expect(await db.getAccounts(), isEmpty);
      expect(await db.getAllTransactions(), isEmpty);
      expect(await db.getBills(), isEmpty);
      expect(await db.hasTutorialSeen('t'), isFalse);
      await db.close();
    });

    test('after reset the same DB can be seeded again', () async {
      final db = await freshDb();
      await db.resetDatabase();
      await db.insertUser(kTestUser);
      await db.initAccounts(initialSavings: 0, salary: 500, monthlyBudget: 100);
      expect((await db.getAccounts()).length, 3);
      await db.close();
    });
  });

  group('migrations', () {
    const user1 =
        'CREATE TABLE user (id INTEGER PRIMARY KEY, name TEXT NOT NULL, salary REAL NOT NULL, monthly_budget REAL NOT NULL)';
    const acc1 =
        'CREATE TABLE accounts (id INTEGER PRIMARY KEY, type TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0.0)';
    const tx =
        "CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, title TEXT NOT NULL DEFAULT '', note TEXT DEFAULT '', related_account_id INTEGER, created_at INTEGER NOT NULL)";
    const bills1 =
        'CREATE TABLE bills (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, amount REAL NOT NULL, is_paid INTEGER NOT NULL DEFAULT 0)';
    const settings =
        'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)';

    Future<String> legacyFile(
        int version, List<String> ddl, Future<void> Function(Database) seed) async {
      final name = uniqueDbName();
      final raw = await databaseFactory.openDatabase(
        p.join(testDir.path, name),
        options: OpenDatabaseOptions(
          version: version,
          onCreate: (db, _) async {
            for (final s in ddl) {
              await db.execute(s);
            }
            await seed(db);
          },
        ),
      );
      await raw.close();
      return name;
    }

    test('v1 -> v7 keeps old data and adds every new column', () async {
      final name = await legacyFile(1, [user1, acc1, tx, bills1], (db) async {
        await db.insert('user', {
          'id': 1, 'name': 'Old', 'salary': 900.0, 'monthly_budget': 300.0
        });
        await db.insert('accounts', {'id': 1, 'type': 'wallet', 'balance': 10.0});
        await db.insert('bills', {'name': 'Rent', 'amount': 50.0, 'is_paid': 1});
      });
      final db = AppDatabase.forFile(name);
      final u = (await db.getUser())!;
      expect((u.name, u.currency), ('Old', 'JOD'));
      final a = (await db.getAccounts()).single;
      expect((a.balance, a.loanedAmount), (10.0, 0.0));
      final bill = (await db.getBills()).single;
      expect((bill.isPaid, bill.category), (true, ''));
      await db.markTutorialSeen('x'); // settings table exists
      expect(await db.insertCustomAccount('n', 1, 2), greaterThan(1));
      await db.updateLoanedAmount(1, 5);
      expect((await db.getAccounts()).first.loanedAmount, 5);
      await db.close();
    });

    final userV5 =
        "CREATE TABLE user (id INTEGER PRIMARY KEY, name TEXT NOT NULL, salary REAL NOT NULL, monthly_budget REAL NOT NULL, currency TEXT NOT NULL DEFAULT 'JOD')";
    const billsV4 =
        "CREATE TABLE bills (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, amount REAL NOT NULL, is_paid INTEGER NOT NULL DEFAULT 0, category TEXT NOT NULL DEFAULT '')";

    test('v6 -> v7 adds loaned_amount', () async {
      final name = await legacyFile(6, [
        userV5,
        'CREATE TABLE accounts (id INTEGER PRIMARY KEY, type TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0.0, custom_name TEXT, color_index INTEGER, icon_code INTEGER)',
        tx,
        billsV4,
        settings,
      ], (db) async {
        await db.insert('accounts', {'id': 1, 'type': 'wallet', 'balance': 3.0});
      });
      final db = AppDatabase.forFile(name);
      expect((await db.getAccounts()).single.loanedAmount, 0);
      await db.close();
    });

    test('v6 DB that already has loaned_amount (partial migration) still opens',
        () async {
      final name = await legacyFile(6, [
        userV5,
        'CREATE TABLE accounts (id INTEGER PRIMARY KEY, type TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0.0, loaned_amount REAL DEFAULT 0.0, custom_name TEXT, color_index INTEGER, icon_code INTEGER)',
        tx,
        billsV4,
        settings,
      ], (db) async {
        await db.insert('accounts',
            {'id': 1, 'type': 'wallet', 'balance': 3.0, 'loaned_amount': 9.0});
      });
      final db = AppDatabase.forFile(name);
      expect((await db.getAccounts()).single.loanedAmount, 9);
      await db.close();
    });

    test('re-opening a current DB keeps its data', () async {
      final name = uniqueDbName();
      final a = AppDatabase.forFile(name);
      await a.insertUser(kTestUser);
      await a.close();
      final b = AppDatabase.forFile(name);
      expect(await b.hasUser(), isTrue);
      await b.close();
    });
  });
}
