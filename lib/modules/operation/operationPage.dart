import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Account model ─────────────────────────────────────────────────────────────

class _Account {
  final String name;
  final IconData icon;
  final int balance;
  const _Account(this.name, this.icon, this.balance);
}

// ── Page ─────────────────────────────────────────────────────────────────────

class OperationPage extends ConsumerStatefulWidget {
  const OperationPage({super.key});

  @override
  ConsumerState<OperationPage> createState() => _OperationPageState();
}

class _OperationPageState extends ConsumerState<OperationPage> {
  int _step = 0; // 0 → account, 1 → operation, 2 → amount

  _Account? _account;
  String? _operation; // 'deposit' | 'withdraw'

  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _next() => setState(() => _step++);

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  // ── Confirm ───────────────────────────────────────────────────────────────

  void _confirm() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter a valid amount',
              style: TextStyle(fontFamily: 'Rubik')),
          backgroundColor: AppColors.myRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusM)),
        ),
      );
      return;
    }
    // TODO: wire to state management
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    final List<_Account> accounts = [
      _Account('Income Account', Icons.account_balance_wallet_rounded,
          profile.income),
      const _Account('Saving Account', Icons.savings_rounded, 1000),
      _Account('Monthly Expenses', Icons.receipt_long_rounded,
          profile.expenses),
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
                  accounts: accounts,
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
                    _next();
                  },
                ),
              _ => _StepAmount(
                  account: _account!,
                  operation: _operation!,
                  controller: _amountCtrl,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.s),
          _BackButton(onBack: onBack),
          const SizedBox(height: AppSizes.l),
          const Text(
            'Choose the account',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontTitle,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSizes.s),
          Text(
            'Select the account on which you want\nto perform the operation:',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontS,
              color: Colors.grey[400],
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          ...accounts.map(
            (acc) => Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.m),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.s),
          _BackButton(onBack: onBack),
          const SizedBox(height: AppSizes.l),
          const Text(
            'Choose the operation',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontTitle,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSizes.s),
          Text(
            'Select the operation you want to perform:',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontS,
              color: Colors.grey[400],
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSizes.xl),

          // ── Deposit ──────────────────────────────────────────────
          _OperationButton(
            label: 'Deposit',
            bg: AppColors.myGreen,
            textColor: AppColors.primary,
            onTap: () => onSelect('deposit'),
          ),
          const SizedBox(height: AppSizes.m),

          // ── Withdraw ─────────────────────────────────────────────
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

// ── Step 2 — Enter amount ─────────────────────────────────────────────────────

class _StepAmount extends StatelessWidget {
  final _Account account;
  final String operation;
  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  const _StepAmount({
    required this.account,
    required this.operation,
    required this.controller,
    required this.onBack,
    required this.onConfirm,
  });

  bool get _isDeposit => operation == 'deposit';

  Color get _accentColor =>
      _isDeposit ? AppColors.myGreen : AppColors.myRed;

  Color get _fieldBg => _isDeposit
      ? AppColors.myGreen.withValues(alpha: 0.12)
      : AppColors.myRed.withValues(alpha: 0.10);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.s),
          _BackButton(onBack: onBack),
          const SizedBox(height: AppSizes.l),
          const Text(
            'Enter the amount',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontTitle,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSizes.s),
          Text(
            'Enter the amount you want to '
            '${_isDeposit ? 'deposit' : 'withdraw'}:',
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontS,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: AppSizes.xl),

          // ── Amount field ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            child: TextField(
              controller: controller,
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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.m, vertical: AppSizes.m),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.l),

          // ── Confirm button ────────────────────────────────────────
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
              child: const Text(
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
      icon: const Icon(
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
            padding: const EdgeInsets.symmetric(
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
                const SizedBox(width: AppSizes.m),
                Expanded(
                  child: Text(
                    account.name,
                    style: const TextStyle(
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
                        text: '${account.balance} ',
                        style: const TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontL,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const TextSpan(
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
