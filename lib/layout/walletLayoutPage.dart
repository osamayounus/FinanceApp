// ── WalletLayoutPage ─────────────────────────────────────────────────────────
// Root shell shown after onboarding. Hosts the three main pages (Salary Day,
// Home/Wallet, Profile) inside an IndexedStack so all pages stay mounted and
// preserve their scroll/state when switching tabs.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:math';

import 'package:financeapp/modules/analytics/analyticsPage.dart';
import 'package:financeapp/modules/fixedExp/bill_due.dart';
import 'package:financeapp/modules/home/homePage.dart';
import 'package:financeapp/modules/profile/profilePage.dart';
import 'package:financeapp/modules/salaryDay/salaryDayPage.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class Walletlayoutpage extends ConsumerStatefulWidget {
  const Walletlayoutpage({super.key});

  @override
  ConsumerState<Walletlayoutpage> createState() => _WalletlayoutpageState();
}

class _WalletlayoutpageState extends ConsumerState<Walletlayoutpage>
    with WidgetsBindingObserver {
  static const List<Widget> _pages = [
    Salarydaypage(),
    Homepage(),
    AnalyticsPage(),
    Profilepage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _payDueBills());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _payDueBills();
  }

  /// Auto-pay bills are charged when the app opens or comes back, not by a
  /// background job. Safe to run any time: a bill is only ever charged once.
  Future<void> _payDueBills() async {
    final paid = await ref.read(expensesProvider.notifier).payDue();
    if (paid.isEmpty || !mounted) return;
    AppToast.success(ScaffoldMessenger.of(context),
        autoPaidText(paid, ref.read(currencyProvider)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navIndexProvider);
    return Scaffold(
      extendBody: true,
      // ── Body ──────────────────────────────────────────────────────────────
      // IndexedStack keeps all three pages alive simultaneously; switching
      // tabs is instant because nothing is unmounted or re-initialised.
      body: IndexedStack(index: selectedIndex, children: _pages),
      // ── Bottom navigation bar (liquid glass) ──────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: LiquidGlass.withOwnLayer(
            settings: LiquidGlassSettings(
              thickness: 40,
              lightAngle: 0.5 * pi,
              lightIntensity: 0.18,
              chromaticAberration: 1,
              blur: 1.5,
              glassColor: AppColors.primary,
            ),
            shape: const LiquidRoundedRectangle(borderRadius: 28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: WalletNavTabs(
                selectedIndex: selectedIndex,
                onTabChange: (index) {
                  ref.read(navIndexProvider.notifier).state = index;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav tabs ──────────────────────────────────────────────────────────────────

const _navTabs = [
  (Icons.attach_money_rounded, 'Salary'),
  (Icons.wallet_rounded, 'Wallet'),
  (Icons.bar_chart_rounded, 'Analytics'),
  (Icons.person_rounded, 'Profile'),
];

const _navLabelStyle = TextStyle(
  fontFamily: 'Rubik',
  fontWeight: FontWeight.w600,
  fontSize: 13,
  color: Colors.white,
);

const _navIconSize = 24.0;
const _navGap = 6.0;
// GNav leaves 8px after the label of the selected tab.
const _navLabelTail = 8.0;
// Labels stop growing with the system font beyond this, so the bar always fits.
const _navMaxTextScale = 1.3;

/// The tab row inside the glass bar. Its tab padding adapts to the width it is
/// given, so it never overflows on narrow screens or with a large system font.
class WalletNavTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChange;

  const WalletNavTabs({
    super.key,
    required this.selectedIndex,
    required this.onTabChange,
  });

  /// Side padding per tab (14 on roomy screens, down to 4) so the widest state,
  /// with the longest label selected, still fits in [maxWidth].
  static double tabPadding(double maxWidth, TextScaler scaler) {
    double labelWidth(String text) {
      final p = TextPainter(
        text: TextSpan(text: text, style: _navLabelStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    final widest = _navTabs.map((t) => labelWidth(t.$2)).reduce(max);
    final fixed =
        _navTabs.length * _navIconSize + _navGap + _navLabelTail + widest;
    // 8 spare px so the tab-switch animation never overflows halfway.
    final padding = (maxWidth - fixed - 8) / (2 * _navTabs.length);
    return padding.floorToDouble().clamp(4.0, 14.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final scaler =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: _navMaxTextScale);
    return LayoutBuilder(
      builder: (context, constraints) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: scaler),
        child: GNav(
          gap: _navGap,
          padding: EdgeInsets.symmetric(
            horizontal: tabPadding(constraints.maxWidth, scaler),
            vertical: 10,
          ),
          backgroundColor: Colors.transparent,
          tabBackgroundColor: Colors.white.withValues(alpha: 0.18),
          selectedIndex: selectedIndex,
          onTabChange: onTabChange,
          color: Colors.white.withValues(alpha: 0.55),
          activeColor: Colors.white,
          textStyle: _navLabelStyle,
          tabs: [
            for (final (icon, label) in _navTabs)
              GButton(icon: icon, text: label, iconSize: _navIconSize),
          ],
        ),
      ),
    );
  }
}
