import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Historypage extends ConsumerStatefulWidget {
  final int accountId;
  final String accountName;

  const Historypage({
    super.key,
    required this.accountId,
    required this.accountName,
  });

  @override
  ConsumerState<Historypage> createState() => _HistorypageState();
}

class _HistorypageState extends ConsumerState<Historypage> {
  List<TransactionModel> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(dbProvider);
    final txs = await db.getTransactions(widget.accountId);
    if (mounted) {
      setState(() {
        _transactions = txs;
        _loading = false;
      });
    }
  }

  /// Groups transactions by "Month Year" preserving order (desc).
  List<_Item> get _items {
    final result = <_Item>[];
    String? lastMonth;

    for (final tx in _transactions) {
      final month = _monthLabel(tx.createdAt);
      if (month != lastMonth) {
        result.add(_Item.header(month));
        lastMonth = month;
      }
      result.add(_Item.tx(tx));
    }
    return result;
  }

  String _monthLabel(DateTime dt) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[dt.month]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.s,
                vertical: AppSizes.s,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.primary,
                      size: AppSizes.iconM,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${widget.accountName} History',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: AppSizes.fontXXL,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : _transactions.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSizes.m,
                            vertical: AppSizes.s,
                          ),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            if (item.isHeader) {
                              return _MonthHeader(label: item.month!);
                            }
                            final tx = item.tx!;
                            return TransactionCard(
                              type: _txDisplayType(tx.type),
                              amount: tx.amount,
                              description: tx.title.isNotEmpty
                                  ? tx.title
                                  : _txDisplayType(tx.type),
                              subtitle: _txSubtitle(tx),
                              dateTime: tx.createdAt,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(AppSizes.l),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_rounded,
                color: AppColors.primary, size: AppSizes.xxl),
          ),
          SizedBox(height: AppSizes.m),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: AppSizes.s),
          Text(
            'Your history will appear here.',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontS,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// Maps DB transaction type → display type for TransactionCard styling.
  String _txDisplayType(String type) {
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
      default:
        return 'Deposit';
    }
  }

  /// Returns a "From X" / "To X" subtitle for transfer transactions.
  String? _txSubtitle(TransactionModel tx) {
    if (tx.type == 'transfer_in' && tx.relatedAccountId != null) {
      return 'From ${_accountName(tx.relatedAccountId!)}';
    }
    if (tx.type == 'transfer_out' && tx.relatedAccountId != null) {
      return 'To ${_accountName(tx.relatedAccountId!)}';
    }
    return null;
  }

  String _accountName(int id) {
    switch (id) {
      case kWalletId: return 'Wallet';
      case kBudgetId: return 'Monthly Budget';
      case kSavingsId: return 'Savings';
      default:
        final accounts = ref.read(accountsProvider);
        try {
          return accounts.firstWhere((a) => a.id == id).displayName;
        } catch (_) {
          return 'Unknown';
        }
    }
  }
}

// ── Month header ──────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final String label;
  const _MonthHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          top: AppSizes.m, bottom: AppSizes.s, left: AppSizes.xs),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Rubik',
          fontSize: AppSizes.fontXS,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}

// ── List item (header or transaction) ────────────────────────────────────────

class _Item {
  final bool isHeader;
  final String? month;
  final TransactionModel? tx;

  const _Item.header(this.month)
      : isHeader = true,
        tx = null;

  const _Item.tx(this.tx)
      : isHeader = false,
        month = null;
}
