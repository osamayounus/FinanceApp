import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Profilepage extends ConsumerWidget {
  const Profilepage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.m, vertical: AppSizes.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page title ──────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.s),
                child: Text(
                  'Profile',
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.m),

              // ── Avatar card ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.xl),
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
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, const Color(0xFF1A1D4A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 34,
                            fontFamily: 'Rubik',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.m),
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: AppSizes.fontXXL,
                        fontFamily: 'Rubik',
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      'Personal Account',
                      style: TextStyle(
                        fontSize: AppSizes.fontS,
                        fontFamily: 'Rubik',
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.l),

              // ── Section label ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: AppSizes.xs, bottom: AppSizes.s),
                child: Text(
                  'PERSONAL INFO',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Rubik',
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[400],
                    letterSpacing: 1.4,
                  ),
                ),
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
                      iconColor: const Color(0xFF5B6BF8),
                      iconBg: const Color(0xFFEEF0FF),
                      label: 'Name',
                      value: profile.name,
                      isFirst: true,
                      onTap: () => _showEditSheet(
                        context: context,
                        ref: ref,
                        title: 'Edit Name',
                        initialValue: profile.name,
                        isNumber: false,
                        onSave: (val) => ref.read(profileProvider.notifier).update(name: val),
                      ),
                    ),
                    _divider(),
                    _InfoRow(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: AppColors.myGreen,
                      iconBg: AppColors.myGreen.withValues(alpha: 0.1),
                      label: 'Monthly Income',
                      value: '${profile.income} JOD',
                      onTap: () => _showEditSheet(
                        context: context,
                        ref: ref,
                        title: 'Edit Income',
                        initialValue: profile.income.toString(),
                        isNumber: true,
                        suffix: 'JOD',
                        onSave: (val) => ref.read(profileProvider.notifier).update(income: int.tryParse(val)),
                      ),
                    ),
                    _divider(),
                    _InfoRow(
                      icon: Icons.receipt_long_rounded,
                      iconColor: AppColors.myRed,
                      iconBg: AppColors.myRed.withValues(alpha: 0.1),
                      label: 'Monthly Expenses',
                      value: '${profile.expenses} JOD',
                      isLast: true,
                      onTap: () => _showEditSheet(
                        context: context,
                        ref: ref,
                        title: 'Edit Expenses',
                        initialValue: profile.expenses.toString(),
                        isNumber: true,
                        suffix: 'JOD',
                        onSave: (val) => ref.read(profileProvider.notifier).update(expenses: int.tryParse(val)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xl),

              // ── Reset button ─────────────────────────────────────
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
                child: _InfoRow(
                  icon: Icons.restart_alt_rounded,
                  iconColor: AppColors.myRed,
                  iconBg: AppColors.myRed.withValues(alpha: 0.1),
                  label: 'Reset to Defaults',
                  value: '',
                  isFirst: true,
                  isLast: true,
                  labelStyle: const TextStyle(
                    fontSize: AppSizes.fontM,
                    fontFamily: 'Rubik',
                    fontWeight: FontWeight.w600,
                    color: AppColors.myRed,
                  ),
                  onTap: () => _confirmReset(context, ref),
                ),
              ),
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.xxl - 8)),
          ),
          padding: const EdgeInsets.fromLTRB(AppSizes.l, AppSizes.m, AppSizes.l, AppSizes.l),
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
              const SizedBox(height: AppSizes.l),
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppSizes.fontXXL,
                  fontFamily: 'Rubik',
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSizes.l),
              // Input field
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F7),
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: isNumber ? TextInputType.number : TextInputType.text,
                  inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
                  style: const TextStyle(
                    fontSize: AppSizes.fontXL,
                    fontFamily: 'Rubik',
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
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
              const SizedBox(height: AppSizes.l),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[200]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusL),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: AppSizes.m),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontFamily: 'Rubik',
                          fontWeight: FontWeight.w600,
                          fontSize: AppSizes.fontM,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.s + 4),
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
                          borderRadius: BorderRadius.circular(AppSizes.radiusL),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: AppSizes.m),
                      ),
                      child: const Text(
                        'Save',
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

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
        title: const Text(
          'Reset Profile',
          style: TextStyle(fontFamily: 'Rubik', fontWeight: FontWeight.bold),
        ),
        content: const Text('Reset all info to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(profileProvider.notifier).reset();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.myRed,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusS)),
            ),
            child: const Text('Reset', style: TextStyle(color: Colors.white, fontFamily: 'Rubik')),
          ),
        ],
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
  final TextStyle? labelStyle;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(AppSizes.radiusXL) : Radius.zero,
          bottom: isLast ? const Radius.circular(AppSizes.radiusXL) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.m, vertical: AppSizes.m),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: Icon(icon, color: iconColor, size: AppSizes.iconM),
              ),
              const SizedBox(width: AppSizes.m),
              // Label + value
              Expanded(
                child: value.isEmpty
                    ? Text(label, style: labelStyle)
                    : Column(
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
                            style: const TextStyle(
                              fontSize: AppSizes.fontM,
                              fontFamily: 'Rubik',
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
              ),
              // Chevron
              Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
