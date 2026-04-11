// ── TransferSuccessPage ───────────────────────────────────────────────────────
// Full-screen confirmation shown after a transfer completes.
// Animations:
//   • Check icon scales in with an elastic bounce
//   • Amount counts up from 0 → final value
//   • From / To row fades + slides up
//   • "Done" button fades in last
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';

class TransferSuccessPage extends StatefulWidget {
  final double amount;
  final String currency;
  final String fromName;
  final IconData fromIcon;
  final String toName;
  final IconData toIcon;
  /// Called when the Done button is pressed.
  /// Defaults to Navigator.pop if not provided.
  final VoidCallback? onDone;

  const TransferSuccessPage({
    super.key,
    required this.amount,
    required this.currency,
    required this.fromName,
    required this.fromIcon,
    required this.toName,
    required this.toIcon,
    this.onDone,
  });

  @override
  State<TransferSuccessPage> createState() => _TransferSuccessPageState();
}

class _TransferSuccessPageState extends State<TransferSuccessPage>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────
  late final AnimationController _checkCtrl;
  late final AnimationController _counterCtrl;
  late final AnimationController _detailsCtrl;

  // ── Animations ───────────────────────────────────────────────────────────
  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;
  late final Animation<double> _counter;      // 0 → amount
  late final Animation<double> _detailsSlide; // 24px → 0
  late final Animation<double> _detailsFade;
  late final Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();

    // 1. Check icon: elastic scale 0 → 1 over 600 ms
    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut),
    );
    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _checkCtrl,
          curve: const Interval(0.0, 0.3, curve: Curves.easeIn)),
    );

    // 2. Counter: 0 → amount over 1000 ms, starts 200 ms after check
    _counterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _counter = Tween<double>(begin: 0, end: widget.amount).animate(
      CurvedAnimation(parent: _counterCtrl, curve: Curves.easeOut),
    );

    // 3. Details (from/to row + button): slide+fade over 400 ms
    _detailsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _detailsSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _detailsCtrl, curve: Curves.easeOut),
    );
    _detailsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _detailsCtrl, curve: Curves.easeIn),
    );
    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _detailsCtrl,
          curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );

    // ── Sequence ─────────────────────────────────────────────────────────
    _checkCtrl.forward().then((_) async {
      await Future.delayed(const Duration(milliseconds: 100));
      _counterCtrl.forward().then((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        _detailsCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _counterCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  String _formatCounter(double value) {
    if (value == value.floorToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSizes.l, vertical: AppSizes.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // ── Check badge ─────────────────────────────────────────
              ScaleTransition(
                scale: _checkScale,
                child: FadeTransition(
                  opacity: _checkOpacity,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.myGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: AppColors.myGreen,
                      size: 48,
                    ),
                  ),
                ),
              ),

              SizedBox(height: AppSizes.l),

              // ── Label ───────────────────────────────────────────────
              Text(
                'Transfer Complete',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontL,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),

              SizedBox(height: AppSizes.s),

              // ── Animated counter ────────────────────────────────────
              AnimatedBuilder(
                animation: _counter,
                builder: (_, __) => RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _formatCounter(_counter.value),
                        style: const TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: '  ${widget.currency}',
                        style: TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: AppSizes.fontL,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: AppSizes.xl + 8),

              // ── From → To row ────────────────────────────────────────
              AnimatedBuilder(
                animation: _detailsCtrl,
                builder: (_, child) => Opacity(
                  opacity: _detailsFade.value,
                  child: Transform.translate(
                    offset: Offset(0, _detailsSlide.value),
                    child: child,
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.l, vertical: AppSizes.m + 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // From account
                      _AccountPill(
                          name: widget.fromName, icon: widget.fromIcon),

                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSizes.m),
                        child: Row(
                          children: [
                            _dot(), SizedBox(width: 4),
                            _dot(), SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 18),
                            SizedBox(width: 4),
                            _dot(), SizedBox(width: 4),
                            _dot(),
                          ],
                        ),
                      ),

                      // To account
                      _AccountPill(
                          name: widget.toName, icon: widget.toIcon),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ── Done button ─────────────────────────────────────────
              AnimatedBuilder(
                animation: _buttonFade,
                builder: (_, child) =>
                    Opacity(opacity: _buttonFade.value, child: child),
                child: SizedBox(
                  width: double.infinity,
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () =>
                        widget.onDone != null
                            ? widget.onDone!()
                            : Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusXL),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: AppSizes.fontM,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _dot() => Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
    );

class _AccountPill extends StatelessWidget {
  final String name;
  final IconData icon;
  const _AccountPill({required this.name, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
          ),
          child: Icon(icon, color: Colors.white, size: AppSizes.iconM),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: TextStyle(
            fontFamily: 'Rubik',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}
