import 'package:card_swiper/card_swiper.dart';
import 'package:financeapp/main.dart';
import 'package:financeapp/modules/home/cards/incomeCard.dart';
import 'package:financeapp/modules/home/cards/monthlyExpCard.dart';
import 'package:financeapp/modules/home/cards/savingCard.dart';
import 'package:financeapp/modules/operation/operationPage.dart';
import 'package:financeapp/modules/transfer/transferPage.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/tutorial/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Homepage extends ConsumerStatefulWidget {
  const Homepage({super.key});

  @override
  ConsumerState<Homepage> createState() => _HomepageState();
}

class _HomepageState extends ConsumerState<Homepage> {
  static const List<Widget> _cards = [
    IncomeCard(),
    SavingCard(),
    MonthlyExpCard(),
  ];

  // GlobalKeys for tutorial spotlights
  final _cardsKey = GlobalKey();
  final _opBtnKey = GlobalKey();
  final _transferBtnKey = GlobalKey();

  OverlayEntry? _tutorialEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  @override
  void dispose() {
    _tutorialEntry?.remove();
    super.dispose();
  }

  void _maybeShowTutorial() {
    if (appConfigNotifier.value?.isFirstRun != true) return;
    _showTutorial();
  }

  void _showTutorial() {
    _tutorialEntry = OverlayEntry(
      builder: (_) => TutorialOverlay(
        steps: [
          TutorialStep(
            targetKey: _cardsKey,
            title: 'Your Accounts',
            body: 'Swipe left or right to browse your Wallet, Savings, and Monthly Budget cards.',
            position: TipPosition.below,
            padding: 16,
          ),
          TutorialStep(
            targetKey: _opBtnKey,
            title: 'Operations',
            body: 'Record any deposit or withdrawal on any of your accounts.',
            position: TipPosition.above,
          ),
          TutorialStep(
            targetKey: _transferBtnKey,
            title: 'Transfer',
            body: 'Move funds between Wallet, Savings, and Budget instantly.',
            position: TipPosition.above,
          ),
          const TutorialStep(
            title: 'Navigation',
            body: 'Use the bottom bar:\n💰 Salary Day — press when your salary arrives\n👤 Profile — edit your name and budget settings',
          ),
        ],
        onDone: _dismissTutorial,
      ),
    );
    Overlay.of(context).insert(_tutorialEntry!);

    // Mark as seen so it never shows again this session
    if (appConfigNotifier.value != null) {
      final v = appConfigNotifier.value!;
      appConfigNotifier.value = AppConfig(
        isSetup: v.isSetup,
        isFirstRun: false,
        db: v.db,
        user: v.user,
        accounts: v.accounts,
        bills: v.bills,
      );
    }
  }

  void _dismissTutorial() {
    _tutorialEntry?.remove();
    _tutorialEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
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
                          user.name,
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
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Swiper(
                    itemBuilder: (BuildContext context, int index) =>
                        _cards[index],
                    itemCount: _cards.length,
                    itemWidth: screenWidth * 0.8,
                    itemHeight: screenHeight * 0.28,
                    layout: SwiperLayout.STACK,
                    axisDirection: AxisDirection.right,
                  ),
                  // Invisible widget — same size as one card — used only
                  // for spotlight measurement. Taps pass through to Swiper.
                  IgnorePointer(
                    child: SizedBox(
                      key: _cardsKey,
                      width: screenWidth * 0.8,
                      height: screenHeight * 0.28,
                    ),
                  ),
                ],
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
                  KeyedSubtree(
                    key: _opBtnKey,
                    child: LightButton(
                      width: double.infinity,
                      text: 'Add Income / Expense',
                      textColor: AppColors.primary,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OperationPage()),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.s + 4),
                  KeyedSubtree(
                    key: _transferBtnKey,
                    child: LightButton(
                      width: double.infinity,
                      text: 'Transfer',
                      textColor: AppColors.primary,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TransferPage()),
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
