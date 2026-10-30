import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/models/user_model.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountModel', () {
    test('toMap/fromMap round trip keeps every field', () {
      const a = AccountModel(
          id: 7,
          type: AccountType.custom,
          balance: 12.5,
          loanedAmount: 3,
          customName: 'Trip',
          colorIndex: 2,
          iconCode: 0xe318);
      final b = AccountModel.fromMap(a.toMap());
      expect(b.id, 7);
      expect(b.type, AccountType.custom);
      expect(b.balance, 12.5);
      expect(b.loanedAmount, 3);
      expect(b.customName, 'Trip');
      expect(b.colorIndex, 2);
      expect(b.iconCode, 0xe318);
    });

    test('fromMap tolerates int balances and null loaned_amount (old rows)', () {
      final a = AccountModel.fromMap(
          {'id': 1, 'type': 'wallet', 'balance': 5, 'loaned_amount': null});
      expect(a.balance, 5.0);
      expect(a.loanedAmount, 0.0);
    });

    test('totalBalance = available + lent out', () {
      const a = AccountModel(
          id: 1, type: AccountType.wallet, balance: 70, loanedAmount: 30);
      expect(a.totalBalance, 100);
    });

    test('displayName: built-ins use the type name, custom uses its own', () {
      expect(const AccountModel(id: 1, type: AccountType.wallet, balance: 0).displayName, 'Wallet');
      expect(const AccountModel(id: 9, type: AccountType.custom, balance: 0, customName: 'X').displayName, 'X');
      expect(const AccountModel(id: 9, type: AccountType.custom, balance: 0).displayName, 'Account');
    });

    test('AccountType key round trip for all values', () {
      for (final t in AccountType.values) {
        expect(AccountTypeExt.fromKey(t.key), t);
      }
    });

    test('copyWith keeps untouched fields', () {
      const a = AccountModel(
          id: 3, type: AccountType.savings, balance: 1, loanedAmount: 2);
      final b = a.copyWith(balance: 9);
      expect(b.balance, 9);
      expect(b.loanedAmount, 2);
      expect(b.id, 3);
    });
  });

  group('TransactionModel', () {
    test('round trip; toMap has no id (AUTOINCREMENT)', () {
      final t = TransactionModel(
          id: 5,
          accountId: 2,
          type: 'deposit',
          amount: 10.25,
          title: 'x',
          note: 'n',
          relatedAccountId: 3,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000));
      final m = t.toMap();
      expect(m.containsKey('id'), isFalse);
      final back = TransactionModel.fromMap({...m, 'id': 5});
      expect(back.amount, 10.25);
      expect(back.relatedAccountId, 3);
      expect(back.createdAt.millisecondsSinceEpoch, 1700000000000);
    });

    test('fromMap null title/note become empty strings', () {
      final t = TransactionModel.fromMap({
        'id': 1, 'account_id': 1, 'type': 'x', 'amount': 1,
        'title': null, 'note': null, 'related_account_id': null, 'created_at': 0,
      });
      expect(t.title, '');
      expect(t.note, '');
    });
  });

  group('UserModel', () {
    test('currency defaults to JOD and survives round trip', () {
      expect(UserModel.fromMap({'id': 1, 'name': 'a', 'salary': 1, 'monthly_budget': 1}).currency, 'JOD');
      const u = UserModel(id: 1, name: 'a', salary: 1, monthlyBudget: 1, currency: 'USD');
      expect(UserModel.fromMap(u.toMap()).currency, 'USD');
    });
  });

  group('fmtAmt', () {
    test('whole numbers have no decimals', () {
      expect(fmtAmt(5, 'JOD'), '5 JOD');
      expect(fmtAmt(5.0, 'USD'), '5 USD');
      expect(fmtAmt(0, 'JOD'), '0 JOD');
      expect(fmtAmt(-3, 'JOD'), '-3 JOD');
    });

    test('fractions get the currency\'s own precision (2 decimals for USD)', () {
      expect(fmtAmt(5.5, 'JOD'), '5.50 JOD');
      expect(fmtAmt(0.999, 'JOD'), '0.999 JOD');
      expect(fmtAmt(0.999, 'USD'), '1.00 USD');
    });

    test('NaN / Infinity do not throw', () {
      expect(() => fmtAmt(double.nan, 'JOD'), returnsNormally);
      expect(() => fmtAmt(double.infinity, 'JOD'), returnsNormally);
    });

    test('JOD (the default currency) has 3 decimals: 0.125 must not become 0.13', () {
      expect(fmtAmt(0.125, 'JOD'), '0.125 JOD');
    });

    test('zero-decimal currencies (JPY) are not shown with cents', () {
      expect(fmtAmt(1000.5, 'JPY'), isNot(contains('.50')));
    });
  });

  group('currency list', () {
    test('codes are unique, 3 upper-case letters, default is present', () {
      final codes = kAllCurrencies.map((c) => c.code).toList();
      expect(codes.toSet().length, codes.length, reason: 'duplicate codes');
      for (final c in codes) {
        expect(RegExp(r'^[A-Z]{3}$').hasMatch(c), isTrue, reason: c);
      }
      expect(codes, contains(kDefaultCurrency));
    });
  });
}
