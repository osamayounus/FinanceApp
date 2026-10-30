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
    await n.lendDebt(kWalletId, 40, mkTx(kWalletId, 'debt_out', 40, title: 'Lent to Ali'));
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
    await e.db.insertBill('Rent', 250, 'Housing');
    final net = await e.db.insertBill('Internet', 20.5, '');
    await e.db.markBillPaid(net);
    return e;
  }

  /// Raw stored rows of the four data tables - what a faithful restore must reproduce.
  Future<String> dump(AppDatabase db) async {
    final raw = await db.database;
    return jsonEncode({
      for (final t in ['user', 'accounts', 'transactions', 'bills'])
        t: await raw.query(t, orderBy: 'id ASC'),
    });
  }

  Future<void> restore(AppDatabase target, String json) =>
      target.restoreBackup(AppDatabase.parseBackup(json));

  group('export', () {
    test('is JSON with the app marker, a version and the four tables', () async {
      final e = await populated();
      final m = jsonDecode(await e.db.exportBackup()) as Map<String, dynamic>;
      expect(m.keys.toSet(),
          {'app', 'version', 'exportedAt', 'user', 'accounts', 'transactions', 'bills'});
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
      expect(accounts[kWalletId]!.loanedAmount, 40);

      final txs = await dst.db.getAllTransactions();
      expect(txs.map((t) => t.note), contains('first, "quoted" ✓ نص'));
      expect(txs.map((t) => t.note), contains('x\x00Trip Fund'));
      // The wallet row pointing at the since-deleted account survives.
      expect(txs.where((t) => t.title == 'To temp'), hasLength(1));

      final bills = await dst.db.getBills();
      expect(bills.map((b) => (b.name, b.amount, b.category, b.isPaid)),
          [('Rent', 250.0, 'Housing', false), ('Internet', 20.5, '', true)]);
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
      expect(b.bills.single, {'id': 1, 'name': 'Rent', 'amount': 5.0, 'is_paid': 0, 'category': ''});
      expect(b.exportedAt, isNull);

      await restore(e.db, jsonEncode(m));
      expect((await e.db.getBills()).single.name, 'Rent');
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
