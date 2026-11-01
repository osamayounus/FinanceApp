import 'dart:io';
import 'dart:typed_data';

import 'package:card_swiper/card_swiper.dart';

import 'package:financeapp/models/account_model.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/models/transaction_model.dart';
import 'package:financeapp/modules/analytics/analyticsPage.dart';
import 'package:financeapp/modules/analytics/widgets/category_budget_card.dart';
import 'package:financeapp/modules/analytics/widgets/debts_card.dart';
import 'package:financeapp/modules/home/widgets/debt_picker.dart';
import 'package:financeapp/modules/home/widgets/goal_picker.dart';
import 'package:financeapp/modules/home/widgets/goals_strip.dart';
import 'package:financeapp/modules/fixedExp/FixedExpensesPage.dart';
import 'package:financeapp/modules/fixedExp/bill_categories.dart';
import 'package:financeapp/modules/history/historyPage.dart';
import 'package:financeapp/modules/home/homePage.dart';
import 'package:financeapp/modules/onboarding/onboardingPage.dart';
import 'package:financeapp/modules/operation/operationPage.dart';
import 'package:financeapp/modules/profile/profilePage.dart';
import 'package:financeapp/modules/salaryDay/salaryDayPage.dart';
import 'package:financeapp/modules/salaryDay/salary_cycle.dart';
import 'package:financeapp/modules/transfer/transferPage.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:financeapp/shared/networks/local/profile_manager.dart';
import 'package:financeapp/shared/services/app_lock.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

    /// Withdraws [amount] from Wallet, tapping [chips] on the way, and returns the stored row.
    Future<TransactionModel> withdrawWith(WidgetTester t, String amount,
        {List<String> chips = const []}) async {
      await open(t, const OperationPage());
      await tapText(t, 'Wallet');
      await tapText(t, 'Withdraw');
      await t.enterText(find.byType(TextField).first, amount);
      for (final chip in chips) {
        await tapText(t, chip);
      }
      await tapText(t, 'Confirm');
      await dbSettles(t);
      final txs = await t.runAsync(() => db.getTransactions(kWalletId));
      return txs!.firstWhere((x) => x.type == 'withdraw');
    }

    testWidgets('a withdrawal can be tagged with a category', (t) async {
      await bootstrap(t);
      final tx = await withdrawWith(t, '12', chips: ['Food']);
      expect((tx.amount, tx.category), (12.0, 'Food'));
      expect(balanceOf(c, kWalletId), 588);
    });

    testWidgets('tapping the chosen category again clears it', (t) async {
      await bootstrap(t);
      final tx = await withdrawWith(t, '12', chips: ['Food', 'Food']);
      expect(tx.category, '');
    });

    testWidgets('choosing another category replaces the first', (t) async {
      await bootstrap(t);
      final tx = await withdrawWith(t, '12', chips: ['Food', 'Transport']);
      expect(tx.category, 'Transport');
    });

    testWidgets('a withdrawal without a choice stays uncategorised', (t) async {
      await bootstrap(t);
      final tx = await withdrawWith(t, '12');
      expect(tx.category, '');
    });

    testWidgets('deposits and debts offer no category', (t) async {
      await bootstrap(t);
      await open(t, const OperationPage());
      await dbSettles(t);
      await tapText(t, 'Wallet');
      await tapText(t, 'Deposit');
      expect(find.byType(CategoryPicker), findsNothing);
      // The previous step is still fading out, so the newest back button is the last one.
      await t.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 100));
      await tapText(t, 'Give Debt');
      expect(find.byType(CategoryPicker), findsNothing);
      noException(t);
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
      await dbSettles(t);
      await tapText(t, 'Wallet');
      await tapText(t, 'Receive Back');
      expect(find.text('Receive back into Wallet:'), findsNothing);
    });

    // ── Debts: who owes it, until when ──────────────────────────────────

    /// Wallet -> Give Debt with [amount] and [person] typed in (not confirmed).
    Future<void> fillDebt(WidgetTester t, String amount, String person) async {
      await open(t, const OperationPage());
      await dbSettles(t);
      await tapText(t, 'Wallet');
      await tapText(t, 'Give Debt');
      await t.enterText(find.byType(TextField).first, amount);
      if (person.isNotEmpty) {
        await t.enterText(find.widgetWithText(TextField, 'Who is borrowing it?'), person);
      }
    }

    Future<void> confirmAndSettle(WidgetTester t) async {
      await tapText(t, 'Confirm');
      await dbSettles(t);
    }

    testWidgets('Give Debt asks who it is for and moves nothing without it', (t) async {
      await bootstrap(t);
      await fillDebt(t, '100', '');
      await confirmAndSettle(t);
      expect(find.text('Enter who you are lending to'), findsOneWidget);
      expect(balanceOf(c, kWalletId), 600);
      expect(await t.runAsync(db.getOpenDebts), isEmpty);
      expect(find.text('Who is borrowing it?'), findsOneWidget, reason: 'still on the form');

      await t.enterText(find.widgetWithText(TextField, 'Who is borrowing it?'), '   ');
      await confirmAndSettle(t);
      expect(balanceOf(c, kWalletId), 600, reason: 'spaces are not a person');
    });

    testWidgets('lend then receive back, via the UI', (t) async {
      await bootstrap(t);
      await fillDebt(t, '100', ' Ali ');
      await confirmAndSettle(t);
      var w = c.read(accountsProvider).firstWhere((a) => a.id == kWalletId);
      expect((w.balance, w.loanedAmount), (500.0, 100.0));
      final debt = (await t.runAsync(db.getOpenDebts))!.single;
      expect((debt.person, debt.amount, debt.dueDate), ('Ali', 100.0, null));
      final lent = (await t.runAsync(() => db.getTransactions(kWalletId)))!
          .firstWhere((x) => x.type == 'debt_out');
      expect(lent.title, 'Lent to Ali', reason: 'history says who');
      expect(find.textContaining('100 JOD lent to Ali'), findsOneWidget, reason: onScreen(t));

      await open(t, const OperationPage());
      await dbSettles(t);
      await tapText(t, 'Wallet');
      await tapText(t, 'Receive Back');
      expect(find.text('Ali · 100 JOD'), findsOneWidget, reason: onScreen(t));
      expect(find.text('Outstanding: 100 JOD'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, '101');
      await tapText(t, 'Confirm');
      await dbSettles(t);
      expect(find.textContaining('Ali owes 100 JOD'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, '100');
      await tapText(t, 'Confirm');
      await dbSettles(t);
      w = c.read(accountsProvider).firstWhere((a) => a.id == kWalletId);
      expect((w.balance, w.loanedAmount), (600.0, 0.0));
      expect(await t.runAsync(db.getOpenDebts), isEmpty);
      final back = (await t.runAsync(() => db.getTransactions(kWalletId)))!
          .firstWhere((x) => x.type == 'debt_repaid');
      expect(back.title, 'Ali paid back');
    });

    testWidgets('with two people owing, the chip says who is paying back', (t) async {
      await bootstrap(t);
      await t.runAsync(() async {
        final n = c.read(accountsProvider.notifier);
        await n.lendDebt(kWalletId, 30, mkTx(kWalletId, 'debt_out', 30), person: 'Ali');
        await n.lendDebt(kWalletId, 50, mkTx(kWalletId, 'debt_out', 50), person: 'Sara');
      });
      await open(t, const OperationPage());
      await dbSettles(t);
      await tapText(t, 'Wallet');
      await tapText(t, 'Receive Back');
      expect(find.text('Outstanding: 30 JOD'), findsOneWidget,
          reason: 'the first debt is picked to start with');

      await tapText(t, 'Sara · 50 JOD');
      expect(find.text('Outstanding: 50 JOD'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, '20');
      await confirmAndSettle(t);

      final left = await t.runAsync(db.getOpenDebts);
      expect(left!.map((d) => (d.person, d.remaining)), [('Ali', 30.0), ('Sara', 30.0)]);
      final rep = (await t.runAsync(() => db.getTransactions(kWalletId)))!
          .firstWhere((x) => x.type == 'debt_repaid');
      expect((rep.title, rep.amount), ('Sara paid back', 20.0));
    });

    testWidgets('Receive Back only offers the debts of the chosen account', (t) async {
      await bootstrap(t);
      await t.runAsync(() async {
        final n = c.read(accountsProvider.notifier);
        await n.lendDebt(kWalletId, 30, mkTx(kWalletId, 'debt_out', 30), person: 'Ali');
        await n.lendDebt(kSavingsId, 40, mkTx(kSavingsId, 'debt_out', 40), person: 'Sara');
      });
      await open(t, const OperationPage());
      await dbSettles(t);
      await tapText(t, 'Savings');
      await tapText(t, 'Receive Back');
      expect(find.byType(DebtPicker), findsOneWidget);
      expect(find.text('Sara · 40 JOD'), findsOneWidget);
      expect(find.textContaining('Ali'), findsNothing);
    });

    testWidgets('the pay-back date is optional, can be picked and cleared', (t) async {
      await bootstrap(t);
      await fillDebt(t, '100', 'Ali');
      expect(find.text('Pay back by (optional)'), findsOneWidget);
      await tapText(t, 'Pay back by (optional)');
      await t.pump(const Duration(milliseconds: 400));
      await tapText(t, 'OK'); // the picker opens on a week from now
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Pay back by (optional)'), findsNothing);
      expect(find.text('Pay back by'), findsOneWidget);

      await t.tap(find.byTooltip('Clear date'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Pay back by (optional)'), findsOneWidget);

      await tapText(t, 'Pay back by (optional)');
      await t.pump(const Duration(milliseconds: 400));
      await tapText(t, 'OK');
      await t.pump(const Duration(milliseconds: 400));
      await confirmAndSettle(t);

      final now = DateTime.now();
      final debt = (await t.runAsync(db.getOpenDebts))!.single;
      expect(debt.dueDate, DateTime(now.year, now.month, now.day + 7));
    });

    testWidgets('amount field only accepts digits and a dot', (t) async {
      await bootstrap(t);
      await open(t, const OperationPage());
      await dbSettles(t);
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

    Future<String> walletTxCategory(WidgetTester t, String title) async {
      final txs = await t.runAsync(() => db.getTransactions(kWalletId));
      return txs!.firstWhere((x) => x.title == title).category;
    }

    testWidgets('editing a withdrawal can set its category, which History then shows and searches',
        (t) async {
      await openWithHistory(t);
      await openDetail(t, 'Groceries');
      expect(find.text('Category'), findsNothing, reason: 'nothing chosen yet');
      await tapText(t, 'Edit');
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byType(CategoryPicker), findsOneWidget);
      await tapText(t, 'Food');
      await tapText(t, 'Save');
      await dbSettles(t);

      expect(await walletTxCategory(t, 'Groceries'), 'Food');
      expect(balanceOf(c, kWalletId), 607.5, reason: 'the category does not move money');

      await openDetail(t, 'Groceries');
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
    });

    testWidgets('the search box finds a transaction by its category', (t) async {
      await bootstrap(t);
      await t.runAsync(() async {
        final n = c.read(accountsProvider.notifier);
        await n.withdraw(kWalletId, 8, mkTx(kWalletId, 'withdraw', 8, title: 'Falafel', category: 'Food'));
        await n.withdraw(kWalletId, 9, mkTx(kWalletId, 'withdraw', 9, title: 'Bus ticket'));
      });
      await open(t, page);
      await dbSettles(t);
      await t.enterText(find.byType(TextField), 'food');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Falafel'), findsOneWidget);
      expect(find.text('Bus ticket'), findsNothing);
    });

    testWidgets('the edit sheet scrolls to the category the transaction already has', (t) async {
      await bootstrap(t);
      await t.runAsync(() => c.read(accountsProvider.notifier).withdraw(
          kWalletId, 8, mkTx(kWalletId, 'withdraw', 8, title: 'Misc', category: 'Other')));
      await open(t, page);
      await dbSettles(t);
      await openDetail(t, 'Misc');
      await tapText(t, 'Edit');
      await t.pump(const Duration(milliseconds: 600));

      // "Other" is the last of eight chips, past the right edge of a phone screen.
      final width = t.view.physicalSize.width / t.view.devicePixelRatio;
      final x = t.getCenter(find.text('Other')).dx;
      expect(x, inInclusiveRange(0, width), reason: 'the chosen chip should be on screen');
    });

    testWidgets('a deposit has no category in its edit sheet', (t) async {
      await openWithHistory(t);
      await openDetail(t, 'Freelance gig');
      await tapText(t, 'Edit');
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byType(CategoryPicker), findsNothing);
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

  // ── Debts on the analytics page ───────────────────────────────────────────

  group('AnalyticsPage debts', () {
    Finder inCard(String text) =>
        find.descendant(of: find.byType(DebtsCard), matching: find.text(text));

    /// Ali owes 40 since yesterday; Sara owes 6 of the 10 she borrowed, no date.
    Future<void> openWithDebts(WidgetTester t, {bool lend = true}) async {
      await bootstrap(t);
      if (lend) {
        await t.runAsync(() async {
          final n = c.read(accountsProvider.notifier);
          final now = DateTime.now();
          await n.lendDebt(kWalletId, 40, mkTx(kWalletId, 'debt_out', 40),
              person: 'Ali', due: DateTime(now.year, now.month, now.day - 1));
          await n.lendDebt(kWalletId, 10, mkTx(kWalletId, 'debt_out', 10), person: 'Sara');
          final sara = (await db.getOpenDebts()).firstWhere((d) => d.person == 'Sara');
          await n.repayDebt(kWalletId, 4, mkTx(kWalletId, 'debt_repaid', 4), debtId: sara.id);
        });
      }
      await open(t, const AnalyticsPage());
      await dbSettles(t);
    }

    Future<void> openAli(WidgetTester t) async {
      await t.ensureVisible(inCard('Ali'));
      await t.tap(inCard('Ali'));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Edit debt'), findsOneWidget);
    }

    testWidgets('nobody owes you: no card', (t) async {
      await openWithDebts(t, lend: false);
      expect(find.byType(DebtsCard), findsNothing);
      noException(t);
    });

    testWidgets('shows who owes what, what is left and what is late', (t) async {
      await openWithDebts(t);
      expect(inCard('Money you lent'), findsOneWidget);
      expect(inCard('46 JOD'), findsOneWidget, reason: 'the total in the header');
      expect(inCard('40 JOD'), findsOneWidget);
      expect(inCard('6 JOD'), findsOneWidget);
      expect(inCard('of 10 JOD'), findsOneWidget, reason: 'only a part-paid debt shows the original');
      expect(inCard('Wallet · No due date'), findsOneWidget);
      final late = inCard('Wallet · Overdue since yesterday');
      expect(late, findsOneWidget, reason: onScreen(t));
      expect(t.widget<Text>(late).style!.color, AppColors.myRed);
      expect(t.widget<Text>(inCard('Wallet · No due date')).style!.color, isNot(AppColors.myRed));
      noException(t);
    });

    testWidgets('tapping a debt changes the person and keeps the rest', (t) async {
      await openWithDebts(t);
      await openAli(t);
      expect(t.widget<TextField>(find.widgetWithText(TextField, 'Who owes it')).controller!.text, 'Ali');
      await t.enterText(find.widgetWithText(TextField, 'Who owes it'), ' Ali Hassan ');
      await tapText(t, 'Save');
      await dbSettles(t);

      final ali = (await t.runAsync(db.getOpenDebts))!.firstWhere((d) => d.amount == 40);
      expect((ali.person, ali.remaining), ('Ali Hassan', 40.0));
      expect(ali.dueDate, isNotNull, reason: 'the date was not touched');
      expect(inCard('Ali Hassan'), findsOneWidget);
      expect(inCard('Ali'), findsNothing);
      noException(t);
    });

    testWidgets('the due date can be cleared', (t) async {
      await openWithDebts(t);
      await openAli(t);
      await t.tap(find.byTooltip('Clear date'));
      await t.pump(const Duration(milliseconds: 300));
      await tapText(t, 'Save');
      await dbSettles(t);

      expect((await t.runAsync(db.getOpenDebts))!.every((d) => d.dueDate == null), isTrue);
      expect(inCard('Wallet · No due date'), findsNWidgets(2));
      expect(inCard('Wallet · Overdue since yesterday'), findsNothing);
    });

    testWidgets('a blank name is refused and nothing changes', (t) async {
      await openWithDebts(t);
      await openAli(t);
      await t.enterText(find.widgetWithText(TextField, 'Who owes it'), '   ');
      await tapText(t, 'Save');
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Enter who owes it'), findsOneWidget);
      expect(find.text('Edit debt'), findsOneWidget, reason: 'the sheet stays open');
      expect((await t.runAsync(db.getOpenDebts))!.map((d) => d.person), contains('Ali'));
    });
  });

  // ── Category limits on the analytics page ─────────────────────────────────

  group('AnalyticsPage category limits', () {
    Finder inCard(String text) => find.descendant(
        of: find.byType(CategoryBudgetCard), matching: find.text(text));

    Future<void> openWithSpending(WidgetTester t,
        {double spent = 40, double? limit}) async {
      await bootstrap(t);
      await t.runAsync(() async {
        await c.read(accountsProvider.notifier).withdraw(kWalletId, spent,
            mkTx(kWalletId, 'withdraw', spent, category: 'Food'));
        if (limit != null) await db.setCategoryBudget('Food', limit);
      });
      await open(t, const AnalyticsPage());
      await dbSettles(t);
    }

    testWidgets('spending shows per category; a category with no limit says so', (t) async {
      await openWithSpending(t);
      expect(inCard('40 JOD'), findsOneWidget, reason: onScreen(t));
      expect(inCard('No limit'), findsNWidgets(7));
      noException(t);
    });

    testWidgets('tapping a category sets its limit and shows the progress', (t) async {
      await openWithSpending(t);
      await t.ensureVisible(inCard('Food'));
      await t.tap(inCard('Food'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Food limit'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Monthly limit'), '100');
      await tapText(t, 'Save');
      await dbSettles(t);

      expect(await t.runAsync(db.getCategoryBudgets), {'Food': 100.0});
      expect(inCard('40 / 100 JOD'), findsOneWidget, reason: onScreen(t));
      expect(
          find.descendant(
              of: find.byType(CategoryBudgetCard),
              matching: find.byType(LinearProgressIndicator)),
          findsOneWidget,
          reason: 'only Food has a limit, so only Food has a bar');
      noException(t);
    });

    testWidgets('an existing limit is prefilled and can be removed', (t) async {
      await openWithSpending(t, limit: 100);
      await t.ensureVisible(inCard('Food'));
      await t.tap(inCard('Food'));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.widget<TextField>(find.widgetWithText(TextField, 'Monthly limit')).controller!.text, '100');
      await tapText(t, 'Remove');
      await dbSettles(t);

      expect(await t.runAsync(db.getCategoryBudgets), isEmpty);
      expect(inCard('No limit'), findsNWidgets(7));
    });

    testWidgets('cancelling the dialog changes nothing', (t) async {
      await openWithSpending(t, limit: 100);
      await t.ensureVisible(inCard('Food'));
      await t.tap(inCard('Food'));
      await t.pump(const Duration(milliseconds: 400));
      await t.enterText(find.widgetWithText(TextField, 'Monthly limit'), '5');
      await tapText(t, 'Cancel');
      await dbSettles(t);
      expect(await t.runAsync(db.getCategoryBudgets), {'Food': 100.0});
    });

    testWidgets('an empty field removes the limit instead of saving garbage', (t) async {
      await openWithSpending(t, limit: 100);
      await t.ensureVisible(inCard('Food'));
      await t.tap(inCard('Food'));
      await t.pump(const Duration(milliseconds: 400));
      await t.enterText(find.widgetWithText(TextField, 'Monthly limit'), '');
      await tapText(t, 'Save');
      await dbSettles(t);
      expect(await t.runAsync(db.getCategoryBudgets), isEmpty);
    });

    testWidgets('going over a limit is shown in the card and in Smart Insights', (t) async {
      await openWithSpending(t, spent: 120, limit: 100);
      expect(inCard('120 / 100 JOD'), findsOneWidget, reason: onScreen(t));
      expect(find.text('Food is over its limit (120 of 100 JOD)'), findsOneWidget,
          reason: onScreen(t));
    });
  });

  group('Homepage savings goals', () {
    // seededContainer puts 100 into Savings.
    Finder inStrip(String text) =>
        find.descendant(of: find.byType(GoalsStrip), matching: find.text(text));
    Finder inStripContaining(String text) => find.descendant(
        of: find.byType(GoalsStrip), matching: find.textContaining(text));

    /// Goals as (name, target, set aside), created in this order.
    Future<void> openWithGoals(WidgetTester t,
        [List<(String, double, double)> goals = const []]) async {
      await bootstrap(t);
      await t.runAsync(() async {
        await ProfileManager.instance.markTutorialSeen('home'); // else its overlay swallows taps
        for (final (name, target, saved) in goals) {
          await db.insertSavingsGoal(name, target, saved: saved);
        }
      });
      await open(t, const Homepage());
      await dbSettles(t);
    }

    Future<void> openDialog(WidgetTester t, [String? goal]) async {
      final f = goal == null ? find.byTooltip('Add goal') : inStrip(goal);
      await t.ensureVisible(f);
      await t.tap(f);
      // a modal bottom sheet needs two pumps to finish sliding in
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 500));
    }

    Finder field(String label) => find.widgetWithText(TextField, label);
    const setAside = 'Set aside from Savings';

    testWidgets('the goals sit under the cards on the dashboard', (t) async {
      await openWithGoals(t, [('Laptop', 800, 60)]);
      final swiper = t.getTopLeft(find.byType(Swiper)).dy;
      final strip = t.getTopLeft(find.byType(GoalsStrip)).dy;
      expect(strip, greaterThan(swiper), reason: onScreen(t));
      noException(t);
    });

    testWidgets('with no goals it invites you to add one', (t) async {
      await openWithGoals(t);
      expect(inStrip('No goals yet · tap + to add one'), findsOneWidget, reason: onScreen(t));
      expect(inStrip('Unallocated: 100 JOD'), findsOneWidget);
      noException(t);
    });

    testWidgets('a new goal can take part of the free savings right away', (t) async {
      await openWithGoals(t);
      await openDialog(t);
      expect(find.text('Free: 100 JOD'), findsOneWidget);
      await t.enterText(field('Goal name'), 'Laptop');
      await t.enterText(field('Target amount'), '800');
      await t.enterText(field(setAside), '30');
      await tapText(t, 'Save');
      await dbSettles(t);

      final saved = (await t.runAsync(db.getSavingsGoals))!.single;
      expect((saved.name, saved.target, saved.saved, saved.targetDate),
          ('Laptop', 800.0, 30.0, null));
      expect(inStrip('30 / 800 JOD'), findsOneWidget, reason: onScreen(t));
      expect(inStrip('770 JOD left'), findsOneWidget);
      expect(inStrip('Unallocated: 70 JOD'), findsOneWidget);
      expect(balanceOf(c, kSavingsId), 100, reason: 'setting aside moves no money');
      noException(t);
    });

    testWidgets('leaving "set aside" empty creates an empty goal', (t) async {
      await openWithGoals(t);
      await openDialog(t);
      await t.enterText(field('Goal name'), 'Laptop');
      await t.enterText(field('Target amount'), '800');
      await tapText(t, 'Save');
      await dbSettles(t);

      expect((await t.runAsync(db.getSavingsGoals))!.single.saved, 0);
      expect(inStrip('0 / 800 JOD'), findsOneWidget, reason: onScreen(t));
      expect(inStrip('Unallocated: 100 JOD'), findsOneWidget);
    });

    testWidgets('a name and a positive target are required', (t) async {
      await openWithGoals(t);
      await openDialog(t);
      await tapText(t, 'Save');
      expect(find.text('Enter a name for the goal'), findsOneWidget);
      await t.enterText(field('Goal name'), 'Laptop');
      await t.enterText(field('Target amount'), '0');
      await tapText(t, 'Save');
      expect(find.text('Enter a valid target amount'), findsOneWidget);
      expect(await t.runAsync(db.getSavingsGoals), isEmpty);
      expect(find.text('New goal'), findsOneWidget, reason: 'the sheet stays open');
    });

    testWidgets('it cannot hold more than the target or more than is free', (t) async {
      await openWithGoals(t, [('Laptop', 800, 70)]); // 30 of the 100 is free
      await openDialog(t);
      await t.enterText(field('Goal name'), 'Trip');
      await t.enterText(field('Target amount'), '20');
      await t.enterText(field(setAside), '25');
      await tapText(t, 'Save');
      expect(find.text('Saved cannot be more than the target'), findsOneWidget);

      await t.enterText(field('Target amount'), '200');
      await t.enterText(field(setAside), '40');
      await tapText(t, 'Save');
      expect(find.text('Only 30 JOD of your savings is free'), findsOneWidget,
          reason: onScreen(t));
      expect((await t.runAsync(db.getSavingsGoals))!.map((g) => g.name), ['Laptop']);

      await t.enterText(field(setAside), '30'); // exactly what is free
      await tapText(t, 'Save');
      await dbSettles(t);
      expect((await t.runAsync(db.getSavingsGoals))!.map((g) => (g.name, g.saved)),
          [('Laptop', 70.0), ('Trip', 30.0)]);
      expect(inStrip('Unallocated: 0 JOD'), findsOneWidget, reason: onScreen(t));
    });

    testWidgets('a target date turns into a monthly amount', (t) async {
      await openWithGoals(t);
      await openDialog(t);
      await t.enterText(field('Goal name'), 'Trip');
      await t.enterText(field('Target amount'), '400');
      await t.enterText(field(setAside), '100');
      await tapText(t, 'Target date (optional)');
      await t.pump(const Duration(milliseconds: 400));
      await tapText(t, 'OK'); // the picker opens on today + 30 days
      await tapText(t, 'Save');
      await dbSettles(t);

      final d = DateTime.now().add(const Duration(days: 30));
      final saved = (await t.runAsync(db.getSavingsGoals))!.single;
      expect(saved.targetDate, DateTime(d.year, d.month, d.day));
      // 300 still to find, 30 days = one month
      expect(inStripContaining('300 JOD / month'), findsOneWidget, reason: onScreen(t));
    });

    testWidgets('a chosen target date can be cleared again', (t) async {
      await openWithGoals(t);
      await openDialog(t);
      await t.enterText(field('Goal name'), 'Trip');
      await t.enterText(field('Target amount'), '400');
      await tapText(t, 'Target date (optional)');
      await t.pump(const Duration(milliseconds: 400));
      await tapText(t, 'OK');
      expect(find.text('Target date (optional)'), findsNothing);
      await t.tap(find.byTooltip('Clear date'));
      await t.pump();
      expect(find.text('Target date (optional)'), findsOneWidget);
      await tapText(t, 'Save');
      await dbSettles(t);
      expect((await t.runAsync(db.getSavingsGoals))!.single.targetDate, isNull);
    });

    testWidgets('each goal shows its own envelope, and the rest is unallocated', (t) async {
      await openWithGoals(t, [('Laptop', 800, 60), ('Trip', 200, 25)]);
      expect(inStrip('60 / 800 JOD'), findsOneWidget, reason: onScreen(t));
      expect(inStrip('25 / 200 JOD'), findsOneWidget);
      expect(inStrip('Unallocated: 15 JOD'), findsOneWidget);
    });

    testWidgets('a full envelope is marked reached', (t) async {
      await openWithGoals(t, [('Phone', 60, 60)]);
      expect(inStrip('60 / 60 JOD'), findsOneWidget, reason: onScreen(t));
      expect(inStrip('Reached'), findsOneWidget);
    });

    testWidgets('editing prefills the goal; it may take its own money plus the free rest', (t) async {
      await openWithGoals(t, [('Laptop', 800, 60)]);
      await openDialog(t, 'Laptop');
      expect(t.widget<TextField>(field('Goal name')).controller!.text, 'Laptop');
      expect(t.widget<TextField>(field('Target amount')).controller!.text, '800');
      expect(t.widget<TextField>(field(setAside)).controller!.text, '60');
      expect(find.text('Free: 100 JOD'), findsOneWidget, reason: '60 of its own + 40 free');
      await t.enterText(field('Goal name'), 'Gaming laptop');
      await t.enterText(field('Target amount'), '1200');
      await t.enterText(field(setAside), '90');
      await tapText(t, 'Save');
      await dbSettles(t);

      final saved = (await t.runAsync(db.getSavingsGoals))!.single;
      expect((saved.name, saved.target, saved.saved), ('Gaming laptop', 1200.0, 90.0));
      expect(inStrip('90 / 1200 JOD'), findsOneWidget, reason: onScreen(t));
      expect(inStrip('Unallocated: 10 JOD'), findsOneWidget);
    });

    testWidgets('taking money out of a goal frees it for the others', (t) async {
      await openWithGoals(t, [('Laptop', 800, 100)]);
      expect(inStrip('Unallocated: 0 JOD'), findsOneWidget, reason: onScreen(t));
      await openDialog(t, 'Laptop');
      await t.enterText(field(setAside), '40');
      await tapText(t, 'Save');
      await dbSettles(t);
      expect(inStrip('Unallocated: 60 JOD'), findsOneWidget, reason: onScreen(t));
    });

    testWidgets('deleting a goal frees its money and leaves the savings alone', (t) async {
      await openWithGoals(t, [('Laptop', 800, 60), ('Trip', 200, 25)]);
      await openDialog(t, 'Laptop');
      await tapText(t, 'Delete');
      await dbSettles(t);

      expect((await t.runAsync(db.getSavingsGoals))!.map((g) => g.name), ['Trip']);
      expect(inStrip('Laptop'), findsNothing);
      expect(inStrip('25 / 200 JOD'), findsOneWidget, reason: 'Trip keeps its own money');
      expect(inStrip('Unallocated: 75 JOD'), findsOneWidget);
      expect(balanceOf(c, kSavingsId), 100);
    });

    testWidgets('when Savings is spent below what the goals hold, the strip says so', (t) async {
      await bootstrap(t);
      await t.runAsync(() async {
        await ProfileManager.instance.markTutorialSeen('home');
        await db.insertSavingsGoal('Laptop', 800, saved: 70);
        await db.insertSavingsGoal('Trip', 200, saved: 30);
        await c.read(accountsProvider.notifier).withdraw(
            kSavingsId, 60, mkTx(kSavingsId, 'withdraw', 60, title: 'Emergency'));
      });
      await open(t, const Homepage());
      await dbSettles(t);

      // 40 left: Laptop keeps its 40 of 70, Trip gets nothing; 60 is no longer there.
      expect(inStrip('40 / 800 JOD'), findsOneWidget, reason: onScreen(t));
      expect(inStrip('0 / 200 JOD'), findsOneWidget);
      expect(inStrip('60 JOD no longer in Savings'), findsOneWidget);
    });

    testWidgets('cancelling changes nothing', (t) async {
      await openWithGoals(t, [('Laptop', 800, 60)]);
      await openDialog(t, 'Laptop');
      await t.enterText(field('Target amount'), '5');
      await t.enterText(field(setAside), '1');
      await tapText(t, 'Cancel');
      await dbSettles(t);
      final g = (await t.runAsync(db.getSavingsGoals))!.single;
      expect((g.target, g.saved), (800, 60));
    });
  });

  // ── Picking a goal when money goes into / out of Savings ───────────────────

  group('Savings goal picker', () {
    Future<double> goalSaved(WidgetTester t, String name) async =>
        (await t.runAsync(db.getSavingsGoals))!.firstWhere((g) => g.name == name).saved;

    Future<void> seed(WidgetTester t, List<(String, double, double)> goals) async {
      await bootstrap(t);
      await t.runAsync(() async {
        for (final (name, target, saved) in goals) {
          await db.insertSavingsGoal(name, target, saved: saved);
        }
      });
    }

    /// Operation wizard on [account] / [op] up to the amount step, amount typed.
    Future<void> toAmountStep(WidgetTester t, String account, String op, String amount) async {
      await open(t, const OperationPage());
      await dbSettles(t); // the goals provider has to be loaded
      await tapText(t, account);
      await tapText(t, op);
      await t.enterText(find.byType(TextField).first, amount);
    }

    testWidgets('a Savings deposit can go into a goal', (t) async {
      await seed(t, [('Laptop', 800, 10), ('Trip', 200, 0)]);
      await toAmountStep(t, 'Savings', 'Deposit', '50');
      expect(find.text('Put into a goal (optional)'), findsOneWidget);
      await tapText(t, 'Laptop');
      await tapText(t, 'Confirm');
      await dbSettles(t);

      expect(balanceOf(c, kSavingsId), 150);
      expect((await goalSaved(t, 'Laptop'), await goalSaved(t, 'Trip')), (60.0, 0.0));
      expect(find.textContaining('50 JOD to Laptop'), findsOneWidget, reason: onScreen(t));
    });

    testWidgets('"No goal" (the default) leaves the money unallocated', (t) async {
      await seed(t, [('Laptop', 800, 10)]);
      await toAmountStep(t, 'Savings', 'Deposit', '50');
      await tapText(t, 'Confirm');
      await dbSettles(t);

      expect(balanceOf(c, kSavingsId), 150);
      expect(await goalSaved(t, 'Laptop'), 10);
    });

    testWidgets('a goal never takes more than it still needs', (t) async {
      await seed(t, [('Phone', 30, 20)]);
      await toAmountStep(t, 'Savings', 'Deposit', '50');
      await tapText(t, 'Phone');
      await tapText(t, 'Confirm');
      await dbSettles(t);

      expect(balanceOf(c, kSavingsId), 150, reason: 'the whole deposit still lands in Savings');
      expect(await goalSaved(t, 'Phone'), 30);
      expect(find.textContaining('10 JOD to Phone'), findsOneWidget, reason: onScreen(t));
    });

    testWidgets('choosing "No goal" after a goal clears the pick', (t) async {
      await seed(t, [('Laptop', 800, 0)]);
      await toAmountStep(t, 'Savings', 'Deposit', '50');
      await tapText(t, 'Laptop');
      await tapText(t, 'No goal');
      await tapText(t, 'Confirm');
      await dbSettles(t);
      expect(await goalSaved(t, 'Laptop'), 0);
    });

    testWidgets('a Savings withdrawal can come out of a goal', (t) async {
      await seed(t, [('Laptop', 800, 60)]);
      await toAmountStep(t, 'Savings', 'Withdraw', '20');
      expect(find.text('Take from a goal (optional)'), findsOneWidget);
      await tapText(t, 'Laptop');
      await tapText(t, 'Confirm');
      await dbSettles(t);

      expect(balanceOf(c, kSavingsId), 80);
      expect(await goalSaved(t, 'Laptop'), 40);
    });

    testWidgets('a withdrawal takes no more from a goal than it holds', (t) async {
      await seed(t, [('Laptop', 800, 15)]);
      await toAmountStep(t, 'Savings', 'Withdraw', '20');
      await tapText(t, 'Laptop');
      await tapText(t, 'Confirm');
      await dbSettles(t);

      expect(balanceOf(c, kSavingsId), 80);
      expect(await goalSaved(t, 'Laptop'), 0);
    });

    testWidgets('a failed Savings withdrawal leaves the goal alone', (t) async {
      await seed(t, [('Laptop', 800, 60)]);
      await toAmountStep(t, 'Savings', 'Withdraw', '500'); // only 100 in Savings
      await tapText(t, 'Laptop');
      await tapText(t, 'Confirm');
      await dbSettles(t);

      expect(balanceOf(c, kSavingsId), 100);
      expect(await goalSaved(t, 'Laptop'), 60);
    });

    testWidgets('other accounts offer no goals', (t) async {
      await seed(t, [('Laptop', 800, 0)]);
      await toAmountStep(t, 'Wallet', 'Deposit', '5');
      expect(find.byType(GoalPicker), findsNothing);
    });

    testWidgets('a loan from Savings is not a goal deposit', (t) async {
      await seed(t, [('Laptop', 800, 0)]);
      await open(t, const OperationPage());
      await dbSettles(t);
      await tapText(t, 'Savings');
      await tapText(t, 'Give Debt');
      expect(find.byType(GoalPicker), findsNothing);
    });

    testWidgets('no goals, no picker', (t) async {
      await seed(t, []);
      await toAmountStep(t, 'Savings', 'Deposit', '5');
      expect(find.byType(GoalPicker), findsNothing);
    });

    testWidgets('Wallet -> Savings transfer can fill a goal', (t) async {
      await seed(t, [('Laptop', 800, 10)]);
      await open(t, const TransferPage());
      await dbSettles(t);
      expect(find.text('Put into a goal (optional)'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, '40');
      await tapText(t, 'Laptop');
      await tapText(t, 'Confirm Transfer');
      await dbSettles(t);

      expect((balanceOf(c, kWalletId), balanceOf(c, kSavingsId)), (560.0, 140.0));
      expect(await goalSaved(t, 'Laptop'), 50);
      await t.pump(const Duration(seconds: 5)); // let the success animation's timers finish
    });

    testWidgets('a transfer without a pick leaves the goals alone', (t) async {
      await seed(t, [('Laptop', 800, 10)]);
      await open(t, const TransferPage());
      await dbSettles(t);
      await t.enterText(find.byType(TextField).first, '40');
      await tapText(t, 'Confirm Transfer');
      await dbSettles(t);

      expect(balanceOf(c, kSavingsId), 140);
      expect(await goalSaved(t, 'Laptop'), 10);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('Savings -> Wallet takes from a goal, and swapping resets the pick', (t) async {
      await seed(t, [('Laptop', 800, 60)]);
      await open(t, const TransferPage());
      await dbSettles(t);
      await tapText(t, 'Laptop');
      expect(t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Laptop')).selected, isTrue);

      await t.ensureVisible(find.byIcon(Icons.swap_vert_rounded));
      await t.tap(find.byIcon(Icons.swap_vert_rounded));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Take from a goal (optional)'), findsOneWidget);
      expect(t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Laptop')).selected, isFalse,
          reason: 'the pick belongs to the old direction');

      await t.enterText(find.byType(TextField).first, '25');
      await tapText(t, 'Laptop');
      await tapText(t, 'Confirm Transfer');
      await dbSettles(t);

      expect((balanceOf(c, kWalletId), balanceOf(c, kSavingsId)), (625.0, 75.0));
      expect(await goalSaved(t, 'Laptop'), 35);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('a transfer between other accounts offers no goals', (t) async {
      await seed(t, [('Laptop', 800, 0)]);
      await open(t, const TransferPage());
      await dbSettles(t);
      expect(find.byType(GoalPicker), findsOneWidget, reason: 'Wallet -> Savings offers it');
      // Wallet -> Budget: pick Budget as the destination. The account sheet trips a
      // debug-only ListTile-over-DecoratedBox assertion that has nothing to do with goals.
      await tapText(t, 'Savings'); // the "To" row
      await t.pump(const Duration(milliseconds: 400));
      await tapText(t, 'Monthly Budget');
      while (t.takeException() != null) {}
      expect(find.byType(GoalPicker), findsNothing);
    });
  });

  testWidgets("paying a bill records the payment under the bill's category", (t) async {
    await bootstrap(t);
    await t.runAsync(() async {
      await db.insertBill('Rent', 250, 'Housing');
      await db.markTutorialSeen('tutorial_bills'); // else its overlay swallows the taps
    });
    c.read(expensesProvider.notifier).state = await t.runAsync(db.getBills) as List<ExpenseModel>;
    await open(t, const Fixedexpensespage());
    await dbSettles(t);
    await t.tap(find.byIcon(Icons.check_circle_outline_rounded));
    await t.pump(const Duration(milliseconds: 400));
    await tapText(t, 'Confirm');
    await dbSettles(t);

    final txs = await t.runAsync(() => db.getTransactions(kWalletId));
    final paid = txs!.firstWhere((x) => x.type == 'bill_paid');
    expect((paid.title, paid.category), ('Rent', 'Housing'));
    expect(balanceOf(c, kWalletId), 350);
  });

  group('FixedExpensesPage due days', () {
    final tomorrow = DateTime.now().add(const Duration(days: 1)).day;
    const dueField = 'Due day of the month (optional)';

    /// Opens the page with [seed] already in the DB (the tutorial would swallow taps).
    Future<void> openBills(WidgetTester t,
        {Future<void> Function()? seed}) async {
      await bootstrap(t);
      await t.runAsync(() async {
        await db.markTutorialSeen('tutorial_bills');
        await seed?.call();
      });
      c.read(expensesProvider.notifier).state =
          await t.runAsync(db.getBills) as List<ExpenseModel>;
      await open(t, const Fixedexpensespage());
      await dbSettles(t);
    }

    Finder field(String label) => find.widgetWithText(TextField, label);

    Future<void> fillSheet(WidgetTester t, {required String due}) async {
      await t.tap(find.byIcon(Icons.add));
      await t.pump(const Duration(milliseconds: 100)); // route is built one frame after the tap
      await t.pump(const Duration(milliseconds: 500));
      await t.enterText(field('Bill Name'), 'Rent');
      await t.enterText(field('Amount (JOD)'), '120');
      await t.enterText(field(dueField), due);
      await t.pump();
    }

    testWidgets('the card says when an unpaid bill is due and when it is late', (t) async {
      await openBills(t, seed: () async {
        await db.insertBill('Soon', 10, '', dueDay: tomorrow);
        await db.insertBill('Late', 10, '',
            dueDay: DateTime.now().subtract(const Duration(days: 3)).day);
        await db.insertBill('Undated', 10, '');
        final paid = await db.insertBill('Done', 10, '',
            dueDay: DateTime.now().subtract(const Duration(days: 3)).day);
        await db.markBillPaid(paid);
        // The cycle began 20 days ago, so "3 days ago" is inside it.
        await (await db.database).update(
            'transactions',
            {
              'created_at': DateTime.now()
                  .subtract(const Duration(days: 20))
                  .millisecondsSinceEpoch
            },
            where: "type = 'salary'");
      });
      await dbSettles(t);
      expect(find.textContaining('Due tomorrow'), findsOneWidget);
      expect(find.textContaining('Overdue by 3 days'), findsOneWidget);
      expect(find.textContaining('Due'), findsOneWidget,
          reason: 'undated and paid bills show no due line');
      expect(find.textContaining('Overdue'), findsOneWidget);
    });

    testWidgets('a due day typed in the add sheet is saved and shown', (t) async {
      await openBills(t);
      await fillSheet(t, due: '$tomorrow');
      await tapText(t, 'Add');
      await dbSettles(t);

      final saved = (await t.runAsync(db.getBills))!.single;
      expect((saved.name, saved.dueDay), ('Rent', tomorrow));
      expect(find.textContaining('Due tomorrow'), findsOneWidget);
    });

    testWidgets('a bill needs no due day', (t) async {
      await openBills(t);
      await fillSheet(t, due: '');
      await tapText(t, 'Add');
      await dbSettles(t);

      expect((await t.runAsync(db.getBills))!.single.dueDay, isNull);
      expect(find.textContaining('Due'), findsNothing);
    });

    testWidgets('a day outside 1-31 is refused with a message and saves nothing', (t) async {
      await openBills(t);
      await fillSheet(t, due: '40');
      await tapText(t, 'Add');
      await dbSettles(t);

      expect(find.text('Due day must be between 1 and 31'), findsOneWidget,
          reason: onScreen(t));
      expect(await t.runAsync(db.getBills), isEmpty);
      await t.enterText(field(dueField), '0');
      await tapText(t, 'Add');
      expect(find.text('Due day must be between 1 and 31'), findsOneWidget);
      expect(await t.runAsync(db.getBills), isEmpty);
    });

    testWidgets('editing prefills the due day and clearing it removes it', (t) async {
      await openBills(t, seed: () async {
        await db.insertBill('Rent', 120, '', dueDay: tomorrow);
      });
      await t.tap(find.text('Rent'));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 500));
      expect(t.widget<TextField>(field(dueField)).controller!.text, '$tomorrow');

      await t.enterText(field(dueField), '');
      await tapText(t, 'Save');
      await dbSettles(t);

      expect((await t.runAsync(db.getBills))!.single.dueDay, isNull);
      expect(find.textContaining('Due'), findsNothing);
    });

    Future<void> flipAutoPay(WidgetTester t) async {
      await t.ensureVisible(find.byType(Switch));
      await t.tap(find.byType(Switch));
      await t.pump();
    }

    testWidgets('Pay automatically is saved with the bill and the card says Auto-pay', (t) async {
      await openBills(t);
      await fillSheet(t, due: '$tomorrow');
      await flipAutoPay(t);
      await tapText(t, 'Add');
      await dbSettles(t);

      expect((await t.runAsync(db.getBills))!.single.autoPay, isTrue);
      expect(find.textContaining('Auto-pay'), findsOneWidget, reason: onScreen(t));
      expect(balanceOf(c, kWalletId), 600, reason: 'due tomorrow, nothing is charged yet');
    });

    testWidgets('Pay automatically without a due day is refused and saves nothing', (t) async {
      await openBills(t);
      await fillSheet(t, due: '');
      await flipAutoPay(t);
      await tapText(t, 'Add');
      await dbSettles(t);

      expect(find.text('Set a due day to pay it automatically'), findsOneWidget,
          reason: onScreen(t));
      expect(await t.runAsync(db.getBills), isEmpty);
    });

    testWidgets('a bill saved with Pay automatically after its due day is charged at once, with a toast',
        (t) async {
      await openBills(t);
      await fillSheet(t, due: '${DateTime.now().day}');
      await flipAutoPay(t);
      await tapText(t, 'Add');
      await dbSettles(t);

      expect((await t.runAsync(db.getBills))!.single.isPaid, isTrue);
      expect(balanceOf(c, kWalletId), 600 - 120);
      expect(find.textContaining('Rent paid automatically'), findsOneWidget, reason: onScreen(t));
      expect(find.textContaining('Auto-pay'), findsNothing, reason: 'a paid bill shows no badge');
    });

    testWidgets('editing shows the switch as saved and turning it off keeps the bill unpaid',
        (t) async {
      await openBills(t, seed: () async {
        await db.insertBill('Rent', 120, '', dueDay: tomorrow, autoPay: true);
      });
      await t.tap(find.text('Rent'));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 500));
      expect(t.widget<Switch>(find.byType(Switch)).value, isTrue);

      await flipAutoPay(t);
      await tapText(t, 'Save');
      await dbSettles(t);

      final bill = (await t.runAsync(db.getBills))!.single;
      expect((bill.autoPay, bill.isPaid), (false, false));
      expect(find.textContaining('Auto-pay'), findsNothing);
    });
  });

  // ── Render smoke tests ────────────────────────────────────────────────────

  group('CardBalanceSection', () {
    // Wallet card with money lent out: AVAILABLE and TOTAL sit side by side and
    // used to overflow by ~40 px once the balance had four digits.
    for (final (available, loaned) in [(2402.25, 25.0), (12345.67, 100.0)]) {
      testWidgets('dual mode fits with $available + $loaned lent', (t) async {
        t.view.physicalSize = const Size(1170, 2532);
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        await t.pumpWidget(ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 250,
                  child: CardBalanceSection(
                    available: available,
                    loanedAmount: loaned,
                    currency: 'JOD',
                    label: 'BALANCE',
                    mainColor: Colors.black,
                    subColor: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ));
        await t.pump(const Duration(milliseconds: 200));
        noException(t);
        expect(find.textContaining('TOTAL'), findsOneWidget);
        expect(t.getSize(find.byType(CardBalanceSection)).width, lessThanOrEqualTo(250));
      });
    }
  });

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

  group('App lock in the profile', () {
    Future<FakeAuthenticator> openProfile(WidgetTester t) async {
      final phone = FakeAuthenticator();
      await bootstrap(t);
      await t.runAsync(() => resetAppLock(phone));
      addTearDown(() => resetAppLock(FakeAuthenticator()));
      await open(t, const Profilepage());
      await dbSettles(t);
      await t.ensureVisible(find.text('App Lock'));
      return phone;
    }

    testWidgets('turns on after the phone confirms, and off again', (t) async {
      final phone = await openProfile(t);
      expect(find.text('Off'), findsOneWidget, reason: onScreen(t));

      await t.tap(find.text('App Lock'));
      await dbSettles(t);
      expect(AppLock.instance.enabled.value, isTrue);
      expect(await t.runAsync(ProfileManager.instance.isLockEnabled), isTrue);
      expect(find.text('On'), findsOneWidget, reason: onScreen(t));

      await t.tap(find.text('App Lock'));
      await dbSettles(t);
      expect(AppLock.instance.enabled.value, isFalse);
      expect(await t.runAsync(ProfileManager.instance.isLockEnabled), isFalse);
      expect(phone.asked, ['Turn on the app lock', 'Turn off the app lock']);
    });

    testWidgets('stays off, with a message, when the phone does not confirm', (t) async {
      final phone = await openProfile(t);
      phone.accept = false;
      await t.tap(find.text('App Lock'));
      await dbSettles(t);
      expect(find.text('Could not confirm it is you'), findsOneWidget, reason: onScreen(t));
      expect(AppLock.instance.enabled.value, isFalse);
      expect(await t.runAsync(ProfileManager.instance.isLockEnabled), isFalse);
    });

    testWidgets('says so when the phone has no screen lock', (t) async {
      final phone = await openProfile(t);
      phone.supported = false;
      await t.tap(find.text('App Lock'));
      await dbSettles(t);
      expect(find.textContaining('Set a screen lock'), findsOneWidget, reason: onScreen(t));
      expect(AppLock.instance.enabled.value, isFalse);
    });
  });

  group('Salary day', () {
    Future<void> openProfileDayEditor(WidgetTester t, {bool first = true}) async {
      if (first) {
        await bootstrap(t);
        await open(t, const Profilepage());
        await dbSettles(t);
      }
      final row = find.text('Day 1'); // the default
      await t.ensureVisible(row);
      await t.tap(row);
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(milliseconds: 500));
    }

    testWidgets('the profile shows the day and saves a new one', (t) async {
      await openProfileDayEditor(t);
      expect(t.widget<TextField>(find.byType(TextField).last).controller!.text, '1');
      await t.enterText(find.byType(TextField).last, '27');
      await tapText(t, 'Save');
      await dbSettles(t);
      expect(c.read(userProvider).salaryDay, 27);
      expect((await t.runAsync(db.getUser))!.salaryDay, 27);
      expect(find.text('Day 27'), findsOneWidget);
    });

    testWidgets('the profile refuses a day that is not 1 to 31', (t) async {
      for (final (i, bad) in ['0', '32', '2.5'].indexed) {
        // the sheet closes on Save and the error is a toast, so open it again each time
        await openProfileDayEditor(t, first: i == 0);
        await t.enterText(find.byType(TextField).last, bad);
        await tapText(t, 'Save');
        await t.pump(const Duration(milliseconds: 500));
        expect(find.text('Enter a day from 1 to 31'), findsOneWidget, reason: 'day "$bad"');
        expect(c.read(userProvider).salaryDay, 1);
      }
    });

    Future<void> openSalaryPage(WidgetTester t, {bool processed = false}) async {
      await bootstrap(t);
      await t.runAsync(() async {
        await db.markTutorialSeen('tutorial_salary');
        if (processed) await db.processSalaryDay(salary: 1000, monthlyBudget: 400);
      });
      await open(t, const Salarydaypage());
      await dbSettles(t);
    }

    final now = DateTime.now();

    testWidgets('before the salary it says which day it is and waits', (t) async {
      await openSalaryPage(t);
      expect(
          find.text('Salary day ${salaryDate(salaryCycleStart(now, 1))} · '
              'press the coin when your salary arrives'),
          findsOneWidget,
          reason: onScreen(t));
    });

    testWidgets('after it was processed it says so and refuses a second press', (t) async {
      await openSalaryPage(t, processed: true);
      expect(
          find.text('Salary processed on ${salaryDate(now)} · '
              'next salary day ${salaryDate(nextSalaryDay(now, 1))}'),
          findsOneWidget,
          reason: onScreen(t));
      final wallet = (await t.runAsync(db.getAccounts))!
          .firstWhere((a) => a.id == kWalletId)
          .balance;

      await t.tap(find.byType(SvgPicture));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Salary already processed on ${salaryDate(now)}'),
          findsOneWidget,
          reason: onScreen(t));
      expect(find.text('نزل الراتب؟'), findsNothing, reason: 'no confirmation to click through');
      expect((await t.runAsync(db.getAccounts))!.firstWhere((a) => a.id == kWalletId).balance,
          wallet);
    });

    testWidgets('pressing the coin asks, processes once and then shows it', (t) async {
      await openSalaryPage(t);
      await t.tap(find.byType(SvgPicture));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('نزل الراتب؟'), findsOneWidget, reason: onScreen(t));
      await tapText(t, 'YES! 🎉');
      await dbSettles(t);

      expect(await t.runAsync(db.lastSalaryProcessedAt), isNotNull);
      expect(
          (await t.runAsync(db.getAccounts))!.firstWhere((a) => a.id == kWalletId).balance,
          600 + 400 + 600, // wallet + budget leftover + net salary
          reason: onScreen(t));
      expect(find.textContaining('Salary processed on ${salaryDate(now)}'), findsOneWidget);
    });

    testWidgets('pressing the coin also charges the auto-pay bills due that day', (t) async {
      await bootstrap(t);
      await t.runAsync(() async {
        await db.markTutorialSeen('tutorial_salary');
        await db.insertBill('Rent', 100, '', dueDay: now.day, autoPay: true);
        await db.insertBill('Later', 50, '', dueDay: now.add(const Duration(days: 3)).day, autoPay: true);
      });
      c.read(expensesProvider.notifier).state =
          await t.runAsync(db.getBills) as List<ExpenseModel>;
      await open(t, const Salarydaypage());
      await dbSettles(t);
      await t.tap(find.byType(SvgPicture));
      await t.pump(const Duration(milliseconds: 300));
      await tapText(t, 'YES! 🎉');
      await dbSettles(t);

      expect(balanceOf(c, kWalletId), 600 + 400 + 600 - 100, reason: onScreen(t));
      final paid = {for (final b in (await t.runAsync(db.getBills))!) b.name: b.isPaid};
      expect(paid, {'Rent': true, 'Later': false});
      expect(find.textContaining('Rent paid automatically'), findsOneWidget, reason: onScreen(t));
    });
  });
}
