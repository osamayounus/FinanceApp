import 'package:financeapp/models/savings_goal_model.dart';
import 'package:financeapp/modules/analytics/savings_goals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 3, 10, 15, 30);
  SavingsGoal goal(String name, double target,
          {double saved = 0, DateTime? date, int id = 0}) =>
      SavingsGoal(id: id, name: name, target: target, saved: saved, targetDate: date);

  group('goalProgress: each goal holds what was set aside for it', () {
    test('goals show their own envelope, not a share of the whole balance', () {
      final p = goalProgress(
          [goal('Laptop', 500, saved: 120), goal('Trip', 200, saved: 30)], 1000, now);
      expect(p.map((x) => (x.goal.name, x.saved, x.reached)),
          [('Laptop', 120.0, false), ('Trip', 30.0, false)]);
    });

    test('a goal with nothing set aside stays empty however big the balance is', () {
      final p = goalProgress([goal('Laptop', 500)], 10000, now).single;
      expect((p.saved, p.reached), (0, false));
    });

    test('a full envelope means reached', () {
      final p = goalProgress([goal('A', 100, saved: 100)], 100, now).single;
      expect(p.reached, isTrue);
      // 0.3 - 0.1 style float dust must not hide a full goal.
      expect(goalProgress([goal('B', 0.3, saved: 0.1 + 0.2)], 1, now).single.reached, isTrue);
    });

    test('no goals, no balance or a negative balance', () {
      expect(goalProgress([], 100, now), isEmpty);
      expect(goalProgress([goal('A', 10, saved: 5)], 0, now).single.saved, 0);
      expect(goalProgress([goal('A', 10, saved: 5)], -50, now).single.saved, 0);
    });
  });

  group('goalProgress: Savings dropped below what the goals hold', () {
    test('later goals show less, earlier ones keep theirs', () {
      final p = goalProgress(
          [goal('A', 100, saved: 80), goal('B', 100, saved: 50), goal('C', 100, saved: 20)],
          100, now);
      expect(p.map((x) => x.saved), [80.0, 20.0, 0.0]);
    });

    test('the stored amounts are untouched, so they come back with the balance', () {
      final g = [goal('A', 100, saved: 80), goal('B', 100, saved: 50)];
      expect(goalProgress(g, 100, now).map((x) => x.saved), [80.0, 20.0]);
      expect(goalProgress(g, 200, now).map((x) => x.saved), [80.0, 50.0]);
    });

    test('a goal that lost its cover is no longer reached', () {
      final g = [goal('A', 100, saved: 100)];
      expect(goalProgress(g, 100, now).single.reached, isTrue);
      expect(goalProgress(g, 60, now).single.reached, isFalse);
    });
  });

  group('goalShare: what a deposit or withdrawal really moves in an envelope', () {
    test('a deposit fills the envelope up to the target', () {
      expect(goalShare(goal('A', 100, saved: 40), 30, deposit: true), 30);
      expect(goalShare(goal('A', 100, saved: 40), 60, deposit: true), 60); // exactly the room
      expect(goalShare(goal('A', 100, saved: 40), 80, deposit: true), 60);
    });

    test('a withdrawal takes at most what the envelope holds', () {
      expect(goalShare(goal('A', 100, saved: 40), 30, deposit: false), 30);
      expect(goalShare(goal('A', 100, saved: 40), 80, deposit: false), 40);
    });

    test('a full envelope takes nothing, an empty one gives nothing', () {
      expect(goalShare(goal('A', 100, saved: 100), 10, deposit: true), 0);
      expect(goalShare(goal('A', 100), 10, deposit: false), 0);
    });
  });

  group('unallocated / uncovered', () {
    test('unallocated is what no goal holds', () {
      final p = goalProgress([goal('A', 100, saved: 30), goal('B', 100, saved: 20.5)], 100, now);
      expect(unallocated(p, 100), 49.5);
      expect(uncovered(p), 0);
    });

    test('nothing is unallocated once the goals hold everything', () {
      final p = goalProgress([goal('A', 100, saved: 60)], 60, now);
      expect(unallocated(p, 60), 0);
    });

    test('over-allocation: nothing free, and the missing amount is reported', () {
      final p = goalProgress([goal('A', 100, saved: 80), goal('B', 100, saved: 50)], 100, now);
      expect(unallocated(p, 100), 0);
      expect(uncovered(p), 30);
    });

    test('no goals: the whole balance is unallocated; a negative balance gives 0', () {
      expect(unallocated(goalProgress([], 75, now), 75), 75);
      expect(unallocated(goalProgress([], -5, now), -5), 0);
    });
  });

  group('goalProgress: what to save per month', () {
    test('remaining amount over the months left until the date', () {
      // 60 days = 2 months (30.44 days each, rounded up)
      final p = goalProgress(
          [goal('A', 500, saved: 100, date: DateTime(2026, 5, 9))], 100, now).single;
      expect(p.perMonth, 200);
      expect(p.late, isFalse);
    });

    test('a partial month counts as a whole one', () {
      final p = goalProgress([goal('A', 300, date: DateTime(2026, 4, 20))], 0, now).single;
      expect(p.perMonth, 150); // 41 days -> 2 months
    });

    test('on the day itself or within it: everything this month', () {
      final today = goalProgress([goal('A', 90, date: DateTime(2026, 3, 10))], 0, now).single;
      expect((today.perMonth, today.late), (90, false), reason: 'the target day itself is not late');
      expect(
          goalProgress([goal('A', 90, saved: 30, date: DateTime(2026, 3, 11))], 30, now)
              .single
              .perMonth,
          60);
    });

    test('the time of day does not matter', () {
      final late = DateTime(2026, 3, 10, 23, 59);
      final early = DateTime(2026, 3, 10, 0, 1);
      final g = [goal('A', 90, date: DateTime(2026, 3, 12))];
      expect(goalProgress(g, 0, late).single.perMonth, goalProgress(g, 0, early).single.perMonth);
      expect(goalProgress(g, 0, late).single.late, isFalse);
    });

    test('a date in the past is late, with no monthly figure', () {
      final p = goalProgress(
          [goal('A', 100, saved: 10, date: DateTime(2026, 3, 9))], 10, now).single;
      expect((p.late, p.perMonth, p.reached), (true, null, false));
    });

    test('a reached goal is never late and needs no saving, whatever its date', () {
      final p = goalProgress(
          [goal('A', 100, saved: 100, date: DateTime(2020, 1, 1))], 100, now).single;
      expect((p.late, p.perMonth, p.reached), (false, null, true));
    });

    test('no date: no monthly figure', () {
      expect(goalProgress([goal('A', 100, saved: 10)], 10, now).single.perMonth, isNull);
    });

    test('the monthly figure uses what the balance really backs', () {
      final g = [goal('A', 300, saved: 100, date: DateTime(2026, 5, 9))];
      expect(goalProgress(g, 100, now).single.perMonth, 100); // (300 - 100) / 2
      expect(goalProgress(g, 40, now).single.perMonth, 130); // only 40 is still there
    });
  });
}
