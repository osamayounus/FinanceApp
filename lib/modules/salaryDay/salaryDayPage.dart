import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/tutorial/tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

class Salarydaypage extends ConsumerStatefulWidget {
  const Salarydaypage({super.key});

  @override
  ConsumerState<Salarydaypage> createState() => _SalarydaypageState();
}

class _SalarydaypageState extends ConsumerState<Salarydaypage>
    with TickerProviderStateMixin {
  // Press animation
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  // Pulse / ripple animation (looping)
  late final AnimationController _pulseCtrl;
  late final Animation<double> _ring1Scale;
  late final Animation<double> _ring1Opacity;
  late final Animation<double> _ring2Scale;
  late final Animation<double> _ring2Opacity;

  final _coinKey = GlobalKey();
  OverlayEntry? _tutorialEntry;
  bool _tutorialTriggered = false;

  @override
  void initState() {
    super.initState();

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 420),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.87).animate(
      CurvedAnimation(
        parent: _pressCtrl,
        curve: Curves.easeIn,
        reverseCurve: Curves.elasticOut,
      ),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Tutorial is triggered from build() when this page becomes visible.

    final curve1 = CurvedAnimation(
      parent: _pulseCtrl,
      curve: const Interval(0.0, 0.70, curve: Curves.easeOut),
    );
    _ring1Scale = Tween<double>(begin: 1.0, end: 1.55).animate(curve1);
    _ring1Opacity = Tween<double>(begin: 0.45, end: 0.0).animate(curve1);

    final curve2 = CurvedAnimation(
      parent: _pulseCtrl,
      curve: const Interval(0.30, 1.0, curve: Curves.easeOut),
    );
    _ring2Scale = Tween<double>(begin: 1.0, end: 1.55).animate(curve2);
    _ring2Opacity = Tween<double>(begin: 0.45, end: 0.0).animate(curve2);
  }

  @override
  void dispose() {
    _tutorialEntry?.remove();
    _pressCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _maybeShowTutorial() async {
    final db = ref.read(dbProvider);
    final seen = await db.hasTutorialSeen('tutorial_salary');
    if (seen || !mounted) return;
    await db.markTutorialSeen('tutorial_salary');
    if (!mounted) return;
    _tutorialEntry = OverlayEntry(
      builder: (_) => TutorialOverlay(
        steps: [
          TutorialStep(
            targetKey: _coinKey,
            title: 'Salary Day',
            body: 'Press this coin ONLY when your salary has actually arrived in your account.',
            position: TipPosition.above,
            padding: 20,
          ),
          const TutorialStep(
            title: 'What happens when you press it?',
            body: '• Budget leftover → transferred to Wallet\n• Wallet receives your net salary\n• Budget resets to its monthly amount\n• All bills reset to unpaid',
          ),
        ],
        onDone: () {
          _tutorialEntry?.remove();
          _tutorialEntry = null;
        },
      ),
    );
    Overlay.of(context).insert(_tutorialEntry!);
  }

  void _onTapDown(_) => _pressCtrl.forward();
  void _onTapUp(_) => _pressCtrl.reverse();
  void _onTapCancel() => _pressCtrl.reverse();
  void _onTap() => _showConfirmDialog();

  void _showConfirmDialog() {
    final user = ref.read(userProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        ),
        contentPadding: EdgeInsets.fromLTRB(
            AppSizes.l, AppSizes.l, AppSizes.l, AppSizes.m),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSizes.m),
              decoration: BoxDecoration(
                color: AppColors.myGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Text('💸', style: TextStyle(fontSize: 36)),
            ),
            SizedBox(height: AppSizes.m),
            Text(
              'نزل الراتب؟',
              style: TextStyle(
                fontFamily: 'Rubik',
                fontSize: AppSizes.fontXXL,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: AppSizes.s),
            Text(
              'Salary: ${user.salary.toInt()} JOD\nBudget: ${user.monthlyBudget.toInt()} JOD\n\nThis will update your balances and reset all bills.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Rubik',
                fontSize: AppSizes.fontS,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
            SizedBox(height: AppSizes.l),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[200]!),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusL),
                      ),
                      padding:
                          EdgeInsets.symmetric(vertical: AppSizes.m),
                    ),
                    child: Text(
                      'Nope 😅',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontFamily: 'Rubik',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSizes.s + 4),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _processSalaryDay();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.myGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusL),
                      ),
                      padding:
                          EdgeInsets.symmetric(vertical: AppSizes.m),
                    ),
                    child: const Text(
                      'YES! 🎉',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontFamily: 'Rubik',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processSalaryDay() async {
    final user = ref.read(userProvider);
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(accountsProvider.notifier)
        .processSalaryDay(user.salary, user.monthlyBudget);
    ref.read(expensesProvider.notifier).resetAll();

    if (!mounted) return;
    AppToast.success(
      messenger,
      'Salary day done! + ${user.salary.toInt()} JOD received 🎉',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show tutorial only when this page is actually visible (nav index 0).
    ref.listen<int>(navIndexProvider, (_, next) {
      if (next == 0 && !_tutorialTriggered) {
        _tutorialTriggered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
      }
    });

    final double screenWidth = MediaQuery.of(context).size.width;
    final double coinSize = screenWidth * 0.62;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.l),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Rule card ───────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppSizes.m),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.myGreen.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusM),
                    color: AppColors.myGreen.withValues(alpha: 0.07),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: AppSizes.s, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.myGreen,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusS - 2),
                        ),
                        child: const Text(
                          'RULE',
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Rubik',
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(height: AppSizes.s),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSizes.xs,
                        children: [
                          Text(
                            'Press the coin if and only if',
                            style: TextStyle(
                              fontFamily: 'Rubik',
                              color: AppColors.primary,
                              fontSize: AppSizes.fontS,
                            ),
                          ),
                          Text(
                            'نزل الراتب',
                            style: TextStyle(
                              fontFamily: 'Rubik',
                              color: AppColors.myGreen,
                              fontSize: AppSizes.fontS,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.myGreen.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.myGreen,
                              size: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSizes.xxl),

                // ── Coin with pulse rings ─────────────────────────
                GestureDetector(
                  key: _coinKey,
                  onTapDown: _onTapDown,
                  onTapUp: _onTapUp,
                  onTapCancel: _onTapCancel,
                  onTap: _onTap,
                  child: AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, child) {
                      return SizedBox(
                        width: coinSize * 1.6,
                        height: coinSize * 1.6,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: _ring1Opacity.value,
                              child: Container(
                                width: coinSize * _ring1Scale.value,
                                height: coinSize * _ring1Scale.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.myGreen,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            Opacity(
                              opacity: _ring2Opacity.value,
                              child: Container(
                                width: coinSize * _ring2Scale.value,
                                height: coinSize * _ring2Scale.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.myGreen,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            child!,
                          ],
                        ),
                      );
                    },
                    child: Container(
                      width: coinSize,
                      height: coinSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              AppColors.myGreen.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.myGreen.withValues(alpha: 0.1),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: ScaleTransition(
                          scale: _pressScale,
                          child: SvgPicture.asset(
                            'lib/shared/styles/images/coin.svg',
                            width: screenWidth * 0.5,
                            height: screenWidth * 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppSizes.xxl),

                Text(
                  'Your balance will be updated automatically',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontS,
                    color: AppColors.primary.withValues(alpha: 0.3),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
