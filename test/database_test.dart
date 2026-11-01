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
          {'id', 'name', 'salary', 'monthly_budget', 'currency', 'salary_day'});
      expect(await cols('accounts'), {
        'id', 'type', 'balance', 'loaned_amount', 'custom_name',
        'color_index', 'icon_code'
      });
      expect(await cols('transactions'), {
        'id', 'account_id', 'type', 'amount', 'title', 'note', 'category',
        'related_account_id', 'created_at'
      });
      expect(await cols('bills'),
          {'id', 'name', 'amount', 'is_paid', 'category', 'due_day', 'auto_pay'});
      expect(await cols('settings'), {'key', 'value'});
      expect(await cols('category_budgets'), {'category', 'amount'});
      expect(await cols('savings_goals'),
          {'id', 'name', 'target', 'saved', 'target_date'});
      expect(await cols('debts'), {
        'id', 'account_id', 'person', 'amount', 'repaid', 'due_date', 'created_at'
      });
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

    test('updateBalance / updateCustomAccount', () async {
      final db = await freshDb();
      final id = await db.insertCustomAccount('A', 0, 1);
      await db.updateBalance(id, 55.5);
      await db.updateCustomAccount(id, 'B', 3, 4);
      final a = (await db.getAccounts()).firstWhere((a) => a.id == id);
      expect(
          (a.balance, a.customName, a.colorIndex, a.iconCode),
          (55.5, 'B', 3, 4));
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

    test('due day is stored, changeable and clearable; out of range means none',
        () async {
      final db = AppDatabase.forFile(uniqueDbName());
      final a = await db.insertBill('Rent', 300, '', dueDay: 5);
      final b = await db.insertBill('Net', 20, '');
      final c = await db.insertBill('Bad', 1, '', dueDay: 32);
      final d = await db.insertBill('Zero', 1, '', dueDay: 0);
      expect((await db.getBills()).map((x) => x.dueDay), [5, null, null, null]);
      await db.updateBill(a, 'Rent', 300, '', dueDay: 31);
      await db.updateBill(b, 'Net', 20, '', dueDay: 1);
      await db.updateBill(c, 'Bad', 1, '', dueDay: -3);
      await db.updateBill(d, 'Zero', 1, '');
      expect((await db.getBills()).map((x) => x.dueDay), [31, 1, null, null]);
      await db.updateBill(a, 'Rent', 300, ''); // omitted = cleared
      expect((await db.getBills()).first.dueDay, isNull);
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

  group('billCycleStart', () {
    test('is the last salary day, or the 1st of this month before any', () async {
      final db = AppDatabase.forFile(uniqueDbName()); // no onboarding salary row
      final now = DateTime.now();
      expect(await db.billCycleStart(), DateTime(now.year, now.month));
      final older = DateTime(2026, 1, 25, 10);
      final newer = DateTime(2026, 2, 25, 9);
      await db.insertTransaction(mkTx(kWalletId, 'salary', 100, at: older));
      await db.insertTransaction(mkTx(kWalletId, 'salary', 100, at: newer));
      await db.insertTransaction(
          mkTx(kWalletId, 'deposit', 5, at: DateTime(2026, 3, 1)));
      expect(await db.billCycleStart(), newer);
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

    group('once per salary cycle', () {
      Future<int> walletSalaryRows(AppDatabase db) async =>
          (await db.getAllTransactions())
              .where((t) => t.type == 'salary' && t.accountId == kWalletId)
              .length;

      test('a second run in the same month is refused and changes nothing', () async {
        final db = await freshDb(savings: 0);
        final bill = await db.insertBill('Rent', 100, '');
        await db.processSalaryDay(
            salary: 1000, monthlyBudget: 400, at: DateTime(2026, 10, 25, 9));
        await db.markBillPaid(bill);
        final before = await db.getAccounts();

        await expectLater(
            db.processSalaryDay(
                salary: 1000, monthlyBudget: 400, at: DateTime(2026, 10, 25, 18)),
            throwsA(isA<SalaryAlreadyProcessed>()
                .having((e) => e.at, 'at', DateTime(2026, 10, 25, 9))
                .having((e) => e.cycleStart, 'cycleStart', DateTime(2026, 10, 1))));

        expect([for (final a in await db.getAccounts()) a.balance],
            [for (final a in before) a.balance]);
        expect(await walletSalaryRows(db), 2, reason: 'seed + the first run');
        expect((await db.getBills()).single.isPaid, isTrue, reason: 'bills not reset');
        await db.close();
      });

      test('the next month is allowed again', () async {
        final db = await freshDb(savings: 0);
        await db.processSalaryDay(
            salary: 1000, monthlyBudget: 400, at: DateTime(2026, 10, 31, 23, 59));
        await db.processSalaryDay(
            salary: 1000, monthlyBudget: 400, at: DateTime(2026, 11, 1));
        expect(await walletSalaryRows(db), 3);
        expect(await db.lastSalaryProcessedAt(), DateTime(2026, 11, 1));
        await db.close();
      });

      test('the cycle starts on the user\'s salary day, not on the 1st', () async {
        final db = await freshDb(savings: 0);
        await db.updateUser(kTestUser.copyWith(salaryDay: 25));
        await db.processSalaryDay(
            salary: 1000, monthlyBudget: 400, at: DateTime(2026, 10, 26));
        // Still the cycle that began on 25 Oct, though it is already November.
        await expectLater(
            db.processSalaryDay(
                salary: 1000, monthlyBudget: 400, at: DateTime(2026, 11, 24)),
            throwsA(isA<SalaryAlreadyProcessed>()
                .having((e) => e.cycleStart, 'cycleStart', DateTime(2026, 10, 25))));
        await db.processSalaryDay(
            salary: 1000, monthlyBudget: 400, at: DateTime(2026, 11, 25));
        expect(await walletSalaryRows(db), 3);
        await db.close();
      });

      test('the onboarding seed does not count as a run', () async {
        final db = await freshDb(savings: 0); // seeded "now"
        expect(await db.lastSalaryProcessedAt(), isNull);
        await db.processSalaryDay(salary: 1000, monthlyBudget: 400);
        expect(await db.lastSalaryProcessedAt(), isNotNull);
        await db.close();
      });

      test('a run that fails is not remembered', () async {
        final db = AppDatabase.forFile(uniqueDbName());
        await db.database; // no accounts: the run fails after the guard
        await expectLater(
            db.processSalaryDay(salary: 1, monthlyBudget: 1), throwsA(anything));
        expect(await db.lastSalaryProcessedAt(), isNull);
        await db.close();
      });

      test('restoring a backup forgets the old run', () async {
        final db = await freshDb(savings: 0);
        final backup = AppDatabase.parseBackup(await db.exportBackup());
        await db.processSalaryDay(salary: 1000, monthlyBudget: 400);
        await db.restoreBackup(backup);
        expect(await db.lastSalaryProcessedAt(), isNull);
        await db.processSalaryDay(salary: 1000, monthlyBudget: 400);
        await db.close();
      });

      test('resetting the profile forgets it too', () async {
        final db = await freshDb(savings: 0);
        await db.processSalaryDay(salary: 1000, monthlyBudget: 400);
        await db.resetDatabase();
        expect(await db.lastSalaryProcessedAt(), isNull);
        await db.close();
      });
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

    test('resetDatabase also drops the category limits', () async {
      final db = await freshDb();
      await db.setCategoryBudget('Food', 10);
      await db.resetDatabase();
      expect(await db.getCategoryBudgets(), isEmpty);
      await db.close();
    });

    test('resetDatabase also drops the savings goals', () async {
      final db = await freshDb();
      await db.insertSavingsGoal('Laptop', 800);
      await db.resetDatabase();
      expect(await db.getSavingsGoals(), isEmpty);
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

  group('savings goals', () {
    test('start empty; goals come back in creation order with their date', () async {
      final db = await freshDb();
      expect(await db.getSavingsGoals(), isEmpty);
      final a = await db.insertSavingsGoal('Laptop', 800, targetDate: DateTime(2027, 3, 15, 18, 30));
      final b = await db.insertSavingsGoal('  Trip  ', 250.5, saved: 40.25);
      final goals = await db.getSavingsGoals();
      expect(goals.map((g) => g.id), [a, b]);
      // The name is trimmed and only the calendar day of the date is kept;
      // a goal starts with nothing set aside unless told otherwise.
      expect(goals.map((g) => (g.name, g.target, g.saved, g.targetDate)), [
        ('Laptop', 800.0, 0.0, DateTime(2027, 3, 15)),
        ('Trip', 250.5, 40.25, null),
      ]);
      await db.close();
    });

    test('update changes one goal, and omitting the date clears it', () async {
      final db = await freshDb();
      final a = await db.insertSavingsGoal('Laptop', 800, targetDate: DateTime(2027, 3, 15));
      final b = await db.insertSavingsGoal('Trip', 250, saved: 10);
      await db.updateSavingsGoal(a, 'Laptop Pro', 1200,
          saved: 300, targetDate: DateTime(2027, 6, 1));
      expect(
          (await db.getSavingsGoals()).map((g) => (g.name, g.target, g.saved, g.targetDate)),
          [('Laptop Pro', 1200.0, 300.0, DateTime(2027, 6, 1)), ('Trip', 250.0, 10.0, null)]);
      await db.updateSavingsGoal(a, 'Laptop Pro', 1200, saved: 300);
      expect((await db.getSavingsGoals()).first.targetDate, isNull);
      expect((await db.getSavingsGoals()).last.id, b);
      await db.close();
    });

    test('addToGoal fills and empties an envelope, never past the target or below zero', () async {
      final db = await freshDb();
      final a = await db.insertSavingsGoal('A', 100, saved: 40);
      final b = await db.insertSavingsGoal('B', 100);
      Future<double> saved(int id) async =>
          (await db.getSavingsGoals()).firstWhere((g) => g.id == id).saved;

      await db.addToGoal(a, 25.5);
      expect(await saved(a), 65.5);
      await db.addToGoal(a, 500); // only 34.5 of room
      expect(await saved(a), 100);
      await db.addToGoal(a, -30);
      expect(await saved(a), 70);
      await db.addToGoal(a, -500);
      expect(await saved(a), 0);
      expect(await saved(b), 0, reason: 'other goals are untouched');

      await db.addToGoal(9999, 5); // unknown id: nothing happens
      await expectLater(db.addToGoal(a, double.nan), throwsArgumentError);
      await expectLater(db.addToGoal(a, double.infinity), throwsArgumentError);
      await db.close();
    });

    test('setting money aside moves no money: the Savings balance is untouched', () async {
      final db = await freshDb();
      final before = (await db.getAccounts()).firstWhere((a) => a.id == kSavingsId).balance;
      final txs = (await db.getAllTransactions()).length;
      final id = await db.insertSavingsGoal('Laptop', 80, saved: 60);
      await db.updateSavingsGoal(id, 'Laptop', 80, saved: 20);
      await db.deleteSavingsGoal(id);
      expect((await db.getAccounts()).firstWhere((a) => a.id == kSavingsId).balance, before);
      expect(await db.getAllTransactions(), hasLength(txs));
      await db.close();
    });

    test('delete removes only that goal and the others keep their order', () async {
      final db = await freshDb();
      final a = await db.insertSavingsGoal('A', 1);
      await db.insertSavingsGoal('B', 2);
      await db.insertSavingsGoal('C', 3);
      await db.deleteSavingsGoal(a);
      expect((await db.getSavingsGoals()).map((g) => g.name), ['B', 'C']);
      await db.deleteSavingsGoal(9999); // unknown id: nothing happens
      expect(await db.getSavingsGoals(), hasLength(2));
      await db.close();
    });

    test('a goal needs a name, a positive finite target and 0 <= saved <= target', () async {
      final db = await freshDb();
      final a = await db.insertSavingsGoal('A', 5, saved: 2);
      for (final (name, target, saved) in [
        ('', 5.0, 0.0), ('   ', 5.0, 0.0), ('A', 0.0, 0.0), ('A', -1.0, 0.0),
        ('A', double.nan, 0.0), ('A', double.infinity, 0.0),
        ('A', 5.0, -1.0), ('A', 5.0, 5.01), ('A', 5.0, double.nan),
      ]) {
        await expectLater(db.insertSavingsGoal(name, target, saved: saved), throwsArgumentError,
            reason: '"$name" / $target / $saved');
        await expectLater(
            db.updateSavingsGoal(a, name, target, saved: saved), throwsArgumentError,
            reason: 'update "$name" / $target / $saved');
      }
      expect((await db.getSavingsGoals()).map((g) => (g.name, g.target, g.saved)),
          [('A', 5.0, 2.0)]);
      // Exactly the target is fine: that goal is full.
      await db.updateSavingsGoal(a, 'A', 5, saved: 5);
      expect((await db.getSavingsGoals()).single.saved, 5);
      await db.close();
    });
  });

  group('category budgets', () {
    test('start empty; a limit is stored per category', () async {
      final db = await freshDb();
      expect(await db.getCategoryBudgets(), isEmpty);
      await db.setCategoryBudget('Food', 80);
      await db.setCategoryBudget('Transport', 12.5);
      expect(await db.getCategoryBudgets(), {'Food': 80.0, 'Transport': 12.5});
      await db.close();
    });

    test('setting a category again replaces its limit', () async {
      final db = await freshDb();
      await db.setCategoryBudget('Food', 80);
      await db.setCategoryBudget('Food', 95);
      expect(await db.getCategoryBudgets(), {'Food': 95.0});
      await db.close();
    });

    test('zero, negative, NaN and infinite amounts remove the limit', () async {
      final db = await freshDb();
      for (final bad in [0.0, -1.0, double.nan, double.infinity]) {
        await db.setCategoryBudget('Food', 80);
        await db.setCategoryBudget('Food', bad);
        expect(await db.getCategoryBudgets(), isEmpty, reason: '$bad');
      }
      await db.close();
    });

    test('removing a limit that was never set is harmless', () async {
      final db = await freshDb();
      await db.setCategoryBudget('Food', 0);
      expect(await db.getCategoryBudgets(), isEmpty);
      await db.close();
    });
  });

  group('debts', () {
    Future<void> lend(AppDatabase db, int account, double amount, String person,
        {DateTime? due}) async {
      final a = (await db.getAccounts()).firstWhere((x) => x.id == account);
      await db.applyTx(
        accountId: account,
        balance: a.balance - amount,
        loanedAmount: a.loanedAmount + amount,
        tx: mkTx(account, 'debt_out', amount),
        lend: (person: person, due: due),
      );
    }

    Future<void> repay(AppDatabase db, int account, int debtId, double amount) async {
      final a = (await db.getAccounts()).firstWhere((x) => x.id == account);
      await db.applyTx(
        accountId: account,
        balance: a.balance + amount,
        loanedAmount: a.loanedAmount - amount,
        tx: mkTx(account, 'debt_repaid', amount),
        repaysDebt: debtId,
      );
    }

    test('lending stores the person (trimmed), the amount and the due day', () async {
      final db = await freshDb();
      await lend(db, kWalletId, 40, '  Ali ', due: DateTime(2027, 1, 20, 15, 30));
      final d = (await db.getOpenDebts()).single;
      expect((d.person, d.amount, d.repaid, d.dueDate, d.accountId),
          ('Ali', 40.0, 0.0, DateTime(2027, 1, 20), kWalletId));
      expect(d.remaining, 40);
      await expectDebtsMatchAccounts(db);
      await db.close();
    });

    test('a blank person is refused and nothing is written', () async {
      final db = await freshDb();
      await expectLater(lend(db, kWalletId, 40, '   '), throwsArgumentError);
      expect(await db.getOpenDebts(), isEmpty);
      final w = (await db.getAccounts()).firstWhere((a) => a.id == kWalletId);
      expect((w.balance, w.loanedAmount), (600.0, 0.0));
      expect((await db.getTransactions(kWalletId)).where((t) => t.type == 'debt_out'), isEmpty);
      await db.close();
    });

    test('soonest due comes first, then undated ones, oldest first', () async {
      final db = await freshDb();
      await lend(db, kWalletId, 1, 'A');
      await lend(db, kWalletId, 1, 'B', due: DateTime(2027, 3, 1));
      await lend(db, kWalletId, 1, 'C', due: DateTime(2027, 1, 1));
      await lend(db, kWalletId, 1, 'D');
      expect((await db.getOpenDebts()).map((d) => d.person), ['C', 'B', 'A', 'D']);
      await db.close();
    });

    test('repaying takes the amount off that debt only; a settled debt drops off the list',
        () async {
      final db = await freshDb();
      await lend(db, kWalletId, 40, 'Ali');
      await lend(db, kWalletId, 10, 'Sara');
      var debts = await db.getOpenDebts();
      final ali = debts.firstWhere((d) => d.person == 'Ali');

      await repay(db, kWalletId, ali.id, 15);
      debts = await db.getOpenDebts();
      expect(debts.map((d) => (d.person, d.amount, d.repaid)),
          [('Ali', 40.0, 15.0), ('Sara', 10.0, 0.0)]);
      await expectDebtsMatchAccounts(db);

      await repay(db, kWalletId, ali.id, 25);
      expect((await db.getOpenDebts()).map((d) => d.person), ['Sara']);
      await expectDebtsMatchAccounts(db);
      await db.close();
    });

    test('repaying what is not an open debt of the account, or more than is owed, writes nothing',
        () async {
      final db = await freshDb();
      await lend(db, kWalletId, 40, 'Ali');
      final ali = (await db.getOpenDebts()).single;
      final txsBefore = (await db.getAllTransactions()).length;

      await expectLater(repay(db, kSavingsId, ali.id, 5), throwsStateError); // other account
      await expectLater(repay(db, kWalletId, ali.id, 41), throwsStateError); // more than owed
      await expectLater(repay(db, kWalletId, 999, 5), throwsStateError); // no such debt

      expect((await db.getOpenDebts()).single.remaining, 40);
      expect((await db.getAllTransactions()).length, txsBefore);
      final w = (await db.getAccounts()).firstWhere((a) => a.id == kWalletId);
      expect((w.balance, w.loanedAmount), (560.0, 40.0));

      await repay(db, kWalletId, ali.id, 40);
      await expectLater(repay(db, kWalletId, ali.id, 1), throwsStateError); // already settled
      await db.close();
    });

    test('updateDebt changes the person and due date but not the amounts', () async {
      final db = await freshDb();
      await lend(db, kWalletId, 40, 'Ali');
      final id = (await db.getOpenDebts()).single.id;

      await db.updateDebt(id, person: ' Ali Hassan ', dueDate: DateTime(2027, 2, 3, 9));
      var d = (await db.getOpenDebts()).single;
      expect((d.person, d.dueDate, d.amount, d.repaid), ('Ali Hassan', DateTime(2027, 2, 3), 40.0, 0.0));

      await db.updateDebt(id, person: 'Ali Hassan'); // no date clears it
      expect((await db.getOpenDebts()).single.dueDate, isNull);

      await expectLater(db.updateDebt(id, person: ' '), throwsArgumentError);
      d = (await db.getOpenDebts()).single;
      expect(d.person, 'Ali Hassan');
      await expectDebtsMatchAccounts(db);
      await db.close();
    });

    test('deleting an account deletes its debts', () async {
      final db = await freshDb();
      final id = await db.insertCustomAccount('Trip', 0, 1);
      await db.updateBalance(id, 100);
      await lend(db, id, 30, 'Ali');
      await lend(db, kWalletId, 5, 'Sara');
      await db.deleteAccount(id);
      expect((await db.getOpenDebts()).map((d) => d.person), ['Sara']);
      await db.close();
    });

    test('resetting the profile wipes the debts', () async {
      final db = await freshDb();
      await lend(db, kWalletId, 5, 'Sara');
      await db.resetDatabase();
      expect(await db.getOpenDebts(), isEmpty);
      await db.close();
    });
  });

  group('auto-pay bills', () {
    // freshDb's salary rows are from now, so a bill's cycle starts today and a
    // due day [n] days ahead is due on [day(n)].
    final today = DateTime.now();
    DateTime day(int n) => DateTime(today.year, today.month, today.day + n);

    Future<AppDatabase> walletDb() => freshDb(); // wallet 600

    Future<int> bill(AppDatabase db, String name, double amount, int dueIn,
            {bool auto = true, String category = ''}) =>
        db.insertBill(name, amount, category, dueDay: day(dueIn).day, autoPay: auto);

    Future<double> wallet(AppDatabase db) async =>
        (await db.getAccounts()).firstWhere((a) => a.id == kWalletId).balance;

    test('pays a bill on its due day: wallet charged, bill_paid logged, bill marked paid',
        () async {
      final db = await walletDb();
      final id = await bill(db, 'Rent', 50, 3, category: 'Housing');
      expect(await db.autoPayDueBills(day(3)), [id]);
      expect(await wallet(db), 550);
      expect((await db.getBills()).single.isPaid, isTrue);
      final tx = (await db.getTransactions(kWalletId)).firstWhere((t) => t.type == 'bill_paid');
      expect((tx.title, tx.amount, tx.category), ('Rent', 50.0, 'Housing'));
      await db.close();
    });

    test('also pays one whose due day is already behind us', () async {
      final db = await walletDb();
      final id = await bill(db, 'Rent', 50, 3);
      expect(await db.autoPayDueBills(day(9)), [id]);
      await db.close();
    });

    test('does nothing before the due day', () async {
      final db = await walletDb();
      await bill(db, 'Rent', 50, 3);
      expect(await db.autoPayDueBills(day(2)), isEmpty);
      expect(await wallet(db), 600);
      expect((await db.getBills()).single.isPaid, isFalse);
      expect((await db.getTransactions(kWalletId)).where((t) => t.type == 'bill_paid'), isEmpty);
      await db.close();
    });

    test('never touches a bill without auto-pay', () async {
      final db = await walletDb();
      await bill(db, 'Rent', 50, 1, auto: false);
      expect(await db.autoPayDueBills(day(5)), isEmpty);
      expect(await wallet(db), 600);
      await db.close();
    });

    test('charges a bill once, however often it runs', () async {
      final db = await walletDb();
      await bill(db, 'Rent', 50, 1);
      await db.autoPayDueBills(day(5));
      expect(await db.autoPayDueBills(day(5)), isEmpty);
      expect(await db.autoPayDueBills(day(6)), isEmpty);
      expect(await wallet(db), 550);
      expect((await db.getTransactions(kWalletId)).where((t) => t.type == 'bill_paid'), hasLength(1));
      await db.close();
    });

    test('two runs at the same time still charge once', () async {
      final db = await walletDb();
      await bill(db, 'Rent', 50, 1);
      final runs = await Future.wait([db.autoPayDueBills(day(5)), db.autoPayDueBills(day(5))]);
      expect(runs.expand((r) => r), hasLength(1));
      expect(await wallet(db), 550);
      await db.close();
    });

    test('a bill already paid by hand is left alone', () async {
      final db = await walletDb();
      final id = await bill(db, 'Rent', 50, 1);
      await db.markBillPaid(id);
      expect(await db.autoPayDueBills(day(5)), isEmpty);
      expect(await wallet(db), 600);
      await db.close();
    });

    test('a wallet that cannot cover it changes nothing; the next bill is still tried', () async {
      final db = await walletDb();
      final big = await bill(db, 'Big', 700, 1);
      final small = await bill(db, 'Small', 100, 2);
      expect(await db.autoPayDueBills(day(5)), [small]);
      expect(await wallet(db), 500);
      final bills = {for (final b in await db.getBills()) b.id: b.isPaid};
      expect(bills, {big: false, small: true});
      expect((await db.getTransactions(kWalletId)).where((t) => t.type == 'bill_paid'), hasLength(1));
      await db.close();
    });

    test('a wallet with exactly the amount pays it down to zero', () async {
      final db = await walletDb();
      await bill(db, 'All', 600, 1);
      expect(await db.autoPayDueBills(day(5)), hasLength(1));
      expect(await wallet(db), 0);
      await db.close();
    });

    test('soonest due day first, ties by id, so a short wallet pays the earlier one', () async {
      final db = await walletDb();
      final later = await bill(db, 'Later', 400, 4);
      final sooner = await bill(db, 'Sooner', 400, 2);
      expect(await db.autoPayDueBills(day(5)), [sooner]);
      expect((await db.getBills()).firstWhere((b) => b.id == later).isPaid, isFalse);
      await db.close();
    });

    test('auto-pay needs a due day: it is stored off without one', () async {
      final db = await walletDb();
      final id = await db.insertBill('A', 5, '', autoPay: true);
      expect((await db.getBills()).single.autoPay, isFalse);
      await db.updateBill(id, 'A', 5, '', dueDay: 12, autoPay: true);
      expect((await db.getBills()).single.autoPay, isTrue);
      await db.updateBill(id, 'A', 5, '', autoPay: true); // due day cleared
      expect((await db.getBills()).single.autoPay, isFalse);
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

    test('v1 -> v10 keeps old data and adds every new column', () async {
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
      expect((bill.isPaid, bill.category, bill.dueDay), (true, '', null));
      await db.markTutorialSeen('x'); // settings table exists
      expect(await db.insertCustomAccount('n', 1, 2), greaterThan(1));
      await db.setCategoryBudget('Food', 9); // category_budgets table exists
      await db.insertTransaction(mkTx(1, 'withdraw', 1, category: 'Food'));
      expect((await db.getAllTransactions()).single.category, 'Food');
      await db.insertSavingsGoal('Goal', 5); // savings_goals table exists
      expect((await db.getSavingsGoals()).single.name, 'Goal');
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

    test('v7 -> v8 keeps transactions, uncategorised, and adds the limits table',
        () async {
      final name = await legacyFile(7, [
        userV5,
        'CREATE TABLE accounts (id INTEGER PRIMARY KEY, type TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0.0, loaned_amount REAL DEFAULT 0.0, custom_name TEXT, color_index INTEGER, icon_code INTEGER)',
        tx,
        billsV4,
        settings,
      ], (db) async {
        await db.insert('accounts', {'id': 1, 'type': 'wallet', 'balance': 3.0});
        await db.insert('transactions', {
          'account_id': 1,
          'type': 'withdraw',
          'amount': 4.0,
          'title': 'Old',
          'created_at': 1700000000000,
        });
      });
      final db = AppDatabase.forFile(name);
      final old = (await db.getAllTransactions()).single;
      expect((old.title, old.amount, old.category), ('Old', 4.0, ''));
      expect(await db.getCategoryBudgets(), isEmpty);
      await db.setCategoryBudget('Food', 10);
      expect(await db.getCategoryBudgets(), {'Food': 10.0});
      await db.close();
    });

    test('v8 -> v9 keeps bills without a due day and accepts one', () async {
      final name = await legacyFile(8, [
        userV5,
        'CREATE TABLE accounts (id INTEGER PRIMARY KEY, type TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0.0, loaned_amount REAL DEFAULT 0.0, custom_name TEXT, color_index INTEGER, icon_code INTEGER)',
        "CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, title TEXT NOT NULL DEFAULT '', note TEXT DEFAULT '', category TEXT NOT NULL DEFAULT '', related_account_id INTEGER, created_at INTEGER NOT NULL)",
        billsV4,
        settings,
        'CREATE TABLE category_budgets (category TEXT PRIMARY KEY, amount REAL NOT NULL)',
      ], (db) async {
        await db.insert('bills',
            {'name': 'Rent', 'amount': 50.0, 'is_paid': 1, 'category': 'Housing'});
      });
      final db = AppDatabase.forFile(name);
      final old = (await db.getBills()).single;
      expect((old.name, old.isPaid, old.category, old.dueDay),
          ('Rent', true, 'Housing', null));
      await db.updateBill(old.id, 'Rent', 50, 'Housing', dueDay: 7);
      expect((await db.getBills()).single.dueDay, 7);
      await db.close();
    });

    test('v9 -> v10 keeps everything and adds the goals table', () async {
      final name = await legacyFile(9, [
        userV5,
        'CREATE TABLE accounts (id INTEGER PRIMARY KEY, type TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0.0, loaned_amount REAL DEFAULT 0.0, custom_name TEXT, color_index INTEGER, icon_code INTEGER)',
        "CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, title TEXT NOT NULL DEFAULT '', note TEXT DEFAULT '', category TEXT NOT NULL DEFAULT '', related_account_id INTEGER, created_at INTEGER NOT NULL)",
        "CREATE TABLE bills (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, amount REAL NOT NULL, is_paid INTEGER NOT NULL DEFAULT 0, category TEXT NOT NULL DEFAULT '', due_day INTEGER)",
        settings,
        'CREATE TABLE category_budgets (category TEXT PRIMARY KEY, amount REAL NOT NULL)',
      ], (db) async {
        await db.insert('bills',
            {'name': 'Rent', 'amount': 50.0, 'is_paid': 0, 'due_day': 7});
        await db.insert('category_budgets', {'category': 'Food', 'amount': 20.0});
      });
      final db = AppDatabase.forFile(name);
      expect((await db.getBills()).single.dueDay, 7);
      expect(await db.getCategoryBudgets(), {'Food': 20.0});
      expect(await db.getSavingsGoals(), isEmpty);
      await db.insertSavingsGoal('Laptop', 800);
      expect((await db.getSavingsGoals()).single.name, 'Laptop');
      await db.close();
    });

    test('v10 -> v11 keeps the goals and starts each with nothing set aside', () async {
      final name = await legacyFile(10, [
        userV5,
        'CREATE TABLE accounts (id INTEGER PRIMARY KEY, type TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0.0, loaned_amount REAL DEFAULT 0.0, custom_name TEXT, color_index INTEGER, icon_code INTEGER)',
        "CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, title TEXT NOT NULL DEFAULT '', note TEXT DEFAULT '', category TEXT NOT NULL DEFAULT '', related_account_id INTEGER, created_at INTEGER NOT NULL)",
        "CREATE TABLE bills (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, amount REAL NOT NULL, is_paid INTEGER NOT NULL DEFAULT 0, category TEXT NOT NULL DEFAULT '', due_day INTEGER)",
        settings,
        'CREATE TABLE category_budgets (category TEXT PRIMARY KEY, amount REAL NOT NULL)',
        'CREATE TABLE savings_goals (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, target REAL NOT NULL, target_date INTEGER)',
      ], (db) async {
        await db.insert('savings_goals', {'name': 'Laptop', 'target': 800.0});
      });
      final db = AppDatabase.forFile(name);
      final g = (await db.getSavingsGoals()).single;
      expect((g.name, g.target, g.saved), ('Laptop', 800.0, 0.0));
      await db.updateSavingsGoal(g.id, 'Laptop', 800, saved: 150);
      expect((await db.getSavingsGoals()).single.saved, 150);
      await db.close();
    });

    test('v11 -> v12 gives the user salary day 1 and lets it change', () async {
      final name = await legacyFile(11, [
        userV5,
        'CREATE TABLE accounts (id INTEGER PRIMARY KEY, type TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0.0, loaned_amount REAL DEFAULT 0.0, custom_name TEXT, color_index INTEGER, icon_code INTEGER)',
        "CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, title TEXT NOT NULL DEFAULT '', note TEXT DEFAULT '', category TEXT NOT NULL DEFAULT '', related_account_id INTEGER, created_at INTEGER NOT NULL)",
        "CREATE TABLE bills (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, amount REAL NOT NULL, is_paid INTEGER NOT NULL DEFAULT 0, category TEXT NOT NULL DEFAULT '', due_day INTEGER)",
        settings,
        'CREATE TABLE category_budgets (category TEXT PRIMARY KEY, amount REAL NOT NULL)',
        'CREATE TABLE savings_goals (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, target REAL NOT NULL, saved REAL NOT NULL DEFAULT 0, target_date INTEGER)',
      ], (db) async {
        await db.insert('user',
            {'id': 1, 'name': 'Old', 'salary': 900.0, 'monthly_budget': 300.0});
      });
      final db = AppDatabase.forFile(name);
      final u = (await db.getUser())!;
      expect((u.name, u.salary, u.salaryDay), ('Old', 900.0, 1));
      await db.updateUser(u.copyWith(salaryDay: 27));
      expect((await db.getUser())!.salaryDay, 27);
      expect(await db.lastSalaryProcessedAt(), isNull);
      await db.close();
    });

    test('v12 -> v13 turns money already lent out into one "Earlier debts" row per account',
        () async {
      final name = await legacyFile(12, [
        "CREATE TABLE user (id INTEGER PRIMARY KEY, name TEXT NOT NULL, salary REAL NOT NULL, monthly_budget REAL NOT NULL, currency TEXT NOT NULL DEFAULT 'JOD', salary_day INTEGER NOT NULL DEFAULT 1)",
        'CREATE TABLE accounts (id INTEGER PRIMARY KEY, type TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0.0, loaned_amount REAL DEFAULT 0.0, custom_name TEXT, color_index INTEGER, icon_code INTEGER)',
        "CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, title TEXT NOT NULL DEFAULT '', note TEXT DEFAULT '', category TEXT NOT NULL DEFAULT '', related_account_id INTEGER, created_at INTEGER NOT NULL)",
        "CREATE TABLE bills (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, amount REAL NOT NULL, is_paid INTEGER NOT NULL DEFAULT 0, category TEXT NOT NULL DEFAULT '', due_day INTEGER)",
        settings,
        'CREATE TABLE category_budgets (category TEXT PRIMARY KEY, amount REAL NOT NULL)',
        'CREATE TABLE savings_goals (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, target REAL NOT NULL, saved REAL NOT NULL DEFAULT 0, target_date INTEGER)',
      ], (db) async {
        await db.insert('accounts', {'id': 1, 'type': 'wallet', 'balance': 5.0, 'loaned_amount': 30.0});
        await db.insert('accounts', {'id': 2, 'type': 'budget', 'balance': 5.0, 'loaned_amount': 0.0});
        await db.insert('accounts', {'id': 3, 'type': 'savings', 'balance': 5.0, 'loaned_amount': null});
      });
      final db = AppDatabase.forFile(name);
      final debts = await db.getOpenDebts();
      expect(debts.map((d) => (d.accountId, d.person, d.amount, d.repaid, d.dueDate)),
          [(1, 'Earlier debts', 30.0, 0.0, null)]);
      await expectDebtsMatchAccounts(db);
      // It is a debt like any other: it can be renamed and paid back.
      await db.updateDebt(debts.single.id, person: 'Ali');
      expect((await db.getOpenDebts()).single.person, 'Ali');
      await db.close();
    });

    test('v13 -> v14 gives every bill auto-pay off, and it can be turned on', () async {
      final name = await legacyFile(13, [
        "CREATE TABLE user (id INTEGER PRIMARY KEY, name TEXT NOT NULL, salary REAL NOT NULL, monthly_budget REAL NOT NULL, currency TEXT NOT NULL DEFAULT 'JOD', salary_day INTEGER NOT NULL DEFAULT 1)",
        'CREATE TABLE accounts (id INTEGER PRIMARY KEY, type TEXT NOT NULL, balance REAL NOT NULL DEFAULT 0.0, loaned_amount REAL DEFAULT 0.0, custom_name TEXT, color_index INTEGER, icon_code INTEGER)',
        "CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, title TEXT NOT NULL DEFAULT '', note TEXT DEFAULT '', category TEXT NOT NULL DEFAULT '', related_account_id INTEGER, created_at INTEGER NOT NULL)",
        "CREATE TABLE bills (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, amount REAL NOT NULL, is_paid INTEGER NOT NULL DEFAULT 0, category TEXT NOT NULL DEFAULT '', due_day INTEGER)",
        settings,
        'CREATE TABLE category_budgets (category TEXT PRIMARY KEY, amount REAL NOT NULL)',
        'CREATE TABLE savings_goals (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, target REAL NOT NULL, saved REAL NOT NULL DEFAULT 0, target_date INTEGER)',
        'CREATE TABLE debts (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL, person TEXT NOT NULL, amount REAL NOT NULL, repaid REAL NOT NULL DEFAULT 0, due_date INTEGER, created_at INTEGER NOT NULL)',
      ], (db) async {
        await db.insert('bills',
            {'name': 'Rent', 'amount': 50.0, 'is_paid': 1, 'due_day': 7});
      });
      final db = AppDatabase.forFile(name);
      final old = (await db.getBills()).single;
      expect((old.name, old.isPaid, old.dueDay, old.autoPay), ('Rent', true, 7, false));
      await db.updateBill(old.id, 'Rent', 50, '', dueDay: 7, autoPay: true);
      expect((await db.getBills()).single.autoPay, isTrue);
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
      expect((await db.getOpenDebts()).single.amount, 9);
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
