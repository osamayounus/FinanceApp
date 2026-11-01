// ── ProfilePage ───────────────────────────────────────────────────────────────
// Settings and personal-info page (rightmost tab). Lets the user edit name,
// salary, budget and currency, and contains a danger-zone section for
// resetting all app data back to the onboarding state.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:financeapp/main.dart';
import 'package:financeapp/shared/overlays/profile_deleted_overlay.dart';
import 'package:financeapp/modules/profile/profile_picker_page.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:financeapp/shared/networks/local/profile_manager.dart';
import 'package:financeapp/shared/services/app_lock.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

class Profilepage extends ConsumerStatefulWidget {
  const Profilepage({super.key});

  @override
  ConsumerState<Profilepage> createState() => _ProfilepageState();
}

class _ProfilepageState extends ConsumerState<Profilepage> {
  bool _resetting = false;
  bool _showDeleted = false;
  String _deletedInitial = '?';
  VoidCallback? _onDeleteComplete;

  /// Saves the salary or monthly budget; returns an error message instead when
  /// the result would break the budget < salary rule (salary day would then
  /// debit the wallet).
  String? _saveMoney(String val, {required bool isSalary}) {
    final amount = double.tryParse(val);
    if (amount == null || amount <= 0) return AppStrings.enterValidAmount;
    final user = ref.read(userProvider);
    final salary = isSalary ? amount : user.salary;
    final budget = isSalary ? user.monthlyBudget : amount;
    if (budget >= salary) {
      return 'Budget must be less than your salary (${fmtAmt(salary, user.currency)})';
    }
    ref.read(userProvider.notifier).update(salary: salary, monthlyBudget: budget);
    return null;
  }

  /// Saves the day of the month the salary arrives; returns an error message instead when invalid.
  String? _saveSalaryDay(String val) {
    final day = int.tryParse(val);
    if (day == null || day < 1 || day > 31) return AppStrings.enterValidDay;
    ref.read(userProvider.notifier).update(salaryDay: day);
    return null;
  }

  Future<void> _toggleLock() async {
    final messenger = ScaffoldMessenger.of(context);
    final lock = AppLock.instance;
    final error = await lock.setEnabled(!lock.enabled.value);
    if (error != null) AppToast.error(messenger, error);
  }

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

    final pm = ProfileManager.instance;
    final activeId = await pm.getActiveProfileId();

    // Capture profile initial before wiping.
    final userName = ref.read(userProvider).name;

    // Wipe current profile's data.
    final db = ref.read(dbProvider);
    await db.resetDatabase();
    await db.close();

    // Remove the profile entry and clear active selection.
    if (activeId != null) await pm.deleteProfile(activeId);
    await pm.clearActiveProfile();

    final remaining = await pm.getProfiles();
    final config = AppConfig(
      isSetup: false,
      showPicker: remaining.isNotEmpty,
      allProfiles: remaining,
    );

