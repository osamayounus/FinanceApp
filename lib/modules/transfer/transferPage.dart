// ── TransferPage ──────────────────────────────────────────────────────────────
// Three-step wizard for moving funds between any two accounts:
//   Step 0 – pick FROM account
//   Step 1 – pick TO account (excludes FROM selection)
//   Step 2 – enter amount + optional title/note, then confirm
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/modules/transfer/transfer_success_page.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Data ─────────────────────────────────────────────────────────────────────

class _Acc {
  final int id;
  final String name;
  final IconData icon;
  const _Acc(this.id, this.name, this.icon);
}

// ── Page ─────────────────────────────────────────────────────────────────────

class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key});

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

// Holds snapshot of a completed transfer — triggers success screen in-place.
class _SuccessData {
  final double amount;
  final String currency;
  final String fromName;
  final IconData fromIcon;
  final String toName;
  final IconData toIcon;
  const _SuccessData({
    required this.amount,
    required this.currency,
    required this.fromName,
    required this.fromIcon,
    required this.toName,
    required this.toIcon,
  });
}

class _TransferPageState extends ConsumerState<TransferPage> {
  // IDs of the selected source and destination accounts.
  // Initialised to Wallet → Savings as the most common transfer direction.
  late int _fromId;
  late int _toId;

  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _customDate;

  // Non-null when the success screen should be shown inside this page.
  _SuccessData? _successData;

  @override
  void initState() {
    super.initState();
    _fromId = kWalletId;
    _toId = kSavingsId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<_Acc> _buildAccounts() {
    final accounts = ref.read(accountsProvider);
    return [
      const _Acc(kWalletId, AppStrings.wallet, Icons.account_balance_wallet_rounded),
      const _Acc(kSavingsId, AppStrings.savings, Icons.savings_rounded),
      const _Acc(kBudgetId, AppStrings.monthlyBudget, Icons.receipt_long_rounded),
      ...accounts.where((a) => a.isCustom).map((a) => _Acc(
            a.id,
            a.displayName,
            a.iconCode != null
                ? IconData(a.iconCode!, fontFamily: 'MaterialIcons')
                : Icons.savings_rounded,
          )),
    ];
  }

  Future<void> _pickAccount({required bool isFrom}) async {
    final accList = _buildAccounts();
    final currentId = isFrom ? _fromId : _toId;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AccountPickerSheet(
        title: isFrom ? AppStrings.transferFrom : AppStrings.transferTo,
        currentId: currentId,
        accounts: accList,
      ),
    );
    if (picked == null || picked == currentId) return;
    setState(() {
      if (isFrom) {
        _fromId = picked;
        if (_toId == picked) {
          _toId = accList.firstWhere((a) => a.id != picked).id;
        }
      } else {
        _toId = picked;
        if (_fromId == picked) {
          _fromId = accList.firstWhere((a) => a.id != picked).id;
        }
      }
    });
  }

  void _swap() => setState(() {
        final tmp = _fromId;
        _fromId = _toId;
        _toId = tmp;
      });

