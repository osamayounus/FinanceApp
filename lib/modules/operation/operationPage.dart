// ── OperationPage ─────────────────────────────────────────────────────────────
// Three-step wizard for depositing or withdrawing from any account:
//   Step 0 – pick the target account
//   Step 1 – choose operation type (Deposit / Withdraw)
//   Step 2 – enter amount + optional title/note, then confirm
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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Account display model ──────────────────────────────────────────────────────

class _Account {
  final int id;
  final String name;
  final IconData icon;
  final double balance;       // available
  final double loanedAmount;  // lent out
  const _Account(this.id, this.name, this.icon, this.balance, this.loanedAmount);
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
  DateTime? _customDate;

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
    final currency = ref.read(currencyProvider);

    if (amount <= 0) {
      AppToast.error(messenger, AppStrings.enterValidAmount);
      return;
    }

    // Debt repayment cannot exceed the outstanding loaned amount.
    if (_operation == 'debt_repaid') {
      final live = ref.read(accountsProvider)
          .firstWhere((a) => a.id == _account!.id);
      if (live.loanedAmount <= 0) {
        AppToast.error(messenger, 'No outstanding debt on ${_account!.name}');
        return;
      }
      if (amount > live.loanedAmount) {
        AppToast.error(
          messenger,
          'Cannot exceed outstanding: ${fmtAmt(live.loanedAmount, currency)}',
        );
        return;
      }
    }

    final defaultTitle = switch (_operation) {
      'deposit'     => AppStrings.deposit,
      'withdraw'    => AppStrings.withdraw,
      'debt_out'    => 'Debt Given',
      'debt_repaid' => 'Debt Received',
      _             => AppStrings.deposit,
    };
    final title = _titleCtrl.text.trim().isNotEmpty
        ? _titleCtrl.text.trim()
        : defaultTitle;
    final note = _noteCtrl.text.trim();
    final amountStr = fmtAmt(amount, currency);

    final tx = TransactionModel(
      id: 0,
      accountId: _account!.id,
      type: _operation!,
      amount: amount,
      title: title,
      note: note,
      createdAt: _customDate ?? DateTime.now(),
    );

    bool success;
    switch (_operation) {
      case 'deposit':
        await ref.read(accountsProvider.notifier).deposit(_account!.id, amount, tx);
        success = true;
      case 'withdraw':
        success = await ref.read(accountsProvider.notifier).withdraw(_account!.id, amount, tx);
      case 'debt_out':
        success = await ref.read(accountsProvider.notifier).lendDebt(_account!.id, amount, tx);
      case 'debt_repaid':
        success = await ref.read(accountsProvider.notifier).repayDebt(_account!.id, amount, tx);
      default:
        success = false;
    }

    if (!mounted) return;
    if (!success) {
      final msg = _operation == 'debt_out'
          ? 'Insufficient balance in ${_account!.name}'
          : 'No outstanding debt in ${_account!.name}';
      AppToast.error(messenger, msg);
      return;
    }

    final toastMsg = switch (_operation) {
      'deposit'     => '+ $amountStr deposited to ${_account!.name}',
      'withdraw'    => '- $amountStr withdrawn from ${_account!.name}',
      'debt_out'    => '$amountStr lent from ${_account!.name}',
      'debt_repaid' => '$amountStr received back into ${_account!.name}',
      _             => 'Done',
    };
    AppToast.success(messenger, toastMsg);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final accounts = ref.watch(accountsProvider);

