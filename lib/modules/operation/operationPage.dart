import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Account display model ──────────────────────────────────────────────────────

class _Account {
  final int id;
  final String name;
  final IconData icon;
  final double balance;
  const _Account(this.id, this.name, this.icon, this.balance);
}

// ── Page ──────────────────────────────────────────────────────────────────────

class OperationPage extends ConsumerStatefulWidget {
  const OperationPage({super.key});

  @override
  ConsumerState<OperationPage> createState() => _OperationPageState();
}

class _OperationPageState extends ConsumerState<OperationPage> {
  int _step = 0; // 0=account, 1=operation, 2=amount+details

  _Account? _account;
  String? _operation; // 'deposit' | 'withdraw'

  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step++);

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _confirm() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final messenger = ScaffoldMessenger.of(context);

    if (amount <= 0) {
      AppToast.error(messenger, 'Enter a valid amount');
      return;
    }

    final title = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : (_operation == 'deposit' ? 'Deposit' : 'Withdraw');
    final note = _noteCtrl.text.trim();
    final isDeposit = _operation == 'deposit';
    final amountStr = amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);

    final tx = TransactionModel(
      id: 0,
      accountId: _account!.id,
      type: isDeposit ? 'deposit' : 'withdraw',
      amount: amount,
      title: title,
      note: note,
      createdAt: DateTime.now(),
    );

    bool success;
    if (isDeposit) {
      await ref.read(accountsProvider.notifier).deposit(_account!.id, amount, tx);
      success = true;
    } else {
      success = await ref.read(accountsProvider.notifier).withdraw(_account!.id, amount, tx);
    }

    if (!mounted) return;
    if (!success) {
      AppToast.error(messenger, 'Insufficient balance in ${_account!.name}');
      return;
    }

    AppToast.success(
      messenger,
      isDeposit
          ? '+ $amountStr JOD deposited to ${_account!.name}'
          : '- $amountStr JOD withdrawn from ${_account!.name}',
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);

    final List<_Account> accList = [
      _Account(
        kWalletId,
        AccountType.wallet.displayName,
        Icons.account_balance_wallet_rounded,
        accounts.firstWhere((a) => a.id == kWalletId).balance,
      ),
      _Account(
        kSavingsId,
        AccountType.savings.displayName,
        Icons.savings_rounded,
        accounts.firstWhere((a) => a.id == kSavingsId).balance,
      ),
      _Account(
        kBudgetId,
        AccountType.budget.displayName,
        Icons.receipt_long_rounded,
        accounts.firstWhere((a) => a.id == kBudgetId).balance,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: switch (_step) {
              0 => _StepAccount(
                  accounts: accList,
                  onBack: _back,
                  onSelect: (acc) {
                    _account = acc;
                    _next();
                  },
                ),
              1 => _StepOperation(
                  account: _account!,
                  onBack: _back,
                  onSelect: (op) {
                    _operation = op;
                    _amountCtrl.clear();
                    _titleCtrl.clear();
                    _noteCtrl.clear();
                    _next();
                  },
                ),
              _ => _StepAmount(
                  account: _account!,
                  operation: _operation!,
                  amountCtrl: _amountCtrl,
                  titleCtrl: _titleCtrl,
                  noteCtrl: _noteCtrl,
                  onBack: _back,
                  onConfirm: _confirm,
                ),
            },
          ),
        ),
      ),
    );
  }
}

// ── Step 0 — Choose account ───────────────────────────────────────────────────

class _StepAccount extends StatelessWidget {
  final List<_Account> accounts;
  final VoidCallback onBack;
  final void Function(_Account) onSelect;

  const _StepAccount({
    required this.accounts,
    required this.onBack,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppSizes.s),
          _BackButton(onBack: onBack),
          SizedBox(height: AppSizes.l),
          Text(
            'Choose the account',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontTitle,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: AppSizes.s),
          Text(
            'Select the account you want to\nperform the operation on:',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontS,
              color: Colors.grey[400],
              height: 1.5,
            ),
          ),
          SizedBox(height: AppSizes.xl),
          ...accounts.map(
            (acc) => Padding(
              padding: EdgeInsets.only(bottom: AppSizes.m),
              child: _AccountCard(account: acc, onTap: () => onSelect(acc)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1 — Choose operation ─────────────────────────────────────────────────

class _StepOperation extends StatelessWidget {
  final _Account account;
  final VoidCallback onBack;
  final void Function(String) onSelect;

  const _StepOperation({
    required this.account,
    required this.onBack,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppSizes.s),
          _BackButton(onBack: onBack),
          SizedBox(height: AppSizes.l),
          Text(
            'Choose the operation',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontTitle,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: AppSizes.s),
          Text(
            'Select what you want to do on\n${account.name}:',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontS,
              color: Colors.grey[400],
              height: 1.5,
            ),
          ),
          SizedBox(height: AppSizes.xl),
          _OperationButton(
            label: 'Deposit',
            bg: AppColors.myGreen,
            textColor: AppColors.primary,
            onTap: () => onSelect('deposit'),
          ),
          SizedBox(height: AppSizes.m),
          _OperationButton(
            label: 'Withdraw',
            bg: AppColors.myRed.withValues(alpha: 0.15),
            textColor: AppColors.myRed,
            onTap: () => onSelect('withdraw'),
          ),
        ],
      ),
    );
  }
}

