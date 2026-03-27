// ── FixedExpensesPage ─────────────────────────────────────────────────────────
// Manages recurring fixed expenses (bills). Shows a live list of expenses
// grouped by category with swipe-to-edit/delete cards. A FAB opens a
// bottom sheet to add a new bill; confirming also logs a bill_paid transaction
// and deducts from the Monthly Budget account.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/modules/fixedExp/bill_categories.dart';
import 'package:financeapp/modules/fixedExp/widgets/expense_card.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:financeapp/shared/tutorial/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Page ─────────────────────────────────────────────────────────────────────

class Fixedexpensespage extends ConsumerStatefulWidget {
  const Fixedexpensespage({super.key});

  @override
  ConsumerState<Fixedexpensespage> createState() => _FixedexpensespageState();
}

class _FixedexpensespageState extends ConsumerState<Fixedexpensespage> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String? _categoryFilter; // null = All
  VoidCallback? _closeOpenCard;

  final _fabKey = GlobalKey();
  OverlayEntry? _tutorialEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  @override
  void dispose() {
    _tutorialEntry?.remove();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _maybeShowTutorial() async {
    final db = ref.read(dbProvider);
    final seen = await db.hasTutorialSeen('tutorial_bills');
    if (seen || !mounted) return;
    await db.markTutorialSeen('tutorial_bills');
    if (!mounted) return;
    _tutorialEntry = OverlayEntry(
      builder: (_) => TutorialOverlay(
        steps: [
          const TutorialStep(
            title: AppStrings.tutBillsTitle,
            body: AppStrings.tutBillsBody,
          ),
          TutorialStep(
            targetKey: _fabKey,
            title: AppStrings.tutAddBillTitle,
            body: AppStrings.tutAddBillBody,
            position: TipPosition.above,
          ),
          const TutorialStep(
            title: AppStrings.tutSwipeTitle,
            body: AppStrings.tutSwipeBody,
          ),
        ],
        onDone: () {
          _tutorialEntry?.remove();
          _tutorialEntry = null;
        },
      ),
    );
    Overlay.of(context).insert(_tutorialEntry!);
  }

  // ── Add / Edit bottom sheet ──────────────────────────────────────────────────
  void _showBottomSheet({ExpenseModel? item, int? index}) {
    if (item != null) {
      _nameCtrl.text = item.name;
      _amountCtrl.text = item.amount.toString();
    } else {
      _nameCtrl.clear();
      _amountCtrl.clear();
    }
    String sheetCat = item?.category ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusXXL)),
            ),
            padding: EdgeInsets.fromLTRB(
                AppSizes.l, AppSizes.m, AppSizes.l, AppSizes.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModalHandle(),
                SizedBox(height: AppSizes.l),

                // Title
                Text(
                  item == null ? AppStrings.addBillTitle : AppStrings.editBillTitle,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: AppSizes.l),

                // Bill name
                _field(_nameCtrl, AppStrings.billName),
                SizedBox(height: AppSizes.m),

                // Amount
                _field(_amountCtrl, 'Amount (${ref.read(currencyProvider)})', isNumber: true),
                SizedBox(height: AppSizes.l),

                // Category label
                Text(
                  AppStrings.sectionCategory,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontXS,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Colors.grey[400],
                  ),
                ),
                SizedBox(height: AppSizes.s),

                // Category chips grid
                Wrap(
                  spacing: AppSizes.s,
                  runSpacing: AppSizes.s,
                  children: kBillCats.map((cat) {
                    final sel = sheetCat == cat.name ||
                        (sheetCat.isEmpty && cat.name == 'Other');
                    return GestureDetector(
                      onTap: () => setSheetState(
                          () => sheetCat = cat.name == 'Other' ? '' : cat.name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.symmetric(
                            horizontal: AppSizes.m, vertical: AppSizes.s),
                        decoration: BoxDecoration(
                          color: sel
                              ? cat.color.withValues(alpha: 0.12)
                              : AppColors.pageBackground,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusL),
                          border: Border.all(
                            color: sel ? cat.color : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon,
                                color: sel ? cat.color : Colors.grey[400],
                                size: AppSizes.iconS),
                            SizedBox(width: AppSizes.xs + 2),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontFamily: 'Rubik',
                                fontSize: AppSizes.fontXS,
                                fontWeight: FontWeight.w600,
                                color: sel ? cat.color : Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                SizedBox(height: AppSizes.l),

                // Buttons
                Row(
                  children: [
                    Expanded(child: _cancelBtn(() => Navigator.pop(ctx))),
                    SizedBox(width: AppSizes.s + 4),
                    Expanded(
                      child: _primaryBtn(
                        item == null ? 'Add' : 'Save',
                        () {
                          final name = _nameCtrl.text.trim();
                          final amount =
                              int.tryParse(_amountCtrl.text.trim()) ?? 0;
                          if (name.isEmpty || amount <= 0) return;
                          if (item == null) {
                            ref
                                .read(expensesProvider.notifier)
                                .add(name, amount, sheetCat);
                          } else {
                            ref
                                .read(expensesProvider.notifier)
                                .edit(index!, name, amount, sheetCat);
                          }
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Confirm paid dialog ──────────────────────────────────────────────────────
  void _showConfirmPaid(int index) {
    final bill = ref.read(expensesProvider)[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSizes.m),
              decoration: BoxDecoration(
                color: AppColors.myGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline,
                  color: AppColors.myGreen, size: AppSizes.iconXL),
            ),
            SizedBox(height: AppSizes.m),
            Text(
              AppStrings.markAsPaid,
              style: TextStyle(
                fontFamily: 'Rubik',
                fontSize: AppSizes.fontXXL,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: AppSizes.s),
            Text(
              'This will deduct ${bill.amount} ${ref.read(currencyProvider)} from your Wallet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontS,
                  color: Colors.grey[400],
                  height: 1.5),
            ),
            SizedBox(height: AppSizes.l),
            Row(
              children: [
                Expanded(child: _cancelBtn(() => Navigator.pop(ctx))),
                SizedBox(width: AppSizes.s + 4),
                Expanded(
                  child: _primaryBtn('Confirm', () async {
                    Navigator.pop(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    final tx = TransactionModel(
                      id: 0,
                      accountId: kWalletId,
                      type: 'bill_paid',
                      amount: bill.amount.toDouble(),
                      title: bill.name,
                      note: AppStrings.monthlyBill,
                      createdAt: DateTime.now(),
                    );
                    final success = await ref
                        .read(accountsProvider.notifier)
                        .withdraw(kWalletId, bill.amount.toDouble(), tx);
                    if (!success) {
                      AppToast.error(messenger, AppStrings.insufficientWalletBalance);
                      return;
                    }
                    // Find the real index in the full list
                    final allBills = ref.read(expensesProvider);
                    final realIndex =
                        allBills.indexWhere((b) => b.id == bill.id);
                    if (realIndex != -1) {
                      await ref
                          .read(expensesProvider.notifier)
                          .markPaid(realIndex);
                    }
                    AppToast.success(
                        messenger, '${bill.name} paid · - ${bill.amount} ${ref.read(currencyProvider)}');
                  }, color: AppColors.myGreen),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete dialog ────────────────────────────────────────────────────────────
  Future<bool> _confirmDelete(BuildContext ctx) async {
    return await showDialog<bool>(
          context: ctx,
          builder: (dCtx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AppSizes.s),
                  decoration: BoxDecoration(
                    color: AppColors.myRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete_outline,
                      color: AppColors.myRed, size: AppSizes.iconM),
                ),
                SizedBox(width: AppSizes.s + 4),
                const Text(AppStrings.deleteBillTitle,
                    style: TextStyle(
                        fontFamily: 'Rubik', fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              AppStrings.deleteBillBody,
              style: TextStyle(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: Text(AppStrings.cancel,
                    style: TextStyle(color: Colors.grey[500])),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.myRed,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusS)),
                ),
                child: const Text(AppStrings.delete,
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Shared UI helpers ────────────────────────────────────────────────────────
  Widget _field(TextEditingController ctrl, String label,
      {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters:
            isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: const TextStyle(
            fontFamily: 'Rubik',
            fontWeight: FontWeight.w600,
            color: AppColors.primary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontFamily: 'Rubik', color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
              horizontal: AppSizes.m, vertical: AppSizes.m),
        ),
      ),
    );
  }

  Widget _cancelBtn(VoidCallback onPressed) => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey[200]!),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL)),
          padding: EdgeInsets.symmetric(vertical: AppSizes.m),
        ),
        child: Text('Cancel',
            style: TextStyle(
                color: Colors.grey[500],
                fontFamily: 'Rubik',
                fontWeight: FontWeight.w600)),
      );

  Widget _primaryBtn(String label, VoidCallback onPressed,
          {Color color = AppColors.primary}) =>
      ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusL)),
          padding: EdgeInsets.symmetric(vertical: AppSizes.m),
        ),
        child: Text(label,
            style: TextStyle(
                color: color == AppColors.myGreen
                    ? AppColors.primary
                    : Colors.white,
                fontFamily: 'Rubik',
                fontWeight: FontWeight.w600)),
      );

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final currency = ref.watch(currencyProvider);

    // Collect used categories in predefined order
    final usedCatNames = kBillCats
        .map((c) => c.name)
        .where((n) => expenses.any((e) => displayCat(e) == n))
        .toList();
    final showFilter = usedCatNames.length >= 2;

    // Filter
    final filtered = _categoryFilter == null
        ? expenses
        : expenses
            .where((e) => displayCat(e) == _categoryFilter)
            .toList();

    // Summary (always all bills)
    final paidCount = expenses.where((e) => e.isPaid).length;
    final totalAmount = expenses.fold<int>(0, (s, e) => s + e.amount);
    final paidAmount =
        expenses.where((e) => e.isPaid).fold<int>(0, (s, e) => s + e.amount);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.primary, size: AppSizes.iconM),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppStrings.bills,
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: AppSizes.fontXXL,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
      body: expenses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSizes.l),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.receipt_long_outlined,
                        color: AppColors.primary, size: AppSizes.xxl),
                  ),
                  SizedBox(height: AppSizes.m),
                  Text(
                    AppStrings.noBillsYet,
                    style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: AppSizes.fontL,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                  SizedBox(height: AppSizes.s),
                  Text('Tap + to add a bill',
                      style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontS,
                          color: Colors.grey[400])),
                ],
              ),
            )
          : Column(
              children: [
                // ── Summary ─────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      AppSizes.m, 0, AppSizes.m, AppSizes.s),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.m, vertical: AppSizes.m),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _summaryTile(
                            label: 'Total',
                            value: '$totalAmount $currency',
                            color: AppColors.primary),
                        _vDivider(),
                        _summaryTile(
                            label: 'Paid',
                            value: '$paidAmount $currency',
                            color: AppColors.myGreen),
                        _vDivider(),
                        _summaryTile(
                            label: 'Remaining',
                            value: '${totalAmount - paidAmount} $currency',
                            color: AppColors.myRed),
                        _vDivider(),
                        _summaryTile(
                            label: 'Done',
                            value: '$paidCount / ${expenses.length}',
                            color: Colors.blueAccent),
                      ],
                    ),
                  ),
                ),

                // ── Category filter chips ────────────────────────────
                if (showFilter)
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: AppSizes.m),
                      children: [
                        // All chip
                        _filterChip('All', null, Icons.grid_view_rounded,
                            Colors.grey, usedCatNames),
                        ...usedCatNames.map((name) {
                          final cat = catFor(name);
                          return _filterChip(
                              name, name, cat.icon, cat.color, usedCatNames);
                        }),
                      ],
                    ),
                  ),

                if (showFilter) SizedBox(height: AppSizes.s),

                // ── List ─────────────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No bills in this category',
                            style: TextStyle(
                                fontFamily: 'Rubik',
                                fontSize: AppSizes.fontS,
                                color: Colors.grey[400]),
                          ),
                        )
                      : ListView.builder(
                          padding:
                              EdgeInsets.symmetric(horizontal: AppSizes.m),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final item = filtered[i];
                            // Real index in the full list (for notifier calls)
                            final realIndex =
                                expenses.indexWhere((e) => e.id == item.id);
                            return Padding(
                              key: ValueKey(item.id),
                              padding:
                                  EdgeInsets.only(bottom: AppSizes.s + 4),
                              child: SlidableExpenseCard(
                                item: item,
                                currency: currency,
                                onOpened: (closeFn) {
                                  _closeOpenCard?.call();
                                  _closeOpenCard = closeFn;
                                },
                                onClosed: () => _closeOpenCard = null,
                                onEdit: () => _showBottomSheet(
                                    item: item, index: realIndex),
                                onDelete: () async {
                                  final confirmed =
                                      await _confirmDelete(context);
                                  if (confirmed) {
                                    ref
                                        .read(expensesProvider.notifier)
                                        .delete(realIndex);
                                  }
                                },
                                onTap: item.isPaid
                                    ? null
                                    : () => _showBottomSheet(
                                        item: item, index: realIndex),
                                onCheckTap: item.isPaid
                                    ? null
                                    : () => _showConfirmPaid(realIndex),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        key: _fabKey,
        onPressed: () => _showBottomSheet(),
        backgroundColor: AppColors.primary,
        elevation: 2,
        child: Icon(Icons.add, color: Colors.white, size: AppSizes.iconL),
      ),
    );
  }

  Widget _filterChip(String label, String? value, IconData icon, Color color,
      List<String> usedCats) {
    final selected = _categoryFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _categoryFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.only(right: AppSizes.s),
        padding: EdgeInsets.symmetric(
            horizontal: AppSizes.m, vertical: AppSizes.xs + 2),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: selected
                    ? Colors.white
                    : (value == null ? Colors.grey[400] : color)),
            SizedBox(width: AppSizes.xs + 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Rubik',
                fontSize: AppSizes.fontXS,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(
          {required String label,
          required String value,
          required Color color}) =>
      Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontS,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: 10,
                    color: Colors.grey[400])),
          ],
        ),
      );

  Widget _vDivider() =>
      Container(width: 1, height: 32, color: Colors.grey[100]);
}
