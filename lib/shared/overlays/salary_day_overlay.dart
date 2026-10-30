// ── SalaryDayOverlay ──────────────────────────────────────────────────────────
// Full-screen animated overlay shown after processing salary day.
// A coin icon pops in, particles arc upward, the salary amount counts up, then
// wallet and budget breakdown rows slide in. Calls [onComplete] when done.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:math' as math;

import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';

class SalaryDayOverlay extends StatefulWidget {
  final double salary;
  final double netIncome;
  final double budgetLeftover;
  final double monthlyBudget;
  final String currency;
  final VoidCallback onComplete;

  const SalaryDayOverlay({
    super.key,
    required this.salary,
    required this.netIncome,
    required this.budgetLeftover,
    required this.monthlyBudget,
    required this.currency,
    required this.onComplete,
  });

  @override
  State<SalaryDayOverlay> createState() => _SalaryDayOverlayState();
}

class _SalaryDayOverlayState extends State<SalaryDayOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bgFade;
  late final Animation<double> _coinScale;
  late final Animation<double> _particleProgress;
  late final Animation<double> _amountFade;
  late final Animation<double> _counter;
  late final Animation<double> _textFade;
  late final Animation<double> _row1Fade;
  late final Animation<Offset> _row1Slide;
  late final Animation<double> _row2Fade;
  late final Animation<Offset> _row2Slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _bgFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.12, curve: Curves.easeIn),
      ),
    );
    _coinScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.08, 0.38, curve: Curves.elasticOut),
      ),
    );
    _particleProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.22, 0.62, curve: Curves.easeOut),
      ),
    );
    _amountFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.28, 0.46, curve: Curves.easeIn),
      ),
    );
    _counter = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.28, 0.72, curve: Curves.easeOut),
      ),
    );
    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.46, 0.62, curve: Curves.easeIn),
      ),
    );
    _row1Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.58, 0.76, curve: Curves.easeIn),
      ),
    );
    _row1Slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.58, 0.76, curve: Curves.easeOut),
          ),
        );
    _row2Fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.70, 0.88, curve: Curves.easeIn),
      ),
    );
    _row2Slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.70, 0.88, curve: Curves.easeOut),
          ),
        );
    _run();
  }

  Future<void> _run() async {
    await _ctrl.forward();
    await Future.delayed(const Duration(milliseconds: 1000));
    widget.onComplete();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _bgFade.value,
        child: IgnorePointer(
          child: Container(
            color: AppColors.primary,
            child: DefaultTextStyle(
              style: const TextStyle(decoration: TextDecoration.none),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Coin + upward particles ───────────────
                    SizedBox(
                      width: 300,
                      height: 300,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(300, 300),
                            painter: _SalaryParticlesPainter(
                              _particleProgress.value,
                            ),
                          ),
                          Transform.scale(
                            scale: _coinScale.value,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.myGreen.withValues(
                                  alpha: 0.15,
                                ),
                                border: Border.all(
                                  color: AppColors.myGreen.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 2,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  '💸',
                                  style: TextStyle(fontSize: 44),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Amount counter ────────────────────────
                    Opacity(
                      opacity: _amountFade.value,
                      child: Text(
                        '+ ${(_counter.value * widget.salary).toInt()} ${widget.currency}',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: AppColors.myGreen,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ── Title ─────────────────────────────────
                    Opacity(
                      opacity: _textFade.value,
                      child: const Text(
                        'نزل الراتب! 🎉',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Wallet row ────────────────────────────
                    SlideTransition(
                      position: _row1Slide,
                      child: Opacity(
                        opacity: _row1Fade.value,
                        child: _BreakdownRow(
                          icon: Icons.account_balance_wallet_rounded,
                          color: AppColors.myGreen,
                          label: 'Wallet',
                          value:
                              '+ ${widget.netIncome.toInt()} ${widget.currency}',
                          sub: 'salary − budget (net income)',
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Budget row ────────────────────────────
                    SlideTransition(
                      position: _row2Slide,
                      child: Opacity(
                        opacity: _row2Fade.value,
                        child: _BreakdownRow(
                          icon: Icons.receipt_long_rounded,
                          color: AppColors.blueIcon,
                          label: 'Budget',
                          value:
                              '${widget.budgetLeftover.toInt()} → wallet  •  reset ${widget.monthlyBudget.toInt()}',
                          sub: 'leftover moved + monthly reset',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Salary particles painter (upward burst) ───────────────────────────────────

class _SalaryParticlesPainter extends CustomPainter {
  final double progress;
  _SalaryParticlesPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    // 10 particles spread in an upward arc (-150° to -30°)
    const count = 10;
    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      final angle = (-5 * math.pi / 6) + t * (2 * math.pi / 3);
      final maxDist = 75.0 + (i % 3) * 28.0;
      final distance = maxDist * progress;
      final x = cx + math.cos(angle) * distance;
      final y = cy + math.sin(angle) * distance;
      final opacity = (1 - progress).clamp(0.0, 1.0) * 0.9;
      final radius = (i.isEven ? 7.0 : 5.0) * (1 - progress * 0.5);
      paint.color = AppColors.myGreen.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_SalaryParticlesPainter old) => old.progress != progress;
}

// ── Breakdown row ─────────────────────────────────────────────────────────────

class _BreakdownRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;

  const _BreakdownRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: AppSizes.fontS,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  sub,
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
