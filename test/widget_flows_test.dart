import 'dart:io';
import 'dart:typed_data';

import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/modules/analytics/analyticsPage.dart';
import 'package:financeapp/modules/fixedExp/FixedExpensesPage.dart';
import 'package:financeapp/modules/history/historyPage.dart';
import 'package:financeapp/modules/home/homePage.dart';
import 'package:financeapp/modules/onboarding/onboardingPage.dart';
import 'package:financeapp/modules/operation/operationPage.dart';
import 'package:financeapp/modules/profile/profilePage.dart';
import 'package:financeapp/modules/salaryDay/salaryDayPage.dart';
import 'package:financeapp/modules/transfer/transferPage.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_env.dart';

void main() {
  setUpAll(() async {
    await setUpTestEnv();
    // flutter_test renders with the 4px-per-em "Ahem" font unless the app font is
    // loaded, which makes every Row overflow. Use the real Rubik metrics.
    final rubik = FontLoader('Rubik');
    for (final w in ['Regular', 'Bold', 'Light', 'Medium']) {
      rubik.addFont(File('lib/shared/styles/fonts/Rubik/Rubik-$w.ttf')
          .readAsBytes()
          .then((b) => ByteData.view(b.buffer)));
    }
    await rubik.load();
  });
  tearDownAll(tearDownTestEnv);

  late AppDatabase db;
  late ProviderContainer c;

  /// SQLite runs on a real isolate, so everything that touches the DB has to
  /// escape the fake-async zone of testWidgets.
  Future<void> bootstrap(WidgetTester t) async {
    await t.runAsync(() async {
      final env = await seededContainer();
      db = env.db;
      c = env.c;
    });
    addTearDown(() async {
      c.dispose();
      await t.runAsync(db.close);
    });
  }

  /// Every awaited DB call completes on a real isolate but its continuation runs
  /// in the fake-async zone, so each hop needs a real delay followed by a pump.
  Future<void> dbSettles(WidgetTester t) async {
    for (var i = 0; i < 12; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await t.pump(const Duration(milliseconds: 60));
    }
  }

  String onScreen(WidgetTester t) => t
      .widgetList<Text>(find.byType(Text))
      .map((e) => (e.data ?? '').replaceAll('\n', ' '))
      .join(' | ');

  /// Mounts [page] on top of a launcher route so Navigator.pop() inside the page is legal.
  Future<void> open(WidgetTester t, Widget page) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                    ctx, MaterialPageRoute(builder: (_) => page)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 200)); // ScreenUtilInit builds its child one frame late
    await t.tap(find.text('open'));
    await t.pump(const Duration(milliseconds: 100)); // route is built one frame after the push
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byWidget(page), findsOneWidget, reason: 'page failed to open: ${onScreen(t)}');
  }

  /// Fails with the full Flutter diagnostics (widget + file) instead of a one-line summary.
  void noException(WidgetTester t) {
    final e = t.takeException();
    expect(e, isNull, reason: e?.toString());
  }

  Future<void> tapText(WidgetTester t, String text) async {
    expect(find.text(text), findsWidgets, reason: 'on screen: ${onScreen(t)}');
    final f = find.text(text).first;
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pump(const Duration(milliseconds: 400));
  }

  // ── OperationPage ─────────────────────────────────────────────────────────

  group('OperationPage', () {
    testWidgets('deposit 50 into Wallet', (t) async {
      await bootstrap(t);
      await open(t, const OperationPage());
      await tapText(t, 'Wallet');
      await tapText(t, 'Deposit');
      await t.enterText(find.byType(TextField).first, '50');
      await tapText(t, 'Confirm');
      await dbSettles(t);
      expect(balanceOf(c, kWalletId), 650);
      final txs = await t.runAsync(() => db.getTransactions(kWalletId));
      expect(txs!.where((x) => x.type == 'deposit' && x.amount == 50), hasLength(1));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('open'), findsOneWidget, reason: 'page should have closed');
    });

    testWidgets('empty amount shows an error and changes nothing', (t) async {
      await bootstrap(t);
      await open(t, const OperationPage());
      await tapText(t, 'Wallet');
      await tapText(t, 'Withdraw');
      await tapText(t, 'Confirm');
      await dbSettles(t);
      expect(find.text('Enter a valid amount'), findsOneWidget);
      expect(balanceOf(c, kWalletId), 600);
    });

    testWidgets('withdraw more than the balance explains it is insufficient funds',
        (t) async {
      await bootstrap(t);
      await open(t, const OperationPage());
      await tapText(t, 'Wallet');
      await tapText(t, 'Withdraw');
      await t.enterText(find.byType(TextField).first, '9999');
      await tapText(t, 'Confirm');
      await dbSettles(t);
      expect(balanceOf(c, kWalletId), 600);
      expect(find.textContaining('Insufficient'), findsOneWidget,
          reason: 'user sees: ${t.widgetList<Text>(find.byType(Text)).map((e) => e.data).whereType<String>().where((s) => s.contains('debt') || s.contains('nsufficient')).toList()}');
    });

    testWidgets('"Receive Back" does nothing while no money is lent out',
        (t) async {
      await bootstrap(t);
      await open(t, const OperationPage());
      await tapText(t, 'Wallet');
      await tapText(t, 'Receive Back');
      expect(find.text('Receive back into Wallet:'), findsNothing);
    });

    testWidgets('lend then receive back, via the UI', (t) async {
      await bootstrap(t);
      await open(t, const OperationPage());
      await tapText(t, 'Wallet');
      await tapText(t, 'Give Debt');
      await t.enterText(find.byType(TextField).first, '100');
      await tapText(t, 'Confirm');
      await dbSettles(t);
      var w = c.read(accountsProvider).firstWhere((a) => a.id == kWalletId);
      expect((w.balance, w.loanedAmount), (500.0, 100.0));

      await open(t, const OperationPage());
      await tapText(t, 'Wallet');
      await tapText(t, 'Receive Back');
      await t.enterText(find.byType(TextField).first, '101');
      await tapText(t, 'Confirm');
      await dbSettles(t);
      expect(find.textContaining('Cannot exceed outstanding'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, '100');
      await tapText(t, 'Confirm');
      await dbSettles(t);
      w = c.read(accountsProvider).firstWhere((a) => a.id == kWalletId);
      expect((w.balance, w.loanedAmount), (600.0, 0.0));
    });

    testWidgets('amount field only accepts digits and a dot', (t) async {
      await bootstrap(t);
      await open(t, const OperationPage());
      await tapText(t, 'Wallet');
      await tapText(t, 'Deposit');
      await t.enterText(find.byType(TextField).first, '-5e3,x');
      expect(t.widget<TextField>(find.byType(TextField).first).controller!.text, '53');
    });

    testWidgets('amount "1.2.3" is rejected, not silently treated as 1.2',
        (t) async {
      await bootstrap(t);
      await open(t, const OperationPage());
      await tapText(t, 'Wallet');
      await tapText(t, 'Deposit');
      await t.enterText(find.byType(TextField).first, '1.2.3');
      await tapText(t, 'Confirm');
      await dbSettles(t);
      expect(balanceOf(c, kWalletId), 600);
    });
  });

  // ── TransferPage ──────────────────────────────────────────────────────────

  group('TransferPage', () {
    testWidgets('Wallet -> Savings moves the money', (t) async {
      await bootstrap(t);
      await open(t, const TransferPage());
      await t.enterText(find.byType(TextField).first, '200');
      await tapText(t, 'Confirm Transfer');
      await dbSettles(t);
      expect(balanceOf(c, kWalletId), 400);
      expect(balanceOf(c, kSavingsId), 300);
      await t.pump(const Duration(seconds: 5)); // let the success animation's timers finish
    });

    testWidgets('insufficient funds: error, no transfer', (t) async {
      await bootstrap(t);
      await open(t, const TransferPage());
      await t.enterText(find.byType(TextField).first, '601');
      await tapText(t, 'Confirm Transfer');
      await dbSettles(t);
      expect(find.textContaining('Insufficient balance'), findsOneWidget);
      expect(balanceOf(c, kWalletId), 600);
      expect(balanceOf(c, kSavingsId), 100);
    });

    testWidgets('zero amount: error, no transfer', (t) async {
      await bootstrap(t);
      await open(t, const TransferPage());
      await t.enterText(find.byType(TextField).first, '0');
      await tapText(t, 'Confirm Transfer');
      await dbSettles(t);
      expect(find.text('Enter a valid amount'), findsOneWidget);
    });
  });

  // ── Historypage: search, filter, edit, delete ─────────────────────────────

  group('Historypage', () {
    const page = Historypage(accountId: kWalletId, accountName: 'Wallet');

    /// Wallet: 600 + 50 - 30 - 12.5 = 607.5, then the page is opened.
    Future<void> openWithHistory(WidgetTester t) async {
      await bootstrap(t);
      await t.runAsync(() async {
        final n = c.read(accountsProvider.notifier);
        await n.deposit(kWalletId, 50, mkTx(kWalletId, 'deposit', 50, title: 'Freelance gig'));
        await n.withdraw(kWalletId, 30, mkTx(kWalletId, 'withdraw', 30, title: 'Groceries'));
        await n.withdraw(kWalletId, 12.5, mkTx(kWalletId, 'withdraw', 12.5, title: 'Taxi'));
      });
      await open(t, page);
      await dbSettles(t);
    }

    Future<double> walletTxAmount(WidgetTester t, String title) async {
      final txs = await t.runAsync(() => db.getTransactions(kWalletId));
      return txs!.firstWhere((x) => x.title == title).amount;
    }

    /// Opens a transaction's detail sheet by tapping its card.
    Future<void> openDetail(WidgetTester t, String title) async {
      await tapText(t, title);
      await t.pump(const Duration(milliseconds: 600));
    }

    testWidgets('search narrows the list as you type and clearing brings it back',
        (t) async {
      await openWithHistory(t);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Taxi'), findsOneWidget);

      await t.enterText(find.byType(TextField), 'groc');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Taxi'), findsNothing);
      expect(find.text('Freelance gig'), findsNothing);

      await t.enterText(find.byType(TextField), '');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Taxi'), findsOneWidget);
      noException(t);
    });

    testWidgets('search also finds an amount', (t) async {
      await openWithHistory(t);
      await t.enterText(find.byType(TextField), '12.5');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Taxi'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);
    });

    /// The chip row scrolls sideways; tapText's ensureVisible would re-centre it
    /// and push the other chips off screen, so tap in place.
    Future<void> tapChip(WidgetTester t, String label) async {
      await t.tap(find.text(label));
      await t.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a kind chip hides the other kinds', (t) async {
      await openWithHistory(t);
      await tapChip(t, 'Withdrawals');
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Taxi'), findsOneWidget);
      expect(find.text('Freelance gig'), findsNothing);

      await tapChip(t, 'Deposits');
      expect(find.text('Freelance gig'), findsOneWidget, reason: onScreen(t));
      expect(find.text('Taxi'), findsNothing);

      await tapChip(t, 'All');
      expect(find.text('Taxi'), findsOneWidget);
      expect(find.text('Freelance gig'), findsOneWidget);
    });

    testWidgets('nothing matching shows a message and "Clear filters" resets everything',
        (t) async {
      await openWithHistory(t);
      await tapChip(t, 'Transfers');
      await t.enterText(find.byType(TextField), 'zzz');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('No matching transactions'), findsOneWidget);

      await tapText(t, 'Clear filters');
      expect(find.text('No matching transactions'), findsNothing);
      expect(find.text('Taxi'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    testWidgets('an empty history shows no search bar', (t) async {
      await bootstrap(t);
      await t.runAsync(() async => (await db.database).delete('transactions'));
      await open(t, page);
      await dbSettles(t);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('No transactions yet'), findsOneWidget);
    });

    testWidgets('deleting a withdrawal returns the money and removes the card',
        (t) async {
      await openWithHistory(t);
      await openDetail(t, 'Groceries');
      await tapText(t, 'Delete');
      await t.pump(const Duration(milliseconds: 600)); // sheet closes, dialog opens
      expect(find.text('Delete transaction'), findsOneWidget);
      await tapText(t, 'Delete');
      await dbSettles(t);

      expect(balanceOf(c, kWalletId), 637.5);
      expect(find.text('Groceries'), findsNothing);
      expect(find.text('Taxi'), findsOneWidget);
      expect(find.text('Transaction deleted'), findsOneWidget);
    });

    testWidgets('cancelling the delete dialog changes nothing', (t) async {
      await openWithHistory(t);
      await openDetail(t, 'Groceries');
      await tapText(t, 'Delete');
      await t.pump(const Duration(milliseconds: 600));
      await tapText(t, 'Cancel');
      await dbSettles(t);
      expect(balanceOf(c, kWalletId), 607.5);
      expect(find.text('Groceries'), findsOneWidget);
    });

    testWidgets('a deposit that was already spent cannot be deleted', (t) async {
      await openWithHistory(t);
      await t.runAsync(() => c.read(accountsProvider.notifier).withdraw(
          kWalletId, 600, mkTx(kWalletId, 'withdraw', 600, title: 'Big spend')));
      await openDetail(t, 'Freelance gig');
      await tapText(t, 'Delete');
      await t.pump(const Duration(milliseconds: 600));
      await tapText(t, 'Delete');
      await dbSettles(t);

      expect(balanceOf(c, kWalletId), 7.5);
      expect(find.textContaining('Balance is too low'), findsOneWidget);
      expect(find.text('Freelance gig'), findsOneWidget);
    });

    testWidgets('editing the amount moves the balance and updates the card', (t) async {
      await openWithHistory(t);
      await openDetail(t, 'Groceries');
      await tapText(t, 'Edit');
      await t.pump(const Duration(milliseconds: 600));

      final amount = find.widgetWithText(TextField, 'Amount');
      expect(t.widget<TextField>(amount).controller!.text, '30',
          reason: 'the sheet starts from the stored amount');
      await t.enterText(amount, '45');
      await tapText(t, 'Save');
      await dbSettles(t);

      expect(balanceOf(c, kWalletId), 592.5);
      expect(await walletTxAmount(t, 'Groceries'), 45);
      expect(find.text('Transaction updated'), findsOneWidget);
    });

    testWidgets('editing the title and note keeps the amount and balance', (t) async {
      await openWithHistory(t);
      await openDetail(t, 'Taxi');
      await tapText(t, 'Edit');
      await t.pump(const Duration(milliseconds: 600));
      await t.enterText(find.widgetWithText(TextField, 'Title (optional)'), 'Uber');
      await t.enterText(find.widgetWithText(TextField, 'Note (optional)'), 'airport');
      await tapText(t, 'Save');
      await dbSettles(t);

      expect(balanceOf(c, kWalletId), 607.5);
      expect(find.text('Uber'), findsOneWidget);
      expect(find.text('Taxi'), findsNothing);
      expect(await walletTxAmount(t, 'Uber'), 12.5);
    });

    testWidgets('an empty or zero amount is rejected inside the sheet', (t) async {
      await openWithHistory(t);
      await openDetail(t, 'Taxi');
      await tapText(t, 'Edit');
      await t.pump(const Duration(milliseconds: 600));
      final amount = find.widgetWithText(TextField, 'Amount');

      await t.enterText(amount, '');
      await tapText(t, 'Save');
      expect(find.text('Enter a valid amount'), findsOneWidget);
      await t.enterText(amount, '0');
      await tapText(t, 'Save');
      expect(find.text('Enter a valid amount'), findsOneWidget);

      expect(balanceOf(c, kWalletId), 607.5);
      expect(await walletTxAmount(t, 'Taxi'), 12.5);
    });

    testWidgets('raising a withdrawal beyond the balance is refused with a message',
        (t) async {
      await openWithHistory(t);
      await openDetail(t, 'Taxi');
      await tapText(t, 'Edit');
      await t.pump(const Duration(milliseconds: 600));
      await t.enterText(find.widgetWithText(TextField, 'Amount'), '9999');
      await tapText(t, 'Save');
      await dbSettles(t);

      expect(find.textContaining('Balance is too low'), findsOneWidget);
      expect(balanceOf(c, kWalletId), 607.5);
      expect(await walletTxAmount(t, 'Taxi'), 12.5);
    });

    testWidgets('transfers and salary can be viewed but not edited or deleted',
        (t) async {
      await bootstrap(t);
      await t.runAsync(() => c.read(accountsProvider.notifier).transfer(
            fromId: kWalletId,
            toId: kSavingsId,
            amount: 20,
            txOut: mkTx(kWalletId, 'transfer_out', 20, title: 'Moved', related: kSavingsId),
            txIn: mkTx(kSavingsId, 'transfer_in', 20, title: 'Moved', related: kWalletId),
          ));
      await open(t, page);
      await dbSettles(t);

      await openDetail(t, 'Moved');
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
      await tapText(t, 'Close');
      await t.pump(const Duration(milliseconds: 600));

      await openDetail(t, 'Salary');
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });
  });

  // ── Backup rows on the profile page ───────────────────────────────────────

  testWidgets('profile page offers save, share and restore of a backup', (t) async {
    await bootstrap(t);
    await open(t, const Profilepage());
    await dbSettles(t);
    expect(find.text('Save Backup'), findsOneWidget);
    expect(find.text('Share Backup'), findsOneWidget);
    expect(find.text('Restore Backup'), findsOneWidget);
    noException(t);
  });

  // ── Render smoke tests ────────────────────────────────────────────────────

  group('pages render without exceptions', () {
    final pages = <String, Widget>{
      'Homepage': const Homepage(),
      'Historypage': const Historypage(accountId: kWalletId, accountName: 'Wallet'),
      'Fixedexpensespage': const Fixedexpensespage(),
      'AnalyticsPage': const AnalyticsPage(),
      'Profilepage': const Profilepage(),
      'Salarydaypage': const Salarydaypage(),
    };
    for (final e in pages.entries) {
      testWidgets(e.key, (t) async {
        await bootstrap(t);
        await t.runAsync(() async {
          await db.insertBill('Rent', 250, 'Housing');
          await db.insertBill('Net', 20.5, '');
          await db.insertTransaction(mkTx(kWalletId, 'deposit', 10));
        });
        c.read(expensesProvider.notifier).state = await t.runAsync(db.getBills) as List<ExpenseModel>;
        await open(t, e.value);
        await dbSettles(t);
        noException(t);
      });
    }

    testWidgets('OnboardingPage', (t) async {
      await bootstrap(t);
      await open(t, const OnboardingPage());
      noException(t);
    });

    testWidgets('Homepage shows an empty-bills / zero state without crashing',
        (t) async {
      await bootstrap(t);
      await t.runAsync(() async {
        await db.updateBalance(kWalletId, 0);
        await db.updateBalance(kBudgetId, 0);
        await db.updateBalance(kSavingsId, 0);
      });
      c.read(accountsProvider.notifier).state = await t.runAsync(db.getAccounts) as List<AccountModel>;
      await open(t, const Homepage());
      await dbSettles(t);
      noException(t);
    });
  });

  // ── Profile edit ──────────────────────────────────────────────────────────

  testWidgets('opening the salary editor and saving unchanged keeps decimals',
      (t) async {
    await bootstrap(t);
    c.read(userProvider.notifier).state =
        kTestUser.copyWith(salary: 1500.5);
    await open(t, const Profilepage());
    await dbSettles(t);
    // The salary row renders "<salary> JOD"
    final row = find.textContaining(' JOD').first;
    await t.ensureVisible(row);
    await t.tap(row);
    await t.pump(const Duration(milliseconds: 500));
    final field = find.byType(TextField).last;
    final shown = t.widget<TextField>(field).controller!.text;
    expect(shown, '1500.5', reason: 'editor pre-fills "$shown" (decimals truncated)');
  });

  testWidgets('profile editor refuses a budget that is not below the salary',
      (t) async {
    await bootstrap(t);
    await open(t, const Profilepage());
    await dbSettles(t);
    final budgetRow = find.textContaining(' JOD').at(1); // name, salary, budget
    await t.ensureVisible(budgetRow);
    await t.tap(budgetRow);
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500)); // sheet slide-in starts one frame after the tap
    await t.enterText(find.byType(TextField).last, '1000'); // salary is 1000
    await tapText(t, 'Save');
    await dbSettles(t);
    expect(c.read(userProvider).monthlyBudget, 400);
    expect(find.textContaining('Budget must be less than your salary'), findsOneWidget);
  });

  testWidgets('profile editor saves a valid decimal salary', (t) async {
    await bootstrap(t);
    await open(t, const Profilepage());
    await dbSettles(t);
    final salaryRow = find.textContaining(' JOD').first;
    await t.ensureVisible(salaryRow);
    await t.tap(salaryRow);
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500)); // sheet slide-in starts one frame after the tap
    await t.enterText(find.byType(TextField).last, '1250.75');
    await tapText(t, 'Save');
    await dbSettles(t);
    expect(c.read(userProvider).salary, 1250.75);
    final saved = await t.runAsync(db.getUser);
    expect(saved!.salary, 1250.75);
  });
}
