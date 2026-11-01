import 'dart:convert';

import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_env.dart';

void main() {
  setUpAll(setUpTestEnv);
  tearDownAll(tearDownTestEnv);

  final open = <ProviderContainer>[];
  final dbs = <AppDatabase>[];
  tearDown(() async {
    for (final c in open) {
      c.dispose();
    }
    for (final d in dbs) {
      await d.close();
    }
    open.clear();
    dbs.clear();
  });

  Future<({AppDatabase db, ProviderContainer c})> env({double savings = 100}) async {
    final e = await seededContainer(savings: savings);
    open.add(e.c);
    dbs.add(e.db);
    return e;
  }

  /// A profile that has used most features: custom account, deposit with a note,
  /// debt, a transfer, a transfer to an account that was deleted later, bills.
  Future<({AppDatabase db, ProviderContainer c})> populated() async {
    final e = await env();
    final n = e.c.read(accountsProvider.notifier);
    final trip = await n.addCustomAccount('Trip Fund', 3, 57424);
    await n.deposit(trip.id, 80,
        mkTx(trip.id, 'deposit', 80, title: 'Seed', note: 'first, "quoted" ✓ نص'));
    await n.lendDebt(kWalletId, 40, mkTx(kWalletId, 'debt_out', 40, title: 'Lent to Ali'),
        person: 'Ali', due: DateTime(2027, 1, 20));
    await n.lendDebt(kWalletId, 10, mkTx(kWalletId, 'debt_out', 10, title: 'Lent to Sara'),
        person: 'Sara');
    final sara = (await e.db.getOpenDebts()).firstWhere((d) => d.person == 'Sara');
    await n.repayDebt(kWalletId, 4, mkTx(kWalletId, 'debt_repaid', 4, title: 'Sara paid back'),
        debtId: sara.id);
    await n.transfer(
      fromId: kWalletId,
      toId: trip.id,
      amount: 25,
      txOut: mkTx(kWalletId, 'transfer_out', 25,
          title: 'Move', note: 'x\x00Trip Fund', related: trip.id),
      txIn: mkTx(trip.id, 'transfer_in', 25,
          title: 'Move', note: 'x\x00Wallet', related: kWalletId),
    );
    final temp = await n.addCustomAccount('Temp', 0, 0);
    await n.transfer(
      fromId: kWalletId,
      toId: temp.id,
      amount: 5,
      txOut: mkTx(kWalletId, 'transfer_out', 5, title: 'To temp', related: temp.id),
      txIn: mkTx(temp.id, 'transfer_in', 5, title: 'From wallet', related: kWalletId),
    );
    await n.deleteCustomAccount(temp.id, transferToWallet: true);
    await e.db.insertBill('Rent', 250, 'Housing', dueDay: 5, autoPay: true);
    final net = await e.db.insertBill('Internet', 20.5, '');
    await e.db.markBillPaid(net);
    await n.withdraw(kWalletId, 12.5,
        mkTx(kWalletId, 'withdraw', 12.5, title: 'Lunch', category: 'Food'));
    await e.db.setCategoryBudget('Food', 80);
    await e.db.setCategoryBudget('Transport', 30.5);
    await e.db.insertSavingsGoal('Laptop', 800, saved: 60.5, targetDate: DateTime(2027, 3, 15));
    await e.db.insertSavingsGoal('Trip', 250.5);
    return e;
  }

  /// Raw stored rows of the data tables - what a faithful restore must reproduce.
  Future<String> dump(AppDatabase db) async {
    final raw = await db.database;
    return jsonEncode({
      for (final (t, order) in [
        ('user', 'id'),
        ('accounts', 'id'),
        ('transactions', 'id'),
        ('bills', 'id'),
        ('category_budgets', 'category'),
        ('savings_goals', 'id'),
        ('debts', 'id'),
      ])
        t: await raw.query(t, orderBy: '$order ASC'),
    });
  }

  Future<void> restore(AppDatabase target, String json) =>
      target.restoreBackup(AppDatabase.parseBackup(json));

  group('export', () {
    test('is JSON with the app marker, a version and the data tables', () async {
      final e = await populated();
      final m = jsonDecode(await e.db.exportBackup()) as Map<String, dynamic>;
      expect(m.keys.toSet(), {
        'app', 'version', 'exportedAt', 'user', 'accounts', 'transactions', 'bills',
        'category_budgets', 'savings_goals', 'debts',
      });
      expect((m['app'], m['version']), ('financeapp', 1));
      expect(DateTime.parse(m['exportedAt'] as String).difference(DateTime.now()).inSeconds.abs(),
          lessThan(60));
      expect(m['user'], hasLength(1));
      expect((m['bills'] as List), hasLength(2));
    });

    test('leaves out settings (tutorial flags are not user data)', () async {
      final e = await env();
      await e.db.markTutorialSeen('home');
      expect(await e.db.exportBackup(), isNot(contains('settings')));
    });

    test('does not change the database', () async {
      final e = await populated();
      final before = await dump(e.db);
      await e.db.exportBackup();
      expect(await dump(e.db), before);
    });
  });

  group('restore', () {
    test('into a different profile reproduces every row exactly', () async {
      final src = await populated();
      final dst = await env(savings: 999);
      await dst.c.read(accountsProvider.notifier).addCustomAccount('Other', 1, 1);

      await restore(dst.db, await src.db.exportBackup());

      expect(await dump(dst.db), await dump(src.db));
    });

    test('into the same profile after it was changed puts the old state back', () async {
      final e = await populated();
      final json = await e.db.exportBackup();
      final saved = await dump(e.db);

      final n = e.c.read(accountsProvider.notifier);
      await n.withdraw(kWalletId, 100, mkTx(kWalletId, 'withdraw', 100, title: 'Oops'));
      await e.db.insertBill('Extra', 1, '');
      expect(await dump(e.db), isNot(saved));

      await restore(e.db, json);
      expect(await dump(e.db), saved);
    });

    test('keeps the details of custom accounts, debts and transfers', () async {
      final src = await populated();
      final dst = await env();
      await restore(dst.db, await src.db.exportBackup());

      final accounts = {for (final a in await dst.db.getAccounts()) a.id: a};
      final trip = accounts.values.firstWhere((a) => a.displayName == 'Trip Fund');
      expect((trip.type, trip.colorIndex, trip.iconCode, trip.balance),
          (AccountType.custom, 3, 57424, 105.0));
      expect(accounts[kWalletId]!.loanedAmount, 46);
      expect(
          (await dst.db.getOpenDebts())
              .map((d) => (d.person, d.amount, d.repaid, d.dueDate, d.accountId)),
          [
            ('Ali', 40.0, 0.0, DateTime(2027, 1, 20), kWalletId),
            ('Sara', 10.0, 4.0, null, kWalletId),
          ]);

      final txs = await dst.db.getAllTransactions();
      expect(txs.map((t) => t.note), contains('first, "quoted" ✓ نص'));
      expect(txs.map((t) => t.note), contains('x\x00Trip Fund'));
      // The wallet row pointing at the since-deleted account survives.
      expect(txs.where((t) => t.title == 'To temp'), hasLength(1));

      final bills = await dst.db.getBills();
      expect(bills.map((b) => (b.name, b.amount, b.category, b.isPaid, b.dueDay)),
          [('Rent', 250.0, 'Housing', false, 5), ('Internet', 20.5, '', true, null)]);
    });

    test('keeps transaction categories and replaces the category limits', () async {
      final src = await populated();
      final dst = await env();
      await dst.db.setCategoryBudget('Health', 5);

      await restore(dst.db, await src.db.exportBackup());

      final lunch = (await dst.db.getAllTransactions()).firstWhere((t) => t.title == 'Lunch');
      expect(lunch.category, 'Food');
      expect(await dst.db.getCategoryBudgets(), {'Food': 80.0, 'Transport': 30.5});
    });

    test('keeps savings goals (with and without a date) and replaces the old ones', () async {
      final src = await populated();
      final dst = await env();
      await dst.db.insertSavingsGoal('Old', 5);

      await restore(dst.db, await src.db.exportBackup());

      final goals = await dst.db.getSavingsGoals();
      expect(goals.map((g) => (g.name, g.target, g.saved, g.targetDate)), [
        ('Laptop', 800.0, 60.5, DateTime(2027, 3, 15)),
        ('Trip', 250.5, 0.0, null),
      ]);
      expect(await dst.db.insertSavingsGoal('Next', 1), greaterThan(goals.last.id));
    });

    test('a backup from before debts had people keeps the lent money as "Earlier debts"',
        () async {
      final src = await populated();
      final dst = await env();
      await dst.c.read(accountsProvider.notifier).lendDebt(
          kSavingsId, 5, mkTx(kSavingsId, 'debt_out', 5), person: 'Old');
      final m = jsonDecode(await src.db.exportBackup()) as Map<String, dynamic>
        ..remove('debts');

      await restore(dst.db, jsonEncode(m));

      expect((await dst.db.getOpenDebts()).map((d) => (d.person, d.amount, d.accountId)),
          [('Earlier debts', 46.0, kWalletId)]);
      await expectDebtsMatchAccounts(dst.db);
    });

    test('a backup from before goals held money restores them with nothing set aside', () async {
      final src = await populated();
      final dst = await env();
      final m = jsonDecode(await src.db.exportBackup()) as Map<String, dynamic>;
      for (final g in m['savings_goals'] as List) {
        (g as Map).remove('saved');
      }

      await restore(dst.db, jsonEncode(m));

      expect((await dst.db.getSavingsGoals()).map((g) => (g.name, g.saved)),
          [('Laptop', 0.0), ('Trip', 0.0)]);
    });

    test('keeps the salary day; a backup without one (or with a bad one) means day 1', () async {
      final src = await populated();
      await src.db.updateUser(kTestUser.copyWith(salaryDay: 27));
      final json = await src.db.exportBackup();

      final dst = await env();
      await restore(dst.db, json);
      expect((await dst.db.getUser())!.salaryDay, 27);

      for (final value in <Object?>[null, 0, 32, 'x', 2.5]) {
        final m = jsonDecode(json) as Map<String, dynamic>;
        final user = (m['user'] as List).single as Map;
        value == null ? user.remove('salary_day') : user['salary_day'] = value;
        await restore(dst.db, jsonEncode(m));
        expect((await dst.db.getUser())!.salaryDay, 1, reason: 'salary_day: $value');
      }
    });

    test('keeps timestamps', () async {
      final src = await populated();
      final dst = await env();
      final at = DateTime(2023, 2, 28, 23, 59, 58, 123);
      await src.db.insertTransaction(mkTx(kWalletId, 'bill_paid', 1, title: 'Old', at: at));
      await restore(dst.db, await src.db.exportBackup());
      final t = (await dst.db.getAllTransactions()).firstWhere((t) => t.title == 'Old');
      expect(t.createdAt, at);
    });

    test('new rows after a restore get fresh ids', () async {
      final src = await populated();
      final dst = await env();
      await restore(dst.db, await src.db.exportBackup());
      final maxId = (await dst.db.getAllTransactions()).map((t) => t.id).reduce((a, b) => a > b ? a : b);

      await dst.db.insertTransaction(mkTx(kWalletId, 'deposit', 1, title: 'After'));
      final fresh = (await dst.db.getAllTransactions()).firstWhere((t) => t.title == 'After');
      expect(fresh.id, greaterThan(maxId));
      expect(await dst.db.insertBill('New', 1, ''), greaterThan(2));
      expect(await dst.db.insertCustomAccount('N', 0, 0), greaterThan(3));
    });

    test('does not touch settings', () async {
      final src = await populated();
      final dst = await env();
      await dst.db.markTutorialSeen('home');
      await restore(dst.db, await src.db.exportBackup());
      expect(await dst.db.hasTutorialSeen('home'), isTrue);
    });

    test('providers pick up the restored data after reload()', () async {
      final src = await populated();
      await src.c.read(userProvider.notifier).update(name: 'Restored', salary: 2000, monthlyBudget: 500);
      final dst = await env();

      await restore(dst.db, await src.db.exportBackup());
      await Future.wait([
        dst.c.read(userProvider.notifier).reload(),
        dst.c.read(accountsProvider.notifier).reload(),
        dst.c.read(expensesProvider.notifier).reload(),
      ]);

      final u = dst.c.read(userProvider);
      expect((u.name, u.salary, u.monthlyBudget), ('Restored', 2000.0, 500.0));
      expect(dst.c.read(accountsProvider).map((a) => a.id).toList(),
          (await src.db.getAccounts()).map((a) => a.id).toList());
      expect(dst.c.read(expensesProvider).map((b) => b.name), ['Rent', 'Internet']);
      await expectStateMatchesDb(dst.c, dst.db);
    });

    test('a failure half-way leaves the current data untouched', () async {
      final src = await populated();
      final dst = await populated();
      final before = await dump(dst.db);

      final good = AppDatabase.parseBackup(await src.db.exportBackup());
      // Same bill twice: the primary-key clash happens after the old rows were deleted.
      final broken = (
        exportedAt: good.exportedAt,
        user: good.user,
        accounts: good.accounts,
        transactions: good.transactions,
        bills: [...good.bills, ...good.bills],
        categoryBudgets: good.categoryBudgets,
        savingsGoals: good.savingsGoals,
        debts: good.debts,
      );
      await expectLater(dst.db.restoreBackup(broken), throwsA(anything));

      expect(await dump(dst.db), before);
    });

    test('5,000 transactions export and restore quickly', () async {
      final src = await env();
      final raw = await src.db.database;
      final batch = raw.batch();
      for (var i = 0; i < 5000; i++) {
        batch.insert('transactions',
            mkTx(i.isEven ? kWalletId : kSavingsId, 'deposit', 1, title: 'n$i').toMap());
      }
      await batch.commit(noResult: true);
      final dst = await env();

      final sw = Stopwatch()..start();
      await restore(dst.db, await src.db.exportBackup());
      sw.stop();

      expect((await dst.db.getAllTransactions()), hasLength(5003));
      expect(sw.elapsedMilliseconds, lessThan(5000));
    });
  });

  group('parseBackup rejects what is not a usable backup', () {
    late String valid;
    setUp(() async {
      valid = await (await populated()).db.exportBackup();
    });

    Map<String, dynamic> decoded() => jsonDecode(valid) as Map<String, dynamic>;

    void expectRejected(String text, {String? message}) {
      expect(
        () => AppDatabase.parseBackup(text),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains(message ?? 'not a valid FinanceApp backup'))),
      );
    }

    test('text that is not JSON', () {
      expectRejected('not json at all');
      expectRejected('');
      expectRejected('{"app": "financeapp"');
    });

    test('JSON that is not an object', () {
      expectRejected('[]');
      expectRejected('42');
      expectRejected('null');
    });

    test('a backup made by a newer app version says so', () {
      final m = decoded()..['version'] = 2;
      expectRejected(jsonEncode(m), message: 'newer version');
    });

    final breakers = <String, void Function(Map<String, dynamic>)>{
      'another app\'s JSON': (m) => m['app'] = 'something-else',
      'no app marker': (m) => m.remove('app'),
      'no version': (m) => m.remove('version'),
      'version as text': (m) => m['version'] = '1',
      'no user': (m) => m.remove('user'),
      'no user row': (m) => m['user'] = [],
      'two user rows': (m) => m['user'] = [...m['user'], ...m['user']],
      'user without a name': (m) => (m['user'] as List).first.remove('name'),
      'user salary as text': (m) => (m['user'] as List).first['salary'] = 'lots',
      'no accounts': (m) => m.remove('accounts'),
      'accounts is not a list': (m) => m['accounts'] = 'x',
      'wallet missing': (m) => (m['accounts'] as List).removeWhere((a) => a['id'] == kWalletId),
      'budget missing': (m) => (m['accounts'] as List).removeWhere((a) => a['id'] == kBudgetId),
      'savings missing': (m) => (m['accounts'] as List).removeWhere((a) => a['id'] == kSavingsId),
      'duplicate account id': (m) => (m['accounts'] as List).add(Map.of((m['accounts'] as List).last)),
      'wallet id with the savings type': (m) =>
          (m['accounts'] as List).firstWhere((a) => a['id'] == kWalletId)['type'] = 'savings',
      'custom account typed as wallet': (m) =>
          (m['accounts'] as List).firstWhere((a) => a['id'] > 3)['type'] = 'wallet',
      'unknown account type': (m) =>
          (m['accounts'] as List).firstWhere((a) => a['id'] > 3)['type'] = 'crypto',
      'balance as text': (m) => (m['accounts'] as List).first['balance'] = 'rich',
      'no transactions': (m) => m.remove('transactions'),
      'transaction of an unknown account': (m) =>
          (m['transactions'] as List).first['account_id'] = 777,
      'transaction amount as text': (m) =>
          (m['transactions'] as List).first['amount'] = 'abc',
      'transaction without a date': (m) =>
          (m['transactions'] as List).first.remove('created_at'),
      'transaction that is not an object': (m) => (m['transactions'] as List).add(5),
      'no bills': (m) => m.remove('bills'),
      'bill without a name': (m) => (m['bills'] as List).first['name'] = null,
      'bill amount as text': (m) => (m['bills'] as List).first['amount'] = 'x',
      'bill due day as text': (m) => (m['bills'] as List).first['due_day'] = 'fifth',
      'category limits that are not a list': (m) => m['category_budgets'] = 'x',
      'category limit as text': (m) =>
          (m['category_budgets'] as List).first['amount'] = 'lots',
      'category limit of zero': (m) =>
          (m['category_budgets'] as List).first['amount'] = 0,
      'negative category limit': (m) =>
          (m['category_budgets'] as List).first['amount'] = -5,
      'category limit without a name': (m) =>
          (m['category_budgets'] as List).first.remove('category'),
      'goals that are not a list': (m) => m['savings_goals'] = 'x',
      'goal target as text': (m) =>
          (m['savings_goals'] as List).first['target'] = 'lots',
      'goal target of zero': (m) => (m['savings_goals'] as List).first['target'] = 0,
      'negative goal target': (m) => (m['savings_goals'] as List).first['target'] = -1,
      'goal without a name': (m) => (m['savings_goals'] as List).first['name'] = '  ',
      'goal saved as text': (m) => (m['savings_goals'] as List).first['saved'] = 'some',
      'negative goal saved': (m) => (m['savings_goals'] as List).first['saved'] = -1,
      'goal saved above its target': (m) =>
          (m['savings_goals'] as List).first['saved'] = 800.5,
      'goal date as text': (m) =>
          (m['savings_goals'] as List).first['target_date'] = 'soon',
      'debts that are not a list': (m) => m['debts'] = 'x',
      'debt of an unknown account': (m) =>
          (m['debts'] as List).first['account_id'] = 777,
      'debt without a person': (m) => (m['debts'] as List).first['person'] = '  ',
      'debt amount as text': (m) => (m['debts'] as List).first['amount'] = 'lots',
      'debt amount of zero': (m) => (m['debts'] as List).first['amount'] = 0,
      'negative debt repaid': (m) => (m['debts'] as List).first['repaid'] = -1,
      'debt repaid above its amount': (m) => (m['debts'] as List).first['repaid'] = 41,
      'debt date as text': (m) => (m['debts'] as List).first['due_date'] = 'soon',
      'debt without a created date': (m) =>
          (m['debts'] as List).first.remove('created_at'),
      'debts that do not add up to the lent amount': (m) =>
          (m['debts'] as List).first['amount'] = 41,
    };
    for (final e in breakers.entries) {
      test(e.key, () {
        final m = decoded();
        e.value(m);
        expectRejected(jsonEncode(m));
      });
    }

    test('a rejected file never reaches the database', () async {
      final dst = await env();
      final before = await dump(dst.db);
      final m = decoded()..remove('bills');
      // parse is what the UI calls first; if it throws, restore is never reached.
      expect(() => AppDatabase.parseBackup(jsonEncode(m)), throwsFormatException);
      expect(await dump(dst.db), before);
    });
  });

  group('parseBackup accepts', () {
    test('a backup whose optional columns are missing', () async {
      final e = await env();
      final m = jsonDecode(await e.db.exportBackup()) as Map<String, dynamic>;
      (m['user'] as List).first.remove('currency');
      for (final a in m['accounts'] as List) {
        a.remove('loaned_amount');
      }
      for (final t in m['transactions'] as List) {
        t.remove('note');
        t.remove('related_account_id');
      }
      m['bills'] = [
        {'id': 1, 'name': 'Rent', 'amount': 5, 'is_paid': 0}, // int amount, no category
      ];
      m.remove('exportedAt');

      final b = AppDatabase.parseBackup(jsonEncode(m));
      expect(b.user['currency'], 'JOD');
      expect(b.accounts.every((a) => a['loaned_amount'] == 0.0), isTrue);
      expect(b.bills.single, {
        'id': 1, 'name': 'Rent', 'amount': 5.0, 'is_paid': 0, 'category': '', 'due_day': null,
        'auto_pay': 0,
      });
      expect(b.exportedAt, isNull);

      await restore(e.db, jsonEncode(m));
      expect((await e.db.getBills()).single.name, 'Rent');
    });

    test('a backup made before categories existed: no limits, uncategorised transactions',
        () async {
      final src = await populated();
      final dst = await env();
      await dst.db.setCategoryBudget('Health', 5);
      final m = jsonDecode(await src.db.exportBackup()) as Map<String, dynamic>
        ..remove('category_budgets');
      for (final t in m['transactions'] as List) {
        t.remove('category');
      }

      await restore(dst.db, jsonEncode(m));

      expect(await dst.db.getCategoryBudgets(), isEmpty);
      expect((await dst.db.getAllTransactions()).every((t) => t.category == ''), isTrue);
    });

    test('a due day outside 1-31 is dropped, not restored', () async {
      final e = await env();
      final m = jsonDecode(await e.db.exportBackup()) as Map<String, dynamic>;
      m['bills'] = [
        {'id': 1, 'name': 'A', 'amount': 1, 'is_paid': 0, 'due_day': 40},
        {'id': 2, 'name': 'B', 'amount': 1, 'is_paid': 0, 'due_day': 12},
      ];
      await restore(e.db, jsonEncode(m));
      expect((await e.db.getBills()).map((b) => b.dueDay), [null, 12]);
    });

    test('auto-pay survives a restore; an old backup (no flag) or one without a due day has it off',
        () async {
      final src = await populated();
      final e = await env();
      await restore(e.db, await src.db.exportBackup());
      expect((await e.db.getBills()).map((b) => (b.name, b.autoPay)),
          [('Rent', true), ('Internet', false)]);

      final m = jsonDecode(await src.db.exportBackup()) as Map<String, dynamic>;
      m['bills'] = [
        {'id': 1, 'name': 'Old', 'amount': 1, 'is_paid': 0, 'due_day': 12}, // made before auto-pay
        {'id': 2, 'name': 'NoDay', 'amount': 1, 'is_paid': 0, 'auto_pay': 1},
        {'id': 3, 'name': 'BadDay', 'amount': 1, 'is_paid': 0, 'due_day': 40, 'auto_pay': 1},
        {'id': 4, 'name': 'On', 'amount': 1, 'is_paid': 0, 'due_day': 12, 'auto_pay': 1},
      ];
      await restore(e.db, jsonEncode(m));
      expect((await e.db.getBills()).map((b) => b.autoPay), [false, false, false, true]);
    });

    test('a backup made before savings goals existed leaves the profile with none', () async {
      final src = await populated();
      final dst = await env();
      await dst.db.insertSavingsGoal('Old', 5);
      final m = jsonDecode(await src.db.exportBackup()) as Map<String, dynamic>
        ..remove('savings_goals');

      await restore(dst.db, jsonEncode(m));

      expect(await dst.db.getSavingsGoals(), isEmpty);
    });

    test('an empty profile (no transactions, no bills)', () async {
      final e = await env();
      final m = jsonDecode(await e.db.exportBackup()) as Map<String, dynamic>
        ..['transactions'] = []
        ..['bills'] = [];
      await restore(e.db, jsonEncode(m));
      expect(await e.db.getAllTransactions(), isEmpty);
    });

    test('extra unknown keys are ignored, not inserted', () async {
      final e = await env();
      final m = jsonDecode(await e.db.exportBackup()) as Map<String, dynamic>;
      m['future_field'] = 1;
      (m['user'] as List).first['evil_column'] = 'x';
      (m['bills'] as List).add({'id': 9, 'name': 'B', 'amount': 1, 'is_paid': 1, 'category': '', 'zzz': 1});
      await restore(e.db, jsonEncode(m));
      expect((await e.db.getBills()).single.isPaid, isTrue);
    });
  });
}