  Future<void> _confirm() async {
    final accList = _buildAccounts();
    final fromAcc = accList.firstWhere((a) => a.id == _fromId);
    final toAcc = accList.firstWhere((a) => a.id == _toId);

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final messenger = ScaffoldMessenger.of(context);

    if (amount <= 0) {
      AppToast.error(messenger, AppStrings.enterValidAmount);
      return;
    }

    // Validate balance synchronously so we can still show the error on this page.
    final fromBalance =
        ref.read(accountsProvider).firstWhere((a) => a.id == _fromId).balance;
    if (fromBalance < amount) {
      AppToast.error(messenger, 'Insufficient balance in ${fromAcc.name}');
      return;
    }

    final title = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : AppStrings.transfer;
    final note = _noteCtrl.text.trim();
    final now = _customDate ?? DateTime.now();
    final currency = ref.read(currencyProvider);

    // Show success screen in-place immediately — no navigator, no waiting.
    if (!mounted) return;
    setState(() => _successData = _SuccessData(
          amount: amount,
          currency: currency,
          fromName: fromAcc.name,
          fromIcon: fromAcc.icon,
          toName: toAcc.name,
          toIcon: toAcc.icon,
        ));

    // Fire the actual transfer in the background — balance was already
    // validated above so this will not fail due to insufficient funds.
    // Embed the counterpart account name after a null separator so history
    // can show the correct name even if the account is later deleted.
    final txOut = TransactionModel(
      id: 0,
      accountId: _fromId,
      type: 'transfer_out',
      amount: amount,
      title: title,
      note: '$note\x00${toAcc.name}',
      relatedAccountId: _toId,
      createdAt: now,
    );
    final txIn = TransactionModel(
      id: 0,
      accountId: _toId,
      type: 'transfer_in',
      amount: amount,
      title: title,
      note: '$note\x00${fromAcc.name}',
      relatedAccountId: _fromId,
      createdAt: now,
    );
    ref.read(accountsProvider.notifier).transfer(
          fromId: _fromId,
          toId: _toId,
          amount: amount,
          txOut: txOut,
          txIn: txIn,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Show success screen in-place when transfer completes.
    if (_successData != null) {
      final d = _successData!;
      return TransferSuccessPage(
        amount: d.amount,
        currency: d.currency,
        fromName: d.fromName,
        fromIcon: d.fromIcon,
        toName: d.toName,
        toIcon: d.toIcon,
        onDone: () => Navigator.pop(context),
      );
    }

    final currency = ref.watch(currencyProvider);
    final allAccounts = ref.watch(accountsProvider);
    final accList = [
      const _Acc(kWalletId, AppStrings.wallet, Icons.account_balance_wallet_rounded),
      const _Acc(kSavingsId, AppStrings.savings, Icons.savings_rounded),
      const _Acc(kBudgetId, AppStrings.monthlyBudget, Icons.receipt_long_rounded),
      ...allAccounts.where((a) => a.isCustom).map((a) => _Acc(
            a.id,
            a.displayName,
            a.iconCode != null
                ? IconData(a.iconCode!, fontFamily: 'MaterialIcons')
                : Icons.savings_rounded,
          )),
    ];

    final fromAcc = accList.firstWhere((a) => a.id == _fromId);
    final toAcc = accList.firstWhere((a) => a.id == _toId);
    final fromBalance =
        allAccounts.firstWhere((a) => a.id == _fromId).balance;

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
          AppStrings.transfer,
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: AppSizes.fontXXL,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            AppSizes.m, AppSizes.s, AppSizes.m, AppSizes.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── From / To card ─────────────────────────────────────
            SectionLabel(AppStrings.sectionAccounts),
            SizedBox(height: AppSizes.s),
            _card(
              child: Column(
                children: [
                  _AccountRow(
                    label: AppStrings.from,
                    account: fromAcc,
                    onTap: () => _pickAccount(isFrom: true),
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Divider(
                          height: 1,
                          indent: AppSizes.m,
                          endIndent: AppSizes.m,
                          color: Colors.grey[100]),
                      GestureDetector(
                        onTap: _swap,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.pageBackground,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.grey[200]!, width: 1.5),
                          ),
                          child: Icon(
                            Icons.swap_vert_rounded,
                            color: AppColors.primary,
                            size: AppSizes.iconM,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _AccountRow(
                    label: AppStrings.to,
                    account: toAcc,
                    onTap: () => _pickAccount(isFrom: false),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppSizes.m),

            // ── Amount card ─────────────────────────────────────────
            SectionLabel(AppStrings.sectionAmount),
            SizedBox(height: AppSizes.s),
            _card(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.m, vertical: AppSizes.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]')),
                            ],
                            style: const TextStyle(
                              fontFamily: 'Rubik',
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                fontFamily: 'Rubik',
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey[300],
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        SizedBox(width: AppSizes.s),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: AppSizes.s + 2,
                              vertical: AppSizes.xs + 2),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.06),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusS),
                          ),
                          child: Text(
                            currency,
                            style: TextStyle(
                              fontFamily: 'Rubik',
                              fontSize: AppSizes.fontS,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSizes.s),
                    Text(
                      'Available: ${fmtAmt(fromBalance, currency)}',
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: AppSizes.fontXS,
                        color: Colors.grey[400],
                      ),
                    ),
                    SizedBox(height: AppSizes.m),
                    Wrap(
                      spacing: AppSizes.s,
                      children: [5, 10, 20, 50, 100].map((v) {
                        return GestureDetector(
                          onTap: () => setState(
                              () => _amountCtrl.text = v.toString()),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSizes.m,
                                vertical: AppSizes.s),
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: 0.06),
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusM),
                            ),
                            child: Text(
                              '+$v',
                              style: TextStyle(
                                fontFamily: 'Rubik',
                                fontSize: AppSizes.fontS,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: AppSizes.m),

            // ── Details card ────────────────────────────────────────
            SectionLabel(AppStrings.sectionDetails),
            SizedBox(height: AppSizes.s),
            _card(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.m, vertical: AppSizes.s),
                child: Column(
                  children: [
                    _DetailField(
                      controller: _titleCtrl,
                      label: AppStrings.titleOptional,
                      hint: 'e.g. Moving to savings',
                      icon: Icons.label_outline_rounded,
                    ),
                    SizedBox(height: AppSizes.s),
                    _DetailField(
                      controller: _noteCtrl,
                      label: AppStrings.noteOptional,
                      hint: 'Additional details...',
                      icon: Icons.notes_rounded,
                    ),
                    SizedBox(height: AppSizes.s),
                    DateTimePickerField(
                      value: _customDate,
                      onChanged: (d) => setState(() => _customDate = d),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: AppSizes.m),

            // ── Summary hint ────────────────────────────────────────
            Center(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontXS,
                      color: Colors.grey[400]),
                  children: [
                    TextSpan(text: fromAcc.name),
                    const WidgetSpan(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 12, color: Colors.grey),
                      ),
                    ),
                    TextSpan(text: toAcc.name),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSizes.m),

            // ── Confirm button ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusXL)),
                ),
                child: Text(
                  AppStrings.confirmTransfer,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontM,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _card({required Widget child}) => Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );

class _AccountRow extends StatelessWidget {
  final String label;
  final _Acc account;
  final VoidCallback onTap;

  const _AccountRow({
    required this.label,
    required this.account,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppSizes.m, vertical: AppSizes.m),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
              child: Icon(account.icon,
                  color: Colors.white, size: AppSizes.iconM),
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
                      fontSize: AppSizes.fontXS,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account.name,
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontM,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.grey[400], size: AppSizes.iconM),
          ],
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  const _DetailField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          fontFamily: 'Rubik',
          fontSize: AppSizes.fontM,
          color: AppColors.primary,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon:
              Icon(icon, color: Colors.grey[400], size: AppSizes.iconM),
          labelStyle:
              TextStyle(fontFamily: 'Rubik', color: Colors.grey[400]),
          hintStyle:
              TextStyle(fontFamily: 'Rubik', color: Colors.grey[300]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: AppSizes.m, vertical: AppSizes.m),
        ),
      ),
    );
  }
}

// ── Account picker bottom sheet ───────────────────────────────────────────────

class _AccountPickerSheet extends StatelessWidget {
  final String title;
  final int currentId;
  final List<_Acc> accounts;

  const _AccountPickerSheet({
    required this.title,
    required this.currentId,
    required this.accounts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXXL)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: AppSizes.m),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          SizedBox(height: AppSizes.m),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: AppSizes.s),
          ...accounts.map((acc) {
            final selected = acc.id == currentId;
            return ListTile(
              contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSizes.l, vertical: AppSizes.xs),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: Icon(acc.icon,
                    color: selected ? Colors.white : AppColors.primary,
                    size: AppSizes.iconM),
              ),
              title: Text(
                acc.name,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontM,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              trailing: selected
                  ? Icon(Icons.check_circle_rounded,
                      color: AppColors.myGreen, size: AppSizes.iconM)
                  : null,
              onTap: () => Navigator.pop(context, acc.id),
            );
          }),
          SizedBox(height: AppSizes.l),
        ],
      ),
    );
  }
}
