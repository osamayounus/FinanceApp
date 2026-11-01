// ── HistoryPage ───────────────────────────────────────────────────────────────
// Full-screen transaction history for a single account. Transactions are
// grouped by month under sticky section headers, loaded once from SQLite on init.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/modules/fixedExp/bill_categories.dart';
import 'package:financeapp/modules/history/history_filter.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final _searchCtrl = TextEditingController();
  HistoryKind _kind = HistoryKind.all;
  DateTimeRange? _range;

  HistoryFilter get _filter =>
      HistoryFilter(query: _searchCtrl.text, kind: _kind, range: _range);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  /// Groups the transactions that pass the filter by "Month Year" preserving
  /// order (desc).
  List<_Item> _itemsOf(List<TransactionModel> visible) {
    final result = <_Item>[];
    String? lastMonth;

    for (final tx in visible) {
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
    final filter = _filter;
    final items = _itemsOf(filter.apply(_transactions));
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

            // ── Search + filters (only worth showing once there is history) ──
            if (!_loading && _transactions.isNotEmpty) _filterBar(filter),

            // ── Content ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : _transactions.isEmpty
                      ? _emptyState()
                      : items.isEmpty
                          ? _noMatchesState()
                          : ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSizes.m,
                            vertical: AppSizes.s,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            if (item.isHeader) {
                              return _MonthHeader(label: item.month!);
                            }
                            final tx = item.tx!;
                            return GestureDetector(
                              onTap: () => _showTxDetail(tx),
                              child: TransactionCard(
                                type: txDisplayType(tx.type),
                                amount: tx.amount,
                                description: tx.title.isNotEmpty
                                    ? tx.title
                                    : txDisplayType(tx.type),
                                subtitle: _txSubtitle(tx),
                                note: txUserNote(tx),
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
    final displayType = txDisplayType(tx.type);
    final subtitle = _txSubtitle(tx);
    final note = txUserNote(tx);
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
            if (tx.category.isNotEmpty)
              _detailRow(Icons.category_rounded, 'Category', tx.category),
            if (note != null)
              _detailRow(Icons.notes_rounded, 'Note', note),

            SizedBox(height: AppSizes.m),

            // Edit / delete: only for rows that can be corrected on their own.
            if (AppDatabase.editableTxTypes.contains(tx.type)) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteTx(tx);
                      },
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.myRed),
                      label: const Text(
                        AppStrings.delete,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontWeight: FontWeight.w600,
                          color: AppColors.myRed,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppColors.myRed.withValues(alpha: 0.4)),
                        minimumSize: Size.fromHeight(AppSizes.buttonHeight),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusXL)),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSizes.s),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _editTx(tx);
                      },
                      icon: const Icon(Icons.edit_outlined,
                          color: AppColors.primary),
                      label: const Text(
                        'Edit',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.4)),
                        minimumSize: Size.fromHeight(AppSizes.buttonHeight),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusXL)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSizes.s),
            ],

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

  // ── Search + filters ──────────────────────────────────────────────────────

  Widget _filterBar(HistoryFilter filter) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.m),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontFamily: 'Rubik',
                fontSize: AppSizes.fontM,
                color: AppColors.primary,
              ),
              decoration: InputDecoration(
                hintText: 'Search title, note or amount',
                hintStyle:
                    TextStyle(fontFamily: 'Rubik', color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.grey[400], size: AppSizes.iconM),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        onPressed: () => setState(_searchCtrl.clear),
                        icon: Icon(Icons.close_rounded,
                            color: Colors.grey[400], size: AppSizes.iconS),
                      ),
                    IconButton(
                      tooltip: 'Filter by date',
                      onPressed: _pickRange,
                      icon: Icon(
                        Icons.date_range_rounded,
                        size: AppSizes.iconM,
                        color: _range == null
                            ? Colors.grey[400]
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: AppSizes.m),
              ),
            ),
          ),
          SizedBox(height: AppSizes.s),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final k in HistoryKind.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(k.label),
                      selected: _kind == k,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _kind = k),
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: AppSizes.fontS,
                        fontWeight: FontWeight.w600,
                        color: _kind == k ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                if (_range != null)
                  InputChip(
                    label: Text(_rangeLabel(_range!)),
                    onDeleted: () => setState(() => _range = null),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontS,
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

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      // The date picker on the Add page allows dates up to a year ahead.
      lastDate: DateTime.now().add(const Duration(days: 366)),
      initialDateRange: _range,
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  String _rangeLabel(DateTimeRange r) {
    String d(DateTime x) => '${AppStrings.monthsShort[x.month]} ${x.day}';
    return r.start.year == r.end.year && r.start.year == DateTime.now().year
        ? '${d(r.start)} – ${d(r.end)}'
        : '${d(r.start)} ${r.start.year} – ${d(r.end)} ${r.end.year}';
  }

  Widget _noMatchesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              color: Colors.grey[300], size: AppSizes.xxl),
          SizedBox(height: AppSizes.m),
          Text(
            'No matching transactions',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: AppSizes.s),
          TextButton(
            onPressed: () => setState(() {
              _searchCtrl.clear();
              _kind = HistoryKind.all;
              _range = null;
            }),
            child: const Text('Clear filters',
                style: TextStyle(fontFamily: 'Rubik')),
          ),
        ],
      ),
    );
  }

  // ── Edit / delete ─────────────────────────────────────────────────────────

  Future<void> _editTx(TransactionModel tx) async {
    final messenger = ScaffoldMessenger.of(context);
    final edited = await showModalBottomSheet<_TxEdit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _EditTxSheet(tx: tx, currency: ref.read(currencyProvider)),
    );
    if (edited == null || !mounted) return;
    final ok = await ref.read(accountsProvider.notifier).updateTransaction(
        tx.id,
        amount: edited.amount,
        title: edited.title,
        note: edited.note,
        category: edited.category);
    if (!mounted) return;
    if (ok) {
      AppToast.success(messenger, 'Transaction updated');
    } else {
      AppToast.error(messenger, 'Balance is too low to apply this change');
    }
    await _load();
  }

  Future<void> _deleteTx(TransactionModel tx) async {
    final messenger = ScaffoldMessenger.of(context);
    final currency = ref.read(currencyProvider);
    final isDeposit = tx.type == 'deposit';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
        title: const Text(
          'Delete transaction',
          style: TextStyle(
              fontFamily: 'Rubik',
              fontWeight: FontWeight.bold,
              color: AppColors.primary),
        ),
        content: Text(
          'The ${fmtAmt(tx.amount, currency)} will be '
          '${isDeposit ? 'taken out of' : 'returned to'} '
          '${widget.accountName}.\n\nThis cannot be undone.',
          style: const TextStyle(fontFamily: 'Rubik', height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel,
                style: TextStyle(
                    fontFamily: 'Rubik',
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.myRed,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.delete,
                style: TextStyle(
                    fontFamily: 'Rubik',
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref.read(accountsProvider.notifier).deleteTransaction(tx.id);
    if (!mounted) return;
    if (ok) {
      AppToast.success(messenger, 'Transaction deleted');
    } else {
      AppToast.error(
          messenger, 'Balance is too low to take this deposit back out');
    }
    await _load();
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

// ── Edit sheet ────────────────────────────────────────────────────────────────

typedef _TxEdit = ({double amount, String title, String note, String category});

class _EditTxSheet extends StatefulWidget {
  final TransactionModel tx;
  final String currency;
  const _EditTxSheet({required this.tx, required this.currency});

  @override
  State<_EditTxSheet> createState() => _EditTxSheetState();
}

class _EditTxSheetState extends State<_EditTxSheet> {
  late final _amount =
      TextEditingController(text: plainAmt(widget.tx.amount));
  late final _title = TextEditingController(text: widget.tx.title);
  late final _note = TextEditingController(text: widget.tx.note);
  late String _category = widget.tx.category;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || !(amount > 0)) {
      setState(() => _error = AppStrings.enterValidAmount);
      return;
    }
    final title = _title.text.trim();
    Navigator.pop<_TxEdit>(context, (
      amount: amount,
      // Same fallback as the Add page uses for an empty title.
      title: title.isNotEmpty
          ? title
          : (widget.tx.type == 'deposit'
              ? AppStrings.deposit
              : AppStrings.withdraw),
      note: _note.text.trim(),
      category: _category,
    ));
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool numeric = false, String? suffix, String? error}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: numeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        onChanged: numeric && _error != null
            ? (_) => setState(() => _error = null)
            : null,
        style: TextStyle(
          fontFamily: 'Rubik',
          fontSize: AppSizes.fontM,
          color: AppColors.primary,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontFamily: 'Rubik', color: Colors.grey[400]),
          suffixText: suffix,
          errorText: error,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: AppSizes.m, vertical: AppSizes.m),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXXL)),
        ),
        padding:
            EdgeInsets.fromLTRB(AppSizes.l, AppSizes.m, AppSizes.l, AppSizes.l),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: ModalHandle()),
              SizedBox(height: AppSizes.l),
              Text(
                'Edit transaction',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontXXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: AppSizes.l),
              _field(_amount, AppStrings.amount,
                  numeric: true, suffix: widget.currency, error: _error),
              SizedBox(height: AppSizes.s),
              _field(_title, AppStrings.titleOptional),
              SizedBox(height: AppSizes.s),
              _field(_note, AppStrings.noteOptional),
              if (widget.tx.type == 'withdraw') ...[
                SizedBox(height: AppSizes.s),
                CategoryPicker(
                    selected: _category,
                    onChanged: (c) => setState(() => _category = c)),
              ],
              SizedBox(height: AppSizes.l),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[200]!),
                        padding: EdgeInsets.symmetric(vertical: AppSizes.m),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusL)),
                      ),
                      child: Text(AppStrings.cancel,
                          style: TextStyle(
                              fontFamily: 'Rubik',
                              fontWeight: FontWeight.w600,
                              fontSize: AppSizes.fontM,
                              color: Colors.grey[500])),
                    ),
                  ),
                  SizedBox(width: AppSizes.s + 4),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: AppSizes.m),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusL)),
                      ),
                      child: Text(AppStrings.save,
                          style: TextStyle(
                              fontFamily: 'Rubik',
                              fontWeight: FontWeight.w600,
                              fontSize: AppSizes.fontM,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