    final List<_Account> accList = [
      _Account(
        kWalletId,
        AccountType.wallet.displayName,
        Icons.account_balance_wallet_rounded,
        accounts.firstWhere((a) => a.id == kWalletId).balance,
        accounts.firstWhere((a) => a.id == kWalletId).loanedAmount,
      ),
      _Account(
        kSavingsId,
        AccountType.savings.displayName,
        Icons.savings_rounded,
        accounts.firstWhere((a) => a.id == kSavingsId).balance,
        accounts.firstWhere((a) => a.id == kSavingsId).loanedAmount,
      ),
      _Account(
        kBudgetId,
        AccountType.budget.displayName,
        Icons.receipt_long_rounded,
        accounts.firstWhere((a) => a.id == kBudgetId).balance,
        accounts.firstWhere((a) => a.id == kBudgetId).loanedAmount,
      ),
      ...accounts.where((a) => a.isCustom).map((a) => _Account(
            a.id,
            a.displayName,
            a.iconCode != null
                ? IconData(a.iconCode!, fontFamily: 'MaterialIcons')
                : Icons.savings_rounded,
            a.balance,
            a.loanedAmount,
          )),
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
                  currency: currency,
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
                  currency: currency,
                  amountCtrl: _amountCtrl,
                  titleCtrl: _titleCtrl,
                  noteCtrl: _noteCtrl,
                  customDate: _customDate,
                  onDateChanged: (d) => setState(() => _customDate = d),
                  onBack: _back,
                  onConfirm: _confirm,
                  loanedAmount: _account!.loanedAmount,
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
  final String currency;
  final VoidCallback onBack;
  final void Function(_Account) onSelect;

  const _StepAccount({
    required this.accounts,
    required this.currency,
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
            AppStrings.chooseAccount,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontTitle,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: AppSizes.s),
          Text(
            AppStrings.chooseAccountSubtitle,
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
              child: _AccountCard(account: acc, currency: currency, onTap: () => onSelect(acc)),
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
            AppStrings.chooseOperation,
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
          // ── Main operations ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _OperationButton(
                  label: AppStrings.deposit,
                  bg: AppColors.myGreen,
                  textColor: AppColors.primary,
                  onTap: () => onSelect('deposit'),
                ),
              ),
              SizedBox(width: AppSizes.s),
              Expanded(
                child: _OperationButton(
                  label: AppStrings.withdraw,
                  bg: AppColors.myRed.withValues(alpha: 0.15),
                  textColor: AppColors.myRed,
                  onTap: () => onSelect('withdraw'),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.s),
          // ── Debt operations ───────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _OperationButton(
                  label: 'Give Debt',
                  bg: const Color(0xFFFFB300).withValues(alpha: 0.15),
                  textColor: const Color(0xFFFF8F00),
                  onTap: () => onSelect('debt_out'),
                ),
              ),
              SizedBox(width: AppSizes.s),
              Expanded(
                child: _OperationButton(
                  label: 'Receive Back',
                  bg: account.loanedAmount > 0
                      ? Colors.teal.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.08),
                  textColor: account.loanedAmount > 0
                      ? Colors.teal
                      : Colors.grey[400]!,
                  onTap: account.loanedAmount > 0
                      ? () => onSelect('debt_repaid')
                      : () {},
                ),
              ),
            ],
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
  final String currency;
  final TextEditingController amountCtrl;
  final TextEditingController titleCtrl;
  final TextEditingController noteCtrl;
  final DateTime? customDate;
  final ValueChanged<DateTime?> onDateChanged;
  final VoidCallback onBack;
  final VoidCallback onConfirm;
  final double loanedAmount;

  const _StepAmount({
    required this.account,
    required this.operation,
    required this.currency,
    required this.amountCtrl,
    required this.titleCtrl,
    required this.noteCtrl,
    required this.customDate,
    required this.onDateChanged,
    required this.onBack,
    required this.onConfirm,
    required this.loanedAmount,
  });

  bool get _isDeposit   => operation == 'deposit';
  bool get _isDebtOut   => operation == 'debt_out';
  bool get _isDebtBack  => operation == 'debt_repaid';

  Color get _accentColor {
    if (_isDeposit) return AppColors.myGreen;
    if (_isDebtOut) return const Color(0xFFFF8F00);
    if (_isDebtBack) return Colors.teal;
    return AppColors.myRed;
  }

  Color get _fieldBg => _accentColor.withValues(alpha: _isDeposit ? 0.12 : 0.10);

  Color get _amtTextColor {
    if (_isDeposit) return AppColors.primary;
    return _accentColor;
  }

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
            AppStrings.enterAmount,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontTitle,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: AppSizes.s),
          Text(
            () {
              if (_isDeposit) return 'Deposit into ${account.name}:';
              if (_isDebtOut) return 'Lend from ${account.name}:';
              if (_isDebtBack) return 'Receive back into ${account.name}:';
              return 'Withdraw from ${account.name}:';
            }(),
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
                color: _amtTextColor,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontL,
                  color: _accentColor.withValues(alpha: 0.4),
                ),
                suffix: Text(
                  currency,
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
          SizedBox(height: AppSizes.s),
          // Available / Outstanding hint
          if (!_isDeposit)
            Padding(
              padding: EdgeInsets.only(left: AppSizes.xs),
              child: Text(
                _isDebtBack
                    ? 'Outstanding: ${fmtAmt(loanedAmount, currency)}'
                    : 'Available: ${fmtAmt(account.balance, currency)}',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontXS,
                  color: Colors.grey[400],
                ),
              ),
            ),
          SizedBox(height: AppSizes.m),

          // Title field
          _DetailField(
            controller: titleCtrl,
            label: AppStrings.titleOptional,
            hint: _isDeposit
                ? 'e.g. Freelance payment'
                : _isDebtOut
                    ? 'e.g. Lent to Ali'
                    : _isDebtBack
                        ? 'e.g. Ali paid back'
                        : 'e.g. Grocery shopping',
            icon: Icons.label_outline_rounded,
          ),
          SizedBox(height: AppSizes.s + 4),

          // Note field
          _DetailField(
            controller: noteCtrl,
            label: AppStrings.noteOptional,
            hint: 'Additional details...',
            icon: Icons.notes_rounded,
          ),
          SizedBox(height: AppSizes.s + 4),

          // Date & Time
          DateTimePickerField(
            value: customDate,
            onChanged: onDateChanged,
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
                AppStrings.confirmOperation,
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
  final String currency;
  final VoidCallback onTap;
  const _AccountCard({required this.account, required this.currency, required this.onTap});

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
              colors: [AppColors.primary, AppColors.darkGradientEnd],
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
                        text: currency,
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
