// ── History filtering ─────────────────────────────────────────────────────────
// Pure helpers for the History page: how a DB transaction type is shown, and
// which transactions match the search text / kind chip / date range the user set.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter/material.dart' show DateTimeRange;

/// Maps a DB transaction type to the display type that styles a TransactionCard.
String txDisplayType(String type) {
  switch (type) {
    case 'deposit':
    case 'salary':
    case 'initial':
      return 'Deposit';
    case 'withdraw':
    case 'bill_paid':
      return 'Withdraw';
    case 'transfer_in':
    case 'transfer_out':
      return 'Transfer';
    case 'debt_out':
      return 'Debt Out';
    case 'debt_repaid':
      return 'Debt Back';
    default:
      return 'Deposit';
  }
}

/// The user-entered note of [tx], or null when there is none.
/// Transfers embed the counterpart account name after '\x00'; it is stripped.
/// System-generated notes (bill_paid, salary, initial) return null.
String? txUserNote(TransactionModel tx) {
  if (tx.type == 'bill_paid' || tx.type == 'salary' || tx.type == 'initial') {
    return null;
  }
  final raw = tx.type == 'transfer_in' || tx.type == 'transfer_out'
      ? tx.note.split('\x00').first
      : tx.note;
  return raw.isNotEmpty ? raw : null;
}

enum HistoryKind {
  all('All'),
  deposits('Deposits'),
  withdrawals('Withdrawals'),
  transfers('Transfers'),
  debts('Debts');

  final String label;
  const HistoryKind(this.label);

  bool matches(String displayType) => switch (this) {
        all => true,
        deposits => displayType == 'Deposit',
        withdrawals => displayType == 'Withdraw',
        transfers => displayType == 'Transfer',
        debts => displayType == 'Debt Out' || displayType == 'Debt Back',
      };
}

/// What the user typed / picked on the History page. An empty filter matches
/// everything.
class HistoryFilter {
  final String query;
  final HistoryKind kind;

  /// Inclusive on both days.
  final DateTimeRange? range;

  const HistoryFilter({
    this.query = '',
    this.kind = HistoryKind.all,
    this.range,
  });

  bool get isActive =>
      query.trim().isNotEmpty || kind != HistoryKind.all || range != null;

  bool matches(TransactionModel tx) {
    final display = txDisplayType(tx.type);
    if (!kind.matches(display)) return false;

    final r = range;
    if (r != null) {
      final start = DateTime(r.start.year, r.start.month, r.start.day);
      final end = DateTime(r.end.year, r.end.month, r.end.day + 1);
      if (tx.createdAt.isBefore(start) || !tx.createdAt.isBefore(end)) {
        return false;
      }
    }

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    // Same text the card shows, plus the amount as typed ("12.5") or padded ("12.50").
    final haystack = [
      tx.title.isNotEmpty ? tx.title : display,
      txUserNote(tx) ?? '',
      plainAmt(tx.amount),
      tx.amount.toStringAsFixed(2),
    ].join('\n').toLowerCase();
    return haystack.contains(q);
  }

  List<TransactionModel> apply(List<TransactionModel> txs) =>
      txs.where(matches).toList();
}