    if (!mounted) return;
    setState(() {
      _showDeleted = true;
      _deletedInitial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';
      _onDeleteComplete = () => appConfigNotifier.value = config;
    });
  }

  // ── Backup ────────────────────────────────────────────────────────────────

  bool _backupBusy = false;

  Future<void> _exportBackup({required bool share}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _backupBusy = true);
    try {
      final json = await ref.read(dbProvider).exportBackup();
      final name =
          'financeapp-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json';
      if (share) {
        final file = File(p.join(Directory.systemTemp.path, name));
        await file.writeAsString(json);
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          fileNameOverrides: [name],
        ));
      } else {
        final saved = await FilePicker.saveFile(
          fileName: name,
          bytes: utf8.encoder.convert(json),
          mimeType: 'application/json',
        );
        if (saved != null) AppToast.success(messenger, 'Backup saved');
      }
    } catch (_) {
      AppToast.error(messenger, 'Could not export the backup');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty || !mounted) return;

    setState(() => _backupBusy = true);
    try {
      final BackupRows backup;
      try {
        backup = AppDatabase.parseBackup(
            utf8.decode(await picked.first.readAsBytes(), allowMalformed: true));
      } on FormatException catch (e) {
        AppToast.error(messenger, e.message);
        return;
      }
      if (!mounted) return;
      if (await _confirmRestore(backup) != true || !mounted) return;

      try {
        await ref.read(dbProvider).restoreBackup(backup);
      } catch (_) {
        AppToast.error(
            messenger, 'Restore failed — your current data is unchanged');
        return;
      }
      await Future.wait([
        ref.read(userProvider.notifier).reload(),
        ref.read(accountsProvider.notifier).reload(),
        ref.read(expensesProvider.notifier).reload(),
      ]);
      ref.invalidate(categoryBudgetsProvider);
      ref.invalidate(savingsGoalsProvider);
      AppToast.success(messenger, 'Backup restored');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<bool?> _confirmRestore(BackupRows b) {
    final when = b.exportedAt;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        ),
        title: const Text(
          AppStrings.restoreBackup,
          style: TextStyle(
            fontFamily: 'Rubik',
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        content: Text(
          '${b.user['name']} · ${b.transactions.length} transactions, '
          '${b.accounts.length} accounts, ${b.bills.length} bills'
          '${when == null ? '' : '\nExported ${when.toIso8601String().substring(0, 10)}'}'
          '\n\nEverything currently in this profile will be replaced. '
          'This cannot be undone.',
          style: const TextStyle(fontFamily: 'Rubik', height: 1.5),
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
              'Restore',
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
  }

  void _switchProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfilePickerPage(canPop: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final currency = ref.watch(currencyProvider);

    return Stack(
      children: [
        Scaffold(
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
                        onSave: (val) {
                          ref.read(userProvider.notifier).update(name: val);
                          return null;
                        },
                      ),
                    ),
                    _divider(),
                    _InfoRow(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: AppColors.myGreen,
                      iconBg: AppColors.myGreen.withValues(alpha: 0.1),
                      label: AppStrings.monthlySalary,
                      value: fmtAmt(user.salary, currency),
                      onTap: () => _showEditSheet(
                        context: context,
                        ref: ref,
                        title: AppStrings.editSalary,
                        initialValue: plainAmt(user.salary),
                        isNumber: true,
                        suffix: currency,
                        onSave: (val) => _saveMoney(val, isSalary: true),
                      ),
                    ),
                    _divider(),
                    _InfoRow(
                      icon: Icons.event_rounded,
                      iconColor: AppColors.blueIcon,
                      iconBg: AppColors.blueIconBg,
                      label: AppStrings.salaryDay,
                      value: 'Day ${user.salaryDay}',
                      onTap: () => _showEditSheet(
                        context: context,
                        ref: ref,
                        title: AppStrings.editSalaryDay,
                        initialValue: '${user.salaryDay}',
                        isNumber: true,
                        suffix: 'of each month',
                        onSave: _saveSalaryDay,
                      ),
                    ),
                    _divider(),
                    _InfoRow(
                      icon: Icons.receipt_long_rounded,
                      iconColor: AppColors.myRed,
                      iconBg: AppColors.myRed.withValues(alpha: 0.1),
                      label: AppStrings.monthlyBudget,
                      value: fmtAmt(user.monthlyBudget, currency),
                      isLast: true,
                      onTap: () => _showEditSheet(
                        context: context,
                        ref: ref,
                        title: AppStrings.editMonthlyBudget,
                        initialValue: plainAmt(user.monthlyBudget),
                        isNumber: true,
                        suffix: currency,
                        onSave: (val) => _saveMoney(val, isSalary: false),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSizes.l),

              // ── Switch profile ───────────────────────────────────
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
                    onTap: _switchProfile,
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
                              color: AppColors.blueIconBg,
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusM),
                            ),
                            child: Icon(
                              Icons.switch_account_rounded,
                              color: AppColors.blueIcon,
                              size: AppSizes.iconM,
                            ),
                          ),
                          SizedBox(width: AppSizes.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.switchProfile,
                                  style: TextStyle(
                                    fontSize: AppSizes.fontM,
                                    fontFamily: 'Rubik',
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppStrings.switchProfileSubtitle,
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

              // ── Security ─────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(bottom: AppSizes.s),
                child: SectionLabel(AppStrings.sectionSecurity),
              ),
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
                child: ValueListenableBuilder<bool>(
                  valueListenable: AppLock.instance.enabled,
                  builder: (_, on, __) => _InfoRow(
                    icon: Icons.lock_rounded,
                    iconColor: AppColors.blueIcon,
                    iconBg: AppColors.blueIconBg,
                    label: AppStrings.appLock,
                    value: on ? 'On' : 'Off',
                    isFirst: true,
                    isLast: true,
                    onTap: _toggleLock,
                  ),
                ),
              ),
              SizedBox(height: AppSizes.l),

              // ── Backup ───────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(bottom: AppSizes.s),
                child: SectionLabel(AppStrings.sectionBackup),
              ),
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
                    _BackupRow(
                      icon: Icons.save_alt_rounded,
                      title: AppStrings.exportBackup,
                      subtitle: AppStrings.exportBackupSubtitle,
                      isFirst: true,
                      onTap: _backupBusy ? null : () => _exportBackup(share: false),
                    ),
                    _divider(),
                    _BackupRow(
                      icon: Icons.ios_share_rounded,
                      title: AppStrings.shareBackup,
                      subtitle: AppStrings.shareBackupSubtitle,
                      onTap: _backupBusy ? null : () => _exportBackup(share: true),
                    ),
                    _divider(),
                    _BackupRow(
                      icon: Icons.settings_backup_restore_rounded,
                      title: AppStrings.restoreBackup,
                      subtitle: AppStrings.restoreBackupSubtitle,
                      isLast: true,
                      onTap: _backupBusy ? null : _restoreBackup,
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
        ),

        // ── Deletion overlay ─────────────────────────────────────────
        if (_showDeleted)
          ProfileDeletedOverlay(
            initial: _deletedInitial,
            onComplete: _onDeleteComplete ?? () {},
          ),
      ],
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
    required String? Function(String) onSave,
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
                  keyboardType: isNumber
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  inputFormatters: isNumber
                      ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
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
                        final error = ctrl.text.trim().isEmpty
                            ? null
                            : onSave(ctrl.text.trim());
                        Navigator.pop(ctx);
                        // Shown after the sheet closes, otherwise it hides under it.
                        if (error != null) {
                          AppToast.error(ScaffoldMessenger.of(context), error);
                        }
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

// ── Backup Row Widget ─────────────────────────────────────────────────────────

class _BackupRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;

  const _BackupRow({
    required this.icon,
    required this.title,
    required this.subtitle,
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
          top: isFirst ? Radius.circular(AppSizes.radiusXL) : Radius.zero,
          bottom: isLast ? Radius.circular(AppSizes.radiusXL) : Radius.zero,
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
                  color: AppColors.blueIconBg,
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: Icon(icon, color: AppColors.blueIcon, size: AppSizes.iconM),
              ),
              SizedBox(width: AppSizes.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        fontFamily: 'Rubik',
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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

