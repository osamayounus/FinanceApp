import 'package:financeapp/models/expense_model.dart';
import 'package:financeapp/modules/fixedExp/bill_due.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/networks/local/database.dart';
import 'package:financeapp/shared/services/bill_reminders.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_env.dart';

class _Recorder implements BillReminders {
  final calls = <List<BillReminder>>[];
  final asks = <bool>[];
  @override
  Future<void> sync(List<BillReminder> reminders, {bool ask = false}) async {
    calls.add(reminders);
    asks.add(ask);
  }

  List<BillReminder> get last => calls.last;
}

void main() {
  setUpAll(setUpTestEnv);
  tearDownAll(tearDownTestEnv);

  late AppDatabase db;
  late _Recorder rec;
  late BillsNotifier bills;
  // freshDb() records the salary at "now", so the cycle starts today and a bill
  // due 5 days from now always has both of its reminders ahead of it.
  final dueInFiveDays = DateTime.now().add(const Duration(days: 5)).day;

  setUp(() async {
    db = await freshDb();
    rec = _Recorder();
    bills = BillsNotifier(db, <ExpenseModel>[], reminders: rec);
  });
  tearDown(() => db.close());

  test('adding a bill with a due day schedules the two reminders', () async {
    await bills.add('Rent', 100, '', dueDay: dueInFiveDays);
    expect(rec.last.map((r) => (r.title, r.body)),
        [('Bill due tomorrow', 'Rent'), ('Bill due today', 'Rent')]);
  });

  test('a bill without a due day schedules nothing', () async {
    await bills.add('Rent', 100, '');
    expect(rec.last, isEmpty);
  });

  test('every change replaces the whole set: pay, reset, edit, delete', () async {
    await bills.add('Rent', 100, '', dueDay: dueInFiveDays);
    await bills.add('Net', 20, '', dueDay: dueInFiveDays);
    expect(rec.last, hasLength(4));

    await bills.markPaid(0);
    expect(rec.last.map((r) => r.body).toSet(), {'Net'});

    await bills.resetAll(); // the next salary day
    expect(rec.last, hasLength(4));

    await bills.edit(1, 'Net', 20, '');
    expect(rec.last.map((r) => r.body).toSet(), {'Rent'});

    await bills.delete(0);
    expect(rec.last, isEmpty);
  });

  test('editing the due day keeps the bill but moves its reminders', () async {
    await bills.add('Rent', 100, '', dueDay: dueInFiveDays);
    final before = rec.last.map((r) => r.at).toList();
    final other = DateTime.now().add(const Duration(days: 8)).day;
    await bills.edit(0, 'Rent', 100, '', dueDay: other);
    expect(bills.state.single.dueDay, other);
    expect(rec.last.map((r) => r.at), isNot(before));
    expect(rec.last, hasLength(2));
  });

  test('only saving a bill with a due day may show the OS permission screens', () async {
    await bills.add('Rent', 100, '');
    expect(rec.asks.last, isFalse, reason: 'no due day, nothing to remind');
    await bills.add('Net', 20, '', dueDay: dueInFiveDays);
    expect(rec.asks.last, isTrue);
    await bills.edit(0, 'Rent', 100, '', dueDay: dueInFiveDays);
    expect(rec.asks.last, isTrue);
    await bills.edit(0, 'Rent', 100, '');
    expect(rec.asks.last, isFalse, reason: 'clearing a due day asks nothing');

    // Everything else (app start, pay, new salary day, delete, restore) stays silent.
    await bills.syncReminders();
    await bills.markPaid(1);
    await bills.resetAll();
    await bills.reload();
    await bills.delete(0);
    expect(rec.asks.skip(4), everyElement(isFalse));
  });

  test('an out-of-range due day is stored as none', () async {
    await bills.add('Rent', 100, '', dueDay: 45);
    expect(bills.state.single.dueDay, isNull);
    expect(rec.last, isEmpty);
  });

  test('reload (after a restore) schedules what is on disk', () async {
    await db.insertBill('Rent', 100, '', dueDay: dueInFiveDays);
    await bills.reload();
    expect(bills.state.single.dueDay, dueInFiveDays);
    expect(rec.last, hasLength(2));
  });

  test('a failing reminder service never breaks the bills screen', () async {
    // LocalBillReminders swallows platform errors; in a plain test run there is
    // no plugin behind it, which is exactly such an error.
    final real = BillsNotifier(db, <ExpenseModel>[], reminders: LocalBillReminders());
    await real.add('Rent', 100, '', dueDay: dueInFiveDays);
    expect(real.state.single.name, 'Rent');
    expect((await db.getBills()).single.dueDay, dueInFiveDays);
  });
}
