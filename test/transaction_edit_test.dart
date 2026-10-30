import 'dart:convert';

import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/analytics_model.dart';
import 'package:financeapp/models/transaction_model.dart';
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

  setUp(() async {
    // wallet 600, budget 400, savings 100
    final env = await seededContainer();
    db = env.db;
    c = env.c;
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  AccountsNotifier n() => c.read(accountsProvider.notifier);

  Future<int> idOf(String title, {int account = kWalletId}) async =>
      (await db.getTransactions(account)).firstWhere((t) => t.title == title).id;

  Future<TransactionModel?> row(int id) async {
    final all = await db.getAllTransactions();
    return all.where((t) => t.id == id).firstOrNull;
  }

  /// Every account and transaction as stored, to prove a call changed nothing.
  Future<String> snapshot() async => jsonEncode([
        for (final a in await db.getAccounts()) a.toMap(),
        for (final t in await db.getAllTransactions()) {...t.toMap(), 'id': t.id},
      ]);

  Future<int> deposit(int account, double amount, String title) async {
    await n().deposit(account, amount, mkTx(account, 'deposit', amount, title: title));
    return idOf(title, account: account);
  }

  Future<int> withdraw(int account, double amount, String title) async {
    await n().withdraw(account, amount, mkTx(account, 'withdraw', amount, title: title));
    return idOf(title, account: account);
  }

  group('editing a deposit', () {
    test('a bigger amount raises the balance by the difference', () async {
      final id = await deposit(kWalletId, 50, 'Bonus'); // 650
      expect(await n().updateTransaction(id, amount: 80, title: 'Bonus', note: ''), isTrue);
      expect(balanceOf(c, kWalletId), 680);
      expect((await row(id))!.amount, 80);
      await expectStateMatchesDb(c, db);
    });

    test('a smaller amount lowers the balance by the difference', () async {
      final id = await deposit(kWalletId, 50, 'Bonus');
      expect(await n().updateTransaction(id, amount: 20, title: 'Bonus', note: ''), isTrue);
      expect(balanceOf(c, kWalletId), 620);
      await expectStateMatchesDb(c, db);
    });

    test('title and note change without touching the balance', () async {
      final id = await deposit(kWalletId, 50, 'Bonus');
      expect(await n().updateTransaction(id, amount: 50, title: 'Gift', note: 'from Sam'), isTrue);
      expect(balanceOf(c, kWalletId), 650);
      final r = (await row(id))!;
      expect((r.title, r.note, r.amount), ('Gift', 'from Sam', 50.0));
    });

    test('lowering it below what is left in the account is refused, nothing changes', () async {
      final id = await deposit(kWalletId, 50, 'Bonus'); // 650
      await withdraw(kWalletId, 640, 'Big spend'); // 10 left
      final before = await snapshot();
      expect(await n().updateTransaction(id, amount: 10, title: 'Bonus', note: ''), isFalse,
          reason: 'would need 40 back out of a balance of 10');
      expect(await snapshot(), before);
      expect(balanceOf(c, kWalletId), 10);
    });

    test('date and kind are kept', () async {
      final at = DateTime(2024, 3, 9, 14, 30);
      await n().deposit(kWalletId, 5, mkTx(kWalletId, 'deposit', 5, title: 'Old', at: at));
      final id = await idOf('Old');
      await n().updateTransaction(id, amount: 6, title: 'Old', note: '');
      final r = (await row(id))!;
      expect((r.createdAt, r.type, r.accountId), (at, 'deposit', kWalletId));
    });
  });

  group('editing a withdrawal', () {
    test('a bigger amount lowers the balance by the difference', () async {
      final id = await withdraw(kWalletId, 30, 'Groceries'); // 570
      expect(await n().updateTransaction(id, amount: 45, title: 'Groceries', note: ''), isTrue);
      expect(balanceOf(c, kWalletId), 555);
      await expectStateMatchesDb(c, db);
    });

    test('a smaller amount gives the difference back', () async {
      final id = await withdraw(kWalletId, 30, 'Groceries');
      expect(await n().updateTransaction(id, amount: 10, title: 'Groceries', note: ''), isTrue);
      expect(balanceOf(c, kWalletId), 590);
    });

    test('raising it beyond the balance is refused, nothing changes', () async {
      final id = await withdraw(kWalletId, 30, 'Groceries'); // 570 left
      final before = await snapshot();
      expect(await n().updateTransaction(id, amount: 631, title: 'Groceries', note: ''), isFalse);
      expect(await snapshot(), before);
    });

    test('raising it to exactly the money available is allowed', () async {
      final id = await withdraw(kWalletId, 30, 'Groceries'); // 570 left
      expect(await n().updateTransaction(id, amount: 600, title: 'Groceries', note: ''), isTrue);
      expect(balanceOf(c, kWalletId), 0);
    });
  });

  group('deleting', () {
    test('a withdrawal returns the money', () async {
      final id = await withdraw(kWalletId, 30, 'Groceries');
      expect(await n().deleteTransaction(id), isTrue);
      expect(balanceOf(c, kWalletId), 600);
      expect(await row(id), isNull);
      await expectStateMatchesDb(c, db);
    });

    test('a deposit takes the money back out', () async {
      final id = await deposit(kWalletId, 50, 'Bonus');
      expect(await n().deleteTransaction(id), isTrue);
      expect(balanceOf(c, kWalletId), 600);
      expect(await row(id), isNull);
    });

    test('a deposit that was already spent cannot be deleted, nothing changes', () async {
      final id = await deposit(kWalletId, 50, 'Bonus');
      await withdraw(kWalletId, 640, 'Big spend'); // 10 left
      final before = await snapshot();
      expect(await n().deleteTransaction(id), isFalse);
      expect(await snapshot(), before);
    });

    test('a second delete of the same row does not reverse it twice', () async {
      // The History page holds a copy loaded earlier; a double tap must be harmless.
      final id = await withdraw(kWalletId, 30, 'Groceries');
      expect(await n().deleteTransaction(id), isTrue);
      expect(await n().deleteTransaction(id), isFalse);
      expect(balanceOf(c, kWalletId), 600);
    });

    test('an unknown id is a no-op', () async {
      final before = await snapshot();
      expect(await n().deleteTransaction(99999), isFalse);
      expect(await n().updateTransaction(99999, amount: 5, title: 't', note: ''), isFalse);
      expect(await snapshot(), before);
    });

    test('works on a custom account and leaves its debt alone', () async {
      final acc = await n().addCustomAccount('Trip', 0, 0);
      await deposit(acc.id, 100, 'Seed');
      await n().lendDebt(acc.id, 30, mkTx(acc.id, 'debt_out', 30, title: 'Lent'));
      final id = await withdraw(acc.id, 20, 'Hotel'); // 50 available, 30 lent
      expect(await n().deleteTransaction(id), isTrue);
      final a = c.read(accountsProvider).firstWhere((x) => x.id == acc.id);
      expect((a.balance, a.loanedAmount), (70.0, 30.0));
      await expectStateMatchesDb(c, db);
    });

    test('a float rounding hair below zero is not treated as "balance too low"', () async {
      final acc = await n().addCustomAccount('Float', 0, 0);
      final big = await deposit(acc.id, 0.7, 'a');
      final small = await deposit(acc.id, 0.1, 'b'); // 0.7999999999999999
      expect(await n().deleteTransaction(big), isTrue);
      expect(await n().deleteTransaction(small), isTrue,
          reason: '0.09999999999999987 - 0.1 is -1.4e-16');
      expect(balanceOf(c, acc.id), 0);
    });
  });

  group('rows that are not a plain deposit/withdraw are left alone', () {
    Future<void> expectUntouchable(int id) async {
      final before = await snapshot();
      expect(await n().deleteTransaction(id), isFalse, reason: 'delete');
      expect(await n().updateTransaction(id, amount: 1, title: 'x', note: 'y'), isFalse,
          reason: 'update');
      expect(await snapshot(), before);
    }

    test('transfers (two linked rows)', () async {
      await n().transfer(
        fromId: kWalletId,
        toId: kSavingsId,
        amount: 50,
        txOut: mkTx(kWalletId, 'transfer_out', 50, title: 'Move out', related: kSavingsId),
        txIn: mkTx(kSavingsId, 'transfer_in', 50, title: 'Move in', related: kWalletId),
      );
      await expectUntouchable(await idOf('Move out'));
      await expectUntouchable(await idOf('Move in', account: kSavingsId));
    });

    test('bill payments', () async {
      await db.insertTransaction(mkTx(kWalletId, 'bill_paid', 20, title: 'Rent'));
      await expectUntouchable(await idOf('Rent'));
    });

    test('salary and the starting balance', () async {
      await expectUntouchable(await idOf('Salary'));
      await expectUntouchable(await idOf('Initial Savings', account: kSavingsId));
    });

    test('debts', () async {
      await n().lendDebt(kWalletId, 40, mkTx(kWalletId, 'debt_out', 40, title: 'Lent'));
      await expectUntouchable(await idOf('Lent'));
      await n().repayDebt(kWalletId, 10, mkTx(kWalletId, 'debt_repaid', 10, title: 'Paid back'));
      await expectUntouchable(await idOf('Paid back'));
    });
  });

  group('bad amounts', () {
    for (final bad in [0.0, -5.0, double.nan, double.infinity]) {
      test('$bad is refused, nothing changes', () async {
        final id = await withdraw(kWalletId, 30, 'Groceries');
        final before = await snapshot();
        expect(await n().updateTransaction(id, amount: bad, title: 'x', note: ''), isFalse);
        expect(await snapshot(), before);
      });
    }
  });

  group('analytics follow the correction', () {
    Future<AnalyticsData> analytics() async {
      c.listen(analyticsProvider, (_, __) {});
      return c.read(analyticsProvider.future);
    }

    test('deleting a savings deposit brings the chart back to the live balance', () async {
      final id = await deposit(kSavingsId, 40, 'Bonus'); // 100 seeded + 40
      expect((await analytics()).savingsHistory.last, 140);

      expect(await n().deleteTransaction(id), isTrue);
      final d = await c.read(analyticsProvider.future);
      expect(balanceOf(c, kSavingsId), 100);
      expect(d.savingsHistory.last, 100);
      expect(d.currentMonthTimeline.last, 100);
    });

    test('editing an expense changes this month\'s expenses', () async {
      final id = await withdraw(kWalletId, 30, 'Groceries');
      expect((await analytics()).currentMonth.expenses, 30);
      await n().updateTransaction(id, amount: 45, title: 'Groceries', note: '');
      expect((await c.read(analyticsProvider.future)).currentMonth.expenses, 45);
    });
  });

  test('account list keeps its order and kinds after a reload', () async {
    final id = await withdraw(kWalletId, 30, 'Groceries');
    final before = c.read(accountsProvider).map((a) => (a.id, a.type)).toList();
    await n().deleteTransaction(id);
    expect(c.read(accountsProvider).map((a) => (a.id, a.type)).toList(), before);
    expect(before.first, (kWalletId, AccountType.wallet));
  });
}