// ── Step 2 — Enter amount + details ───────────────────────────────────────────

class _StepAmount extends StatelessWidget {
  final _Account account;
  final String operation;
  final TextEditingController amountCtrl;
  final TextEditingController titleCtrl;
  final TextEditingController noteCtrl;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  const _StepAmount({
    required this.account,
    required this.operation,
    required this.amountCtrl,
    required this.titleCtrl,
    required this.noteCtrl,
    required this.onBack,
    required this.onConfirm,
  });

  bool get _isDeposit => operation == 'deposit';
  Color get _accentColor => _isDeposit ? AppColors.myGreen : AppColors.myRed;
  Color get _fieldBg => _isDeposit
      ? AppColors.myGreen.withValues(alpha: 0.12)
      : AppColors.myRed.withValues(alpha: 0.10);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppSizes.s),
          _BackButton(onBack: onBack),
          SizedBox(height: AppSizes.l),
          Text(
            'Enter the amount',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontTitle,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: AppSizes.s),
          Text(
            'Enter the amount you want to '
            '${_isDeposit ? 'deposit into' : 'withdraw from'} ${account.name}:',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontS,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: AppSizes.xl),

          // Amount field
          Container(
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            child: TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: TextStyle(
                fontFamily: 'Rubik',
                fontSize: AppSizes.fontL,
                fontWeight: FontWeight.bold,
                color: _isDeposit ? AppColors.primary : AppColors.myRed,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontL,
                  color: _accentColor.withValues(alpha: 0.4),
                ),
                suffix: Text(
                  'JOD',
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontWeight: FontWeight.w600,
                    color: _accentColor.withValues(alpha: 0.6),
                  ),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSizes.m, vertical: AppSizes.m),
              ),
            ),
          ),
          SizedBox(height: AppSizes.m),

          // Title field
          _DetailField(
            controller: titleCtrl,
            label: 'Title (optional)',
            hint: _isDeposit ? 'e.g. Freelance payment' : 'e.g. Grocery shopping',
            icon: Icons.label_outline_rounded,
          ),
          SizedBox(height: AppSizes.s + 4),

          // Note field
          _DetailField(
            controller: noteCtrl,
            label: 'Note (optional)',
            hint: 'Additional details...',
            icon: Icons.notes_rounded,
          ),
          SizedBox(height: AppSizes.l),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeight,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusXL)),
              ),
              child: Text(
                'Confirm',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontM,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: AppSizes.l),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  final VoidCallback onBack;
  const _BackButton({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onBack,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        color: AppColors.primary,
        size: AppSizes.iconM,
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final _Account account;
  final VoidCallback onTap;
  const _AccountCard({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF1A1D4A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: AppSizes.m, vertical: AppSizes.m),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: Icon(account.icon,
                      color: Colors.white70, size: AppSizes.iconM),
                ),
                SizedBox(width: AppSizes.m),
                Expanded(
                  child: Text(
                    account.name,
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontM,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '${account.balance % 1 == 0 ? account.balance.toInt() : account.balance.toStringAsFixed(2)} ',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontL,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: 'JOD',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontXS,
                          fontWeight: FontWeight.w500,
                          color: Colors.white60,
                        ),
                      ),
                    ],
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

class _OperationButton extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;
  final VoidCallback onTap;

  const _OperationButton({
    required this.label,
    required this.bg,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeight + 8,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusXXL)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: AppSizes.fontL,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
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
        style: TextStyle(
          fontFamily: 'Rubik',
          fontSize: AppSizes.fontM,
          color: AppColors.primary,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey[400], size: AppSizes.iconM),
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
