import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/modules/history/history_filter.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';

TransactionModel tx(String type, double amount,
        {String title = '', String note = '', DateTime? at, int id = 0}) =>
    TransactionModel(
      id: id,
      accountId: 1,
      type: type,
      amount: amount,
      title: title,
      note: note,
      createdAt: at ?? DateTime(2025, 6, 15, 12),
    );

void main() {
  group('txDisplayType / txUserNote', () {
    test('every stored type maps to one of the card styles', () {
      expect({
        for (final t in [
          'deposit', 'salary', 'initial', 'withdraw', 'bill_paid',
          'transfer_in', 'transfer_out', 'debt_out', 'debt_repaid',
        ])
          t: txDisplayType(t),
      }, {
        'deposit': 'Deposit', 'salary': 'Deposit', 'initial': 'Deposit',
        'withdraw': 'Withdraw', 'bill_paid': 'Withdraw',
        'transfer_in': 'Transfer', 'transfer_out': 'Transfer',
        'debt_out': 'Debt Out', 'debt_repaid': 'Debt Back',
      });
    });

    test('an unknown type is shown as a deposit (existing behaviour)', () {
      expect(txDisplayType('leftover'), 'Deposit');
    });

    test('system notes are hidden, transfer notes lose the account suffix', () {
      expect(txUserNote(tx('bill_paid', 1, note: 'auto')), isNull);
      expect(txUserNote(tx('salary', 1, note: 'auto')), isNull);
      expect(txUserNote(tx('initial', 1, note: 'auto')), isNull);
      expect(txUserNote(tx('deposit', 1, note: 'gift')), 'gift');
      expect(txUserNote(tx('deposit', 1)), isNull);
      expect(txUserNote(tx('transfer_out', 1, note: 'rent\x00Savings')), 'rent');
      expect(txUserNote(tx('transfer_out', 1, note: '\x00Savings')), isNull);
    });
  });

  group('HistoryFilter', () {
    final all = [
      tx('deposit', 50, title: 'Freelance', note: 'Invoice 7', id: 1),
      tx('withdraw', 12.5, title: 'Taxi', id: 2),
      tx('withdraw', 30, title: '', id: 3),
      tx('bill_paid', 250, title: 'Rent', id: 4),
      tx('transfer_out', 100, title: 'Move', note: 'rent\x00Savings', id: 5),
      tx('debt_out', 40, title: 'Lent to Ali', id: 6),
      tx('debt_repaid', 15, title: 'Ali paid', id: 7),
      tx('salary', 600, title: 'Salary', id: 8),
    ];
    List<int> ids(HistoryFilter f) => f.apply(all).map((t) => t.id).toList();

    test('an empty filter keeps everything, in the same order, and is not "active"', () {
      const f = HistoryFilter();
      expect(f.isActive, isFalse);
      expect(ids(f), [1, 2, 3, 4, 5, 6, 7, 8]);
    });

    test('whitespace-only search is not a filter', () {
      const f = HistoryFilter(query: '   ');
      expect(f.isActive, isFalse);
      expect(ids(f), hasLength(8));
    });

    group('search', () {
      test('matches the title, ignoring case', () {
        expect(ids(const HistoryFilter(query: 'taXI')), [2]);
      });

      test('matches the note', () {
        expect(ids(const HistoryFilter(query: 'invoice')), [1]);
      });

      test('matches part of a title', () {
        expect(ids(const HistoryFilter(query: 'ali')), [6, 7]);
      });

      test('matches the amount as plain or two-decimal text', () {
        expect(ids(const HistoryFilter(query: '12.5')), [2]);
        expect(ids(const HistoryFilter(query: '12.50')), [2]);
        expect(ids(const HistoryFilter(query: '250')), [4]);
      });

      test('a row without a title is found by the label the card shows', () {
        expect(ids(const HistoryFilter(query: 'withdraw')), [3]);
      });

      test('the hidden account suffix of a transfer note is not searchable', () {
        // "Savings" is only stored for the deleted-account fallback.
        expect(ids(const HistoryFilter(query: 'savings')), isEmpty);
        expect(ids(const HistoryFilter(query: 'rent')), [4, 5]);
      });

      test('no match gives an empty list', () {
        expect(ids(const HistoryFilter(query: 'zzz')), isEmpty);
      });

      test('surrounding spaces are ignored', () {
        expect(ids(const HistoryFilter(query: '  taxi ')), [2]);
      });
    });

    group('kind', () {
      test('deposits include salary', () {
        expect(ids(const HistoryFilter(kind: HistoryKind.deposits)), [1, 8]);
      });
      test('withdrawals include bills', () {
        expect(ids(const HistoryFilter(kind: HistoryKind.withdrawals)), [2, 3, 4]);
      });
      test('transfers', () {
        expect(ids(const HistoryFilter(kind: HistoryKind.transfers)), [5]);
      });
      test('debts cover both directions', () {
        expect(ids(const HistoryFilter(kind: HistoryKind.debts)), [6, 7]);
      });
      test('the kinds together cover every row exactly once', () {
        final seen = [
          for (final k in HistoryKind.values.where((k) => k != HistoryKind.all))
            ...ids(HistoryFilter(kind: k)),
        ]..sort();
        expect(seen, [1, 2, 3, 4, 5, 6, 7, 8]);
      });
    });

    group('date range', () {
      final days = [
        tx('deposit', 1, at: DateTime(2025, 6, 9, 23, 59, 59), id: 1),
        tx('deposit', 1, at: DateTime(2025, 6, 10, 0, 0, 0), id: 2),
        tx('deposit', 1, at: DateTime(2025, 6, 12, 15), id: 3),
        tx('deposit', 1, at: DateTime(2025, 6, 14, 23, 59, 59), id: 4),
        tx('deposit', 1, at: DateTime(2025, 6, 15, 0, 0, 0), id: 5),
      ];
      List<int> inRange(DateTimeRange r) =>
          HistoryFilter(range: r).apply(days).map((t) => t.id).toList();

      test('both the first and the last day are included in full', () {
        final r = DateTimeRange(
            start: DateTime(2025, 6, 10), end: DateTime(2025, 6, 14));
        expect(inRange(r), [2, 3, 4]);
      });

      test('a single day', () {
        final d = DateTime(2025, 6, 12);
        expect(inRange(DateTimeRange(start: d, end: d)), [3]);
      });

      test('a range counts as an active filter', () {
        final d = DateTime(2025, 6, 12);
        expect(HistoryFilter(range: DateTimeRange(start: d, end: d)).isActive, isTrue);
      });

      test('month and year boundaries', () {
        final dec31 = tx('deposit', 1, at: DateTime(2024, 12, 31, 23, 30), id: 9);
        final jan1 = tx('deposit', 1, at: DateTime(2025, 1, 1, 0, 30), id: 10);
        final r = DateTimeRange(
            start: DateTime(2024, 12, 31), end: DateTime(2024, 12, 31));
        expect(HistoryFilter(range: r).apply([dec31, jan1]).map((t) => t.id), [9]);
      });
    });

    test('search, kind and range all have to match', () {
      final f = HistoryFilter(
        query: 'rent',
        kind: HistoryKind.withdrawals,
        range: DateTimeRange(
            start: DateTime(2025, 6, 15), end: DateTime(2025, 6, 15)),
      );
      expect(ids(f), [4]); // 5 matches "rent" but is a transfer
      expect(f.isActive, isTrue);
    });
  });
}
