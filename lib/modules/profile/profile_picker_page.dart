// ── ProfilePickerPage ─────────────────────────────────────────────────────────
// Full-screen (or push-on-top) page that lists all saved profiles and lets the
// user switch to one or create a new one (max 3).
//
// Each tile shows wallet, savings, salary, and budget.
// The currently active profile is highlighted and cannot be tapped.
//
// [canPop] = false  → launched from AppRoot, back button hidden (must pick).
// [canPop] = true   → launched from ProfilePage, can dismiss.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/main.dart';
import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/profile_entry.dart';
import 'package:financeapp/models/user_model.dart';
import 'package:financeapp/modules/onboarding/onboardingPage.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:financeapp/shared/networks/local/profile_manager.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:financeapp/shared/utils/currency.dart';
import 'package:flutter/material.dart';

const int kMaxProfiles = 3;

// Snapshot of a single profile's financial data, loaded once on init.
class _ProfileSnapshot {
  final ProfileEntry profile;
  final UserModel? user;
  final double walletBalance;
  final double savingsBalance;

  const _ProfileSnapshot({
    required this.profile,
    required this.user,
    required this.walletBalance,
    required this.savingsBalance,
  });
}

class ProfilePickerPage extends StatefulWidget {
  final bool canPop;
  const ProfilePickerPage({super.key, this.canPop = true});

  @override
  State<ProfilePickerPage> createState() => _ProfilePickerPageState();
}

class _ProfilePickerPageState extends State<ProfilePickerPage> {
  List<_ProfileSnapshot> _snapshots = [];
  int? _activeProfileId;
  bool _loading = true;
  int? _switching;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pm = ProfileManager.instance;
    final profiles = await pm.getProfiles();
    final activeId = await pm.getActiveProfileId();

    final snapshots = <_ProfileSnapshot>[];
    for (final p in profiles) {
      final db = AppDatabase.forFile(pm.dbFileFor(p.id));
      final user = await db.getUser();
      final accounts = await db.getAccounts();
      double walletBal = 0.0;
      double savingsBal = 0.0;
      for (final a in accounts) {
        if (a.id == kWalletId) walletBal = a.balance;
        if (a.id == kSavingsId) savingsBal = a.balance;
      }
      snapshots.add(_ProfileSnapshot(
        profile: p,
        user: user,
        walletBalance: walletBal,
        savingsBalance: savingsBal,
      ));
    }

    if (mounted) {
      setState(() {
        _snapshots = snapshots;
        _activeProfileId = activeId;
        _loading = false;
      });
    }
  }

  Future<void> _switchTo(_ProfileSnapshot snap) async {
    setState(() => _switching = snap.profile.id);
    final pm = ProfileManager.instance;
    await pm.setActiveProfileId(snap.profile.id);

    final db = AppDatabase.forFile(pm.dbFileFor(snap.profile.id));
    final user = await db.getUser();
    final accounts = await db.getAccounts();
    final bills = await db.getBills();
    final allProfiles = await pm.getProfiles();

    appConfigNotifier.value = AppConfig(
      isSetup: user != null,
      allProfiles: allProfiles,
      activeProfileId: snap.profile.id,
      db: db,
      user: user,
      accounts: accounts,
      bills: bills,
    );

    if (mounted && widget.canPop) Navigator.pop(context);
  }

  void _addNew() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OnboardingPage(isFirstProfile: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSizes.m, AppSizes.m, AppSizes.m, 0),
              child: Row(
                children: [
                  if (widget.canPop)
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.primary,
                        size: AppSizes.iconM,
                      ),
                    )
                  else
                    SizedBox(width: AppSizes.m),
                  Expanded(
                    child: Text(
                      'Switch Profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: AppSizes.fontXXL,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: widget.canPop ? 0 : AppSizes.m + 24),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSizes.l, AppSizes.s, AppSizes.l, AppSizes.l),
              child: Text(
                'Choose a profile to continue',
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontS,
                  color: Colors.grey[400],
                ),
              ),
            ),

            // ── Profile list ──────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : ListView(
                      padding: EdgeInsets.symmetric(horizontal: AppSizes.m),
                      children: [
                        ..._snapshots.map((snap) {
                          final isActive = snap.profile.id == _activeProfileId;
                          return _ProfileTile(
                            snapshot: snap,
                            isActive: isActive,
                            isLoading: _switching == snap.profile.id,
                            onTap: (isActive || _switching != null)
                                ? null
                                : () => _switchTo(snap),
                          );
                        }),
                        if (_snapshots.length < kMaxProfiles)
                          _AddProfileTile(
                            onTap: _switching != null ? null : _addNew,
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

// ── Profile tile ──────────────────────────────────────────────────────────────

class _ProfileTile extends StatelessWidget {
  final _ProfileSnapshot snapshot;
  final bool isActive;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.snapshot,
    required this.isActive,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = snapshot.user;
    final currency = user?.currency ?? kDefaultCurrency;

    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.m),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.03)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        border: isActive
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.25), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          child: Padding(
            padding: EdgeInsets.all(AppSizes.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: avatar + name + badge ────────────────
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isActive
                              ? [AppColors.primary, AppColors.darkGradientEnd]
                              : [Colors.grey.shade400, Colors.grey.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          snapshot.profile.name.isNotEmpty
                              ? snapshot.profile.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSizes.s + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshot.profile.name,
                            style: TextStyle(
                              fontFamily: 'Rubik',
                              fontSize: AppSizes.fontM,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          if (user != null)
                            Text(
                              '${fmtAmt(user.salary, currency)} / month',
                              style: TextStyle(
                                fontFamily: 'Rubik',
                                fontSize: AppSizes.fontXS,
                                color: Colors.grey[400],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Active badge or chevron
                    if (isLoading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    else if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.grey[300], size: 22),
                  ],
                ),

                if (user != null) ...[
                  SizedBox(height: AppSizes.m),
                  Divider(height: 1, color: Colors.grey[100]),
                  SizedBox(height: AppSizes.m),

                  // ── 2×2 stats grid ─────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatCell(
                          label: 'Wallet',
                          value: fmtAmt(snapshot.walletBalance, currency),
                          icon: Icons.account_balance_wallet_rounded,
                          color: AppColors.myGreen,
                        ),
                      ),
                      Container(
                          width: 1, height: 36, color: Colors.grey[100]),
                      Expanded(
                        child: _StatCell(
                          label: 'Savings',
                          value: fmtAmt(snapshot.savingsBalance, currency),
                          icon: Icons.savings_rounded,
                          color: AppColors.blueIcon,
                        ),
                      ),
                      Container(
                          width: 1, height: 36, color: Colors.grey[100]),
                      Expanded(
                        child: _StatCell(
                          label: 'Budget',
                          value: fmtAmt(user.monthlyBudget, currency),
                          icon: Icons.receipt_long_rounded,
                          color: AppColors.myRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Single stat cell inside the grid ─────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 11, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: 10,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontS,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add new profile tile ──────────────────────────────────────────────────────

class _AddProfileTile extends StatelessWidget {
  final VoidCallback? onTap;
  const _AddProfileTile({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.m),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: AppSizes.m, vertical: AppSizes.m),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: AppColors.primary,
                    size: AppSizes.iconM,
                  ),
                ),
                SizedBox(width: AppSizes.m),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Profile',
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: AppSizes.fontM,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Up to 3 profiles per device',
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: AppSizes.fontXS,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
