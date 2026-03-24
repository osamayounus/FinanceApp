import 'package:card_swiper/card_swiper.dart';
import 'package:financeapp/modules/home/cards/incomeCard.dart';
import 'package:financeapp/modules/home/cards/monthlyExpCard.dart';
import 'package:financeapp/modules/home/cards/savingCard.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Homepage extends ConsumerWidget {
  const Homepage({super.key});

  static const List<Widget> _cards = [
    IncomeCard(),
    SavingCard(),
    MonthlyExpCard(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Greeting header ──────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                screenWidth * 0.1,
                AppSizes.l,
                screenWidth * 0.1,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: AppSizes.fontS,
                            color: AppColors.secondary.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.name,
                          style: const TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: AppSizes.fontXXL,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        profile.name.isNotEmpty
                            ? profile.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontFamily: 'Rubik',
                          fontWeight: FontWeight.bold,
                          fontSize: AppSizes.fontL,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Cards swiper ─────────────────────────────────────────
            Expanded(
              child: Center(
                child: Swiper(
                  itemBuilder: (BuildContext context, int index) =>
                      _cards[index],
                  itemCount: _cards.length,
                  itemWidth: screenWidth * 0.8,
                  itemHeight: screenHeight * 0.28,
                  layout: SwiperLayout.STACK,
                  axisDirection: AxisDirection.right,
                ),
              ),
            ),

            // ── Action buttons ───────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                screenWidth * 0.1,
                0,
                screenWidth * 0.1,
                AppSizes.l,
              ),
              child: Column(
                children: [
                  LightButton(
                    width: double.infinity,
                    text: 'Add Income / Expense',
                    textColor: AppColors.primary,
                    onPressed: () {},
                  ),
                  const SizedBox(height: AppSizes.s + 4),
                  LightButton(
                    width: double.infinity,
                    text: 'Transfer',
                    textColor: AppColors.primary,
                    onPressed: () {},
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
