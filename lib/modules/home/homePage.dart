// ── HomePage ──────────────────────────────────────────────────────────────────
// Main wallet dashboard shown on the centre tab. Contains a horizontal card
// swiper (Wallet, Savings, Budget, custom accounts), an "Add Account" button,
// the savings goals under them, Operation and Transfer quick-action buttons, and
// a "How does this work?" sheet.
// Also triggers the first-run tutorial overlay via AppConfig.isFirstRun.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:card_swiper/card_swiper.dart';
import 'package:financeapp/modules/home/cards/customAccountCard.dart';
import 'package:financeapp/shared/networks/local/profile_manager.dart';
import 'package:financeapp/modules/home/cards/incomeCard.dart';
import 'package:financeapp/modules/home/sheets/add_account_sheet.dart';
import 'package:financeapp/modules/home/widgets/goals_strip.dart';
import 'package:financeapp/modules/home/cards/monthlyExpCard.dart';
import 'package:financeapp/modules/home/cards/savingCard.dart';
import 'package:financeapp/modules/operation/operationPage.dart';
import 'package:financeapp/modules/transfer/transferPage.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/styles/strings.dart';
import 'package:financeapp/shared/tutorial/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Homepage extends ConsumerStatefulWidget {
  const Homepage({super.key});

  @override
  ConsumerState<Homepage> createState() => _HomepageState();
}

class _HomepageState extends ConsumerState<Homepage> {
  // GlobalKeys for tutorial spotlights
  final _cardsKey = GlobalKey();
  final _addAccountKey = GlobalKey();
  final _opBtnKey = GlobalKey();
  final _transferBtnKey = GlobalKey();

