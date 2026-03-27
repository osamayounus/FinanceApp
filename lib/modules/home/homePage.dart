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
            body:
                'Swipe left or right to browse your Wallet, Savings, and Monthly Budget cards.',
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
            body:
                'Use the bottom bar:\n💰 Salary Day — press when your salary arrives\n👤 Profile — edit your name and budget settings',
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

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return '🌅 Good morning,';
    if (hour < 17) return '☀️ Good afternoon,';
    return '🌙 Good evening,';
  }

  void _dismissTutorial() {
    _tutorialEntry?.remove();
    _tutorialEntry = null;
  }

  void _showHowItWorksSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSizes.radiusXXL),
            ),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: EdgeInsets.fromLTRB(
              AppSizes.l,
              AppSizes.m,
              AppSizes.l,
              AppSizes.xl,
            ),
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
              SizedBox(height: AppSizes.l),

              // Title
              Text(
                'How does this work?',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontXXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: AppSizes.xs),
              Text(
                'A quick overview of your three accounts and wallet logic.',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontS,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
              ),
              SizedBox(height: AppSizes.l),

              // ── Section: Accounts ────────────────────────────────
              _sheetSectionLabel('YOUR 3 ACCOUNTS'),
              SizedBox(height: AppSizes.s),
              _accountTile(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF5B6BF8),
                iconBg: const Color(0xFFEEF0FF),
                title: 'Wallet',
                body:
                    'Your main spending account. Receives your net salary (Salary − Budget) on each salary day, plus any leftover budget from the previous month.',
              ),
              SizedBox(height: AppSizes.s),
              _accountTile(
                icon: Icons.receipt_long_rounded,
                iconColor: AppColors.myRed,
                iconBg: AppColors.myRed.withValues(alpha: 0.1),
                title: 'Monthly Budget',
                body:
                    'A dedicated envelope for your monthly expenses. Resets to your preset amount every salary day. Any unspent balance is automatically transferred to your Wallet.',
              ),
              SizedBox(height: AppSizes.s),
              _accountTile(
                icon: Icons.savings_rounded,
                iconColor: AppColors.myGreen,
                iconBg: AppColors.myGreen.withValues(alpha: 0.1),
                title: 'Savings',
                body:
                    'Your long-term savings pot. It is never touched automatically — only you decide when to move money in or out.',
              ),
              SizedBox(height: AppSizes.l),

              // ── Section: Salary day logic ────────────────────────
              _sheetSectionLabel('SALARY DAY LOGIC'),
              SizedBox(height: AppSizes.s),
              Container(
                padding: EdgeInsets.all(AppSizes.m),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F7),
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
                child: Column(
                  children: [
                    _logicStep(
                      number: '1',
                      color: const Color(0xFF5B6BF8),
                      title: 'Leftover budget is swept',
                      body:
                          'Any remaining balance in Monthly Budget is moved to your Wallet first.',
                    ),
                    SizedBox(height: AppSizes.m),
                    _logicStep(
                      number: '2',
                      color: AppColors.myGreen,
                      title: 'Net salary is added to Wallet',
                      body: 'Wallet  +=  Salary − Monthly Budget',
                    ),
                    SizedBox(height: AppSizes.m),
                    _logicStep(
                      number: '3',
                      color: AppColors.myRed,
                      title: 'Budget resets',
                      body:
                          'Monthly Budget is refilled to your preset monthly amount.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetSectionLabel(String label) => Text(
    label,
    style: TextStyle(
      fontFamily: 'Rubik',
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
      color: Colors.grey[400],
    ),
  );

  Widget _accountTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String body,
  }) => Container(
    padding: EdgeInsets.all(AppSizes.m),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
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
                title,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontM,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: AppSizes.xs),
              Text(
                body,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontS,
                  color: Colors.grey[500],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _logicStep({
    required String number,
    required Color color,
    required String title,
    required String body,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontXS,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
      SizedBox(width: AppSizes.s + 4),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Rubik',
                fontSize: AppSizes.fontS,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              body,
              style: TextStyle(
                fontFamily: 'Rubik',
                fontSize: AppSizes.fontXS,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ],
  );

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
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontS,
                          color: AppColors.secondary.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.name,
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontXXL,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Cards swiper + info pill ─────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info button
                  Padding(
                    padding: EdgeInsets.only(
                      right: screenWidth * 0.1,
                      bottom: AppSizes.s,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => _showHowItWorksSheet(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: AppSizes.s + 2,
                              vertical: AppSizes.xs + 1),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.07),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusXXL),
                            border: Border.all(
                              color:
                                  AppColors.secondary.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 13,
                                color:
                                    AppColors.secondary.withValues(alpha: 0.55),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'How it works',
                                style: TextStyle(
                                  fontFamily: 'Rubik',
                                  fontSize: AppSizes.fontXS,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Swiper
                  SizedBox(
                    height: screenHeight * 0.28,
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
                          builder: (_) => const OperationPage(),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSizes.s + 4),
                  KeyedSubtree(
                    key: _transferBtnKey,
                    child: LightButton(
                      width: double.infinity,
                      text: 'Transfer',
                      textColor: AppColors.primary,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TransferPage()),
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
