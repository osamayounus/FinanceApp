import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Data ─────────────────────────────────────────────────────────────────────

class _Account {
  final String name;
  final IconData icon;
  const _Account(this.name, this.icon);
}

const List<_Account> _kAccounts = [
  _Account('Income Account', Icons.account_balance_wallet_rounded),
  _Account('Saving Account', Icons.savings_rounded),
  _Account('Monthly Expenses', Icons.receipt_long_rounded),
];

// ── Page ─────────────────────────────────────────────────────────────────────

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  String _from = _kAccounts[0].name;
  String _to = _kAccounts[1].name;

  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  // ── Account picker sheet ──────────────────────────────────────────────────

  Future<void> _pickAccount({required bool isFrom}) async {
    final current = isFrom ? _from : _to;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AccountPickerSheet(
        title: isFrom ? 'Transfer From' : 'Transfer To',
        current: current,
      ),
    );
    if (picked == null || picked == current) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to == picked) _to = _kAccounts.firstWhere((a) => a.name != picked).name;
      } else {
        _to = picked;
        if (_from == picked) _from = _kAccounts.firstWhere((a) => a.name != picked).name;
      }
    });
  }

  // ── Swap ──────────────────────────────────────────────────────────────────

  void _swap() => setState(() {
        final tmp = _from;
        _from = _to;
        _to = tmp;
      });

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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusM)),
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
    final fromAcc = _kAccounts.firstWhere((a) => a.name == _from);
    final toAcc = _kAccounts.firstWhere((a) => a.name == _to);

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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSizes.m, AppSizes.s, AppSizes.m, AppSizes.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── From / To card ──────────────────────────────────────
            _SectionLabel('Accounts'),
            const SizedBox(height: AppSizes.s),
            _card(
              child: Column(
                children: [
                  _AccountRow(
                    label: 'From',
                    account: fromAcc,
                    onTap: () => _pickAccount(isFrom: true),
                  ),
                  // Divider + swap button
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
                    account: toAcc,
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
                            autofocus: false,
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
                            color: AppColors.primary.withValues(alpha: 0.06),
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
                    const SizedBox(height: AppSizes.m),
                    // Quick amount chips
                    Wrap(
                      spacing: AppSizes.s,
                      children: [5, 10, 20, 50, 100].map((v) {
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _amountCtrl.text = v.toString()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.m, vertical: AppSizes.s),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.06),
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

            const Spacer(),

            // ── Summary hint ────────────────────────────────────────
            Center(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontXS,
                      color: Colors.grey[400]),
                  children: [
                    TextSpan(text: _from),
                    const WidgetSpan(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 12, color: Colors.grey),
                      ),
                    ),
                    TextSpan(text: _to),
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
  final _Account account;
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
              child: Icon(account.icon, color: Colors.white, size: AppSizes.iconM),
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

// ── Account picker bottom sheet ───────────────────────────────────────────────

class _AccountPickerSheet extends StatelessWidget {
  final String title;
  final String current;

  const _AccountPickerSheet({required this.title, required this.current});

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
          ..._kAccounts.map((acc) {
            final selected = acc.name == current;
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
              onTap: () => Navigator.pop(context, acc.name),
            );
          }),
          const SizedBox(height: AppSizes.l),
        ],
      ),
    );
  }
}