  // Controls programmatic swipe — used to jump to a newly created account card.
  final _swiperController = SwiperController();
  // Holds the active tutorial overlay entry so it can be dismissed on dispose.
  OverlayEntry? _tutorialEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _tutorialEntry?.remove();
    super.dispose();
  }

  Future<void> _maybeShowTutorial() async {
    final seen = await ProfileManager.instance.hasTutorialSeen('home');
    if (seen || !mounted) return;
    await ProfileManager.instance.markTutorialSeen('home');
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _showTutorial();
  }

  void _showTutorial() {
    _tutorialEntry = OverlayEntry(
      builder: (_) => TutorialOverlay(
        steps: [
          TutorialStep(
            targetKey: _cardsKey,
            title: AppStrings.tutYourAccounts,
            body: AppStrings.tutYourAccountsBody,
            position: TipPosition.below,
            padding: 16,
          ),
          TutorialStep(
            targetKey: _addAccountKey,
            title: AppStrings.tutAddAccount,
            body: AppStrings.tutAddAccountBody,
            position: TipPosition.below,
          ),
          TutorialStep(
            targetKey: _opBtnKey,
            title: AppStrings.tutOperations,
            body: AppStrings.tutOperationsBody,
            position: TipPosition.above,
          ),
          TutorialStep(
            targetKey: _transferBtnKey,
            title: AppStrings.tutTransfer,
            body: AppStrings.tutTransferBody,
            position: TipPosition.above,
          ),
          const TutorialStep(
            title: AppStrings.tutNavigation,
            body: AppStrings.tutNavigationBody,
          ),
        ],
        onDone: _dismissTutorial,
      ),
    );
    Overlay.of(context).insert(_tutorialEntry!);
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.goodMorning;
    if (hour < 17) return AppStrings.goodAfternoon;
    return AppStrings.goodEvening;
  }

  void _dismissTutorial() {
    _tutorialEntry?.remove();
    _tutorialEntry = null;
  }

  Future<void> _showAddAccountSheet(BuildContext context) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddAccountSheet(),
    );
    if (added == true && mounted) {
      final accounts = ref.read(accountsProvider);
      final customCount = accounts.where((a) => a.isCustom).length;
      final lastIndex = 2 + customCount; // 3 built-in (0,1,2) + custom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _swiperController.move(lastIndex);
      });
    }
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
              const ModalHandle(),
              SizedBox(height: AppSizes.l),

              // Title
              Text(
                AppStrings.howDoesThisWork,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontXXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: AppSizes.xs),
              Text(
                AppStrings.howItWorksSubtitle,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontS,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
              ),
              SizedBox(height: AppSizes.l),

              // ── Section: Accounts ────────────────────────────────
              SectionLabel(AppStrings.sectionYourAccounts),
              SizedBox(height: AppSizes.s),
              _accountTile(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: AppColors.blueIcon,
                iconBg: AppColors.blueIconBg,
                title: AppStrings.wallet,
                body: AppStrings.walletDescription,
              ),
              SizedBox(height: AppSizes.s),
              _accountTile(
                icon: Icons.receipt_long_rounded,
                iconColor: AppColors.myRed,
                iconBg: AppColors.myRed.withValues(alpha: 0.1),
                title: AppStrings.monthlyBudget,
                body: AppStrings.budgetDescription,
              ),
              SizedBox(height: AppSizes.s),
              _accountTile(
                icon: Icons.savings_rounded,
                iconColor: AppColors.myGreen,
                iconBg: AppColors.myGreen.withValues(alpha: 0.1),
                title: AppStrings.savings,
                body: AppStrings.savingsDescription,
              ),
              SizedBox(height: AppSizes.l),

              // ── Section: Salary day logic ────────────────────────
              SectionLabel(AppStrings.sectionSalaryDayLogic),
              SizedBox(height: AppSizes.s),
              Container(
                padding: EdgeInsets.all(AppSizes.m),
                decoration: BoxDecoration(
                  color: AppColors.pageBackground,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
                child: Column(
                  children: [
                    _logicStep(
                      number: '1',
                      color: AppColors.blueIcon,
                      title: AppStrings.step1Title,
                      body: AppStrings.step1Body,
                    ),
                    SizedBox(height: AppSizes.m),
                    _logicStep(
                      number: '2',
                      color: AppColors.myGreen,
                      title: AppStrings.step2Title,
                      body: AppStrings.step2Body,
                    ),
                    SizedBox(height: AppSizes.m),
                    _logicStep(
                      number: '3',
                      color: AppColors.myRed,
                      title: AppStrings.step3Title,
                      body: AppStrings.step3Body,
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

  Widget _accountTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String body,
  }) =>
      Container(
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
  }) =>
      Row(
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
    final accounts = ref.watch(accountsProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final List<Widget> cards = [
      const IncomeCard(),
      const SavingCard(),
      const MonthlyExpCard(),
      ...accounts
          .where((a) => a.isCustom)
          .map((a) => CustomAccountCard(account: a)),
    ];

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

            // ── Cards swiper + buttons row ───────────────────────────
            // Scrolls only when the cards + goals do not fit (small screens).
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "+" and "?" buttons row
                        Padding(
                          padding: EdgeInsets.only(
                            left: screenWidth * 0.1,
                            right: screenWidth * 0.1,
                            bottom: AppSizes.s,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // "+" add account button (left)
                              GestureDetector(
                                key: _addAccountKey,
                                onTap: () => _showAddAccountSheet(context),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.08),
                                    border: Border.all(
                                        color: AppColors.secondary
                                            .withValues(alpha: 0.18),
                                        width: 1),
                                  ),
                                  child: Icon(Icons.add_rounded,
                                      size: 16,
                                      color: AppColors.secondary
                                          .withValues(alpha: 0.55)),
                                ),
                              ),
                              // "?" how it works button (right)
                              GestureDetector(
                                onTap: () => _showHowItWorksSheet(context),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: AppSizes.s + 2,
                                      vertical: AppSizes.xs + 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.07),
                                    borderRadius:
                                        BorderRadius.circular(AppSizes.radiusXXL),
                                    border: Border.all(
                                      color: AppColors.secondary
                                          .withValues(alpha: 0.15),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lightbulb_outline_rounded,
                                        size: 13,
                                        color: AppColors.secondary
                                            .withValues(alpha: 0.55),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        AppStrings.howItWorks,
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
                            ],
                          ),
                        ),

                        // Swiper
                        SizedBox(
                          height: screenHeight * 0.28,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Swiper(
                                controller: _swiperController,
                                itemBuilder: (BuildContext context, int index) =>
                                    cards[index],
                                itemCount: cards.length,
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

                        // ── Savings goals ────────────────────────────────────
                        SizedBox(height: AppSizes.m),
                        const GoalsStrip(),
                      ],
                    ),
                  ),
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
                  KeyedSubtree(
                    key: _opBtnKey,
                    child: LightButton(
                      width: double.infinity,
                      text: AppStrings.addIncomeExpense,
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
                      text: AppStrings.transfer,
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
