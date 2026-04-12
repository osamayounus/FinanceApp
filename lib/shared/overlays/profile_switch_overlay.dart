// ── ProfileSwitchOverlay ──────────────────────────────────────────────────────
// Full-screen animated overlay shown when switching between profiles.
// Fades in a dark background, ripple-expands two rings, pops an avatar in with
// elastic bounce, slides the profile name up, and finally shows an "Now Active"
// badge. Calls [onComplete] after the animation + a short hold.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';

class ProfileSwitchOverlay extends StatefulWidget {
  final String name;
  final String initial;
  final VoidCallback onComplete;

  const ProfileSwitchOverlay({
    super.key,
    required this.name,
    required this.initial,
    required this.onComplete,
  });

  @override
  State<ProfileSwitchOverlay> createState() => _ProfileSwitchOverlayState();
}

class _ProfileSwitchOverlayState extends State<ProfileSwitchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  // background
  late final Animation<double> _bgFade;
  // ripple rings
  late final Animation<double> _ring1Scale;
  late final Animation<double> _ring1Opacity;
  late final Animation<double> _ring2Scale;
  late final Animation<double> _ring2Opacity;
  // avatar
  late final Animation<double> _avatarScale;
  // text
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  // badge
  late final Animation<double> _badgeScale;
  late final Animation<double> _badgeFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    // 0–20%: background fades in
    _bgFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.20, curve: Curves.easeIn)));

    // 10–55%: ring 1 expands + fades out
    _ring1Scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.10, 0.55, curve: Curves.easeOut)));
    _ring1Opacity = Tween<double>(begin: 0.35, end: 0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.10, 0.55, curve: Curves.easeIn)));

    // 20–65%: ring 2 expands + fades out (bigger, slower)
    _ring2Scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.20, 0.65, curve: Curves.easeOut)));
    _ring2Opacity = Tween<double>(begin: 0.20, end: 0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.20, 0.65, curve: Curves.easeIn)));

    // 15–55%: avatar pops in with elastic bounce
    _avatarScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.15, 0.55, curve: Curves.elasticOut)));

    // 45–75%: name text slides up + fades in
    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.45, 0.75, curve: Curves.easeIn)));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.45, 0.75, curve: Curves.easeOut)));

    // 65–100%: "Active" badge pops in
    _badgeFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.65, 1.0, curve: Curves.easeIn)));
    _badgeScale = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.65, 1.0, curve: Curves.elasticOut)));

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
      builder: (_, __) {
        if (_ctrl.value == 0) return const SizedBox.shrink();
        return IgnorePointer(
          child: Opacity(
            opacity: _bgFade.value,
            child: Container(
              color: AppColors.primary,
              child: DefaultTextStyle(
                style: const TextStyle(decoration: TextDecoration.none),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Ripple rings behind avatar ──────────────
                      SizedBox(
                        width: 280,
                        height: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ring 2 (outer)
                            Transform.scale(
                              scale: _ring2Scale.value,
                              child: Opacity(
                                opacity: _ring2Opacity.value,
                                child: Container(
                                  width: 260,
                                  height: 260,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Ring 1 (inner)
                            Transform.scale(
                              scale: _ring1Scale.value,
                              child: Opacity(
                                opacity: _ring1Opacity.value,
                                child: Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Avatar
                            Transform.scale(
                              scale: _avatarScale.value,
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.25),
                                      Colors.white.withValues(alpha: 0.10),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    widget.initial,
                                    style: const TextStyle(
                                      fontFamily: 'Rubik',
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Name ───────────────────────────────────
                      SlideTransition(
                        position: _textSlide,
                        child: FadeTransition(
                          opacity: _textFade,
                          child: Column(
                            children: [
                              Text(
                                widget.name,
                                style: const TextStyle(
                                  fontFamily: 'Rubik',
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Switching profile...',
                                style: TextStyle(
                                  fontFamily: 'Rubik',
                                  fontSize: AppSizes.fontS,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: AppSizes.l),

                      // ── Active badge ────────────────────────────
                      Transform.scale(
                        scale: _badgeScale.value,
                        child: Opacity(
                          opacity: _badgeFade.value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'Now Active',
                                  style: TextStyle(
                                    fontFamily: 'Rubik',
                                    fontSize: AppSizes.fontXS,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
