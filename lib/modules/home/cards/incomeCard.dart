import 'package:financeapp/modules/fixedExp/FixedExpensesPage.dart';
import 'package:financeapp/modules/history/historyPage.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IncomeCard extends ConsumerWidget {
  const IncomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final income = ref.watch(profileProvider).income;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF4F5FB), Color(0xFFE8EAF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.14),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Decorative circles ──────────────────────────────────
            Positioned(
              top: -28,
              right: -18,
              child: _circle(130, 0.18),
            ),
            Positioned(
              top: 18,
              right: 52,
              child: _circle(70, 0.12),
            ),
            Positioned(
              bottom: -40,
              left: -20,
              child: _circle(110, 0.10),
            ),

            // ── Content ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.m,
                vertical: AppSizes.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon + title
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusM),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.primary,
                          size: AppSizes.iconM,
                        ),
                      ),
                      const SizedBox(width: AppSizes.s),
                      Text(
                        'Income Account',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontS,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Balance label
                  Text(
                    'Balance',
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontXS,
                      color: AppColors.primary.withValues(alpha: 0.4),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Amount
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$income',
                        style: const TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSizes.s),
                      Text(
                        'JOD',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontM,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _CardButton(
                          label: 'History',
                          icon: Icons.history_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => Historypage('Income')),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.s),
                      Expanded(
                        child: _CardButton(
                          label: 'Bills',
                          icon: Icons.receipt_long_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const Fixedexpensespage()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _circle(double size, double opacity) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: opacity),
      ),
    );

class _CardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CardButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSizes.s + 2, horizontal: AppSizes.s),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: AppSizes.iconS),
              const SizedBox(width: AppSizes.xs + 2),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontS,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
