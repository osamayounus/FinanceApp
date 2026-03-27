// ── main.dart ─────────────────────────────────────────────────────────────────
// App entry point. Reads saved user data from SQLite, then mounts either
// OnboardingPage (first run) or WalletLayoutPage (returning user) inside a
// ProviderScope seeded with all initial state. appConfigNotifier drives the
// root widget rebuild when onboarding completes or data is reset.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:financeapp/layout/walletLayoutPage.dart';
import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/models/user_model.dart';
import 'package:financeapp/modules/onboarding/onboardingPage.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ── App configuration (set before runApp, updated after onboarding) ───────────

class AppConfig {
  final bool isSetup;
  final bool isFirstRun;
  final AppDatabase db;
  final UserModel? user;
  final List<AccountModel> accounts;
  final List<ExpenseModel> bills;

  const AppConfig({
    required this.isSetup,
    this.isFirstRun = false,
    required this.db,
    this.user,
    this.accounts = const [],
    this.bills = const [],
  });
}

/// Holds the bootstrapped app state. Updating this value triggers a full
/// ProviderScope rebuild via [ValueListenableBuilder] in [AppRoot], which is
/// the mechanism used both after onboarding completes and after a data reset.
/// A [ValueNotifier] is used (instead of a Riverpod provider) because the
/// notifier must be readable before the first ProviderScope is mounted.
final appConfigNotifier = ValueNotifier<AppConfig?>(null);

// ── Entry point ───────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom error screen (replaces the red crash screen)
  ErrorWidget.builder = (details) => _AppErrorWidget(details: details);

  final db = AppDatabase.instance;
  final hasUser = await db.hasUser();

  UserModel? user;
  List<AccountModel> accounts = [];
  List<ExpenseModel> bills = [];

  if (hasUser) {
    user = await db.getUser();
    accounts = await db.getAccounts();
    bills = await db.getBills();
  }

  appConfigNotifier.value = AppConfig(
    isSetup: hasUser,
    db: db,
    user: user,
    accounts: accounts,
    bills: bills,
  );

  runApp(const AppRoot());
}

// ── Root widget — ProviderScope always wraps MaterialApp ──────────────────────

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppConfig?>(
      valueListenable: appConfigNotifier,
      builder: (context, config, _) {
        if (config == null) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final overrides = <Override>[
          dbProvider.overrideWithValue(config.db),
        ];

        if (config.isSetup && config.user != null) {
          overrides.addAll([
            userProvider.overrideWith(
                (ref) => UserNotifier(config.db, config.user!)),
            accountsProvider.overrideWith(
                (ref) => AccountsNotifier(config.db, config.accounts)),
            expensesProvider.overrideWith(
                (ref) => BillsNotifier(config.db, config.bills)),
          ]);
        }

        // ValueKey forces Flutter to tear down and recreate the ProviderScope
        // (and all its providers) whenever isSetup toggles — e.g. after
        // onboarding finishes or after a full data reset.
        return ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          child: ProviderScope(
            key: ValueKey(config.isSetup),
            overrides: overrides,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme:
                    ColorScheme.fromSeed(seedColor: const Color(0xFF0A0F2C)),
              ),
              home: config.isSetup
                  ? const Walletlayoutpage()
                  : const OnboardingPage(),
            ),
          ),
        );
      },
    );
  }
}

// ── Custom error widget (replaces the red crash screen) ───────────────────────

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
