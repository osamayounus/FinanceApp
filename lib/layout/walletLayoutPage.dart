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
    final double navPaddingHor = MediaQuery.of(context).size.width * 0.10;
    final double navPaddingVer = MediaQuery.of(context).size.height * 0.03;

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        color: AppColors.primary,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: navPaddingHor,
            vertical: navPaddingVer,
          ),
          child: GNav(
            gap: 8,
            padding: const EdgeInsets.all(8),
            backgroundColor: AppColors.primary,
            tabBackgroundColor: AppColors.secondary,
            selectedIndex: selectedIndex,
            onTabChange: (index) {
              ref.read(navIndexProvider.notifier).state = index;
            },
            color: AppColors.secondary,
            activeColor: AppColors.primary,
            textStyle: const TextStyle(
              fontFamily: 'Rubik',
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              GButton(
                icon: Icons.attach_money_rounded,
                text: 'Salary Day',
                iconSize: 32,
              ),
              GButton(
                icon: Icons.wallet_outlined,
                text: 'Wallet',
                iconSize: 32,
              ),
              GButton(
                icon: Icons.account_circle_rounded,
                text: 'Profile',
                iconSize: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
