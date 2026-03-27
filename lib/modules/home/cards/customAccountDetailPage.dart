import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/modules/home/cards/customAccountCard.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomAccountDetailPage extends ConsumerStatefulWidget {
  final AccountModel account;
  const CustomAccountDetailPage({super.key, required this.account});

  @override
  ConsumerState<CustomAccountDetailPage> createState() =>
      _CustomAccountDetailPageState();
}

class _CustomAccountDetailPageState
    extends ConsumerState<CustomAccountDetailPage> {
  late final TextEditingController _nameCtrl;
  late int _selectedColor;
  late int _selectedIcon;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.account.customName ?? '');
    _selectedColor =
        (widget.account.colorIndex ?? 0).clamp(0, kCustomAccountColors.length - 1);
    _selectedIcon = _findIconIndex(widget.account.iconCode);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int _findIconIndex(int? code) {
    if (code == null) return 0;
    for (int i = 0; i < kCustomAccountIcons.length; i++) {
      if (kCustomAccountIcons[i].codePoint == code) return i;
    }
    return 0;
  }

  bool get _hasChanges {
    final nameDiff = _nameCtrl.text.trim() != (widget.account.customName ?? '');
    final colorDiff = _selectedColor != (widget.account.colorIndex ?? 0);
    final iconDiff = kCustomAccountIcons[_selectedIcon].codePoint !=
        (widget.account.iconCode ?? kCustomAccountIcons[0].codePoint);
    return nameDiff || colorDiff || iconDiff;
  }

  List<Color> get _currentGradient => [
        kCustomAccountColors[_selectedColor][0],
        kCustomAccountColors[_selectedColor][1],
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            // ── Gradient header ────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _currentGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.s, vertical: AppSizes.s),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: AppSizes.iconM),
                    ),
                    Expanded(
                      child: Text(
                        _nameCtrl.text.trim().isEmpty
                            ? AppStrings.accountDetails
                            : _nameCtrl.text.trim(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontXXL,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // ── Form ───────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSizes.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: AppSizes.s),

                    // ── Account name ─────────────────────────────
                    SectionLabel(AppStrings.sectionAccountName),
                    SizedBox(height: AppSizes.s),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusL),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontM,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        decoration: InputDecoration(
                          hintText: AppStrings.accountName,
                          hintStyle: TextStyle(
                              fontFamily: 'Rubik', color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSizes.m, vertical: AppSizes.m),
                        ),
                      ),
                    ),
                    SizedBox(height: AppSizes.l),

                    // ── Color ────────────────────────────────────
                    SectionLabel(AppStrings.sectionColor),
                    SizedBox(height: AppSizes.s),
                    Container(
                      padding: EdgeInsets.all(AppSizes.m),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusL),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          kCustomAccountColors.length,
                          (i) {
                            final selected = i == _selectedColor;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedColor = i),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      kCustomAccountColors[i][0],
                                      kCustomAccountColors[i][1],
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: selected
                                      ? Border.all(
                                          color: AppColors.primary,
                                          width: 2.5)
                                      : null,
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: kCustomAccountColors[i]
                                                    [0]
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          )
                                        ]
                                      : null,
                                ),
                                child: selected
                                    ? Icon(Icons.check_rounded,
                                        color: Colors.white, size: 16)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: AppSizes.l),

                    // ── Icon ─────────────────────────────────────
                    SectionLabel(AppStrings.sectionIcon),
                    SizedBox(height: AppSizes.s),
                    Container(
                      padding: EdgeInsets.all(AppSizes.m),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusL),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Wrap(
                        spacing: AppSizes.s,
                        runSpacing: AppSizes.s,
                        children: List.generate(
                          kCustomAccountIcons.length,
                          (i) {
                            final selected = i == _selectedIcon;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedIcon = i),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? _currentGradient[0]
                                          .withValues(alpha: 0.12)
                                      : AppColors.pageBackground,
                                  borderRadius: BorderRadius.circular(
                                      AppSizes.radiusM),
                                  border: selected
                                      ? Border.all(
                                          color: _currentGradient[0],
                                          width: 1.5)
                                      : null,
                                ),
                                child: Icon(
                                  kCustomAccountIcons[i],
                                  size: 20,
                                  color: selected
                                      ? _currentGradient[0]
                                      : Colors.grey[400],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: AppSizes.l),

                    // ── Save button ───────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.buttonHeight,
                      child: ElevatedButton(
                        onPressed:
                            (_saving || !_hasChanges) ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.3),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSizes.radiusL)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : Text(
                                AppStrings.saveChanges,
                                style: TextStyle(
                                  fontFamily: 'Rubik',
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppSizes.fontM,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: AppSizes.l),

                    // ── Danger zone ───────────────────────────────
                    SectionLabel(AppStrings.sectionDangerZone),
                    SizedBox(height: AppSizes.s),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusL),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _handleDelete(context),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusL),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSizes.m,
                                vertical: AppSizes.m),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                        AppSizes.radiusM),
                                  ),
                                  child: Icon(
                                      Icons.delete_sweep_rounded,
                                      color: Colors.redAccent,
                                      size: AppSizes.iconM),
                                ),
                                SizedBox(width: AppSizes.m),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(AppStrings.deleteAccount,
                                          style: TextStyle(
                                            fontFamily: 'Rubik',
                                            fontSize: AppSizes.fontM,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.redAccent,
                                          )),
                                      SizedBox(height: 2),
                                      Text(AppStrings.removeAccountSubtitle,
                                          style: TextStyle(
                                            fontFamily: 'Rubik',
                                            fontSize: AppSizes.fontXS,
                                            color: Colors.grey[400],
                                          )),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color: Colors.grey[300], size: 22),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppSizes.l),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(accountsProvider.notifier).updateCustomAccount(
          widget.account.id,
          name,
          _selectedColor,
          kCustomAccountIcons[_selectedIcon].codePoint,
        );
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final hasBalance = widget.account.balance > 0;

    if (!hasBalance) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
          title: const Text(AppStrings.deleteAccount,
              style: TextStyle(
                  fontFamily: 'Rubik', fontWeight: FontWeight.bold)),
          content: Text(
            'Delete "${widget.account.displayName}"? This cannot be undone.',
            style: const TextStyle(fontFamily: 'Rubik', height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.cancel,
                  style: TextStyle(
                      fontFamily: 'Rubik', color: Colors.grey[500])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusM)),
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
      if (confirmed == true && context.mounted) {
        await ref
            .read(accountsProvider.notifier)
            .deleteCustomAccount(widget.account.id);
        if (context.mounted) Navigator.pop(context);
      }
      return;
    }

    // Has balance — ask what to do
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
        title: const Text(AppStrings.deleteAccount,
            style: TextStyle(
                fontFamily: 'Rubik', fontWeight: FontWeight.bold)),
        content: Text(
          'This account has ${fmtAmt(widget.account.balance, ref.read(currencyProvider))} remaining.\nWhat do you want to do with it?',
          style: const TextStyle(fontFamily: 'Rubik', height: 1.6),
        ),
        actionsAlignment: MainAxisAlignment.start,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.account_balance_wallet_rounded,
                  size: 18, color: Colors.white),
              label: const Text(AppStrings.transferToWallet,
                  style: TextStyle(
                      fontFamily: 'Rubik',
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusM)),
              ),
              onPressed: () => Navigator.pop(ctx, 'transfer'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: Colors.redAccent),
              label: const Text(AppStrings.discardBalance,
                  style: TextStyle(
                      fontFamily: 'Rubik',
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusM)),
              ),
              onPressed: () => Navigator.pop(ctx, 'discard'),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(AppStrings.cancel,
                  style: TextStyle(
                      fontFamily: 'Rubik', color: Colors.grey[500])),
            ),
          ),
        ],
      ),
    );

    if (choice == null || !context.mounted) return;
    await ref.read(accountsProvider.notifier).deleteCustomAccount(
          widget.account.id,
          transferToWallet: choice == 'transfer',
        );
    if (context.mounted) Navigator.pop(context);
  }
}
