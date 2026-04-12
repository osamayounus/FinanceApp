// ── WelcomeOverlay ────────────────────────────────────────────────────────────
// Full-screen animated overlay shown after a new profile is created.
// A checkmark pops in with elastic bounce, particles burst outward, the user's
// name slides up, and a subtitle fades in. Calls [onComplete] when done.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:math' as math;

import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';

class WelcomeOverlay extends StatefulWidget {
  final String name;
  final VoidCallback onComplete;

  const WelcomeOverlay({
    super.key,
    required this.name,
    required this.onComplete,
  });

  @override
  State<WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends State<WelcomeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bgFade;
  late final Animation<double> _checkScale;
  late final Animation<double> _particleProgress;
  late final Animation<double> _nameFade;
  late final Animation<Offset> _nameSlide;
  late final Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _bgFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.18, curve: Curves.easeIn)));
    _checkScale = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.12, 0.52, curve: Curves.elasticOut)));
    _particleProgress = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.30, 0.78, curve: Curves.easeOut)));
    _nameFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.48, 0.78, curve: Curves.easeIn)));
    _nameSlide =
        Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _ctrl,
                curve: const Interval(0.48, 0.78, curve: Curves.easeOut)));
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.70, 1.0, curve: Curves.easeIn)));

    _run();
  }

  Future<void> _run() async {
    await _ctrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
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
            color: AppColors.myGreen,
            child: DefaultTextStyle(
              style: const TextStyle(decoration: TextDecoration.none),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Checkmark + particle burst ────────────
                    SizedBox(
                      width: 300,
                      height: 300,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(300, 300),
                            painter:
                                _CelebrationPainter(_particleProgress.value),
                          ),
                          Transform.scale(
                            scale: _checkScale.value,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.18),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    width: 2),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 52,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Welcome text ──────────────────────────
                    SlideTransition(
                      position: _nameSlide,
                      child: FadeTransition(
                        opacity: _nameFade,
                        child: Text(
                          'Welcome, ${widget.name}!',
                          style: const TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    FadeTransition(
                      opacity: _subtitleFade,
                      child: Text(
                        'Your account is all set.',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontS,
                          color: Colors.white.withValues(alpha: 0.7),
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

// ── Celebration particle painter ─────────────────────────────────────────────

class _CelebrationPainter extends CustomPainter {
  final double progress;
  _CelebrationPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    const count = 12;
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi;
      final maxDist = i.isEven ? 120.0 : 90.0;
      final distance = maxDist * progress;
      final x = cx + math.cos(angle) * distance;
      final y = cy + math.sin(angle) * distance;
      final opacity = (1 - progress).clamp(0.0, 1.0) * 0.85;
      final radius = (i.isEven ? 7.0 : 5.0) * (1 - progress * 0.55);
      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) => old.progress != progress;
}
