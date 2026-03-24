import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class Salarydaypage extends StatefulWidget {
  const Salarydaypage({super.key});

  @override
  State<Salarydaypage> createState() => _SalarydaypageState();
}

class _SalarydaypageState extends State<Salarydaypage>
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

  @override
  void initState() {
    super.initState();

    // ── Press ────────────────────────────────────────────────────
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

    // ── Pulse rings (staggered, looping 2.4 s) ───────────────────
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Ring 1 starts early (0% → 70%)
    final curve1 = CurvedAnimation(
      parent: _pulseCtrl,
      curve: const Interval(0.0, 0.70, curve: Curves.easeOut),
    );
    _ring1Scale = Tween<double>(begin: 1.0, end: 1.55).animate(curve1);
    _ring1Opacity = Tween<double>(begin: 0.45, end: 0.0).animate(curve1);

    // Ring 2 starts later (30% → 100%)
    final curve2 = CurvedAnimation(
      parent: _pulseCtrl,
      curve: const Interval(0.30, 1.0, curve: Curves.easeOut),
    );
    _ring2Scale = Tween<double>(begin: 1.0, end: 1.55).animate(curve2);
    _ring2Opacity = Tween<double>(begin: 0.45, end: 0.0).animate(curve2);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _pressCtrl.forward();
  void _onTapUp(_) => _pressCtrl.reverse();
  void _onTapCancel() => _pressCtrl.reverse();
  void _onTap() => _showConfirmDialog();

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        ),
        contentPadding: const EdgeInsets.fromLTRB(
            AppSizes.l, AppSizes.l, AppSizes.l, AppSizes.m),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(AppSizes.m),
              decoration: BoxDecoration(
                color: AppColors.myGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Text('💸', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: AppSizes.m),
            const Text(
              'نزل الراتب؟',
              style: TextStyle(
                fontFamily: 'Rubik',
                fontSize: AppSizes.fontXXL,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSizes.s),
            Text(
              'Are you 100% sure the salary arrived?\nThis will update your balance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Rubik',
                fontSize: AppSizes.fontS,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSizes.l),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[200]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.m),
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
                const SizedBox(width: AppSizes.s + 4),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.myGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.m),
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

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double coinSize = screenWidth * 0.62;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.l),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Rule card ─────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.m),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.myGreen.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    color: AppColors.myGreen.withValues(alpha: 0.07),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
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
                      const SizedBox(height: AppSizes.s),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSizes.xs,
                        children: [
                          const Text(
                            'Press the coin if and only if',
                            style: TextStyle(
                              fontFamily: 'Rubik',
                              color: AppColors.primary,
                              fontSize: AppSizes.fontS,
                            ),
                          ),
                          const Text(
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
                              color: AppColors.myGreen.withValues(alpha: 0.15),
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
                const SizedBox(height: AppSizes.xxl),

                // ── Coin with pulse rings ─────────────────────────────
                GestureDetector(
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
                            // Ring 1
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
                            // Ring 2
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
                            // Static coin container
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
                          color: AppColors.myGreen.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.myGreen.withValues(alpha: 0.1),
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
                const SizedBox(height: AppSizes.xxl),

                // ── Subtitle ──────────────────────────────────────────
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
