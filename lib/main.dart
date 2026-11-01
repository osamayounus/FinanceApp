// ── main.dart ─────────────────────────────────────────────────────────────────
// App entry point. Reads the active profile from ProfileManager, loads its
// SQLite data, then mounts the correct root widget:
//   • OnboardingPage  — no profiles exist yet
//   • ProfilePickerPage — multiple profiles, must choose (e.g. after a reset)
//   • WalletLayoutPage  — active profile loaded and ready
//
// appConfigNotifier drives the root widget rebuild when profiles change.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/layout/walletLayoutPage.dart';
import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/models/profile_entry.dart';
import 'package:financeapp/models/user_model.dart';
import 'package:financeapp/modules/onboarding/onboardingPage.dart';
import 'package:financeapp/modules/profile/profile_picker_page.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:financeapp/shared/networks/local/profile_manager.dart';
import 'package:financeapp/shared/overlays/app_lock_gate.dart';
import 'package:financeapp/shared/services/app_lock.dart';
import 'package:financeapp/shared/services/bill_reminders.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ── App configuration ─────────────────────────────────────────────────────────

class AppConfig {
  final bool isSetup;
  final bool isFirstRun;
  /// True when the root should show ProfilePickerPage instead of OnboardingPage.
  final bool showPicker;
  final List<ProfileEntry> allProfiles;
  final int? activeProfileId;
  final AppDatabase? db;
  final UserModel? user;
  final List<AccountModel> accounts;
  final List<ExpenseModel> bills;

  const AppConfig({
    required this.isSetup,
    this.isFirstRun = false,
    this.showPicker = false,
    this.allProfiles = const [],
    this.activeProfileId,
    this.db,
    this.user,
    this.accounts = const [],
    this.bills = const [],
  });
}

/// Holds the bootstrapped app state. Updating this value triggers a full
/// ProviderScope rebuild via [ValueListenableBuilder] in [AppRoot].
final appConfigNotifier = ValueNotifier<AppConfig?>(null);

final _reminders = LocalBillReminders();

// ── Entry point ───────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) => _AppErrorWidget(details: details);

  final pm = ProfileManager.instance;

  // Migrate legacy single-DB installs to the per-profile file layout.
  await pm.migrateIfNeeded();

  final profiles = await pm.getProfiles();
  final activeId = await pm.getActiveProfileId();

  if (profiles.isEmpty || activeId == null) {
    // No profiles or no active selection — onboarding or picker.
    appConfigNotifier.value = AppConfig(
      isSetup: false,
      showPicker: profiles.isNotEmpty,
      allProfiles: profiles,
    );
  } else {
    final db = AppDatabase.forFile(pm.dbFileFor(activeId));
    final hasUser = await db.hasUser();
    if (hasUser) {
      final user = await db.getUser();
      final accounts = await db.getAccounts();
      final bills = await db.getBills();
      appConfigNotifier.value = AppConfig(
        isSetup: true,
        allProfiles: profiles,
        activeProfileId: activeId,
        db: db,
        user: user!,
        accounts: accounts,
        bills: bills,
      );
    } else {
      // Active profile ID set but DB is empty — fall back to onboarding.
      appConfigNotifier.value = AppConfig(
        isSetup: false,
        showPicker: profiles.isNotEmpty,
        allProfiles: profiles,
      );
    }
  }

  await AppLock.instance.load(); // before the first frame, so the app never shows unlocked
  runApp(const AppRoot());
}

// ── Root widget ───────────────────────────────────────────────────────────────

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    // The gate stays above the profile-keyed ProviderScope, so switching profile does not lock.
    return AppLockGate(
        child: ValueListenableBuilder<AppConfig?>(
      valueListenable: appConfigNotifier,
      builder: (context, config, _) {
        if (config == null) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final overrides = <Override>[];

        if (config.db != null) {
          overrides.add(dbProvider.overrideWithValue(config.db!));
        }

        if (config.isSetup && config.user != null && config.db != null) {
          overrides.addAll([
            userProvider.overrideWith(
                (ref) => UserNotifier(config.db!, config.user!)),
            accountsProvider.overrideWith(
                (ref) => AccountsNotifier(config.db!, config.accounts)),
            expensesProvider.overrideWith((ref) => BillsNotifier(
                config.db!, config.bills,
                reminders: _reminders,
                onCharged: () => ref.read(accountsProvider.notifier).reload())
              ..syncReminders()),
          ]);
        }

        // Key changes when the active profile changes so ProviderScope and all
        // its providers are torn down and recreated for the new profile.
        final scopeKey =
            ValueKey(config.isSetup ? config.activeProfileId : null);

        return ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          child: ProviderScope(
            key: scopeKey,
            overrides: overrides,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme:
                    ColorScheme.fromSeed(seedColor: const Color(0xFF0A0F2C)),
              ),
              home: config.isSetup
                  ? const Walletlayoutpage()
                  : config.showPicker
                      ? const ProfilePickerPage(canPop: false)
                      : const OnboardingPage(),
            ),
          ),
        );
      },
    ));
  }
}

// ── Custom error widget ───────────────────────────────────────────────────────

class _AppErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;
  const _AppErrorWidget({required this.details});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'An unexpected error occurred.\nPlease restart the app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
