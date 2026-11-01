import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/analytics_model.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_env.dart';

void main() {
  setUpAll(setUpTestEnv);
  tearDownAll(tearDownTestEnv);

  late AppDatabase db;
  late ProviderContainer c;
  final now = DateTime.now();

  DateTime monthsAgo(int m, {int day = 15}) =>
      DateTime(now.year, now.month - m, day, 12);

  // Start every test from an empty tx log so only what the test writes is counted.
  Future<void> clearTxs() async =>
      (await db.database).delete('transactions');

  Future<AnalyticsData> load() async {
    c.listen(analyticsProvider, (_, __) {});
    return c.read(analyticsProvider.future);
  }

  Future<void> setSavings(double v) async {
    await db.updateBalance(kSavingsId, v);
    c.read(accountsProvider.notifier).state = await db.getAccounts();
  }

  setUp(() async {
    final env = await seededContainer(savings: 100);
    db = env.db;
    c = env.c;
    await clearTxs();
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  test('no transactions: 6 zero months, flat savings line, empty timeline',
      () async {
    final d = await load();
    expect(d.months.length, 6);
    expect(d.months.every((m) => m.income == 0 && m.expenses == 0), isTrue);
    expect(d.savingsHistory, List.filled(6, 100.0));
    expect(d.currentMonthTimeline, isEmpty);
  });

  test('months are oldest -> current and wrap correctly over year boundaries',
      () async {
    final d = await load();
    for (var k = 0; k < 6; k++) {
      final expected = DateTime(now.year, now.month - (5 - k));
      expect((d.months[k].year, d.months[k].month),
          (expected.year, expected.month));
    }
    expect(d.currentMonth.month, now.month);
  });

  test('income = salary + deposit; expenses = withdraw + bill_paid; the rest is ignored',
      () async {
    final t = monthsAgo(0, day: 1);
    for (final (type, amt) in [
      ('salary', 100.0), ('deposit', 50.0),
      ('withdraw', 30.0), ('bill_paid', 20.0),
      ('transfer_in', 999.0), ('transfer_out', 999.0), ('initial', 999.0),
      ('debt_out', 999.0), ('debt_repaid', 999.0), ('leftover', 999.0),
    ]) {
      await db.insertTransaction(mkTx(kWalletId, type, amt, at: t));
    }
    final m = (await load()).currentMonth;
    expect((m.income, m.expenses, m.net), (150.0, 50.0, 100.0));
  });

  test('a tx lands in its own month; older than 6 months is dropped', () async {
    await db.insertTransaction(mkTx(kWalletId, 'deposit', 10, at: monthsAgo(2)));
    await db.insertTransaction(mkTx(kWalletId, 'deposit', 77, at: monthsAgo(7)));
    final d = await load();
    expect(d.months[3].income, 10);
    expect(d.months.fold<double>(0, (s, m) => s + m.income), 10);
  });

  test('month boundaries: last ms of a month vs first ms of the next', () async {
    final lastMsPrev = DateTime(now.year, now.month, 1).subtract(const Duration(milliseconds: 1));
    final firstMsCur = DateTime(now.year, now.month, 1);
    await db.insertTransaction(mkTx(kWalletId, 'deposit', 1, at: lastMsPrev));
    await db.insertTransaction(mkTx(kWalletId, 'deposit', 2, at: firstMsCur));
    final d = await load();
    expect(d.months[4].income, 1);
    expect(d.months[5].income, 2);
  });

  test('savings history is reconstructed backwards from the live balance',
      () async {
    await setSavings(300);
    await db.insertTransaction(mkTx(kSavingsId, 'deposit', 200, at: monthsAgo(3)));
    await db.insertTransaction(
        mkTx(kSavingsId, 'deposit', 100, at: DateTime(now.year, now.month, 1, 0, 0, 1)));
    final d = await load();
    expect(d.savingsHistory, [0, 0, 200, 200, 200, 300]);
  });

  test('current-month timeline is chronological and ends at the live balance',
      () async {
    await setSavings(270);
    final m0 = DateTime(now.year, now.month, 1, 0, 0, 0);
    // inserted newest-first on purpose
    await db.insertTransaction(mkTx(kSavingsId, 'withdraw', 30, at: m0.add(const Duration(seconds: 2))));
    await db.insertTransaction(mkTx(kSavingsId, 'deposit', 100, at: m0.add(const Duration(seconds: 1))));
    final d = await load();
    expect(d.currentMonthTimeline, [300, 270]);
    expect(d.currentMonthTimeline.last, d.savingsHistory.last);
  });

  test('lending from savings does not distort earlier months of the savings chart',
      () async {
    // seed: initial 100 (this month). Lend 40 -> balance 60.
    await db.insertTransaction(mkTx(kSavingsId, 'initial', 100));
    await c.read(accountsProvider.notifier)
        .lendDebt(kSavingsId, 40, mkTx(kSavingsId, 'debt_out', 40), person: 'Ali');
    final d = await load();
    expect(d.savingsHistory.sublist(0, 5), List.filled(5, 0.0),
        reason: 'nothing happened before this month, got ${d.savingsHistory}');
    expect(d.savingsHistory.last, 60);
  });

  test('receiving a debt back into savings does not distort earlier months',
      () async {
    await db.insertTransaction(mkTx(kSavingsId, 'initial', 100));
    final n = c.read(accountsProvider.notifier);
    await n.lendDebt(kSavingsId, 40, mkTx(kSavingsId, 'debt_out', 40), person: 'Ali');
    await n.repayDebt(kSavingsId, 40, mkTx(kSavingsId, 'debt_repaid', 40), debtId: await debtIdOf(db, kSavingsId));
    final d = await load();
    expect(d.savingsHistory.sublist(0, 5), List.filled(5, 0.0),
        reason: 'got ${d.savingsHistory}');
    expect(d.savingsHistory.last, 100);
  });

  test('a future-dated savings deposit (date picker allows +365d) must not make the chart disagree with the balance',
      () async {
    final n = c.read(accountsProvider.notifier);
    await db.insertTransaction(mkTx(kSavingsId, 'initial', 100));
    await n.deposit(kSavingsId, 50,
        mkTx(kSavingsId, 'deposit', 50, at: now.add(const Duration(days: 40))));
    final live = balanceOf(c, kSavingsId);
    final d = await load();
    expect(d.savingsHistory.last, live,
        reason: 'card shows $live but the chart ends at ${d.savingsHistory.last}');
  });

  test('savings change this month leaves out the starting balance', () async {
    final n = c.read(accountsProvider.notifier);
    await db.insertTransaction(mkTx(kSavingsId, 'initial', 100));
    expect((await load()).savingsChangeThisMonth, 0,
        reason: 'only the seeded balance exists');

    await n.deposit(kSavingsId, 10.25, mkTx(kSavingsId, 'deposit', 10.25));
    expect((await c.read(analyticsProvider.future)).savingsChangeThisMonth, 10.25);

    await n.withdraw(kSavingsId, 4, mkTx(kSavingsId, 'withdraw', 4));
    expect((await c.read(analyticsProvider.future)).savingsChangeThisMonth, 6.25);
  });

  test('savings change this month ignores earlier months and counts transfers',
      () async {
    final n = c.read(accountsProvider.notifier);
    await db.insertTransaction(mkTx(kSavingsId, 'deposit', 500, at: monthsAgo(2)));
    await db.insertTransaction(
        mkTx(kSavingsId, 'deposit', 7, at: DateTime(now.year, now.month, 1, 0, 0, 1)));
    await n.transfer(
      fromId: kWalletId,
      toId: kSavingsId,
      amount: 30,
      txOut: mkTx(kWalletId, 'transfer_out', 30),
      txIn: mkTx(kSavingsId, 'transfer_in', 30),
    );
    expect((await load()).savingsChangeThisMonth, 37);
  });

  test('category spending: withdrawals and paid bills of this month, by category',
      () async {
    final n = c.read(accountsProvider.notifier);
    await n.withdraw(kWalletId, 10, mkTx(kWalletId, 'withdraw', 10, category: 'Food'));
    await n.withdraw(kWalletId, 5.5, mkTx(kWalletId, 'withdraw', 5.5, category: 'Food'));
    await n.withdraw(kWalletId, 20, mkTx(kWalletId, 'bill_paid', 20, category: 'Housing'));
    await n.withdraw(kWalletId, 3, mkTx(kWalletId, 'withdraw', 3)); // none
    await n.withdraw(kSavingsId, 4, mkTx(kSavingsId, 'withdraw', 4, category: 'Health'));
    expect((await load()).categorySpendingThisMonth,
        {'Food': 15.5, 'Housing': 20.0, 'Other': 3.0, 'Health': 4.0});
  });

  test('category spending ignores income, transfers, debts and earlier months',
      () async {
    final n = c.read(accountsProvider.notifier);
    await n.deposit(kWalletId, 50, mkTx(kWalletId, 'deposit', 50, category: 'Food'));
    await n.lendDebt(kWalletId, 5, mkTx(kWalletId, 'debt_out', 5, category: 'Food'), person: 'Ali');
    await db.insertTransaction(
        mkTx(kWalletId, 'withdraw', 99, category: 'Food', at: monthsAgo(1)));
    expect((await load()).categorySpendingThisMonth, isEmpty);
  });

  test('a category name nobody knows counts as Other', () async {
    await db.insertTransaction(mkTx(kWalletId, 'withdraw', 7, category: 'Crypto'));
    expect((await load()).categorySpendingThisMonth, {'Other': 7.0});
  });

  test('analytics recompute after a new transaction', () async {
    final before = (await load()).currentMonth.income;
    await c.read(accountsProvider.notifier)
        .deposit(kWalletId, 25, mkTx(kWalletId, 'deposit', 25));
    final after = (await c.read(analyticsProvider.future)).currentMonth.income;
    expect(after, before + 25);
  });

  test('5,000 transactions are processed quickly', () async {
    final raw = await db.database;
    final batch = raw.batch();
    for (var i = 0; i < 5000; i++) {
      batch.insert('transactions', mkTx(i.isEven ? kSavingsId : kWalletId,
          i % 3 == 0 ? 'deposit' : 'withdraw', 1, at: monthsAgo(i % 6)).toMap());
    }
    await batch.commit(noResult: true);
    final sw = Stopwatch()..start();
    final d = await load();
    sw.stop();
    expect(d.months.length, 6);
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });
}
