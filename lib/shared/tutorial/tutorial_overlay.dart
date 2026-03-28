// ── tutorial_overlay.dart ─────────────────────────────────────────────────────
// Fullscreen tutorial overlay driven by a list of TutorialStep objects.
// Each step spotlights a widget via GlobalKey, draws a dark scrim with a
// cutout, and shows a positioned speech-bubble tooltip. Tapping anywhere
// advances to the next step; the overlay removes itself when steps are done.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';

// ── Step model ────────────────────────────────────────────────────────────────

enum TipPosition { above, below }

class TutorialStep {
  /// Null = no spotlight, bubble shown centred on screen.
  final GlobalKey? targetKey;
  final String title;
  final String body;
  final TipPosition position;

  /// Extra padding around the highlighted widget (default 12).
  final double padding;

  const TutorialStep({
    this.targetKey,
    required this.title,
    required this.body,
    this.position = TipPosition.below,
    this.padding = 12,
  });
}

// ── Overlay widget ────────────────────────────────────────────────────────────

class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onDone;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onDone,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  Rect? _spot;

  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveSpot();
      _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _resolveSpot() {
    final key = widget.steps[_step].targetKey;
    if (key == null) {
      setState(() => _spot = null);
      return;
    }
    final rb = key.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null || !rb.attached) {
      setState(() => _spot = null);
      return;
    }
    final offset = rb.localToGlobal(Offset.zero);
    final pad = widget.steps[_step].padding;
    setState(() {
      _spot = Rect.fromLTWH(
        offset.dx - pad,
        offset.dy - pad,
        rb.size.width + pad * 2,
        rb.size.height + pad * 2,
      );
    });
  }

  Future<void> _advance() async {
    await _ctrl.reverse();
    if (_step < widget.steps.length - 1) {
      setState(() => _step++);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveSpot();
        _ctrl.forward();
      });
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final step = widget.steps[_step];

    return FadeTransition(
      opacity: _fade,
      child: Stack(
        children: [
          // ── Dark overlay (tappable anywhere to advance) ──────────────
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _advance,
              child: CustomPaint(
                painter: _spot != null
                    ? _SpotlightPainter(spot: _spot!)
                    : _DimPainter(),
                child: const SizedBox.expand(),
              ),
            ),
          ),

          // ── Info bubble (above the gesture detector) ─────────────────
          _BubbleCard(
            step: step,
            stepIndex: _step,
            totalSteps: widget.steps.length,
            spot: _spot,
            screenSize: screenSize,
            onNext: _advance,
          ),
        ],
      ),
    );
  }
}

// ── Bubble card ───────────────────────────────────────────────────────────────

class _BubbleCard extends StatelessWidget {
  final TutorialStep step;
  final int stepIndex;
  final int totalSteps;
  final Rect? spot;
  final Size screenSize;
  final VoidCallback onNext;

  const _BubbleCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.spot,
    required this.screenSize,
    required this.onNext,
  });

  static const double _kBubbleW = 268;
  static const double _kBubbleEstH = 162;
  static const double _kGap = 18;

  @override
  Widget build(BuildContext context) {
    double left, top;

    if (spot == null) {
      // No spotlight — centre bubble on screen
      left = (screenSize.width - _kBubbleW) / 2;
      top = (screenSize.height - _kBubbleEstH) / 2;
    } else {
      // Horizontally centre on the spotlight, then clamp
      left = spot!.left + spot!.width / 2 - _kBubbleW / 2;
      left = left.clamp(16.0, screenSize.width - _kBubbleW - 16.0);

      // Place above or below the spotlight
      if (step.position == TipPosition.below) {
        top = spot!.bottom + _kGap;
        // If it doesn't fit below, flip above
        if (top + _kBubbleEstH > screenSize.height - 24) {
          top = spot!.top - _kGap - _kBubbleEstH;
        }
      } else {
        top = spot!.top - _kGap - _kBubbleEstH;
        // If it doesn't fit above, flip below
        if (top < 80) top = spot!.bottom + _kGap;
      }
      top = top.clamp(80.0, screenSize.height - _kBubbleEstH - 20.0);
    }

    final isLast = stepIndex == totalSteps - 1;

    return Positioned(
      left: left,
      top: top,
      width: _kBubbleW,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step dots
              Row(
                children: List.generate(totalSteps, (i) {
                  final active = i == stepIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.only(right: 5),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                step.title,
                style: const TextStyle(
                  fontFamily: 'Rubik',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),

              // Body
              Text(
                step.body,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: 12.5,
                  color: Colors.grey[500],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),

              // Footer row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${stepIndex + 1} / $totalSteps',
                    style: TextStyle(
                      fontFamily: 'Rubik',
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                  GestureDetector(
                    onTap: onNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isLast ? 'Got it!' : 'Next  →',
                        style: const TextStyle(
                          fontFamily: 'Rubik',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect spot;
  const _SpotlightPainter({required this.spot});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    // Dark overlay
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.75),
    );
    // Clear spotlight hole
    canvas.drawRRect(
      RRect.fromRectAndRadius(spot, const Radius.circular(16)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.spot != spot;
}

class _DimPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(_DimPainter _) => false;
}
