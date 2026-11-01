import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/modules/fixedExp/bill_due.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ExpenseModel bill({int id = 1, int? due, bool paid = false, String name = 'Rent'}) =>
      ExpenseModel(id: id, name: name, amount: 10, isPaid: paid, dueDay: due);

  group('billDueDate', () {
    test('is this month when the day is still ahead, else next month', () {
      expect(billDueDate(28, DateTime(2026, 1, 25)), DateTime(2026, 1, 28));
      expect(billDueDate(5, DateTime(2026, 1, 25)), DateTime(2026, 2, 5));
    });

    test('the day itself still counts as this cycle', () {
      expect(billDueDate(25, DateTime(2026, 1, 25, 23, 59)), DateTime(2026, 1, 25));
    });

    test('a day the month lacks means its last day', () {
      expect(billDueDate(31, DateTime(2026, 4, 1)), DateTime(2026, 4, 30));
      expect(billDueDate(31, DateTime(2026, 2, 10)), DateTime(2026, 2, 28));
      expect(billDueDate(30, DateTime(2028, 2, 1)), DateTime(2028, 2, 29)); // leap year
      expect(billDueDate(30, DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    });

    test('rolls over the year', () {
      expect(billDueDate(5, DateTime(2026, 12, 20)), DateTime(2027, 1, 5));
    });
  });

  group('isOverdue', () {
    final start = DateTime(2026, 3, 1);

    test('the due day is not late, the next day is', () {
      final b = bill(due: 5);
      expect(isOverdue(b, start, DateTime(2026, 3, 5, 23, 59)), isFalse);
      expect(isOverdue(b, start, DateTime(2026, 3, 6, 0, 1)), isTrue);
    });

    test('paid bills and bills without a due day are never overdue', () {
      final now = DateTime(2026, 3, 20);
      expect(isOverdue(bill(due: 5, paid: true), start, now), isFalse);
      expect(isOverdue(bill(), start, now), isFalse);
    });
  });

  group('dueLabel', () {
    final start = DateTime(2026, 3, 1);
    String? label(ExpenseModel b, DateTime now, [DateTime? from]) =>
        dueLabel(b, from ?? start, now)?.text;

    test('counts down, then says it is late', () {
      final now = DateTime(2026, 3, 10, 15);
      expect(label(bill(due: 10), now), 'Due today');
      expect(label(bill(due: 11), now), 'Due tomorrow');
      expect(label(bill(due: 13), now), 'Due in 3 days');
      expect(label(bill(due: 16), now), 'Due in 6 days');
      expect(label(bill(due: 9), now), 'Overdue since yesterday');
      expect(label(bill(due: 5), now), 'Overdue by 5 days');
    });

    test('far dates show the day with the right ordinal', () {
      final now = DateTime(2026, 3, 1);
      expect(label(bill(due: 22), now), 'Due 22nd');
      expect(label(bill(due: 21), now), 'Due 21st');
      expect(label(bill(due: 23), now), 'Due 23rd');
      expect(label(bill(due: 11), now), 'Due 11th');
      expect(label(bill(due: 12), now), 'Due 12th');
      expect(label(bill(due: 13), now), 'Due 13th');
      expect(label(bill(due: 2), DateTime(2026, 1, 20), DateTime(2026, 1, 20)), 'Due 2nd');
    });

    test('only late labels are flagged late', () {
      final now = DateTime(2026, 3, 10);
      expect(dueLabel(bill(due: 9), start, now)!.late, isTrue);
      expect(dueLabel(bill(due: 10), start, now)!.late, isFalse);
    });

    test('nothing to say without a due day or once paid', () {
      final now = DateTime(2026, 3, 10);
      expect(dueLabel(bill(), start, now), isNull);
      expect(dueLabel(bill(due: 12, paid: true), start, now), isNull);
    });
  });

  group('dueText (shared by bills and debts)', () {
    final now = DateTime(2026, 3, 10, 15);
    String text(DateTime due) => dueText(due, now, 'FAR').text;

    test('counts down, says what a far date says, then says it is late', () {
      expect(text(DateTime(2026, 3, 10)), 'Due today');
      expect(text(DateTime(2026, 3, 11)), 'Due tomorrow');
      expect(text(DateTime(2026, 3, 16)), 'Due in 6 days');
      expect(text(DateTime(2026, 3, 17)), 'FAR');
      expect(text(DateTime(2026, 3, 9)), 'Overdue since yesterday');
      expect(text(DateTime(2026, 2, 28)), 'Overdue by 10 days');
    });

    test('a due date with a time of day counts as that whole day', () {
      expect(dueText(DateTime(2026, 3, 10, 23, 59), DateTime(2026, 3, 10, 0, 1), 'FAR').late, isFalse);
      expect(dueText(DateTime(2026, 3, 9, 23, 59), DateTime(2026, 3, 10, 0, 1), 'FAR').late, isTrue);
    });
  });

  group('pendingReminders', () {
    final start = DateTime(2026, 3, 1);

    test('9:00 the day before and on the day, named after the bill', () {
      final r = pendingReminders([bill(id: 4, due: 10)], start, DateTime(2026, 3, 2, 12));
      expect(r, [
        (id: 8, at: DateTime(2026, 3, 9, 9), title: 'Bill due tomorrow', body: 'Rent'),
        (id: 9, at: DateTime(2026, 3, 10, 9), title: 'Bill due today', body: 'Rent'),
      ]);
    });

    test('drops reminders whose time already passed', () {
      final b = [bill(due: 10)];
      // Day before at 10:00 -> its 9:00 reminder is gone, the day-of one stays.
      expect(pendingReminders(b, start, DateTime(2026, 3, 9, 10)).map((x) => x.title),
          ['Bill due today']);
      // 08:00 the day before -> both still ahead.
      expect(pendingReminders(b, start, DateTime(2026, 3, 9, 8)), hasLength(2));
      // The due day after 9:00, or later: nothing.
      expect(pendingReminders(b, start, DateTime(2026, 3, 10, 9, 30)), isEmpty);
      expect(pendingReminders(b, start, DateTime(2026, 3, 12)), isEmpty);
    });

    test('a bill due on the 1st is reminded on the last day of the month before', () {
      final r = pendingReminders([bill(due: 1)], DateTime(2026, 3, 20), DateTime(2026, 3, 20, 8));
      expect(r.first.at, DateTime(2026, 3, 31, 9));
      expect(r.last.at, DateTime(2026, 4, 1, 9));
    });

    test('paid bills and bills without a due day get none', () {
      expect(
          pendingReminders(
              [bill(id: 1, due: 10, paid: true), bill(id: 2)], start, DateTime(2026, 3, 2)),
          isEmpty);
    });

    test('ids never clash across bills and kinds', () {
      final r = pendingReminders(
          [for (var i = 1; i <= 5; i++) bill(id: i, due: 20)], start, DateTime(2026, 3, 2));
      expect(r.map((x) => x.id).toSet(), hasLength(10));
    });
  });
}
