import 'dart:io';
import 'dart:typed_data';

import 'package:financeapp/models/analytics_model.dart';
import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/modules/analytics/widgets/smart_insights_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    // Without the real font the 4px-per-em Ahem font makes the empty-state row overflow.
    final rubik = FontLoader('Rubik');
    for (final w in ['Regular', 'Bold', 'Light', 'Medium']) {
      rubik.addFont(File('lib/shared/styles/fonts/Rubik/Rubik-$w.ttf')
          .readAsBytes()
          .then((b) => ByteData.view(b.buffer)));
    }
    await rubik.load();
  });

  /// Six months, oldest first; the last one is "this month".
  AnalyticsData data(List<double> expenses,
      {double income = 1000, double savingsChange = 0}) {
    return AnalyticsData(
      months: [
        for (var i = 0; i < 6; i++)
          MonthStat(
              year: 2025,
              month: i + 1,
              income: i == 5 ? income : 0,
              expenses: expenses[i]),
      ],
      savingsHistory: List.filled(6, 0),
      currentMonthTimeline: const [],
      savingsChangeThisMonth: savingsChange,
    );
  }

  Future<List<String>> shown(
    WidgetTester t,
    AnalyticsData d, {
    double budgetBalance = 400,
    double monthlyBudget = 400,
    List<ExpenseModel> bills = const [],
  }) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SmartInsightsCard(
              data: d,
              budgetBalance: budgetBalance,
              monthlyBudget: monthlyBudget,
              bills: bills,
              currency: 'JOD',
            ),
          ),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 200));
    return t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .where((s) => s.isNotEmpty && s != 'Smart Insights')
        .toList();
  }

  group('best / worst month', () {
    testWidgets('is not claimed when the other months have no spending at all',
        (t) async {
      final texts = await shown(t, data([0, 0, 0, 0, 0, 500]));
      expect(texts.where((s) => s.contains('Highest-spending')), isEmpty, reason: '$texts');
      expect(texts.where((s) => s.contains('Best spending')), isEmpty, reason: '$texts');
    });

    testWidgets('is not claimed from only two months of data', (t) async {
      final texts = await shown(t, data([0, 0, 0, 0, 100, 500]));
      expect(texts.where((s) => s.contains('Highest-spending')), isEmpty, reason: '$texts');
    });

    testWidgets('highest month is reported once three months have data', (t) async {
      final texts = await shown(t, data([0, 300, 200, 100, 150, 500]));
      expect(texts.where((s) => s.contains('Highest-spending')), hasLength(1), reason: '$texts');
    });

    testWidgets('best month is reported once three months have data', (t) async {
      final texts = await shown(t, data([0, 300, 200, 400, 150, 100]));
      expect(texts.where((s) => s.contains('Best spending')), hasLength(1), reason: '$texts');
    });

    testWidgets('a tie is still not reported', (t) async {
      final texts = await shown(t, data([0, 300, 200, 500, 150, 500]));
      expect(texts.where((s) => s.contains('Highest-spending')), isEmpty, reason: '$texts');
    });
  });

  group('budget usage', () {
    testWidgets('"only 0% used" is not shown while the budget is untouched', (t) async {
      // Spending happened (e.g. bills paid from the wallet) but nothing left the budget.
      final texts = await shown(t, data([0, 0, 0, 0, 0, 50]), budgetBalance: 400);
      expect(texts.where((s) => s.contains('of budget used')), isEmpty, reason: '$texts');
    });

    testWidgets('a rounding-to-zero amount is not "0%" either', (t) async {
      final texts = await shown(t, data([0, 0, 0, 0, 0, 50]), budgetBalance: 399.9);
      expect(texts.where((s) => s.contains('of budget used')), isEmpty, reason: '$texts');
    });

    testWidgets('real low usage is still praised', (t) async {
      final texts = await shown(t, data([0, 0, 0, 0, 0, 50]), budgetBalance: 320);
      expect(texts, contains('Only 20% of budget used — you\'re well on track'));
    });

    testWidgets('high usage still warns', (t) async {
      final texts = await shown(t, data([0, 0, 0, 0, 0, 50]), budgetBalance: 40);
      expect(texts, contains('90% of your monthly budget has been used'));
    });
  });

  group('savings activity', () {
    testWidgets('reports what the user added, not the starting balance', (t) async {
      final texts = await shown(t, data([0, 0, 0, 0, 0, 0], savingsChange: 10.25));
      expect(texts, contains('You added 10.25 JOD to savings this month'));
      expect(texts.where((s) => s.contains('110.25')), isEmpty);
    });

    testWidgets('reports a withdrawal', (t) async {
      final texts = await shown(t, data([0, 0, 0, 0, 0, 0], savingsChange: -5));
      expect(texts, contains('You withdrew 5 JOD from savings this month'));
    });

    testWidgets('says nothing when savings did not move', (t) async {
      final texts = await shown(t, data([0, 0, 0, 0, 0, 0]));
      expect(texts.where((s) => s.contains('savings')), isEmpty, reason: '$texts');
    });
  });
}
