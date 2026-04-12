// ── ProfileDeletedOverlay ─────────────────────────────────────────────────────
// Full-screen animated overlay shown after a profile is deleted.
// The avatar pops in then implodes while particles converge inward, then
// "Profile Deleted" text fades in. Calls [onComplete] when done.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:math' as math;

import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';

class ProfileDeletedOverlay extends StatefulWidget {
  final String initial;
  final VoidCallback onComplete;

  const ProfileDeletedOverlay({
    super.key,
    required this.initial,
    required this.onComplete,
  });

  @override
  State<ProfileDeletedOverlay> createState() => _ProfileDeletedOverlayState();
}

class _ProfileDeletedOverlayState extends State<ProfileDeletedOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bgFade;
  late final Animation<double> _avatarEnter;
  late final Animation<double> _avatarExit;
  late final Animation<double> _particleProgress;
  late final Animation<double> _textFade;
  late final Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _bgFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.18, curve: Curves.easeIn)));
    _avatarEnter = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.10, 0.42, curve: Curves.elasticOut)));
    _avatarExit = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.52, 0.78, curve: Curves.easeIn)));
    _particleProgress = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.30, 0.75, curve: Curves.easeIn)));
    _textFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.65, 0.90, curve: Curves.easeIn)));
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.80, 1.0, curve: Curves.easeIn)));

    _run();
  }

  Future<void> _run() async {
    await _ctrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
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
            color: const Color(0xFF1A0A0A),
            child: DefaultTextStyle(
              style: const TextStyle(decoration: TextDecoration.none),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Avatar implosion + particles ──────────
                    SizedBox(
                      width: 300,
                      height: 300,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(300, 300),
                            painter:
                                _DeletionPainter(_particleProgress.value),
                          ),
                          Transform.scale(
                            scale: _avatarEnter.value * _avatarExit.value,
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.myRed.withValues(alpha: 0.18),
                                border: Border.all(
                                    color: AppColors.myRed
                                        .withValues(alpha: 0.55),
                                    width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  widget.initial,
                                  style: TextStyle(
                                    fontFamily: 'Rubik',
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.myRed.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Text ─────────────────────────────────
                    FadeTransition(
                      opacity: _textFade,
                      child: const Text(
                        'Profile Deleted',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _subtitleFade,
                      child: Text(
                        'Your data has been removed.',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontS,
                          color: Colors.white.withValues(alpha: 0.5),
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

// ── Deletion particle painter (implosion) ────────────────────────────────────

class _DeletionPainter extends CustomPainter {
  final double progress; // 0 = particles far out, 1 = particles at center
  _DeletionPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    const count = 12;
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi;
      final maxDist = i.isEven ? 115.0 : 85.0;
      // implode: start far, travel inward
      final distance = maxDist * (1 - progress);
      final x = cx + math.cos(angle) * distance;
      final y = cy + math.sin(angle) * distance;
      // fade in as they approach center
      final opacity = (progress * 0.75).clamp(0.0, 1.0);
      final radius = (i.isEven ? 6.0 : 4.5) * (1 - progress * 0.5);
      paint.color = AppColors.myRed.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DeletionPainter old) => old.progress != progress;
}
