import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_env.dart';

void main() {
  setUpAll(setUpTestEnv);
  tearDownAll(tearDownTestEnv);

  // wallet 600 / budget 400 / savings 100
  late AppDatabase db;
  late ProviderContainer c;
  late AccountsNotifier n;

  setUp(() async {
    final env = await seededContainer();
    db = env.db;
    c = env.c;
    n = c.read(accountsProvider.notifier);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<void> consistent() => expectStateMatchesDb(c, db);

  group('deposit / withdraw', () {
    test('deposit raises state + DB and logs a tx', () async {
      await n.deposit(kWalletId, 50, mkTx(kWalletId, 'deposit', 50));
      expect(balanceOf(c, kWalletId), 650);
      await consistent();
      final txs = await db.getTransactions(kWalletId);
      expect(txs.where((t) => t.type == 'deposit').length, 1);
    });

    test('withdraw succeeds, can drain to exactly zero', () async {
      expect(await n.withdraw(kWalletId, 600, mkTx(kWalletId, 'withdraw', 600)), isTrue);
      expect(balanceOf(c, kWalletId), 0);
      await consistent();
    });

    test('withdraw with insufficient funds changes nothing', () async {
      final before = (await db.getAllTransactions()).length;
      expect(await n.withdraw(kWalletId, 600.01, mkTx(kWalletId, 'withdraw', 600.01)), isFalse);
      expect(balanceOf(c, kWalletId), 600);
      expect((await db.getAllTransactions()).length, before);
      await consistent();
    });

    test('floating point: 10 x withdraw 0.1 from 1.0 ends at ~0 and never rejects',
        () async {
      await db.updateBalance(kSavingsId, 1.0);
      n.state = await db.getAccounts();
      for (var i = 0; i < 10; i++) {
        final ok = await n.withdraw(kSavingsId, 0.1, mkTx(kSavingsId, 'withdraw', 0.1));
        expect(ok, isTrue, reason: 'rejected withdrawal #${i + 1}');
      }
      expect(balanceOf(c, kSavingsId).abs(), lessThan(1e-9));
    });

    test('deposit/withdraw of a negative amount is rejected', () async {
      await n.withdraw(kWalletId, -50, mkTx(kWalletId, 'withdraw', -50));
      await n.deposit(kWalletId, -50, mkTx(kWalletId, 'deposit', -50));
      expect(balanceOf(c, kWalletId), 600,
          reason: 'negative amounts moved the balance');
    });

    test('zero amount is rejected', () async {
      final before = (await db.getAllTransactions()).length;
      await n.deposit(kWalletId, 0, mkTx(kWalletId, 'deposit', 0));
      expect((await db.getAllTransactions()).length, before,
          reason: 'a 0 deposit was written to history');
    });

    test('operating on an unknown account id fails loudly and writes nothing',
        () async {
      final before = (await db.getAllTransactions()).length;
      await expectLater(n.deposit(999, 5, mkTx(999, 'deposit', 5)), throwsA(anything));
      expect((await db.getAllTransactions()).length, before);
    });
  });

  group('transfer', () {
    TransactionModelPair pair(int from, int to, double amt) =>
        TransactionModelPair(
            mkTx(from, 'transfer_out', amt, related: to),
            mkTx(to, 'transfer_in', amt, related: from));

    test('moves money, conserves total, logs both sides', () async {
      final t = pair(kWalletId, kSavingsId, 250);
      expect(await n.transfer(fromId: kWalletId, toId: kSavingsId, amount: 250, txOut: t.out, txIn: t.inn), isTrue);
      expect(balanceOf(c, kWalletId), 350);
      expect(balanceOf(c, kSavingsId), 350);
      await consistent();
      final all = await db.getAllTransactions();
      expect(all.where((x) => x.type == 'transfer_out').length, 1);
      expect(all.where((x) => x.type == 'transfer_in').length, 1);
    });

    test('insufficient funds -> false, nothing written', () async {
      final before = (await db.getAllTransactions()).length;
      final t = pair(kSavingsId, kWalletId, 100.01);
      expect(await n.transfer(fromId: kSavingsId, toId: kWalletId, amount: 100.01, txOut: t.out, txIn: t.inn), isFalse);
      expect((await db.getAllTransactions()).length, before);
      await consistent();
    });

    test('transfer to the same account must not touch balances', () async {
      final t = pair(kWalletId, kWalletId, 100);
      await n.transfer(fromId: kWalletId, toId: kWalletId, amount: 100, txOut: t.out, txIn: t.inn);
      expect(balanceOf(c, kWalletId), 600);
    });

    test('transfer to the same account keeps memory and DB in sync', () async {
      final t = pair(kWalletId, kWalletId, 100);
      await n.transfer(fromId: kWalletId, toId: kWalletId, amount: 100, txOut: t.out, txIn: t.inn);
      await consistent();
    });

    test('negative transfer amount is rejected (otherwise it pulls money backwards)',
        () async {
      final t = pair(kWalletId, kSavingsId, -100);
      await n.transfer(fromId: kWalletId, toId: kSavingsId, amount: -100, txOut: t.out, txIn: t.inn);
      expect(balanceOf(c, kSavingsId), 100);
      expect(balanceOf(c, kWalletId), 600);
    });

    test('transfer is atomic: if the 2nd tx insert fails, balances roll back',
        () async {
      // Force a failure on the credit-side tx insert by violating NOT NULL on `type`.
      final raw = await db.database;
      await raw.execute('CREATE TRIGGER boom BEFORE INSERT ON transactions '
          "WHEN NEW.type = 'transfer_in' BEGIN SELECT RAISE(ABORT, 'boom'); END");
      final t = pair(kWalletId, kSavingsId, 100);
      await expectLater(
          n.transfer(fromId: kWalletId, toId: kSavingsId, amount: 100, txOut: t.out, txIn: t.inn),
          throwsA(anything));
      final disk = {for (final a in await db.getAccounts()) a.id: a.balance};
      expect(disk[kWalletId], 600, reason: 'wallet debited in DB although transfer failed');
      expect(disk[kSavingsId], 100);
      expect((await db.getAllTransactions()).where((x) => x.type == 'transfer_out'), isEmpty,
          reason: 'half of the transfer was logged');
    });

    test('many sequential transfers keep the total constant', () async {
      for (var i = 0; i < 20; i++) {
        final from = i.isEven ? kWalletId : kSavingsId;
        final to = i.isEven ? kSavingsId : kWalletId;
        final t = pair(from, to, 7.77);
        await n.transfer(fromId: from, toId: to, amount: 7.77, txOut: t.out, txIn: t.inn);
      }
      final total = c.read(accountsProvider).fold<double>(0, (s, a) => s + a.balance);
      expect(total, closeTo(1100, 1e-9));
      await consistent();
    });
  });

  group('debt (lend / repay)', () {
    test('lend moves available -> loaned, total unchanged', () async {
      expect(await n.lendDebt(kWalletId, 200, mkTx(kWalletId, 'debt_out', 200)), isTrue);
      final w = c.read(accountsProvider).firstWhere((a) => a.id == kWalletId);
      expect((w.balance, w.loanedAmount, w.totalBalance), (400.0, 200.0, 600.0));
      await consistent();
    });

    test('lend more than available -> false, nothing changes', () async {
      expect(await n.lendDebt(kWalletId, 601, mkTx(kWalletId, 'debt_out', 601)), isFalse);
      expect(balanceOf(c, kWalletId), 600);
      await consistent();
    });

    test('partial and full repayment', () async {
      await n.lendDebt(kWalletId, 200, mkTx(kWalletId, 'debt_out', 200));
      expect(await n.repayDebt(kWalletId, 50, mkTx(kWalletId, 'debt_repaid', 50)), isTrue);
      var w = c.read(accountsProvider).firstWhere((a) => a.id == kWalletId);
      expect((w.balance, w.loanedAmount), (450.0, 150.0));
      await n.repayDebt(kWalletId, 150, mkTx(kWalletId, 'debt_repaid', 150));
      w = c.read(accountsProvider).firstWhere((a) => a.id == kWalletId);
      expect((w.balance, w.loanedAmount), (600.0, 0.0));
      await consistent();
    });

    test('repay with no outstanding debt -> false', () async {
      expect(await n.repayDebt(kWalletId, 10, mkTx(kWalletId, 'debt_repaid', 10)), isFalse);
    });

    test('over-repayment is clamped AND the logged tx amount matches what was applied',
        () async {
      await n.lendDebt(kWalletId, 30, mkTx(kWalletId, 'debt_out', 30));
      await n.repayDebt(kWalletId, 80, mkTx(kWalletId, 'debt_repaid', 80));
      expect(balanceOf(c, kWalletId), 600);
      final rep = (await db.getTransactions(kWalletId)).firstWhere((t) => t.type == 'debt_repaid');
      expect(rep.amount, 30, reason: 'history says 80 was repaid but only 30 was owed');
    });

    test('negative lend amount is rejected', () async {
      await n.lendDebt(kWalletId, -100, mkTx(kWalletId, 'debt_out', -100));
      final w = c.read(accountsProvider).firstWhere((a) => a.id == kWalletId);
      expect((w.balance, w.loanedAmount), (600.0, 0.0));
    });

    test('debt is isolated per account', () async {
      await n.lendDebt(kSavingsId, 40, mkTx(kSavingsId, 'debt_out', 40));
      expect(c.read(accountsProvider).firstWhere((a) => a.id == kWalletId).loanedAmount, 0);
    });
  });

  group('custom accounts', () {
    test('add -> in state, in DB, balance 0, id > 3', () async {
      final a = await n.addCustomAccount('Trip', 1, 0xe318);
      expect(a.id, greaterThan(kSavingsId));
      expect(c.read(accountsProvider).any((x) => x.id == a.id), isTrue);
      await consistent();
    });

    test('editing an account keeps its balance AND its outstanding loan',
        () async {
      final a = await n.addCustomAccount('Trip', 1, 0xe318);
      await n.deposit(a.id, 300, mkTx(a.id, 'deposit', 300));
      await n.lendDebt(a.id, 100, mkTx(a.id, 'debt_out', 100));
      await n.updateCustomAccount(a.id, 'Trip 2', 2, 0xe319);
      final after = c.read(accountsProvider).firstWhere((x) => x.id == a.id);
      expect(after.customName, 'Trip 2');
      expect(after.balance, 200);
      expect(after.loanedAmount, 100,
          reason: 'edit dropped the loan from in-memory state');
      await consistent();
    });

    test('lending after an edit does not overwrite the old loan in the DB',
        () async {
      final a = await n.addCustomAccount('Trip', 1, 0xe318);
      await n.deposit(a.id, 300, mkTx(a.id, 'deposit', 300));
      await n.lendDebt(a.id, 100, mkTx(a.id, 'debt_out', 100));
      await n.updateCustomAccount(a.id, 'Renamed', 1, 1); // user just renames
      await n.lendDebt(a.id, 50, mkTx(a.id, 'debt_out', 50));
      final disk = (await db.getAccounts()).firstWhere((x) => x.id == a.id);
      expect(disk.loanedAmount, 150, reason: 'persisted loan shrank from 100+50 to ${disk.loanedAmount}');
    });

    test('delete without sweep drops account + its txs', () async {
      final a = await n.addCustomAccount('Tmp', 0, 1);
      await n.deposit(a.id, 10, mkTx(a.id, 'deposit', 10));
      await n.deleteCustomAccount(a.id);
      expect(c.read(accountsProvider).any((x) => x.id == a.id), isFalse);
      expect(await db.getTransactions(a.id), isEmpty);
      expect(balanceOf(c, kWalletId), 600);
      await consistent();
    });

    test('delete with sweep moves the balance into the wallet and logs it',
        () async {
      final a = await n.addCustomAccount('Tmp', 0, 1);
      await n.deposit(a.id, 75, mkTx(a.id, 'deposit', 75));
      await n.deleteCustomAccount(a.id, transferToWallet: true);
      expect(balanceOf(c, kWalletId), 675);
      expect((await db.getTransactions(kWalletId)).any((t) => t.type == 'transfer_in' && t.amount == 75), isTrue);
      await consistent();
    });

    test('delete with sweep and zero balance does not log a 0 transfer', () async {
      final a = await n.addCustomAccount('Tmp', 0, 1);
      await n.deleteCustomAccount(a.id, transferToWallet: true);
      expect((await db.getTransactions(kWalletId)).where((t) => t.type == 'transfer_in'), isEmpty);
    });

    test('deleting an account that still has money lent out is refused or sweeps it',
        () async {
      final a = await n.addCustomAccount('Tmp', 0, 1);
      await n.deposit(a.id, 100, mkTx(a.id, 'deposit', 100));
      await n.lendDebt(a.id, 100, mkTx(a.id, 'debt_out', 100)); // balance 0, loaned 100
      Object? err;
      try {
        await n.deleteCustomAccount(a.id);
      } catch (e) {
        err = e;
      }
      final stillThere = c.read(accountsProvider).any((x) => x.id == a.id);
      expect(err != null || stillThere, isTrue,
          reason: '100 lent to someone silently vanished with the account');
    });

    test('deleteCustomAccount refuses built-in accounts', () async {
      Object? err;
      try {
        await n.deleteCustomAccount(kWalletId);
      } catch (e) {
        err = e;
      }
      expect(err != null || c.read(accountsProvider).any((a) => a.id == kWalletId), isTrue,
          reason: 'the Wallet was deleted');
    });
  });

  group('salary day (notifier)', () {
    test('updates state and DB together', () async {
      await n.withdraw(kBudgetId, 150, mkTx(kBudgetId, 'withdraw', 150));
      await n.processSalaryDay(1000, 400);
      expect(balanceOf(c, kWalletId), 600 + 250 + 600);
      expect(balanceOf(c, kBudgetId), 400);
      expect(balanceOf(c, kSavingsId), 100);
      await consistent();
    });

    test('does not touch loaned amounts or custom accounts', () async {
      final a = await n.addCustomAccount('Keep', 0, 1);
      await n.deposit(a.id, 5, mkTx(a.id, 'deposit', 5));
      await n.lendDebt(kWalletId, 100, mkTx(kWalletId, 'debt_out', 100));
      await n.processSalaryDay(1000, 400);
      expect(balanceOf(c, a.id), 5);
      expect(c.read(accountsProvider).firstWhere((x) => x.id == kWalletId).loanedAmount, 100);
      await consistent();
    });
  });

  test('wallet/budget/savings getters', () {
    expect(n.wallet.id, kWalletId);
    expect(n.budget.id, kBudgetId);
    expect(n.savings.id, kSavingsId);
  });
}

class TransactionModelPair {
  final TransactionModel out;
  final TransactionModel inn;
  TransactionModelPair(this.out, this.inn);
}
