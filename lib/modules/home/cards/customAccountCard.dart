import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/modules/history/historyPage.dart';
import 'package:financeapp/modules/home/cards/customAccountDetailPage.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 8 color pairs (start, end) for the card gradient.
// Chosen to NOT conflict with built-in cards:
//   Wallet = light beige, Savings = green, Budget = red
const kCustomAccountColors = [
  [Color(0xFF7C4DFF), Color(0xFF512DA8)], // Purple
  [Color(0xFF2979FF), Color(0xFF1565C0)], // Blue
  [Color(0xFF00BCD4), Color(0xFF00838F)], // Cyan
  [Color(0xFFFF6D00), Color(0xFFBF360C)], // Deep Orange
  [Color(0xFFE91E63), Color(0xFF880E4F)], // Pink
  [Color(0xFFFFB300), Color(0xFFE65100)], // Amber
  [Color(0xFF009688), Color(0xFF004D40)], // Teal
  [Color(0xFF3D5AFE), Color(0xFF1A237E)], // Indigo
];

// Icons available for custom accounts
const kCustomAccountIcons = <IconData>[
  Icons.home_rounded,
  Icons.flight_rounded,
  Icons.restaurant_rounded,
  Icons.shopping_bag_rounded,
  Icons.local_hospital_rounded,
  Icons.school_rounded,
  Icons.directions_car_rounded,
  Icons.sports_esports_rounded,
  Icons.fitness_center_rounded,
  Icons.work_rounded,
  Icons.favorite_rounded,
  Icons.star_rounded,
  Icons.pets_rounded,
  Icons.coffee_rounded,
  Icons.beach_access_rounded,
  Icons.savings_rounded,
];

class CustomAccountCard extends ConsumerWidget {
  final AccountModel account;
  const CustomAccountCard({super.key, required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final colorPair = kCustomAccountColors[
        (account.colorIndex ?? 0).clamp(0, kCustomAccountColors.length - 1)];
    final iconData = account.iconCode != null
        ? IconData(account.iconCode!, fontFamily: 'MaterialIcons')
        : Icons.savings_rounded;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorPair[0], colorPair[1]],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -28, right: -18, child: _circle(130, 0.15)),
            Positioned(top: 18, right: 52, child: _circle(70, 0.10)),
            Positioned(bottom: -40, left: -20, child: _circle(110, 0.08)),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.m,
                vertical: AppSizes.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row: icon + name + ⋮ ───────────────────
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusM),
                        ),
                        child: Icon(iconData,
                            color: Colors.white, size: AppSizes.iconM),
                      ),
                      SizedBox(width: AppSizes.s),
                      Expanded(
                        child: Text(
                          account.displayName,
                          style: TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: AppSizes.fontS,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // ⋮ → detail page
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomAccountDetailPage(
                                account: account),
                          ),
                        ),
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: AppSizes.iconM,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── Balance ───────────────────────────────────────
                  Text(
                    'Balance',
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontXS,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        account.balance % 1 == 0
                            ? '${account.balance.toInt()}'
                            : account.balance.toStringAsFixed(2),
                        style: const TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: AppSizes.s),
                      Text(
                        currency,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontM,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── History button (full width) ───────────────────
                  _CardButton(
                    label: 'History',
                    icon: Icons.history_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Historypage(
                          accountId: account.id,
                          accountName: account.displayName,
                        ),
                      ),
                    ),
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
        color: Colors.white.withValues(alpha: opacity),
      ),
    );

class _CardButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _CardButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: AppSizes.s + 2, horizontal: AppSizes.s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: AppSizes.iconS),
                SizedBox(width: AppSizes.xs + 2),
                Text(label,
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: AppSizes.fontS,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
