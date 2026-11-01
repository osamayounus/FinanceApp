import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/expense_model.dart';
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
  late BillsNotifier bills;

  setUp(() async {
    final env = await seededContainer();
    db = env.db;
    c = env.c;
    bills = c.read(expensesProvider.notifier);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  List<ExpenseModel> mem() => c.read(expensesProvider);

  Future<void> memMatchesDb() async {
    final disk = await db.getBills();
    expect(mem().map((b) => (b.id, b.name, b.amount, b.isPaid, b.category)),
        disk.map((b) => (b.id, b.name, b.amount, b.isPaid, b.category)));
  }

  test('add assigns the DB id and keeps order', () async {
    await bills.add('Rent', 300, 'home');
    await bills.add('Net', 20.5, 'utilities');
    expect(mem().map((b) => b.name), ['Rent', 'Net']);
    expect(mem()[0].id, isNot(mem()[1].id));
    await memMatchesDb();
  });

  test('edit changes the right bill, keeps its paid flag', () async {
    await bills.add('A', 1, '');
    await bills.add('B', 2, '');
    await bills.markPaid(1);
    await bills.edit(1, 'B2', 22, 'x');
    expect(mem()[0].name, 'A');
    expect((mem()[1].name, mem()[1].amount, mem()[1].isPaid), ('B2', 22.0, true));
    await memMatchesDb();
  });

  test('delete removes only that bill', () async {
    await bills.add('A', 1, '');
    await bills.add('B', 2, '');
    await bills.add('C', 3, '');
    await bills.delete(1);
    expect(mem().map((b) => b.name), ['A', 'C']);
    await memMatchesDb();
  });

  test('markPaid is idempotent', () async {
    await bills.add('A', 1, '');
    await bills.markPaid(0);
    await bills.markPaid(0);
    expect(mem().single.isPaid, isTrue);
    await memMatchesDb();
  });

  group('auto-pay', () {
    final today = DateTime.now();
    final inThreeDays = today.add(const Duration(days: 3)).day;

    test('add and edit keep the flag; without a due day it is off; paying and resetting keep it',
        () async {
      await bills.add('A', 1, '', dueDay: 5, autoPay: true);
      await bills.add('B', 1, '', autoPay: true);
      expect(mem().map((b) => b.autoPay), [true, false]);
      await bills.edit(0, 'A', 1, '', dueDay: 6, autoPay: true);
      expect(mem()[0].autoPay, isTrue);
      await bills.markPaid(0);
      await bills.resetAll();
      expect(mem()[0].autoPay, isTrue);
      await bills.edit(0, 'A', 1, '', autoPay: true); // due day taken off
      expect(mem()[0].autoPay, isFalse);
      expect((await db.getBills()).map((b) => b.autoPay), mem().map((b) => b.autoPay));
    });

    test('payDue charges the wallet once, marks only the due auto-pay bill paid, returns it',
        () async {
      await bills.add('Rent', 100, 'Housing', dueDay: today.day, autoPay: true);
      await bills.add('Later', 50, '', dueDay: inThreeDays, autoPay: true);
      await bills.add('Manual', 10, '', dueDay: today.day);

      final paid = await bills.payDue();

      expect(paid.map((b) => b.name), ['Rent']);
      expect(mem().map((b) => b.isPaid), [true, false, false]);
      expect(balanceOf(c, kWalletId), 500);
      await memMatchesDb();
      await expectStateMatchesDb(c, db);
      expect(await bills.payDue(), isEmpty);
      expect(balanceOf(c, kWalletId), 500);
    });

    test('payDue with a wallet that is too small pays nothing and keeps the bill unpaid', () async {
      await bills.add('Big', 700, '', dueDay: today.day, autoPay: true);
      expect(await bills.payDue(), isEmpty);
      expect(mem().single.isPaid, isFalse);
      expect(balanceOf(c, kWalletId), 600);
      await expectStateMatchesDb(c, db);
    });

    test('payDue on a day the bill is due later pays it then (now can be passed)', () async {
      await bills.add('Later', 50, '', dueDay: inThreeDays, autoPay: true);
      expect(await bills.payDue(), isEmpty);
      final paid = await bills.payDue(DateTime(today.year, today.month, today.day + 3));
      expect(paid.map((b) => b.name), ['Later']);
      expect(balanceOf(c, kWalletId), 550);
    });
  });

  test('out-of-range index does not corrupt state or DB', () async {
    await bills.add('A', 1, '');
    await expectLater(bills.delete(5), throwsA(anything));
    await expectLater(bills.edit(5, 'x', 1, ''), throwsA(anything));
    await memMatchesDb();
  });

  test('resetAll() clears paid flags in state and in the DB', () async {
    await bills.add('A', 1, '');
    await bills.markPaid(0);
    await bills.resetAll();
    expect(mem().single.isPaid, isFalse);
    expect((await db.getBills()).single.isPaid, isFalse,
        reason: 'after an app restart the bill would be "paid" again');
  });

  test('salary day flow (as SalaryDayPage does it) resets bills in state and DB',
      () async {
    await bills.add('A', 1, '');
    await bills.markPaid(0);
    await c.read(accountsProvider.notifier).processSalaryDay(1000, 400);
    await bills.resetAll();
    expect(mem().single.isPaid, isFalse);
    expect((await db.getBills()).single.isPaid, isFalse);
  });

  group('paying a bill (FixedExpensesPage flow: withdraw from wallet + markPaid)',
      () {
    Future<bool> pay(int index) async {
      final b = mem()[index];
      final ok = await c.read(accountsProvider.notifier).withdraw(
          kWalletId, b.amount, mkTx(kWalletId, 'bill_paid', b.amount, title: b.name));
      if (ok) await bills.markPaid(index);
      return ok;
    }

    test('success: wallet debited, bill paid, bill_paid tx logged', () async {
      await bills.add('Rent', 250, '');
      expect(await pay(0), isTrue);
      expect(balanceOf(c, kWalletId), 350);
      expect(mem().single.isPaid, isTrue);
      expect((await db.getTransactions(kWalletId)).where((t) => t.type == 'bill_paid').length, 1);
    });

    test('wallet too low: nothing is debited and the bill stays unpaid', () async {
      await bills.add('Big', 601, '');
      expect(await pay(0), isFalse);
      expect(balanceOf(c, kWalletId), 600);
      expect(mem().single.isPaid, isFalse);
    });

  });
}
