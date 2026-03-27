// ── WalletLayoutPage ─────────────────────────────────────────────────────────
// Root shell shown after onboarding. Hosts the three main pages (Salary Day,
// Home/Wallet, Profile) inside an IndexedStack so all pages stay mounted and
// preserve their scroll/state when switching tabs.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/modules/home/homePage.dart';
import 'package:financeapp/modules/profile/profilePage.dart';
import 'package:financeapp/modules/salaryDay/salaryDayPage.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

class Walletlayoutpage extends ConsumerWidget {
  const Walletlayoutpage({super.key});

  static const List<Widget> _pages = [
    Salarydaypage(),
    Homepage(),
    Profilepage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navIndexProvider);
    return Scaffold(
      extendBody: true,
      // ── Body ──────────────────────────────────────────────────────────────
      // IndexedStack keeps all three pages alive simultaneously; switching tabs
      // is instant because nothing is unmounted or re-initialised.
      body: IndexedStack(
        index: selectedIndex,
        children: _pages,
      ),
      // ── Bottom navigation bar ─────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: GNav(
              gap: 6,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              backgroundColor: Colors.transparent,
              tabBackgroundColor: AppColors.secondary,
              selectedIndex: selectedIndex,
              onTabChange: (index) {
                ref.read(navIndexProvider.notifier).state = index;
              },
              color: AppColors.secondary.withValues(alpha: 0.55),
              activeColor: AppColors.primary,
              textStyle: const TextStyle(
                fontFamily: 'Rubik',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                GButton(
                  icon: Icons.attach_money_rounded,
                  text: 'Salary',
                  iconSize: 24,
                ),
                GButton(
                  icon: Icons.wallet_rounded,
                  text: 'Wallet',
                  iconSize: 24,
                ),
                GButton(
                  icon: Icons.person_rounded,
                  text: 'Profile',
                  iconSize: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
