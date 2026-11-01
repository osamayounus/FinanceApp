import 'package:financeapp/modules/salaryDay/salary_cycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('salaryCycleStart', () {
    test('is this month once the salary day has come, last month before it', () {
      expect(salaryCycleStart(DateTime(2026, 10, 25), 25), DateTime(2026, 10, 25));
      expect(salaryCycleStart(DateTime(2026, 10, 31, 23, 59), 25), DateTime(2026, 10, 25));
      expect(salaryCycleStart(DateTime(2026, 10, 24), 25), DateTime(2026, 9, 25));
    });

    test('day 1 is the calendar month', () {
      expect(salaryCycleStart(DateTime(2026, 10, 1), 1), DateTime(2026, 10, 1));
      expect(salaryCycleStart(DateTime(2026, 10, 31), 1), DateTime(2026, 10, 1));
    });

    test('crosses the year', () {
      expect(salaryCycleStart(DateTime(2027, 1, 10), 25), DateTime(2026, 12, 25));
    });

    test('a day the month does not have means its last day', () {
      expect(salaryCycleStart(DateTime(2026, 4, 30), 31), DateTime(2026, 4, 30));
      expect(salaryCycleStart(DateTime(2026, 4, 29), 31), DateTime(2026, 3, 31));
      expect(salaryCycleStart(DateTime(2026, 3, 1), 30), DateTime(2026, 2, 28));
      expect(salaryCycleStart(DateTime(2028, 3, 1), 30), DateTime(2028, 2, 29)); // leap year
    });
  });

  group('nextSalaryDay', () {
    test('is the start of the following cycle, never today', () {
      expect(nextSalaryDay(DateTime(2026, 10, 25), 25), DateTime(2026, 11, 25));
      expect(nextSalaryDay(DateTime(2026, 10, 3), 25), DateTime(2026, 10, 25));
      expect(nextSalaryDay(DateTime(2026, 12, 30), 1), DateTime(2027, 1, 1));
    });

    test('clamps to short months', () {
      expect(nextSalaryDay(DateTime(2026, 1, 31), 31), DateTime(2026, 2, 28));
    });
  });

  group('salaryProcessed / salaryStatus', () {
    final now = DateTime(2026, 11, 3, 10);

    test('nothing processed yet', () {
      expect(salaryProcessed(now, 1, null), isFalse);
      expect(salaryStatus(now, 1, null),
          'Salary day 1 Nov · press the coin when your salary arrives');
    });

    test('a run in an earlier cycle does not count', () {
      expect(salaryProcessed(now, 1, DateTime(2026, 10, 31, 23)), isFalse);
      expect(salaryProcessed(now, 25, DateTime(2026, 10, 24)), isFalse);
    });

    test('a run since the cycle began does, even at midnight of its first day', () {
      expect(salaryProcessed(now, 1, DateTime(2026, 11, 1)), isTrue);
      expect(salaryProcessed(now, 25, DateTime(2026, 10, 25)), isTrue);
      expect(salaryStatus(now, 25, DateTime(2026, 10, 27)),
          'Salary processed on 27 Oct · next salary day 25 Nov');
    });
  });
}
