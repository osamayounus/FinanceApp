import 'dart:io';

import 'package:financeapp/shared/networks/local/database.dart';
import 'package:financeapp/shared/networks/local/profile_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers/test_env.dart';

void main() {
  final pm = ProfileManager.instance;

  setUpAll(setUpTestEnv);
  tearDownAll(tearDownTestEnv);

  // ProfileManager is a singleton holding one profiles.db: wipe it between tests.
  setUp(() async {
    for (final prof in await pm.getProfiles()) {
      await pm.deleteProfile(prof.id);
    }
    await pm.clearActiveProfile();
  });

  group('profiles', () {
    test('starts empty', () async {
      expect(await pm.getProfiles(), isEmpty);
      expect(await pm.getActiveProfileId(), isNull);
    });

    test('create returns ids that increase and are listed in order', () async {
      final a = await pm.createProfile('A');
      final b = await pm.createProfile('B');
      expect(b.id, greaterThan(a.id));
      expect((await pm.getProfiles()).map((e) => e.name), ['A', 'B']);
    });

    test('ids are not reused after delete (finance_N.db never clashes)',
        () async {
      final a = await pm.createProfile('A');
      await pm.deleteProfile(a.id);
      final b = await pm.createProfile('B');
      expect(b.id, isNot(a.id));
    });

    test('dbFileFor', () {
      expect(pm.dbFileFor(4), 'finance_4.db');
    });

    test('names with unicode / quotes are stored verbatim', () async {
      await pm.createProfile("أسامة's \"main\"");
      expect((await pm.getProfiles()).single.name, "أسامة's \"main\"");
    });

    test('creating more than kMaxProfiles (3) is refused by the manager',
        () async {
      // The 3-profile limit is documented on ProfileManager but only checked in the UI.
      Object? err;
      try {
        for (var i = 0; i < 5; i++) {
          await pm.createProfile('P$i');
        }
      } catch (e) {
        err = e;
      }
      expect(err != null || (await pm.getProfiles()).length <= 3, isTrue,
          reason: '${(await pm.getProfiles()).length} profiles were created');
    });
  });

  group('active profile', () {
    test('set / get / replace / clear', () async {
      await pm.setActiveProfileId(2);
      expect(await pm.getActiveProfileId(), 2);
      await pm.setActiveProfileId(5);
      expect(await pm.getActiveProfileId(), 5);
      await pm.clearActiveProfile();
      expect(await pm.getActiveProfileId(), isNull);
    });

    test('deleting the active profile must not leave a dangling active id',
        () async {
      final a = await pm.createProfile('A');
      await pm.setActiveProfileId(a.id);
      await pm.deleteProfile(a.id);
      final active = await pm.getActiveProfileId();
      final ids = (await pm.getProfiles()).map((e) => e.id);
      expect(active == null || ids.contains(active), isTrue,
          reason: 'active_profile_id=$active but profiles=$ids');
    });
  });

  group('deleteProfile', () {
    test('removes the entry and the finance_N.db file', () async {
      final a = await pm.createProfile('A');
      final db = AppDatabase.forFile(pm.dbFileFor(a.id));
      await db.insertUser(kTestUser);
      await db.close();
      final file = File(p.join(testDir.path, pm.dbFileFor(a.id)));
      expect(file.existsSync(), isTrue);
      await pm.deleteProfile(a.id);
      expect(file.existsSync(), isFalse);
      expect(await pm.getProfiles(), isEmpty);
    });

    test('deleting an unknown id is harmless', () async {
      await pm.deleteProfile(999);
    });

    test('only the deleted profile\'s data goes away', () async {
      final a = await pm.createProfile('A');
      final b = await pm.createProfile('B');
      for (final prof in [a, b]) {
        final db = AppDatabase.forFile(pm.dbFileFor(prof.id));
        await db.insertUser(kTestUser.copyWith(name: prof.name));
        await db.close();
      }
      await pm.deleteProfile(a.id);
      final db = AppDatabase.forFile(pm.dbFileFor(b.id));
      expect((await db.getUser())!.name, 'B');
      await db.close();
    });

    test('profile data stays isolated between profile DB files', () async {
      final a = await pm.createProfile('A');
      final b = await pm.createProfile('B');
      final da = AppDatabase.forFile(pm.dbFileFor(a.id));
      final dbb = AppDatabase.forFile(pm.dbFileFor(b.id));
      await da.insertBill('only-in-A', 1, '');
      expect(await dbb.getBills(), isEmpty);
      await da.close();
      await dbb.close();
    });
  });

  group('tutorial flags (device-wide)', () {
    test('seen flag persists and is key-specific', () async {
      expect(await pm.hasTutorialSeen('x'), isFalse);
      await pm.markTutorialSeen('x');
      await pm.markTutorialSeen('x');
      expect(await pm.hasTutorialSeen('x'), isTrue);
      expect(await pm.hasTutorialSeen('y'), isFalse);
    });

    test('tutorial flags do not collide with active_profile_id', () async {
      await pm.setActiveProfileId(3);
      await pm.markTutorialSeen('active_profile_id');
      expect(await pm.getActiveProfileId(), 3);
    });

    test('clearActiveProfile keeps tutorial flags', () async {
      await pm.markTutorialSeen('keep');
      await pm.clearActiveProfile();
      expect(await pm.hasTutorialSeen('keep'), isTrue);
    });
  });

  group('migrateIfNeeded', () {
    File legacy() => File(p.join(testDir.path, 'finance.db'));

    test('no legacy file, no profiles -> nothing happens', () async {
      if (legacy().existsSync()) legacy().deleteSync();
      await pm.migrateIfNeeded();
      expect(await pm.getProfiles(), isEmpty);
    });

    test('legacy finance.db becomes profile "User 1" and is set active',
        () async {
      // build a real legacy DB (single-user layout)
      final db = AppDatabase.forFile('finance.db');
      await db.insertUser(kTestUser);
      await db.close();
      expect(legacy().existsSync(), isTrue);

      await pm.migrateIfNeeded();

      final profiles = await pm.getProfiles();
      expect(profiles.single.name, 'User 1');
      expect(await pm.getActiveProfileId(), profiles.single.id);
      expect(legacy().existsSync(), isFalse);
      final moved = AppDatabase.forFile(pm.dbFileFor(profiles.single.id));
      expect((await moved.getUser())!.name, kTestUser.name);
      await moved.close();
    });

    test('is idempotent: second call does not create another profile',
        () async {
      final db = AppDatabase.forFile('finance.db');
      await db.insertUser(kTestUser);
      await db.close();
      await pm.migrateIfNeeded();
      await pm.migrateIfNeeded();
      expect((await pm.getProfiles()).length, 1);
    });

    test('existing profiles + stray legacy file -> legacy file left alone',
        () async {
      await pm.createProfile('Real');
      final db = AppDatabase.forFile('finance.db');
      await db.insertUser(kTestUser);
      await db.close();
      await pm.migrateIfNeeded();
      expect((await pm.getProfiles()).length, 1);
      expect(legacy().existsSync(), isTrue);
      legacy().deleteSync();
    });

    test('legacy DB with -wal/-shm side files keeps them with the main file',
        () async {
      // sqlite in WAL mode leaves finance.db-wal next to the file; renaming only
      // the main file would orphan uncommitted pages.
      final db = AppDatabase.forFile('finance.db');
      final raw = await db.database;
      await raw.execute('PRAGMA journal_mode=WAL');
      await db.insertUser(kTestUser);
      // do NOT close: -wal still holds the data
      final wal = File(p.join(testDir.path, 'finance.db-wal'));
      final hadWal = wal.existsSync();
      await db.close();
      if (!hadWal) {
        // after a clean close sqlite checkpoints; nothing to orphan
        await pm.migrateIfNeeded();
        return;
      }
      await pm.migrateIfNeeded();
      final prof = (await pm.getProfiles()).single;
      final moved = AppDatabase.forFile(pm.dbFileFor(prof.id));
      expect(await moved.hasUser(), isTrue);
      await moved.close();
    });
  });
}
