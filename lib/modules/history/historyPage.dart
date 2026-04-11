// ── HistoryPage ───────────────────────────────────────────────────────────────
// Full-screen transaction history for a single account. Transactions are
// grouped by month under sticky section headers, loaded once from SQLite on init.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:financeapp/shared/utils/currency.dart';
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
  // Raw transactions in newest-first order, loaded from DB once.
  List<TransactionModel> _transactions = [];
  // True while the initial DB fetch is in-flight; shows a spinner.
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
    return '${AppStrings.monthsFull[dt.month]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
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
                            return GestureDetector(
                              onTap: () => _showTxDetail(tx),
                              child: TransactionCard(
                                type: _txDisplayType(tx.type),
                                amount: tx.amount,
                                description: tx.title.isNotEmpty
                                    ? tx.title
                                    : _txDisplayType(tx.type),
                                subtitle: _txSubtitle(tx),
                                note: _userNote(tx),
                                dateTime: tx.createdAt,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTxDetail(TransactionModel tx) {
    final displayType = _txDisplayType(tx.type);
    final subtitle = _txSubtitle(tx);
    final note = _userNote(tx);
    final currency = ref.read(currencyProvider);

    final iconData = switch (displayType) {
      'Deposit'   => Icons.arrow_downward_rounded,
      'Withdraw'  => Icons.arrow_upward_rounded,
      'Debt Out'  => Icons.handshake_outlined,
      'Debt Back' => Icons.handshake_outlined,
      _           => Icons.swap_horiz_rounded,
    };
    final accentColor = switch (displayType) {
      'Deposit'   => AppColors.myGreen,
      'Withdraw'  => AppColors.myRed,
      'Debt Out'  => const Color(0xFFFF8F00),
      'Debt Back' => Colors.teal,
      _           => Colors.blueAccent,
    };
    final sign = switch (displayType) {
      'Deposit' || 'Debt Back' => '+ ',
      'Withdraw' || 'Debt Out' => '- ',
      _                        => '',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSizes.radiusXXL)),
        ),
        padding: EdgeInsets.fromLTRB(
            AppSizes.l, AppSizes.m, AppSizes.l, AppSizes.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: AppSizes.handleBarWidth,
                height: AppSizes.handleBarHeight,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: AppSizes.l),

            // Icon + Title + Amount
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  ),
                  child: Icon(iconData, color: accentColor, size: AppSizes.iconL),
                ),
                SizedBox(width: AppSizes.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.title.isNotEmpty ? tx.title : displayType,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontXXL,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        displayType,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontXS,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$sign${fmtAmt(tx.amount, currency)}',
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),

            SizedBox(height: AppSizes.l),
            Divider(color: Colors.grey[100], height: 1),
            SizedBox(height: AppSizes.s),

            // Detail rows
            _detailRow(Icons.calendar_today_rounded, 'Date',
                _formatDateFull(tx.createdAt)),
            if (subtitle != null)
              _detailRow(Icons.compare_arrows_rounded, 'Account',
                  subtitle),
            if (note != null)
              _detailRow(Icons.notes_rounded, 'Note', note),

            SizedBox(height: AppSizes.m),

            // Close button
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pageBackground,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusXL)),
                ),
                child: Text(
                  'Close',
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontM,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.s - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.pageBackground,
              borderRadius: BorderRadius.circular(AppSizes.radiusS),
            ),
            child: Icon(icon, color: Colors.grey[400], size: AppSizes.iconS),
          ),
          SizedBox(width: AppSizes.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontS,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateFull(DateTime dt) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final hour = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month]} ${dt.day}, ${dt.year}  ·  '
        '$hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
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
            AppStrings.noTransactions,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: AppSizes.s),
          Text(
            AppStrings.historyEmptySubtitle,
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
      case 'debt_out':
        return 'Debt Out';
      case 'debt_repaid':
        return 'Debt Back';
      default:
        return 'Deposit';
    }
  }

  /// Extracts the user-entered note from tx.note.
  /// Transfers embed the counterpart account name after '\x00'; we strip it.
  /// System-generated notes (bill_paid, salary, initial) return null.
  String? _userNote(TransactionModel tx) {
    if (tx.type == 'bill_paid' || tx.type == 'salary' || tx.type == 'initial') {
      return null;
    }
    final raw = tx.type == 'transfer_in' || tx.type == 'transfer_out'
        ? tx.note.split('\x00').first
        : tx.note;
    return raw.isNotEmpty ? raw : null;
  }

  /// Returns a "From X" / "To X" subtitle for transfer transactions.
  String? _txSubtitle(TransactionModel tx) {
    if (tx.type == 'transfer_in' && tx.relatedAccountId != null) {
      return 'From ${_accountName(tx.relatedAccountId!, tx.note)}';
    }
    if (tx.type == 'transfer_out' && tx.relatedAccountId != null) {
      return 'To ${_accountName(tx.relatedAccountId!, tx.note)}';
    }
    return null;
  }

  /// Resolves an account name by id. If the account no longer exists (deleted),
  /// falls back to the name embedded in [note] after the '\x00' separator.
  String _accountName(int id, String note) {
    switch (id) {
      case kWalletId: return AppStrings.wallet;
      case kBudgetId: return AppStrings.monthlyBudget;
      case kSavingsId: return AppStrings.savings;
      default:
        final accounts = ref.read(accountsProvider);
        try {
          return accounts.firstWhere((a) => a.id == id).displayName;
        } catch (_) {
          // Use the account name embedded in the note field as a fallback.
          final sep = note.indexOf('\x00');
          final stored = sep >= 0 ? note.substring(sep + 1) : note;
          return stored.isNotEmpty ? stored : AppStrings.deletedAccount;
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
