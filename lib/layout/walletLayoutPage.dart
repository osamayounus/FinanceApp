// ── WalletLayoutPage ─────────────────────────────────────────────────────────
// Root shell shown after onboarding. Hosts the three main pages (Salary Day,
// Home/Wallet, Profile) inside an IndexedStack so all pages stay mounted and
// preserve their scroll/state when switching tabs.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:math';

import 'package:financeapp/modules/analytics/analyticsPage.dart';
import 'package:financeapp/modules/home/homePage.dart';
import 'package:financeapp/modules/profile/profilePage.dart';
import 'package:financeapp/modules/salaryDay/salaryDayPage.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class Walletlayoutpage extends ConsumerWidget {
  const Walletlayoutpage({super.key});

  static const List<Widget> _pages = [
    Salarydaypage(),
    Homepage(),
    AnalyticsPage(),
    Profilepage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navIndexProvider);
    return Scaffold(
      extendBody: true,
      // ── Body ──────────────────────────────────────────────────────────────
      // IndexedStack keeps all three pages alive simultaneously; switching
      // tabs is instant because nothing is unmounted or re-initialised.
      body: IndexedStack(index: selectedIndex, children: _pages),
      // ── Bottom navigation bar (liquid glass) ──────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: LiquidGlass.withOwnLayer(
            settings: LiquidGlassSettings(
              thickness: 40,
              lightAngle: 0.5 * pi,
              lightIntensity: 0.18,
              chromaticAberration: 1,
              blur: 1.5,
              glassColor: AppColors.primary,
            ),
            shape: const LiquidRoundedRectangle(borderRadius: 28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: GNav(
                gap: 6,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                backgroundColor: Colors.transparent,
                tabBackgroundColor: Colors.white.withValues(alpha: 0.18),
                selectedIndex: selectedIndex,
                onTabChange: (index) {
                  ref.read(navIndexProvider.notifier).state = index;
                },
                color: Colors.white.withValues(alpha: 0.55),
                activeColor: Colors.white,
                textStyle: const TextStyle(
                  fontFamily: 'Rubik',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
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
                    icon: Icons.bar_chart_rounded,
                    text: 'Analytics',
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
      ),
    );
  }
}
