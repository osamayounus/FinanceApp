import 'package:financeapp/main.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Profilepage extends ConsumerStatefulWidget {
  const Profilepage({super.key});

  @override
  ConsumerState<Profilepage> createState() => _ProfilepageState();
}

class _ProfilepageState extends ConsumerState<Profilepage> {
  bool _resetting = false;

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        ),
        title: const Text(
          AppStrings.resetApp,
          style: TextStyle(
            fontFamily: 'Rubik',
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        content: const Text(
          AppStrings.resetConfirmBody,
          style: TextStyle(
            fontFamily: 'Rubik',
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              AppStrings.cancel,
              style: TextStyle(
                fontFamily: 'Rubik',
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.myRed,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              AppStrings.reset,
              style: TextStyle(
                fontFamily: 'Rubik',
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _resetting = true);
    final db = ref.read(dbProvider);
    await db.resetDatabase();

    appConfigNotifier.value = AppConfig(
      isSetup: false,
      isFirstRun: false,
      db: db,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: AppSizes.m, vertical: AppSizes.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page title ──────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.s),
                child: const Text(
                  AppStrings.profile,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: AppSizes.m),

              // ── Avatar card ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: AppSizes.xl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.darkGradientEnd
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 34,
                            fontFamily: 'Rubik',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppSizes.m),
                    Text(
                      user.name,
                      style: TextStyle(
                        fontSize: AppSizes.fontXXL,
                        fontFamily: 'Rubik',
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: AppSizes.xs),
                    Text(
                      AppStrings.personalAccount,
                      style: TextStyle(
                        fontSize: AppSizes.fontS,
                        fontFamily: 'Rubik',
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSizes.l),

              // ── Section label ────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(bottom: AppSizes.s),
                child: SectionLabel(AppStrings.sectionPersonalInfo),
              ),

              // ── Info rows card ───────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.person_rounded,
                      iconColor: AppColors.blueIcon,
                      iconBg: AppColors.blueIconBg,
                      label: AppStrings.name,
                      value: user.name,
                      isFirst: true,
                      onTap: () => _showEditSheet(
                        context: context,
                        ref: ref,
                        title: AppStrings.editName,
                        initialValue: user.name,
                        isNumber: false,
                        onSave: (val) =>
                            ref.read(userProvider.notifier).update(name: val),
                      ),
                    ),
                    _divider(),
                    _InfoRow(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: AppColors.myGreen,
                      iconBg: AppColors.myGreen.withValues(alpha: 0.1),
                      label: AppStrings.monthlySalary,
                      value: '${user.salary.toInt()} $currency',
                      onTap: () => _showEditSheet(
                        context: context,
                        ref: ref,
                        title: AppStrings.editSalary,
                        initialValue: user.salary.toInt().toString(),
                        isNumber: true,
                        suffix: currency,
                        onSave: (val) => ref
                            .read(userProvider.notifier)
                            .update(salary: double.tryParse(val)),
                      ),
                    ),
                    _divider(),
                    _InfoRow(
                      icon: Icons.receipt_long_rounded,
                      iconColor: AppColors.myRed,
                      iconBg: AppColors.myRed.withValues(alpha: 0.1),
                      label: AppStrings.monthlyBudget,
                      value: '${user.monthlyBudget.toInt()} $currency',
                      isLast: true,
                      onTap: () => _showEditSheet(
                        context: context,
                        ref: ref,
                        title: AppStrings.editMonthlyBudget,
                        initialValue: user.monthlyBudget.toInt().toString(),
                        isNumber: true,
                        suffix: currency,
                        onSave: (val) => ref
                            .read(userProvider.notifier)
                            .update(monthlyBudget: double.tryParse(val)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSizes.l),

              // ── Danger zone label ────────────────────────────────
              Padding(
                padding: EdgeInsets.only(bottom: AppSizes.s),
                child: Padding(
                  padding: EdgeInsets.only(left: AppSizes.xs),
                  child: Text(
                    AppStrings.sectionDangerZone,
                    style: TextStyle(
                      fontSize: AppSizes.fontSection,
                      fontFamily: 'Rubik',
                      fontWeight: FontWeight.w700,
                      color: AppColors.myRed.withValues(alpha: 0.7),
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),

              // ── Reset card ───────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _resetting ? null : _confirmReset,
                    borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.m, vertical: AppSizes.m),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.myRed.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusM),
                            ),
                            child: _resetting
                                ? Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.myRed,
                                    ),
                                  )
                                : Icon(
                                    Icons.delete_sweep_rounded,
                                    color: AppColors.myRed,
                                    size: AppSizes.iconM,
                                  ),
                          ),
                          SizedBox(width: AppSizes.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.resetAppData,
                                  style: TextStyle(
                                    fontSize: AppSizes.fontM,
                                    fontFamily: 'Rubik',
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.myRed,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppStrings.eraseEverythingSubtitle,
                                  style: TextStyle(
                                    fontSize: AppSizes.fontXS,
                                    fontFamily: 'Rubik',
                                    color: Colors.grey[400],
                                  ),
                                ),
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
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.only(left: 72),
        child: Divider(height: 1, thickness: 1, color: Colors.grey[100]),
      );

  void _showEditSheet({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String initialValue,
    required bool isNumber,
    required void Function(String) onSave,
    String? suffix,
  }) {
    final ctrl = TextEditingController(text: initialValue);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSizes.xxl - 8)),
          ),
          padding: EdgeInsets.fromLTRB(
              AppSizes.l, AppSizes.m, AppSizes.l, AppSizes.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ModalHandle(),
              SizedBox(height: AppSizes.l),
              Text(
                title,
                style: TextStyle(
                  fontSize: AppSizes.fontXXL,
                  fontFamily: 'Rubik',
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: AppSizes.l),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.pageBackground,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType:
                      isNumber ? TextInputType.number : TextInputType.text,
                  inputFormatters: isNumber
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
                  style: TextStyle(
                    fontSize: AppSizes.fontXL,
                    fontFamily: 'Rubik',
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSizes.m,
                      vertical: AppSizes.m,
                    ),
                    suffixText: suffix,
                    suffixStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: AppSizes.fontM,
                      fontFamily: 'Rubik',
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: AppSizes.l),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[200]!),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusL),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppSizes.m),
                      ),
                      child: Text(
                        AppStrings.cancel,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontFamily: 'Rubik',
                          fontWeight: FontWeight.w600,
                          fontSize: AppSizes.fontM,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSizes.s + 4),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (ctrl.text.trim().isNotEmpty) {
                          onSave(ctrl.text.trim());
                        }
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusL),
                        ),
                        padding:
                            EdgeInsets.symmetric(vertical: AppSizes.m),
                      ),
                      child: Text(
                        AppStrings.save,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Rubik',
                          fontWeight: FontWeight.w600,
                          fontSize: AppSizes.fontM,
                        ),
                      ),
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

// ── Info Row Widget ───────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top:
              isFirst ? Radius.circular(AppSizes.radiusXL) : Radius.zero,
          bottom:
              isLast ? Radius.circular(AppSizes.radiusXL) : Radius.zero,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSizes.m, vertical: AppSizes.m),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: Icon(icon, color: iconColor, size: AppSizes.iconM),
              ),
              SizedBox(width: AppSizes.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: AppSizes.fontXS,
                        fontFamily: 'Rubik',
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        fontFamily: 'Rubik',
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey[300], size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
