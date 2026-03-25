import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
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

class _TransferPageState extends ConsumerState<TransferPage> {
  late int _fromId;
  late int _toId;

  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

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

  List<_Acc> get _accounts => const [
        _Acc(kWalletId, 'Wallet', Icons.account_balance_wallet_rounded),
        _Acc(kSavingsId, 'Savings', Icons.savings_rounded),
        _Acc(kBudgetId, 'Monthly Budget', Icons.receipt_long_rounded),
      ];

  _Acc get _from => _accounts.firstWhere((a) => a.id == _fromId);
  _Acc get _to => _accounts.firstWhere((a) => a.id == _toId);

  Future<void> _pickAccount({required bool isFrom}) async {
    final currentId = isFrom ? _fromId : _toId;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AccountPickerSheet(
        title: isFrom ? 'Transfer From' : 'Transfer To',
        currentId: currentId,
        accounts: _accounts,
      ),
    );
    if (picked == null || picked == currentId) return;
    setState(() {
      if (isFrom) {
        _fromId = picked;
        if (_toId == picked) {
          _toId = _accounts.firstWhere((a) => a.id != picked).id;
        }
      } else {
        _toId = picked;
        if (_fromId == picked) {
          _fromId = _accounts.firstWhere((a) => a.id != picked).id;
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
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final messenger = ScaffoldMessenger.of(context);

    if (amount <= 0) {
      AppToast.error(messenger, 'Enter a valid amount');
      return;
    }

    final title = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : 'Transfer';
    final note = _noteCtrl.text.trim();
    final now = DateTime.now();
    final amountStr = amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);

    final txOut = TransactionModel(
      id: 0,
      accountId: _fromId,
      type: 'transfer_out',
      amount: amount,
      title: title,
      note: note,
      relatedAccountId: _toId,
      createdAt: now,
    );
    final txIn = TransactionModel(
      id: 0,
      accountId: _toId,
      type: 'transfer_in',
      amount: amount,
      title: title,
      note: note,
      relatedAccountId: _fromId,
      createdAt: now,
    );

    final success = await ref.read(accountsProvider.notifier).transfer(
          fromId: _fromId,
          toId: _toId,
          amount: amount,
          txOut: txOut,
          txIn: txIn,
        );

    if (!mounted) return;
    if (!success) {
      AppToast.error(messenger, 'Insufficient balance in ${_from.name}');
      return;
    }

    AppToast.success(
        messenger, '$amountStr JOD transferred to ${_to.name}');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final fromBalance =
        accounts.firstWhere((a) => a.id == _fromId).balance;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.primary, size: AppSizes.iconM),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Transfer',
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: AppSizes.fontXXL,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSizes.m, AppSizes.s, AppSizes.m, AppSizes.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── From / To card ─────────────────────────────────────
            _SectionLabel('Accounts'),
            const SizedBox(height: AppSizes.s),
            _card(
              child: Column(
                children: [
                  _AccountRow(
                    label: 'From',
                    account: _from,
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
                            color: const Color(0xFFF2F3F7),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.grey[200]!, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.swap_vert_rounded,
                            color: AppColors.primary,
                            size: AppSizes.iconM,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _AccountRow(
                    label: 'To',
                    account: _to,
                    onTap: () => _pickAccount(isFrom: false),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.m),

            // ── Amount card ─────────────────────────────────────────
            _SectionLabel('Amount'),
            const SizedBox(height: AppSizes.s),
            _card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
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
                        const SizedBox(width: AppSizes.s),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.s + 2,
                              vertical: AppSizes.xs + 2),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.06),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusS),
                          ),
                          child: const Text(
                            'JOD',
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
                    const SizedBox(height: AppSizes.s),
                    Text(
                      'Available: ${fromBalance % 1 == 0 ? fromBalance.toInt() : fromBalance.toStringAsFixed(2)} JOD',
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: AppSizes.fontXS,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: AppSizes.m),
                    Wrap(
                      spacing: AppSizes.s,
                      children: [5, 10, 20, 50, 100].map((v) {
                        return GestureDetector(
                          onTap: () => setState(
                              () => _amountCtrl.text = v.toString()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
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
                              style: const TextStyle(
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

            const SizedBox(height: AppSizes.m),

            // ── Details card ────────────────────────────────────────
            _SectionLabel('Details'),
            const SizedBox(height: AppSizes.s),
            _card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.m, vertical: AppSizes.s),
                child: Column(
                  children: [
                    _DetailField(
                      controller: _titleCtrl,
                      label: 'Title (optional)',
                      hint: 'e.g. Moving to savings',
                      icon: Icons.label_outline_rounded,
                    ),
                    const SizedBox(height: AppSizes.s),
                    _DetailField(
                      controller: _noteCtrl,
                      label: 'Note (optional)',
                      hint: 'Additional details...',
                      icon: Icons.notes_rounded,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSizes.m),

            // ── Summary hint ────────────────────────────────────────
            Center(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontXS,
                      color: Colors.grey[400]),
                  children: [
                    TextSpan(text: _from.name),
                    const WidgetSpan(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 12, color: Colors.grey),
                      ),
                    ),
                    TextSpan(text: _to.name),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.m),

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
                child: const Text(
                  'Confirm Transfer',
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Rubik',
          fontSize: AppSizes.fontXS,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: Colors.grey[400],
        ),
      );
}

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
        padding: const EdgeInsets.symmetric(
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
            const SizedBox(width: AppSizes.m),
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
                    style: const TextStyle(
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
        color: const Color(0xFFF2F3F7),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
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
          contentPadding: const EdgeInsets.symmetric(
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXXL)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSizes.m),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: AppSizes.m),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSizes.s),
          ...accounts.map((acc) {
            final selected = acc.id == currentId;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
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
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.myGreen, size: AppSizes.iconM)
                  : null,
              onTap: () => Navigator.pop(context, acc.id),
            );
          }),
          const SizedBox(height: AppSizes.l),
        ],
      ),
    );
  }
}
