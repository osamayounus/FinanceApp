import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/tutorial/tutorial_overlay.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Bill categories ───────────────────────────────────────────────────────────

class _Cat {
  final String name;
  final IconData icon;
  final Color color;
  const _Cat(this.name, this.icon, this.color);
}

const _kCats = [
  _Cat('Housing',       Icons.home_rounded,            Color(0xFF7C4DFF)),
  _Cat('Utilities',     Icons.bolt_rounded,            Color(0xFFFFB300)),
  _Cat('Subscriptions', Icons.play_circle_rounded,     Color(0xFFE91E63)),
  _Cat('Transport',     Icons.directions_car_rounded,  Color(0xFF2979FF)),
  _Cat('Health',        Icons.favorite_rounded,        Color(0xFFE53935)),
  _Cat('Education',     Icons.school_rounded,          Color(0xFF00BCD4)),
  _Cat('Food',          Icons.restaurant_rounded,      Color(0xFFFF6D00)),
  _Cat('Other',         Icons.category_rounded,        Color(0xFF78909C)),
];

_Cat _catFor(String name) =>
    _kCats.firstWhere((c) => c.name == name, orElse: () => _kCats.last);

String _displayCat(ExpenseModel e) =>
    e.category.isEmpty ? 'Other' : e.category;

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
            title: 'Monthly Bills',
            body:
                'Track your fixed monthly expenses here — rent, subscriptions, utilities, and more.',
          ),
          TutorialStep(
            targetKey: _fabKey,
            title: 'Add a Bill',
            body:
                'Tap + to add a new bill. Each month, mark it as paid and it deducts from your Wallet.',
            position: TipPosition.above,
          ),
          const TutorialStep(
            title: 'Swipe to Manage',
            body:
                'Swipe a bill right to edit it, or left to delete it.\nTap the ✓ icon to mark it as paid.',
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
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: AppSizes.l),

                // Title
                Text(
                  item == null ? 'Add Bill' : 'Edit Bill',
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontXXL,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: AppSizes.l),

                // Bill name
                _field(_nameCtrl, 'Bill Name'),
                SizedBox(height: AppSizes.m),

                // Amount
                _field(_amountCtrl, 'Amount (${ref.read(currencyProvider)})', isNumber: true),
                SizedBox(height: AppSizes.l),

                // Category label
                Text(
                  'CATEGORY',
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
                  children: _kCats.map((cat) {
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
                              : const Color(0xFFF2F3F7),
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
              'Mark as Paid?',
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
                      note: 'Monthly Bill',
                      createdAt: DateTime.now(),
                    );
                    final success = await ref
                        .read(accountsProvider.notifier)
                        .withdraw(kWalletId, bill.amount.toDouble(), tx);
                    if (!success) {
                      AppToast.error(messenger, 'Insufficient wallet balance');
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
                const Text('Delete Bill',
                    style: TextStyle(
                        fontFamily: 'Rubik', fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'Are you sure? This action cannot be undone.',
              style: TextStyle(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child:
                    Text('Cancel', style: TextStyle(color: Colors.grey[500])),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.myRed,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusS)),
                ),
                child: const Text('Delete',
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
        color: const Color(0xFFF2F3F7),
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
    final usedCatNames = _kCats
        .map((c) => c.name)
        .where((n) => expenses.any((e) => _displayCat(e) == n))
        .toList();
    final showFilter = usedCatNames.length >= 2;

    // Filter
    final filtered = _categoryFilter == null
        ? expenses
        : expenses
            .where((e) => _displayCat(e) == _categoryFilter)
            .toList();

    // Summary (always all bills)
    final paidCount = expenses.where((e) => e.isPaid).length;
    final totalAmount = expenses.fold<int>(0, (s, e) => s + e.amount);
    final paidAmount =
        expenses.where((e) => e.isPaid).fold<int>(0, (s, e) => s + e.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
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
          'Bills',
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
                    'No bills yet',
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
                          final cat = _catFor(name);
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
                              child: _SlidableExpenseCard(
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

// ── Slidable expense card ─────────────────────────────────────────────────────

class _SlidableExpenseCard extends StatefulWidget {
  final ExpenseModel item;
  final String currency;
  final void Function(VoidCallback closeFn)? onOpened;
  final VoidCallback? onClosed;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onCheckTap;

  const _SlidableExpenseCard({
    required this.item,
    required this.currency,
    this.onOpened,
    this.onClosed,
    this.onEdit,
    this.onDelete,
    this.onTap,
    this.onCheckTap,
  });

  @override
  State<_SlidableExpenseCard> createState() => _SlidableExpenseCardState();
}

class _SlidableExpenseCardState extends State<_SlidableExpenseCard>
    with SingleTickerProviderStateMixin {
  static const double _actionW = 80.0;

  late final AnimationController _ctrl;
  late Animation<double> _anim;
  double _offset = 0;
  bool _dragging = false;

  bool get _canEdit => !widget.item.isPaid;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _anim = const AlwaysStoppedAnimation(0.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _snapTo(double target) {
    final from = _dragging ? _offset : _anim.value;
    _dragging = false;
    _anim = Tween<double>(begin: from, end: target).animate(
      CurvedAnimation(parent: _ctrl..reset(), curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
    if (target != 0) {
      widget.onOpened?.call(_close);
    } else {
      widget.onClosed?.call();
    }
    setState(() {});
  }

  void _close() => _snapTo(0);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final displayOffset = _dragging ? _offset : _anim.value;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              _ctrl.stop();
              _offset = _anim.value;
              setState(() => _dragging = true);
            },
            onHorizontalDragUpdate: (d) {
              if (!_dragging) return;
              setState(() {
                _offset += d.delta.dx;
                _offset = _canEdit
                    ? _offset.clamp(-_actionW, _actionW)
                    : _offset.clamp(-_actionW, 0.0);
              });
            },
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              double target = 0;
              if (_offset > _actionW * 0.5 || v > 700) {
                target = _canEdit ? _actionW : 0;
              } else if (_offset < -_actionW * 0.5 || v < -700) {
                target = -_actionW;
              }
              _snapTo(target);
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    children: [
                      if (_canEdit)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _close();
                              widget.onEdit?.call();
                            },
                            child: Container(
                              color: const Color(0xFF1C2D6B),
                              alignment: Alignment.centerLeft,
                              padding: EdgeInsets.only(left: AppSizes.l),
                              child: const _ActionLabel(
                                  icon: Icons.edit_outlined, label: 'Edit'),
                            ),
                          ),
                        ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _close();
                            widget.onDelete?.call();
                          },
                          child: Container(
                            color: const Color(0xFF8B1A1A),
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: AppSizes.l),
                            child: const _ActionLabel(
                                icon: Icons.delete_outline_rounded,
                                label: 'Delete'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: Offset(displayOffset, 0),
                  child: _ExpenseCard(
                    item: widget.item,
                    currency: widget.currency,
                    onTap: displayOffset == 0 ? widget.onTap : _close,
                    onCheckTap:
                        displayOffset == 0 ? widget.onCheckTap : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Action label ──────────────────────────────────────────────────────────────

class _ActionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ActionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: AppSizes.iconM),
        SizedBox(height: AppSizes.xs),
        Text(label,
            style: TextStyle(
                color: Colors.white,
                fontSize: AppSizes.fontXS,
                fontFamily: 'Rubik',
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ── Expense card ──────────────────────────────────────────────────────────────

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel item;
  final String currency;
  final VoidCallback? onTap;
  final VoidCallback? onCheckTap;

  const _ExpenseCard({required this.item, required this.currency, this.onTap, this.onCheckTap});

  @override
  Widget build(BuildContext context) {
    final bool paid = item.isPaid;
    final cat = _catFor(_displayCat(item));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: paid
                  ? [Colors.grey[200]!, Colors.grey[100]!]
                  : [AppColors.primary, const Color(0xFF1A1D4A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            border: paid
                ? Border.all(
                    color: AppColors.myGreen.withValues(alpha: 0.55),
                    width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: (paid ? AppColors.myGreen : AppColors.primary)
                    .withValues(alpha: paid ? 0.12 : 0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: AppSizes.m, vertical: AppSizes.m),
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: paid
                        ? Colors.grey[300]
                        : cat.color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: Icon(
                    cat.icon,
                    color: paid ? Colors.grey[500] : cat.color,
                    size: AppSizes.iconM,
                  ),
                ),
                SizedBox(width: AppSizes.m),
                // Name + category + amount
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontM,
                          fontWeight: FontWeight.w600,
                          color: paid ? Colors.grey[500] : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat.name,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontXS,
                          color: paid
                              ? Colors.grey[400]
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.amount} $currency',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontXXL - 2,
                          fontWeight: FontWeight.w900,
                          color: paid ? Colors.grey[400] : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Check
                GestureDetector(
                  onTap: onCheckTap,
                  child: Container(
                    padding: EdgeInsets.all(AppSizes.s),
                    decoration: BoxDecoration(
                      color: paid
                          ? AppColors.myGreen.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      paid
                          ? Icons.check_circle_rounded
                          : Icons.check_circle_outline_rounded,
                      color: paid ? AppColors.myGreen : Colors.white60,
                      size: AppSizes.iconM + 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
